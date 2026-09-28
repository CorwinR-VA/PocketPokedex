import Foundation
import Observation

@MainActor
@Observable
final class PokedexFeedViewModel {
    nonisolated static let defaultPageSize = 40

    enum Phase: Equatable {
        case idle
        case loadingFirstPage
        case loaded
        case failed(message: String)
    }

    private(set) var items: [PokemonFeedItem] = []
    private(set) var availableTypes: [PokemonType] = PokemonType.allCases
    private(set) var phase: Phase = .idle
    private(set) var isLoadingNextPage = false
    private(set) var hasMorePages = true
    private(set) var totalCount = 0
    private(set) var loadedPageCount = 0
    private(set) var nextPageErrorMessage: String?

    /// The selected types, in the order they were picked. Empty means no type filter. At most
    /// `maximumSelectedTypes` of them, because a card has to carry *every* selected type.
    var selectedTypes: [PokemonType] = []

    /// No Pokémon has more than two types, so an all-of filter is only ever satisfiable with one or
    /// two chips. The third tap replaces the earliest selection instead of silently doing nothing.
    nonisolated static let maximumSelectedTypes = 2

    var showsOnlyTeam = false

    private(set) var teamItems: [PokemonFeedItem] = []
    private(set) var isLoadingTeam = false
    private(set) var teamErrorMessage: String?

    /// Ids whose detail request has been sent but has not settled yet — whether it succeeds or fails.
    /// A card's types only arrive with that request, so until it settles the feed cannot say whether
    /// the card satisfies a filter. Failure counts as settled, or a card whose detail request failed
    /// would leave the empty state suppressed forever.
    private var identifiersAwaitingTypes: Set<Int> = []

    var isAwaitingCardTypes: Bool { !identifiersAwaitingTypes.isEmpty }

    /// Whether one card's details are still on their way, so a view can tell a wait apart from a
    /// Pokémon whose artwork will never arrive.
    func isAwaitingDetails(for identifier: Int) -> Bool {
        identifiersAwaitingTypes.contains(identifier)
    }

    var visibleItems: [PokemonFeedItem] {
        guard !showsOnlyTeam else {
            return teamItems.filter { teamStore.contains($0.id) && matchesSelectedTypes($0) }
        }

        guard !selectedTypes.isEmpty else { return items }
        return items.filter(matchesSelectedTypes)
    }

    private var isFilterAwaitingMatches: Bool {
        !showsOnlyTeam && !selectedTypes.isEmpty && visibleItems.isEmpty && !items.isEmpty && hasMorePages
    }

    /// The selected types named in chip order — "Fire", "Fire and Ice", or empty when unfiltered.
    /// Chip order rather than tap order, so the copy lines up with the chip row and cannot reshuffle
    /// between renders.
    var selectedTypeSummary: String {
        availableTypes
            .filter(selectedTypes.contains)
            .map(\.name)
            .joined(separator: " and ")
    }

    /// Closes the feed: the size of the dex, or — once a filter has finished loading every page —
    /// the number of Pokémon that matched it.
    var paginationFooterText: String {
        guard !selectedTypes.isEmpty else {
            return "That's all \(totalCount) Pokémon."
        }
        return "That's all \(visibleItems.count) \(selectedTypeSummary) type Pokémon."
    }

    /// All-of matching: a card has to carry every selected type. An empty selection matches
    /// everything, which is what the team path relies on.
    private func matchesSelectedTypes(_ item: PokemonFeedItem) -> Bool {
        selectedTypes.allSatisfy(item.types.contains)
    }

    private let service: any PokemonService
    private let teamStore: TeamStore
    private let pageSize: Int
    private let detailConcurrency: Int
    private var nextPageURL: URL?
    private var nextPageOffset = 0
    private var pageRequest: Task<PokemonPage, any Error>?
    private var hydrationTask: Task<Void, Never>?
    private var hydrationQueue: [Int] = []
    private var queuedIdentifiers: Set<Int> = []

    init(
        service: any PokemonService,
        teamStore: TeamStore,
        pageSize: Int = PokedexFeedViewModel.defaultPageSize,
        detailConcurrency: Int = 6
    ) {
        self.service = service
        self.teamStore = teamStore
        self.pageSize = pageSize
        self.detailConcurrency = detailConcurrency
    }

    func start() async {
        guard phase == .idle else { return }
        phase = .loadingFirstPage

        async let typesTask: Void = loadAvailableTypes()
        async let pageTask: Void = loadNextPage()
        _ = await (typesTask, pageTask)
    }

    func refresh() async {
        guard !showsOnlyTeam else {
            if !isLoadingTeam {
                teamItems = []
            }
            await loadTeam()
            return
        }

        if let pageRequest {
            pageRequest.cancel()
            _ = try? await pageRequest.value
        }

        hydrationTask?.cancel()
        hydrationQueue = []
        queuedIdentifiers = []
        identifiersAwaitingTypes = []
        nextPageURL = nil
        nextPageOffset = 0
        hasMorePages = true
        totalCount = 0
        nextPageErrorMessage = nil
        items = []
        // Reset the page count along with everything else. The grid's pagination sentinel re-arms
        // by watching this value, so leaving it at the old total makes a refresh — which is not a
        // page load — look like one, and the sentinel then asks for a page nobody scrolled to.
        loadedPageCount = 0
        phase = .loadingFirstPage
        await loadNextPage()
    }

    func retry() async {
        if items.isEmpty {
            await refresh()
        } else {
            nextPageErrorMessage = nil
            await loadNextPage()
        }
    }

    func loadMoreIfNeeded() async {
        if isFilterAwaitingMatches {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
        }

        await loadNextPage()
    }

    private func loadNextPage() async {
        guard !isLoadingNextPage, hasMorePages else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let pageRequest = Task { [service, pageSize, nextPageOffset, nextPageURL] in
            if let nextPageURL {
                return try await service.pokemonPage(following: nextPageURL)
            }
            return try await service.pokemonPage(limit: pageSize, offset: nextPageOffset)
        }
        self.pageRequest = pageRequest
        defer { self.pageRequest = nil }

        do {
            let page = try await pageRequest.value

            nextPageURL = page.nextPageURL
            nextPageOffset += page.items.count
            hasMorePages = page.nextPageURL != nil
            totalCount = page.totalCount
            nextPageErrorMessage = nil
            items.append(contentsOf: page.items)
            loadedPageCount += 1
            phase = .loaded

            if hasMorePages {
                hydrateDetails(for: page.items)
            } else {
                // Paging is over, so give a card whose detail request failed during the scroll one
                // more try — the queue drains work, it does not retry failures.
                hydrateDetails(for: items.filter { $0.types.isEmpty })
            }
        } catch {
            let apiError = PokeAPIError.from(error)
            guard apiError != .cancelled else { return }

            if items.isEmpty {
                phase = .failed(message: apiError.userFacingMessage)
            } else {
                nextPageErrorMessage = apiError.userFacingMessage
            }
        }
    }

    func toggleType(_ type: PokemonType) {
        if let index = selectedTypes.firstIndex(of: type) {
            selectedTypes.remove(at: index)
            return
        }

        if selectedTypes.count == Self.maximumSelectedTypes {
            selectedTypes.removeFirst()
        }
        selectedTypes.append(type)
    }

    func toggleTeamFilter() {
        showsOnlyTeam.toggle()
        guard showsOnlyTeam else { return }
        Task { await loadTeam() }
    }

    func loadTeam() async {
        guard !isLoadingTeam else { return }

        let markedIdentifiers = teamStore.memberIdentifiers
        teamItems.removeAll { !markedIdentifiers.contains($0.id) }

        let unfetchedIdentifiers = markedIdentifiers.subtracting(teamItems.map(\.id)).sorted()
        guard !unfetchedIdentifiers.isEmpty else {
            teamErrorMessage = nil
            return
        }

        isLoadingTeam = true
        defer { isLoadingTeam = false }

        let fetched: [Pokemon?] = await withBoundedTaskGroup(
            over: unfetchedIdentifiers,
            maxConcurrent: detailConcurrency
        ) { identifier in
            await self.fetchTeamMember(identifier)
        }

        let loaded = fetched.compactMap { $0 }.map(PokemonFeedItem.init(pokemon:))
        let failedCount = unfetchedIdentifiers.count - loaded.count
        teamErrorMessage = failedCount == 0
            ? nil
            : "Couldn't load \(failedCount) \(failedCount == 1 ? "team member" : "team members")."

        teamItems.append(contentsOf: loaded)
        teamItems.sort { $0.id < $1.id }
    }

    private func fetchTeamMember(_ identifier: Int) async -> Pokemon? {
        try? await service.pokemon(.id(identifier))
    }

    private func loadAvailableTypes() async {
        guard let types = try? await service.availableTypes(), !types.isEmpty else { return }
        availableTypes = types
    }

    /// Queues the cards that still need their details and starts draining if nothing is draining.
    ///
    /// Pages arrive faster than forty detail requests can finish — a fast scroll loads them back to
    /// back — so a new page *adds* to the queue instead of cancelling the page before it. Cancelling
    /// is what used to strand cards: an unhydrated card has no types and no artwork URL, so it can
    /// never satisfy a filter and no image loader can ever fetch it, however well the cache works.
    private func hydrateDetails(for pageItems: [PokemonFeedItem]) {
        let identifiers = pageItems.map(\.id).filter { queuedIdentifiers.insert($0).inserted }
        guard !identifiers.isEmpty else { return }

        hydrationQueue.append(contentsOf: identifiers)
        identifiersAwaitingTypes.formUnion(identifiers)

        guard hydrationTask == nil else { return }
        hydrationTask = Task { [weak self] in
            await self?.drainHydrationQueue()
            self?.hydrationTask = nil
        }
    }

    private func drainHydrationQueue() async {
        while !hydrationQueue.isEmpty, !Task.isCancelled {
            let batch = Array(hydrationQueue.prefix(detailConcurrency))
            hydrationQueue.removeFirst(batch.count)
            batch.forEach { queuedIdentifiers.remove($0) }

            _ = await withBoundedTaskGroup(over: batch, maxConcurrent: detailConcurrency) { identifier in
                await self.hydrate(identifier)
            }
        }
    }

    private func hydrate(_ pokemonIdentifier: Int) async {
        guard let pokemon = try? await service.pokemon(.id(pokemonIdentifier)) else {
            // A cancelled request is re-queued by whoever cancelled it, and a refresh has already
            // cleared the sets, so only a real failure settles the wait here.
            if !Task.isCancelled {
                identifiersAwaitingTypes.remove(pokemonIdentifier)
            }
            return
        }

        identifiersAwaitingTypes.remove(pokemonIdentifier)

        guard let index = items.firstIndex(where: { $0.id == pokemonIdentifier }) else { return }
        items[index] = PokemonFeedItem(pokemon: pokemon)
    }
}

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

    var selectedType: PokemonType?

    var showsOnlyTeam = false

    private(set) var teamItems: [PokemonFeedItem] = []
    private(set) var isLoadingTeam = false
    private(set) var teamErrorMessage: String?

    var visibleItems: [PokemonFeedItem] {
        guard !showsOnlyTeam else {
            return teamItems.filter { teamStore.contains($0.id) && matchesSelectedType($0) }
        }

        guard let selectedType else { return items }
        return items.filter { $0.types.contains(selectedType) }
    }

    private var isFilterAwaitingMatches: Bool {
        !showsOnlyTeam && selectedType != nil && visibleItems.isEmpty && !items.isEmpty && hasMorePages
    }

    private func matchesSelectedType(_ item: PokemonFeedItem) -> Bool {
        guard let selectedType else { return true }
        return item.types.contains(selectedType)
    }

    private let service: any PokemonService
    private let teamStore: TeamStore
    private let pageSize: Int
    private let detailConcurrency: Int
    private var nextPageURL: URL?
    private var nextPageOffset = 0
    private var pageRequest: Task<PokemonPage, any Error>?
    private var hydrationTask: Task<Void, Never>?

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
        nextPageURL = nil
        nextPageOffset = 0
        hasMorePages = true
        totalCount = 0
        nextPageErrorMessage = nil
        items = []
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

            hydrateDetails(for: page.items)
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

    private func hydrateDetails(for pageItems: [PokemonFeedItem]) {
        let identifiers = pageItems.map(\.id)
        hydrationTask?.cancel()
        hydrationTask = Task { [weak self] in
            guard let self else { return }
            _ = await withBoundedTaskGroup(over: identifiers, maxConcurrent: self.detailConcurrency) { identifier in
                await self.hydrate(identifier)
            }
        }
    }

    private func hydrate(_ pokemonIdentifier: Int) async {
        guard let pokemon = try? await service.pokemon(.id(pokemonIdentifier)) else { return }

        guard let index = items.firstIndex(where: { $0.id == pokemonIdentifier }) else { return }
        items[index] = PokemonFeedItem(pokemon: pokemon)
    }
}

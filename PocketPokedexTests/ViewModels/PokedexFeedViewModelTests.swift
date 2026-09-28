import Foundation
import Testing
@testable import PocketPokedex

/// The `next` link the stub's first page carries.
private let secondPageURL = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=2&offset=2")!

@Suite("Feed view model")
@MainActor
struct PokedexFeedViewModelTests {

    /// A service serving two pages of two cards, with hydratable details for every card.
    private static func stubService(
        firstPage: PokemonPage? = nil,
        secondPage: PokemonPage? = nil,
        details: [Int: Pokemon] = [:],
        types: [PokemonType] = PokemonType.allCases
    ) -> RecordingPokemonService {
        let pageOne = firstPage ?? Fixture.page(
            [Fixture.feedItem(id: 1), Fixture.feedItem(id: 2)],
            nextPageURL: secondPageURL,
            totalCount: 4
        )
        let pageTwo = secondPage ?? Fixture.page(
            [Fixture.feedItem(id: 3), Fixture.feedItem(id: 4)],
            nextPageURL: nil,
            totalCount: 4
        )

        return RecordingPokemonService(
            pageHandler: { request in
                guard let followedURL = request.followedURL else { return pageOne }
                return followedURL == secondPageURL ? pageTwo : pageOne
            },
            pokemonHandler: { identifier in
                guard case .id(let id) = identifier, let pokemon = details[id] else {
                    throw PokeAPIError.notFound
                }
                return pokemon
            },
            speciesHandler: { _ in Fixture.species(id: 1) },
            typesHandler: { types }
        )
    }

    private static func makeViewModel(
        service: RecordingPokemonService,
        defaults: UserDefaults? = nil,
        pageSize: Int = PokedexFeedViewModel.defaultPageSize
    ) -> PokedexFeedViewModel {
        PokedexFeedViewModel(
            service: service,
            teamStore: TeamStore(defaults: defaults ?? Fixture.scratchDefaults()),
            pageSize: pageSize
        )
    }

    /// Builds the details map keyed by dex number, so a test can say `detail(...)` inline.
    private static func details(_ pokemon: Pokemon...) -> [Int: Pokemon] {
        Dictionary(uniqueKeysWithValues: pokemon.map { ($0.id, $0) })
    }

    // MARK: Starting

    @Test("Starts idle, with the full type list and nothing loaded")
    func startsIdle() {
        let viewModel = Self.makeViewModel(service: Self.stubService())

        #expect(viewModel.phase == .idle)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.availableTypes == PokemonType.allCases)
        #expect(viewModel.hasMorePages)
        #expect(viewModel.loadedPageCount == 0)
        #expect(viewModel.totalCount == 0)
        #expect(viewModel.nextPageErrorMessage == nil)
    }

    @Test("Loads the first page and the type list in one start")
    func loadsFirstPage() async {
        let service = Self.stubService()
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.items.map(\.id) == [1, 2])
        #expect(viewModel.totalCount == 4)
        #expect(viewModel.loadedPageCount == 1)
        #expect(service.recordedPageRequests == [.offset(0, limit: 2)] as [RecordingPokemonService.PageRequest])
        #expect(service.count(of: .availableTypes) == 1)
    }

    @Test("Ignores a second start")
    func ignoresSecondStart() async {
        let service = Self.stubService()
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.start()

        #expect(viewModel.items.map(\.id) == [1, 2])
        #expect(service.count(of: .page) == 1)
    }

    @Test("Adopts the type list the service returns")
    func adoptsAvailableTypes() async {
        let service = Self.stubService(types: [.fire, .water])
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()

        #expect(viewModel.availableTypes == [.fire, .water])
    }

    @Test("Keeps the full type list when the service fails")
    func keepsTypesOnFailure() async {
        let service = RecordingPokemonService(
            pageHandler: { (_: RecordingPokemonService.PageRequest) in
                Fixture.page([Fixture.feedItem(id: 1)], totalCount: 1)
            },
            typesHandler: { () throws -> [PokemonType] in
                throw PokeAPIError.transport(description: "offline")
            }
        )
        let viewModel = Self.makeViewModel(service: service, pageSize: 1)

        await viewModel.start()

        #expect(viewModel.availableTypes == PokemonType.allCases)
    }

    // MARK: Pagination

    @Test("Follows the next-page URL for the second page")
    func followsNextPageURL() async {
        let service = Self.stubService()
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.items.map(\.id) == [1, 2, 3, 4])
        #expect(viewModel.loadedPageCount == 2)
        #expect(!viewModel.hasMorePages)
        #expect(service.recordedPageRequests == [
            RecordingPokemonService.PageRequest.offset(0, limit: 2),
            .following(secondPageURL)
        ])
    }

    @Test("Stops asking for pages once the feed is exhausted")
    func stopsAtTheEnd() async {
        let service = Self.stubService()
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        await viewModel.loadMoreIfNeeded()

        #expect(service.count(of: .page) == 2)
        #expect(viewModel.items.count == 4)
    }

    @Test("Fills in each card's types and artwork after the page lands")
    func hydratesCards() async {
        let artwork = URL(string: "https://art.test/1.png")!
        let bulbasaur = Fixture.pokemon(id: 1, name: "bulbasaur", types: [.grass, .poison], artworkURL: artwork)
        let service = Self.stubService(details: [1: bulbasaur])
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await waitUntil { viewModel.items.first?.types == [.grass, .poison] }

        #expect(viewModel.items.first?.artworkURL == artwork)
        #expect(viewModel.items.first?.displayName == "Bulbasaur")
        // A card whose detail request fails keeps the bare version the list gave it.
        #expect(viewModel.items.last?.types.isEmpty == true)
    }

    // MARK: Filtering

    @Test("Filters by type over the pages already loaded")
    func filtersByType() async {
        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1, types: [.grass]),
            Fixture.pokemon(id: 2, types: [.fire]),
            Fixture.pokemon(id: 3, types: [.grass]),
            Fixture.pokemon(id: 4, types: [.water])
        ))
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }

        viewModel.selectedTypes = [.grass]
        #expect(viewModel.visibleItems.map(\.id) == [1, 3])

        viewModel.selectedTypes = [.water]
        #expect(viewModel.visibleItems.map(\.id) == [4])

        viewModel.selectedTypes = []
        #expect(viewModel.visibleItems.map(\.id) == [1, 2, 3, 4])
    }

    @Test("Matches every selected type, so adding one narrows the feed")
    func filtersByAllSelectedTypes() async {
        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1, types: [.grass]),
            Fixture.pokemon(id: 2, types: [.fire]),
            Fixture.pokemon(id: 3, types: [.grass, .poison]),
            Fixture.pokemon(id: 4, types: [.water])
        ))
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }

        viewModel.selectedTypes = [.grass]
        let grassOnly = Set(viewModel.visibleItems.map(\.id))
        #expect(grassOnly == [1, 3])

        // Only the dual-type card carries both, so adding a type can only ever remove cards.
        viewModel.selectedTypes = [.grass, .poison]
        #expect(viewModel.visibleItems.map(\.id) == [3])
        #expect(Set(viewModel.visibleItems.map(\.id)).isSubset(of: grassOnly))

        // A pair nothing carries matches nothing rather than falling back to either type.
        viewModel.selectedTypes = [.fire, .water]
        #expect(viewModel.visibleItems.isEmpty)
    }

    @Test("Caps the type selection at two, replacing the earliest")
    func capsTheTypeSelection() {
        let viewModel = Self.makeViewModel(service: Self.stubService())

        viewModel.toggleType(.grass)
        #expect(viewModel.selectedTypes == [.grass])

        viewModel.toggleType(.poison)
        #expect(viewModel.selectedTypes == [.grass, .poison])

        // Nothing carries three types, so the third tap replaces the first instead of joining it.
        viewModel.toggleType(.water)
        #expect(viewModel.selectedTypes == [.poison, .water])

        // Tapping a filled chip still clears just that one.
        viewModel.toggleType(.poison)
        #expect(viewModel.selectedTypes == [.water])

        viewModel.toggleType(.water)
        #expect(viewModel.selectedTypes.isEmpty)
    }

    @Test("Shows nothing while a filter has no matches yet")
    func showsNothingWhileFilterHasNoMatches() async {
        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1, types: [.grass]),
            Fixture.pokemon(id: 2, types: [.fire])
        ))
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        viewModel.selectedTypes = [.water]

        #expect(viewModel.visibleItems.isEmpty)
    }

    @Test("Closes the feed with the size of the dex, or of the filtered result")
    func paginationFooterNamesTheFilter() async {
        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1, types: [.grass]),
            Fixture.pokemon(id: 2, types: [.fire]),
            Fixture.pokemon(id: 3, types: [.grass, .poison]),
            Fixture.pokemon(id: 4, types: [.water])
        ))
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }

        // Unfiltered, the line is about the whole dex rather than the loaded pages.
        #expect(viewModel.totalCount == 4)
        #expect(viewModel.paginationFooterText == "That's all 4 Pokémon.")

        viewModel.selectedTypes = [.grass]
        #expect(viewModel.paginationFooterText == "That's all 2 Grass type Pokémon.")

        // Two types read as "and", named in chip order rather than the order they were tapped.
        viewModel.selectedTypes = [.poison, .grass]
        #expect(viewModel.selectedTypeSummary == "Grass and Poison")
        #expect(viewModel.paginationFooterText == "That's all 1 Grass and Poison type Pokémon.")
    }

    // MARK: Hydration

    @Test("Hydrates a slow page before paging ends, so a filter can still find its cards")
    func hydratesPagesThatOutliveTheirLoad() async {
        let secondPageURL = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=3&offset=3")!
        let firstPage = Fixture.page(
            (1...3).map { Fixture.feedItem(id: $0) },
            nextPageURL: secondPageURL
        )
        let secondPage = Fixture.page((4...6).map { Fixture.feedItem(id: $0) })

        // Only the last card of the first page carries the pair, so it is the one an abandoned
        // hydration loses.
        var details: [Int: Pokemon] = [:]
        for id in 1...6 {
            details[id] = id == 3
                ? Fixture.pokemon(id: id, types: [.grass, .poison])
                : Fixture.pokemon(id: id, types: [.fire])
        }

        let service = RecordingPokemonService(
            pageHandler: { request in
                request.followedURL == secondPageURL ? secondPage : firstPage
            },
            pokemonHandler: { identifier in
                // Slower than the pause between filter-driven page loads, so the second page lands
                // while this page's hydration is still in flight and cancels it.
                try await Task.sleep(for: .milliseconds(300))
                guard case .id(let id) = identifier, let pokemon = details[id] else {
                    throw PokeAPIError.notFound
                }
                return pokemon
            },
            speciesHandler: { _ in Fixture.species(id: 1) },
            typesHandler: { PokemonType.allCases }
        )

        let viewModel = PokedexFeedViewModel(
            service: service,
            teamStore: TeamStore(defaults: Fixture.scratchDefaults()),
            pageSize: 3
        )

        viewModel.selectedTypes = [.grass, .poison]
        await viewModel.start()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.hasMorePages == false)
        // The match is loaded but not yet resolved, so the feed must not claim there are none.
        #expect(viewModel.isAwaitingCardTypes)

        await waitUntil { viewModel.visibleItems.map(\.id) == [3] }
        #expect(viewModel.visibleItems.map(\.id) == [3])

        // The queue settles every card, including the ones behind the match.
        await waitUntil { !viewModel.isAwaitingCardTypes }
        #expect(!viewModel.isAwaitingCardTypes)
    }

    @Test("Keeps hydrating a page while the next page is already loading")
    func hydratesThroughBackToBackPages() async {
        let secondPageURL = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=3&offset=3")!
        let thirdPageURL = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=3&offset=6")!
        let firstPage = Fixture.page((1...3).map { Fixture.feedItem(id: $0) }, nextPageURL: secondPageURL)
        let secondPage = Fixture.page((4...6).map { Fixture.feedItem(id: $0) }, nextPageURL: thirdPageURL)
        let thirdPage = Fixture.page((7...9).map { Fixture.feedItem(id: $0) })

        let service = RecordingPokemonService(
            pageHandler: { request in
                switch request.followedURL {
                case secondPageURL: secondPage
                case thirdPageURL: thirdPage
                default: firstPage
                }
            },
            pokemonHandler: { identifier in
                // Slow enough that a page's details are always still arriving when the next page
                // lands, which is what a fast scroll looks like on the wire.
                try await Task.sleep(for: .milliseconds(40))
                guard case .id(let id) = identifier else { throw PokeAPIError.notFound }
                return Fixture.pokemon(id: id, types: [.fire])
            },
            speciesHandler: { _ in Fixture.species(id: 1) },
            typesHandler: { PokemonType.allCases }
        )

        let viewModel = PokedexFeedViewModel(
            service: service,
            teamStore: TeamStore(defaults: Fixture.scratchDefaults()),
            pageSize: 3
        )

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()

        // Paging has not finished, so nothing will come back for the first page: its hydration has to
        // survive on its own or those cards stay permanently bare — no types, and no artwork URL for
        // any image loader to fetch.
        #expect(viewModel.hasMorePages)
        #expect(viewModel.isAwaitingDetails(for: 1))

        await waitUntil { viewModel.items.prefix(3).allSatisfy { !$0.types.isEmpty } }
        #expect(viewModel.items.prefix(3).allSatisfy { !$0.types.isEmpty })

        // ...and the queue keeps going for the pages behind it.
        await viewModel.loadMoreIfNeeded()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }
        #expect(viewModel.items.allSatisfy { !$0.types.isEmpty })
    }

    @Test("Stops awaiting types when a card's detail request fails")
    func settlesWhenHydrationFails() async {
        // No details at all, so every detail request fails and leaves its card bare.
        let service = Self.stubService(details: [:])
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.hasMorePages == false)
        await waitUntil { !viewModel.isAwaitingCardTypes }
        // A failure has to settle the wait, or the empty state would stay suppressed forever and the
        // card would spin for an image that is never coming.
        #expect(!viewModel.isAwaitingCardTypes)
        #expect(!viewModel.isAwaitingDetails(for: 1))
        #expect(viewModel.items.allSatisfy { $0.types.isEmpty })
    }

    // MARK: Team

    @Test("Loads marked pokemon by id, never by filtering the loaded pages")
    func loadsTeamByIdentifier() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(3)
        store.toggle(9)

        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 3, name: "venusaur", types: [.grass]),
            Fixture.pokemon(id: 9, name: "blastoise", types: [.water])
        ))
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 2)

        await viewModel.start()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }
        let identifiersFetchedByTheFeed = Set(service.requestedPokemonIdentifiers)

        // Neither mark is on the pages the feed loaded, so both have to be asked for by id.
        await viewModel.loadTeam()

        let identifiersFetchedByTheTeam = service.requestedPokemonIdentifiers.filter {
            !identifiersFetchedByTheFeed.contains($0)
        }
        #expect(Set(identifiersFetchedByTheTeam) == [.id(3), .id(9)])
        #expect(viewModel.teamItems.map(\.id) == [3, 9])
        #expect(viewModel.teamItems.map(\.name) == ["venusaur", "blastoise"])
    }

    @Test("Does not refetch a team member it already holds")
    func doesNotRefetchHeldTeamMember() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(3)

        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 3, name: "venusaur", types: [.grass])
        ))
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 2)

        await viewModel.loadTeam()
        #expect(viewModel.teamItems.map(\.id) == [3])

        await viewModel.loadTeam()
        #expect(service.requestedPokemonIdentifiers.filter { $0 == .id(3) }.count == 1)
    }

    @Test("Sorts the team by dex number as members arrive out of order")
    func sortsTeamByDexNumber() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(9)
        store.toggle(3)
        store.toggle(6)

        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 3), Fixture.pokemon(id: 6), Fixture.pokemon(id: 9)
        ))
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 1)

        await viewModel.loadTeam()

        #expect(viewModel.teamItems.map(\.id) == [3, 6, 9])
    }

    @Test("Reports how many team members could not be loaded")
    func reportsFailedTeamMembers() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(1)
        store.toggle(2)

        let service = Self.stubService(details: [1: Fixture.pokemon(id: 1)])
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 1)

        await viewModel.loadTeam()

        #expect(viewModel.teamItems.map(\.id) == [1])
        #expect(viewModel.teamErrorMessage == "Couldn't load 1 team member.")
    }

    @Test("Pluralises the message when several team members fail")
    func pluralisesFailedTeamMembers() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(1)
        store.toggle(2)
        store.toggle(3)

        let service = Self.stubService(details: [1: Fixture.pokemon(id: 1)])
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 1)

        await viewModel.loadTeam()

        #expect(viewModel.teamErrorMessage == "Couldn't load 2 team members.")
    }

    @Test("Clears the error once the team loads cleanly")
    func clearsTeamError() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(1)

        let service = Self.stubService(details: [1: Fixture.pokemon(id: 1)])
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 1)

        await viewModel.loadTeam()
        #expect(viewModel.teamErrorMessage == nil)

        await viewModel.loadTeam()
        #expect(viewModel.teamErrorMessage == nil)
        #expect(service.requestedPokemonIdentifiers.filter { $0 == .id(1) }.count == 1)
    }

    @Test("Drops already-loaded members that are no longer marked")
    func dropsUnmarkedMembers() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(1)
        store.toggle(2)

        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1),
            Fixture.pokemon(id: 2)
        ))
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 1)

        await viewModel.loadTeam()
        #expect(viewModel.teamItems.map(\.id) == [1, 2])

        store.toggle(1)
        await viewModel.loadTeam()
        #expect(viewModel.teamItems.map(\.id) == [2])
    }

    @Test("Shows only the marked set while the team filter is on")
    func showsOnlyTheTeam() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(4)

        let service = Self.stubService(details: Self.details(
            Fixture.pokemon(id: 1, types: [.grass]),
            Fixture.pokemon(id: 2, types: [.fire]),
            Fixture.pokemon(id: 3, types: [.grass]),
            Fixture.pokemon(id: 4, types: [.water])
        ))
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        await waitUntil { viewModel.items.allSatisfy { !$0.types.isEmpty } }

        viewModel.toggleTeamFilter()
        #expect(viewModel.showsOnlyTeam)
        await waitUntil { viewModel.teamItems.count == 1 }
        #expect(viewModel.visibleItems.map(\.id) == [4])

        viewModel.selectedTypes = [.water]
        #expect(viewModel.visibleItems.map(\.id) == [4])

        viewModel.selectedTypes = [.grass]
        #expect(viewModel.visibleItems.isEmpty)

        viewModel.toggleTeamFilter()
        #expect(!viewModel.showsOnlyTeam)
        #expect(viewModel.visibleItems.map(\.id) == [1, 3])
    }

    // MARK: Refreshing

    @Test("Refresh throws the loaded pages away and starts over")
    func refreshStartsOver() async {
        let service = Self.stubService()
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        #expect(viewModel.items.count == 4)
        #expect(viewModel.loadedPageCount == 2)

        await viewModel.refresh()

        #expect(viewModel.items.map(\.id) == [1, 2])
        #expect(viewModel.loadedPageCount == 1)
        #expect(viewModel.hasMorePages)
        #expect(service.recordedPageRequests == [
            .offset(0, limit: 2),
            .following(secondPageURL),
            .offset(0, limit: 2)
        ] as [RecordingPokemonService.PageRequest])
    }

    @Test("Refresh reloads the team while the team filter is on")
    func refreshReloadsTeam() async {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        store.toggle(3)

        let service = Self.stubService(details: [3: Fixture.pokemon(id: 3, name: "venusaur")])
        let viewModel = PokedexFeedViewModel(service: service, teamStore: store, pageSize: 2)

        viewModel.showsOnlyTeam = true
        await viewModel.refresh()

        #expect(viewModel.teamItems.map(\.name) == ["venusaur"])
        #expect(viewModel.phase == .idle)
        #expect(service.count(of: .page) == 0)
    }

    // MARK: Failure

    @Test("Fails the whole screen when the first page cannot load")
    func failsFirstPage() async {
        let service = RecordingPokemonService(pageHandler: { _ in
            throw PokeAPIError.transport(description: "offline")
        })
        let viewModel = Self.makeViewModel(service: service, pageSize: 2)

        await viewModel.start()

        #expect(viewModel.phase == .failed(message: "Check your connection and try again."))
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.nextPageErrorMessage == nil)
    }

    @Test("Keeps the pages it has when a later page fails")
    func keepsPagesOnLaterFailure() async {
        let service = RecordingPokemonService(pageHandler: { (request: RecordingPokemonService.PageRequest) in
            guard request.followedURL == nil else { throw PokeAPIError.httpStatus(code: 500) }
            return Fixture.page([Fixture.feedItem(id: 1)], nextPageURL: secondPageURL, totalCount: 2)
        })
        let viewModel = Self.makeViewModel(service: service, pageSize: 1)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.items.map(\.id) == [1])
        #expect(viewModel.nextPageErrorMessage == "Something went wrong while loading Pokémon data.")
    }

    @Test("Retries the first page when nothing is loaded, and the next page when something is")
    func retriesTheRightPage() async {
        let attempts = AttemptCounter()
        let service = RecordingPokemonService(pageHandler: { (_: RecordingPokemonService.PageRequest) in
            guard attempts.next() > 1 else { throw PokeAPIError.transport(description: "offline") }
            return Fixture.page([Fixture.feedItem(id: 1)], totalCount: 1)
        })
        let viewModel = Self.makeViewModel(service: service, pageSize: 1)

        await viewModel.start()
        #expect(viewModel.phase == .failed(message: "Check your connection and try again."))

        await viewModel.retry()
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.items.map(\.id) == [1])
        #expect(viewModel.nextPageErrorMessage == nil)
    }

    @Test("Clears the inline error when retrying a later page")
    func clearsInlineErrorOnRetry() async {
        let attempts = AttemptCounter()
        let service = RecordingPokemonService(pageHandler: { (request: RecordingPokemonService.PageRequest) in
            guard request.followedURL != nil else {
                return Fixture.page([Fixture.feedItem(id: 1)], nextPageURL: secondPageURL, totalCount: 2)
            }
            guard attempts.next() > 1 else { throw PokeAPIError.httpStatus(code: 503) }
            return Fixture.page([Fixture.feedItem(id: 2)], totalCount: 2)
        })
        let viewModel = Self.makeViewModel(service: service, pageSize: 1)

        await viewModel.start()
        await viewModel.loadMoreIfNeeded()
        #expect(viewModel.nextPageErrorMessage != nil)

        await viewModel.retry()

        #expect(viewModel.nextPageErrorMessage == nil)
        #expect(viewModel.items.map(\.id) == [1, 2])
    }

    @Test("Says nothing when the request was cancelled rather than failed")
    func staysQuietOnCancellation() async {
        let service = RecordingPokemonService(pageHandler: { _ in throw CancellationError() })
        let viewModel = Self.makeViewModel(service: service, pageSize: 1)

        await viewModel.start()

        #expect(viewModel.phase == .loadingFirstPage)
        #expect(viewModel.nextPageErrorMessage == nil)
    }

    @Test("Moves to the first-page phase while starting")
    func movesToFirstPagePhase() async {
        let viewModel = Self.makeViewModel(service: Self.stubService(), pageSize: 2)

        let start = Task { await viewModel.start() }
        await start.value

        #expect(viewModel.phase == .loaded)
    }
}

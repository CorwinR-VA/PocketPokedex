import Foundation
import Testing
@testable import PocketPokedex

@Suite("Pokemon types")
struct PokemonTypeTests {
    @Test("Models the eighteen elemental types")
    func modelsEighteenTypes() {
        #expect(PokemonType.allCases.count == 18)
        #expect(PokemonType.allCases.first == .normal)
        #expect(PokemonType.allCases.last == .fairy)
    }

    @Test("Resolves a type from the API's lowercase slug")
    func resolvesAPIName() {
        #expect(PokemonType(apiName: "fire") == .fire)
        #expect(PokemonType(apiName: "FIRE") == .fire)
        #expect(PokemonType(apiName: "stellar") == nil)
        #expect(PokemonType(apiName: "") == nil)
    }

    @Test("Displays a type name in title case")
    func displaysName() {
        #expect(PokemonType.grass.name == "Grass")
        #expect(PokemonType.dark.name == "Dark")
    }

    @Test("Uses its raw value as its identity")
    func usesRawValueAsIdentity() {
        #expect(PokemonType.fire.id == "fire")
    }
}

@Suite("Stat kinds")
struct StatKindTests {
    @Test("Models the six base stats as the API spells them")
    func modelsSixStats() {
        #expect(StatKind.allCases.count == 6)
        #expect(StatKind.allCases.map(\.rawValue) == [
            "hp", "attack", "defense", "special-attack", "special-defense", "speed"
        ])
    }

    @Test("Displays each stat with the app's own abbreviation")
    func displaysNames() {
        #expect(StatKind.hitPoints.displayName == "HP")
        #expect(StatKind.attack.displayName == "Attack")
        #expect(StatKind.defense.displayName == "Defense")
        #expect(StatKind.specialAttack.displayName == "Sp. Atk")
        #expect(StatKind.specialDefense.displayName == "Sp. Def")
        #expect(StatKind.speed.displayName == "Speed")
    }
}

@Suite("Pokemon model")
struct PokemonModelTests {
    @Test("Sums the base stats into a total")
    func sumsStats() {
        let pokemon = Fixture.pokemon(id: 1, stats: [
            PokemonStat(kind: .hitPoints, baseValue: 45),
            PokemonStat(kind: .attack, baseValue: 49),
            PokemonStat(kind: .speed, baseValue: 45)
        ])

        #expect(pokemon.totalStats == 139)
    }

    @Test("Reports a zero total for no stats")
    func reportsZeroTotal() {
        #expect(Fixture.pokemon(id: 1, stats: []).totalStats == 0)
    }

    @Test("Displays a slug name as a readable name")
    func displaysName() {
        #expect(Fixture.pokemon(id: 122, name: "mr-mime").displayName == "Mr Mime")
    }
}

@Suite("Pokemon feed item")
struct PokemonFeedItemTests {
    @Test("Formats its id as a dex number")
    func formatsDexNumber() {
        #expect(Fixture.feedItem(id: 1).dexNumber == "#001")
        #expect(Fixture.feedItem(id: 1_025).dexNumber == "#1025")
    }

    @Test("Starts a card with no types and no artwork")
    func startsBare() {
        let item = PokemonFeedItem(id: 25, name: "pikachu")
        #expect(item.types.isEmpty)
        #expect(item.artworkURL == nil)
    }

    @Test("Builds a card from a loaded pokemon")
    func buildsFromPokemon() {
        let artwork = URL(string: "https://art.test/official/25.png")!
        let pokemon = Fixture.pokemon(
            id: 25,
            name: "pikachu",
            types: [.electric],
            artworkURL: artwork,
            thumbnailURL: URL(string: "https://art.test/front/25.png")
        )

        let item = PokemonFeedItem(pokemon: pokemon)

        #expect(item.id == 25)
        #expect(item.name == "pikachu")
        #expect(item.displayName == "Pikachu")
        #expect(item.types == [.electric])
        #expect(item.artworkURL == artwork)
    }

    @Test("Falls back to the thumbnail when a pokemon has no official artwork")
    func fallsBackToThumbnail() {
        let thumbnail = URL(string: "https://art.test/front/25.png")!
        let pokemon = Fixture.pokemon(id: 25, artworkURL: nil, thumbnailURL: thumbnail)

        #expect(PokemonFeedItem(pokemon: pokemon).artworkURL == thumbnail)
    }

    @Test("Carries no artwork when a pokemon has none")
    func carriesNoArtwork() {
        let pokemon = Fixture.pokemon(id: 25, artworkURL: nil, thumbnailURL: nil)
        #expect(PokemonFeedItem(pokemon: pokemon).artworkURL == nil)
    }

    @Test("Hydrating a card is what makes it differ from the bare one")
    func hydrationChangesIdentity() {
        let bare = PokemonFeedItem(id: 1, name: "bulbasaur")
        let hydrated = PokemonFeedItem(pokemon: Fixture.pokemon(id: 1, name: "bulbasaur"))

        #expect(bare != hydrated)
    }
}

@Suite("Detail tab")
struct PokemonDetailTabTests {
    @Test("Offers the three tabs in the order the tab bar shows them")
    func offersThreeTabs() {
        #expect(PokemonDetailTab.allCases == [.stats, .moves, .about])
    }

    @Test("Titles each tab")
    func titlesTabs() {
        #expect(PokemonDetailTab.stats.title == "Stats")
        #expect(PokemonDetailTab.moves.title == "Moves")
        #expect(PokemonDetailTab.about.title == "About")
    }
}

@Suite("App dependencies")
struct AppDependenciesTests {
    @Test("Builds a feed view model over the graph it was given")
    @MainActor
    func buildsFeedViewModel() {
        let service = RecordingPokemonService()
        let dependencies = AppDependencies(
            pokemonService: service,
            imageCache: PreviewImageCache(),
            teamStore: TeamStore(defaults: Fixture.scratchDefaults())
        )

        let viewModel = dependencies.makeFeedViewModel()
        #expect(viewModel.phase == .idle)
        #expect(viewModel.items.isEmpty)
    }

    @Test("Builds a detail view model that knows the card it was opened from")
    @MainActor
    func buildsDetailViewModel() {
        let item = Fixture.feedItem(id: 25, name: "pikachu", types: [.electric])
        let dependencies = AppDependencies(
            pokemonService: RecordingPokemonService(),
            imageCache: PreviewImageCache(),
            teamStore: TeamStore(defaults: Fixture.scratchDefaults())
        )

        let viewModel = dependencies.makeDetailViewModel(for: item)
        #expect(viewModel.item == item)
        #expect(viewModel.displayName == "Pikachu")
        #expect(viewModel.dexNumber == "#025")
        #expect(viewModel.types == [.electric])
    }

    @Test("Shares one team store across the view models it builds")
    @MainActor
    func sharesTeamStore() {
        let dependencies = AppDependencies(
            pokemonService: RecordingPokemonService(),
            imageCache: PreviewImageCache(),
            teamStore: TeamStore(defaults: Fixture.scratchDefaults())
        )

        dependencies.teamStore.toggle(25)
        #expect(dependencies.makeFeedViewModel().teamItems.isEmpty)
        #expect(dependencies.teamStore.contains(25))
    }

    @Test("Offers a preview graph that needs no network")
    @MainActor
    func offersPreviewGraph() async throws {
        let dependencies = AppDependencies.preview
        let page = try await dependencies.pokemonService.pokemonPage(limit: 20, offset: 0)

        #expect(page.items.count == 20)
    }
}

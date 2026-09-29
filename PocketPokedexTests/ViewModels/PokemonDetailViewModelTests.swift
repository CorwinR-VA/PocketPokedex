import Foundation
import Testing
@testable import PocketPokedex

@Suite("Detail view model")
@MainActor
struct PokemonDetailViewModelTests {
    private static func stubService(
        pokemon: Pokemon? = nil,
        species: PokemonSpecies? = nil,
        evolution: [EvolutionStage] = [],
        evolutionError: (any Error)? = nil
    ) -> RecordingPokemonService {
        RecordingPokemonService(
            pokemonHandler: { _ in
                guard let pokemon else { throw PokeAPIError.notFound }
                return pokemon
            },
            speciesHandler: { _ in
                guard let species else { throw PokeAPIError.notFound }
                return species
            },
            evolutionHandler: { _ in
                if let evolutionError { throw evolutionError }
                return evolution
            }
        )
    }

    @Test("Shows the card it was opened from before anything loads")
    func showsFeedItemFirst() {
        let item = Fixture.feedItem(
            id: 1,
            name: "bulbasaur",
            types: [.grass, .poison],
            artworkURL: URL(string: "https://art.test/card/1.png")
        )
        let viewModel = PokemonDetailViewModel(item: item, service: Self.stubService())

        #expect(viewModel.phase == .loading)
        #expect(viewModel.selectedTab == .stats)
        #expect(viewModel.displayName == "Bulbasaur")
        #expect(viewModel.dexNumber == "#001")
        #expect(viewModel.types == [.grass, .poison])
        #expect(viewModel.artworkURL?.absoluteString == "https://art.test/card/1.png")
        #expect(viewModel.heightText == MeasurementFormat.placeholder)
        #expect(viewModel.weightText == MeasurementFormat.placeholder)
        #expect(viewModel.abilityText == MeasurementFormat.placeholder)
        #expect(viewModel.hiddenAbilityText == MeasurementFormat.placeholder)
        #expect(viewModel.evolutionChain.isEmpty)
    }

    @Test("Loads the pokemon, the species and then the evolution chain")
    func loadsEverything() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, name: "bulbasaur", types: [.grass, .poison]),
            species: Fixture.species(id: 1, evolutionChainIdentifier: 7),
            evolution: [Fixture.evolutionStage(id: 1, name: "bulbasaur")]
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.pokemon?.id == 1)
        #expect(viewModel.species?.id == 1)
        #expect(viewModel.evolutionChain.map(\.id) == [1])
        #expect(service.count(of: .pokemon) == 1)
        #expect(service.count(of: .species) == 1)
        #expect(service.count(of: .evolutionChain) == 1)
    }

    @Test("Prefers the loaded pokemon's own name, artwork and types over the card's")
    func prefersLoadedValues() async {
        let loadedArtwork = URL(string: "https://art.test/official/1.png")!
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, name: "bulbasaur", types: [.grass], artworkURL: loadedArtwork),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(
            item: Fixture.feedItem(id: 1, name: "bulbasaur", types: [.grass, .poison]),
            service: service
        )

        await viewModel.load()

        #expect(viewModel.displayName == "Bulbasaur")
        #expect(viewModel.artworkURL == loadedArtwork)
        #expect(viewModel.types == [.grass])
    }

    @Test("Falls back to the card's types when the loaded pokemon has none")
    func fallsBackToCardTypes() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, types: []),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(
            item: Fixture.feedItem(id: 1, types: [.grass, .poison]),
            service: service
        )

        await viewModel.load()

        #expect(viewModel.types == [.grass, .poison])
    }

    @Test("Formats the height and weight it loaded")
    func formatsMeasurements() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, heightInMetres: 0.7, weightInKilograms: 6.9),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.heightText == "\(LocalizedNumber.text(0.7)) m")
        #expect(viewModel.weightText == "\(LocalizedNumber.text(6.9)) kg")
    }

    @Test("Lists the visible abilities and gives the hidden one its own line")
    func splitsAbilities() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, abilities: [
                PokemonAbility(name: "overgrow", isHidden: false),
                PokemonAbility(name: "solar-power", isHidden: false),
                PokemonAbility(name: "chlorophyll", isHidden: true)
            ]),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.abilityText == "Overgrow, Solar Power")
        #expect(viewModel.hiddenAbilityText == "Chlorophyll")
    }

    @Test("Says None when a pokemon has no hidden ability")
    func reportsNoHiddenAbility() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, abilities: [PokemonAbility(name: "overgrow", isHidden: false)]),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.hiddenAbilityText == "None")
        #expect(viewModel.abilityText == "Overgrow")
    }

    @Test("Shows a placeholder when a pokemon has no visible abilities")
    func reportsNoVisibleAbilities() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1, abilities: [PokemonAbility(name: "chlorophyll", isHidden: true)]),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.abilityText == MeasurementFormat.placeholder)
        #expect(viewModel.hiddenAbilityText == "Chlorophyll")
    }

    @Test("Follows the species' evolution chain link")
    func followsEvolutionChainLink() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1),
            species: Fixture.species(id: 1, evolutionChainIdentifier: 42),
            evolution: [Fixture.evolutionStage(id: 1, name: "bulbasaur")]
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(service.requestedEvolutionChainIdentifiers == [42])
        #expect(viewModel.evolutionChain.map(\.id) == [1])
    }

    @Test("Skips the chain request when the species names no chain")
    func skipsChainWithoutIdentifier() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1),
            species: Fixture.species(id: 1, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(service.count(of: .evolutionChain) == 0)
        #expect(viewModel.evolutionChain.isEmpty)
    }

    @Test("Keeps the screen usable when the evolution chain fails, since it decorates one tab")
    func survivesChainFailure() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 1),
            species: Fixture.species(id: 1, evolutionChainIdentifier: 3),
            evolutionError: PokeAPIError.httpStatus(code: 500)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.evolutionChain.isEmpty)
    }

    @Test("Fails the screen when the pokemon or the species cannot load")
    func failsOnMissingData() async {
        let missingPokemon = PokemonDetailViewModel(
            item: Fixture.feedItem(id: 1),
            service: Self.stubService(species: Fixture.species(id: 1))
        )
        await missingPokemon.load()
        #expect(missingPokemon.phase == .failed(message: "We couldn't find that Pokémon."))

        let missingSpecies = PokemonDetailViewModel(
            item: Fixture.feedItem(id: 1),
            service: Self.stubService(pokemon: Fixture.pokemon(id: 1))
        )
        await missingSpecies.load()
        #expect(missingSpecies.phase == .failed(message: "We couldn't find that Pokémon."))
    }

    @Test("Reports a transport failure with the message the user can act on")
    func reportsTransportFailure() async {
        let service = RecordingPokemonService(pokemonHandler: { _ in
            throw PokeAPIError.transport(description: "offline")
        })
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.phase == .failed(message: "Check your connection and try again."))
    }

    @Test("Stays in the loading phase when the load was cancelled rather than failed")
    func staysLoadingOnCancellation() async {
        let service = RecordingPokemonService(pokemonHandler: { _ in throw CancellationError() })
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: service)

        await viewModel.load()

        #expect(viewModel.phase == .loading)
    }

    @Test("Asks the service for the id the card carries")
    func requestsTheCardsIdentifier() async {
        let service = Self.stubService(
            pokemon: Fixture.pokemon(id: 25),
            species: Fixture.species(id: 25, evolutionChainIdentifier: nil)
        )
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 25), service: service)

        await viewModel.load()

        #expect(service.requestedPokemonIdentifiers == [.id(25)])
    }

    @Test("Every tab is reachable, and stats is the one it opens on")
    func selectsTabs() {
        let viewModel = PokemonDetailViewModel(item: Fixture.feedItem(id: 1), service: Self.stubService())

        #expect(viewModel.selectedTab == .stats)
        viewModel.selectedTab = .moves
        #expect(viewModel.selectedTab == .moves)
        viewModel.selectedTab = .about
        #expect(viewModel.selectedTab == .about)
    }
}

@Suite("Team store")
@MainActor
struct TeamStoreTests {
    @Test("Starts empty on a fresh install")
    func startsEmpty() {
        let store = TeamStore(defaults: Fixture.scratchDefaults())

        #expect(store.count == 0)
        #expect(store.memberIdentifiers.isEmpty)
        #expect(!store.contains(1))
    }

    @Test("Marks a pokemon and reports it as a member")
    func marksPokemon() {
        let store = TeamStore(defaults: Fixture.scratchDefaults())

        store.toggle(25)

        #expect(store.contains(25))
        #expect(store.count == 1)
        #expect(store.memberIdentifiers == [25])
    }

    @Test("Unmarks a pokemon that is already a member")
    func unmarksPokemon() {
        let store = TeamStore(defaults: Fixture.scratchDefaults())

        store.toggle(25)
        store.toggle(25)

        #expect(!store.contains(25))
        #expect(store.count == 0)
    }

    @Test("Toggles one member without touching the others")
    func togglesIndependently() {
        let store = TeamStore(defaults: Fixture.scratchDefaults())

        store.toggle(1)
        store.toggle(4)
        store.toggle(7)
        store.toggle(4)

        #expect(store.memberIdentifiers == [1, 7])
        #expect(store.count == 2)
    }

    @Test("Survives a relaunch by reading its members back from storage")
    func persistsAcrossLaunches() {
        let defaults = Fixture.scratchDefaults()
        let store = TeamStore(defaults: defaults)

        store.toggle(25)
        store.toggle(1)

        let relaunched = TeamStore(defaults: defaults)
        #expect(relaunched.memberIdentifiers == [25, 1])
        #expect(relaunched.contains(25))
    }

    @Test("Persists a removal too")
    func persistsRemovals() {
        let defaults = Fixture.scratchDefaults()
        let store = TeamStore(defaults: defaults)

        store.toggle(25)
        store.toggle(25)

        #expect(TeamStore(defaults: defaults).memberIdentifiers.isEmpty)
    }

    @Test("Keeps two stores on different suites apart, so a preview cannot edit a real team")
    func keepsSuitesApart() {
        let store = TeamStore(defaults: Fixture.scratchDefaults())
        let other = TeamStore(defaults: Fixture.scratchDefaults())

        store.toggle(25)

        #expect(other.count == 0)
    }

    @Test("Stores its members under the documented defaults key")
    func usesDocumentedKey() {
        let defaults = Fixture.scratchDefaults()
        let store = TeamStore(defaults: defaults)

        store.toggle(25)

        let stored = defaults.array(forKey: "pokedex.team.memberIDs") as? [Int]
        #expect(stored == [25])
    }

    @Test("Ignores a stored value that is not a list of ids")
    func ignoresCorruptStorage() {
        let defaults = Fixture.scratchDefaults()
        defaults.set("not a list", forKey: "pokedex.team.memberIDs")

        #expect(TeamStore(defaults: defaults).count == 0)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class PokemonDetailViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(message: String)
    }

    let item: PokemonFeedItem

    var selectedTab: PokemonDetailTab = .stats
    private(set) var phase: Phase = .loading
    private(set) var pokemon: Pokemon?
    private(set) var species: PokemonSpecies?
    private(set) var evolutionLines: [EvolutionLine] = []

    private let service: any PokemonService

    init(item: PokemonFeedItem, service: any PokemonService) {
        self.item = item
        self.service = service
    }

    var dexNumber: String { item.dexNumber }

    var displayName: String { pokemon?.displayName ?? item.displayName }

    var artworkURL: URL? { pokemon?.artworkURL ?? item.artworkURL }

    var types: [PokemonType] {
        guard let pokemon, !pokemon.types.isEmpty else { return item.types }
        return pokemon.types
    }

    var heightText: String { MeasurementFormat.height(pokemon?.heightInMetres) }
    var weightText: String { MeasurementFormat.weight(pokemon?.weightInKilograms) }

    var abilityText: String {
        guard let pokemon else { return MeasurementFormat.placeholder }
        let visible = pokemon.abilities.filter { !$0.isHidden }.map(\.displayName)
        return visible.isEmpty ? MeasurementFormat.placeholder : visible.joined(separator: ", ")
    }

    var hiddenAbilityText: String {
        guard let pokemon else { return MeasurementFormat.placeholder }
        let hidden = pokemon.abilities.filter(\.isHidden).map(\.displayName)
        return hidden.isEmpty ? "None" : hidden.joined(separator: ", ")
    }

    func load() async {
        phase = .loading

        do {
            async let pokemonRequest = service.pokemon(.id(item.id))
            async let speciesRequest = service.species(.id(item.id))
            let (pokemon, species) = try await (pokemonRequest, speciesRequest)

            self.pokemon = pokemon
            self.species = species
            phase = .loaded
        } catch {
            let apiError = PokeAPIError.from(error)
            guard apiError != .cancelled else { return }
            phase = .failed(message: apiError.userFacingMessage)
            return
        }

        await loadEvolutionChain()
    }

    private func loadEvolutionChain() async {
        guard let evolutionChainIdentifier = species?.evolutionChainIdentifier else { return }
        evolutionLines = (try? await service.evolutionChain(id: evolutionChainIdentifier)) ?? []
    }
}

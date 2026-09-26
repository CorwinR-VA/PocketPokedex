import Foundation

nonisolated struct EvolutionStage: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let artworkURL: URL?
    let types: [PokemonType]
    let requirement: String?

    var displayName: String { name.pokemonDisplayName }
}

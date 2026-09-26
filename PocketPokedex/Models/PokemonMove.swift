import Foundation

nonisolated struct PokemonMove: Identifiable, Hashable, Sendable {
    let name: String
    let level: Int

    var id: String { name }
    var displayName: String { name.pokemonDisplayName }
}

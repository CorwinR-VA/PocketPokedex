import Foundation

nonisolated struct PokemonAbility: Identifiable, Hashable, Sendable {
    let name: String
    let isHidden: Bool

    var id: String { name }
    var displayName: String { name.pokemonDisplayName }
}

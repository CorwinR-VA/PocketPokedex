import Foundation

nonisolated struct Pokemon: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let types: [PokemonType]
    let artworkURL: URL?
    let thumbnailURL: URL?
    let heightInMetres: Double
    let weightInKilograms: Double
    let baseExperience: Int?
    let abilities: [PokemonAbility]
    let stats: [PokemonStat]
    let moves: [PokemonMove]

    var displayName: String { name.pokemonDisplayName }

    var totalStats: Int { stats.reduce(0) { $0 + $1.baseValue } }
}

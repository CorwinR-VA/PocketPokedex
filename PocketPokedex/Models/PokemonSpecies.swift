import Foundation

nonisolated struct PokemonSpecies: Identifiable, Hashable, Sendable {
    let id: Int
    let genus: String?
    let flavorText: String?
    let captureRate: Int
    let growthRate: String?
    let evolutionChainIdentifier: Int?
}

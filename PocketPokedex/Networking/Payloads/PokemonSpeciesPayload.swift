import Foundation

nonisolated struct PokemonSpeciesPayload: Decodable, Sendable {
    let id: Int
    let captureRate: Int
    let growthRate: NamedResourcePayload?
    let genera: [GenusPayload]
    let flavorTextEntries: [FlavorTextEntryPayload]
    let evolutionChain: EvolutionChainReferencePayload?
}

nonisolated struct GenusPayload: Decodable, Sendable {
    let genus: String
    let language: NamedResourcePayload
}

nonisolated struct FlavorTextEntryPayload: Decodable, Sendable {
    let flavorText: String
    let language: NamedResourcePayload
}

nonisolated struct EvolutionChainReferencePayload: Decodable, Sendable {
    let url: URL
}

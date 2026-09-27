import Foundation

nonisolated struct EvolutionChainPayload: Decodable, Sendable {
    let id: Int
    let chain: EvolutionLinkPayload
}

nonisolated struct EvolutionLinkPayload: Decodable, Sendable {
    let species: NamedResourcePayload
    let evolutionDetails: [EvolutionDetailPayload]
    let evolvesTo: [EvolutionLinkPayload]
}

nonisolated struct EvolutionDetailPayload: Decodable, Sendable {
    let trigger: NamedResourcePayload?
    let minLevel: Int?
    let minHappiness: Int?
    let minAffection: Int?
    let item: NamedResourcePayload?
    let heldItem: NamedResourcePayload?
    let knownMove: NamedResourcePayload?
    let location: NamedResourcePayload?
    let minBeauty: Int?
    let relativePhysicalStats: Int?
}

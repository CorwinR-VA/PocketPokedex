import Foundation

nonisolated struct PokemonPayload: Decodable, Sendable {
    let id: Int
    let name: String
    let baseExperience: Int?
    let height: Int
    let weight: Int
    let sprites: PokemonSpritesPayload
    let types: [PokemonTypeSlotPayload]
    let stats: [PokemonStatPayload]
    let abilities: [PokemonAbilityPayload]
    let moves: [PokemonMovePayload]
}

nonisolated struct PokemonSpritesPayload: Decodable, Sendable {
    let frontDefault: URL?
    let other: PokemonSpritesOtherPayload?
}

nonisolated struct PokemonSpritesOtherPayload: Decodable, Sendable {
    let officialArtwork: PokemonArtworkPayload?
    let home: PokemonArtworkPayload?

    private enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
        case home
    }
}

nonisolated struct PokemonArtworkPayload: Decodable, Sendable {
    let frontDefault: URL?
}

nonisolated struct PokemonTypeSlotPayload: Decodable, Sendable {
    let slot: Int
    let type: NamedResourcePayload
}

nonisolated struct PokemonStatPayload: Decodable, Sendable {
    let baseStat: Int
    let stat: NamedResourcePayload
}

nonisolated struct PokemonAbilityPayload: Decodable, Sendable {
    let ability: NamedResourcePayload
    let isHidden: Bool
    let slot: Int
}

nonisolated struct PokemonMovePayload: Decodable, Sendable {
    let move: NamedResourcePayload
    let versionGroupDetails: [MoveVersionGroupDetailPayload]
}

nonisolated struct MoveVersionGroupDetailPayload: Decodable, Sendable {
    let levelLearnedAt: Int
    let moveLearnMethod: NamedResourcePayload
}

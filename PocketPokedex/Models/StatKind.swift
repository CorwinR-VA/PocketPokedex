import Foundation

nonisolated enum StatKind: String, CaseIterable, Sendable {
    case hitPoints = "hp"
    case attack
    case defense
    case specialAttack = "special-attack"
    case specialDefense = "special-defense"
    case speed

    var displayName: String {
        switch self {
        case .hitPoints: "HP"
        case .attack: "Attack"
        case .defense: "Defense"
        case .specialAttack: "Sp. Atk"
        case .specialDefense: "Sp. Def"
        case .speed: "Speed"
        }
    }

    static let maximumBaseValue: Double = 255
}

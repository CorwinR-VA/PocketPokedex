import SwiftUI

nonisolated enum PokemonGame: String, CaseIterable, Sendable, Identifiable {
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case yellow = "Yellow"
    case gold = "Gold"
    case silver = "Silver"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case emerald = "Emerald"
    case black = "Black"
    case white = "White"
    case scarlet = "Scarlet"
    case violet = "Violet"

    var id: String { rawValue }

    var title: String { rawValue }

    var motif: PokedexMotif {
        switch self {
        case .red: .pokeball
        case .green: .sprout
        case .blue: .droplet
        case .yellow: .bolt
        case .gold: .star
        case .silver: .crescent
        case .ruby: .gem
        case .sapphire: .wave
        case .emerald: .leaf
        case .black: .snowflake
        case .white: .sun
        case .scarlet: .flame
        case .violet: .blossom
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .red: Color(.gameRed)
        case .green: Color(.gameGreen)
        case .blue: Color(.gameBlue)
        case .yellow: Color(.gameYellow)
        case .gold: Color(.gameGold)
        case .silver: Color(.gameSilver)
        case .ruby: Color(.gameRuby)
        case .sapphire: Color(.gameSapphire)
        case .emerald: Color(.gameEmerald)
        case .black: Color(.gameBlack)
        case .white: Color(.gameWhite)
        case .scarlet: Color(.gameScarlet)
        case .violet: Color(.gameViolet)
        }
    }

    @MainActor
    var watermark: Color {
        switch self {
        case .red: Color(.gameRedWatermark)
        case .green: Color(.gameGreenWatermark)
        case .blue: Color(.gameBlueWatermark)
        case .yellow: Color(.gameYellowWatermark)
        case .gold: Color(.gameGoldWatermark)
        case .silver: Color(.gameSilverWatermark)
        case .ruby: Color(.gameRubyWatermark)
        case .sapphire: Color(.gameSapphireWatermark)
        case .emerald: Color(.gameEmeraldWatermark)
        case .black: Color(.gameBlackWatermark)
        case .white: Color(.gameWhiteWatermark)
        case .scarlet: Color(.gameScarletWatermark)
        case .violet: Color(.gameVioletWatermark)
        }
    }
}

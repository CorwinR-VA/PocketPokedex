import SwiftUI

enum PokedexBackgroundTheme: Hashable, Identifiable, CaseIterable {
    case standard
    case game(PokemonGame)

    static var allCases: [PokedexBackgroundTheme] {
        [.standard] + PokemonGame.allCases.map(PokedexBackgroundTheme.game)
    }

    var id: String { title }

    var title: String {
        switch self {
        case .standard: "Default"
        case .game(let game): game.title
        }
    }

    struct Watermark {
        let motif: PokedexMotif
        let tint: Color
    }

    var wash: Color? {
        switch self {
        case .standard: nil
        case .game(let game): game.color.opacity(0.12)
        }
    }

    var watermark: Watermark? {
        switch self {
        case .standard: nil
        case .game(let game): Watermark(motif: game.motif, tint: game.watermark.opacity(0.16))
        }
    }
}

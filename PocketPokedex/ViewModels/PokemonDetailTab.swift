import Foundation

enum PokemonDetailTab: CaseIterable, Identifiable, Hashable, Sendable {
    case stats
    case moves
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .stats: "Stats"
        case .moves: "Moves"
        case .about: "About"
        }
    }
}

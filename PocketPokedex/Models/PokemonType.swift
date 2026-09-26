import SwiftUI

nonisolated enum PokemonType: String, CaseIterable, Sendable, Identifiable {
    case normal, fire, water, electric, grass, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    var id: String { rawValue }

    var name: String { rawValue.pokemonDisplayName }

    init?(apiName: String) {
        self.init(rawValue: apiName.lowercased())
    }

    @MainActor
    var color: Color {
        switch self {
        case .normal: Color(.normalType)
        case .fire: Color(.fireType)
        case .water: Color(.waterType)
        case .electric: Color(.electricType)
        case .grass: Color(.grassType)
        case .ice: Color(.ice)
        case .fighting: Color(.fighting)
        case .poison: Color(.poisonType)
        case .ground: Color(.ground)
        case .flying: Color(.flying)
        case .psychic: Color(.psychic)
        case .bug: Color(.bug)
        case .rock: Color(.rock)
        case .ghost: Color(.ghost)
        case .dragon: Color(.dragon)
        case .dark: Color(.darkType)
        case .steel: Color(.steel)
        case .fairy: Color(.fairyType)
        }
    }
}

import SwiftUI

struct TypeBadge: View {
    let type: PokemonType

    var body: some View {
        Text(type.rawValue)
            .font(.pokedexLabelStrong)
            .foregroundStyle(PokedexTheme.onAccent)
            .lineLimit(1)
            .padding(.horizontal, PokedexTheme.Metrics.badgeHorizontalPadding)
            .frame(height: PokedexTheme.Metrics.badgeHeight)
            .background(type.color, in: .capsule)
            .overlay { Capsule().stroke(PokedexTheme.onAccent, lineWidth: 1) }
            .accessibilityLabel(type.name)
    }
}

#Preview {
    HStack(spacing: 4) {
        ForEach(PokemonType.allCases.prefix(6)) { TypeBadge(type: $0) }
    }
    .padding()
}

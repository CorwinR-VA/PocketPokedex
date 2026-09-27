import SwiftUI

struct TypeChip: View {
    let type: PokemonType
    var isFilled: Bool
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isFilled ? [.isSelected] : [])
        } else {
            label
        }
    }

    private var label: some View {
        Text(type.name)
            .font(.pokedexLabelStrong)
            .foregroundStyle(isFilled ? PokedexTheme.onAccent : PokedexTheme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, PokedexTheme.Metrics.chipHorizontalPadding)
            .frame(height: PokedexTheme.Metrics.chipHeight)
            .background {
                if isFilled {
                    Capsule().fill(type.color)
                } else {
                    Capsule()
                        .fill(PokedexTheme.surface)
                        .stroke(type.color, lineWidth: 1)
                }
            }
            .contentShape(.capsule)
    }
}

#Preview {
    VStack(spacing: 12) {
        TypeChip(type: .grass, isFilled: true)
        TypeChip(type: .fire, isFilled: false) {}
    }
    .padding()
    .background(PokedexTheme.canvas)
}

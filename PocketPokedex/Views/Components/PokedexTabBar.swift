import SwiftUI

struct PokedexTabBar<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    select(option)
                } label: {
                    Text(title(option))
                        .font(.pokedexLabel)
                        .foregroundStyle(isSelected(option) ? PokedexTheme.textPrimary : PokedexTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if isSelected(option) {
                                RoundedRectangle(cornerRadius: PokedexTheme.Metrics.tabThumbCornerRadius)
                                    .fill(PokedexTheme.surface)
                                    .pokedexCardShadow()
                            }
                        }
                        .contentShape(.rect(cornerRadius: PokedexTheme.Metrics.tabThumbCornerRadius))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected(option) ? [.isSelected] : [])
            }
        }
        .padding(4)
        .frame(height: 40)
        .background(PokedexTheme.mutedSurface, in: .rect(cornerRadius: PokedexTheme.Metrics.controlCornerRadius))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: selection)
    }

    private func select(_ option: Option) {
        guard !isSelected(option) else { return }
        selection = option
    }

    private func isSelected(_ option: Option) -> Bool {
        selection == option
    }
}

#Preview {
    @Previewable @State var selection = PokemonDetailTab.stats

    PokedexTabBar(
        options: PokemonDetailTab.allCases,
        title: \.title,
        selection: $selection
    )
    .padding()
    .background(PokedexTheme.canvas)
}

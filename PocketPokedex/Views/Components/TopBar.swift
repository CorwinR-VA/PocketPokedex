import SwiftUI

struct TopBar: View {
    @Binding var theme: PokedexBackgroundTheme
    @Binding var appearance: ColorScheme?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text("Pocket Pokédex")
                .font(.pokedexTitle)
                .foregroundStyle(PokedexTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 12)

            themeMenu
            appearanceToggle
        }
        .frame(height: 40)
    }

    private var themeMenu: some View {
        Menu {
            Picker("Theme", selection: $theme) {
                ForEach(PokedexBackgroundTheme.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            ZStack {
                Text(theme.title)
                    .font(.pokedexLabel)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 0) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 13))
                        .scaleEffect(x: -1, y: -1)
                        .foregroundStyle(PokedexTheme.accent)
                        .frame(width: PokedexTheme.Metrics.themeControlIconWidth)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PokedexTheme.accent)
                        .frame(width: PokedexTheme.Metrics.themeControlIconWidth)
                }
            }
            .padding(.horizontal, 12)
            .frame(width: PokedexTheme.Metrics.themeControlWidth, height: PokedexTheme.Metrics.controlHeight)
            .pokedexPanel(cornerRadius: PokedexTheme.Metrics.controlCornerRadius)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Theme")
        .accessibilityValue(theme.title)
    }

    private var appearanceToggle: some View {
        Button(action: toggleAppearance) {
            Image(systemName: isDark ? "moon" : "sun.max")
                .font(.system(size: 15))
                .foregroundStyle(PokedexTheme.textPrimary)
                .frame(width: 40, height: 40)
                .pokedexPanel(cornerRadius: PokedexTheme.Metrics.controlCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDark ? "Switch to light appearance" : "Switch to dark appearance")
    }

    private var isDark: Bool { colorScheme == .dark }

    private func toggleAppearance() {
        appearance = isDark ? .light : .dark
    }
}

#Preview {
    TopBar(theme: .constant(.standard), appearance: .constant(nil))
        .padding()
        .background(PokedexTheme.canvas)
}

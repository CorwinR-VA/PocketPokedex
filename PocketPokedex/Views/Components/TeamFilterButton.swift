import SwiftUI

struct TeamFilterButton: View {
    let isOn: Bool
    let teamCount: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isOn ? PokedexTheme.onAccent : PokedexTheme.accent)
                .contentTransition(.symbolEffect(.replace))
                .frame(
                    width: PokedexTheme.Metrics.floatingButtonSize,
                    height: PokedexTheme.Metrics.floatingButtonSize
                )
                .background(isOn ? PokedexTheme.accent : PokedexTheme.surface, in: .circle)
                .overlay { outline }
                .overlay(alignment: .topTrailing) { countBadge }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .shadow(color: PokedexTheme.shadow.opacity(0.18), radius: 8, x: 0, y: 4)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isOn)
        .accessibilityLabel(isOn ? "Show all Pokémon" : "Show my team only")
        .accessibilityValue(Text("^[\(teamCount) team member](inflect: true)"))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    @ViewBuilder
    private var outline: some View {
        if !isOn {
            Circle().stroke(PokedexTheme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var countBadge: some View {
        if teamCount > 0 {
            Text("\(teamCount)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isOn ? PokedexTheme.accent : PokedexTheme.onAccent)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(isOn ? PokedexTheme.onAccent : PokedexTheme.accent, in: .capsule)
                .offset(x: 4, y: -4)
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        TeamFilterButton(isOn: false, teamCount: 0) {}
        TeamFilterButton(isOn: false, teamCount: 3) {}
        TeamFilterButton(isOn: true, teamCount: 3) {}
    }
    .padding(40)
    .background(PokedexTheme.canvas)
}

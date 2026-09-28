import SwiftUI

struct PokemonStatsTab: View {
    let stats: [PokemonStat]
    let total: Int

    var body: some View {
        VStack(spacing: 16) {
            ForEach(stats) { stat in
                StatRow(stat: stat)
            }

            Rectangle()
                .fill(PokedexTheme.border)
                .frame(height: 1)

            HStack(spacing: 8) {
                Text("Total")
                    .font(.pokedexBodyEmphasis)
                    .foregroundStyle(PokedexTheme.textPrimary)
                Spacer(minLength: 0)
                Text("\(total)")
                    .font(.pokedexBodyEmphasis)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .monospacedDigit()
            }
            .frame(height: 24)
        }
    }
}

private struct StatRow: View {
    let stat: PokemonStat

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(stat.displayName)
                    .font(.pokedexLabel)
                    .foregroundStyle(PokedexTheme.textPrimary)
                Spacer(minLength: 0)
                Text("\(stat.baseValue)")
                    .font(.pokedexLabel)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .monospacedDigit()
            }
            .frame(height: 20)

            StatBar(value: stat.baseValue)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.displayName)
        .accessibilityValue("\(stat.baseValue) of \(Int(StatKind.maximumBaseValue))")
    }
}

#Preview {
    PokemonStatsTab(
        stats: [
            PokemonStat(kind: .hitPoints, baseValue: 45),
            PokemonStat(kind: .attack, baseValue: 49),
            PokemonStat(kind: .speed, baseValue: 45)
        ],
        total: 139
    )
    .padding()
    .background(PokedexTheme.canvas)
}

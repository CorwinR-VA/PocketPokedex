import SwiftUI

struct PokemonMovesTab: View {
    let moves: [PokemonMove]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level-up Moves")
                .font(.pokedexBodyEmphasis)
                .foregroundStyle(PokedexTheme.textPrimary)
                .frame(height: 24)

            if moves.isEmpty {
                Text("No level-up moves recorded.")
                    .font(.pokedexParagraph)
                    .foregroundStyle(PokedexTheme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(moves.enumerated(), id: \.element.id) { index, move in
                        MoveRow(move: move, isLast: index == moves.count - 1)
                    }
                }
            }
        }
    }
}

private struct MoveRow: View {
    let move: PokemonMove
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(move.displayName)
                    .font(.pokedexBody)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("Level \(move.level)")
                    .font(.pokedexBody)
                    .foregroundStyle(PokedexTheme.textSecondary)
                    .monospacedDigit()
            }
            .frame(height: 33)

            if !isLast {
                Rectangle()
                    .fill(PokedexTheme.border)
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PokemonMovesTab(moves: [
        PokemonMove(name: "tackle", level: 1),
        PokemonMove(name: "vine-whip", level: 13),
        PokemonMove(name: "razor-leaf", level: 29)
    ])
    .padding()
    .background(PokedexTheme.canvas)
}

import SwiftUI

struct EvolutionChainRow: View {
    let lines: [EvolutionLine]

    var body: some View {
        if lines.isEmpty {
            Text("No evolution data.")
                .font(.pokedexParagraph)
                .foregroundStyle(PokedexTheme.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines) { line in
                    lineRow(line.stages)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One route per row, left-aligned so the stages a branching chain shares sit under each other —
    /// Eevee's eight routes all start with the same Eevee tile.
    private func lineRow(_ stages: [EvolutionStage]) -> some View {
        ViewThatFits(in: .horizontal) {
            row(stages)
            ScrollView(.horizontal) { row(stages) }
                .scrollIndicators(.hidden)
        }
    }

    private func row(_ stages: [EvolutionStage]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(stages.enumerated(), id: \.element.id) { index, stage in
                if index > 0 {
                    EvolutionConnector(requirement: stage.requirement)
                }
                EvolutionStageTile(stage: stage)
            }
        }
    }
}

private struct EvolutionStageTile: View {
    let stage: EvolutionStage

    var body: some View {
        VStack(spacing: 4) {
            CachedArtworkImage(url: stage.artworkURL)
                .frame(width: 64, height: 64)

            Text(stage.displayName)
                .font(.pokedexCaptionStrong)
                .foregroundStyle(PokedexTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 16)

            TypeDotRow(types: stage.types)
                .frame(height: 12)
        }
        .padding(.top, 8)
        .frame(width: 80, height: 112, alignment: .top)
    }
}

private struct EvolutionConnector: View {
    let requirement: String?

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.right")
                .font(.system(size: 15))
                .foregroundStyle(PokedexTheme.textSecondary)
                .frame(width: 20, height: 20)

            Text(requirement ?? "Special")
                .font(.pokedexCaption)
                .foregroundStyle(PokedexTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 16)
        }
        .frame(width: 40)
        .padding(.top, 38)
    }
}

private struct TypeDotRow: View {
    let types: [PokemonType]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(types.prefix(2)) { type in
                Circle()
                    .fill(type.color)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(types.prefix(2).map(\.name).joined(separator: ", "))
    }
}

#Preview {
    EvolutionChainRow(lines: [
        EvolutionLine(stages: [
            EvolutionStage(id: 1, name: "bulbasaur", artworkURL: nil, types: [.grass, .poison], requirement: nil),
            EvolutionStage(id: 2, name: "ivysaur", artworkURL: nil, types: [.grass, .poison], requirement: "Lv. 16"),
            EvolutionStage(id: 3, name: "venusaur", artworkURL: nil, types: [.grass, .poison], requirement: "Lv. 32")
        ]),
        EvolutionLine(stages: [
            EvolutionStage(id: 133, name: "eevee", artworkURL: nil, types: [.normal], requirement: nil),
            EvolutionStage(id: 134, name: "vaporeon", artworkURL: nil, types: [.water], requirement: "Water Stone")
        ]),
        EvolutionLine(stages: [
            EvolutionStage(id: 133, name: "eevee", artworkURL: nil, types: [.normal], requirement: nil),
            EvolutionStage(id: 135, name: "jolteon", artworkURL: nil, types: [.electric], requirement: "Thunder Stone")
        ])
    ])
    .padding()
    .background(PokedexTheme.canvas)
}

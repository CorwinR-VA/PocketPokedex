import SwiftUI

struct EvolutionChainRow: View {
    let lines: [EvolutionLine]

    var body: some View {
        if lines.isEmpty {
            Text("No evolution data.")
                .font(.pokedexParagraph)
                .foregroundStyle(PokedexTheme.textSecondary)
        } else {
            let geometry = Geometry(longestRoute: lines.map(\.stages.count).max() ?? 1)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines) { line in
                    lineRow(line.stages, geometry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One route per row, left-aligned so the stages a branching chain shares sit under each other —
    /// Eevee's eight routes all start with the same Eevee tile. The row is only wrapped in a scroll
    /// view when it cannot fit at all, which on a phone means a four-stage route; three stages fit.
    private func lineRow(_ stages: [EvolutionStage], _ geometry: Geometry) -> some View {
        ViewThatFits(in: .horizontal) {
            row(stages, geometry)
            ScrollView(.horizontal) { row(stages, geometry) }
                .scrollIndicators(.hidden)
        }
    }

    private func row(_ stages: [EvolutionStage], _ geometry: Geometry) -> some View {
        HStack(alignment: .top, spacing: geometry.spacing) {
            ForEach(stages.enumerated(), id: \.element.id) { index, stage in
                if index > 0 {
                    EvolutionConnector(requirement: stage.requirement, width: geometry.connectorWidth)
                }
                EvolutionStageTile(stage: stage, width: geometry.tileWidth)
            }
        }
    }

    /// How much room a route's tiles and connectors get.
    ///
    /// Width is in short supply. The About column measures 308 pt on a 6.9" iPhone, and the original
    /// geometry — three 80 pt tiles, two 40 pt connectors and four 8 pt gaps — comes to 352 pt, so a
    /// three-stage route overflowed the column and had its last Pokémon clipped.
    ///
    /// A long route therefore gives each tile 16 pt less. The artwork stays 64 pt either way, so the
    /// Pokémon are the same size; it is the padding around them that shrinks. The 44 pt connector and
    /// 4 pt gaps still leave a 12 pt margin at three stages, and keep the connector wide enough that a
    /// requirement wraps or scales down rather than being cut in half.
    ///
    /// The geometry is chosen once per chain, from its longest route, so every row of a chain lines up
    /// even when its branches are of different lengths. A four-stage route would still not fit, and
    /// falls back to the scroll view — no chain in the dex is that long.
    struct Geometry {
        let tileWidth: CGFloat
        let connectorWidth: CGFloat
        let spacing: CGFloat

        init(longestRoute: Int) {
            if longestRoute > 2 {
                tileWidth = 64
                connectorWidth = 44
                spacing = 4
            } else {
                tileWidth = 80
                connectorWidth = 72
                spacing = 8
            }
        }

        /// What a route of this length needs, which is what the scroll fallback is measured against.
        func width(forStages count: Int) -> CGFloat {
            let gaps = CGFloat(max(count - 1, 0))
            return CGFloat(count) * tileWidth + gaps * connectorWidth + gaps * 2 * spacing
        }
    }
}

private struct EvolutionStageTile: View {
    let stage: EvolutionStage
    var width: CGFloat = 80

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
        .frame(width: width, height: 112, alignment: .top)
    }
}

private struct EvolutionConnector: View {
    let requirement: String?
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.right")
                .font(.system(size: 15))
                .foregroundStyle(PokedexTheme.textSecondary)
                .frame(width: 20, height: 20)

            // Wraps rather than truncating: "Thunder Stone" is worth two lines, and the one-line cap
            // is what left every requirement reading "Thunde…". The tighter connector of a three-stage
            // route scales a long word such as "Friendship" down instead of cutting it in half.
            Text(requirement ?? "Special")
                .font(.pokedexCaption)
                .foregroundStyle(PokedexTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width)
        }
        .frame(width: width)
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

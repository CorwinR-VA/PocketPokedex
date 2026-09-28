import SwiftUI

struct PokemonAboutTab: View {
    let pokemon: Pokemon?
    let species: PokemonSpecies?
    let evolutionLines: [EvolutionLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AboutSection(icon: "book", title: "Pokédex Entry") {
                Text(species?.flavorText ?? MeasurementFormat.placeholder)
                    .font(.pokedexParagraph)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AboutSection(icon: "dumbbell.fill", title: "Training") {
                AboutFactGrid {
                    AboutFactCell(label: "Base EXP", value: baseExperienceText)
                    AboutFactCell(label: "Catch Rate", value: catchRateText)
                    AboutFactCell(
                        label: "Growth Rate",
                        value: species?.growthRate ?? MeasurementFormat.placeholder
                    )
                }
            }

            AboutSection(icon: "ruler", title: "Physical Attributes") {
                AboutFactGrid {
                    AboutFactCell(label: "Height", value: MeasurementFormat.height(pokemon?.heightInMetres))
                    AboutFactCell(label: "Weight", value: MeasurementFormat.weight(pokemon?.weightInKilograms))
                }
            }

            AboutSection(icon: "arrow.triangle.branch", title: "Evolution Chain") {
                EvolutionChainRow(lines: evolutionLines)
            }

            AboutSection(icon: "sparkles", title: "Classification") {
                Text(species?.genus ?? MeasurementFormat.placeholder)
                    .font(.pokedexLabel)
                    .foregroundStyle(PokedexTheme.accent)
                    .lineLimit(1)
                    .padding(.horizontal, PokedexTheme.Metrics.chipHorizontalPadding)
                    .frame(height: 38)
                    .pokedexPanel(cornerRadius: PokedexTheme.Metrics.controlCornerRadius)
            }
        }
    }

    private var baseExperienceText: String {
        guard let experience = pokemon?.baseExperience else { return MeasurementFormat.placeholder }
        return "\(experience)"
    }

    private var catchRateText: String {
        guard let species else { return MeasurementFormat.placeholder }
        return "\(species.captureRate)"
    }
}

#if DEBUG
#Preview {
    PokemonAboutTab(
        pokemon: nil,
        species: nil,
        evolutionLines: [
            EvolutionLine(stages: [
                EvolutionStage(id: 133, name: "eevee", artworkURL: nil, types: [.normal], requirement: nil),
                EvolutionStage(id: 134, name: "vaporeon", artworkURL: nil, types: [.water], requirement: "Water Stone")
            ]),
            EvolutionLine(stages: [
                EvolutionStage(id: 133, name: "eevee", artworkURL: nil, types: [.normal], requirement: nil),
                EvolutionStage(id: 135, name: "jolteon", artworkURL: nil, types: [.electric], requirement: "Thunder Stone")
            ])
        ]
    )
    .padding()
    .background(PokedexTheme.canvas)
}
#endif

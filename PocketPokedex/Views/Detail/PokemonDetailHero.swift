import SwiftUI

struct PokemonDetailHero: View {
    let viewModel: PokemonDetailViewModel

    var body: some View {
        layout
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pokedexPanel()
            .pokedexCardShadow()
    }

    private var layout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                artwork
                details
            }
            VStack(spacing: 12) {
                artwork.frame(maxWidth: .infinity)
                details
            }
        }
    }

    private var artwork: some View {
        // The hero falls back to the feed item's artwork, so a missing URL here may still be filled in
        // by the detail request that is already in flight.
        CachedArtworkImage(url: viewModel.artworkURL, isAwaitingDetails: viewModel.pokemon == nil)
            .frame(width: 200, height: 218)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.dexNumber)
                .font(.pokedexBody)
                .foregroundStyle(PokedexTheme.textSecondary)
                .frame(height: 24)

            Text(viewModel.displayName)
                .font(.pokedexDetailTitle)
                .foregroundStyle(PokedexTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 16) {
                typeChips
                facts
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var typeChips: some View {
        HStack(spacing: PokedexTheme.Metrics.chipSpacing) {
            ForEach(viewModel.types) { TypeChip(type: $0, isFilled: true) }
        }
        .frame(height: 38, alignment: .bottom)
    }

    private var facts: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                DetailFieldCell(
                    icon: "ruler",
                    iconColor: PokedexTheme.iconBlue,
                    label: "Height",
                    value: viewModel.heightText
                )
                DetailFieldCell(
                    icon: "scalemass",
                    iconColor: PokedexTheme.iconGreen,
                    label: "Weight",
                    value: viewModel.weightText
                )
            }
            HStack(spacing: 16) {
                DetailFieldCell(
                    icon: "bolt.fill",
                    iconColor: PokedexTheme.iconYellow,
                    label: "Abilities",
                    value: viewModel.abilityText
                )
                DetailFieldCell(
                    icon: "star",
                    iconColor: PokedexTheme.iconPurple,
                    label: "Hidden Ability",
                    value: viewModel.hiddenAbilityText
                )
            }
        }
        .frame(height: 108, alignment: .top)
    }
}

#if DEBUG
#Preview {
    PokemonDetailHero(viewModel: AppDependencies.preview.makeDetailViewModel(for: .preview))
        .padding()
        .background(PokedexTheme.canvas)
}
#endif

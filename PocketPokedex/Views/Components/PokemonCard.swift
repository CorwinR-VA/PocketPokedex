import SwiftUI

struct PokemonCard: View {
    let item: PokemonFeedItem
    var isInTeam: Bool = false
    /// Whether this card's details are still loading. A card that has settled without artwork shows
    /// a no-artwork mark rather than a spinner that would never stop.
    var isAwaitingDetails: Bool = false
    var onSelect: () -> Void = {}
    var onToggleTeam: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onSelect) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.displayName), \(item.dexNumber)")

            teamButton
                .padding(PokedexTheme.Metrics.cardPadding)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            header
            artwork
            footer
        }
        .padding(PokedexTheme.Metrics.cardPadding)
        .frame(maxWidth: .infinity)
        .pokedexSurfaceFill(cornerRadius: PokedexTheme.Metrics.cardCornerRadius)
        .pokedexCardShadow()
        .contentShape(.rect(cornerRadius: PokedexTheme.Metrics.cardCornerRadius))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(item.displayName)
                .font(.pokedexCardTitle)
                .foregroundStyle(PokedexTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text(item.dexNumber)
                .font(.pokedexBody)
                .foregroundStyle(PokedexTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(height: 28)
    }

    private var artwork: some View {
        CachedArtworkImage(url: item.artworkURL, isAwaitingDetails: isAwaitingDetails)
            .frame(
                width: PokedexTheme.Metrics.cardArtworkWidth,
                height: PokedexTheme.Metrics.cardArtworkHeight
            )
            .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            TypeBadgeRow(types: item.types)
            Spacer(minLength: 0)
            Color.clear
                .frame(width: PokedexTheme.Metrics.cardActionSize, height: PokedexTheme.Metrics.cardActionSize)
        }
        .frame(height: 28)
    }

    private var teamButton: some View {
        Button(action: onToggleTeam) {
            Image(systemName: isInTeam ? "checkmark" : "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PokedexTheme.accent)
                .frame(width: 16, height: 16)
                .frame(
                    width: PokedexTheme.Metrics.cardActionSize,
                    height: PokedexTheme.Metrics.cardActionSize
                )
                .background(PokedexTheme.surface, in: .circle)
                .overlay { Circle().stroke(PokedexTheme.border, lineWidth: 1) }
                .padding(PokedexTheme.Metrics.cardActionHitMargin)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(PokedexTheme.Metrics.cardPadding - PokedexTheme.Metrics.cardActionHitMargin)
        .accessibilityLabel(isInTeam ? "Remove \(item.displayName) from team" : "Add \(item.displayName) to team")
    }
}

#Preview {
    HStack(spacing: 16) {
        PokemonCard(item: .preview)
        PokemonCard(item: .preview, isInTeam: true)
    }
    .frame(width: 560)
    .padding()
    .background(PokedexTheme.canvas)
}

extension PokemonFeedItem {
    static var preview: PokemonFeedItem {
        PokemonFeedItem(
            id: 1,
            name: "bulbasaur",
            types: [.grass, .poison],
            artworkURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/1.png")
        )
    }
}

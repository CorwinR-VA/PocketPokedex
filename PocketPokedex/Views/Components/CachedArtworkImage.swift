import SwiftUI

struct CachedArtworkImage: View {
    @Environment(\.imageCache) private var imageCache

    private let url: URL?
    private let isAwaitingDetails: Bool
    @State private var loader = ArtworkLoader()

    /// - Parameter isAwaitingDetails: whether the card's artwork URL can still change, which is what
    ///   tells a missing URL apart from a Pokémon that has no artwork at all.
    init(url: URL?, isAwaitingDetails: Bool = false) {
        self.url = url
        self.isAwaitingDetails = isAwaitingDetails
    }

    var body: some View {
        Group {
            if let image = loader.resolvedImage(for: url, in: imageCache) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .task(id: Request(url: url, isAwaitingDetails: isAwaitingDetails)) {
            await loader.load(url, isAwaitingDetails: isAwaitingDetails, in: imageCache)
        }
    }

    /// The task re-runs when the URL arrives *or* when hydration settles without one, because both
    /// change what there is to show.
    private struct Request: Equatable {
        let url: URL?
        let isAwaitingDetails: Bool
    }

    @ViewBuilder
    private var placeholder: some View {
        if loader.isUnavailable {
            noArtwork
        } else {
            ProgressView()
                .controlSize(.regular)
                .tint(PokedexTheme.textSecondary)
        }
    }

    /// A quiet Poké Ball rather than a broken-image glyph: a handful of forms have no artwork
    /// anywhere in the API, and that is not the same thing as a load that failed.
    private var noArtwork: some View {
        Image(.motifPokeball)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
            .foregroundStyle(PokedexTheme.textSecondary.opacity(0.35))
            .accessibilityHidden(true)
    }
}

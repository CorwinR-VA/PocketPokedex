import SwiftUI

struct CachedArtworkImage: View {
    @Environment(\.imageCache) private var imageCache

    private let url: URL?
    @State private var loadedImage: UIImage?
    @State private var loadedImageURL: URL?
    @State private var didFail = false

    init(url: URL?) {
        self.url = url
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .task(id: url) { await load() }
    }

    @ViewBuilder
    private var placeholder: some View {
        if didFail {
            Image(systemName: "photo")
                .font(.system(size: 22))
                .foregroundStyle(PokedexTheme.textSecondary.opacity(0.5))
                .accessibilityHidden(true)
        } else {
            ProgressView()
                .controlSize(.regular)
                .tint(PokedexTheme.textSecondary)
        }
    }

    private var resolvedImage: UIImage? {
        guard let url else { return nil }
        if loadedImageURL == url, let loadedImage { return loadedImage }
        return imageCache.cachedImage(for: url)
    }

    private func load() async {
        guard let url else {
            didFail = true
            return
        }

        if imageCache.cachedImage(for: url) != nil {
            didFail = false
            return
        }

        do {
            let image = try await imageCache.image(for: url)
            guard !Task.isCancelled else { return }
            didFail = false
            withAnimation(.easeOut(duration: 0.18)) {
                loadedImageURL = url
                loadedImage = image
            }
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}

import Observation
import UIKit

/// Drives the artwork for one view: reads the shared cache, retries a load that failed for a passing
/// reason, and keeps watching for an image that lands in the cache from somewhere else.
///
/// A view cannot simply load once and give up. Its image may already be cached, the request may fail
/// and then succeed, and — the case this exists for — the image may be *put in the cache by another
/// screen while this view is on screen*: the detail screen loads the same artwork, and `NSCache` has
/// no way to tell a view that it changed. So an unresolved view re-reads the shared cache on a short
/// interval until it has an image, or until the view goes away and cancels the task.
///
/// The policy lives here rather than in the view because the app's view layer is not unit-tested.
///
/// `load(_:isAwaitingDetails:in:)` returns once it has an image, or immediately when there is no URL
/// to fetch. For a URL that keeps failing it returns only when its task is cancelled — which is what
/// the view does when the card scrolls away — so callers must never await it without a way to cancel.
@MainActor
@Observable
final class ArtworkLoader {
    private(set) var image: UIImage?

    /// True once the artwork is known to be unavailable, so a view shows a quiet mark rather than a
    /// spinner that would never stop. Not final: the poll can still find an image afterwards.
    private(set) var isUnavailable = false

    private let maximumAttempts: Int
    private let recheckInterval: Duration

    init(maximumAttempts: Int = 3, recheckInterval: Duration = .milliseconds(500)) {
        self.maximumAttempts = maximumAttempts
        self.recheckInterval = recheckInterval
    }

    /// The image to draw right now, for the synchronous path: a re-render must never drop an image
    /// the cache already holds, so a card paints from the cache before any task runs.
    func resolvedImage(for url: URL?, in cache: any ImageCaching) -> UIImage? {
        image ?? url.flatMap(cache.cachedImage(for:))
    }

    func load(_ url: URL?, isAwaitingDetails: Bool, in cache: any ImageCaching) async {
        guard image == nil else { return }

        guard let url else {
            // A card is rendered from the list endpoint before hydration hands it an artwork URL.
            // That is a wait, not a failure — `.task(id:)` calls again once it has one — but once
            // hydration has reported and there is still no URL, the Pokémon has no artwork at all.
            isUnavailable = !isAwaitingDetails
            return
        }

        if let cached = cache.cachedImage(for: url) {
            image = cached
            isUnavailable = false
            return
        }

        var attempts = 0

        while !Task.isCancelled {
            if attempts < maximumAttempts {
                attempts += 1
                if let loaded = try? await cache.image(for: url) {
                    guard !Task.isCancelled else { return }
                    image = loaded
                    isUnavailable = false
                    return
                }
                guard !Task.isCancelled else { return }
            } else if !isUnavailable {
                isUnavailable = true
            }

            // Out of attempts is not the end of the story: another screen may cache this image, and
            // the cache cannot tell us when it does.
            if let cached = cache.cachedImage(for: url) {
                guard !Task.isCancelled else { return }
                image = cached
                isUnavailable = false
                return
            }

            do {
                try await Task.sleep(for: recheckInterval)
            } catch {
                return
            }
        }
    }
}

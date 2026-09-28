import Foundation
import Testing
import UIKit
@testable import PocketPokedex

@Suite("Artwork loading")
@MainActor
struct ArtworkLoaderTests {

    private static func url(_ id: Int) -> URL {
        URL(string: "https://art.test/\(id).png")!
    }

    @Test("Paints from the cache before any task runs")
    func resolvesFromCacheSynchronously() {
        let url = Self.url(1)
        let cached = UIImage()
        let cache = StubImageCache(cached: [url: cached])
        let loader = ArtworkLoader()

        #expect(loader.resolvedImage(for: url, in: cache) === cached)
    }

    @Test("Takes a cached image without asking the network")
    func adoptsACachedImage() async {
        let url = Self.url(1)
        let cached = UIImage()
        let cache = StubImageCache(cached: [url: cached])
        let loader = ArtworkLoader()

        await loader.load(url, isAwaitingDetails: false, in: cache)

        #expect(loader.image === cached)
        #expect(cache.loadCount == 0)
        #expect(!loader.isUnavailable)
    }

    @Test("Loads through the cache and exposes the image")
    func loadsThroughTheCache() async {
        let url = Self.url(1)
        let stored = UIImage()
        let cache = StubImageCache(served: [url: stored])
        let loader = ArtworkLoader()

        await loader.load(url, isAwaitingDetails: false, in: cache)

        #expect(loader.image === stored)
        #expect(!loader.isUnavailable)
    }

    @Test("Keeps waiting on an image that has not arrived")
    func keepsWaitingForAnImage() async {
        let url = Self.url(1)
        let cache = StubImageCache()
        let loader = ArtworkLoader(maximumAttempts: 1, recheckInterval: .milliseconds(5))

        let loading = Task { await loader.load(url, isAwaitingDetails: false, in: cache) }

        // Nothing arrived, so the view is told there is no artwork rather than left spinning, and the
        // attempt budget stops it hammering the network.
        await waitUntil { loader.isUnavailable }
        #expect(loader.image == nil)
        #expect(loader.isUnavailable)
        #expect(cache.loadCount == 1)

        // `load` returns only once it has an image or the view goes away, so the task is still alive.
        #expect(!loading.isCancelled)

        loading.cancel()
        await loading.value
    }

    @Test("Retries a load that failed and then succeeds")
    func retriesAFailure() async {
        let url = Self.url(1)
        let stored = UIImage()
        let cache = StubImageCache(failures: 1, served: [url: stored])
        let loader = ArtworkLoader(maximumAttempts: 3, recheckInterval: .milliseconds(5))

        await loader.load(url, isAwaitingDetails: false, in: cache)

        #expect(loader.image === stored)
        #expect(cache.loadCount == 2)
        #expect(!loader.isUnavailable)
    }

    @Test("Takes up an image another screen caches while it waits")
    func adoptsAnImageCachedElsewhere() async {
        let url = Self.url(1)
        // Every attempt fails, so only the shared cache can save this view.
        let cache = StubImageCache(failures: 99)
        let loader = ArtworkLoader(maximumAttempts: 1, recheckInterval: .milliseconds(5))

        let loading = Task { await loader.load(url, isAwaitingDetails: false, in: cache) }
        // Wait until it has really tried, so this is about adoption rather than an up-front hit.
        await waitUntil { cache.loadCount >= 1 }

        // The detail screen loads the same artwork and puts it in the shared cache.
        let fromDetail = UIImage()
        cache.seed(fromDetail, for: url)

        await loading.value
        #expect(loader.image === fromDetail)
        #expect(!loader.isUnavailable)
    }

    @Test("Stops asking the network after the attempt budget, but keeps watching")
    func stopsAfterTheAttemptBudget() async {
        let url = Self.url(1)
        let cache = StubImageCache(failures: 99)
        let loader = ArtworkLoader(maximumAttempts: 2, recheckInterval: .milliseconds(5))

        let loading = Task { await loader.load(url, isAwaitingDetails: false, in: cache) }

        await waitUntil { cache.loadCount == 2 && loader.isUnavailable }
        #expect(cache.loadCount == 2)
        #expect(loader.isUnavailable)
        #expect(loader.image == nil)

        // Still watching: an image cached later still reaches the view.
        let late = UIImage()
        cache.seed(late, for: url)
        await loading.value
        #expect(loader.image === late)
    }

    @Test("Reports no artwork once hydration has reported without a URL")
    func reportsMissingArtworkAfterHydration() async {
        let loader = ArtworkLoader()
        await loader.load(nil, isAwaitingDetails: false, in: StubImageCache())

        #expect(loader.isUnavailable)
        #expect(loader.image == nil)
    }

    @Test("Waits rather than giving up while the card is still being hydrated")
    func waitsWhileDetailsArePending() async {
        let loader = ArtworkLoader()
        await loader.load(nil, isAwaitingDetails: true, in: StubImageCache())

        #expect(!loader.isUnavailable)
    }

    @Test("Leaves the artwork unresolved when the view goes away")
    func cancellationLeavesItUnresolved() async {
        let cache = StubImageCache(failures: 99)
        let loader = ArtworkLoader(maximumAttempts: 20, recheckInterval: .milliseconds(10))

        let loading = Task { await loader.load(Self.url(1), isAwaitingDetails: false, in: cache) }
        try? await Task.sleep(for: .milliseconds(30))
        loading.cancel()
        await loading.value

        // A cancelled load is a wait, not a verdict: the card should try again when it comes back.
        #expect(loader.image == nil)
        #expect(!loader.isUnavailable)
    }
}

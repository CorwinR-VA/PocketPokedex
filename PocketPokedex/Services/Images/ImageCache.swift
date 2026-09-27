import SwiftUI

nonisolated protocol ImageCaching: Sendable {
    func image(for url: URL) async throws -> UIImage

    func cachedImage(for url: URL) -> UIImage?
}

actor ImageCache: ImageCaching {
    static let shared = ImageCache()

    private nonisolated let memory: ImageMemoryCache
    private let disk: ImageDiskCache
    private let session: URLSession
    private var inFlight: [URL: Task<UIImage, any Error>] = [:]

    init(
        memory: ImageMemoryCache = ImageMemoryCache(),
        disk: ImageDiskCache = ImageDiskCache(),
        session: URLSession = ImageCache.makeSession()
    ) {
        self.memory = memory
        self.disk = disk
        self.session = session
    }

    nonisolated func cachedImage(for url: URL) -> UIImage? {
        memory.image(for: url)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = memory.image(for: url) { return cached }

        if let existing = inFlight[url] { return try await existing.value }

        let task = Task<UIImage, any Error> { [weak self] in
            guard let self else { throw CancellationError() }
            let image = try await self.load(url)
            self.memory.insert(image, for: url)
            return image
        }
        inFlight[url] = task

        defer { inFlight[url] = nil }
        return try await task.value
    }

    private func load(_ url: URL) async throws -> UIImage {
        if let data = disk.data(for: url), let image = UIImage(data: data) {
            return image
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw PokeAPIError.httpStatus(code: http.statusCode)
            }
            guard let image = UIImage(data: data) else {
                throw PokeAPIError.decodingFailed(description: "The image data was not readable.")
            }
            disk.store(data, for: url)
            return image
        } catch {
            throw PokeAPIError.from(error)
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }
}

extension EnvironmentValues {
    @Entry var imageCache: any ImageCaching = ImageCache.shared
}

nonisolated struct PreviewImageCache: ImageCaching {
    func image(for url: URL) async throws -> UIImage {
        throw PokeAPIError.notFound
    }

    func cachedImage(for url: URL) -> UIImage? { nil }
}

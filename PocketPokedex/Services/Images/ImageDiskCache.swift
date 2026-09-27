import CryptoKit
import Foundation

nonisolated struct ImageDiskCache: Sendable {
    private let directory: URL

    init(directoryName: String = "PokeImageCache") {
        directory = URL.cachesDirectory.appending(path: directoryName, directoryHint: .isDirectory)
    }

    func data(for url: URL) -> Data? {
        try? Data(contentsOf: fileURL(for: url))
    }

    func store(_ data: Data, for url: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: url), options: .atomic)
        } catch {
        }
    }

    private func fileURL(for url: URL) -> URL {
        directory.appending(path: Self.filename(for: url))
    }

    private static func filename(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".img"
    }
}

import Foundation

nonisolated struct NamedResourcePayload: Decodable, Sendable, Hashable {
    let name: String
    let url: URL
}

nonisolated struct ResourceListPayload: Decodable, Sendable {
    let count: Int
    let next: URL?
    let results: [NamedResourcePayload]
}

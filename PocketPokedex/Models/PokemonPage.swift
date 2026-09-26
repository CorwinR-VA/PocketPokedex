import Foundation

nonisolated struct PokemonPage: Sendable {
    let items: [PokemonFeedItem]
    let nextPageURL: URL?
    let totalCount: Int
}

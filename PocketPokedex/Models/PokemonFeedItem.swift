import Foundation

nonisolated struct PokemonFeedItem: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    var types: [PokemonType] = []
    var artworkURL: URL?

    var displayName: String { name.pokemonDisplayName }
    var dexNumber: String { id.pokedexNumber }
}

extension PokemonFeedItem {
    init(pokemon: Pokemon) {
        self.init(
            id: pokemon.id,
            name: pokemon.name,
            types: pokemon.types,
            artworkURL: pokemon.artworkURL ?? pokemon.thumbnailURL
        )
    }
}

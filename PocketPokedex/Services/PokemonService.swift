import Foundation

nonisolated protocol PokemonService: Sendable {
    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage
    func pokemonPage(following url: URL) async throws -> PokemonPage

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon
    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies

    func availableTypes() async throws -> [PokemonType]

    func evolutionChain(id: Int) async throws -> [EvolutionStage]
}

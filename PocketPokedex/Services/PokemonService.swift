import Foundation

nonisolated protocol PokemonService: Sendable {
    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage
    func pokemonPage(following url: URL) async throws -> PokemonPage

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon

    /// The species of the Pokémon with this identifier. A form — a mega, a regional variant — has no
    /// species entry under its own id, so it resolves to the species it belongs to.
    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies

    func availableTypes() async throws -> [PokemonType]

    /// Every route through the chain, one per leaf, each starting at the base form.
    func evolutionChain(id: Int) async throws -> [EvolutionLine]
}

import Foundation

nonisolated struct CachedPokemonService: PokemonService {
    private let upstream: any PokemonService
    private let pokemonMemo = ResourceMemo<PokemonIdentifier, Pokemon>()
    private let speciesMemo = ResourceMemo<PokemonIdentifier, PokemonSpecies>()
    private let evolutionMemo = ResourceMemo<Int, [EvolutionStage]>()
    private static let availableTypesKey = "available-types"
    private let typesMemo = ResourceMemo<String, [PokemonType]>()

    init(upstream: any PokemonService) {
        self.upstream = upstream
    }

    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        try await upstream.pokemonPage(limit: limit, offset: offset)
    }

    func pokemonPage(following url: URL) async throws -> PokemonPage {
        try await upstream.pokemonPage(following: url)
    }

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon {
        try await pokemonMemo.value(for: identifier) { [upstream] in
            try await upstream.pokemon(identifier)
        }
    }

    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies {
        try await speciesMemo.value(for: identifier) { [upstream] in
            try await upstream.species(identifier)
        }
    }

    func availableTypes() async throws -> [PokemonType] {
        try await typesMemo.value(for: Self.availableTypesKey) { [upstream] in
            try await upstream.availableTypes()
        }
    }

    func evolutionChain(id: Int) async throws -> [EvolutionStage] {
        try await evolutionMemo.value(for: id) { [upstream] in
            try await upstream.evolutionChain(id: id)
        }
    }
}

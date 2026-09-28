#if DEBUG
import Foundation

nonisolated struct PreviewPokemonService: PokemonService {
    private static let names = [
        "bulbasaur", "ivysaur", "venusaur", "charmander", "charmeleon",
        "charizard", "squirtle", "wartortle", "blastoise", "caterpie",
        "metapod", "butterfree", "weedle", "kakuna", "beedrill",
        "pidgey", "pidgeotto", "pidgeot", "rattata", "raticate"
    ]

    private static let typePairs: [[PokemonType]] = [
        [.grass, .poison], [.grass, .poison], [.grass, .poison], [.fire], [.fire],
        [.fire, .flying], [.water], [.water], [.water], [.bug],
        [.bug], [.bug, .flying], [.bug, .poison], [.bug, .poison], [.bug, .poison],
        [.normal, .flying], [.normal, .flying], [.normal, .flying], [.normal], [.normal]
    ]

    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        let slice = Self.names.enumerated().dropFirst(offset).prefix(limit)
        let items = slice.map { PokemonFeedItem(id: $0.offset + 1, name: $0.element) }
        let nextOffset = offset + items.count
        let next = nextOffset < Self.names.count
            ? URL(string: "preview://pokemon?offset=\(nextOffset)&limit=\(limit)")
            : nil
        return PokemonPage(items: items, nextPageURL: next, totalCount: Self.names.count)
    }

    func pokemonPage(following url: URL) async throws -> PokemonPage {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let offset = Int(components?.queryItems?.first { $0.name == "offset" }?.value ?? "0") ?? 0
        let limit = Int(components?.queryItems?.first { $0.name == "limit" }?.value ?? "40") ?? 40
        return try await pokemonPage(limit: limit, offset: offset)
    }

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon {
        let id = try resolveIdentifier(identifier)
        let index = fixtureIndex(for: id)
        return Pokemon(
            id: id,
            name: Self.names[index],
            types: Self.typePairs[index],
            artworkURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(index + 1).png"),
            thumbnailURL: nil,
            heightInMetres: Double(7 + index) / 10,
            weightInKilograms: Double(69 + index * 10) / 10,
            baseExperience: 64 + index,
            abilities: [
                PokemonAbility(name: "overgrow", isHidden: false),
                PokemonAbility(name: "chlorophyll", isHidden: true)
            ],
            stats: [
                PokemonStat(kind: .hitPoints, baseValue: 45 + index),
                PokemonStat(kind: .attack, baseValue: 49 + index),
                PokemonStat(kind: .defense, baseValue: 49 + index),
                PokemonStat(kind: .specialAttack, baseValue: 65 + index),
                PokemonStat(kind: .specialDefense, baseValue: 65 + index),
                PokemonStat(kind: .speed, baseValue: 45 + index)
            ],
            moves: [
                PokemonMove(name: "tackle", level: 1),
                PokemonMove(name: "growl", level: 1),
                PokemonMove(name: "vine-whip", level: 13),
                PokemonMove(name: "take-down", level: 15),
                PokemonMove(name: "seed-bomb", level: 20),
                PokemonMove(name: "razor-leaf", level: 29)
            ]
        )
    }

    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies {
        let id = try resolveIdentifier(identifier)
        return PokemonSpecies(
            id: id,
            genus: "Seed Pokémon",
            flavorText: "When the bulb on its back grows large, it appears to lose the ability to stand on its hind legs.",
            captureRate: 45,
            growthRate: "Medium Slow",
            evolutionChainIdentifier: 1
        )
    }

    func availableTypes() async throws -> [PokemonType] {
        PokemonType.allCases
    }

    func evolutionChain(id: Int) async throws -> [EvolutionLine] {
        [EvolutionLine(stages: [
            EvolutionStage(id: 1, name: "bulbasaur", artworkURL: nil, types: [.grass, .poison], requirement: nil),
            EvolutionStage(id: 2, name: "ivysaur", artworkURL: nil, types: [.grass, .poison], requirement: "Lv. 16"),
            EvolutionStage(id: 3, name: "venusaur", artworkURL: nil, types: [.grass, .poison], requirement: "Lv. 32")
        ])]
    }

    private func fixtureIndex(for id: Int) -> Int {
        min(max(id - 1, 0), Self.names.count - 1)
    }

    private func resolveIdentifier(_ identifier: PokemonIdentifier) throws -> Int {
        switch identifier {
        case .id(let id):
            return id
        case .name(let name):
            guard let index = Self.names.firstIndex(of: name.lowercased()) else {
                throw PokeAPIError.notFound
            }
            return index + 1
        }
    }
}
#endif

import Foundation
import Testing
@testable import PocketPokedex

/// Shared domain values, hoisted out of the actor-isolated suites so a stub closure can use them.
private let bulbasaur = Fixture.pokemon(id: 1, name: "bulbasaur")
private let ivysaur = Fixture.pokemon(id: 2, name: "ivysaur")

@Suite("Live service page mapping")
struct LivePokemonServicePageTests {
    @Test("Maps a list response onto feed items, reading the id out of each resource URL")
    func mapsListPage() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(
            count: 1_351,
            next: "https://pokeapi.co/api/v2/pokemon?limit=2&offset=2",
            results: [
                ("bulbasaur", "https://pokeapi.co/api/v2/pokemon/1/"),
                ("ivysaur", "https://pokeapi.co/api/v2/pokemon/2/")
            ]
        ))
        let page = try await LivePokemonService(client: PokeAPIClient(transport: transport))
            .pokemonPage(limit: 2, offset: 0)

        #expect(page.totalCount == 1_351)
        #expect(page.nextPageURL?.absoluteString == "https://pokeapi.co/api/v2/pokemon?limit=2&offset=2")
        #expect(page.items.map(\.id) == [1, 2])
        #expect(page.items.map(\.name) == ["bulbasaur", "ivysaur"])
    }

    @Test("Starts every card with no types and no artwork, for hydration to fill in")
    func cardsStartBare() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(
            results: [("bulbasaur", "https://pokeapi.co/api/v2/pokemon/1/")]
        ))
        let page = try await LivePokemonService(client: PokeAPIClient(transport: transport))
            .pokemonPage(limit: 1, offset: 0)

        let item = try #require(page.items.first)
        #expect(item.types.isEmpty)
        #expect(item.artworkURL == nil)
    }

    @Test("Drops a resource whose URL has no numeric id")
    func dropsUnparseableResources() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(
            count: 3,
            results: [
                ("bulbasaur", "https://pokeapi.co/api/v2/pokemon/1/"),
                ("mystery", "https://pokeapi.co/api/v2/pokemon/not-a-number/"),
                ("ivysaur", "https://pokeapi.co/api/v2/pokemon/2/")
            ]
        ))
        let page = try await LivePokemonService(client: PokeAPIClient(transport: transport))
            .pokemonPage(limit: 3, offset: 0)

        #expect(page.items.map(\.id) == [1, 2])
        #expect(page.totalCount == 3)
    }

    @Test("Requests the page the caller asked for")
    func requestsRequestedPage() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(results: []))
        _ = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemonPage(limit: 40, offset: 120)

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://pokeapi.co/api/v2/pokemon?limit=40&offset=120")
    }

    @Test("Follows a pagination URL without rebuilding it")
    func followsPaginationURL() async throws {
        let next = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=40&offset=40")!
        let transport = StubHTTPClient(json: JSONFixture.resourceList(results: []))
        _ = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemonPage(following: next)

        #expect(transport.requests.first?.url == next)
    }

    @Test("Reports a page with no next link as the last page")
    func reportsLastPage() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(results: []))
        let page = try await LivePokemonService(client: PokeAPIClient(transport: transport))
            .pokemonPage(limit: 40, offset: 1_320)

        #expect(page.nextPageURL == nil)
    }
}

@Suite("Live service available types")
struct LivePokemonServiceTypeTests {
    @Test("Keeps only the types the app models, in its own canonical order")
    func filtersAndOrdersTypes() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(
            count: 4,
            results: [
                ("water", "https://pokeapi.co/api/v2/type/11/"),
                ("fire", "https://pokeapi.co/api/v2/type/10/"),
                ("stellar", "https://pokeapi.co/api/v2/type/10002/"),
                ("grass", "https://pokeapi.co/api/v2/type/12/")
            ]
        ))
        let types = try await LivePokemonService(client: PokeAPIClient(transport: transport)).availableTypes()

        #expect(types == [.fire, .water, .grass])
    }

    @Test("Falls back to every known type when the response carries none the app models")
    func fallsBackToAllTypes() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(
            results: [("stellar", "https://pokeapi.co/api/v2/type/10002/")]
        ))
        let types = try await LivePokemonService(client: PokeAPIClient(transport: transport)).availableTypes()

        #expect(types == PokemonType.allCases)
    }
}

@Suite("Live service pokemon mapping")
struct LivePokemonServicePokemonTests {
    @Test("Maps a pokemon payload onto the domain model")
    func mapsPokemon() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            id: 1,
            name: "bulbasaur",
            baseExperience: 64,
            height: 7,
            weight: 69
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.id == 1)
        #expect(pokemon.name == "bulbasaur")
        #expect(pokemon.displayName == "Bulbasaur")
        #expect(pokemon.types == [.grass, .poison])
        #expect(pokemon.baseExperience == 64)
        #expect(pokemon.artworkURL?.absoluteString == "https://art.test/official/1.png")
        #expect(pokemon.thumbnailURL?.absoluteString == "https://art.test/front/1.png")
    }

    @Test("Converts decimetres and hectograms into metres and kilograms")
    func convertsMeasurements() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(height: 7, weight: 69))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.heightInMetres == 0.7)
        #expect(pokemon.weightInKilograms == 6.9)
    }

    @Test("Orders type slots by slot number, not by their order in the payload")
    func ordersTypesBySlot() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            types: [(2, "poison"), (1, "grass")]
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.types == [.grass, .poison])
    }

    @Test("Drops type names the app does not model")
    func dropsUnknownTypes() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            types: [(1, "grass"), (2, "stellar")]
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.types == [.grass])
    }

    @Test("Orders abilities by slot and keeps the hidden flag")
    func ordersAbilities() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            abilities: [
                (3, "chlorophyll", true),
                (1, "overgrow", false),
                (2, "solar-power", false)
            ]
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.abilities == [
            PokemonAbility(name: "overgrow", isHidden: false),
            PokemonAbility(name: "solar-power", isHidden: false),
            PokemonAbility(name: "chlorophyll", isHidden: true)
        ])
    }

    @Test("Resolves the six base stats by their API slug, in the app's own order")
    func ordersStats() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            stats: [
                ("speed", 45), ("special-defense", 65), ("special-attack", 65),
                ("defense", 49), ("attack", 49), ("hp", 45)
            ]
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.stats.map(\.kind) == StatKind.allCases)
        #expect(pokemon.stats.map(\.baseValue) == [45, 49, 49, 65, 65, 45])
        #expect(pokemon.totalStats == 318)
    }

    @Test("Skips a base stat the payload omits rather than inventing a zero")
    func skipsMissingStats() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(
            stats: [("hp", 45), ("attack", 49)]
        ))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.stats.map(\.kind) == [.hitPoints, .attack])
        #expect(pokemon.totalStats == 94)
    }

    @Test("Accepts a missing base experience")
    func acceptsMissingBaseExperience() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(baseExperience: nil))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.baseExperience == nil)
    }

    @Test("Falls back from official artwork to home artwork to the default sprite")
    func fallsBackThroughArtwork() async throws {
        func artwork(artwork: String?, home: String?, frontDefault: String?) async throws -> URL? {
            let transport = StubHTTPClient(json: JSONFixture.pokemon(
                artwork: artwork,
                home: home,
                frontDefault: frontDefault
            ))
            return try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1)).artworkURL
        }

        let official = try await artwork(artwork: "https://art.test/a.png", home: "https://art.test/b.png", frontDefault: "https://art.test/c.png")
        let home = try await artwork(artwork: nil, home: "https://art.test/b.png", frontDefault: "https://art.test/c.png")
        let sprite = try await artwork(artwork: nil, home: nil, frontDefault: "https://art.test/c.png")
        let none = try await artwork(artwork: nil, home: nil, frontDefault: nil)

        #expect(official?.absoluteString == "https://art.test/a.png")
        #expect(home?.absoluteString == "https://art.test/b.png")
        #expect(sprite?.absoluteString == "https://art.test/c.png")
        #expect(none == nil)
    }

    @Test("Ignores sprite keys the app does not model")
    func ignoresUnknownSpriteKeys() async throws {
        let json = """
        {
          "id": 1, "name": "bulbasaur", "height": 7, "weight": 69,
          "sprites": {
            "front_default": "https://art.test/front/1.png",
            "other": {
              "dream_world": { "front_default": "https://art.test/dream/1.png" },
              "showdown": { "front_default": "https://art.test/showdown/1.png" },
              "official-artwork": { "front_default": "https://art.test/official/1.png" }
            }
          },
          "types": [], "stats": [], "abilities": [], "moves": []
        }
        """
        let transport = StubHTTPClient(json: json)
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.artworkURL?.absoluteString == "https://art.test/official/1.png")
    }
}

@Suite("Live service move mapping")
struct LivePokemonServiceMoveTests {
    @Test("Keeps only level-up moves learned at a positive level")
    func filtersToLevelUpMoves() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(moves: [
            .levelUp("tackle", at: 1),
            JSONFixture.Move(name: "cut", details: [("machine", 0)]),
            JSONFixture.Move(name: "hidden-power", details: [("tutor", 0)]),
            .levelUp("egg-move", at: 0)
        ]))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.moves == [PokemonMove(name: "tackle", level: 1)])
    }

    @Test("Orders moves by the earliest level they are learned at")
    func ordersMovesByLevel() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(moves: [
            .levelUp("vine-whip", at: 13),
            .levelUp("tackle", at: 1),
            .levelUp("growl", at: 3)
        ]))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.moves == [
            PokemonMove(name: "tackle", level: 1),
            PokemonMove(name: "growl", level: 3),
            PokemonMove(name: "vine-whip", level: 13)
        ])
    }

    @Test("Keeps the earliest level when a move is taught at several levels")
    func keepsEarliestLevel() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(moves: [
            JSONFixture.Move(name: "tackle", details: [("level-up", 20), ("level-up", 1), ("level-up", 8)])
        ]))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.moves == [PokemonMove(name: "tackle", level: 1)])
    }

    @Test("De-duplicates a move that appears more than once")
    func deDuplicatesMoves() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(moves: [
            .levelUp("tackle", at: 1),
            .levelUp("tackle", at: 1)
        ]))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.moves.count == 1)
    }

    @Test("Breaks level ties by the order the API listed the moves in")
    func breaksTiesByAPIOrder() async throws {
        let transport = StubHTTPClient(json: JSONFixture.pokemon(moves: [
            .levelUp("growl", at: 1),
            .levelUp("tackle", at: 1),
            .levelUp("vine-whip", at: 1)
        ]))
        let pokemon = try await LivePokemonService(client: PokeAPIClient(transport: transport)).pokemon(.id(1))

        #expect(pokemon.moves.map(\.name) == ["growl", "tackle", "vine-whip"])
    }
}

@Suite("Live service species mapping")
struct LivePokemonServiceSpeciesTests {
    @Test("Maps a species payload onto the domain model")
    func mapsSpecies() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(
            id: 1,
            captureRate: 45,
            growthRate: "medium-slow",
            evolutionChainID: 1
        ))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.id == 1)
        #expect(species.genus == "Seed Pokémon")
        #expect(species.captureRate == 45)
        #expect(species.growthRate == "Medium Slow")
        #expect(species.evolutionChainIdentifier == 1)
    }

    @Test("Prefers English lore over the first entry the API sends")
    func prefersEnglishFlavorText() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(flavorTexts: [
            ("ja", "たねポケモン。"),
            ("en", "A strange seed was planted on its back at birth.")
        ]))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.flavorText == "A strange seed was planted on its back at birth.")
    }

    @Test("Falls back to the first entry when there is no English lore")
    func fallsBackFromEnglish() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(flavorTexts: [
            ("ja", "たねポケモン。"),
            ("fr", "Une graine étrange.")
        ]))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.flavorText == "たねポケモン。")
    }

    @Test("Collapses the API's line breaks, form feeds and soft hyphens into single spaces")
    func normalisesFlavorText() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(flavorTexts: [
            ("en", "A strange seed was\nplanted on its back.\u{0C}It  grows.\u{00AD}")
        ]))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.flavorText == "A strange seed was planted on its back. It grows.")
    }

    @Test("Corrects the API's shouted POKéMON")
    func correctsShoutedPokemon() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(flavorTexts: [
            ("en", "This POKéMON grows quickly.")
        ]))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.flavorText == "This Pokémon grows quickly.")
    }

    @Test("Reports missing lore, genus, growth rate and chain as nil")
    func reportsMissingOptionalFields() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(
            growthRate: nil,
            evolutionChainID: nil,
            genera: [("ja", "たねポケモン")],
            flavorTexts: []
        ))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.genus == nil)
        #expect(species.flavorText == nil)
        #expect(species.growthRate == nil)
        #expect(species.evolutionChainIdentifier == nil)
    }

    @Test("Reads the evolution chain id out of its resource URL")
    func readsEvolutionChainIdentifier() async throws {
        let transport = StubHTTPClient(json: JSONFixture.species(evolutionChainID: 42))
        let species = try await LivePokemonService(client: PokeAPIClient(transport: transport)).species(.id(1))

        #expect(species.evolutionChainIdentifier == 42)
    }
}

@Suite("Live service evolution chains")
struct LivePokemonServiceEvolutionTests {
    private static let chainID = 1

    private static func service(
        chain: JSONFixture.Link,
        pokemon: @escaping @Sendable (String) -> String? = { _ in nil }
    ) -> LivePokemonService {
        let transport = StubHTTPClient(responder: { request -> (data: Data, response: HTTPURLResponse) in
            let path = request.url?.path() ?? ""
            let json: String

            if path.hasPrefix("/api/v2/evolution-chain") {
                json = JSONFixture.evolutionChain(id: chainID, chain: chain)
            } else if let name = path.split(separator: "/").last.map(String.init), let body = pokemon(name) {
                json = body
            } else {
                json = "{}"
            }

            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://pokeapi.co")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(json.utf8), response)
        })
        return LivePokemonService(client: PokeAPIClient(transport: transport))
    }

    @Test("Flattens a chain in depth-first order")
    func flattensChain() async throws {
        let chain = JSONFixture.Link.node("bulbasaur", id: 1, evolvesTo: [
            .node("ivysaur", id: 2, details: JSONFixture.evolutionDetail(trigger: "level-up", minLevel: 16), evolvesTo: [
                .node("venusaur", id: 3, details: JSONFixture.evolutionDetail(trigger: "level-up", minLevel: 32))
            ])
        ])

        let stages = try await Self.service(chain: chain).evolutionChain(id: Self.chainID)

        #expect(stages.map(\.id) == [1, 2, 3])
        #expect(stages.map(\.name) == ["bulbasaur", "ivysaur", "venusaur"])
        #expect(stages.map(\.requirement) == [nil, "Lv. 16", "Lv. 32"])
    }

    @Test("Flattens every branch of a splitting chain")
    func flattensBranches() async throws {
        let chain = JSONFixture.Link.node("eevee", id: 133, evolvesTo: [
            .node("vaporeon", id: 134, details: JSONFixture.evolutionDetail(trigger: "use-item", item: "water-stone")),
            .node("jolteon", id: 135, details: JSONFixture.evolutionDetail(trigger: "use-item", item: "thunder-stone")),
            .node("flareon", id: 136, details: JSONFixture.evolutionDetail(trigger: "use-item", item: "fire-stone"))
        ])

        let stages = try await Self.service(chain: chain).evolutionChain(id: Self.chainID)

        #expect(stages.map(\.id) == [133, 134, 135, 136])
        #expect(stages.map(\.requirement) == [nil, "Water Stone", "Thunder Stone", "Fire Stone"])
    }

    @Test("Labels each evolution requirement the way the detail row shows it")
    func labelsRequirements() async throws {
        let cases: [(detail: String, expected: String)] = [
            (JSONFixture.evolutionDetail(trigger: "level-up", minLevel: 16), "Lv. 16"),
            (JSONFixture.evolutionDetail(item: "thunder-stone"), "Thunder Stone"),
            (JSONFixture.evolutionDetail(heldItem: "kings-rock"), "Trade holding Kings Rock"),
            (JSONFixture.evolutionDetail(minHappiness: 220), "Friendship 220"),
            (JSONFixture.evolutionDetail(minAffection: 2), "Affection 2"),
            (JSONFixture.evolutionDetail(minBeauty: 170), "Beauty 170"),
            (JSONFixture.evolutionDetail(knownMove: "ancient-power"), "Knows Ancient Power"),
            (JSONFixture.evolutionDetail(location: "eterna-forest"), "At Eterna Forest"),
            (JSONFixture.evolutionDetail(relativePhysicalStats: 1), "Stat ratio"),
            (JSONFixture.evolutionDetail(trigger: "trade"), "Trade"),
            (JSONFixture.evolutionDetail(trigger: "use-item"), "Use item"),
            (JSONFixture.evolutionDetail(trigger: "shed"), "Empty slot"),
            (JSONFixture.evolutionDetail(trigger: "spin"), "Spin"),
            (JSONFixture.evolutionDetail(trigger: "tower-of-darkness"), "Tower"),
            (JSONFixture.evolutionDetail(trigger: "three-critical-hits"), "3 critical hits"),
            (JSONFixture.evolutionDetail(trigger: "take-damage"), "Take damage"),
            (JSONFixture.evolutionDetail(trigger: "agile-style-move"), "Hisui style"),
            (JSONFixture.evolutionDetail(trigger: "recoil-damage"), "Recoil damage"),
            (JSONFixture.evolutionDetail(trigger: "other-reason"), "Other Reason"),
            (JSONFixture.evolutionDetail(), "Special")
        ]

        for (detail, expected) in cases {
            let chain = JSONFixture.Link.node("base", id: 1, evolvesTo: [
                .node("evolved", id: 2, details: detail)
            ])
            let stages = try await Self.service(chain: chain).evolutionChain(id: Self.chainID)
            #expect(stages.last?.requirement == expected, "\(detail) should read as \(expected)")
        }
    }

    @Test("Decorates each stage with the artwork and types of its own pokemon")
    func decoratesStages() async throws {
        let chain = JSONFixture.Link.node("bulbasaur", id: 1, evolvesTo: [
            .node("ivysaur", id: 2, details: JSONFixture.evolutionDetail(trigger: "level-up", minLevel: 16))
        ])

        let service = Self.service(chain: chain) { name in
            JSONFixture.pokemon(
                id: name == "bulbasaur" ? 1 : 2,
                name: name,
                artwork: "https://art.test/\(name).png",
                types: [(1, name == "bulbasaur" ? "grass" : "poison")]
            )
        }

        let stages = try await service.evolutionChain(id: Self.chainID)

        #expect(stages.map(\.artworkURL?.absoluteString) == [
            "https://art.test/bulbasaur.png",
            "https://art.test/ivysaur.png"
        ])
        #expect(stages.map(\.types) == [[.grass], [.poison]])
    }

    @Test("Leaves a stage undecorated when its pokemon cannot be fetched")
    func leavesUndecoratedStage() async throws {
        let chain = JSONFixture.Link.node("bulbasaur", id: 1, evolvesTo: [
            .node("ivysaur", id: 2, details: JSONFixture.evolutionDetail(trigger: "level-up", minLevel: 16))
        ])

        let stages = try await Self.service(chain: chain).evolutionChain(id: Self.chainID)

        #expect(stages.count == 2)
        #expect(stages.allSatisfy { $0.artworkURL == nil && $0.types.isEmpty })
    }

    @Test("Drops a link the API gave no id for")
    func dropsUnparseableLinks() async throws {
        let brokenChain = JSONFixture.Link(
            species: "missingno",
            id: 0,
            details: "{}",
            evolvesTo: []
        ).json.replacingOccurrences(of: "/0/", with: "/not-a-number/")

        let transport = StubHTTPClient(json: """
        { "id": 1, "chain": \(brokenChain) }
        """)
        let stages = try await LivePokemonService(client: PokeAPIClient(transport: transport))
            .evolutionChain(id: Self.chainID)

        #expect(stages.isEmpty)
    }

    @Test("Reports a lone basic stage with no requirement")
    func reportsLoneStage() async throws {
        let service = Self.service(chain: JSONFixture.Link.node("bulbasaur", id: 1))
        let stages = try await service.evolutionChain(id: Self.chainID)

        #expect(stages.count == 1)
        #expect(stages[0].requirement == nil)
    }
}

@Suite("Cached service")
struct CachedPokemonServiceTests {
    @Test("Serves a repeated request from memory instead of the network")
    func memoisesPokemon() async throws {
        let upstream = RecordingPokemonService(pokemonHandler: { identifier in
            identifier == .id(1) ? bulbasaur : ivysaur
        })
        let service = CachedPokemonService(upstream: upstream)

        let first = try await service.pokemon(.id(1))
        let second = try await service.pokemon(.id(1))

        #expect(first == bulbasaur)
        #expect(second == bulbasaur)
        #expect(upstream.count(of: .pokemon) == 1)
    }

    @Test("Memoises each resource kind separately")
    func memoisesEveryKind() async throws {
        let upstream = RecordingPokemonService(
            pokemonHandler: { _ in bulbasaur },
            speciesHandler: { _ in Fixture.species(id: 1) },
            typesHandler: { [.fire, .water] },
            evolutionHandler: { _ in [Fixture.evolutionStage(id: 1, name: "bulbasaur")] }
        )
        let service = CachedPokemonService(upstream: upstream)

        _ = try await service.pokemon(.id(1))
        _ = try await service.pokemon(.id(1))
        _ = try await service.species(.id(1))
        _ = try await service.species(.id(1))
        _ = try await service.availableTypes()
        _ = try await service.availableTypes()
        _ = try await service.evolutionChain(id: 1)
        _ = try await service.evolutionChain(id: 1)

        #expect(upstream.count(of: .pokemon) == 1)
        #expect(upstream.count(of: .species) == 1)
        #expect(upstream.count(of: .availableTypes) == 1)
        #expect(upstream.count(of: .evolutionChain) == 1)
    }

    @Test("Caches by identifier, so a name and an id are separate entries")
    func cachesByIdentifier() async throws {
        let upstream = RecordingPokemonService(pokemonHandler: { identifier in
            Fixture.pokemon(id: 1, name: identifier == .name("bulbasaur") ? "from-name" : "from-id")
        })
        let service = CachedPokemonService(upstream: upstream)

        let byID = try await service.pokemon(.id(1))
        let byName = try await service.pokemon(.name("bulbasaur"))
        let byIDAgain = try await service.pokemon(.id(1))

        #expect(byID.name == "from-id")
        #expect(byName.name == "from-name")
        #expect(byIDAgain.name == "from-id")
        #expect(upstream.count(of: .pokemon) == 2)
    }

    @Test("Coalesces concurrent requests for the same resource into one download")
    func coalescesConcurrentRequests() async throws {
        let upstream = RecordingPokemonService(pokemonHandler: { _ in
            try? await Task.sleep(for: .milliseconds(60))
            return bulbasaur
        })
        let service = CachedPokemonService(upstream: upstream)

        async let first = service.pokemon(.id(1))
        async let second = service.pokemon(.id(1))
        async let third = service.pokemon(.id(1))
        let results = try await [first, second, third]

        #expect(results.allSatisfy { $0 == bulbasaur })
        #expect(upstream.count(of: .pokemon) == 1)
    }

    @Test("Does not cache a failure, so a retry reaches the network again")
    func doesNotCacheFailures() async throws {
        let attempts = AttemptCounter()
        let upstream = RecordingPokemonService(pokemonHandler: { _ in
            guard attempts.next() > 1 else { throw PokeAPIError.transport(description: "offline") }
            return bulbasaur
        })
        let service = CachedPokemonService(upstream: upstream)

        await #expect(throws: PokeAPIError.transport(description: "offline")) {
            _ = try await service.pokemon(.id(1))
        }
        let recovered = try await service.pokemon(.id(1))

        #expect(recovered == bulbasaur)
        #expect(upstream.count(of: .pokemon) == 2)
    }

    @Test("Never caches a page, because pages advance and pull-to-refresh must refetch")
    func neverCachesPages() async throws {
        let upstream = RecordingPokemonService(pageHandler: { request in
            Fixture.page(
                [Fixture.feedItem(id: (request.offset ?? 0) + 1)],
                nextPageURL: URL(string: "https://pokeapi.co/api/v2/pokemon?limit=1&offset=1"),
                totalCount: 3
            )
        })
        let service = CachedPokemonService(upstream: upstream)

        _ = try await service.pokemonPage(limit: 1, offset: 0)
        _ = try await service.pokemonPage(limit: 1, offset: 0)
        _ = try await service.pokemonPage(following: URL(string: "https://pokeapi.co/api/v2/pokemon?limit=1&offset=1")!)
        _ = try await service.pokemonPage(following: URL(string: "https://pokeapi.co/api/v2/pokemon?limit=1&offset=1")!)

        #expect(upstream.count(of: .page) == 4)
    }

    @Test("Passes a failure straight through")
    func propagatesFailures() async {
        let upstream = RecordingPokemonService(pokemonHandler: { _ in throw PokeAPIError.notFound })
        let service = CachedPokemonService(upstream: upstream)

        await #expect(throws: PokeAPIError.notFound) {
            _ = try await service.pokemon(.id(9999))
        }
    }
}

@Suite("Resource memo")
struct ResourceMemoTests {
    @Test("Loads once and serves the value again")
    func loadsOnce() async throws {
        let memo = ResourceMemo<String, Int>()
        let counter = AttemptCounter()

        let first = try await memo.value(for: "key") { counter.next() }
        let second = try await memo.value(for: "key") { counter.next() }

        #expect(first == 1)
        #expect(second == 1)
        #expect(counter.value == 1)
    }

    @Test("Coalesces concurrent loads of one key into a single call")
    func coalescesConcurrentLoads() async throws {
        let memo = ResourceMemo<String, Int>()
        let counter = AttemptCounter()

        async let first = memo.value(for: "key") {
            let attempt = counter.next()
            try? await Task.sleep(for: .milliseconds(60))
            return attempt
        }
        async let second = memo.value(for: "key") {
            let attempt = counter.next()
            try? await Task.sleep(for: .milliseconds(60))
            return attempt
        }
        let values = try await [first, second]

        #expect(values[0] == values[1])
        #expect(counter.value == 1)
    }

    @Test("Keeps keys independent")
    func keepsKeysIndependent() async throws {
        let memo = ResourceMemo<String, Int>()

        _ = try await memo.value(for: "first") { 1 }
        _ = try await memo.value(for: "second") { 2 }

        #expect(try await memo.value(for: "first") { 99 } == 1)
        #expect(try await memo.value(for: "second") { 99 } == 2)
    }

    @Test("Does not remember a failure")
    func doesNotRememberFailures() async throws {
        let memo = ResourceMemo<String, Int>()

        await #expect(throws: PokeAPIError.notFound) {
            _ = try await memo.value(for: "key") { throw PokeAPIError.notFound }
        }

        let recovered = try await memo.value(for: "key") { 7 }
        #expect(recovered == 7)
    }

    @Test("Clears the in-flight entry after a failure so the next caller retries")
    func clearsInFlightAfterFailure() async throws {
        let memo = ResourceMemo<String, Int>()
        let counter = AttemptCounter()

        await #expect(throws: PokeAPIError.notFound) {
            _ = try await memo.value(for: "key") {
                _ = counter.next()
                throw PokeAPIError.notFound
            }
        }
        _ = try await memo.value(for: "key") { counter.next() }

        #expect(counter.value == 2)
    }
}

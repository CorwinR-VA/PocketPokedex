import Foundation

nonisolated struct LivePokemonService: PokemonService {
    private let client: PokeAPIClient

    init(client: PokeAPIClient = PokeAPIClient()) {
        self.client = client
    }

    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        let payload: ResourceListPayload = try await client.get(.pokemonList(limit: limit, offset: offset))
        return mapList(payload)
    }

    func pokemonPage(following url: URL) async throws -> PokemonPage {
        let payload: ResourceListPayload = try await client.get(.resource(url))
        return mapList(payload)
    }

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon {
        let payload: PokemonPayload = try await client.get(.pokemon(identifier))
        return Self.mapPokemon(payload)
    }

    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies {
        do {
            let payload: PokemonSpeciesPayload = try await client.get(.pokemonSpecies(identifier))
            return Self.mapSpecies(payload)
        } catch PokeAPIError.notFound {
            // A form has a /pokemon entry but no /pokemon-species one of its own: #10321 is
            // glimmora-mega, while /pokemon-species/970 is glimmora. Its own payload names the
            // species it belongs to, so follow that instead of failing the screen.
            guard let speciesIdentifier = try await speciesIdentifier(for: identifier) else {
                throw PokeAPIError.notFound
            }
            let payload: PokemonSpeciesPayload = try await client.get(.pokemonSpecies(.id(speciesIdentifier)))
            return Self.mapSpecies(payload)
        }
    }

    private func speciesIdentifier(for identifier: PokemonIdentifier) async throws -> Int? {
        let payload: PokemonPayload = try await client.get(.pokemon(identifier))
        return Self.identifier(fromResourceURL: payload.species.url)
    }

    func availableTypes() async throws -> [PokemonType] {
        let payload: ResourceListPayload = try await client.get(.typeList)
        let known = Set(payload.results.compactMap { PokemonType(apiName: $0.name) })
        guard !known.isEmpty else { return PokemonType.allCases }
        return PokemonType.allCases.filter(known.contains)
    }

    func evolutionChain(id: Int) async throws -> [EvolutionLine] {
        let payload: EvolutionChainPayload = try await client.get(.evolutionChain(id: id))
        let routes = Self.routes(in: payload.chain, requirement: nil)
        guard !routes.isEmpty else { return [] }

        // Decorate each Pokémon once and drop it back into every route that passes through it: the
        // routes of a branching chain share their base form and often a branch point, and Eevee's
        // eight routes would otherwise fetch the same artwork eight times.
        let undecorated = routes.flatMap { $0 }
        var seen: Set<Int> = []
        let unique = undecorated.filter { seen.insert($0.id).inserted }

        let decorated = await withBoundedTaskGroup(over: unique, maxConcurrent: 4) { stage -> EvolutionStage in
            guard let pokemon = try? await pokemon(.name(stage.name)) else { return stage }
            return EvolutionStage(
                id: stage.id,
                name: stage.name,
                artworkURL: pokemon.artworkURL ?? pokemon.thumbnailURL,
                types: pokemon.types,
                requirement: stage.requirement
            )
        }

        let byID = Dictionary(decorated.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return routes.map { route in
            EvolutionLine(stages: route.map { byID[$0.id] ?? $0 })
        }
    }

    private func mapList(_ payload: ResourceListPayload) -> PokemonPage {
        let items = payload.results.compactMap { resource -> PokemonFeedItem? in
            guard let id = Self.identifier(fromResourceURL: resource.url) else { return nil }
            return PokemonFeedItem(id: id, name: resource.name)
        }
        return PokemonPage(items: items, nextPageURL: payload.next, totalCount: payload.count)
    }

    private static func mapPokemon(_ payload: PokemonPayload) -> Pokemon {
        let artwork = payload.sprites.other?.officialArtwork?.frontDefault
            ?? payload.sprites.other?.home?.frontDefault
            ?? payload.sprites.frontDefault

        let types = payload.types
            .sorted { $0.slot < $1.slot }
            .compactMap { PokemonType(apiName: $0.type.name) }

        let abilities = payload.abilities
            .sorted { $0.slot < $1.slot }
            .map { PokemonAbility(name: $0.ability.name, isHidden: $0.isHidden) }

        let stats = StatKind.allCases.compactMap { kind -> PokemonStat? in
            guard let match = payload.stats.first(where: { $0.stat.name == kind.rawValue }) else { return nil }
            return PokemonStat(kind: kind, baseValue: match.baseStat)
        }

        return Pokemon(
            id: payload.id,
            name: payload.name,
            types: types,
            artworkURL: artwork,
            thumbnailURL: payload.sprites.frontDefault,
            heightInMetres: Double(payload.height) / 10,
            weightInKilograms: Double(payload.weight) / 10,
            baseExperience: payload.baseExperience,
            abilities: abilities,
            stats: stats,
            moves: levelUpMoves(from: payload)
        )
    }

    private static func levelUpMoves(from payload: PokemonPayload) -> [PokemonMove] {
        var earliestLevel: [String: Int] = [:]
        var apiOrder: [String] = []

        for entry in payload.moves {
            let name = entry.move.name
            let levels: [Int] = entry.versionGroupDetails
                .filter { $0.moveLearnMethod.name == "level-up" && $0.levelLearnedAt > 0 }
                .map(\.levelLearnedAt)
            guard let level = levels.min() else { continue }

            if earliestLevel[name] == nil {
                apiOrder.append(name)
                earliestLevel[name] = level
            } else if level < (earliestLevel[name] ?? level) {
                earliestLevel[name] = level
            }
        }

        var moves: [PokemonMove] = []
        moves.reserveCapacity(apiOrder.count)
        for name in apiOrder {
            moves.append(PokemonMove(name: name, level: earliestLevel[name] ?? 1))
        }

        let indexed = Array(moves.enumerated())
        let ordered = indexed.sorted { lhs, rhs in
            lhs.element.level == rhs.element.level
                ? lhs.offset < rhs.offset
                : lhs.element.level < rhs.element.level
        }
        return ordered.map(\.element)
    }

    private static func mapSpecies(_ payload: PokemonSpeciesPayload) -> PokemonSpecies {
        PokemonSpecies(
            id: payload.id,
            genus: payload.genera.first { $0.language.name == "en" }?.genus,
            flavorText: englishFlavorText(from: payload),
            captureRate: payload.captureRate,
            growthRate: payload.growthRate?.name.pokemonDisplayName,
            evolutionChainIdentifier: payload.evolutionChain.flatMap { identifier(fromResourceURL: $0.url) }
        )
    }

    private static func englishFlavorText(from payload: PokemonSpeciesPayload) -> String? {
        let english = payload.flavorTextEntries.filter { $0.language.name == "en" }
        guard let entry = english.first ?? payload.flavorTextEntries.first else { return nil }
        return entry.flavorText
            .replacing("\n", with: " ")
            .replacing("\u{0C}", with: " ")
            .replacing("\r", with: " ")
            .replacing("\u{00AD}", with: "")
            .replacing("POKéMON", with: "Pokémon")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Every route from this link down to a leaf, each one starting with this link's own stage. A link
    /// with no children is a route on its own, which is what makes a leaf the end of a line.
    private static func routes(
        in link: EvolutionLinkPayload,
        requirement: String?
    ) -> [[EvolutionStage]] {
        guard let id = identifier(fromResourceURL: link.species.url) else { return [] }

        let stage = EvolutionStage(
            id: id,
            name: link.species.name,
            artworkURL: nil,
            types: [],
            requirement: requirement
        )

        let branches = link.evolvesTo.map { child in
            routes(
                in: child,
                requirement: child.evolutionDetails.first.map(requirementLabel(for:)) ?? "Special"
            )
        }

        guard !branches.isEmpty else { return [[stage]] }
        return branches.flatMap { branch in branch.map { [stage] + $0 } }
    }

    private static func requirementLabel(for detail: EvolutionDetailPayload) -> String {
        if let level = detail.minLevel { return "Lv. \(level)" }
        if let item = detail.item { return item.name.pokemonDisplayName }
        if let held = detail.heldItem { return "Trade holding \(held.name.pokemonDisplayName)" }
        if let happiness = detail.minHappiness { return "Friendship \(happiness)" }
        if let affection = detail.minAffection { return "Affection \(affection)" }
        if let beauty = detail.minBeauty { return "Beauty \(beauty)" }
        if let move = detail.knownMove { return "Knows \(move.name.pokemonDisplayName)" }
        if let location = detail.location { return "At \(location.name.pokemonDisplayName)" }
        if detail.relativePhysicalStats != nil { return "Stat ratio" }
        if let trigger = detail.trigger {
            switch trigger.name {
            case "trade": return "Trade"
            case "use-item": return "Use item"
            case "shed": return "Empty slot"
            case "spin": return "Spin"
            case "tower-of-darkness", "tower-of-waters": return "Tower"
            case "three-critical-hits": return "3 critical hits"
            case "take-damage": return "Take damage"
            case "agile-style-move", "strong-style-move": return "Hisui style"
            case "recoil-damage": return "Recoil damage"
            default: return trigger.name.pokemonDisplayName
            }
        }
        return "Special"
    }

    private static func identifier(fromResourceURL url: URL) -> Int? {
        Int(url.lastPathComponent)
    }
}

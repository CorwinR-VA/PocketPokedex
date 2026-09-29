import Foundation
import Testing
@testable import PocketPokedex

// MARK: - Awaiting

/// Polls `condition` until it holds or `timeout` elapses, then returns whether it held.
///
/// Used only where the code under test hands work to an unstructured `Task` that the
/// test cannot await directly (card hydration, for example). Everything else awaits.
@MainActor
@discardableResult
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

// MARK: - Networking

/// An `HTTPClient` that answers from a closure instead of a socket, and keeps the
/// requests it was handed so a test can assert on what the client actually sent.
nonisolated final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    typealias Responder = @Sendable (URLRequest) async throws -> (data: Data, response: HTTPURLResponse)

    private let lock = NSLock()
    private let responder: Responder
    private var recordedRequests: [URLRequest] = []

    init(responder: @escaping Responder) {
        self.responder = responder
    }

    /// Answers every request with `json` and the given status code.
    init(json: String, statusCode: Int = 200) {
        let data = Data(json.utf8)
        self.responder = { request in
            (data, Self.response(for: request, statusCode: statusCode))
        }
    }

    /// Fails every request with `error`.
    init(throwing error: any Error) {
        self.responder = { _ in throw error }
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        remember(request)
        return try await responder(request)
    }

    private func remember(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        recordedRequests.append(request)
    }

    private static func response(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://pokeapi.co")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

// MARK: - PokemonService

/// A `PokemonService` that answers from closures and records what it was asked for.
nonisolated final class RecordingPokemonService: PokemonService, @unchecked Sendable {
    typealias PageHandler = @Sendable (PageRequest) async throws -> PokemonPage

    struct PageRequest: Equatable, Sendable {
        /// The requested offset, or `nil` when the caller followed a `next` URL.
        let offset: Int?
        let limit: Int?
        let followedURL: URL?

        static func offset(_ offset: Int, limit: Int) -> PageRequest {
            PageRequest(offset: offset, limit: limit, followedURL: nil)
        }

        static func following(_ url: URL) -> PageRequest {
            PageRequest(offset: nil, limit: nil, followedURL: url)
        }
    }

    enum Call: String, Sendable {
        case page, pokemon, species, availableTypes, evolutionChain
    }

    private struct State {
        var counts: [Call: Int] = [:]
        var pageRequests: [PageRequest] = []
        var pokemonIdentifiers: [PokemonIdentifier] = []
        var evolutionChainIdentifiers: [Int] = []
    }

    private let lock = NSLock()
    private var state = State()

    private let pageHandler: PageHandler?
    private let pokemonHandler: (@Sendable (PokemonIdentifier) async throws -> Pokemon)?
    private let speciesHandler: (@Sendable (PokemonIdentifier) async throws -> PokemonSpecies)?
    private let typesHandler: (@Sendable () async throws -> [PokemonType])?
    private let evolutionHandler: (@Sendable (Int) async throws -> [EvolutionStage])?

    init(
        pageHandler: PageHandler? = nil,
        pokemonHandler: (@Sendable (PokemonIdentifier) async throws -> Pokemon)? = nil,
        speciesHandler: (@Sendable (PokemonIdentifier) async throws -> PokemonSpecies)? = nil,
        typesHandler: (@Sendable () async throws -> [PokemonType])? = nil,
        evolutionHandler: (@Sendable (Int) async throws -> [EvolutionStage])? = nil
    ) {
        self.pageHandler = pageHandler
        self.pokemonHandler = pokemonHandler
        self.speciesHandler = speciesHandler
        self.typesHandler = typesHandler
        self.evolutionHandler = evolutionHandler
    }

    /// The call counts, keyed by kind, for assertions about caching and coalescing.
    var callCounts: [Call: Int] { withLock { $0.counts } }

    var recordedPageRequests: [PageRequest] { withLock { $0.pageRequests } }

    var requestedPokemonIdentifiers: [PokemonIdentifier] { withLock { $0.pokemonIdentifiers } }

    var requestedEvolutionChainIdentifiers: [Int] { withLock { $0.evolutionChainIdentifiers } }

    func count(of call: Call) -> Int { withLock { $0.counts[call] ?? 0 } }

    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage {
        record { state in
            state.counts[.page, default: 0] += 1
            state.pageRequests.append(.offset(offset, limit: limit))
        }
        guard let pageHandler else { throw PokeAPIError.invalidRequest }
        return try await pageHandler(.offset(offset, limit: limit))
    }

    func pokemonPage(following url: URL) async throws -> PokemonPage {
        record { state in
            state.counts[.page, default: 0] += 1
            state.pageRequests.append(.following(url))
        }
        guard let pageHandler else { throw PokeAPIError.invalidRequest }
        return try await pageHandler(.following(url))
    }

    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon {
        record { state in
            state.counts[.pokemon, default: 0] += 1
            state.pokemonIdentifiers.append(identifier)
        }
        guard let pokemonHandler else { throw PokeAPIError.invalidRequest }
        return try await pokemonHandler(identifier)
    }

    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies {
        record { state in
            state.counts[.species, default: 0] += 1
        }
        guard let speciesHandler else { throw PokeAPIError.invalidRequest }
        return try await speciesHandler(identifier)
    }

    func availableTypes() async throws -> [PokemonType] {
        record { $0.counts[.availableTypes, default: 0] += 1 }
        guard let typesHandler else { throw PokeAPIError.invalidRequest }
        return try await typesHandler()
    }

    func evolutionChain(id: Int) async throws -> [EvolutionStage] {
        record { state in
            state.counts[.evolutionChain, default: 0] += 1
            state.evolutionChainIdentifiers.append(id)
        }
        guard let evolutionHandler else { throw PokeAPIError.invalidRequest }
        return try await evolutionHandler(id)
    }

    private func record(_ mutate: (inout State) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutate(&state)
    }

    private func withLock<T>(_ body: (State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(state)
    }
}

// MARK: - Locale-dependent expectations

/// Renders a measurement string the way `MeasurementFormat` does, so an assertion is about the
/// unit and the digit count rather than about the machine's decimal separator.
///
/// `MeasurementFormat` deliberately follows the device locale, so a pinned `"0.7 m"` literal
/// would fail the moment the suite runs on a comma-decimal machine.
nonisolated enum LocalizedNumber {
    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// The locale's thousands separator, or `nil` when it groups with nothing.
    static var groupingSeparator: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        let separator = formatter.groupingSeparator
        return (separator?.isEmpty ?? true) ? nil : separator
    }
}

// MARK: - Counting

/// Hands out 1, 2, 3… so a stub can fail once and succeed afterwards.
nonisolated final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        attempts += 1
        return attempts
    }

    /// How many times `next()` has been called.
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return attempts
    }
}

// MARK: - Fixtures

/// Builders for domain values, callable from a test and from a stub's sendable closure alike.
nonisolated enum Fixture {
    /// A `UserDefaults` suite that belongs to one test and is wiped before use.
    static func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: name) else {
            Issue.record("Could not create a UserDefaults suite named \(name)")
            return .standard
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func feedItem(
        id: Int,
        name: String? = nil,
        types: [PokemonType] = [],
        artworkURL: URL? = nil
    ) -> PokemonFeedItem {
        PokemonFeedItem(
            id: id,
            name: name ?? "pokemon-\(id)",
            types: types,
            artworkURL: artworkURL
        )
    }

    static func page(
        _ items: [PokemonFeedItem],
        nextPageURL: URL? = nil,
        totalCount: Int = 1_351
    ) -> PokemonPage {
        PokemonPage(items: items, nextPageURL: nextPageURL, totalCount: totalCount)
    }

    static func pokemon(
        id: Int,
        name: String = "bulbasaur",
        types: [PokemonType] = [.grass, .poison],
        artworkURL: URL? = nil,
        thumbnailURL: URL? = nil,
        heightInMetres: Double = 0.7,
        weightInKilograms: Double = 6.9,
        baseExperience: Int? = 64,
        abilities: [PokemonAbility] = [],
        stats: [PokemonStat] = [],
        moves: [PokemonMove] = []
    ) -> Pokemon {
        Pokemon(
            id: id,
            name: name,
            types: types,
            artworkURL: artworkURL,
            thumbnailURL: thumbnailURL,
            heightInMetres: heightInMetres,
            weightInKilograms: weightInKilograms,
            baseExperience: baseExperience,
            abilities: abilities,
            stats: stats,
            moves: moves
        )
    }

    static func species(
        id: Int,
        genus: String? = "Seed Pokémon",
        flavorText: String? = "A strange seed was planted on its back.",
        captureRate: Int = 45,
        growthRate: String? = "Medium Slow",
        evolutionChainIdentifier: Int? = 1
    ) -> PokemonSpecies {
        PokemonSpecies(
            id: id,
            genus: genus,
            flavorText: flavorText,
            captureRate: captureRate,
            growthRate: growthRate,
            evolutionChainIdentifier: evolutionChainIdentifier
        )
    }

    static func evolutionStage(
        id: Int,
        name: String,
        artworkURL: URL? = nil,
        types: [PokemonType] = [],
        requirement: String? = nil
    ) -> EvolutionStage {
        EvolutionStage(
            id: id,
            name: name,
            artworkURL: artworkURL,
            types: types,
            requirement: requirement
        )
    }
}

// MARK: - JSON fixtures for the wire layer

enum JSONFixture {
    /// A `/pokemon/{id}` response. Every nested object has a sensible PokeAPI-shaped default.
    static func pokemon(
        id: Int = 1,
        name: String = "bulbasaur",
        baseExperience: Int? = 64,
        height: Int = 7,
        weight: Int = 69,
        artwork: String? = "https://art.test/official/1.png",
        home: String? = "https://art.test/home/1.png",
        frontDefault: String? = "https://art.test/front/1.png",
        types: [(slot: Int, name: String)] = [(1, "grass"), (2, "poison")],
        stats: [(name: String, baseStat: Int)] = [
            ("hp", 45), ("attack", 49), ("defense", 49),
            ("special-attack", 65), ("special-defense", 65), ("speed", 45)
        ],
        abilities: [(slot: Int, name: String, isHidden: Bool)] = [(1, "overgrow", false)],
        moves: [Move] = []
    ) -> String {
        let spriteOthers: String = {
            var parts: [String] = []
            if let artwork { parts.append(#""official-artwork": { "front_default": "\#(jsonString(artwork))" }"#) }
            if let home { parts.append(#""home": { "front_default": "\#(jsonString(home))" }"#) }
            return "{ \(parts.joined(separator: ", ")) }"
        }()

        let typeSlots = types
            .map { #"{ "slot": \#($0.slot), "type": { "name": "\#(jsonString($0.name))", "url": "https://pokeapi.co/api/v2/type/\#(jsonString($0.name))/" } }"# }
            .joined(separator: ", ")

        let statSlots = stats
            .map { #"{ "base_stat": \#($0.baseStat), "effort": 0, "stat": { "name": "\#(jsonString($0.name))", "url": "https://pokeapi.co/api/v2/stat/\#(jsonString($0.name))/" } }"# }
            .joined(separator: ", ")

        let abilitySlots = abilities
            .map { #"{ "slot": \#($0.slot), "is_hidden": \#($0.isHidden), "ability": { "name": "\#(jsonString($0.name))", "url": "https://pokeapi.co/api/v2/ability/\#(jsonString($0.name))/" } }"# }
            .joined(separator: ", ")

        let moveEntries = moves.map(\.json).joined(separator: ", ")

        return """
        {
          "id": \(id),
          "name": "\(jsonString(name))",
          "base_experience": \(baseExperience.map(String.init) ?? "null"),
          "height": \(height),
          "weight": \(weight),
          "sprites": {
            "front_default": \(frontDefault.map { "\"\(jsonString($0))\"" } ?? "null"),
            "back_default": null,
            "other": \(spriteOthers),
            "versions": { "generation-i": { "red-blue": { "front_default": null } } }
          },
          "types": [\(typeSlots)],
          "stats": [\(statSlots)],
          "abilities": [\(abilitySlots)],
          "moves": [\(moveEntries)]
        }
        """
    }

    /// One entry of the `moves` array: a move plus the version groups that teach it.
    struct Move {
        let name: String
        /// `(learn method, level)` pairs. Methods other than `level-up` exercise the filter.
        let details: [(method: String, level: Int)]

        static func levelUp(_ name: String, at level: Int) -> Move {
            Move(name: name, details: [("level-up", level)])
        }

        static func levelUp(_ name: String, in versions: [(String, Int)]) -> Move {
            Move(name: name, details: versions.map { ("level-up", $0.1) })
        }

        var json: String {
            let details = self.details
                .map { #"{ "level_learned_at": \#($0.level), "move_learn_method": { "name": "\#($0.method)", "url": "https://pokeapi.co/api/v2/move-learn-method/\#($0.method)/" }, "version_group": { "name": "scarlet-violet", "url": "https://pokeapi.co/api/v2/version-group/25/" } }"# }
                .joined(separator: ", ")
            return #"{ "move": { "name": "\#(jsonString(name))", "url": "https://pokeapi.co/api/v2/move/\#(jsonString(name))/" }, "version_group_details": [\#(details)] }"#
        }
    }

    /// A `/pokemon-species/{id}` response.
    static func species(
        id: Int = 1,
        captureRate: Int = 45,
        growthRate: String? = "medium-slow",
        evolutionChainID: Int? = 1,
        genera: [(language: String, genus: String)] = [("en", "Seed Pokémon")],
        flavorTexts: [(language: String, text: String)] = [("en", "A strange seed was planted.")]
    ) -> String {
        let genusEntries = genera
            .map { #"{ "genus": "\#(jsonString($0.genus))", "language": { "name": "\#(jsonString($0.language))", "url": "https://pokeapi.co/api/v2/language/9/" } }"# }
            .joined(separator: ", ")

        let flavorEntries = flavorTexts
            .map { #"{ "flavor_text": "\#(jsonString($0.text))", "language": { "name": "\#(jsonString($0.language))", "url": "https://pokeapi.co/api/v2/language/9/" }, "version": { "name": "red", "url": "https://pokeapi.co/api/v2/version/1/" } }"# }
            .joined(separator: ", ")

        let chain = evolutionChainID
            .map { #""evolution_chain": { "url": "https://pokeapi.co/api/v2/evolution-chain/\#($0)/" }"# }
            ?? #""evolution_chain": null"#

        return """
        {
          "id": \(id),
          "name": "bulbasaur",
          "capture_rate": \(captureRate),
          "growth_rate": \(growthRate.map { "{ \"name\": \"\($0)\", \"url\": \"https://pokeapi.co/api/v2/growth-rate/4/\" }" } ?? "null"),
          "genera": [\(genusEntries)],
          "flavor_text_entries": [\(flavorEntries)],
          \(chain)
        }
        """
    }

    /// A `/type` (or `/pokemon`) list response.
    static func resourceList(
        count: Int = 1_351,
        next: String? = nil,
        results: [(name: String, url: String)]
    ) -> String {
        let entries = results
            .map { #"{ "name": "\#(jsonString($0.name))", "url": "\#(jsonString($0.url))" }"# }
            .joined(separator: ", ")
        return """
        {
          "count": \(count),
          "next": \(next.map { "\"\($0)\"" } ?? "null"),
          "previous": null,
          "results": [\(entries)]
        }
        """
    }

    /// An evolution-chain link. `details` is rendered as the first (and only) `evolution_details` entry.
    struct Link {
        let species: String
        let id: Int
        var details: String = "{}"
        var evolvesTo: [Link] = []

        static func node(
            _ species: String,
            id: Int,
            details: String = "{}",
            evolvesTo: [Link] = []
        ) -> Link {
            Link(species: species, id: id, details: details, evolvesTo: evolvesTo)
        }

        var json: String {
            let children = evolvesTo.map(\.json).joined(separator: ", ")
            return """
            {
              "species": { "name": "\(jsonString(species))", "url": "https://pokeapi.co/api/v2/pokemon-species/\(id)/" },
              "evolution_details": [\(details)],
              "evolves_to": [\(children)]
            }
            """
        }
    }

    /// An `/evolution-chain/{id}` response.
    static func evolutionChain(id: Int = 1, chain: Link) -> String {
        """
        { "id": \(id), "baby_trigger_item": null, "chain": \(chain.json) }
        """
    }

    /// A single `evolution_details` entry, as the API sends it.
    static func evolutionDetail(
        trigger: String? = nil,
        minLevel: Int? = nil,
        minHappiness: Int? = nil,
        minAffection: Int? = nil,
        minBeauty: Int? = nil,
        item: String? = nil,
        heldItem: String? = nil,
        knownMove: String? = nil,
        location: String? = nil,
        relativePhysicalStats: Int? = nil
    ) -> String {
        func named(_ key: String, _ value: String) -> String {
            #""\#(key)": { "name": "\#(jsonString(value))", "url": "https://pokeapi.co/api/v2/x/\#(jsonString(value))/" }"#
        }
        var parts: [String] = []
        if let trigger { parts.append(named("trigger", trigger)) }
        if let item { parts.append(named("item", item)) }
        if let heldItem { parts.append(named("held_item", heldItem)) }
        if let knownMove { parts.append(named("known_move", knownMove)) }
        if let location { parts.append(named("location", location)) }
        if let minLevel { parts.append(#""min_level": \#(minLevel)"#) }
        if let minHappiness { parts.append(#""min_happiness": \#(minHappiness)"#) }
        if let minAffection { parts.append(#""min_affection": \#(minAffection)"#) }
        if let minBeauty { parts.append(#""min_beauty": \#(minBeauty)"#) }
        if let relativePhysicalStats { parts.append(#""relative_physical_stats": \#(relativePhysicalStats)"#) }
        parts.append(#""turn_upside_down": false"#)
        return "{ \(parts.joined(separator: ", ")) }"
    }

    /// Escapes a value for embedding in a JSON string literal.
    ///
    /// PokeAPI's flavour text really does carry form feeds, newlines and soft hyphens,
    /// and those have to arrive as `\f`, `\n` and `\u00ad` rather than raw characters.
    static func jsonString(_ raw: String) -> String {
        var escaped = ""
        for character in raw.unicodeScalars {
            switch character {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            case "\u{0C}": escaped += "\\f"
            case "\u{08}": escaped += "\\b"
            default:
                if character.value < 0x20 {
                    escaped += String(format: "\\u%04x", character.value)
                } else {
                    escaped.unicodeScalars.append(character)
                }
            }
        }
        return escaped
    }

    static func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(json.utf8))
    }
}

import Foundation
import Testing
@testable import PocketPokedex

@Suite("PokeAPI endpoints")
struct PokeAPIEndpointTests {
    @Test("Builds a paged pokemon list URL")
    func buildsListURL() {
        let url = PokeAPIEndpoint.pokemonList(limit: 40, offset: 80).url
        #expect(url.absoluteString == "https://pokeapi.co/api/v2/pokemon?limit=40&offset=80")
    }

    @Test("Builds a pokemon URL from an id")
    func buildsPokemonURLFromID() {
        #expect(PokeAPIEndpoint.pokemon(.id(25)).url.absoluteString == "https://pokeapi.co/api/v2/pokemon/25")
    }

    @Test("Lowercases a name in a path component")
    func lowercasesNameIdentifier() {
        #expect(PokemonIdentifier.name("Pikachu").pathComponent == "pikachu")
        #expect(PokemonIdentifier.id(25).pathComponent == "25")
        #expect(PokeAPIEndpoint.pokemon(.name("Mr-Mime")).url.absoluteString == "https://pokeapi.co/api/v2/pokemon/mr-mime")
    }

    @Test("Builds the remaining routes exactly as PokeAPI spells them")
    func buildsRemainingRoutes() {
        #expect(PokeAPIEndpoint.pokemonSpecies(.id(1)).url.absoluteString == "https://pokeapi.co/api/v2/pokemon-species/1")
        #expect(PokeAPIEndpoint.typeList.url.absoluteString == "https://pokeapi.co/api/v2/type")
        #expect(PokeAPIEndpoint.evolutionChain(id: 3).url.absoluteString == "https://pokeapi.co/api/v2/evolution-chain/3")
    }

    @Test("Passes a pagination URL straight through")
    func followsResourceURL() {
        let next = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=40&offset=40")!
        #expect(PokeAPIEndpoint.resource(next).url == next)
    }

    @Test("Identifiers compare by case and payload")
    func identifiersAreHashable() {
        #expect(PokemonIdentifier.id(25) == PokemonIdentifier.id(25))
        #expect(PokemonIdentifier.id(25) != PokemonIdentifier.id(26))
        #expect(PokemonIdentifier.name("pikachu") != PokemonIdentifier.id(25))
        #expect(Set([PokemonIdentifier.id(1), .id(1), .name("bulbasaur")]).count == 2)
    }

    @Test("Builds a GET request with JSON accept, a cache policy and a timeout")
    func buildsRequest() throws {
        let request = try PokeAPIEndpoint.pokemon(.id(1)).makeRequest()
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.cachePolicy == .returnCacheDataElseLoad)
        #expect(request.timeoutInterval == 20)
        #expect(request.url?.absoluteString == "https://pokeapi.co/api/v2/pokemon/1")
    }
}

@Suite("PokeAPI errors")
struct PokeAPIErrorTests {
    @Test("Passes an existing PokeAPIError through untouched")
    func passesThrough() {
        #expect(PokeAPIError.from(PokeAPIError.notFound) == .notFound)
        #expect(PokeAPIError.from(PokeAPIError.httpStatus(code: 503)) == .httpStatus(code: 503))
    }

    @Test("Folds a cancellation error into cancelled")
    func mapsCancellation() {
        #expect(PokeAPIError.from(CancellationError()) == .cancelled)
        #expect(PokeAPIError.from(URLError(.cancelled)) == .cancelled)
    }

    @Test("Folds a URL error into a transport failure")
    func mapsURLError() {
        guard case .transport = PokeAPIError.from(URLError(.notConnectedToInternet)) else {
            Issue.record("Expected a transport failure")
            return
        }
    }

    @Test("Folds a decoding error into a decoding failure that names the key and path")
    func mapsDecodingError() {
        struct Payload: Decodable { let value: Int }
        let json = Data(#"{ "nested": { "other": 1 } }"#.utf8)

        do {
            _ = try JSONDecoder().decode(Payload.self, from: json)
            Issue.record("Expected decoding to fail")
        } catch {
            guard case .decodingFailed(let description) = PokeAPIError.from(error) else {
                Issue.record("Expected a decoding failure, got \(PokeAPIError.from(error))")
                return
            }
            #expect(description.contains("missing key"))
            #expect(description.contains("'value'"))
        }
    }

    @Test("Describes every case for the developer")
    func describesEveryCase() {
        #expect(PokeAPIError.invalidRequest.errorDescription == "The request could not be built.")
        #expect(PokeAPIError.invalidResponse.errorDescription == "The server returned an unexpected response.")
        #expect(PokeAPIError.httpStatus(code: 500).errorDescription == "The server responded with status code 500.")
        #expect(PokeAPIError.notFound.errorDescription == "That Pokémon could not be found.")
        #expect(PokeAPIError.cancelled.errorDescription == "The request was cancelled.")
        #expect(PokeAPIError.transport(description: "offline").errorDescription == "Network error: offline")
        #expect(PokeAPIError.decodingFailed(description: "x").errorDescription == "The data could not be read: x")
    }

    @Test("Tells the user what they can act on")
    func describesUserFacingMessages() {
        #expect(PokeAPIError.transport(description: "offline").userFacingMessage == "Check your connection and try again.")
        #expect(PokeAPIError.notFound.userFacingMessage == "We couldn't find that Pokémon.")
        #expect(PokeAPIError.httpStatus(code: 500).userFacingMessage == "Something went wrong while loading Pokémon data.")
        #expect(PokeAPIError.cancelled.userFacingMessage == "Something went wrong while loading Pokémon data.")
    }
}

@Suite("PokeAPI client")
struct PokeAPIClientTests {
    @Test("Decodes a 200 response, converting snake_case keys")
    func decodesSuccessfulResponse() async throws {
        let client = PokeAPIClient(transport: StubHTTPClient(json: JSONFixture.resourceList(
            count: 2,
            results: [
                ("bulbasaur", "https://pokeapi.co/api/v2/pokemon/1/"),
                ("ivysaur", "https://pokeapi.co/api/v2/pokemon/2/")
            ]
        )))

        let payload: ResourceListPayload = try await client.get(.pokemonList(limit: 2, offset: 0))
        #expect(payload.count == 2)
        #expect(payload.results.map(\.name) == ["bulbasaur", "ivysaur"])
        #expect(payload.next == nil)
    }

    @Test("Sends the endpoint's own request to the transport")
    func sendsEndpointRequest() async throws {
        let transport = StubHTTPClient(json: JSONFixture.resourceList(results: []))
        _ = try await PokeAPIClient(transport: transport).get(.typeList) as ResourceListPayload

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.url?.absoluteString == "https://pokeapi.co/api/v2/type")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("Maps 404 onto notFound")
    func mapsNotFound() async {
        let client = PokeAPIClient(transport: StubHTTPClient(json: "{}", statusCode: 404))
        await #expect(throws: PokeAPIError.notFound) {
            let _: ResourceListPayload = try await client.get(.pokemon(.id(9999)))
        }
    }

    @Test("Maps any other failing status onto httpStatus")
    func mapsOtherStatuses() async {
        for code in [400, 429, 500, 503] {
            let client = PokeAPIClient(transport: StubHTTPClient(json: "{}", statusCode: code))
            await #expect(throws: PokeAPIError.httpStatus(code: code)) {
                let _: ResourceListPayload = try await client.get(.typeList)
            }
        }
    }

    @Test("Accepts every status in the 2xx range")
    func acceptsSuccessRange() async throws {
        for code in [200, 201, 204] {
            let client = PokeAPIClient(transport: StubHTTPClient(json: JSONFixture.resourceList(results: []), statusCode: code))
            let payload: ResourceListPayload = try await client.get(.typeList)
            #expect(payload.results.isEmpty)
        }
    }

    @Test("Maps a malformed body onto decodingFailed")
    func mapsMalformedBody() async {
        let client = PokeAPIClient(transport: StubHTTPClient(json: #"{ "count": "not a number" }"#))
        await #expect(throws: PokeAPIError.self) {
            let _: ResourceListPayload = try await client.get(.typeList)
        }
    }

    @Test("Maps a transport failure onto a PokeAPIError")
    func mapsTransportFailure() async {
        let client = PokeAPIClient(transport: StubHTTPClient(throwing: URLError(.timedOut)))
        guard case .transport = await capturedError(from: client) else {
            Issue.record("Expected a transport failure")
            return
        }
    }

    @Test("Maps a cancelled transport onto cancelled")
    func mapsCancelledTransport() async {
        let client = PokeAPIClient(transport: StubHTTPClient(throwing: URLError(.cancelled)))
        #expect(await capturedError(from: client) == .cancelled)
    }

    private func capturedError(from client: PokeAPIClient) async -> PokeAPIError? {
        do {
            let _: ResourceListPayload = try await client.get(.typeList)
            return nil
        } catch {
            return PokeAPIError.from(error)
        }
    }
}

import Foundation

nonisolated enum PokemonIdentifier: Hashable, Sendable {
    case id(Int)
    case name(String)

    var pathComponent: String {
        switch self {
        case .id(let id): String(id)
        case .name(let name): name.lowercased()
        }
    }
}

nonisolated enum PokeAPIEndpoint: Sendable {
    case pokemonList(limit: Int, offset: Int)
    case pokemon(PokemonIdentifier)
    case pokemonSpecies(PokemonIdentifier)
    case typeList
    case evolutionChain(id: Int)
    case resource(URL)

    static let baseURL = URL(string: "https://pokeapi.co/api/v2")!

    var url: URL {
        switch self {
        case .resource(let url):
            return url
        case .pokemonList(let limit, let offset):
            return Self.baseURL
                .appending(path: "pokemon")
                .appending(queryItems: [
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "offset", value: String(offset))
                ])

        case .pokemon(let identifier):
            return Self.baseURL.appending(path: "pokemon").appending(path: identifier.pathComponent)
        case .pokemonSpecies(let identifier):
            return Self.baseURL.appending(path: "pokemon-species").appending(path: identifier.pathComponent)
        case .typeList:
            return Self.baseURL.appending(path: "type")
        case .evolutionChain(let id):
            return Self.baseURL.appending(path: "evolution-chain").appending(path: String(id))
        }
    }

    func makeRequest() throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20
        return request
    }
}

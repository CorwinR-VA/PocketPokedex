import Foundation

nonisolated struct PokeAPIClient: Sendable {
    private let transport: HTTPClient

    init(transport: HTTPClient = URLSessionHTTPClient()) {
        self.transport = transport
    }

    func get<Payload: Decodable & Sendable>(
        _ endpoint: PokeAPIEndpoint,
        as type: Payload.Type = Payload.self
    ) async throws -> Payload {
        let request = try endpoint.makeRequest()

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw PokeAPIError.from(error)
        }

        switch response.statusCode {
        case 200..<300:
            break
        case 404:
            throw PokeAPIError.notFound
        case let code:
            throw PokeAPIError.httpStatus(code: code)
        }

        do {
            return try Self.makeDecoder().decode(Payload.self, from: data)
        } catch {
            throw PokeAPIError.from(error)
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

import Foundation

nonisolated protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse)
}

nonisolated struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PokeAPIError.invalidResponse
            }
            return (data, http)
        } catch {
            throw PokeAPIError.from(error)
        }
    }
}

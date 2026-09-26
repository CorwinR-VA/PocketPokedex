import Foundation

nonisolated enum PokeAPIError: LocalizedError, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case httpStatus(code: Int)
    case decodingFailed(description: String)
    case notFound
    case transport(description: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "The request could not be built."
        case .invalidResponse:
            "The server returned an unexpected response."
        case .httpStatus(let code):
            "The server responded with status code \(code)."
        case .decodingFailed(let description):
            "The data could not be read: \(description)"
        case .notFound:
            "That Pokémon could not be found."
        case .transport(let description):
            "Network error: \(description)"
        case .cancelled:
            "The request was cancelled."
        }
    }

    var userFacingMessage: String {
        switch self {
        case .transport:
            "Check your connection and try again."
        case .notFound:
            "We couldn't find that Pokémon."
        default:
            "Something went wrong while loading Pokémon data."
        }
    }

    static func from(_ error: any Error) -> PokeAPIError {
        if let error = error as? PokeAPIError { return error }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return .cancelled }
            return .transport(description: urlError.localizedDescription)
        }
        if let decodingError = error as? DecodingError {
            return .decodingFailed(description: decodingError.readableDescription)
        }
        return .transport(description: error.localizedDescription)
    }
}

private extension DecodingError {
    var readableDescription: String {
        func path(_ context: Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch self {
        case .typeMismatch(let type, let context):
            return "type mismatch for \(type) at \(path(context))"
        case .valueNotFound(let type, let context):
            return "missing value for \(type) at \(path(context))"
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(path(context))"
        case .dataCorrupted(let context):
            return "corrupted data at \(path(context)): \(context.debugDescription)"
        @unknown default:
            return "unknown decoding failure"
        }
    }
}

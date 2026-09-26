import Foundation

nonisolated extension String {
    var pokemonDisplayName: String {
        split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

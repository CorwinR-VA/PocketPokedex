import Foundation
import Observation

@MainActor
@Observable
final class TeamStore {
    private static let storageKey = "pokedex.team.memberIDs"

    private let defaults: UserDefaults
    private(set) var memberIdentifiers: Set<Int>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.array(forKey: Self.storageKey) as? [Int] ?? []
        self.memberIdentifiers = Set(stored)
    }

    var count: Int { memberIdentifiers.count }

    func contains(_ pokemonIdentifier: Int) -> Bool {
        memberIdentifiers.contains(pokemonIdentifier)
    }

    func toggle(_ pokemonIdentifier: Int) {
        if memberIdentifiers.contains(pokemonIdentifier) {
            memberIdentifiers.remove(pokemonIdentifier)
        } else {
            memberIdentifiers.insert(pokemonIdentifier)
        }
        defaults.set(Array(memberIdentifiers), forKey: Self.storageKey)
    }
}

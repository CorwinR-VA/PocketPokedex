import Foundation

nonisolated struct PokemonStat: Identifiable, Hashable, Sendable {
    let kind: StatKind
    let baseValue: Int

    var id: StatKind { kind }
    var displayName: String { kind.displayName }
}

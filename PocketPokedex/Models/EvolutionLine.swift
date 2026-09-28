import Foundation

/// One route through an evolution chain: the base form, everything it passes through, and the leaf.
///
/// A chain that branches has one line per leaf, so Eevee's eight evolutions are eight lines rather
/// than one run of arrows that would imply Vaporeon evolves into Jolteon. Deeper branches repeat the
/// stages they share, which is what makes each line readable on its own.
nonisolated struct EvolutionLine: Identifiable, Hashable, Sendable {
    let stages: [EvolutionStage]

    /// The leaf identifies the route: two lines of one chain differ only in where they end.
    var id: Int { stages.last?.id ?? 0 }
}

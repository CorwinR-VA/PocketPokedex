import SwiftUI

struct TypeBadgeRow: View {
    let types: [PokemonType]

    var body: some View {
        HStack(spacing: PokedexTheme.Metrics.badgeSpacing) {
            ForEach(types) { TypeBadge(type: $0) }
        }
    }
}

import SwiftUI

struct TypeFilter: View {
    let types: [PokemonType]
    let selectedTypes: [PokemonType]
    let onToggle: (PokemonType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by type")
                .font(.pokedexSectionTitle)
                .foregroundStyle(PokedexTheme.textPrimary)
                .frame(height: 28)

            ScrollView(.horizontal) {
                HStack(spacing: PokedexTheme.Metrics.chipSpacing) {
                    ForEach(types) { type in
                        TypeChip(type: type, isFilled: selectedTypes.contains(type)) {
                            onToggle(type)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .frame(height: 70, alignment: .top)
    }
}

#Preview {
    TypeFilter(types: PokemonType.allCases, selectedTypes: [.grass, .poison]) { _ in }
        .padding()
        .background(PokedexTheme.canvas)
}

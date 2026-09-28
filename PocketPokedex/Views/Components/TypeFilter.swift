import SwiftUI

struct TypeFilter: View {
    let types: [PokemonType]
    @Binding var selectedType: PokemonType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by type")
                .font(.pokedexSectionTitle)
                .foregroundStyle(PokedexTheme.textPrimary)
                .frame(height: 28)

            ScrollView(.horizontal) {
                HStack(spacing: PokedexTheme.Metrics.chipSpacing) {
                    ForEach(types) { type in
                        TypeChip(type: type, isFilled: selectedType == type) {
                            toggle(type)
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

    private func toggle(_ type: PokemonType) {
        selectedType = (selectedType == type) ? nil : type
    }
}

#Preview {
    TypeFilter(types: PokemonType.allCases, selectedType: .constant(.grass))
        .padding()
        .background(PokedexTheme.canvas)
}

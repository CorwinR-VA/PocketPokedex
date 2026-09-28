import SwiftUI

struct AboutFactCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.pokedexCaption)
                .foregroundStyle(PokedexTheme.textSecondary)
                .frame(height: 16)
            Text(value)
                .font(.pokedexBodyEmphasis)
                .foregroundStyle(PokedexTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .frame(height: 56, alignment: .top)
    }
}

#Preview {
    AboutFactCell(label: "Height", value: "0.7 m")
        .padding()
        .background(PokedexTheme.canvas)
}

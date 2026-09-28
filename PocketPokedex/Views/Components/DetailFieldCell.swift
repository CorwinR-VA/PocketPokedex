import SwiftUI

struct DetailFieldCell: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.pokedexParagraph)
                    .foregroundStyle(PokedexTheme.textSecondary)
                    .frame(height: 20)
                Text(value)
                    .font(.pokedexLabel)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40, alignment: .leading)
    }
}

#Preview {
    DetailFieldCell(icon: "ruler", iconColor: PokedexTheme.iconBlue, label: "Height", value: "0.7 m")
        .padding()
        .background(PokedexTheme.canvas)
}

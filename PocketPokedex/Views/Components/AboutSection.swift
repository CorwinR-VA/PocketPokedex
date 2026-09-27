import SwiftUI

struct AboutSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SectionIconTile(icon: icon)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.pokedexBodyEmphasis)
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .frame(height: 24)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    AboutSection(icon: "book", title: "Pokédex Entry") {
        Text("When the bulb on its back grows large…")
            .font(.pokedexParagraph)
    }
    .padding()
    .background(PokedexTheme.canvas)
}

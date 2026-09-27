import SwiftUI

struct PokedexSurface<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .pokedexPanel()
            .pokedexCardShadow()
    }
}

#Preview {
    PokedexSurface(padding: 17) {
        Text("Surface")
            .font(.pokedexBodyEmphasis)
    }
    .padding()
    .background(PokedexTheme.canvas)
}

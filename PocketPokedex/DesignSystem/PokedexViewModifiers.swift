import SwiftUI

extension View {
    func pokedexCardShadow() -> some View {
        shadow(color: PokedexTheme.shadow.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    func pokedexSurfaceFill(cornerRadius: CGFloat) -> some View {
        background(PokedexTheme.surface, in: .rect(cornerRadius: cornerRadius))
    }

    func pokedexBorder(cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(PokedexTheme.border, lineWidth: 1)
        }
    }

    func pokedexPanel(cornerRadius: CGFloat = PokedexTheme.Metrics.sectionCornerRadius) -> some View {
        pokedexSurfaceFill(cornerRadius: cornerRadius)
            .pokedexBorder(cornerRadius: cornerRadius)
    }
}

import SwiftUI

struct SectionIconTile: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(PokedexTheme.accent)
            .frame(width: 20, height: 20)
            .frame(width: 36, height: 36)
            .background(PokedexTheme.mutedSurface, in: .rect(cornerRadius: PokedexTheme.Metrics.controlCornerRadius))
            .accessibilityHidden(true)
    }
}

#Preview {
    SectionIconTile(icon: "book")
        .padding()
        .background(PokedexTheme.canvas)
}

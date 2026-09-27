import SwiftUI

struct PokedexButton: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task { await action() }
        }
        .font(.pokedexLabel)
        .foregroundStyle(PokedexTheme.onAccent)
        .padding(.horizontal, 16)
        .frame(minHeight: PokedexTheme.Metrics.minimumTapTarget)
        .background(PokedexTheme.accent, in: .rect(cornerRadius: PokedexTheme.Metrics.controlCornerRadius))
    }
}

#Preview {
    PokedexButton(title: "Try Again") {}
        .padding()
        .background(PokedexTheme.canvas)
}

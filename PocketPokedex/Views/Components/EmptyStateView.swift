import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() async -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(PokedexTheme.textSecondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.pokedexBodyEmphasis)
                .foregroundStyle(PokedexTheme.textPrimary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.pokedexParagraph)
                    .foregroundStyle(PokedexTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                PokedexButton(title: actionTitle, action: action)
                    .padding(.top, 4)
            }
        }
        .padding(32)
    }
}

#Preview {
    VStack(spacing: 32) {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Fire Pokémon found.",
            message: "Try another type."
        )
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Couldn't load the Pokédex",
            message: "Check your connection and try again.",
            actionTitle: "Try Again"
        ) {}
    }
    .background(PokedexTheme.canvas)
}

import SwiftUI

struct PokemonDetailView: View {
    @State private var viewModel: PokemonDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PokemonDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    PokemonDetailHero(viewModel: viewModel)
                    tabSection
                }
                .padding(PokedexTheme.Metrics.detailInset)
                .frame(maxWidth: PokedexTheme.Metrics.detailWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { PokedexTheme.surface.ignoresSafeArea() }
        .task { await viewModel.load() }
    }

    private var header: some View {
        ZStack {
            Text("Pokémon Details")
                .font(.pokedexSectionTitle)
                .foregroundStyle(PokedexTheme.textPrimary)

            HStack {
                Spacer(minLength: 0)
                Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(PokedexTheme.textPrimary)
                    .frame(
                        width: PokedexTheme.Metrics.minimumTapTarget,
                        height: PokedexTheme.Metrics.minimumTapTarget
                    )
                    .contentShape(.rect)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: PokedexTheme.Metrics.minimumTapTarget)
        .padding(.leading, PokedexTheme.Metrics.pageInset)
        .padding(.trailing, 8)
    }

    private var tabSection: some View {
        PokedexSurface(padding: 17) {
            VStack(spacing: 24) {
                PokedexTabBar(
                    options: PokemonDetailTab.allCases,
                    title: \.title,
                    selection: $viewModel.selectedTab
                )
                content
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(PokedexTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 220)

        case .failed(let message):
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Couldn't load this Pokémon",
                message: message,
                actionTitle: "Try Again",
                action: { await viewModel.load() }
            )
            .frame(maxWidth: .infinity, minHeight: 220)

        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        switch viewModel.selectedTab {
        case .stats:
            PokemonStatsTab(
                stats: viewModel.pokemon?.stats ?? [],
                total: viewModel.pokemon?.totalStats ?? 0
            )
        case .moves:
            PokemonMovesTab(moves: viewModel.pokemon?.moves ?? [])
        case .about:
            PokemonAboutTab(
                pokemon: viewModel.pokemon,
                species: viewModel.species,
                evolutionChain: viewModel.evolutionChain
            )
        }
    }
}

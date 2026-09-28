import SwiftUI

struct PokemonFeedView: View {
    let viewModel: PokedexFeedViewModel
    let dependencies: AppDependencies

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedItem: PokemonFeedItem?

    var body: some View {
        Group {
            if viewModel.showsOnlyTeam {
                grid
            } else {
                switch viewModel.phase {
                case .idle, .loadingFirstPage:
                    loadingState
                case .failed(let message):
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't load the Pokédex",
                        message: message,
                        actionTitle: "Try Again",
                        action: { await viewModel.retry() }
                    )
                case .loaded:
                    grid
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) { teamFilterButton }
        .fullScreenCover(item: $selectedItem) { item in
            PokemonDetailView(viewModel: dependencies.makeDetailViewModel(for: item))
                .id(item.id)
        }
    }

    private var grid: some View {
        PokemonGrid(
            viewModel: viewModel,
            teamStore: dependencies.teamStore,
            selectedItem: $selectedItem
        )
    }

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .tint(PokedexTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var teamFilterButton: some View {
        TeamFilterButton(
            isOn: viewModel.showsOnlyTeam,
            teamCount: dependencies.teamStore.count,
            action: toggleTeamFilter
        )
        .padding(.trailing, PokedexTheme.Metrics.floatingButtonInset)
        .padding(.bottom, PokedexTheme.Metrics.floatingButtonInset)
    }

    private func toggleTeamFilter() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            viewModel.toggleTeamFilter()
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = AppDependencies.preview.makeFeedViewModel()

    PokemonFeedView(viewModel: viewModel, dependencies: .preview)
}
#endif

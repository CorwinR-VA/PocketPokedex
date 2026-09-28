import SwiftUI

struct PokemonGrid: View {
    let viewModel: PokedexFeedViewModel
    let teamStore: TeamStore
    @Binding var selectedItem: PokemonFeedItem?

    private let columns = [
        GridItem(
            .adaptive(
                minimum: PokedexTheme.Metrics.cardMinWidth,
                maximum: PokedexTheme.Metrics.cardMaxWidth
            ),
            spacing: 16
        )
    ]

    var body: some View {
        let visibleItems = viewModel.visibleItems

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(visibleItems) { item in
                    PokemonCard(
                        item: item,
                        isInTeam: teamStore.contains(item.id),
                        onSelect: { selectedItem = item },
                        onToggleTeam: { teamStore.toggle(item.id) }
                    )
                }

                if viewModel.hasMorePages {
                    Color.clear
                        .frame(height: 1)
                        .task(id: viewModel.loadedPageCount) {
                            await viewModel.loadMoreIfNeeded()
                        }
                }
            }
            .padding(.bottom, visibleItems.isEmpty ? 0 : 8)
            .padding(.horizontal)

            Color.clear
                .frame(height: PokedexTheme.Metrics.floatingButtonClearance)

            footer
        }
        .refreshable { await viewModel.refresh() }
        .overlay {
            if visibleItems.isEmpty { emptyState }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.showsOnlyTeam {
            teamFooter
        } else {
            paginationFooter
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if let message = viewModel.nextPageErrorMessage {
            FeedInlineFailure(message: message) {
                await viewModel.retry()
            }
        } else if viewModel.hasMorePages {
            ProgressView()
                .controlSize(.regular)
                .tint(PokedexTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: PokedexTheme.Metrics.minimumTapTarget)
                .padding(.vertical, 8)
        } else if !viewModel.items.isEmpty {
            Text("That's all \(viewModel.totalCount) Pokémon.")
                .font(.pokedexParagraph)
                .foregroundStyle(PokedexTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: PokedexTheme.Metrics.minimumTapTarget)
        }
    }

    @ViewBuilder
    private var teamFooter: some View {
        if let message = viewModel.teamErrorMessage, !viewModel.teamItems.isEmpty {
            FeedInlineFailure(message: message) {
                await viewModel.loadTeam()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.showsOnlyTeam {
            if viewModel.isLoadingTeam {
                loadingIndicator
            } else if let message = viewModel.teamErrorMessage, viewModel.teamItems.isEmpty {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Couldn't load your team",
                    message: message,
                    actionTitle: "Try Again",
                    action: { await viewModel.loadTeam() }
                )
            } else {
                teamEmptyState
            }
        } else if !viewModel.hasMorePages {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No \(selectedTypeName) Pokémon found.",
                message: "Try another type."
            )
        }
    }

    private var teamEmptyState: some View {
        if teamStore.count > 0 {
            EmptyStateView(
                icon: "heart",
                title: "No \(selectedTypeName) team members found.",
                message: "Try another type."
            )
        } else {
            EmptyStateView(
                icon: "heart",
                title: "No team members yet.",
                message: "Tap + on any card to add one."
            )
        }
    }

    private var selectedTypeName: String {
        viewModel.selectedType?.name ?? ""
    }

    private var loadingIndicator: some View {
        ProgressView()
            .controlSize(.large)
            .tint(PokedexTheme.textSecondary)
    }
}

private struct FeedInlineFailure: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.pokedexParagraph)
                .foregroundStyle(PokedexTheme.textSecondary)
                .multilineTextAlignment(.center)
            PokedexButton(title: "Try Again", action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

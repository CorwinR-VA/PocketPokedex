import SwiftUI

struct HomeView: View {
    private let dependencies: AppDependencies
    @State private var feedViewModel: PokedexFeedViewModel
    @State private var theme: PokedexBackgroundTheme = .standard
    @State private var appearance: ColorScheme?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _feedViewModel = State(initialValue: dependencies.makeFeedViewModel())
    }

    var body: some View {
        PokemonFeedView(viewModel: feedViewModel, dependencies: dependencies)
            .frame(maxWidth: PokedexTheme.Metrics.contentMaxWidth + PokedexTheme.Metrics.pageInset * 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top) { header }
            .environment(\.imageCache, dependencies.imageCache)
            .task { await feedViewModel.start() }
            .background { background }
            .preferredColorScheme(appearance)
    }

    private var header: some View {
        VStack {
            TopBar(theme: $theme, appearance: $appearance)

            TypeFilter(
                types: feedViewModel.availableTypes,
                selectedTypes: feedViewModel.selectedTypes,
                onToggle: feedViewModel.toggleType
            )
        }
        .padding()
        .background { headerBackdrop }
    }

    private var headerBackdrop: some View {
        background
            .opacity(0.45)
            .background(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(.all)
    }

    private var background: some View {
        ZStack {
            PokedexTheme.canvas
            if let wash = theme.wash {
                wash
            }
            if let watermark = theme.watermark {
                PokedexWatermark(motif: watermark.motif, color: watermark.tint)
            }
        }
        .ignoresSafeArea(.all)
    }
}

#Preview("Live") {
    HomeView(dependencies: .live)
}

#if DEBUG
#Preview("Offline") {
    HomeView(dependencies: .preview)
}
#endif

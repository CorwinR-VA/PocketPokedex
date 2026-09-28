import Foundation

@MainActor
struct AppDependencies {
    let pokemonService: any PokemonService
    let imageCache: any ImageCaching
    let teamStore: TeamStore

    static let live = AppDependencies(
        pokemonService: CachedPokemonService(upstream: LivePokemonService()),
        imageCache: ImageCache.shared,
        teamStore: TeamStore()
    )

    #if DEBUG
    static let preview = AppDependencies(
        pokemonService: PreviewPokemonService(),
        imageCache: PreviewImageCache(),
        teamStore: TeamStore(defaults: UserDefaults(suiteName: "pokedex.preview") ?? .standard)
    )
    #endif

    func makeFeedViewModel() -> PokedexFeedViewModel {
        PokedexFeedViewModel(service: pokemonService, teamStore: teamStore)
    }

    func makeDetailViewModel(for item: PokemonFeedItem) -> PokemonDetailViewModel {
        PokemonDetailViewModel(item: item, service: pokemonService)
    }
}

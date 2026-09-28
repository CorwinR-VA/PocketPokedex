import SwiftUI

@main
struct PocketPokedexApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(dependencies: .live)
        }
    }
}

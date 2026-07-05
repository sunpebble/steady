import SwiftUI
import SwiftData

@main
struct SteadyWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchRootView() }
            .modelContainer((try? SteadyModels.container()) ?? SteadyModels.testContainer())
    }
}

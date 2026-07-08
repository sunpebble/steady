import SwiftUI
import SwiftData

@main
struct SteadyApp: App {
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
                .task {
                    await pro.load()
                    await pro.listenForTransactions()
                }
        }
            .modelContainer(LaunchArgs.isDemoSeed
                ? SteadyModels.testContainer()
                : ((try? SteadyModels.container()) ?? SteadyModels.testContainer()))
    }
}

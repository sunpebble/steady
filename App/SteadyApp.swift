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
            // ponytail: CloudKit 容器建失败回退内存库；-seedDemo 强制内存库(演示数据零污染)
            .modelContainer(LaunchArgs.isDemoSeed
                ? SteadyModels.testContainer()
                : ((try? SteadyModels.container()) ?? SteadyModels.testContainer()))
    }
}

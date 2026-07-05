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
            // ponytail: CloudKit 容器建失败(无 iCloud 账号等)回退内存库，App 不崩
            .modelContainer((try? SteadyModels.container()) ?? SteadyModels.testContainer())
    }
}

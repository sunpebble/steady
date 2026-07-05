import SwiftUI
import SwiftData

@main
struct SteadyApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            // ponytail: CloudKit 容器建失败(无 iCloud 账号等)回退内存库，App 不崩
            .modelContainer((try? SteadyModels.container()) ?? SteadyModels.testContainer())
    }
}

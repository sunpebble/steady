import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Text("Timeline").tabItem { Label("Timeline", systemImage: "list.bullet.rectangle") }
            Text("Trends").tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            Text("Meds").tabItem { Label("Meds", systemImage: "pills") }
            Text("Settings").tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.sun)
    }
}

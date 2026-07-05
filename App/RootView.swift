import SwiftUI

struct RootView: View {
    @State private var health = HealthStore()
    @State private var logging: Reading.Kind?

    var body: some View {
        TabView {
            TimelineView().tabItem { Label("Timeline", systemImage: "list.bullet.rectangle") }
            TrendsView().tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            MedsView().tabItem { Label("Meds", systemImage: "pills") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.sun)
        .environment(health)
        .task { await health.requestAuthorization() }
        .sheet(item: $logging) { QuickLogView(kind: $0) }
        .onOpenURL { url in
            guard url.scheme == "steady", url.host() == "log",
                  let kind = Reading.Kind(rawValue: url.lastPathComponent) else { return }
            logging = kind
        }
        .overlay(alignment: .bottomTrailing) {
            Menu {
                ForEach(Reading.Kind.allCases) { kind in
                    Button(kind.displayName, systemImage: kind.systemImage) { logging = kind }
                }
            } label: {
                Image(systemName: "plus")
                    .font(Theme.font(24, weight: .bold))
                    .foregroundStyle(Theme.ink)   // sun 上只放 ink
                    .frame(width: 56, height: 56)
                    .background(Theme.sun, in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 64)
        }
    }
}

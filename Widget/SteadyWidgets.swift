import SwiftUI
import WidgetKit

@main
struct SteadyWidgetBundle: WidgetBundle {
    var body: some Widget { QuickLogWidget() }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLog", provider: Provider()) { _ in
            Text("Steady").containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Quick log")
    }
}

struct Provider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

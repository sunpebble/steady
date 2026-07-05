import SwiftUI
import WidgetKit

private let cream = Color(red: 1.0, green: 0.965, blue: 0.91)
private let ink = Color(red: 0.137, green: 0.153, blue: 0.20)
private let sun = Color(red: 0.969, green: 0.718, blue: 0.20)

@main
struct SteadyWidgetBundle: WidgetBundle {
    var body: some Widget { QuickLogWidget() }
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let isPro: Bool
}

struct Provider: TimelineProvider {
    private func entry() -> QuickLogEntry {
        QuickLogEntry(
            date: .now,
            isPro: UserDefaults(suiteName: "group.com.sunpebble.steady")?.bool(forKey: "isPro") ?? false)
    }

    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: .now, isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLog", provider: Provider()) { entry in
            QuickLogWidgetView(entry: entry)
                .containerBackground(cream, for: .widget)
        }
        .configurationDisplayName("Quick log")
        .description("Log a reading with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickLogEntry

    private var kinds: [Reading.Kind] {
        family == .systemSmall ? [.bloodPressure, .glucose] : [.bloodPressure, .glucose, .weight, .heartRate]
    }

    var body: some View {
        if entry.isPro {
            HStack(spacing: 8) {
                ForEach(kinds) { kind in
                    Link(destination: URL(string: "steady://log/\(kind.rawValue)")!) {
                        VStack(spacing: 6) {
                            Image(systemName: kind.systemImage)
                                .font(.title3)
                            Text(kind.displayName)
                                .font(.system(size: 10, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .foregroundStyle(ink)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "lock")
                    .font(.title2)
                    .foregroundStyle(sun)
                Text("Widgets are part of Steady Pro")
                    .font(.system(size: 11, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(ink)
        }
    }
}

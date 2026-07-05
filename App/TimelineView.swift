import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(HealthStore.self) private var health
    @Query(sort: \SymptomEntry.date, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \MedLog.date, order: .reverse) private var medLogs: [MedLog]
    @State private var loggingSymptom = false

    private enum Item: Identifiable {
        case reading(Reading), symptom(SymptomEntry), med(MedLog)
        var id: AnyHashable {
            switch self {
            case .reading(let r): r.id
            case .symptom(let s): s.persistentModelID
            case .med(let m): m.persistentModelID
            }
        }
        var date: Date {
            switch self {
            case .reading(let r): r.date
            case .symptom(let s): s.date
            case .med(let m): m.date
            }
        }
    }

    private var days: [(day: Date, items: [Item])] {
        let all: [Item] = health.readings.map(Item.reading)
            + symptoms.map(Item.symptom) + medLogs.map(Item.med)
        return Dictionary(grouping: all) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            List {
                if days.isEmpty {
                    ContentUnavailableView("Nothing yet",
                        systemImage: "square.and.pencil",
                        description: Text("Log your first reading with the + button."))
                }
                ForEach(days, id: \.day) { day in
                    Section(day.day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(day.items) { row($0) }
                    }
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                Button("Log symptom", systemImage: "bandage") { loggingSymptom = true }
            }
            .sheet(isPresented: $loggingSymptom) { SymptomLogView() }
            .refreshable { await health.refresh() }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .reading(let r):
            HStack {
                Label(r.kind.displayName, systemImage: r.kind.systemImage)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(r.display) \(health.unitLabel(for: r.kind))").font(Theme.font(16, weight: .semibold))
                    if let context = r.mealtime?.label ?? r.note, !context.isEmpty {
                        Text(context).font(Theme.font(12)).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        case .symptom(let s):
            HStack {
                Label(s.name, systemImage: "bandage")
                Spacer()
                Text(String(repeating: "•", count: s.severity))
                    .foregroundStyle(Theme.sun).font(Theme.font(18, weight: .bold))
            }
        case .med(let m):
            Label("\(m.medication?.name ?? "?") — \(m.taken ? String(localized: "taken") : String(localized: "skipped"))",
                  systemImage: m.taken ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(m.taken ? Theme.text : Theme.secondaryText)
        }
    }
}

struct SymptomLogView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var severity = 1
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Symptom (e.g. headache)", text: $name)
                Picker("Severity", selection: $severity) {
                    Text("Mild").tag(1); Text("Moderate").tag(2); Text("Severe").tag(3)
                }.pickerStyle(.segmented)
                TextField("Note", text: $note)
            }
            .navigationTitle("Log symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ctx.insert(SymptomEntry(name: name, severity: severity, note: note))
                        dismiss()
                    }.disabled(name.isEmpty)
                }
            }
        }
        .tint(Theme.sun)
    }
}

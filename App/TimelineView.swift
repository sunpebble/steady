import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.modelContext) private var ctx
    @Query(sort: \SymptomEntry.date, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \MedLog.date, order: .reverse) private var medLogs: [MedLog]
    @State private var loggingSymptom = false
    @State private var editingReading: Reading?
    @State private var editingSymptom: SymptomEntry?
    @State private var pendingDelete: Item?
    @State private var deleteError: String?

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
                        ForEach(day.items) { item in
                            row(item)
                                .swipeActions {
                                    // 不用 .destructive role:先弹确认,避免行被乐观移除
                                    Button("Delete", systemImage: "trash") { pendingDelete = item }
                                        .tint(.red)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                Button("Log symptom", systemImage: "bandage") { loggingSymptom = true }
            }
            .sheet(isPresented: $loggingSymptom) { SymptomLogView() }
            .sheet(item: $editingReading) { QuickLogView(kind: $0.kind, editing: $0) }
            .sheet(item: $editingSymptom) { SymptomLogView(entry: $0) }
            .confirmationDialog("Delete this entry?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible, presenting: pendingDelete) { item in
                Button("Delete", role: .destructive) { delete(item) }
            }
            .alert(deleteError ?? "", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .refreshable { await health.refresh() }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .reading(let r):
            Button {
                editingReading = r
            } label: {
                HStack {
                    Label(r.kind.displayName, systemImage: r.kind.systemImage)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(r.display) \(health.unitLabel(for: r.kind))").font(Theme.font(16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        if let context = r.mealtime?.label ?? r.note, !context.isEmpty {
                            Text(context).font(Theme.font(12)).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
        case .symptom(let s):
            Button {
                editingSymptom = s
            } label: {
                HStack {
                    Label(s.name, systemImage: "bandage")
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(String(repeating: "•", count: s.severity))
                        .foregroundStyle(Theme.sun).font(Theme.font(18, weight: .bold))
                }
            }
        case .med(let m):
            Label("\(m.medication?.name ?? "?") — \(m.taken ? String(localized: "taken") : String(localized: "skipped"))",
                  systemImage: m.taken ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(m.taken ? Theme.text : Theme.secondaryText)
        }
    }

    private func delete(_ item: Item) {
        switch item {
        case .reading(let r):
            Task {
                do { try await health.delete(r) }
                catch { deleteError = String(localized: "Couldn't delete from Health: \(error.localizedDescription)") }
            }
        case .symptom(let s):
            ctx.delete(s)
        case .med(let m):
            ctx.delete(m)
        }
    }
}

struct SymptomLogView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let entry: SymptomEntry?       // 非 nil = 编辑已有记录
    @State private var name = ""
    @State private var severity = 1
    @State private var date = Date.now
    @State private var note = ""
    @State private var confirmingDelete = false

    init(entry: SymptomEntry? = nil) { self.entry = entry }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Symptom (e.g. headache)", text: $name)
                Picker("Severity", selection: $severity) {
                    Text("Mild").tag(1); Text("Moderate").tag(2); Text("Severe").tag(3)
                }.pickerStyle(.segmented)
                DatePicker("Time", selection: $date)
                TextField("Note", text: $note)
                if entry != nil {
                    Section {
                        Button("Delete", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry { ctx.delete(entry) }
                    dismiss()
                }
            }
            .navigationTitle(entry == nil ? String(localized: "Log symptom") : String(localized: "Edit symptom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear {
                guard let entry else { return }
                name = entry.name
                severity = entry.severity
                date = entry.date
                note = entry.note
            }
        }
        .tint(Theme.sun)
    }

    private func save() {
        if let entry {
            entry.name = name
            entry.severity = severity
            entry.date = date
            entry.note = note
        } else {
            ctx.insert(SymptomEntry(name: name, severity: severity, date: date, note: note))
        }
        dismiss()
    }
}

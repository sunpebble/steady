import SwiftUI
import SwiftData

func todayLog(for med: Medication, slot: Int, in logs: [MedLog]) -> MedLog? {
    logs.first {
        $0.medication?.persistentModelID == med.persistentModelID
            && $0.slot == slot
            && Calendar.current.isDateInToday($0.date)
    }
}

func minutesLabel(_ minutes: Int) -> String {
    let t = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
    return t.formatted(date: .omitted, time: .shortened)
}

struct MedsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Medication> { !$0.archived }, sort: \Medication.createdAt)
    private var meds: [Medication]
    @Query private var logs: [MedLog]
    @State private var editing: Medication?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if meds.isEmpty {
                    ContentUnavailableView("No medications", systemImage: "pills",
                        description: Text("Add one to get reminders and a daily checklist."))
                }
                Section("Today") {
                    ForEach(meds) { med in
                        ForEach(med.times, id: \.self) { slot in
                            checklistRow(med: med, slot: slot)
                        }
                    }
                }
                Section("Medications") {
                    ForEach(meds) { med in
                        Button {
                            editing = med
                        } label: {
                            VStack(alignment: .leading) {
                                Text(med.name).foregroundStyle(Theme.text)
                                Text("\(med.dosage) · \(med.times.map(minutesLabel).joined(separator: ", "))")
                                    .font(Theme.font(12)).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    .onDelete { idx in idx.forEach { meds[$0].archived = true } }
                }
            }
            .navigationTitle("Meds")
            .toolbar { Button("Add", systemImage: "plus") { adding = true } }
            .sheet(isPresented: $adding) { MedEditView(med: nil) }
            .sheet(item: $editing) { MedEditView(med: $0) }
        }
    }

    private func checklistRow(med: Medication, slot: Int) -> some View {
        let log = todayLog(for: med, slot: slot, in: logs)
        return HStack {
            Text("\(med.name) · \(minutesLabel(slot))")
            Spacer()
            Button {
                if let log { ctx.delete(log) }
                else { ctx.insert(MedLog(slot: slot, taken: true, medication: med)) }
            } label: {
                Image(systemName: log?.taken == true ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(log?.taken == true ? Theme.sun : Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}

struct MedEditView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let med: Medication?
    @State private var name = ""
    @State private var dosage = ""
    @State private var times: [Date] = []

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Dosage (e.g. 500mg)", text: $dosage)
                Section("Times") {
                    ForEach(times.indices, id: \.self) { i in
                        DatePicker("Dose \(i + 1)", selection: $times[i], displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }
                    Button("Add time", systemImage: "plus") {
                        times.append(Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!)
                    }
                }
            }
            .navigationTitle(med == nil ? "New medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty || times.isEmpty)
                }
            }
            .onAppear {
                guard let med else { return }
                name = med.name
                dosage = med.dosage
                times = med.times.map {
                    Calendar.current.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: .now)!
                }
            }
        }
        .tint(Theme.sun)
    }

    private func save() {
        let minutes = times.map {
            Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0)
        }.sorted()
        if let med {
            med.name = name
            med.dosage = dosage
            med.times = minutes
        } else {
            ctx.insert(Medication(name: name, dosage: dosage, times: minutes))
        }
        dismiss()
    }
}

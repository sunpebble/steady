import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(HealthStore.self) private var health
    @Environment(ProStore.self) private var pro
    @Query private var meds: [Medication]
    @State private var reminder = SettingsStore.measurementReminder
    @State private var ranges: [Reading.Kind: (String, String)] = [:]
    @State private var showPaywall = false
    @State private var csvURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Export") {
                    NavigationLink("Doctor report") { ReportView() }
                    Button("Export CSV", systemImage: "tablecells") { exportCSV() }
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("Share CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                Section {
                    ForEach([Reading.Kind.bloodPressure, .glucose, .weight]) { kind in
                        rangeRow(kind)
                    }
                } header: { Text("My target ranges") } footer: {
                    Text("Set these with your doctor. Steady only counts readings against ranges you enter — it never judges them.")
                }
                Section("Measurement reminder") {
                    Toggle("Daily reminder", isOn: Binding(
                        get: { reminder != nil },
                        set: { reminder = $0 ? MeasurementReminder(kinds: [Reading.Kind.bloodPressure.rawValue]) : nil }))
                    if reminder != nil {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    Text(Disclaimer.text).font(Theme.font(12)).foregroundStyle(Theme.secondaryText)
                }
                Section {
                    if pro.isPro {
                        Label("Steady Pro — unlocked", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("Steady Pro…") { showPaywall = true }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { loadRanges() }
            .onDisappear { saveAll() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let r = reminder ?? MeasurementReminder()
                return Calendar.current.date(bySettingHour: r.hour, minute: r.minute, second: 0, of: .now)!
            },
            set: {
                reminder?.hour = Calendar.current.component(.hour, from: $0)
                reminder?.minute = Calendar.current.component(.minute, from: $0)
            })
    }

    private func rangeRow(_ kind: Reading.Kind) -> some View {
        HStack {
            Label(kind.displayName, systemImage: kind.systemImage)
            Spacer()
            TextField("low", text: rangeBinding(kind, \.0)).frame(width: 52)
            Text("–")
            TextField("high", text: rangeBinding(kind, \.1)).frame(width: 52)
        }
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
    }

    private func rangeBinding(_ kind: Reading.Kind, _ part: WritableKeyPath<(String, String), String>) -> Binding<String> {
        Binding(
            get: { ranges[kind, default: ("", "")][keyPath: part] },
            set: {
                var pair = ranges[kind, default: ("", "")]
                pair[keyPath: part] = $0
                ranges[kind] = pair
            })
    }

    private func loadRanges() {
        for kind in Reading.Kind.allCases {
            if let r = SettingsStore.targetRange(for: kind) {
                ranges[kind] = (r.lowerBound.formatted(), r.upperBound.formatted())
            }
        }
    }

    private func saveAll() {
        for (kind, pair) in ranges {
            if let lo = Double(pair.0), let hi = Double(pair.1), hi > lo {
                SettingsStore.setTargetRange(lo...hi, for: kind)
            } else {
                SettingsStore.setTargetRange(nil, for: kind)
            }
        }
        SettingsStore.measurementReminder = reminder
        Task { await ReminderCenter.sync(meds: meds, measurement: reminder) }
    }

    private func exportCSV() {
        guard pro.isPro else {
            showPaywall = true
            return
        }
        let url = URL.temporaryDirectory.appending(path: "steady.csv")
        try? ReportModel.csv(readings: health.readings).write(to: url, atomically: true, encoding: .utf8)
        csvURL = url
    }
}

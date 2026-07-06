import SwiftUI

struct QuickLogView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.dismiss) private var dismiss
    let kind: Reading.Kind
    @State private var draft: ReadingDraft
    @State private var error: String?
    // 记住上次值作默认，减少输入
    @AppStorage private var lastValue: Double
    @AppStorage private var lastSecondary: Double

    init(kind: Reading.Kind) {
        self.kind = kind
        _lastValue = AppStorage(wrappedValue: 0, "last.\(kind.rawValue).value")
        _lastSecondary = AppStorage(wrappedValue: 0, "last.\(kind.rawValue).secondary")
        _draft = State(initialValue: ReadingDraft(kind: kind))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(kind == .bloodPressure ? String(localized: "Systolic") : kind.displayName) {
                        numberField(value: $draft.value)
                    }
                    if kind == .bloodPressure {
                        LabeledContent("Diastolic") { numberField(value: $draft.secondary) }
                    }
                    if kind == .glucose {
                        Picker("Context", selection: $draft.mealtime) {
                            Text("—").tag(Reading.Mealtime?.none)
                            ForEach(Reading.Mealtime.allCases) { Text($0.label).tag(Optional($0)) }
                        }
                    }
                    DatePicker("Time", selection: $draft.date)
                    TextField("Note", text: $draft.note)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.value <= 0 || (kind == .bloodPressure && draft.secondary <= 0))
                }
            }
            .onAppear {
                draft.value = lastValue
                draft.secondary = lastSecondary
            }
        }
        .tint(Theme.sun)
    }

    private func numberField(value: Binding<Double>) -> some View {
        TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
    }

    private func save() {
        Task {
            do {
                try await health.save(draft)
                lastValue = draft.value
                lastSecondary = draft.secondary
                dismiss()
            } catch { self.error = String(localized: "Couldn't save to Health: \(error.localizedDescription)") }
        }
    }
}

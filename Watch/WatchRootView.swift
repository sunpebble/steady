import SwiftUI
import SwiftData
import HealthKit

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchLogView(kind: .bloodPressure)
            WatchLogView(kind: .glucose)
            WatchMedsView()
        }
        .tabViewStyle(.verticalPage)
    }
}

struct WatchLogView: View {
    let kind: Reading.Kind
    @State private var value: Double = 0
    @State private var secondary: Double = 0
    @State private var saved = false
    private let store = HKHealthStore()

    var body: some View {
        VStack {
            Text(kind.displayName)
                .font(.headline)
            Text(value.formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .focusable()
                .digitalCrownRotation($value, from: 0, through: 400, by: 1)
            if kind == .bloodPressure {
                Text(secondary.formatted(.number.precision(.fractionLength(0))))
                    .font(.title3)
                    .focusable()
                    .digitalCrownRotation($secondary, from: 0, through: 200, by: 1)
            }
            Button(saved ? "Saved" : "Save") { save() }
                .disabled(value <= 0 || (kind == .bloodPressure && secondary <= 0))
        }
    }

    private func save() {
        Task {
            let types: Set<HKSampleType> = kind == .bloodPressure
                ? [HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic)]
                : [HKQuantityType(.bloodGlucose)]
            try? await store.requestAuthorization(toShare: types, read: types)

            let now = Date.now
            let sample: HKSample
            if kind == .bloodPressure {
                let sys = HKQuantitySample(
                    type: HKQuantityType(.bloodPressureSystolic),
                    quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: value),
                    start: now,
                    end: now)
                let dia = HKQuantitySample(
                    type: HKQuantityType(.bloodPressureDiastolic),
                    quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: secondary),
                    start: now,
                    end: now)
                sample = HKCorrelation(
                    type: HKCorrelationType(.bloodPressure),
                    start: now,
                    end: now,
                    objects: [sys, dia])
            } else {
                let unit = (try? await store.preferredUnits(for: [HKQuantityType(.bloodGlucose)]))?[HKQuantityType(.bloodGlucose)]
                    ?? HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
                sample = HKQuantitySample(
                    type: HKQuantityType(.bloodGlucose),
                    quantity: HKQuantity(unit: unit, doubleValue: value),
                    start: now,
                    end: now)
            }

            try? await store.save(sample)
            saved = true
        }
    }
}

struct WatchMedsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Medication> { !$0.archived }) private var meds: [Medication]
    @Query private var logs: [MedLog]

    var body: some View {
        List {
            ForEach(meds) { med in
                ForEach(med.times, id: \.self) { slot in
                    medRow(med: med, slot: slot)
                }
            }
            if meds.isEmpty {
                Text("Add medications on iPhone.")
            }
        }
        .navigationTitle("Meds")
    }

    private func medRow(med: Medication, slot: Int) -> some View {
        let log = todayLog(for: med, slot: slot, in: logs)
        return Button {
            if let log {
                ctx.delete(log)
            } else {
                ctx.insert(MedLog(slot: slot, taken: true, medication: med))
            }
            try? ctx.save()
        } label: {
            Label(
                "\(med.name) \(minutesLabel(slot))",
                systemImage: log != nil ? "checkmark.circle.fill" : "circle")
        }
    }
}

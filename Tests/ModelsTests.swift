import XCTest
import SwiftData
@testable import Steady

final class ModelsTests: XCTestCase {
    @MainActor
    func testContainerRoundTrip() throws {
        let container = SteadyModels.testContainer()
        let ctx = container.mainContext
        let med = Medication(name: "Metformin", dosage: "500mg", times: [8 * 60, 20 * 60])
        ctx.insert(med)
        ctx.insert(MedLog(date: .now, slot: 8 * 60, taken: true, medication: med))
        ctx.insert(SymptomEntry(name: "Headache", severity: 2, date: .now, note: ""))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Medication>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<MedLog>()).first?.medication?.name, "Metformin")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SymptomEntry>()).first?.severity, 2)
    }

    @MainActor
    func testTodayLogMatchesMedicationSlotAndToday() throws {
        let container = SteadyModels.testContainer()
        let ctx = container.mainContext
        let med = Medication(name: "Metformin", times: [8 * 60])
        let other = Medication(name: "Aspirin", times: [8 * 60])
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let hit = MedLog(date: .now, slot: 8 * 60, taken: true, medication: med)
        let logs = [
            MedLog(date: yesterday, slot: 8 * 60, taken: true, medication: med),
            MedLog(date: .now, slot: 9 * 60, taken: true, medication: med),
            MedLog(date: .now, slot: 8 * 60, taken: true, medication: other),
            hit,
        ]
        ctx.insert(med)
        ctx.insert(other)
        logs.forEach(ctx.insert)

        XCTAssertTrue(todayLog(for: med, slot: 8 * 60, in: logs) === hit)
        XCTAssertNil(todayLog(for: med, slot: 7 * 60, in: logs))
    }

    func testSettingsStoreRoundTrip() {
        let defaults = UserDefaults.standard
        let kind = Reading.Kind.glucose
        let keys = ["target.\(kind.rawValue).lo", "target.\(kind.rawValue).hi", "measurementReminder"]
        let oldValues = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, oldValues) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        SettingsStore.setTargetRange(70...140, for: kind)
        XCTAssertEqual(SettingsStore.targetRange(for: kind), 70...140)
        SettingsStore.setTargetRange(nil, for: kind)
        XCTAssertNil(SettingsStore.targetRange(for: kind))

        let reminder = MeasurementReminder(hour: 9, minute: 30, kinds: [kind.rawValue])
        SettingsStore.measurementReminder = reminder
        XCTAssertEqual(SettingsStore.measurementReminder, reminder)
        SettingsStore.measurementReminder = nil
        XCTAssertNil(SettingsStore.measurementReminder)
    }
}

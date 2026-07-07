import XCTest
@testable import Steady

/// demo 模式下 HealthStore 的增删改走内存路径,不碰 HealthKit,可直接单测。
final class HealthStoreDemoTests: XCTestCase {
    @MainActor
    private func makeDemoStore() -> HealthStore {
        let health = HealthStore()
        health.isDemo = true
        return health
    }

    @MainActor
    func testDemoSaveInsertsSortedByDateDescending() async throws {
        let health = makeDemoStore()
        let older = ReadingDraft(kind: .weight, date: .now.addingTimeInterval(-3600), value: 70)
        let newer = ReadingDraft(kind: .heartRate, date: .now, value: 68)
        try await health.save(older)
        try await health.save(newer)
        XCTAssertEqual(health.readings.count, 2)
        XCTAssertEqual(health.readings.first?.kind, .heartRate)
        XCTAssertEqual(health.readings.last?.kind, .weight)
    }

    @MainActor
    func testDemoDeleteRemovesOnlyTargetReading() async throws {
        let health = makeDemoStore()
        let keep = Reading(id: UUID(), kind: .glucose, date: .now, value: 105,
                           secondary: nil, mealtime: .fasting, note: nil)
        let gone = Reading(id: UUID(), kind: .weight, date: .now, value: 70,
                           secondary: nil, mealtime: nil, note: nil)
        health.readings = [keep, gone]
        try await health.delete(gone)
        XCTAssertEqual(health.readings, [keep])
    }

    @MainActor
    func testDemoUpdateReplacesReadingWithDraftValues() async throws {
        let health = makeDemoStore()
        let original = Reading(id: UUID(), kind: .bloodPressure, date: .now,
                               value: 128, secondary: 84, mealtime: nil, note: nil)
        health.readings = [original]
        var draft = ReadingDraft(reading: original)
        draft.value = 135
        draft.note = "after coffee"
        try await health.update(original, with: draft)
        XCTAssertEqual(health.readings.count, 1)
        let updated = try XCTUnwrap(health.readings.first)
        XCTAssertNotEqual(updated.id, original.id)   // 改 = 删旧 + 存新
        XCTAssertEqual(updated.value, 135, accuracy: 0.001)
        XCTAssertEqual(updated.secondary!, 84, accuracy: 0.001)
        XCTAssertEqual(updated.note, "after coffee")
    }
}

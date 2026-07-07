import XCTest
import HealthKit
@testable import Steady

final class ReadingTests: XCTestCase {
    let mgdl = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

    func testGlucoseSampleMapsWithMealtimeAndNote() {
        let sample = HKQuantitySample(
            type: HKQuantityType(.bloodGlucose),
            quantity: HKQuantity(unit: mgdl, doubleValue: 105),
            start: .now, end: .now,
            metadata: [
                HKMetadataKeyBloodGlucoseMealTime: HKBloodGlucoseMealTime.preprandial.rawValue,
                Reading.noteKey: "before breakfast",
            ])
        let reading = Reading(sample: sample, glucoseUnit: mgdl, weightUnit: .pound())
        XCTAssertEqual(reading?.kind, .glucose)
        XCTAssertEqual(reading!.value, 105, accuracy: 0.001)
        XCTAssertEqual(reading?.mealtime, .fasting)
        XCTAssertEqual(reading?.note, "before breakfast")
    }

    func testBloodPressureCorrelationMaps() {
        let start = Date.now
        let sys = HKQuantitySample(type: HKQuantityType(.bloodPressureSystolic),
                                   quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 128),
                                   start: start, end: start)
        let dia = HKQuantitySample(type: HKQuantityType(.bloodPressureDiastolic),
                                   quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 84),
                                   start: start, end: start)
        let corr = HKCorrelation(type: HKCorrelationType(.bloodPressure),
                                 start: start, end: start, objects: [sys, dia])
        let reading = Reading(sample: corr, glucoseUnit: mgdl, weightUnit: .pound())
        XCTAssertEqual(reading?.kind, .bloodPressure)
        XCTAssertEqual(reading!.value, 128, accuracy: 0.001)
        XCTAssertEqual(reading!.secondary!, 84, accuracy: 0.001)
    }

    func testDraftFromReadingPrefillsAllFields() {
        let reading = Reading(id: UUID(), kind: .bloodPressure, date: .now,
                              value: 128, secondary: 84, mealtime: nil, note: "morning")
        let draft = ReadingDraft(reading: reading)
        XCTAssertEqual(draft.kind, .bloodPressure)
        XCTAssertEqual(draft.date, reading.date)
        XCTAssertEqual(draft.value, 128, accuracy: 0.001)
        XCTAssertEqual(draft.secondary, 84, accuracy: 0.001)
        XCTAssertEqual(draft.note, "morning")
    }

    func testDraftFromReadingMapsNilsToDefaults() {
        let reading = Reading(id: UUID(), kind: .weight, date: .now,
                              value: 70, secondary: nil, mealtime: nil, note: nil)
        let draft = ReadingDraft(reading: reading)
        XCTAssertEqual(draft.secondary, 0)
        XCTAssertEqual(draft.note, "")
    }

    func testReadingFromDraftKeepsKindSpecificFieldsOnly() {
        var draft = ReadingDraft(kind: .glucose, value: 105, secondary: 84)
        draft.mealtime = .fasting
        let glucose = Reading(draft: draft)
        XCTAssertEqual(glucose.kind, .glucose)
        XCTAssertNil(glucose.secondary)          // 舒张压仅血压保留
        XCTAssertEqual(glucose.mealtime, .fasting)
        XCTAssertNil(glucose.note)               // 空备注 → nil

        draft.kind = .bloodPressure
        draft.note = "after walk"
        let bp = Reading(draft: draft)
        XCTAssertEqual(bp.secondary!, 84, accuracy: 0.001)
        XCTAssertNil(bp.mealtime)                // 用餐上下文仅血糖保留
        XCTAssertEqual(bp.note, "after walk")
    }
}

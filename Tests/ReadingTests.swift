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
}

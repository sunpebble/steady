import XCTest
@testable import Steady

final class ReportModelTests: XCTestCase {
    private func reading(_ kind: Reading.Kind, _ value: Double, secondary: Double? = nil,
                         day: Int, note: String? = nil) -> Reading {
        Reading(
            id: UUID(),
            kind: kind,
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: day))!,
            value: value,
            secondary: secondary,
            mealtime: nil,
            note: note)
    }

    func testSectionStatsAndInRange() {
        let model = ReportModel(
            readings: [
                reading(.glucose, 100, day: 1),
                reading(.glucose, 150, day: 2),
                reading(.weight, 70, day: 1),
            ],
            symptoms: [],
            meds: [],
            medLogs: [],
            interval: DateInterval(start: .distantPast, end: .distantFuture),
            targets: [.glucose: 80...130])

        let glucose = model.sections.first { $0.kind == .glucose }!
        XCTAssertEqual(glucose.average!, 125, accuracy: 0.001)
        XCTAssertEqual(glucose.inRange?.0, 1)
        XCTAssertEqual(glucose.inRange?.1, 2)
        XCTAssertNil(model.sections.first { $0.kind == .weight }!.inRange)
        XCTAssertFalse(model.sections.contains { $0.kind == .heartRate })
    }

    func testCSVEscapesQuotesAndCommas() {
        let csv = ReportModel.csv(readings: [
            reading(.glucose, 100, day: 1, note: #"before "big, meal""#),
        ])

        XCTAssertTrue(csv.hasPrefix("date,kind,value,secondary,mealtime,note\n"))
        XCTAssertTrue(csv.contains(#""before ""big, meal""""#))
    }
}

import XCTest
@testable import Steady

final class StatsTests: XCTestCase {
    func testAverageEmptyIsNil() { XCTAssertNil(Stats.average([])) }
    func testAverage() { XCTAssertEqual(Stats.average([120, 130, 140])!, 130, accuracy: 0.001) }
    func testRange() { XCTAssertEqual(Stats.range([7.2, 5.1, 6.0]), 5.1...7.2) }
    func testRangeEmptyIsNil() { XCTAssertNil(Stats.range([])) }
    func testInRangeCountBoundsInclusive() {
        XCTAssertEqual(Stats.inRangeCount([89, 90, 120, 121], target: 90...120), 2)
    }
    func testAdherence() { XCTAssertEqual(Stats.adherence(taken: 9, expected: 12)!, 0.75, accuracy: 0.001) }
    func testAdherenceZeroExpectedIsNil() { XCTAssertNil(Stats.adherence(taken: 0, expected: 0)) }
}

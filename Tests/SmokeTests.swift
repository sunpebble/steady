import XCTest
@testable import Steady

final class SmokeTests: XCTestCase {
    func testThemeLoads() { XCTAssertNotNil(Theme.sun) }
}

import XCTest
@testable import Steady

final class ProStoreTests: XCTestCase {
    func testReadsCachedUnlockOnInit() {
        let defaults = UserDefaults.standard
        let old = defaults.object(forKey: ProStore.proCacheKey)
        defer {
            if let old { defaults.set(old, forKey: ProStore.proCacheKey) }
            else { defaults.removeObject(forKey: ProStore.proCacheKey) }
        }

        defaults.set(true, forKey: ProStore.proCacheKey)
        XCTAssertTrue(ProStore().isPro)
    }
}

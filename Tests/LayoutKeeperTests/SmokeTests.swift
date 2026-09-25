import XCTest
@testable import LayoutKeeper

final class SmokeTests: XCTestCase {
    func testBundleLoads() {
        XCTAssertNotNil(Bundle.main.bundleIdentifier)
    }
}

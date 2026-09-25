import XCTest
@testable import LayoutKeeper

/// Integration tests against the real TIS API. They change the system layout briefly,
/// so they only run when `LK_INTEGRATION=1` (use `make test-integration`).
final class TISInputSourceServiceTests: XCTestCase {
    private let service = TISInputSourceService()

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LK_INTEGRATION"] == "1",
                          "Set LK_INTEGRATION=1 to run TIS integration tests")
    }

    func testListsAndReadsCurrent() throws {
        let sources = service.allSelectableKeyboardSources()
        XCTAssertFalse(sources.isEmpty)
        let current = try XCTUnwrap(service.current())
        XCTAssertTrue(sources.contains(current), "current source \(current.id) not in selectable list")
    }

    func testSelectUnknownIDFails() {
        XCTAssertFalse(service.select(id: "com.example.does-not-exist"))
    }

    /// Verifies that TISSelectInputSource works from the (sandboxed) host app.
    func testSelectSwitchesAndRestores() throws {
        print("Sandboxed: \(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)")
        let original = try XCTUnwrap(service.current())
        let other = try XCTUnwrap(service.allSelectableKeyboardSources().first { $0.id != original.id },
                                  "Need at least two input sources enabled")
        defer { service.select(id: original.id) }

        XCTAssertTrue(service.select(id: other.id))
        XCTAssertEqual(service.current()?.id, other.id)

        XCTAssertTrue(service.select(id: original.id))
        XCTAssertEqual(service.current()?.id, original.id)
    }
}

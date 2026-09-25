import XCTest
@testable import LayoutKeeper

final class StateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTrip() {
        let store = StateStore(directory: directory, debounce: 60)
        store.setMemory("com.apple.keylayout.US", for: "com.apple.Terminal")
        store.setMemory("com.apple.keylayout.Bulgarian-Phonetic", for: "com.tinyspeck.slackmacgap")
        store.flush()

        let reloaded = StateStore(directory: directory)
        XCTAssertEqual(reloaded.state, store.state)
        XCTAssertEqual(reloaded.state.memory.count, 2)
    }

    func testRemoveMemory() {
        let store = StateStore(directory: directory, debounce: 60)
        store.setMemory("com.apple.keylayout.US", for: "a")
        store.setMemory("com.apple.keylayout.US", for: "b")
        store.removeMemory(for: "a")
        store.flush()
        XCTAssertEqual(StateStore(directory: directory).state.memory, ["b": "com.apple.keylayout.US"])

        store.removeAllMemory()
        store.flush()
        XCTAssertTrue(StateStore(directory: directory).state.memory.isEmpty)
    }

    func testMissingFileGivesEmptyState() {
        XCTAssertEqual(StateStore(directory: directory).state, State())
    }
}

import XCTest
@testable import LayoutKeeper

private final class MockInputSources: InputSourceService {
    var sources: [InputSource]
    var currentID: String
    private(set) var selections: [String] = []

    init(ids: [String], current: String) {
        sources = ids.map { InputSource(id: $0, name: $0) }
        currentID = current
    }

    func allSelectableKeyboardSources() -> [InputSource] { sources }
    func current() -> InputSource? { sources.first { $0.id == currentID } }

    func select(id: String) -> Bool {
        guard sources.contains(where: { $0.id == id }) else { return false }
        selections.append(id)
        currentID = id
        return true
    }
}

@MainActor
final class SwitcherTests: XCTestCase {
    private let us = "com.apple.keylayout.US"
    private let bg = "com.apple.keylayout.Bulgarian-Phonetic"
    private var directory: URL!
    private var mock: MockInputSources!
    private var stateStore: StateStore!
    private var switcher: Switcher!
    private var hudTargets: [String] = []

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        mock = MockInputSources(ids: [us, bg], current: us)
        stateStore = StateStore(directory: directory, debounce: 60)
        switcher = Switcher(inputSources: mock, configStore: ConfigStore(directory: directory), stateStore: stateStore)
        switcher.onAutomaticSwitch = { [unowned self] in hudTargets.append($0) }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRestoresMemoryAndNotifies() {
        stateStore.setMemory(bg, for: "app")
        switcher.handleActivation(of: "app")
        XCTAssertEqual(mock.selections, [bg])
        XCTAssertEqual(hudTargets, [bg])
    }

    func testSkipsSelectWhenAlreadyCurrent() {
        stateStore.setMemory(us, for: "app")
        switcher.handleActivation(of: "app")
        XCTAssertTrue(mock.selections.isEmpty)
        XCTAssertTrue(hudTargets.isEmpty, "no HUD for a no-op")
    }

    func testLearnsCurrentForNewApp() {
        switcher.handleActivation(of: "new")
        XCTAssertEqual(stateStore.state.memory["new"], us)
        XCTAssertTrue(mock.selections.isEmpty)
    }

    func testDropsStaleMemory() {
        stateStore.setMemory("com.apple.keylayout.Removed", for: "app")
        switcher.handleActivation(of: "app")
        // Memory dropped, then the current source is learned instead.
        XCTAssertEqual(stateStore.state.memory["app"], us)
        XCTAssertTrue(mock.selections.isEmpty)
    }
}

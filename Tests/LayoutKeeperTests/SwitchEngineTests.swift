import XCTest
@testable import LayoutKeeper

final class SwitchEngineTests: XCTestCase {
    private let app = "com.example.App"
    private let us = "com.apple.keylayout.US"
    private let bg = "com.apple.keylayout.Bulgarian-Phonetic"
    private let custom = "org.sil.ukelele.keyboardlayout.custom.bg"
    private lazy var available: Set<String> = [us, bg, custom]

    private func resolve(_ config: Config = Config(), _ state: State = State()) -> SwitchEngine.Decision {
        SwitchEngine.resolve(bundleID: app, config: config, state: state, availableSourceIDs: available)
    }

    func testPausedIgnoresEverything() {
        var config = Config()
        config.enabled = false
        config.rules[app] = us
        config.defaultSourceID = us
        XCTAssertEqual(resolve(config, State(memory: [app: bg])), .ignore)
    }

    func testIgnoreListWinsOverRule() {
        var config = Config()
        config.ignore = [app]
        config.rules[app] = us
        XCTAssertEqual(resolve(config), .ignore)
    }

    func testRuleWinsOverMemory() {
        var config = Config()
        config.rules[app] = us
        XCTAssertEqual(resolve(config, State(memory: [app: bg])), .switchTo(us, .rule))
    }

    func testRuleSupportsCustomLayout() {
        var config = Config()
        config.rules[app] = custom
        XCTAssertEqual(resolve(config), .switchTo(custom, .rule))
    }

    func testMemoryWinsOverDefault() {
        var config = Config()
        config.defaultSourceID = us
        XCTAssertEqual(resolve(config, State(memory: [app: bg])), .switchTo(bg, .memory))
    }

    func testDefaultForUnknownApp() {
        var config = Config()
        config.defaultSourceID = us
        XCTAssertEqual(resolve(config, State(memory: ["com.other": bg])), .switchTo(us, .default))
    }

    func testLearnCurrentWithoutDefault() {
        XCTAssertEqual(resolve(), .learnCurrent)
    }

    func testMissingMemoryTargetFallsThroughToDefault() {
        var config = Config()
        config.defaultSourceID = us
        XCTAssertEqual(resolve(config, State(memory: [app: "com.apple.keylayout.Removed"])), .switchTo(us, .default))
    }

    func testMissingRuleTargetFallsThroughToMemory() {
        var config = Config()
        config.rules[app] = "com.apple.keylayout.Removed"
        XCTAssertEqual(resolve(config, State(memory: [app: bg])), .switchTo(bg, .memory))
    }

    func testMissingDefaultLearnsCurrent() {
        var config = Config()
        config.defaultSourceID = "com.apple.keylayout.Removed"
        XCTAssertEqual(resolve(config), .learnCurrent)
    }
}

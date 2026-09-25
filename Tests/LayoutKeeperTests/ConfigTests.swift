import XCTest
@testable import LayoutKeeper

final class ConfigTests: XCTestCase {
    private func decode(_ json: String) throws -> Config {
        try ConfigStore.decode(Data(json.utf8))
    }

    func testFullConfig() throws {
        let config = try decode("""
        {
          "version": 1,
          "enabled": false,
          "defaultSourceID": "com.apple.keylayout.US",
          "rules": { "com.apple.Terminal": "com.apple.keylayout.US" },
          "ignore": [ "com.apple.Spotlight" ],
          "labels": { "com.apple.keylayout.US": "EN" },
          "hud": { "enabled": false, "durationMs": 500 }
        }
        """)
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.defaultSourceID, "com.apple.keylayout.US")
        XCTAssertEqual(config.rules, ["com.apple.Terminal": "com.apple.keylayout.US"])
        XCTAssertEqual(config.ignore, ["com.apple.Spotlight"])
        XCTAssertEqual(config.labels, ["com.apple.keylayout.US": "EN"])
        XCTAssertFalse(config.hud.enabled)
        XCTAssertEqual(config.hud.durationMs, 500)
    }

    func testMinimalConfigUsesDefaults() throws {
        XCTAssertEqual(try decode(#"{ "version": 1 }"#), Config())
    }

    func testPartialHUDUsesDefaults() throws {
        let config = try decode(#"{ "version": 1, "hud": { "durationMs": 1200 } }"#)
        XCTAssertTrue(config.hud.enabled)
        XCTAssertEqual(config.hud.durationMs, 1200)
    }

    func testUnknownFieldsAreIgnored() throws {
        XCTAssertEqual(try decode(#"{ "version": 1, "futureOption": [1, 2, 3] }"#), Config())
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try decode(#"{ "version": 1, "#))
    }

    func testMissingVersionThrows() {
        XCTAssertThrowsError(try decode(#"{ "enabled": true }"#))
    }

    func testWrongTypeThrows() {
        XCTAssertThrowsError(try decode(#"{ "version": 1, "ignore": "com.apple.Spotlight" }"#))
    }
}

final class ConfigStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("config.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileGivesDefaultsWithoutError() {
        let store = ConfigStore(directory: directory)
        XCTAssertEqual(store.config, Config())
        XCTAssertNil(store.lastError)
    }

    func testMalformedFileKeepsLastGoodConfig() throws {
        try #"{ "version": 1, "ignore": ["a"] }"#.write(to: fileURL, atomically: true, encoding: .utf8)
        let store = ConfigStore(directory: directory)
        XCTAssertEqual(store.config.ignore, ["a"])

        try #"{ "version": 1, "ignore": [ }"#.write(to: fileURL, atomically: true, encoding: .utf8)
        store.load()
        XCTAssertEqual(store.config.ignore, ["a"])
        XCTAssertNotNil(store.lastError)

        try #"{ "version": 1 }"#.write(to: fileURL, atomically: true, encoding: .utf8)
        store.load()
        XCTAssertEqual(store.config, Config())
        XCTAssertNil(store.lastError)
    }
}

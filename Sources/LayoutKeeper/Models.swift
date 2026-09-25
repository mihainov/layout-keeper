import Foundation

/// User-edited configuration (`config.json`). Every field except `version` is optional in the file.
struct Config: Codable, Equatable {
    struct HUD: Codable, Equatable {
        var enabled = true
        var durationMs = 800

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
            durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? durationMs
        }
    }

    var version = 1
    var enabled = true
    var defaultSourceID: String?
    /// Bundle ID → input source ID. Rules override memory.
    var rules: [String: String] = [:]
    /// Bundle IDs that are never switched or learned.
    var ignore: [String] = []
    /// Input source ID → short label for the menu bar and HUD.
    var labels: [String: String] = [:]
    var hud = HUD()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        defaultSourceID = try c.decodeIfPresent(String.self, forKey: .defaultSourceID)
        rules = try c.decodeIfPresent([String: String].self, forKey: .rules) ?? rules
        ignore = try c.decodeIfPresent([String].self, forKey: .ignore) ?? ignore
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? labels
        hud = try c.decodeIfPresent(HUD.self, forKey: .hud) ?? hud
    }
}

/// App-written learned state (`state.json`).
struct State: Codable, Equatable {
    var version = 1
    /// Bundle ID → last input source ID used in that app.
    var memory: [String: String] = [:]

    init(memory: [String: String] = [:]) {
        self.memory = memory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? version
        memory = try c.decodeIfPresent([String: String].self, forKey: .memory) ?? memory
    }
}

enum Storage {
    /// `~/Library/Application Support/LayoutKeeper/`. Under the App Sandbox this resolves to
    /// `~/Library/Containers/dev.local.LayoutKeeper/Data/Library/Application Support/LayoutKeeper/`.
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LayoutKeeper", isDirectory: true)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

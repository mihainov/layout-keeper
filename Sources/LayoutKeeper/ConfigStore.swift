import Foundation
import os

/// Loads the user-edited `config.json`. A missing file means default settings.
/// A malformed file keeps the last good config and reports the problem in `lastError`.
final class ConfigStore {
    private(set) var config = Config()
    /// Human-readable description of the last load failure, or nil if the last load succeeded.
    private(set) var lastError: String?
    let fileURL: URL
    private let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "ConfigStore")

    init(directory: URL = Storage.defaultDirectory) {
        fileURL = directory.appendingPathComponent("config.json")
        load()
    }

    func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            config = Config()
            lastError = nil
            return
        } catch {
            fail("Can't read config.json: \(error.localizedDescription)")
            return
        }
        do {
            config = try Self.decode(data)
            lastError = nil
        } catch {
            fail("Invalid config.json: \(Self.describe(error))")
        }
    }

    enum UpdateError: LocalizedError {
        case configInvalid
        var errorDescription: String? { "Fix config.json and reload before changing settings from the menu." }
    }

    /// Reloads config.json, applies `change` and writes it back. Only the keys that change are rewritten;
    /// unknown keys in the file are preserved. Refuses to touch a file that fails to load.
    func update(_ change: (inout Config) -> Void) throws {
        load()
        guard lastError == nil else { throw UpdateError.configInvalid }
        var updated = config
        change(&updated)
        guard updated != config else { return }

        var object = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let old = try Self.jsonObject(config)
        let new = try Self.jsonObject(updated)
        for key in Set(old.keys).union(new.keys) where (old[key] as? NSObject) != (new[key] as? NSObject) {
            object[key] = new[key]
        }
        object["version"] = updated.version

        let data = try JSONSerialization.data(withJSONObject: object,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        config = updated
    }

    private static func jsonObject(_ config: Config) throws -> [String: Any] {
        let data = try Storage.makeEncoder().encode(config)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    static func decode(_ data: Data) throws -> Config {
        try JSONDecoder().decode(Config.self, from: data)
    }

    private func fail(_ message: String) {
        lastError = message
        log.error("\(message, privacy: .public); keeping last good config")
    }

    private static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return error.localizedDescription }
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            return keys.isEmpty ? "top level" : keys.joined(separator: ".")
        }
        switch error {
        case .dataCorrupted(let context):
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            return underlying ?? context.debugDescription
        case .keyNotFound(let key, _):
            return "missing required key \"\(key.stringValue)\""
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "wrong type at \(path(context))"
        @unknown default:
            return error.localizedDescription
        }
    }
}

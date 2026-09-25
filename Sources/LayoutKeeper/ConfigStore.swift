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

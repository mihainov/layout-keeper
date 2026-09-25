import Foundation
import os

/// Loads the user-edited `config.json`. A missing file means default settings.
final class ConfigStore {
    private(set) var config = Config()
    let fileURL: URL
    private let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "ConfigStore")

    init(directory: URL = Storage.defaultDirectory) {
        fileURL = directory.appendingPathComponent("config.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            config = Config()
            return
        }
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            log.error("Ignoring malformed config.json: \(error.localizedDescription, privacy: .public)")
        }
    }
}

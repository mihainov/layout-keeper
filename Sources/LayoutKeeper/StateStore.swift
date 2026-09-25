import Foundation
import os

/// Loads and saves `state.json`. Writes are atomic and debounced; call `flush()` on quit.
final class StateStore {
    private(set) var state: State
    let fileURL: URL
    private let debounce: TimeInterval
    private var pendingSave: DispatchWorkItem?
    private let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "StateStore")

    init(directory: URL = Storage.defaultDirectory, debounce: TimeInterval = 2) {
        fileURL = directory.appendingPathComponent("state.json")
        self.debounce = debounce
        state = State()
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            state = try JSONDecoder().decode(State.self, from: data)
        } catch {
            log.error("Ignoring unreadable state.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setMemory(_ sourceID: String, for bundleID: String) {
        guard state.memory[bundleID] != sourceID else { return }
        state.memory[bundleID] = sourceID
        scheduleSave()
    }

    func removeMemory(for bundleID: String) {
        guard state.memory.removeValue(forKey: bundleID) != nil else { return }
        scheduleSave()
    }

    func removeAllMemory() {
        guard !state.memory.isEmpty else { return }
        state.memory.removeAll()
        scheduleSave()
    }

    /// Writes any pending change immediately.
    func flush() {
        guard let pendingSave else { return }
        pendingSave.cancel()
        self.pendingSave = nil
        save()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.save()
        }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Storage.makeEncoder().encode(state).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Failed to save state.json: \(error.localizedDescription, privacy: .public)")
        }
    }
}

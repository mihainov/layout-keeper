import AppKit
import os

/// Wires app activations and input source changes to the SwitchEngine and the stores.
@MainActor
final class Switcher {
    struct Activation: Equatable {
        var bundleID: String
        var decision: SwitchEngine.Decision
    }

    let configStore: ConfigStore
    let stateStore: StateStore
    private let inputSources: InputSourceService
    private let appMonitor = AppMonitor()
    private let sourceChangeMonitor = SourceChangeMonitor()
    private let ownBundleID = Bundle.main.bundleIdentifier
    private let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "Switcher")

    /// Called after the switcher handles an activation or a source change.
    var onUpdate: ((Activation?) -> Void)?
    private(set) var lastActivation: Activation?

    init(inputSources: InputSourceService, configStore: ConfigStore, stateStore: StateStore) {
        self.inputSources = inputSources
        self.configStore = configStore
        self.stateStore = stateStore
    }

    func start() {
        appMonitor.start { [weak self] bundleID in
            Task { @MainActor in self?.handleActivation(of: bundleID) }
        }
        sourceChangeMonitor.start { [weak self] in
            Task { @MainActor in self?.handleSourceChange() }
        }
    }

    func handleActivation(of bundleID: String) {
        let config = configStore.config
        let available = Set(inputSources.allSelectableKeyboardSources().map(\.id))

        if let remembered = stateStore.state.memory[bundleID], !available.contains(remembered) {
            log.info("Dropping stale memory \(remembered, privacy: .public) for \(bundleID, privacy: .public)")
            stateStore.removeMemory(for: bundleID)
        }
        if let rule = config.rules[bundleID], !available.contains(rule) {
            log.error("Rule for \(bundleID, privacy: .public) targets missing source \(rule, privacy: .public)")
        }

        let decision = SwitchEngine.resolve(bundleID: bundleID, config: config, state: stateStore.state,
                                            availableSourceIDs: available)
        switch decision {
        case .ignore:
            break
        case .switchTo(let target, _):
            if inputSources.current()?.id != target {
                inputSources.select(id: target)
            }
        case .learnCurrent:
            if let current = inputSources.current() {
                stateStore.setMemory(current.id, for: bundleID)
            }
        }
        lastActivation = Activation(bundleID: bundleID, decision: decision)
        onUpdate?(lastActivation)
    }

    /// Records the new source as the frontmost app's memory.
    func handleSourceChange() {
        defer { onUpdate?(lastActivation) }
        let config = configStore.config
        guard config.enabled,
              let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              bundleID != ownBundleID,
              !config.ignore.contains(bundleID),
              let current = inputSources.current()
        else { return }
        stateStore.setMemory(current.id, for: bundleID)
    }
}

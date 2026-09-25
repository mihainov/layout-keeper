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

    /// The app whose activation was handled most recently. Source changes are only recorded for this
    /// app, so a change that arrives while another activation is still queued can't be misattributed.
    private var activeBundleID: String?
    private var pendingVerify: DispatchWorkItem?
    /// How long after a switch to check that it stuck.
    private let verifyDelay: TimeInterval = 0.15

    init(inputSources: InputSourceService, configStore: ConfigStore, stateStore: StateStore) {
        self.inputSources = inputSources
        self.configStore = configStore
        self.stateStore = stateStore
    }

    func start() {
        appMonitor.start { [weak self] bundleID in
            MainActor.assumeIsolated { self?.handleActivation(of: bundleID) }
        }
        sourceChangeMonitor.start { [weak self] in
            MainActor.assumeIsolated { self?.handleSourceChange() }
        }
    }

    func handleActivation(of bundleID: String) {
        activeBundleID = bundleID
        pendingVerify?.cancel()
        pendingVerify = nil
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
        log.notice("Activated \(bundleID, privacy: .public): \(String(describing: decision), privacy: .public)")
        switch decision {
        case .ignore:
            break
        case .switchTo(let target, _):
            if inputSources.current()?.id != target {
                inputSources.select(id: target)
                scheduleVerify(target: target, for: bundleID)
            }
        case .learnCurrent:
            if let current = inputSources.current() {
                stateStore.setMemory(current.id, for: bundleID)
            }
        }
        lastActivation = Activation(bundleID: bundleID, decision: decision)
        onUpdate?(lastActivation)
    }

    /// Records the new source as the active app's memory.
    func handleSourceChange() {
        defer { onUpdate?(lastActivation) }
        let config = configStore.config
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let current = inputSources.current()
        log.notice("Source changed to \(current?.id ?? "nil", privacy: .public), frontmost \(frontmost ?? "nil", privacy: .public), active \(self.activeBundleID ?? "nil", privacy: .public)")
        guard config.enabled,
              let bundleID = activeBundleID,
              // An activation is still queued; the change belongs to neither app for sure.
              frontmost == bundleID,
              bundleID != ownBundleID,
              !config.ignore.contains(bundleID),
              let current
        else { return }
        // Don't record a switch we are still verifying; it may be the system reverting it.
        if pendingVerify != nil, case .switchTo(let target, _)? = lastActivation?.decision, target != current.id {
            return
        }
        stateStore.setMemory(current.id, for: bundleID)
    }

    /// Re-applies `target` once if something reverted it right after activation.
    private func scheduleVerify(target: String, for bundleID: String) {
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.activeBundleID == bundleID else { return }
                self.pendingVerify = nil
                let current = self.inputSources.current()?.id
                guard current != target else { return }
                self.log.notice("Switch to \(target, privacy: .public) for \(bundleID, privacy: .public) was reverted to \(current ?? "nil", privacy: .public); retrying")
                self.inputSources.select(id: target)
                self.onUpdate?(self.lastActivation)
            }
        }
        pendingVerify = item
        DispatchQueue.main.asyncAfter(deadline: .now() + verifyDelay, execute: item)
    }
}

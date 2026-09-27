import AppKit

/// Shared app state backing the menu bar UI.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentSource: InputSource?
    @Published private(set) var config = Config()
    @Published private(set) var memory: [String: String] = [:]
    /// The app LayoutKeeper last handled (the user's frontmost app).
    @Published private(set) var activeBundleID: String?
    /// Problem with config.json, or the last failed menu action.
    @Published private(set) var errorMessage: String?
    @Published private(set) var launchAtLogin = LoginItemService.isEnabled
    @Published private(set) var launchAtLoginNeedsApproval = LoginItemService.requiresApproval

    private let inputSources: InputSourceService
    let switcher: Switcher
    private var terminateObserver: NSObjectProtocol?

    init(inputSources: InputSourceService = TISInputSourceService()) {
        self.inputSources = inputSources
        switcher = Switcher(inputSources: inputSources, configStore: ConfigStore(), stateStore: StateStore())
        switcher.onUpdate = { [weak self] _ in self?.sync() }
        sources = inputSources.allSelectableKeyboardSources()
        sync()
        switcher.start()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.switcher.stateStore.flush() }
        }
    }

    // MARK: - Derived state

    var isPaused: Bool { !config.enabled }

    /// Menu bar title: the current layout's label, or nil to show the keyboard symbol.
    var menuBarLabel: String? {
        guard !isPaused, let id = currentSource?.id else { return nil }
        return config.labels[id]
    }

    var activeAppName: String? {
        guard let bundleID = activeBundleID else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName ?? bundleID
    }

    /// What currently applies to the active app: "Rule", "Memory", "Default", "Ignored", ...
    var activeAppStatus: String? {
        guard let bundleID = activeBundleID else { return nil }
        if isPaused { return "Paused" }
        let decision = SwitchEngine.resolve(bundleID: bundleID, config: config, state: State(memory: memory),
                                            availableSourceIDs: Set(sources.map(\.id)))
        switch decision {
        case .ignore: return "Ignored"
        case .learnCurrent: return "New app"
        case .switchTo(let id, let reason): return "\(reason.rawValue): \(label(ofSource: id))"
        }
    }

    var isActiveAppIgnored: Bool { activeBundleID.map(config.ignore.contains) ?? false }
    var activeAppHasMemory: Bool { activeBundleID.map { memory[$0] != nil } ?? false }

    func label(ofSource id: String) -> String {
        config.labels[id] ?? sources.first { $0.id == id }?.name ?? id
    }

    // MARK: - Actions

    func togglePaused() {
        updateConfig { $0.enabled.toggle() }
    }

    func pinCurrentLayoutToActiveApp() {
        guard let bundleID = activeBundleID, let current = currentSource else { return }
        updateConfig { $0.rules[bundleID] = current.id }
    }

    func toggleIgnoreActiveApp() {
        guard let bundleID = activeBundleID else { return }
        updateConfig { config in
            if let index = config.ignore.firstIndex(of: bundleID) {
                config.ignore.remove(at: index)
            } else {
                config.ignore.append(bundleID)
            }
        }
    }

    func forgetActiveAppMemory() {
        guard let bundleID = activeBundleID else { return }
        switcher.stateStore.removeMemory(for: bundleID)
        sync()
    }

    func forgetAllMemory() {
        switcher.stateStore.removeAllMemory()
        sync()
    }

    func copyCurrentLayoutID() {
        guard let id = currentSource?.id else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(id, forType: .string)
    }

    func toggleLaunchAtLogin() {
        do {
            try LoginItemService.setEnabled(!launchAtLogin)
        } catch {
            errorMessage = "Launch at login: \(error.localizedDescription)"
        }
        refreshLoginItem()
        if launchAtLoginNeedsApproval {
            LoginItemService.openSystemSettings()
        }
    }

    func refreshLoginItem() {
        launchAtLogin = LoginItemService.isEnabled
        launchAtLoginNeedsApproval = LoginItemService.requiresApproval
    }

    func reloadConfig() {
        switcher.configStore.load()
        sources = inputSources.allSelectableKeyboardSources()
        sync()
    }

    func openConfigFolder() {
        let directory = switcher.configStore.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    // MARK: - Private

    private func updateConfig(_ change: (inout Config) -> Void) {
        do {
            try switcher.configStore.update(change)
            sync()
        } catch {
            sync()
            errorMessage = error.localizedDescription
        }
    }

    private func sync() {
        currentSource = inputSources.current()
        config = switcher.configStore.config
        memory = switcher.stateStore.state.memory
        activeBundleID = switcher.lastActivation?.bundleID
        errorMessage = switcher.configStore.lastError
        // The login item status can change in System Settings while the app runs.
        refreshLoginItem()
    }
}

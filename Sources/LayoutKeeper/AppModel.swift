import AppKit

/// Shared app state backing the menu bar UI.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentSource: InputSource?
    @Published private(set) var lastActivation: Switcher.Activation?

    private let inputSources: InputSourceService
    let switcher: Switcher
    private var terminateObserver: NSObjectProtocol?

    init(inputSources: InputSourceService = TISInputSourceService()) {
        self.inputSources = inputSources
        switcher = Switcher(inputSources: inputSources, configStore: ConfigStore(), stateStore: StateStore())
        refresh()
        switcher.onUpdate = { [weak self] activation in
            self?.lastActivation = activation
            self?.refreshCurrent()
        }
        switcher.start()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.switcher.stateStore.flush() }
        }
    }

    func refresh() {
        sources = inputSources.allSelectableKeyboardSources()
        refreshCurrent()
    }

    func select(_ source: InputSource) {
        inputSources.select(id: source.id)
        refreshCurrent()
    }

    func name(ofSource id: String) -> String {
        sources.first { $0.id == id }?.name ?? id
    }

    private func refreshCurrent() {
        currentSource = inputSources.current()
    }
}

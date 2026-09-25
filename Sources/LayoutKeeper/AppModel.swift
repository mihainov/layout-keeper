import Foundation

/// Shared app state backing the menu bar UI.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var currentSource: InputSource?

    private let inputSources: InputSourceService
    private let sourceChangeMonitor = SourceChangeMonitor()

    init(inputSources: InputSourceService = TISInputSourceService()) {
        self.inputSources = inputSources
        refresh()
        sourceChangeMonitor.start { [weak self] in
            Task { @MainActor in self?.refreshCurrent() }
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

    private func refreshCurrent() {
        currentSource = inputSources.current()
    }
}

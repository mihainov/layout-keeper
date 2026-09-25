import SwiftUI

@main
struct LayoutKeeperApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("LayoutKeeper", systemImage: "keyboard") {
            MenuContent(model: model)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text("Current: \(model.currentSource?.name ?? "unknown")")
        Text(model.currentSource?.id ?? "")
        if let activation = model.lastActivation {
            Text("Last app: \(activation.bundleID)")
            Text("Decision: \(describe(activation.decision))")
        }
        Divider()
        Menu("Debug: Layouts") {
            ForEach(model.sources) { source in
                Button {
                    model.select(source)
                } label: {
                    Text(source.id == model.currentSource?.id ? "✓ \(source.name)" : "    \(source.name)")
                }
            }
            Divider()
            Button("Refresh List") { model.refresh() }
        }
        Menu("Debug: Memory") {
            let memory = model.switcher.stateStore.state.memory.sorted { $0.key < $1.key }
            if memory.isEmpty {
                Text("(empty)")
            }
            ForEach(memory, id: \.key) { bundleID, sourceID in
                Text("\(bundleID) → \(model.name(ofSource: sourceID))")
            }
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func describe(_ decision: SwitchEngine.Decision) -> String {
        switch decision {
        case .ignore: return "Ignored"
        case .learnCurrent: return "Learned current"
        case .switchTo(let id, let reason): return "\(reason.rawValue) → \(model.name(ofSource: id))"
        }
    }
}

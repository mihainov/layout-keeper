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
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

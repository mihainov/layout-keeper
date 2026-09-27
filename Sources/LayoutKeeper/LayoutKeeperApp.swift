import SwiftUI

@main
struct LayoutKeeperApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            if let label = model.menuBarLabel {
                Text(label)
            } else {
                Image(systemName: model.isPaused ? "keyboard.badge.ellipsis" : "keyboard")
            }
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let error = model.errorMessage {
            Text("⚠️ \(error)")
            Divider()
        }

        Text(model.isPaused ? "Paused" : "Active")
        Text("Layout: \(model.currentSource.map { model.label(ofSource: $0.id) } ?? "unknown")")
        if let app = model.activeAppName, let status = model.activeAppStatus {
            Text("\(app) — \(status)")
        }
        Divider()

        Button(model.isPaused ? "Resume" : "Pause") { model.togglePaused() }
            .keyboardShortcut("p")
        Divider()

        if let app = model.activeAppName {
            Button("Pin Current Layout to “\(app)”") { model.pinCurrentLayoutToActiveApp() }
                .disabled(model.currentSource == nil)
            Button(model.isActiveAppIgnored ? "Stop Ignoring “\(app)”" : "Ignore “\(app)”") {
                model.toggleIgnoreActiveApp()
            }
            Button("Forget Memory for “\(app)”") { model.forgetActiveAppMemory() }
                .disabled(!model.activeAppHasMemory)
        }
        Button("Forget All Memory") { model.forgetAllMemory() }
            .disabled(model.memory.isEmpty)
        Divider()

        Button("Copy Current Layout ID") { model.copyCurrentLayoutID() }
            .keyboardShortcut("c")
        Button("Open Config Folder") { model.openConfigFolder() }
        Button("Reload Config") { model.reloadConfig() }
            .keyboardShortcut("r")
        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { _ in model.toggleLaunchAtLogin() }
        ))
        if model.launchAtLoginNeedsApproval {
            Button("Allow in Login Items Settings…") { LoginItemService.openSystemSettings() }
        }
        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

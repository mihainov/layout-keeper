import SwiftUI

@main
struct LayoutKeeperApp: App {
    var body: some Scene {
        MenuBarExtra("LayoutKeeper", systemImage: "keyboard") {
            Text("LayoutKeeper")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

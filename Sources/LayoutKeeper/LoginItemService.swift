import ServiceManagement
import os

/// Registers LayoutKeeper as a login item via `SMAppService.mainApp`.
/// Works reliably only when the app runs from /Applications (`make install`).
enum LoginItemService {
    private static let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "LoginItem")

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    /// Registered, but the user must still allow it in System Settings → General → Login Items.
    static var requiresApproval: Bool { status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister", privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

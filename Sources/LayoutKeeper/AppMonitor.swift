import AppKit

/// Reports the bundle ID of each newly activated app, skipping apps without one and LayoutKeeper itself.
final class AppMonitor {
    private var observer: NSObjectProtocol?

    func start(onActivate: @escaping (String) -> Void) {
        stop()
        let ownBundleID = Bundle.main.bundleIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let bundleID = app?.bundleIdentifier, bundleID != ownBundleID else { return }
            onActivate(bundleID)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    deinit { stop() }
}

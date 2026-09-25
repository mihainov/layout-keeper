import Foundation

/// Observes system-wide keyboard input source changes (manual or programmatic).
final class SourceChangeMonitor {
    private static let notification = Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged")
    private var observer: NSObjectProtocol?

    func start(onChange: @escaping () -> Void) {
        stop()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.notification, object: nil, queue: .main
        ) { _ in onChange() }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    deinit { stop() }
}

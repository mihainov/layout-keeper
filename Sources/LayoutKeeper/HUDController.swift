import AppKit
import SwiftUI

/// A small overlay that shows the new layout after an automatic switch. It never takes focus
/// and never receives mouse events.
@MainActor
final class HUDController {
    private let panel: NSPanel
    private let hostingView = NSHostingView(rootView: HUDView(text: ""))
    private var hideWorkItem: DispatchWorkItem?
    private let fadeDuration: TimeInterval = 0.2

    init() {
        panel = HUDPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = hostingView
    }

    func show(_ text: String, duration: TimeInterval) {
        hideWorkItem?.cancel()
        hostingView.rootView = HUDView(text: text)
        let size = hostingView.fittingSize
        panel.setFrame(frame(for: size), display: true)

        panel.alphaValue = 1
        // Shows the panel without activating LayoutKeeper or making the panel key.
        panel.orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.fadeOut() }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.panel.alphaValue == 0 else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    /// Bottom-center of the screen with the mouse cursor.
    private func frame(for size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSRect(x: visible.midX - size.width / 2, y: visible.minY + visible.height * 0.12,
                      width: size.width, height: size.height)
    }
}

private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct HUDView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .fixedSize()
    }
}

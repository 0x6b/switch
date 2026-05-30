import AppKit
import SwiftUI

final class SwitcherPanel: NSPanel {
    /// Fires the first time the panel sees a mouseMoved after being shown.
    /// Used to gate hover-driven selection until the user actually moves the mouse.
    var onFirstMouseMove: (() -> Void)?
    private var sawMouseMove = false

    init(rootView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hasShadow = true
        backgroundColor = .clear
        acceptsMouseMovedEvents = true

        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        contentViewController = hosting
    }

    func show() {
        // Recompute each show because dynamic content height changes the frame.
        sawMouseMove = false

        // Lay out and size to the current content before positioning, so the
        // origin below is computed from the correct height.
        if let content = contentViewController?.view {
            content.layoutSubtreeIfNeeded()
            setContentSize(content.fittingSize)
        }

        guard let screen = NSScreen.main else {
            orderFrontRegardless()
            return
        }
        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.maxY - screenFrame.height / 3 - frame.height
        )
        setFrameOrigin(origin)

        // When the window becomes visible the hosting controller runs a layout
        // pass that briefly resizes it to the empty-list height (~42pt) before
        // settling on the real height — a visible vertical flicker. Order in
        // transparent so that pass isn't drawn, then reveal on the next runloop
        // tick once the size has settled.
        alphaValue = 0
        orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.alphaValue = 1
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .mouseMoved, !sawMouseMove {
            sawMouseMove = true
            onFirstMouseMove?()
        }
        super.sendEvent(event)
    }
}

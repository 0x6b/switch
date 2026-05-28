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
        orderFrontRegardless()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .mouseMoved, !sawMouseMove {
            sawMouseMove = true
            onFirstMouseMove?()
        }
        super.sendEvent(event)
    }
}

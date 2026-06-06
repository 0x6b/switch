import AppKit
import SwiftUI

final class SwitcherPanel: NSPanel {
    /// The panel's width is a design constant — SwitcherView fixes its root
    /// frame to the same value; only the height tracks content.
    static let fixedWidth: CGFloat = 600

    /// Fires the first time the panel sees a mouseMoved after being shown.
    /// Used to gate hover-driven selection until the user actually moves the mouse.
    var onFirstMouseMove: (() -> Void)?
    private var sawMouseMove = false

    init(rootView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.fixedWidth, height: 480),
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

    /// The hosting controller (sizingOptions=.preferredContentSize) resizes the
    /// window behind our back; a transient wrong width shifts the row columns
    /// sideways. Pin the width — only the height is allowed to change.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        rect.size.width = Self.fixedWidth
        super.setFrame(rect, display: flag)
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
        // transparent so that pass isn't drawn, then reveal once the frame
        // matches the content's fitting size again. On a cold first show the
        // settle can take more than one runloop tick, so poll instead of
        // assuming one tick, with a small cap as a backstop.
        alphaValue = 0
        orderFrontRegardless()
        revealWhenSettled(remainingTicks: 5)
    }

    private func revealWhenSettled(remainingTicks: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.alphaValue == 0 else { return }
            let settled = self.contentViewController.map {
                self.frame.size == $0.view.fittingSize
            } ?? true
            if settled || remainingTicks <= 1 {
                self.alphaValue = 1
            } else {
                self.revealWhenSettled(remainingTicks: remainingTicks - 1)
            }
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

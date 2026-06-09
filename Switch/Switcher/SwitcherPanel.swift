import AppKit
import SwiftUI

final class SwitcherPanel: NSPanel {
    /// The panel's width is a design constant — SwitcherView fills this width;
    /// only the height tracks content.
    static let fixedWidth: CGFloat = 600

    /// Fires the first time the panel sees a mouseMoved after being shown.
    /// Used to gate hover-driven selection until the user actually moves the mouse.
    var onFirstMouseMove: (() -> Void)?
    private var sawMouseMove = false

    /// We host SwiftUI in a manually-managed NSHostingView rather than as a
    /// contentViewController. NSHostingController with .preferredContentSize
    /// installs Auto Layout constraints from SwiftUI's fitting size and resizes
    /// the window behind our back; during a height change it briefly proposes a
    /// narrower width to the SwiftUI root, which shifts the row columns sideways
    /// for one frame. With sizingOptions = [] and autoresizing we keep the
    /// hosting view exactly the window width at every layout pass, and we drive
    /// the window height ourselves via setFrame.
    private let hostingView: NSView

    init(rootView: some View) {
        let hosting = NSHostingView(rootView: rootView)
        // Keep intrinsicContentSize so we can read fittingSize.height to drive
        // the window height ourselves. Because the view uses an autoresizing
        // mask (no Auto Layout constraints to the window), this intrinsic size
        // is informational only — it never resizes the window behind our back,
        // unlike NSHostingController's .preferredContentSize did.
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hostingView = hosting

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

        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.fixedWidth, height: 480))
        hosting.frame = container.bounds
        container.addSubview(hosting)
        contentView = container
    }

    /// Belt-and-suspenders: the width is a design constant, never animated.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        rect.size.width = Self.fixedWidth
        super.setFrame(rect, display: flag)
    }

    func show() {
        sawMouseMove = false

        let size = NSSize(width: Self.fixedWidth, height: contentHeight())

        guard let screen = NSScreen.main else {
            setFrame(NSRect(origin: frame.origin, size: size), display: false)
            alphaValue = 1
            orderFrontRegardless()
            return
        }
        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - screenFrame.height / 3 - size.height
        )

        setFrame(NSRect(origin: origin, size: size), display: false)
        revealWhenLaidOut()
    }

    /// Even with the frame fully resolved before ordering in, the first on-screen
    /// layout/compositing pass (SwiftUI + glassEffect attachment) can briefly
    /// draw at the wrong height — a vertical flicker. Order in transparent, force
    /// the content to lay out and draw at its final size while invisible, then
    /// reveal on the next runloop tick (imperceptible, ~1 frame) so that pass is
    /// never seen.
    private func revealWhenLaidOut() {
        alphaValue = 0
        orderFrontRegardless()
        contentView?.layoutSubtreeIfNeeded()
        contentView?.displayIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.alphaValue = 1
        }
    }

    /// Re-fit the height when the row count changes mid-session. Anchors the top
    /// edge so the panel grows/shrinks downward instead of appearing to jump.
    /// No-op when the height is unchanged (e.g. selection-only updates), so this
    /// is cheap to call on every controller change.
    func resizeToContent() {
        guard isVisible else { return }
        let height = contentHeight()
        guard abs(frame.size.height - height) > 0.5 else { return }
        var rect = frame
        rect.origin.y += rect.size.height - height
        rect.size.height = height
        setFrame(rect, display: true)
    }

    private func contentHeight() -> CGFloat {
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .mouseMoved, !sawMouseMove {
            sawMouseMove = true
            onFirstMouseMove?()
        }
        super.sendEvent(event)
    }
}

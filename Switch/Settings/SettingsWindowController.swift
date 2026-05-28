import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Switch Settings"
        window.titleVisibility = .visible
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func showAndActivate() {
        // Switch to .regular so the window can become the active key window
        // (accessory apps' windows otherwise appear inactive).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to background-only once the user dismisses Settings.
        NSApp.setActivationPolicy(.accessory)
    }
}

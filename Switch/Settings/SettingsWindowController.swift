import AppKit
import SwiftUI

/// NSWindow that closes on Escape. `cancelOperation(_:)` is the action AppKit sends
/// up the responder chain for Esc (and Cmd-.); the default NSWindow ignores it.
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let launcherStore: LauncherConfigStore

    init(launcherStore: LauncherConfigStore) {
        self.launcherStore = launcherStore
        let hosting = NSHostingController(rootView: SettingsView(launcherStore: launcherStore))
        hosting.sizingOptions = [.preferredContentSize]
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
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
        // Sort here, not while the window is open — re-sorting on every edit
        // would yank rows out from under the user mid-edit.
        launcherStore.config.sortMappings()
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

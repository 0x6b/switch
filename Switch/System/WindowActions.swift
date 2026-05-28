import AppKit
import ApplicationServices

final class WindowActions: WindowActioning {
    func activate(_ entry: WindowEntry) {
        guard let app = NSRunningApplication(processIdentifier: entry.appPID) else { return }

        // Order matters: unhide first, then un-minimize, then activate + raise.
        if app.isHidden {
            app.unhide()
        }
        if let minimized: Bool = entry.axWindow.attribute(kAXMinimizedAttribute as String), minimized {
            entry.axWindow.setAttribute(kAXMinimizedAttribute as String, false as CFBoolean)
        }
        app.activate(options: [])
        entry.axWindow.perform(kAXRaiseAction as String)
    }

    func close(_ entry: WindowEntry) {
        guard let closeButton: AXUIElement = entry.axWindow.attribute(kAXCloseButtonAttribute as String) else { return }
        closeButton.perform(kAXPressAction as String)
    }

    func quit(_ entry: WindowEntry) {
        NSRunningApplication(processIdentifier: entry.appPID)?.terminate()
    }

    func hide(_ entry: WindowEntry) {
        NSRunningApplication(processIdentifier: entry.appPID)?.hide()
    }

    func minimize(_ entry: WindowEntry) {
        entry.axWindow.setAttribute(kAXMinimizedAttribute as String, true as CFBoolean)
    }
}

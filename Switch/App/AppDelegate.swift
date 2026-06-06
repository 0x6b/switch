import AppKit
import ApplicationServices
import Combine
import os.log

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.mainMenu = makeMainMenu()
        app.run()
    }

    /// Accessory apps have no menu bar, but AppKit still routes standard edit
    /// key equivalents (Cmd+V, Cmd+A, …) through mainMenu. Without this, text
    /// fields in the Settings window get no clipboard shortcuts.
    private static func makeMainMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let main = NSMenu()
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }

    private static let logger = Logger(subsystem: "io.warpnine.switch", category: "AppDelegate")

    private var controller: SwitcherController!
    private var panel: SwitcherPanel!
    private var tap: HotkeyTap!
    private let launcherStore = LauncherConfigStore()
    private var cancellable: AnyCancellable?
    private var clickOutsideMonitor: Any?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureAccessibilityTrusted() else {
            showOnboardingAndExit()
            return
        }

        controller = SwitcherController(provider: WindowList(), actions: WindowActions())
        panel = SwitcherPanel(rootView: SwitcherView(controller: controller))
        panel.onFirstMouseMove = { [weak self] in self?.controller.enableHover() }

        cancellable = controller.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.syncPanelVisibility() }

        tap = HotkeyTap(
            stateProvider: { [weak self] in self?.controller.state ?? .closed },
            handler: { [weak self] in self?.controller.handle($0) ?? .passthrough }
        )
        tap.onOpenSettings = { [weak self] in self?.openSettings() }
        tap.launcher = LauncherDecoder(configProvider: { [launcherStore] in launcherStore.config })
        tap.onLaunchApp = { target in
            guard let url = LauncherTarget.url(from: target) else { return }
            if url.isFileURL {
                // Launches if not running, brings to front otherwise.
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        do {
            try tap.install()
        } catch {
            Self.logger.error("Failed to install event tap: \(error.localizedDescription)")
            NSApp.terminate(nil)
        }

        // Dismiss the panel when the user clicks outside it. A global monitor only
        // sees clicks delivered to other apps, so clicks inside the panel never
        // fire this. Limited to filter mode — hold-cycle mode dismisses on the
        // modifier release instead.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, case .filter = controller.state else { return }
            controller.handle(.escape)
        }
    }

    /// Fired when the user reopens Switch (double-click in Finder, Dock click)
    /// while it's already running. Not called on the initial login/cold launch, so
    /// the panel won't pop up at boot. Summons the switcher in all-windows scope.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.openFiltered(mode: .allWindows)
        return true
    }

    func openSettings() {
        // Dismiss the switcher first; otherwise releasing the held modifier
        // would fire confirm() and activate the selected window, stealing
        // focus from the Settings window we're about to show.
        controller.handle(.escape)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(launcherStore: launcherStore)
        }
        settingsWindowController?.showAndActivate()
    }

    private func syncPanelVisibility() {
        if controller.state == .closed {
            panel.orderOut(nil)
        } else if !panel.isVisible {
            panel.show()
        }
    }

    private func ensureAccessibilityTrusted() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    private func showOnboardingAndExit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Accessibility permission required"
        alert.informativeText = """
            Switch needs Accessibility access to read window lists and intercept Cmd+Tab / Opt+Tab.

            Open System Settings → Privacy & Security → Accessibility, enable Switch, then relaunch this app.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        exit(0)
    }
}

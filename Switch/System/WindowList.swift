import AppKit
import ApplicationServices

final class WindowList: WindowProviding {
    private var axAppCache: [pid_t: AXUIElement] = [:]
    private let ourPID = getpid()

    /// Some apps keep phantom layer-0 windows on screen (e.g. CleanMyMac's
    /// untitled AXButton/AXUnknown helpers). Real windows report one of these.
    private static let allowedSubroles: Set<String> = [
        kAXStandardWindowSubrole as String,
        kAXDialogSubrole as String,
    ]

    private func isSwitchTarget(_ window: AXUIElement) -> Bool {
        guard let subrole: String = window.attribute(kAXSubroleAttribute as String) else { return false }
        return Self.allowedSubroles.contains(subrole)
    }

    func snapshot(mode: SwitcherMode) -> [WindowEntry] {
        let pidFilter: pid_t? = switch mode {
        case .allWindows: nil
        case .currentApp: NSWorkspace.shared.frontmostApplication?.processIdentifier
        }

        let onScreen = onScreenEntries(pidFilter: pidFilter)
        let seen = Set(onScreen.compactMap(\.cgWindowID))
        let extras = minimizedAndHiddenEntries(pidFilter: pidFilter, excludingCGIDs: seen)
            .sorted {
                ($0.appName.localizedLowercase, $0.windowTitle.localizedLowercase)
                    < ($1.appName.localizedLowercase, $1.windowTitle.localizedLowercase)
            }

        // Keep on-screen order, then minimized, then hidden.
        return onScreen
            + extras.filter { $0.section == .minimized }
            + extras.filter { $0.section == .hidden }
    }

    // MARK: - On-screen

    private func onScreenEntries(pidFilter: pid_t?) -> [WindowEntry] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return raw.compactMap { info -> WindowEntry? in
            // Drop non-normal layers (Dock, menu bar, status items, etc.)
            guard info[kCGWindowLayer as String] as? Int == 0 else { return nil }

            // Drop our own windows
            let pid = info[kCGWindowOwnerPID as String] as? pid_t ?? -1
            guard pid > 0, pid != ourPID else { return nil }
            if let pidFilter, pid != pidFilter { return nil }

            guard
                let cgID = info[kCGWindowNumber as String] as? CGWindowID,
                let app = NSRunningApplication(processIdentifier: pid),
                let axWindow = resolveAXWindow(pid: pid, cgID: cgID),
                isSwitchTarget(axWindow)
            else { return nil }

            // kCGWindowName requires Screen Recording permission; prefer AX, fall back to CG.
            let axTitle = windowTitle(axWindow)
            let cgTitle = info[kCGWindowName as String] as? String ?? ""

            return WindowEntry(
                appPID: pid,
                appName: app.localizedName ?? "",
                appIcon: app.icon ?? NSImage(),
                bundleID: app.bundleIdentifier,
                windowTitle: axTitle.isEmpty ? cgTitle : axTitle,
                cgWindowID: cgID,
                axWindow: axWindow,
                section: .current
            )
        }
    }

    // MARK: - Minimized and hidden

    private func minimizedAndHiddenEntries(
        pidFilter: pid_t?,
        excludingCGIDs excluded: Set<CGWindowID>
    ) -> [WindowEntry] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
                && $0.processIdentifier > 0
                && $0.processIdentifier != ourPID
                && (pidFilter == nil || $0.processIdentifier == pidFilter)
        }

        return apps.flatMap { app -> [WindowEntry] in
            let pid = app.processIdentifier
            let windows: [AXUIElement] = axApp(for: pid).attribute(kAXWindowsAttribute as String) ?? []
            return windows.compactMap { w in
                guard isSwitchTarget(w) else { return nil }
                let cgID = w.windowID()
                if let cgID, excluded.contains(cgID) { return nil }

                let section: WindowSection
                if app.isHidden {
                    section = .hidden
                } else if w.attribute(kAXMinimizedAttribute as String) ?? false {
                    section = .minimized
                } else {
                    // Ordinary on-screen window already covered above; CG ID was
                    // unresolvable here so skip to avoid duplicates.
                    return nil
                }

                return WindowEntry(
                    appPID: pid,
                    appName: app.localizedName ?? "",
                    appIcon: app.icon ?? NSImage(),
                    bundleID: app.bundleIdentifier,
                    windowTitle: windowTitle(w),
                    cgWindowID: cgID,
                    axWindow: w,
                    section: section
                )
            }
        }
    }

    // MARK: - Titles

    private func windowTitle(_ window: AXUIElement) -> String {
        if let title: String = window.attribute(kAXTitleAttribute as String), !title.isEmpty {
            return title
        }
        // Chrome PWA windows (e.g. Google Meet) fail AXTitle on the window element;
        // the document title is on the web-content child group instead.
        let children: [AXUIElement] = window.attribute(kAXChildrenAttribute as String) ?? []
        for child in children {
            if let title: String = child.attribute(kAXTitleAttribute as String), !title.isEmpty {
                return title
            }
        }
        return ""
    }

    // MARK: - AX resolution

    private func axApp(for pid: pid_t) -> AXUIElement {
        if let cached = axAppCache[pid] { return cached }
        let app = AXUIElementCreateApplication(pid)
        axAppCache[pid] = app
        return app
    }

    private func resolveAXWindow(pid: pid_t, cgID: CGWindowID) -> AXUIElement? {
        let windows: [AXUIElement]? = axApp(for: pid).attribute(kAXWindowsAttribute as String)
        return windows?.first { $0.windowID() == cgID }
    }
}

import AppKit
import ApplicationServices
@testable import Switch

/// Creates an AXUIElement we can safely use in test fixtures.
/// Returns the AX element for the test process itself — always valid, no permissions needed.
func makeTestAXElement() -> AXUIElement {
    AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
}

final class FakeWindowProvider: WindowProviding {
    var allWindows: [WindowEntry] = []
    var currentAppWindows: [WindowEntry] = []
    var snapshotCalls: [SwitcherMode] = []

    func snapshot(mode: SwitcherMode) -> [WindowEntry] {
        snapshotCalls.append(mode)
        switch mode {
        case .allWindows: return allWindows
        case .currentApp: return currentAppWindows
        }
    }
}

final class FakeWindowActions: WindowActioning {
    enum Call: Equatable {
        case activate(WindowEntry.ID)
        case close(WindowEntry.ID)
        case quit(WindowEntry.ID)
        case hide(WindowEntry.ID)
        case minimize(WindowEntry.ID)
        case place(WindowEntry.ID, PlacementAction)
    }

    var calls: [Call] = []

    func activate(_ entry: WindowEntry) { calls.append(.activate(entry.id)) }
    func close(_ entry: WindowEntry) { calls.append(.close(entry.id)) }
    func quit(_ entry: WindowEntry) { calls.append(.quit(entry.id)) }
    func hide(_ entry: WindowEntry) { calls.append(.hide(entry.id)) }
    func minimize(_ entry: WindowEntry) { calls.append(.minimize(entry.id)) }
    func place(_ entry: WindowEntry, _ action: PlacementAction) { calls.append(.place(entry.id, action)) }
}

/// Builds a synthetic WindowEntry for tests.
func makeEntry(
    pid: pid_t = 42,
    app: String = "TestApp",
    title: String = "Window",
    section: WindowSection = .current
) -> WindowEntry {
    WindowEntry(
        appPID: pid,
        appName: app,
        appIcon: NSImage(),
        bundleID: nil,
        windowTitle: title,
        cgWindowID: nil,
        axWindow: makeTestAXElement(),
        section: section
    )
}

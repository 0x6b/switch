import AppKit
import ApplicationServices

struct WindowEntry: Identifiable, Equatable {
    let id: UUID = UUID()
    let appPID: pid_t
    let appName: String
    let appIcon: NSImage
    let bundleID: String?
    let windowTitle: String
    let cgWindowID: CGWindowID?
    let axWindow: AXUIElement
    let section: WindowSection

    static func == (lhs: WindowEntry, rhs: WindowEntry) -> Bool { lhs.id == rhs.id }
}

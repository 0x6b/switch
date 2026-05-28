import ApplicationServices

/// Private AX SPI. Stable across macOS releases but not App Store safe.
/// Resolves the CGWindowID for an AXUIElement representing a window.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(self, name as CFString, &value)
        guard err == .success else { return nil }
        return value as? T
    }

    func setAttribute<T>(_ name: String, _ value: T) {
        AXUIElementSetAttributeValue(self, name as CFString, value as CFTypeRef)
    }

    func perform(_ action: String) {
        AXUIElementPerformAction(self, action as CFString)
    }

    func windowID() -> CGWindowID? {
        var id: CGWindowID = 0
        let err = _AXUIElementGetWindow(self, &id)
        return err == .success ? id : nil
    }
}

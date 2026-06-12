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

    /// Window frame in AX coordinates (top-left origin).
    func frame() -> CGRect? {
        guard let positionValue: AXValue = attribute(kAXPositionAttribute as String),
              let sizeValue: AXValue = attribute(kAXSizeAttribute as String) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Sets the window frame in AX coordinates. Size is applied before and
    /// after the position: macOS clamps a window's size to its current display,
    /// so a cross-display move needs the size re-applied once the move lands.
    func setFrame(_ rect: CGRect) {
        var origin = rect.origin
        var size = rect.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        setAttribute(kAXSizeAttribute as String, sizeValue)
        setAttribute(kAXPositionAttribute as String, positionValue)
        setAttribute(kAXSizeAttribute as String, sizeValue)
    }
}

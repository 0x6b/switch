import CoreGraphics
import Carbon.HIToolbox
import os.log

final class HotkeyTap {
    typealias Handler = (SwitcherEvent) -> HandleResult

    /// Called when the user presses the Settings shortcut (Cmd+,) while the
    /// switcher is open.
    var onOpenSettings: (() -> Void)?

    private let handler: Handler
    private let stateProvider: () -> SwitcherState
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var reEnableFailures: [Date] = []
    private let logger = Logger(subsystem: "io.warpnine.switch", category: "HotkeyTap")

    init(stateProvider: @escaping () -> SwitcherState, handler: @escaping Handler) {
        self.stateProvider = stateProvider
        self.handler = handler
    }

    enum TapError: Error { case tapCreateFailed }

    func install() throws {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<HotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handleTap(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            logger.error("CGEvent.tapCreate returned nil — Accessibility permission missing")
            throw TapError.tapCreateFailed
        }
        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
    }

    private func handleTap(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recoverTap()
            return Unmanaged.passUnretained(event)
        }

        if type == .scrollWheel {
            return handleScrollWheel(event: event)
        }

        let flags = event.flags
        let cmd = flags.contains(.maskCommand)
        let opt = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Settings shortcut: Cmd+, opens the Settings window, but only while the
        // switcher is open. When closed we must not swallow it — this is a global
        // session tap, so consuming Cmd+, here would steal it from every app.
        if type == .keyDown, cmd, !opt, keyCode == kVK_ANSI_Comma,
           stateProvider() != .closed {
            DispatchQueue.main.async { [weak self] in self?.onOpenSettings?() }
            return nil
        }

        let result = HotkeyDecoder.decode(
            type: type,
            keyCode: keyCode,
            flagsMaskCommand: cmd,
            flagsMaskOption: opt,
            flagsMaskShift: shift,
            state: stateProvider(),
            keyDownCharacter: type == .keyDown ? event.firstCharacter() : nil
        )

        switch result {
        case .passthrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .event(let switcherEvent):
            DispatchQueue.main.async { [weak self] in
                _ = self?.handler(switcherEvent)
            }
            return nil
        }
    }

    private var scrollAccumulator: CGFloat = 0
    private static let scrollTickThreshold: CGFloat = 30

    /// Consumes scroll events globally while the switcher is open, converting
    /// accumulated deltaY into arrow events. Passes events through otherwise.
    private func handleScrollWheel(event: CGEvent) -> Unmanaged<CGEvent>? {
        if case .closed = stateProvider() {
            scrollAccumulator = 0
            return Unmanaged.passUnretained(event)
        }

        let pointDelta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let lineDelta = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        // Trackpads populate the point delta with full resolution; mouse wheels
        // tick on the line delta. Scale the latter so one click = one row.
        let delta = pointDelta != 0 ? pointDelta : lineDelta * Double(Self.scrollTickThreshold)
        // Invert so swipe-down moves selection down (matches arrow-key direction).
        scrollAccumulator -= CGFloat(delta)

        while scrollAccumulator >= Self.scrollTickThreshold {
            DispatchQueue.main.async { [weak self] in _ = self?.handler(.scrollDown) }
            scrollAccumulator -= Self.scrollTickThreshold
        }
        while scrollAccumulator <= -Self.scrollTickThreshold {
            DispatchQueue.main.async { [weak self] in _ = self?.handler(.scrollUp) }
            scrollAccumulator += Self.scrollTickThreshold
        }
        return nil
    }

    private func recoverTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)

        let now = Date()
        reEnableFailures.append(now)
        reEnableFailures.removeAll { now.timeIntervalSince($0) > 60 }
        if reEnableFailures.count > 3 {
            logger.error("Event tap repeatedly disabled; terminating.")
            exit(1)
        }
    }
}

private extension CGEvent {
    /// First Unicode scalar produced by this key event, if any. Used for filter typing.
    func firstCharacter() -> Character? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0, let scalar = Unicode.Scalar(chars[0]) else { return nil }
        return Character(scalar)
    }
}

import Carbon.HIToolbox        // for kVK_* constants
import CoreGraphics

enum DecoderResult: Equatable {
    case passthrough                 // let the OS deliver this event normally
    case consume                     // swallow this event, no controller action
    case event(SwitcherEvent)        // swallow this event and dispatch to controller
}

enum HotkeyDecoder {
    static func decode(
        type: CGEventType,
        keyCode: Int,
        flagsMaskCommand: Bool,
        flagsMaskOption: Bool,
        flagsMaskShift: Bool,
        state: SwitcherState,
        keyDownCharacter: Character? = nil
    ) -> DecoderResult {

        // --- flagsChanged: detect modifier release ---
        if type == .flagsChanged {
            switch state {
            case .holdCycle(.cmd, _) where !flagsMaskCommand: return .event(.modifierUp(.cmd))
            case .holdCycle(.opt, _) where !flagsMaskOption:  return .event(.modifierUp(.opt))
            // In filter mode, swallow modifier changes so they don't reach apps,
            // but they don't trigger any controller action.
            case .filter:                                     return .event(.modifierUp(.cmd))
            default:                                          return .passthrough
            }
        }

        guard type == .keyDown else { return .passthrough }

        switch state {
        case .closed:
            return decodeClosed(keyCode: keyCode, cmd: flagsMaskCommand, opt: flagsMaskOption)
        case .holdCycle:
            return decodeHoldCycle(keyCode: keyCode, shift: flagsMaskShift)
        case .filter:
            return decodeFilter(keyCode: keyCode, shift: flagsMaskShift, character: keyDownCharacter)
        }
    }

    // MARK: - Per-state decoders

    private static func decodeClosed(keyCode: Int, cmd: Bool, opt: Bool) -> DecoderResult {
        switch (keyCode, cmd, opt) {
        case (kVK_Tab, true, false): return .event(.openAllWindows)
        case (kVK_Tab, false, true): return .event(.openCurrentApp)
        default:                     return .passthrough
        }
    }

    private static let holdCycleMap: [Int: SwitcherEvent] = [
        kVK_DownArrow: .arrowDown, kVK_ANSI_J: .arrowDown,
        kVK_UpArrow:   .arrowUp,   kVK_ANSI_K: .arrowUp,
        kVK_PageDown:  .arrowDown, kVK_PageUp:  .arrowUp,
        kVK_End:       .moveToBottom, kVK_Home: .moveToTop,
        kVK_Escape:    .escape,
        kVK_ANSI_W:    .action(.closeWindow),
        kVK_ANSI_Q:    .action(.quitApp),
        kVK_ANSI_H:    .action(.hideApp),
        kVK_ANSI_M:    .action(.minimizeWindow),
        kVK_ANSI_S:    .enterFilterMode,
    ]

    private static func decodeHoldCycle(keyCode: Int, shift: Bool) -> DecoderResult {
        if keyCode == kVK_Tab { return .event(shift ? .tabBackward : .tabForward) }
        // Unknown keys are swallowed so they don't leak through to the focused app.
        return holdCycleMap[keyCode].map(DecoderResult.event) ?? .consume
    }

    private static func decodeFilter(keyCode: Int, shift: Bool, character: Character?) -> DecoderResult {
        // In FilterMode every printable key is treated as filter input — including
        // w/q/h/m. Action keys are only available in HoldCycle.
        switch keyCode {
        case kVK_Tab:                              return .event(shift ? .tabBackward : .tabForward)
        case kVK_DownArrow, kVK_PageDown:          return .event(.arrowDown)
        case kVK_UpArrow, kVK_PageUp:              return .event(.arrowUp)
        case kVK_Home:                             return .event(.moveToTop)
        case kVK_End:                              return .event(.moveToBottom)
        case kVK_Return, kVK_ANSI_KeypadEnter:     return .event(.enter)
        case kVK_Escape:                           return .event(.escape)
        case kVK_Delete:                           return .event(.backspace)
        default:
            guard let ch = character, let scalar = ch.unicodeScalars.first else {
                return .consume
            }
            // Ctrl+H (BS) or forward DEL → backspace. Ctrl+W (ETB) → delete word.
            // Other non-printables are swallowed but never inserted into the
            // filter — see controller.
            if scalar.value == 0x08 || scalar.value == 0x7F { return .event(.backspace) }
            if scalar.value == 0x17 { return .event(.deleteWord) }
            return .event(.character(ch))
        }
    }
}

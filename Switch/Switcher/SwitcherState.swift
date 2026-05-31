import Foundation

enum SwitcherMode: Equatable {
    case allWindows    // Cmd+Tab
    case currentApp    // Opt+Tab
}

enum HoldModifier: Equatable {
    case cmd
    case opt
}

enum WindowSection: Hashable {
    case current      // on-screen, current Space
    case minimized
    case hidden

    var label: String {
        switch self {
        case .current:   "Current"
        case .minimized: "Minimized"
        case .hidden:    "Hidden"
        }
    }
}

enum SwitcherState: Equatable {
    case closed
    case holdCycle(modifier: HoldModifier, mode: SwitcherMode)
    case filter(mode: SwitcherMode)

    var mode: SwitcherMode? {
        switch self {
        case .closed: nil
        case .holdCycle(_, let mode), .filter(let mode): mode
        }
    }
}

enum WindowAction: Equatable {
    case closeWindow
    case quitApp
    case hideApp
    case minimizeWindow
}

enum SwitcherEvent: Equatable {
    case openAllWindows
    case openCurrentApp
    case modifierUp(HoldModifier)
    case tabForward
    case tabBackward
    case arrowDown
    case arrowUp
    case moveToTop            // Home: jump to first row
    case moveToBottom         // End: jump to last row
    case scrollDown
    case scrollUp
    case enterFilterMode      // S (with modifier still held)
    case enter                // FilterMode confirm
    case escape
    case action(WindowAction)
    case character(Character)
    case backspace
    case deleteWord           // Ctrl+W: delete the word before the cursor
}

enum HandleResult: Equatable {
    case consumed       // event tap should swallow this event
    case passthrough    // event tap should let it through
}

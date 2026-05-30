import Foundation

final class SwitcherController: ObservableObject {
    @Published private(set) var state: SwitcherState = .closed
    @Published private(set) var rows: [WindowEntry] = []
    @Published private(set) var selection: Int = 0
    @Published private(set) var filter: String = ""

    private var snapshot: [WindowEntry] = []
    private let provider: WindowProviding
    private let actions: WindowActioning
    private var hoverEnabled = false
    private var pendingHoverID: WindowEntry.ID?

    init(provider: WindowProviding, actions: WindowActioning) {
        self.provider = provider
        self.actions = actions
    }

    /// Opens the switcher directly into the persistent filter mode, without a held
    /// modifier. Used when the app is reopened (double-clicked) rather than summoned
    /// by a hotkey: there's no modifier to release, so the hold-cycle mode can't apply.
    func openFiltered(mode: SwitcherMode = .allWindows) {
        snapshot = provider.snapshot(mode: mode)
        rows = snapshot
        selection = 0
        filter = ""
        state = .filter(mode: mode)
    }

    @discardableResult
    func handle(_ event: SwitcherEvent) -> HandleResult {
        // ---- Closed: only the two open events do anything. ----
        if case .closed = state {
            switch event {
            case .openAllWindows: return open(mode: .allWindows, modifier: .cmd)
            case .openCurrentApp: return open(mode: .currentApp, modifier: .opt)
            default: return .passthrough
            }
        }

        // ---- Shared HoldCycle / Filter handling ----
        switch (state, event) {
        case (_, .tabForward), (_, .arrowDown):
            advance(by: 1)
        case (_, .tabBackward), (_, .arrowUp):
            advance(by: -1)
        case (_, .scrollDown):
            advance(by: 1, wrap: false)
        case (_, .scrollUp):
            advance(by: -1, wrap: false)
        case (_, .escape):
            close()
        case (_, .action(let action)):
            performAction(action)

        case (.holdCycle(let mod, _), .modifierUp(let up)) where mod == up:
            confirm()
        case (.holdCycle(_, let mode), .enterFilterMode):
            state = .filter(mode: mode)
            filter = ""
            applyFilter()

        case (.filter, .enter):
            confirm()
        case (.filter, .character(let ch)) where Self.isPrintable(ch):
            filter.append(ch)
            applyFilter()
        case (.filter, .backspace):
            if !filter.isEmpty { filter.removeLast() }
            applyFilter()
        case (.filter, .deleteWord):
            deleteLastWord()
            applyFilter()

        default:
            break   // swallow stray events while open
        }
        return .consumed
    }

    /// Activates the row with the given id (from a mouse click). Closes the panel.
    func activate(rowID: WindowEntry.ID) {
        guard let entry = rows.first(where: { $0.id == rowID }) else { return }
        actions.activate(entry)
        close()
    }

    /// Moves the selection to the row with the given id. Used by the keyboard path.
    /// Silently ignores unknown ids (rows can change between event dispatch and handling).
    func select(rowID: WindowEntry.ID) {
        if let index = rows.firstIndex(where: { $0.id == rowID }) {
            selection = index
        }
    }

    /// Mouse hover request from the view. Suppressed until the user has moved the
    /// mouse at least once since the panel opened, so a cursor parked over a row
    /// at open time doesn't steal the default keyboard selection.
    func hover(rowID: WindowEntry.ID) {
        if hoverEnabled {
            select(rowID: rowID)
        } else {
            pendingHoverID = rowID
        }
    }

    /// Called once the panel detects the first real mouse movement.
    func enableHover() {
        hoverEnabled = true
        if let pending = pendingHoverID {
            select(rowID: pending)
            pendingHoverID = nil
        }
    }

    // MARK: - Private

    private func open(mode: SwitcherMode, modifier: HoldModifier) -> HandleResult {
        snapshot = provider.snapshot(mode: mode)
        rows = snapshot
        selection = rows.count > 1 ? 1 : 0
        state = .holdCycle(modifier: modifier, mode: mode)
        return .consumed
    }

    private func close() {
        snapshot = []
        rows = []
        selection = 0
        filter = ""
        hoverEnabled = false
        pendingHoverID = nil
        state = .closed
    }

    private func confirm() {
        if let entry = selectedEntry() { actions.activate(entry) }
        close()
    }

    private func advance(by delta: Int, wrap: Bool = true) {
        guard !rows.isEmpty else { return }
        let count = rows.count
        if wrap {
            selection = ((selection + delta) % count + count) % count
        } else {
            selection = max(0, min(count - 1, selection + delta))
        }
    }

    private func selectedEntry() -> WindowEntry? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }

    private func performAction(_ action: WindowAction) {
        guard let entry = selectedEntry() else { return }
        switch action {
        case .closeWindow:    actions.close(entry)
        case .quitApp:        actions.quit(entry)
        case .hideApp:        actions.hide(entry)
        case .minimizeWindow: actions.minimize(entry)
        }
        refreshSnapshot()
        // OS hide/minimize/close are async with animations; poll a few times so
        // the panel reflects the new state without the user having to nudge it.
        for delay in [0.1, 0.4, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshSnapshot()
            }
        }
    }

    private func refreshSnapshot() {
        guard let mode = state.mode else { return }
        snapshot = provider.snapshot(mode: mode)
        if case .filter = state {
            applyFilter()
        } else {
            rows = snapshot
        }
        selection = rows.isEmpty ? 0 : min(selection, rows.count - 1)
    }

    /// Ctrl+W: drop trailing whitespace, then the run of non-whitespace before it.
    private func deleteLastWord() {
        while let last = filter.last, last.isWhitespace { filter.removeLast() }
        while let last = filter.last, !last.isWhitespace { filter.removeLast() }
    }

    private func applyFilter() {
        rows = snapshot.filter {
            FilterEngine.matches(haystack: "\($0.appName) \($0.windowTitle)", filter: filter)
        }
        selection = 0
    }

    /// True for characters we want to insert into the filter string.
    /// Filters out control codes and Apple's function-key private-use range
    /// (arrow keys, F1–F12, etc. all live in 0xF700–0xF8FF).
    private static func isPrintable(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        let v = scalar.value
        return v >= 0x20 && v != 0x7F && !(0xF700...0xF8FF).contains(v)
    }
}

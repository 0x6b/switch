import XCTest
@testable import Switch

final class SwitcherControllerTests: XCTestCase {
    var provider: FakeWindowProvider!
    var actions: FakeWindowActions!
    var controller: SwitcherController!

    override func setUp() {
        super.setUp()
        provider = FakeWindowProvider()
        actions = FakeWindowActions()
        controller = SwitcherController(provider: provider, actions: actions)
    }

    func testStartsClosed() {
        XCTAssertEqual(controller.state, .closed)
        XCTAssertTrue(controller.rows.isEmpty)
    }

    func testOpenAllWindowsLoadsSnapshotAndAdvancesPastFirst() {
        let a = makeEntry(app: "A")
        let b = makeEntry(app: "B")
        let c = makeEntry(app: "C")
        provider.allWindows = [a, b, c]

        let result = controller.handle(.openAllWindows)

        XCTAssertEqual(result, .consumed)
        XCTAssertEqual(controller.state, .holdCycle(modifier: .cmd, mode: .allWindows))
        XCTAssertEqual(controller.rows.map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(controller.selection, 1, "selection starts on the second row so initial advance lands on next-most-recent")
    }

    func testOpenCurrentAppUsesOptModifier() {
        provider.currentAppWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openCurrentApp)
        XCTAssertEqual(controller.state, .holdCycle(modifier: .opt, mode: .currentApp))
    }

    func testTabForwardAndBackwardCycle() {
        provider.allWindows = [makeEntry(), makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        XCTAssertEqual(controller.selection, 1)

        _ = controller.handle(.tabForward)
        XCTAssertEqual(controller.selection, 2)

        _ = controller.handle(.tabForward)
        XCTAssertEqual(controller.selection, 0, "wraps around")

        _ = controller.handle(.tabBackward)
        XCTAssertEqual(controller.selection, 2, "wraps around the other way")
    }

    func testArrowKeysSameAsTab() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.arrowDown)
        XCTAssertEqual(controller.selection, 0)
        _ = controller.handle(.arrowUp)
        XCTAssertEqual(controller.selection, 1)
    }

    func testEmptySnapshotKeepsSelectionAtZero() {
        provider.allWindows = []
        _ = controller.handle(.openAllWindows)
        XCTAssertEqual(controller.selection, 0)
        _ = controller.handle(.tabForward)
        XCTAssertEqual(controller.selection, 0)
    }

    func testSingleRowSelectionStaysAtZero() {
        provider.allWindows = [makeEntry()]
        _ = controller.handle(.openAllWindows)
        XCTAssertEqual(controller.selection, 0, "with one row there's no 'next' to advance to")
    }

    func testModifierUpInHoldCycleActivatesSelectionAndCloses() {
        let a = makeEntry(app: "A")
        let b = makeEntry(app: "B")
        provider.allWindows = [a, b]
        _ = controller.handle(.openAllWindows)
        // selection is now 1 (= b)

        let result = controller.handle(.modifierUp(.cmd))

        XCTAssertEqual(result, .consumed)
        XCTAssertEqual(controller.state, .closed)
        XCTAssertEqual(actions.calls, [.activate(b.id)])
        XCTAssertTrue(controller.rows.isEmpty)
    }

    func testWrongModifierUpDoesNothing() {
        // Cmd+Tab opened the panel; only Cmd up should confirm.
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        let result = controller.handle(.modifierUp(.opt))
        XCTAssertEqual(result, .consumed, "still swallow the event")
        XCTAssertEqual(actions.calls, [], "but do not activate")
        XCTAssertEqual(controller.state, .holdCycle(modifier: .cmd, mode: .allWindows))
    }

    func testEscapeInHoldCycleCancelsWithoutActivating() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        let result = controller.handle(.escape)
        XCTAssertEqual(result, .consumed)
        XCTAssertEqual(controller.state, .closed)
        XCTAssertEqual(actions.calls, [])
    }

    func testActionKeysInHoldCycleActOnSelection() {
        let a = makeEntry(app: "A")
        let b = makeEntry(app: "B")
        provider.allWindows = [a, b]
        _ = controller.handle(.openAllWindows)
        // selection = 1 (b)

        _ = controller.handle(.action(.closeWindow))
        XCTAssertEqual(actions.calls, [.close(b.id)])

        _ = controller.handle(.action(.quitApp))
        XCTAssertEqual(actions.calls.last, .quit(b.id))

        _ = controller.handle(.action(.hideApp))
        XCTAssertEqual(actions.calls.last, .hide(b.id))

        _ = controller.handle(.action(.minimizeWindow))
        XCTAssertEqual(actions.calls.last, .minimize(b.id))
    }

    func testActionKeysKeepPanelOpenAndRefreshSnapshot() {
        let a = makeEntry(app: "A")
        let b = makeEntry(app: "B")
        provider.allWindows = [a, b]
        _ = controller.handle(.openAllWindows)

        // After the action, simulate that the row is gone from the world:
        provider.allWindows = [a]
        _ = controller.handle(.action(.closeWindow))

        XCTAssertEqual(controller.state, .holdCycle(modifier: .cmd, mode: .allWindows))
        XCTAssertEqual(controller.rows.map(\.id), [a.id])
        XCTAssertEqual(controller.selection, 0, "selection clamped into new range")
    }

    func testSTransitionsToFilterMode() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        XCTAssertEqual(controller.state, .filter(mode: .allWindows))
        XCTAssertEqual(controller.filter, "")
        XCTAssertEqual(controller.selection, 0, "selection resets to first row when filter starts")
    }

    func testCharactersAndBackspaceEditFilter() {
        let a = makeEntry(app: "Alpha")
        let b = makeEntry(app: "Beta")
        let c = makeEntry(app: "Bravo")
        provider.allWindows = [a, b, c]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)

        _ = controller.handle(.character("b"))
        XCTAssertEqual(controller.filter, "b")
        XCTAssertEqual(controller.rows.map(\.id), [b.id, c.id])
        XCTAssertEqual(controller.selection, 0)

        _ = controller.handle(.character("e"))
        XCTAssertEqual(controller.filter, "be")
        XCTAssertEqual(controller.rows.map(\.id), [b.id])

        _ = controller.handle(.backspace)
        XCTAssertEqual(controller.filter, "b")
        XCTAssertEqual(controller.rows.map(\.id), [b.id, c.id])

        _ = controller.handle(.backspace)
        XCTAssertEqual(controller.filter, "")
        XCTAssertEqual(controller.rows.map(\.id), [a.id, b.id, c.id])
    }

    func testDeleteWordRemovesPreviousWord() {
        provider.allWindows = [makeEntry(app: "Alpha"), makeEntry(app: "Beta")]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        for ch in "alpha one" { _ = controller.handle(.character(ch)) }
        XCTAssertEqual(controller.filter, "alpha one")

        _ = controller.handle(.deleteWord)
        XCTAssertEqual(controller.filter, "alpha ", "drops the last word, keeps the separating space")

        _ = controller.handle(.deleteWord)
        XCTAssertEqual(controller.filter, "", "trailing space then the remaining word are removed")

        _ = controller.handle(.deleteWord)
        XCTAssertEqual(controller.filter, "", "no-op on an empty filter")
    }

    func testFilterTabAndArrowsNavigateFilteredRows() {
        let a = makeEntry(app: "Alpha")
        let b = makeEntry(app: "Beta")
        let c = makeEntry(app: "Bravo")
        provider.allWindows = [a, b, c]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        _ = controller.handle(.character("b"))

        _ = controller.handle(.tabForward)
        XCTAssertEqual(controller.selection, 1)
        _ = controller.handle(.tabForward)
        XCTAssertEqual(controller.selection, 0, "wraps")
        _ = controller.handle(.arrowUp)
        XCTAssertEqual(controller.selection, 1)
    }

    func testEnterInFilterModeActivatesSelected() {
        let a = makeEntry(app: "Alpha")
        let b = makeEntry(app: "Beta")
        provider.allWindows = [a, b]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        _ = controller.handle(.character("b"))

        _ = controller.handle(.enter)

        XCTAssertEqual(actions.calls, [.activate(b.id)])
        XCTAssertEqual(controller.state, .closed)
    }

    func testEscapeInFilterModeCancels() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        _ = controller.handle(.escape)
        XCTAssertEqual(controller.state, .closed)
        XCTAssertEqual(actions.calls, [])
    }

    func testActionKeysWorkInFilterMode() {
        let a = makeEntry(app: "Alpha")
        let b = makeEntry(app: "Beta")
        provider.allWindows = [a, b]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        _ = controller.handle(.character("b"))

        _ = controller.handle(.action(.closeWindow))
        XCTAssertEqual(actions.calls, [.close(b.id)])
    }

    func testModifierUpInFilterModeDoesNotActivate() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)
        _ = controller.handle(.modifierUp(.cmd))
        XCTAssertEqual(controller.state, .filter(mode: .allWindows), "modifier release no longer commits in filter mode")
        XCTAssertEqual(actions.calls, [])
    }

    func testActivateByRowIDFromMouseClick() {
        let a = makeEntry(app: "A")
        let b = makeEntry(app: "B")
        let c = makeEntry(app: "C")
        provider.allWindows = [a, b, c]
        _ = controller.handle(.openAllWindows)

        controller.activate(rowID: c.id)

        XCTAssertEqual(actions.calls, [.activate(c.id)])
        XCTAssertEqual(controller.state, .closed)
    }

    func testHoverIsSuppressedUntilEnabled() {
        let a = makeEntry()
        let b = makeEntry()
        let c = makeEntry()
        provider.allWindows = [a, b, c]
        _ = controller.handle(.openAllWindows)
        XCTAssertEqual(controller.selection, 1)

        // Cursor parked on row C when panel opens — hover comes in but should be ignored.
        controller.hover(rowID: c.id)
        XCTAssertEqual(controller.selection, 1, "hover before enable must not move selection")

        // First real mouse move arrives; the pending hover should snap selection now.
        controller.enableHover()
        XCTAssertEqual(controller.selection, 2)

        // Subsequent hovers update selection directly.
        controller.hover(rowID: a.id)
        XCTAssertEqual(controller.selection, 0)
    }

    func testHoverEnableIsResetOnClose() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        controller.enableHover()
        _ = controller.handle(.escape)

        // Re-open: hover must again be suppressed until enableHover() is called.
        let x = makeEntry()
        let y = makeEntry()
        provider.allWindows = [x, y]
        _ = controller.handle(.openAllWindows)
        // default selection is index 1; hover row x (index 0) — should NOT move because suppressed.
        controller.hover(rowID: x.id)
        XCTAssertEqual(controller.selection, 1, "hover before enable must not move selection on re-open")
    }

    func testSelectByRowIDMovesSelectionWithoutActivating() {
        let a = makeEntry()
        let b = makeEntry()
        let c = makeEntry()
        provider.allWindows = [a, b, c]
        _ = controller.handle(.openAllWindows)
        XCTAssertEqual(controller.selection, 1)

        controller.select(rowID: c.id)

        XCTAssertEqual(controller.selection, 2)
        XCTAssertEqual(actions.calls, [])
        XCTAssertEqual(controller.state, .holdCycle(modifier: .cmd, mode: .allWindows))
    }

    func testSelectUnknownRowIDIsIgnored() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)
        let priorSelection = controller.selection

        controller.select(rowID: UUID())

        XCTAssertEqual(controller.selection, priorSelection)
    }

    func testActivateUnknownRowIDIsIgnored() {
        provider.allWindows = [makeEntry(), makeEntry()]
        _ = controller.handle(.openAllWindows)

        controller.activate(rowID: UUID())

        XCTAssertEqual(actions.calls, [])
        XCTAssertEqual(controller.state, .holdCycle(modifier: .cmd, mode: .allWindows))
    }

    func testFilterDropsNonPrintableCharacters() {
        provider.allWindows = [makeEntry(app: "A")]
        _ = controller.handle(.openAllWindows)
        _ = controller.handle(.enterFilterMode)

        // Control characters (Ctrl+letter combos) and function-key private-use
        // codepoints (arrows etc.) must not enter the filter string.
        _ = controller.handle(.character(Character(UnicodeScalar(0x01)!)))  // SOH (Ctrl+A)
        _ = controller.handle(.character(Character(UnicodeScalar(0x17)!)))  // ETB (Ctrl+W)
        _ = controller.handle(.character(Character(UnicodeScalar(0xF702)!))) // NSLeftArrowFunctionKey
        XCTAssertEqual(controller.filter, "")

        _ = controller.handle(.character("a"))
        XCTAssertEqual(controller.filter, "a")
    }
}

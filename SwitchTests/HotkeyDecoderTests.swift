import XCTest
import Carbon.HIToolbox
import CoreGraphics
@testable import Switch

final class HotkeyDecoderTests: XCTestCase {

    /// Convenience wrapper so each case stays a single readable line.
    private func decode(
        key keyCode: Int,
        type: CGEventType = .keyDown,
        cmd: Bool = false, opt: Bool = false, shift: Bool = false, ctrl: Bool = false,
        state: SwitcherState,
        char: Character? = nil
    ) -> DecoderResult {
        HotkeyDecoder.decode(
            type: type,
            keyCode: keyCode,
            flagsMaskCommand: cmd,
            flagsMaskOption: opt,
            flagsMaskShift: shift,
            flagsMaskControl: ctrl,
            state: state,
            keyDownCharacter: char
        )
    }

    private let cycle = SwitcherState.holdCycle(modifier: .cmd, mode: .allWindows)
    private let filtering = SwitcherState.filter(mode: .allWindows)

    // MARK: - Closed

    func testClosedConsumesCmdTab() {
        XCTAssertEqual(decode(key: kVK_Tab, cmd: true, state: .closed), .event(.openAllWindows))
    }

    func testClosedConsumesOptTab() {
        XCTAssertEqual(decode(key: kVK_Tab, opt: true, state: .closed), .event(.openCurrentApp))
    }

    func testClosedPassesThroughOtherKeys() {
        XCTAssertEqual(decode(key: kVK_ANSI_A, cmd: true, state: .closed), .passthrough)
    }

    // MARK: - HoldCycle

    func testHoldCycleConsumesTab() {
        XCTAssertEqual(decode(key: kVK_Tab, cmd: true, state: cycle), .event(.tabForward))
    }

    func testHoldCycleShiftTab() {
        XCTAssertEqual(decode(key: kVK_Tab, cmd: true, shift: true, state: cycle), .event(.tabBackward))
    }

    func testHoldCycleEscape() {
        XCTAssertEqual(decode(key: kVK_Escape, cmd: true, state: cycle), .event(.escape))
    }

    func testHoldCycleActionKeys() {
        let cases: [(Int, WindowAction)] = [
            (kVK_ANSI_W, .closeWindow),
            (kVK_ANSI_Q, .quitApp),
            (kVK_ANSI_H, .hideApp),
            (kVK_ANSI_M, .minimizeWindow),
        ]
        for (key, expected) in cases {
            XCTAssertEqual(decode(key: key, cmd: true, state: cycle), .event(.action(expected)), "keyCode \(key)")
        }
    }

    func testHoldCycleSEntersFilterMode() {
        XCTAssertEqual(decode(key: kVK_ANSI_S, cmd: true, state: cycle), .event(.enterFilterMode))
    }

    func testHoldCycleArrowKeys() {
        XCTAssertEqual(decode(key: kVK_DownArrow, cmd: true, state: cycle), .event(.arrowDown))
        XCTAssertEqual(decode(key: kVK_UpArrow,   cmd: true, state: cycle), .event(.arrowUp))
    }

    func testHoldCycleVimNavigation() {
        XCTAssertEqual(decode(key: kVK_ANSI_J, cmd: true, state: cycle), .event(.arrowDown))
        XCTAssertEqual(decode(key: kVK_ANSI_K, cmd: true, state: cycle), .event(.arrowUp))
    }

    func testHoldCyclePageAndHomeEndKeys() {
        XCTAssertEqual(decode(key: kVK_PageDown, cmd: true, state: cycle), .event(.arrowDown))
        XCTAssertEqual(decode(key: kVK_PageUp,   cmd: true, state: cycle), .event(.arrowUp))
        XCTAssertEqual(decode(key: kVK_Home,     cmd: true, state: cycle), .event(.moveToTop))
        XCTAssertEqual(decode(key: kVK_End,      cmd: true, state: cycle), .event(.moveToBottom))
    }

    func testHoldCyclePlacementKeys() {
        let cases: [(Int, Bool, Bool, PlacementAction)] = [
            // (keyCode, ctrl, shift, expected)
            (kVK_LeftArrow,  false, false, .leftHalf),
            (kVK_RightArrow, false, false, .rightHalf),
            (kVK_LeftArrow,  true,  false, .topLeft),
            (kVK_RightArrow, true,  false, .topRight),
            (kVK_LeftArrow,  true,  true,  .bottomLeft),
            (kVK_RightArrow, true,  true,  .bottomRight),
            (kVK_ANSI_C,     true,  false, .center),
            (kVK_ANSI_N,     true,  false, .nextDisplay),
        ]
        for (key, ctrl, shift, expected) in cases {
            XCTAssertEqual(
                decode(key: key, cmd: true, shift: shift, ctrl: ctrl, state: cycle),
                .event(.action(.place(expected))),
                "keyCode \(key) ctrl=\(ctrl) shift=\(shift)"
            )
        }
    }

    func testHoldCycleCAndNWithoutCtrlAreSwallowed() {
        XCTAssertEqual(decode(key: kVK_ANSI_C, cmd: true, state: cycle), .consume)
        XCTAssertEqual(decode(key: kVK_ANSI_N, cmd: true, state: cycle), .consume)
    }

    func testFlagsChangedCmdReleaseConfirms() {
        // Cmd up in HoldCycle(cmd) decodes as modifierUp(.cmd).
        XCTAssertEqual(
            decode(key: kVK_Command, type: .flagsChanged, state: cycle),
            .event(.modifierUp(.cmd))
        )
    }

    // MARK: - Filter

    func testFilterModeCharacterTyping() {
        XCTAssertEqual(decode(key: kVK_ANSI_A, state: filtering, char: "a"), .event(.character("a")))
    }

    func testFilterModeEnter() {
        XCTAssertEqual(decode(key: kVK_Return, state: filtering), .event(.enter))
    }

    func testFilterModePageAndHomeEndKeys() {
        XCTAssertEqual(decode(key: kVK_PageDown, state: filtering), .event(.arrowDown))
        XCTAssertEqual(decode(key: kVK_PageUp,   state: filtering), .event(.arrowUp))
        XCTAssertEqual(decode(key: kVK_Home,     state: filtering), .event(.moveToTop))
        XCTAssertEqual(decode(key: kVK_End,      state: filtering), .event(.moveToBottom))
    }

    func testFilterModeBackspace() {
        XCTAssertEqual(decode(key: kVK_Delete, state: filtering), .event(.backspace))
    }

    func testFilterModeCtrlHIsBackspace() {
        // Ctrl+H produces 0x08 (ASCII BS) via keyboardGetUnicodeString.
        let bs = Character(UnicodeScalar(0x08)!)
        XCTAssertEqual(decode(key: kVK_ANSI_H, state: filtering, char: bs), .event(.backspace))
    }

    func testFilterModeCtrlWIsDeleteWord() {
        // Ctrl+W produces 0x17 (ASCII ETB) via keyboardGetUnicodeString.
        let etb = Character(UnicodeScalar(0x17)!)
        XCTAssertEqual(decode(key: kVK_ANSI_W, state: filtering, char: etb), .event(.deleteWord))
    }

    func testFilterModeActionLettersTypeAsCharacters() {
        // In filter mode w/q/h/m must type, not trigger actions — otherwise filtering
        // for "WezTerm" or "Notion" is impossible.
        for (key, ch) in [(kVK_ANSI_W, "w"), (kVK_ANSI_Q, "q"), (kVK_ANSI_H, "h"), (kVK_ANSI_M, "m")] {
            let c = Character(ch)
            XCTAssertEqual(decode(key: key, state: filtering, char: c), .event(.character(c)), "key \(ch)")
        }
    }
}

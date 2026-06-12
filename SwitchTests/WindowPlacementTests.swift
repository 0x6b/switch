import XCTest
@testable import Switch

final class WindowPlacementTests: XCTestCase {

    // All rects are in AX coordinates: top-left origin, y grows downward.
    // A 1440x900 display with a 25pt menu bar.
    private let vf = CGRect(x: 0, y: 25, width: 1440, height: 875)
    private let window = CGRect(x: 100, y: 100, width: 600, height: 400)

    private func target(_ action: PlacementAction, next: CGRect? = nil, step: Int = 0) -> CGRect? {
        WindowPlacement.targetFrame(for: action, window: window, visibleFrame: vf, nextVisibleFrame: next, step: step)
    }

    // MARK: - Halves

    func testLeftHalf() {
        XCTAssertEqual(target(.leftHalf), CGRect(x: 0, y: 25, width: 720, height: 875))
    }

    func testRightHalf() {
        XCTAssertEqual(target(.rightHalf), CGRect(x: 720, y: 25, width: 720, height: 875))
    }

    // MARK: - Quarters (heights use floor, so the odd 875 splits as 437)

    func testTopLeft() {
        XCTAssertEqual(target(.topLeft), CGRect(x: 0, y: 25, width: 720, height: 437))
    }

    func testTopRight() {
        XCTAssertEqual(target(.topRight), CGRect(x: 720, y: 25, width: 720, height: 437))
    }

    func testBottomLeft() {
        XCTAssertEqual(target(.bottomLeft), CGRect(x: 0, y: 463, width: 720, height: 437))
    }

    func testBottomRight() {
        XCTAssertEqual(target(.bottomRight), CGRect(x: 720, y: 463, width: 720, height: 437))
    }

    // MARK: - Center

    func testCenterKeepsSize() {
        // x: (1440-600)/2 = 420; y: 25 + round((875-400)/2) = 25 + 238 = 263
        XCTAssertEqual(target(.center), CGRect(x: 420, y: 263, width: 600, height: 400))
    }

    func testCenterClampsOversizedWindowToVisibleFrame() {
        let huge = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        let result = WindowPlacement.targetFrame(for: .center, window: huge, visibleFrame: vf, nextVisibleFrame: nil)
        XCTAssertEqual(result, vf)
    }

    func testCenterClampsOnlyTheOversizedAxis() {
        let wide = CGRect(x: 0, y: 0, width: 2000, height: 300)
        let result = WindowPlacement.targetFrame(for: .center, window: wide, visibleFrame: vf, nextVisibleFrame: nil)
        // width clamped to 1440 at x=0; height 300 centered: 25 + round(575/2) = 313
        XCTAssertEqual(result, CGRect(x: 0, y: 313, width: 1440, height: 300))
    }

    // MARK: - Next display

    func testNextDisplayCentersOnNextScreen() {
        let next = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        // x: 1440 + (1920-600)/2 = 2100; y: 0 + (1080-400)/2 = 340
        XCTAssertEqual(target(.nextDisplay, next: next), CGRect(x: 2100, y: 340, width: 600, height: 400))
    }

    func testNextDisplayWithSingleDisplayIsNoOp() {
        XCTAssertNil(target(.nextDisplay, next: nil))
    }

    // MARK: - Size cycling on repeated commands (1/2 → 2/3 → 1/4 → 1/3)

    func testLeftHalfCyclesWidthOnRepeat() {
        XCTAssertEqual(target(.leftHalf, step: 0)?.width, 720)  // 1/2
        XCTAssertEqual(target(.leftHalf, step: 1)?.width, 960)  // 2/3
        XCTAssertEqual(target(.leftHalf, step: 2)?.width, 360)  // 1/4
        XCTAssertEqual(target(.leftHalf, step: 3)?.width, 480)  // 1/3
        XCTAssertEqual(target(.leftHalf, step: 4), target(.leftHalf, step: 0), "wraps")
    }

    func testRightHalfStaysAnchoredToRightEdgeWhileCycling() {
        XCTAssertEqual(target(.rightHalf, step: 1), CGRect(x: 480, y: 25, width: 960, height: 875))
    }

    func testCornersCycleWidthAndKeepHalfHeight() {
        XCTAssertEqual(target(.topLeft, step: 1), CGRect(x: 0, y: 25, width: 960, height: 437))
        XCTAssertEqual(target(.bottomRight, step: 2), CGRect(x: 1080, y: 463, width: 360, height: 437))
    }

    func testCenterAndNextDisplayIgnoreStep() {
        XCTAssertEqual(target(.center, step: 1), target(.center, step: 0))
        let next = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(target(.nextDisplay, next: next, step: 2), target(.nextDisplay, next: next, step: 0))
    }
}

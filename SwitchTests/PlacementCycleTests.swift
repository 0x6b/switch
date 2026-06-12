import XCTest
@testable import Switch

final class PlacementCycleTests: XCTestCase {
    private let frame = CGRect(x: 0, y: 25, width: 720, height: 875)

    func testFirstInvocationStartsAtStepZero() {
        var cycle = PlacementCycle()
        XCTAssertEqual(cycle.step(windowID: 1, action: .leftHalf, currentFrame: frame), 0)
    }

    func testRepeatOnSameWindowAdvancesAndWraps() {
        var cycle = PlacementCycle()
        var current = frame
        for expected in [0, 1, 2, 3, 0] {
            XCTAssertEqual(cycle.step(windowID: 1, action: .leftHalf, currentFrame: current), expected)
            // Record whatever frame the window actually ended up with (apps
            // may clamp the requested size); a repeat compares against this.
            current = CGRect(x: 0, y: 25, width: CGFloat(700 + expected), height: 875)
            cycle.record(windowID: 1, action: .leftHalf, step: expected, frame: current)
        }
    }

    func testDifferentActionResetsCycle() {
        var cycle = PlacementCycle()
        cycle.record(windowID: 1, action: .leftHalf, step: 2, frame: frame)
        XCTAssertEqual(cycle.step(windowID: 1, action: .rightHalf, currentFrame: frame), 0)
    }

    func testDifferentWindowResetsCycle() {
        var cycle = PlacementCycle()
        cycle.record(windowID: 1, action: .leftHalf, step: 2, frame: frame)
        XCTAssertEqual(cycle.step(windowID: 2, action: .leftHalf, currentFrame: frame), 0)
    }

    func testExternalMoveResetsCycle() {
        var cycle = PlacementCycle()
        cycle.record(windowID: 1, action: .leftHalf, step: 2, frame: frame)
        let moved = frame.offsetBy(dx: 10, dy: 0)
        XCTAssertEqual(cycle.step(windowID: 1, action: .leftHalf, currentFrame: moved), 0)
    }

    func testNilWindowIDNeverCycles() {
        var cycle = PlacementCycle()
        cycle.record(windowID: nil, action: .leftHalf, step: 2, frame: frame)
        XCTAssertEqual(cycle.step(windowID: nil, action: .leftHalf, currentFrame: frame), 0)
    }
}

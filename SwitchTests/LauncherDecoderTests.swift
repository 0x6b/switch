import XCTest
@testable import Switch

final class LauncherDecoderTests: XCTestCase {

    private let leader: UInt16 = 109 // F10
    private let safari = "/Applications/Safari.app"
    private let mail = "cleanshot://capture-window"
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func makeDecoder(leaderKeyCode: UInt16? = 109) -> LauncherDecoder {
        var config = LauncherConfig()
        config.leaderKeyCode = leaderKeyCode
        config.timeoutMs = 600
        config.mappings = [
            LauncherMapping(keyCode: 1, target: safari, isSecondary: false), // S → Safari
            LauncherMapping(keyCode: 46, target: mail, isSecondary: true),   // M → URL scheme
        ]
        return LauncherDecoder(configProvider: { config })
    }

    func testLeaderIsConsumed() {
        let decoder = makeDecoder()
        XCTAssertEqual(decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0), .consume)
    }

    func testLeaderThenMappedKeyLaunches() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.1),
            .launch(safari)
        )
    }

    func testMappedKeyWithoutLeaderPassesThrough() {
        let decoder = makeDecoder()
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0), .passthrough)
    }

    func testDoubleTapTogglesToSecondarySet() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0 + 0.1), .consume)
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 46, hasModifiers: false, now: t0 + 0.2),
            .launch(mail)
        )
    }

    func testTripleTapTogglesBackToPrimarySet() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0 + 0.1)
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0 + 0.2)
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.3),
            .launch(safari)
        )
    }

    func testPrimaryKeyDoesNotLaunchFromSecondarySet() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0 + 0.1)
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.2),
            .passthrough
        )
    }

    func testMappedKeyAfterTimeoutPassesThrough() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.7),
            .passthrough
        )
    }

    func testLeaderAfterTimeoutStartsFreshSequence() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        // After expiry the leader is consumed again (new sequence)…
        XCTAssertEqual(decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0 + 1.0), .consume)
        // …and starts from the primary set, not toggled to secondary.
        XCTAssertEqual(
            decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 1.1),
            .launch(safari)
        )
    }

    func testUnmappedKeyPassesThroughAndResets() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 99, hasModifiers: false, now: t0 + 0.1), .passthrough)
        // Sequence is over; mapped key no longer launches.
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.2), .passthrough)
    }

    func testModifiedKeyPassesThroughAndResets() {
        let decoder = makeDecoder()
        _ = decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 1, hasModifiers: true, now: t0 + 0.1), .passthrough)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.2), .passthrough)
    }

    func testModifiedLeaderPassesThrough() {
        let decoder = makeDecoder()
        XCTAssertEqual(decoder.handleKeyDown(keyCode: leader, hasModifiers: true, now: t0), .passthrough)
    }

    func testNilLeaderDisablesLauncher() {
        let decoder = makeDecoder(leaderKeyCode: nil)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: leader, hasModifiers: false, now: t0), .passthrough)
        XCTAssertEqual(decoder.handleKeyDown(keyCode: 1, hasModifiers: false, now: t0 + 0.1), .passthrough)
    }
}

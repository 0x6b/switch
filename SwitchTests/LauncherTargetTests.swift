import XCTest
@testable import Switch

final class LauncherTargetTests: XCTestCase {

    func testAbsolutePathBecomesFileURL() {
        let url = LauncherTarget.url(from: "/Applications/Visual Studio Code.app")
        XCTAssertEqual(url, URL(fileURLWithPath: "/Applications/Visual Studio Code.app"))
        XCTAssertEqual(url?.isFileURL, true)
    }

    func testTildePathExpandsToHome() {
        let url = LauncherTarget.url(from: "~/bin/jrnl.app")
        XCTAssertEqual(url, URL(fileURLWithPath: NSHomeDirectory() + "/bin/jrnl.app"))
    }

    func testURLSchemeStringBecomesURL() {
        let url = LauncherTarget.url(from: "cleanshot://capture-area?action=annotate")
        XCTAssertEqual(url, URL(string: "cleanshot://capture-area?action=annotate"))
        XCTAssertEqual(url?.isFileURL, false)
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(
            LauncherTarget.url(from: " cleanshot://capture-window "),
            URL(string: "cleanshot://capture-window")
        )
    }

    func testSchemelessStringIsRejected() {
        // A bare word parses as a relative URL; opening it would do nothing useful.
        XCTAssertNil(LauncherTarget.url(from: "cleanshot"))
    }

    func testEmptyStringIsRejected() {
        XCTAssertNil(LauncherTarget.url(from: ""))
        XCTAssertNil(LauncherTarget.url(from: "   "))
    }
}

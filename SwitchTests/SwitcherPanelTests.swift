import SwiftUI
import XCTest
@testable import Switch

final class SwitcherPanelTests: XCTestCase {
    /// The panel's width is a design constant; only the height tracks content.
    /// The hosting controller (sizingOptions=.preferredContentSize) runs layout
    /// passes that resize the window behind our back — a transient wrong width
    /// shifts the row columns sideways. setFrame must pin the width.
    func testSetFramePinsWidth() {
        let panel = SwitcherPanel(rootView: Text("test"))
        XCTAssertEqual(panel.frame.width, 600)

        panel.setFrame(NSRect(x: 0, y: 0, width: 480, height: 300), display: false)

        XCTAssertEqual(panel.frame.width, 600)
        XCTAssertEqual(panel.frame.height, 300)
    }
}

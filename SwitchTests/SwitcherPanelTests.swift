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

    /// We drive the window height from the hosting view's fittingSize. If the
    /// hosting view stops reporting an intrinsic content size (e.g. sizingOptions
    /// = []), fittingSize.height collapses to 0 and the panel is invisible.
    /// show() must size the window to the content's height.
    func testShowSizesWindowToContentHeight() {
        let panel = SwitcherPanel(rootView: Color.clear.frame(width: 600, height: 173))
        panel.show()
        defer { panel.orderOut(nil) }

        XCTAssertEqual(panel.frame.width, 600)
        XCTAssertEqual(panel.frame.height, 173, accuracy: 1)
    }
}

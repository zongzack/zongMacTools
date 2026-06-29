import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class PreviewPanelControllerTests: XCTestCase {
    func testMouseInsidePanelIsFalseBeforePanelIsShown() {
        let controller = PreviewPanelController(logger: ProbeLogger())

        XCTAssertFalse(controller.isMouseInsidePanel(CGPoint(x: 0, y: 0)))
    }
}

import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class GeometryHelpersTests: XCTestCase {
    func testContainsWithToleranceAcceptsSlightlyOutsidePoint() {
        let rect = CGRect(x: 100, y: 200, width: 50, height: 60)
        XCTAssertTrue(GeometryHelpers.contains(CGPoint(x: 99.5, y: 230), in: rect, tolerance: 1))
        XCTAssertFalse(GeometryHelpers.contains(CGPoint(x: 98.5, y: 230), in: rect, tolerance: 1))
    }

    func testDockItemHoverAcceptsBottomAutoHideRevealEdge() {
        let dockItemFrame = CGRect(x: 827.2218, y: 10, width: 74.2148, height: 86.2148)
        let screenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)

        XCTAssertTrue(GeometryHelpers.containsDockItemHover(
            CGPoint(x: 835.98, y: 0.02),
            dockItemFrame: dockItemFrame,
            screenFrame: screenFrame,
            tolerance: 2
        ))
        XCTAssertFalse(GeometryHelpers.containsDockItemHover(
            CGPoint(x: 910, y: 0.02),
            dockItemFrame: dockItemFrame,
            screenFrame: screenFrame,
            tolerance: 2
        ))
    }

    func testConvertTopLeftFrameToBottomLeftFrameMatchesDockMouseCoordinates() {
        let displayFrame = CGRect(x: 0, y: 0, width: 3008, height: 1692)
        let rawAXFrame = CGRect(x: 1055.618408203125, y: 1633.5828857421875, width: 36.4171142578125, height: 48.4171142578125)

        let converted = GeometryHelpers.convertTopLeftFrameToBottomLeftFrame(rawAXFrame, in: displayFrame)

        XCTAssertEqual(converted.origin.x, rawAXFrame.origin.x, accuracy: 0.001)
        XCTAssertEqual(converted.origin.y, 10, accuracy: 0.001)
        XCTAssertTrue(GeometryHelpers.contains(CGPoint(x: 1071.42578125, y: 54.765625), in: converted, tolerance: 2))
    }

    func testFrameMatchScorePrefersCloseFrames() {
        let scFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        let closeAXFrame = CGRect(x: 102, y: 99, width: 798, height: 602)
        let farAXFrame = CGRect(x: 600, y: 500, width: 300, height: 200)
        XCTAssertGreaterThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: closeAXFrame), 0.95)
        XCTAssertLessThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: farAXFrame), 0.40)
    }
}

import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class GeometryHelpersTests: XCTestCase {
    func testContainsWithToleranceAcceptsSlightlyOutsidePoint() {
        let rect = CGRect(x: 100, y: 200, width: 50, height: 60)
        XCTAssertTrue(GeometryHelpers.contains(CGPoint(x: 99.5, y: 230), in: rect, tolerance: 1))
        XCTAssertFalse(GeometryHelpers.contains(CGPoint(x: 98.5, y: 230), in: rect, tolerance: 1))
    }

    func testFrameMatchScorePrefersCloseFrames() {
        let scFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        let closeAXFrame = CGRect(x: 102, y: 99, width: 798, height: 602)
        let farAXFrame = CGRect(x: 600, y: 500, width: 300, height: 200)
        XCTAssertGreaterThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: closeAXFrame), 0.95)
        XCTAssertLessThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: farAXFrame), 0.40)
    }
}

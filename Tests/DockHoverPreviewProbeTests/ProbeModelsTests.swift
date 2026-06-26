import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class ProbeModelsTests: XCTestCase {
    func testPreviewWindowIdentityUsesPidAndWindowID() {
        let lhs = PreviewWindowID(pid: 10, windowID: 20)
        let rhs = PreviewWindowID(pid: 10, windowID: 20)
        let other = PreviewWindowID(pid: 11, windowID: 20)
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, other)
    }

    func testThumbnailCacheKeyIncludesFrameSizeAndTitle() {
        let id = PreviewWindowID(pid: 1, windowID: 2)
        let key = ThumbnailCacheKey(id: id, frame: CGRect(x: 0, y: 0, width: 640, height: 480), title: "One")
        let changedTitle = ThumbnailCacheKey(id: id, frame: CGRect(x: 0, y: 0, width: 640, height: 480), title: "Two")
        XCTAssertNotEqual(key, changedTitle)
    }

    func testActivationProbeResultCapturesActivationEvidence() {
        let result = ActivationProbeResult(
            windowID: 42,
            title: "Editor",
            hadAXElement: true,
            raiseSucceeded: true,
            appActivateRequestSucceeded: false
        )

        XCTAssertEqual(result.windowID, 42)
        XCTAssertEqual(result.title, "Editor")
        XCTAssertTrue(result.hadAXElement)
        XCTAssertTrue(result.raiseSucceeded)
        XCTAssertFalse(result.appActivateRequestSucceeded)
    }
}

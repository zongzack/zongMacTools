import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelLayoutEngineTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let visibleFrame = CGRect(x: 0, y: 50, width: 1512, height: 900)
    private let panelSize = CGSize(width: 720, height: 180)

    func testBottomDockAnchorsPanelAboveIcon() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 730, y: 0, width: 52, height: 48),
            mouseLocation: CGPoint(x: 756, y: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.origin.x, 396, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 58, accuracy: 0.001)
        XCTAssertEqual(frame.size.width, 720, accuracy: 0.001)
        XCTAssertEqual(frame.size.height, 180, accuracy: 0.001)
    }

    func testBottomDockNearRightEdgeClampsInsideVisibleFrame() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 1480, y: 0, width: 40, height: 48),
            mouseLocation: CGPoint(x: 1500, y: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 58, accuracy: 0.001)
    }

    func testLeftDockPlacesPanelBesideIcon() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 0, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 24, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.origin.x, 58, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 456, accuracy: 0.001)
    }

    func testRightDockPlacesPanelBesideIcon() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 1464, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 1488, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, 1454, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 456, accuracy: 0.001)
    }

    func testBottomDockUsesHorizontalPanelLayout() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 730, y: 0, width: 52, height: 48),
            mouseLocation: CGPoint(x: 756, y: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(PreviewPanelLayoutEngine.panelLayout(for: anchor), .horizontal)
    }

    func testSideDockUsesVerticalPanelLayout() {
        let leftAnchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 0, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 24, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
        let rightAnchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 1464, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 1488, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(PreviewPanelLayoutEngine.panelLayout(for: leftAnchor), .vertical)
        XCTAssertEqual(PreviewPanelLayoutEngine.panelLayout(for: rightAnchor), .vertical)
    }

    func testVerticalPanelSizeKeepsFullCardWidthAndCapsAtThreeCards() {
        let size = PreviewPanelMetrics.panelSize(cardCount: 5, layout: .vertical)

        XCTAssertEqual(size.width, 256, accuracy: 0.001)
        XCTAssertEqual(size.height, 556, accuracy: 0.001)
    }

    func testHorizontalPanelSizeCapsVisibleWidthWhenMaxCardsIsTwelve() {
        let eightCardSize = PreviewPanelMetrics.panelSize(cardCount: 8, layout: .horizontal)
        let twelveCardSize = PreviewPanelMetrics.panelSize(cardCount: 12, layout: .horizontal)

        XCTAssertEqual(twelveCardSize.width, eightCardSize.width, accuracy: 0.001)
        XCTAssertEqual(twelveCardSize.height, eightCardSize.height, accuracy: 0.001)
    }

    func testMissingDockFrameFallsBackToMouseLocationAndClamps() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: nil,
            mouseLocation: CGPoint(x: 1400, y: 600),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 610, accuracy: 0.001)
    }

    func testPanelWiderThanVisibleFramePinsToVisibleMinX() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 300, height: 200)
        let panelSize = CGSize(width: 720, height: 100)
        let anchor = PreviewPanelAnchor(
            dockItemFrame: nil,
            mouseLocation: CGPoint(x: 150, y: 100),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(frame.size.width, 720, accuracy: 0.001)
        XCTAssertEqual(frame.size.height, 100, accuracy: 0.001)
    }
}

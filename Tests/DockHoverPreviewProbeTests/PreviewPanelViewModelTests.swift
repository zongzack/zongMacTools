import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelViewModelTests: XCTestCase {
    func testPanelViewModelCapsCardsAtEight() {
        let cards = (1...10).map { makeCard(id: CGWindowID($0), title: "Window \($0)") }

        let model = PreviewPanelViewModel(appName: "Code", cards: cards, maxCardCount: 8)

        XCTAssertEqual(model.cards.count, 8)
        XCTAssertEqual(model.cards.last?.title, "Window 8")
    }

    func testPanelViewModelDoesNotApplyIndependentEightCardLimit() {
        let cards = (1...12).map { makeCard(id: CGWindowID($0), title: "Window \($0)") }

        let model = PreviewPanelViewModel(appName: "Code", cards: cards, maxCardCount: 12)

        XCTAssertEqual(model.cards.count, 12)
        XCTAssertEqual(model.cards.last?.title, "Window 12")
    }

    func testUpdateThumbnailStopsLoadingForMatchingCardOnly() {
        let matchingID = PreviewWindowID(pid: 100, windowID: 1)
        let otherID = PreviewWindowID(pid: 100, windowID: 2)
        let thumbnail = makeImage()
        var model = PreviewPanelViewModel(
            appName: "Code",
            cards: [
                makeCard(id: matchingID.windowID, title: "Project"),
                makeCard(id: otherID.windowID, title: "Terminal")
            ],
            maxCardCount: 8
        )

        model.updateThumbnail(thumbnail, for: matchingID)

        XCTAssertEqual(model.cards[0].thumbnail?.width, thumbnail.width)
        XCTAssertEqual(model.cards[0].thumbnail?.height, thumbnail.height)
        XCTAssertFalse(model.cards[0].isLoadingThumbnail)
        XCTAssertNil(model.cards[1].thumbnail)
        XCTAssertTrue(model.cards[1].isLoadingThumbnail)
    }

    func testCardAccessibilityLabelIncludesAppNameAndTitle() {
        let card = makeCard(id: 1, title: "Project")

        XCTAssertEqual(card.accessibilityLabel, "Code, Project")
    }

    private func makeCard(id: CGWindowID, title: String) -> PreviewCardViewModel {
        PreviewCardViewModel(
            id: PreviewWindowID(pid: 100, windowID: id),
            title: title,
            appName: "Code",
            appIcon: NSImage(size: NSSize(width: 16, height: 16)),
            thumbnail: nil,
            isLoadingThumbnail: true
        )
    }

    private func makeImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}

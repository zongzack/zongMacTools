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

    func testUpdateThumbnailNilMarksMatchingCardUnavailable() {
        let matchingID = PreviewWindowID(pid: 100, windowID: 1)
        var model = PreviewPanelViewModel(
            appName: "Code",
            cards: [makeCard(id: matchingID.windowID, title: "Project")],
            maxCardCount: 8
        )

        model.updateThumbnail(nil, for: matchingID)

        XCTAssertNil(model.cards[0].thumbnail)
        XCTAssertFalse(model.cards[0].isLoadingThumbnail)
    }

    func testCardThumbnailDisplayModeDefaultsToFill() {
        let card = makeCard(id: 1, title: "Project")

        XCTAssertEqual(card.thumbnailDisplayMode, .fill)
        XCTAssertEqual(card.effectiveThumbnailDisplayMode, .fill)
    }

    func testCardThumbnailDisplayModeFitsNearlySquareSourceFrames() {
        let card = PreviewCardViewModel(
            id: PreviewWindowID(pid: 100, windowID: 1),
            title: "Project",
            appName: "Code",
            appIcon: NSImage(size: NSSize(width: 16, height: 16)),
            thumbnail: nil,
            isLoadingThumbnail: true,
            sourceFrame: CGRect(x: 0, y: 0, width: 600, height: 600)
        )

        XCTAssertEqual(card.thumbnailDisplayMode, .fit)
        XCTAssertEqual(card.effectiveThumbnailDisplayMode, .fit)
    }

    func testCardThumbnailDisplayModeFillsWideSourceFrames() {
        let card = PreviewCardViewModel(
            id: PreviewWindowID(pid: 100, windowID: 1),
            title: "Project",
            appName: "Code",
            appIcon: NSImage(size: NSSize(width: 16, height: 16)),
            thumbnail: nil,
            isLoadingThumbnail: true,
            sourceFrame: CGRect(x: 0, y: 0, width: 1600, height: 900)
        )

        XCTAssertEqual(card.thumbnailDisplayMode, .fill)
    }

    func testPanelViewModelCarriesThumbnailUnavailableText() {
        let model = PreviewPanelViewModel(
            appName: "Code",
            cards: [makeCard(id: 1, title: "Project")],
            maxCardCount: 8,
            thumbnailUnavailableText: "No thumbnail"
        )

        XCTAssertEqual(model.thumbnailUnavailableText, "No thumbnail")
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

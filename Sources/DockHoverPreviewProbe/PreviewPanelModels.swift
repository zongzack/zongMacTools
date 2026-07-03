import AppKit
import CoreGraphics

enum DockEdge: Equatable {
    case bottom
    case left
    case right
}

enum PreviewPanelLayout: Equatable {
    case horizontal
    case vertical
}

enum ThumbnailDisplayMode: String, CaseIterable, Sendable {
    case fill
    case fit
}

struct PreviewPanelAnchor: Equatable {
    let dockItemFrame: CGRect?
    let mouseLocation: CGPoint
    let screenFrame: CGRect
    let visibleFrame: CGRect
}

struct PreviewCardViewModel: Identifiable {
    let id: PreviewWindowID
    let title: String
    let appName: String
    let appIcon: NSImage
    var thumbnail: CGImage?
    var isLoadingThumbnail: Bool
    let thumbnailDisplayMode: ThumbnailDisplayMode

    var accessibilityLabel: String { "\(appName), \(title)" }
    var effectiveThumbnailDisplayMode: ThumbnailDisplayMode { thumbnailDisplayMode }

    init(
        id: PreviewWindowID,
        title: String,
        appName: String,
        appIcon: NSImage,
        thumbnail: CGImage?,
        isLoadingThumbnail: Bool,
        sourceFrame: CGRect? = nil
    ) {
        self.id = id
        self.title = title
        self.appName = appName
        self.appIcon = appIcon
        self.thumbnail = thumbnail
        self.isLoadingThumbnail = isLoadingThumbnail
        thumbnailDisplayMode = Self.thumbnailDisplayMode(for: sourceFrame)
    }

    private static func thumbnailDisplayMode(for sourceFrame: CGRect?) -> ThumbnailDisplayMode {
        guard let sourceFrame, sourceFrame.height > 0 else {
            return .fill
        }

        return sourceFrame.width / sourceFrame.height < 1.2 ? .fit : .fill
    }
}

struct PreviewPanelViewModel {
    let appName: String
    let thumbnailUnavailableText: String
    private(set) var cards: [PreviewCardViewModel]

    init(
        appName: String,
        cards: [PreviewCardViewModel],
        maxCardCount: Int,
        thumbnailUnavailableText: String = ""
    ) {
        self.appName = appName
        self.thumbnailUnavailableText = thumbnailUnavailableText
        self.cards = Array(cards.prefix(max(maxCardCount, 0)))
    }

    mutating func updateThumbnail(_ thumbnail: CGImage?, for id: PreviewWindowID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].thumbnail = thumbnail
        cards[index].isLoadingThumbnail = false
    }
}

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

    var accessibilityLabel: String { "\(appName), \(title)" }
}

struct PreviewPanelViewModel {
    let appName: String
    private(set) var cards: [PreviewCardViewModel]

    init(appName: String, cards: [PreviewCardViewModel]) {
        self.appName = appName
        self.cards = Array(cards.prefix(8))
    }

    mutating func updateThumbnail(_ thumbnail: CGImage?, for id: PreviewWindowID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].thumbnail = thumbnail
        cards[index].isLoadingThumbnail = false
    }
}

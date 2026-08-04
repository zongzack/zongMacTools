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

enum PreviewWindowOperation: String, CaseIterable, Sendable {
    case activate
    case hideApplication
    case closeWindow
    case minimizeWindow
}

enum PreviewPanelAction: Equatable, Sendable {
    case primarySelect(PreviewWindowID)
    case closePreviewCard(PreviewWindowID)
    case windowOperation(PreviewWindowID, PreviewWindowOperation)
    case contextMenuWillOpen(PreviewWindowID)
    case contextMenuBegan(PreviewWindowID)
    case contextMenuEnded(PreviewWindowID)
    case hoverEntered(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    case hoverExited(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
}

struct PreviewCardCloseControlPlan: Equatable {
    let isVisible: Bool
    let isEnabled: Bool

    static func plan(for card: PreviewCardViewModel, isHovered: Bool) -> Self {
        Self(
            isVisible: isHovered,
            isEnabled: card.operationMenu.closeWindow.isEnabled
        )
    }
}

enum PreviewCardCloseActionDispatcher {
    static func dispatch(
        for card: PreviewCardViewModel,
        onAction: (PreviewPanelAction) -> Void
    ) {
        guard card.operationMenu.closeWindow.isEnabled else { return }
        onAction(.closePreviewCard(card.id))
    }
}

struct WindowOperationAvailability: Equatable, Sendable {
    let operation: PreviewWindowOperation
    let isEnabled: Bool
    let disabledReason: String?
    let disabledStage: WindowOperationFailureStage?
    let disabledAXErrorCode: Int32?

    init(
        operation: PreviewWindowOperation,
        isEnabled: Bool,
        disabledReason: String?,
        disabledStage: WindowOperationFailureStage? = nil,
        disabledAXErrorCode: Int32? = nil
    ) {
        self.operation = operation
        self.isEnabled = isEnabled
        self.disabledReason = disabledReason
        self.disabledStage = disabledStage
        self.disabledAXErrorCode = disabledAXErrorCode
    }

    static func enabled(_ operation: PreviewWindowOperation) -> WindowOperationAvailability {
        WindowOperationAvailability(operation: operation, isEnabled: true, disabledReason: nil)
    }

    static func disabled(
        _ operation: PreviewWindowOperation,
        reason: String,
        stage: WindowOperationFailureStage? = nil,
        axErrorCode: Int32? = nil
    ) -> WindowOperationAvailability {
        WindowOperationAvailability(
            operation: operation,
            isEnabled: false,
            disabledReason: reason,
            disabledStage: stage,
            disabledAXErrorCode: axErrorCode
        )
    }
}

struct PreviewWindowOperationMenuModel: Equatable, Sendable {
    let activate: WindowOperationAvailability
    let hideApplication: WindowOperationAvailability
    let closeWindow: WindowOperationAvailability
    let minimizeWindow: WindowOperationAvailability
    let environmentDescription: String

    static func allEnabled(environmentDescription: String = "") -> PreviewWindowOperationMenuModel {
        PreviewWindowOperationMenuModel(
            activate: .enabled(.activate),
            hideApplication: .enabled(.hideApplication),
            closeWindow: .enabled(.closeWindow),
            minimizeWindow: .enabled(.minimizeWindow),
            environmentDescription: environmentDescription
        )
    }

    func availability(for operation: PreviewWindowOperation) -> WindowOperationAvailability? {
        switch operation {
        case .activate:
            activate
        case .hideApplication:
            hideApplication
        case .closeWindow:
            closeWindow
        case .minimizeWindow:
            minimizeWindow
        }
    }
}

struct PreviewWindowOperationMenuText: Equatable, Sendable {
    let activateWindow: String
    let hideApplication: String
    let closeWindow: String
    let minimizeWindow: String

    static let english = PreviewWindowOperationMenuText(
        textProvider: AppTextProvider(language: .english)
    )

    init(textProvider: AppTextProvider) {
        activateWindow = textProvider.string(.activateWindow)
        hideApplication = textProvider.string(.hideApplication)
        closeWindow = textProvider.string(.closeWindow)
        minimizeWindow = textProvider.string(.minimizeWindow)
    }

    func title(for operation: PreviewWindowOperation) -> String {
        switch operation {
        case .activate:
            activateWindow
        case .hideApplication:
            hideApplication
        case .closeWindow:
            closeWindow
        case .minimizeWindow:
            minimizeWindow
        }
    }
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
    let operationMenu: PreviewWindowOperationMenuModel

    var accessibilityLabel: String { "\(appName), \(title)" }
    var effectiveThumbnailDisplayMode: ThumbnailDisplayMode { thumbnailDisplayMode }

    init(
        id: PreviewWindowID,
        title: String,
        appName: String,
        appIcon: NSImage,
        thumbnail: CGImage?,
        isLoadingThumbnail: Bool,
        sourceFrame: CGRect? = nil,
        operationMenu: PreviewWindowOperationMenuModel = .allEnabled()
    ) {
        self.id = id
        self.title = title
        self.appName = appName
        self.appIcon = appIcon
        self.thumbnail = thumbnail
        self.isLoadingThumbnail = isLoadingThumbnail
        thumbnailDisplayMode = Self.thumbnailDisplayMode(for: sourceFrame)
        self.operationMenu = operationMenu
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
    let operationMenuText: PreviewWindowOperationMenuText
    private(set) var cards: [PreviewCardViewModel]

    init(
        appName: String,
        cards: [PreviewCardViewModel],
        maxCardCount: Int,
        thumbnailUnavailableText: String = "",
        operationMenuText: PreviewWindowOperationMenuText = .english
    ) {
        self.appName = appName
        self.thumbnailUnavailableText = thumbnailUnavailableText
        self.operationMenuText = operationMenuText
        self.cards = Array(cards.prefix(max(maxCardCount, 0)))
    }

    mutating func updateThumbnail(_ thumbnail: CGImage?, for id: PreviewWindowID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].thumbnail = thumbnail
        cards[index].isLoadingThumbnail = false
    }

    @discardableResult
    mutating func removeCard(for id: PreviewWindowID) -> Bool {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return false }
        cards.remove(at: index)
        return true
    }
}

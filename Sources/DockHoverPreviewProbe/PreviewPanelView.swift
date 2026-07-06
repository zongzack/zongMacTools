import AppKit
import SwiftUI

struct PreviewPanelView: View {
    let model: PreviewPanelViewModel
    let layout: PreviewPanelLayout
    let onAction: (PreviewPanelAction) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        panelContent
            .frame(
                width: PreviewPanelMetrics.panelSize(cardCount: model.cards.count, layout: layout).width,
                height: PreviewPanelMetrics.panelSize(cardCount: model.cards.count, layout: layout).height
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(style.panelBorderOpacity), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(style.panelShadowOpacity), radius: 18, x: 0, y: 10)
            .fixedSize()
    }

    private var style: PreviewPanelVisualStyle.Tokens {
        PreviewPanelVisualStyle.tokens(for: colorScheme)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch layout {
        case .horizontal:
            horizontalContent
        case .vertical:
            verticalContent
        }
    }

    private var horizontalContent: some View {
        ScrollView(.horizontal, showsIndicators: model.cards.count > PreviewPanelMetrics.maxVisibleHorizontalCards) {
            HStack(spacing: PreviewPanelMetrics.cardSpacing) {
                ForEach(model.cards) { card in
                    PreviewCardView(
                        card: card,
                        thumbnailUnavailableText: model.thumbnailUnavailableText,
                        operationMenuText: model.operationMenuText,
                        onAction: onAction
                    )
                }
            }
            .padding(PreviewPanelMetrics.panelPadding)
        }
    }

    private var verticalContent: some View {
        ScrollView(.vertical, showsIndicators: model.cards.count > PreviewPanelMetrics.maxVisibleVerticalCards) {
            VStack(spacing: PreviewPanelMetrics.cardSpacing) {
                ForEach(model.cards) { card in
                    PreviewCardView(
                        card: card,
                        thumbnailUnavailableText: model.thumbnailUnavailableText,
                        operationMenuText: model.operationMenuText,
                        onAction: onAction
                    )
                }
            }
            .padding(PreviewPanelMetrics.panelPadding)
        }
    }
}

struct PreviewCardView: View {
    let card: PreviewCardViewModel
    let thumbnailUnavailableText: String
    let operationMenuText: PreviewWindowOperationMenuText
    let onAction: (PreviewPanelAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button {
            onAction(.primarySelect(card.id))
        } label: {
            VStack(alignment: .leading, spacing: PreviewPanelMetrics.cardContentSpacing) {
                thumbnailView

                HStack(spacing: PreviewPanelMetrics.titleIconSpacing) {
                    Image(nsImage: card.appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: PreviewPanelMetrics.iconSize, height: PreviewPanelMetrics.iconSize)

                    Text(card.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: PreviewPanelMetrics.titleTextWidth, alignment: .leading)
                }
                .frame(width: PreviewPanelMetrics.titleRowWidth, height: 28, alignment: .leading)
            }
            .padding(PreviewPanelMetrics.cardPadding)
            .frame(width: PreviewPanelMetrics.cardWidth, height: PreviewPanelMetrics.cardHeight, alignment: .topLeading)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? style.cardHoverBorderOpacity : style.cardBorderOpacity), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(card.accessibilityLabel)
        .help(card.title)
        .overlay {
            PreviewCardContextMenuBridge(
                card: card,
                menuText: operationMenuText,
                onAction: onAction
            )
        }
    }

    private var style: PreviewPanelVisualStyle.Tokens {
        PreviewPanelVisualStyle.tokens(for: colorScheme)
    }

    private var thumbnailPlan: PreviewThumbnailRenderPlan {
        PreviewThumbnailRenderPlan.plan(for: card, unavailableText: thumbnailUnavailableText)
    }

    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(style.placeholderSurfaceOpacity))

            if let thumbnail = card.thumbnail {
                thumbnailImage(thumbnail, sizing: thumbnailPlan.imageSizing ?? .fill)
            } else {
                VStack(spacing: 8) {
                    Image(nsImage: card.appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .opacity(0.72)

                    if thumbnailPlan.showsSpinner {
                        ProgressView()
                            .controlSize(.small)
                    } else if let unavailableText = thumbnailPlan.unavailableText {
                        Text(unavailableText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: PreviewPanelMetrics.thumbnailWidth - 24)
                    }
                }
            }
        }
        .frame(width: thumbnailPlan.containerSize.width, height: thumbnailPlan.containerSize.height)
        .clipShape(RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(style.thumbnailBorderOpacity), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func thumbnailImage(_ thumbnail: CGImage, sizing: ThumbnailImageSizing) -> some View {
        let image = Image(decorative: thumbnail, scale: 1.0, orientation: .up)
            .resizable()
        switch sizing {
        case .fill:
            image.scaledToFill()
        case .fit:
            image.scaledToFit()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(isHovered ? style.cardHoverBackgroundOpacity : style.cardBackgroundOpacity))
    }
}

enum PreviewWindowOperationMenuItemKind: Equatable {
    case operation(PreviewWindowOperation)
    case separator
    case information
}

struct PreviewWindowOperationMenuItem: Equatable {
    let kind: PreviewWindowOperationMenuItemKind
    let title: String
    let isEnabled: Bool
}

enum PreviewWindowOperationMenuPlan {
    static func items(
        for card: PreviewCardViewModel,
        text: PreviewWindowOperationMenuText
    ) -> [PreviewWindowOperationMenuItem] {
        PreviewWindowOperation.allCases.map { operation in
            let availability = card.operationMenu.availability(for: operation)
            return PreviewWindowOperationMenuItem(
                kind: .operation(operation),
                title: text.title(for: operation),
                isEnabled: availability?.isEnabled == true
            )
        } + [
            PreviewWindowOperationMenuItem(kind: .separator, title: "", isEnabled: false),
            PreviewWindowOperationMenuItem(
                kind: .information,
                title: card.operationMenu.environmentDescription,
                isEnabled: false
            )
        ]
    }
}

enum PreviewWindowOperationMenuActionDispatcher {
    static func dispatch(
        _ operation: PreviewWindowOperation,
        for card: PreviewCardViewModel,
        onAction: (PreviewPanelAction) -> Void
    ) {
        guard card.operationMenu.availability(for: operation)?.isEnabled == true else {
            return
        }
        onAction(.windowOperation(card.id, operation))
    }
}

private struct PreviewCardContextMenuBridge: NSViewRepresentable {
    let card: PreviewCardViewModel
    let menuText: PreviewWindowOperationMenuText
    let onAction: (PreviewPanelAction) -> Void

    func makeNSView(context: Context) -> PreviewCardContextMenuView {
        PreviewCardContextMenuView(card: card, menuText: menuText, onAction: onAction)
    }

    func updateNSView(_ nsView: PreviewCardContextMenuView, context: Context) {
        nsView.card = card
        nsView.menuText = menuText
        nsView.onAction = onAction
    }
}

private final class PreviewCardContextMenuView: NSView {
    var card: PreviewCardViewModel
    var menuText: PreviewWindowOperationMenuText
    var onAction: (PreviewPanelAction) -> Void

    init(
        card: PreviewCardViewModel,
        menuText: PreviewWindowOperationMenuText,
        onAction: @escaping (PreviewPanelAction) -> Void
    ) {
        self.card = card
        self.menuText = menuText
        self.onAction = onAction
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent ?? NSApp.currentEvent,
              event.type == .rightMouseDown else {
            return nil
        }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        onAction(.contextMenuBegan(card.id))
        NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
        onAction(.contextMenuEnded(card.id))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for item in PreviewWindowOperationMenuPlan.items(for: card, text: menuText) {
            switch item.kind {
            case let .operation(operation):
                let menuItem = NSMenuItem(
                    title: item.title,
                    action: #selector(selectOperation(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = operation.rawValue
                menuItem.isEnabled = item.isEnabled
                menu.addItem(menuItem)
            case .separator:
                menu.addItem(.separator())
            case .information:
                let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
                menuItem.isEnabled = false
                menu.addItem(menuItem)
            }
        }

        return menu
    }

    @objc private func selectOperation(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let operation = PreviewWindowOperation(rawValue: rawValue)
        else {
            return
        }
        PreviewWindowOperationMenuActionDispatcher.dispatch(operation, for: card, onAction: onAction)
    }
}

enum ThumbnailImageSizing: Equatable {
    case fill
    case fit
}

struct PreviewThumbnailRenderPlan: Equatable {
    let imageSizing: ThumbnailImageSizing?
    let containerSize: CGSize
    let clipsToContainer: Bool
    let showsSpinner: Bool
    let unavailableText: String?

    static func plan(for card: PreviewCardViewModel, unavailableText: String) -> PreviewThumbnailRenderPlan {
        PreviewThumbnailRenderPlan(
            imageSizing: card.thumbnail == nil ? nil : ThumbnailImageSizing(mode: card.thumbnailDisplayMode),
            containerSize: CGSize(width: PreviewPanelMetrics.thumbnailWidth, height: PreviewPanelMetrics.thumbnailHeight),
            clipsToContainer: true,
            showsSpinner: card.thumbnail == nil && card.isLoadingThumbnail,
            unavailableText: card.thumbnail == nil && !card.isLoadingThumbnail ? unavailableText : nil
        )
    }
}

private extension ThumbnailImageSizing {
    init(mode: ThumbnailDisplayMode) {
        switch mode {
        case .fill:
            self = .fill
        case .fit:
            self = .fit
        }
    }
}

enum PreviewPanelMetrics {
    static let panelPadding: CGFloat = 12
    static let panelCornerRadius: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let maxVisibleHorizontalCards = 8
    static let maxVisibleVerticalCards = 3
    static let cardWidth: CGFloat = 232
    static let cardHeight: CGFloat = 172
    static let cardPadding: CGFloat = 6
    static let cardCornerRadius: CGFloat = 7
    static let cardContentSpacing: CGFloat = 8
    static let thumbnailWidth: CGFloat = 220
    static let thumbnailHeight: CGFloat = 124
    static let thumbnailCornerRadius: CGFloat = 6
    static let iconSize: CGFloat = 18
    static let titleIconSpacing: CGFloat = 6
    static let titleRowWidth: CGFloat = cardWidth - cardPadding * 2
    static let titleTextWidth: CGFloat = titleRowWidth - iconSize - titleIconSpacing

    static func panelSize(cardCount: Int, layout: PreviewPanelLayout) -> CGSize {
        let safeCardCount = max(cardCount, 1)
        switch layout {
        case .horizontal:
            let visibleCardCount = min(safeCardCount, maxVisibleHorizontalCards)
            return CGSize(
                width: CGFloat(visibleCardCount) * cardWidth
                    + CGFloat(max(visibleCardCount - 1, 0)) * cardSpacing
                    + panelPadding * 2,
                height: cardHeight + panelPadding * 2
            )
        case .vertical:
            let visibleCardCount = min(safeCardCount, maxVisibleVerticalCards)
            return CGSize(
                width: cardWidth + panelPadding * 2,
                height: CGFloat(visibleCardCount) * cardHeight
                    + CGFloat(max(visibleCardCount - 1, 0)) * cardSpacing
                    + panelPadding * 2
            )
        }
    }
}

enum PreviewPanelVisualStyle {
    struct Tokens: Equatable {
        let panelBorderOpacity: Double
        let panelShadowOpacity: Double
        let cardBorderOpacity: Double
        let cardHoverBorderOpacity: Double
        let cardBackgroundOpacity: Double
        let cardHoverBackgroundOpacity: Double
        let thumbnailBorderOpacity: Double
        let placeholderSurfaceOpacity: Double
    }

    static func tokens(for colorScheme: ColorScheme) -> Tokens {
        switch colorScheme {
        case .dark:
            Tokens(
                panelBorderOpacity: 0.18,
                panelShadowOpacity: 0.12,
                cardBorderOpacity: 0.10,
                cardHoverBorderOpacity: 0.22,
                cardBackgroundOpacity: 0.055,
                cardHoverBackgroundOpacity: 0.12,
                thumbnailBorderOpacity: 0.10,
                placeholderSurfaceOpacity: 0.08
            )
        default:
            Tokens(
                panelBorderOpacity: 0.12,
                panelShadowOpacity: 0.18,
                cardBorderOpacity: 0.08,
                cardHoverBorderOpacity: 0.18,
                cardBackgroundOpacity: 0.045,
                cardHoverBackgroundOpacity: 0.10,
                thumbnailBorderOpacity: 0.08,
                placeholderSurfaceOpacity: 0.06
            )
        }
    }
}

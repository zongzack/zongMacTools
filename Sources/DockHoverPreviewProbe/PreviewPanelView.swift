import SwiftUI

struct PreviewPanelView: View {
    let model: PreviewPanelViewModel
    let layout: PreviewPanelLayout
    let onSelect: (PreviewWindowID) -> Void

    var body: some View {
        panelContent
            .frame(
                width: PreviewPanelMetrics.panelSize(cardCount: model.cards.count, layout: layout).width,
                height: PreviewPanelMetrics.panelSize(cardCount: model.cards.count, layout: layout).height
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
            .fixedSize()
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
                    PreviewCardView(card: card) {
                        onSelect(card.id)
                    }
                }
            }
            .padding(PreviewPanelMetrics.panelPadding)
        }
    }

    private var verticalContent: some View {
        ScrollView(.vertical, showsIndicators: model.cards.count > PreviewPanelMetrics.maxVisibleVerticalCards) {
            VStack(spacing: PreviewPanelMetrics.cardSpacing) {
                ForEach(model.cards) { card in
                    PreviewCardView(card: card) {
                        onSelect(card.id)
                    }
                }
            }
            .padding(PreviewPanelMetrics.panelPadding)
        }
    }
}

struct PreviewCardView: View {
    let card: PreviewCardViewModel
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: PreviewPanelMetrics.cardContentSpacing) {
                thumbnailView
                    .frame(width: PreviewPanelMetrics.thumbnailWidth, height: PreviewPanelMetrics.thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }

                HStack(spacing: 6) {
                    Image(nsImage: card.appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: PreviewPanelMetrics.iconSize, height: PreviewPanelMetrics.iconSize)

                    Text(card.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 208, height: 28, alignment: .leading)
            }
            .padding(PreviewPanelMetrics.cardPadding)
            .frame(width: PreviewPanelMetrics.cardWidth, height: PreviewPanelMetrics.cardHeight, alignment: .topLeading)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? 0.18 : 0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(card.accessibilityLabel)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = card.thumbnail {
            Image(decorative: thumbnail, scale: 1.0, orientation: .up)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: PreviewPanelMetrics.thumbnailCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))

                VStack(spacing: 8) {
                    Image(nsImage: card.appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .opacity(0.72)

                    if card.isLoadingThumbnail {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(isHovered ? 0.10 : 0.045))
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

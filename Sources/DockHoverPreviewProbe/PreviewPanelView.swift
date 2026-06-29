import SwiftUI

struct PreviewPanelView: View {
    let model: PreviewPanelViewModel
    let onSelect: (PreviewWindowID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: model.cards.count > 3) {
            HStack(spacing: PreviewPanelMetrics.cardSpacing) {
                ForEach(model.cards) { card in
                    PreviewCardView(card: card) {
                        onSelect(card.id)
                    }
                }
            }
            .padding(PreviewPanelMetrics.panelPadding)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PreviewPanelMetrics.panelCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        .fixedSize()
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

private enum PreviewPanelMetrics {
    static let panelPadding: CGFloat = 12
    static let panelCornerRadius: CGFloat = 8
    static let cardSpacing: CGFloat = 8
    static let cardWidth: CGFloat = 232
    static let cardHeight: CGFloat = 172
    static let cardPadding: CGFloat = 6
    static let cardCornerRadius: CGFloat = 7
    static let cardContentSpacing: CGFloat = 8
    static let thumbnailWidth: CGFloat = 220
    static let thumbnailHeight: CGFloat = 124
    static let thumbnailCornerRadius: CGFloat = 6
    static let iconSize: CGFloat = 18
}

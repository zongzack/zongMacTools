import SwiftUI

struct SettingsGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content
    @State private var isHovering = false

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    private var backgroundColor: Color {
        isHovering ? hoverBackgroundColor : baseBackgroundColor
    }

    private var baseBackgroundColor: Color {
        Color(nsColor: .systemGray).opacity(SettingsGroupVisualStyle.baseBackgroundOpacity)
    }

    private var hoverBackgroundColor: Color {
        Color(nsColor: .systemGray).opacity(SettingsGroupVisualStyle.hoverBackgroundOpacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous)
                    .stroke(
                        Color.primary.opacity(
                            isHovering
                                ? SettingsGroupVisualStyle.hoverBorderOpacity
                                : SettingsGroupVisualStyle.borderOpacity
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous))
            .shadow(
                color: Color.black.opacity(isHovering ? SettingsGroupVisualStyle.hoverShadowOpacity : 0),
                radius: isHovering ? SettingsGroupVisualStyle.hoverShadowRadius : 0,
                x: 0,
                y: isHovering ? SettingsGroupVisualStyle.hoverShadowYOffset : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: SettingsGroupVisualStyle.animationDuration), value: isHovering)
        }
    }
}

private enum SettingsGroupVisualStyle {
    static let cornerRadius: CGFloat = 8
    static let baseBackgroundOpacity = 0.13
    static let hoverBackgroundOpacity = 0.18
    static let borderOpacity = 0.05
    static let hoverBorderOpacity = 0.11
    static let hoverShadowOpacity = 0.06
    static let hoverShadowRadius: CGFloat = 8
    static let hoverShadowYOffset: CGFloat = 3
    static let animationDuration = 0.18
}

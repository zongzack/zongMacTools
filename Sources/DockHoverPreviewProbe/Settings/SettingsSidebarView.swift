import SwiftUI

struct SettingsSidebarView: View {
    @ObservedObject var selection: SettingsWindowSelection
    let text: AppTextProvider
    let tools: [ToolDescriptor]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SidebarSection(title: text.string(.settingsSectionApplications)) {
                    SidebarButton(
                        title: text.string(.general),
                        systemImage: "gearshape",
                        isSelected: selection.selectedPage == .general
                    ) {
                        selection.selectedPage = .general
                    }
                }

                SidebarSection(title: text.string(.settingsSectionTools)) {
                    ForEach(tools) { tool in
                        toolSidebarItem(tool)
                    }
                }

                SidebarSection(title: text.string(.settingsSectionSupport)) {
                    SidebarButton(
                        title: text.string(.permissionsAndStatus),
                        systemImage: "checkmark.shield",
                        isSelected: selection.selectedPage == .support
                    ) {
                        selection.selectedPage = .support
                    }

                    SidebarButton(
                        title: text.string(.aboutStatus),
                        systemImage: "info.circle",
                        isSelected: selection.selectedPage == .aboutStatus
                    ) {
                        selection.selectedPage = .aboutStatus
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func toolSidebarItem(_ tool: ToolDescriptor) -> some View {
        if let settingsPage = tool.settingsPage {
            SidebarButton(
                title: text.string(tool.titleKey),
                systemImage: tool.systemImage,
                isSelected: selection.selectedPage == settingsPage
            ) {
                selection.selectedPage = settingsPage
            }
        } else {
            DisabledSidebarItem(
                title: text.string(tool.titleKey),
                badge: tool.badgeKey.map(text.string) ?? "",
                systemImage: tool.systemImage
            )
        }
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            content
        }
    }
}

private struct SidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(SidebarButtonVisualStyle.selectedBackgroundOpacity)
        }
        if isHovering {
            return Color.primary.opacity(SidebarButtonVisualStyle.hoverBackgroundOpacity)
        }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: SidebarButtonVisualStyle.cornerRadius))
                .scaleEffect(isHovering ? SidebarButtonVisualStyle.hoverScale : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .contentShape(RoundedRectangle(cornerRadius: SidebarButtonVisualStyle.cornerRadius))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: SidebarButtonVisualStyle.animationDuration), value: isHovering)
    }
}

private enum SidebarButtonVisualStyle {
    static let cornerRadius: CGFloat = 6
    static let selectedBackgroundOpacity = 0.16
    static let hoverBackgroundOpacity = 0.05
    static let hoverScale: CGFloat = 1.01
    static let animationDuration = 0.16
}

private struct DisabledSidebarItem: View {
    let title: String
    let badge: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .frame(width: 16)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(badge)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .foregroundStyle(.secondary)
        .opacity(0.72)
    }
}

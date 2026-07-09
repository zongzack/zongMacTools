import Foundation

enum ToolID: Hashable {
    case dockWindowQuickLook
    case contextMenuExtension
}

struct ToolDescriptor: Identifiable, Hashable {
    let id: ToolID
    let titleKey: LocalizedTextKey
    let systemImage: String
    let settingsPage: SettingsPage?
    let badgeKey: LocalizedTextKey?
}

extension ToolDescriptor {
    static let dockWindowQuickLook = ToolDescriptor(
        id: .dockWindowQuickLook,
        titleKey: .dockWindowQuickLook,
        systemImage: "dock.rectangle",
        settingsPage: .dockWindowQuickLook,
        badgeKey: nil
    )

    static let contextMenuExtensionPlaceholder = ToolDescriptor(
        id: .contextMenuExtension,
        titleKey: .contextMenuExtension,
        systemImage: "contextualmenu.and.cursorarrow",
        settingsPage: nil,
        badgeKey: .notDeveloped
    )
}

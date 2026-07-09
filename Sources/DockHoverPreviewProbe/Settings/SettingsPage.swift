import Foundation

enum SettingsPage: Hashable {
    case general
    case dockWindowQuickLook
    case support
    case aboutStatus
}

@MainActor
protocol SettingsWindowPresenting: AnyObject {
    func showSettings(selectedPage: SettingsPage)
}

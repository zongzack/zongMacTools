import CoreGraphics
import Foundation

struct DockHoverPreviewSettings: Equatable, Sendable {
    var isDockHoverPreviewEnabled: Bool
    var hoverDelayMilliseconds: Int
    var panelRetentionMode: PanelRetentionMode
    var maxCardCount: Int
    var excludedAppBundleIdentifiers: Set<String>
    var displayLanguage: DisplayLanguage

    static let defaults = DockHoverPreviewSettings(
        isDockHoverPreviewEnabled: true,
        hoverDelayMilliseconds: 250,
        panelRetentionMode: .standard,
        maxCardCount: 8,
        excludedAppBundleIdentifiers: [],
        displayLanguage: .english
    )

    static let validHoverDelayMilliseconds: Set<Int> = [150, 250, 400]
    static let validMaxCardCounts: Set<Int> = [3, 5, 8, 12]

    var panelRetentionParameters: PanelRetentionParameters {
        panelRetentionMode.parameters
    }
}

enum PanelRetentionMode: String, CaseIterable, Sendable {
    case tight
    case standard
    case forgiving

    var parameters: PanelRetentionParameters {
        switch self {
        case .tight:
            PanelRetentionParameters(dockItemTolerance: 12, panelEdgeTolerance: 4, bridgeInset: 12)
        case .standard:
            PanelRetentionParameters(dockItemTolerance: 24, panelEdgeTolerance: 6, bridgeInset: 24)
        case .forgiving:
            PanelRetentionParameters(dockItemTolerance: 36, panelEdgeTolerance: 8, bridgeInset: 36)
        }
    }
}

struct PanelRetentionParameters: Equatable, Sendable {
    let dockItemTolerance: CGFloat
    let panelEdgeTolerance: CGFloat
    let bridgeInset: CGFloat
}

enum DisplayLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}

enum SettingsKey: String, CaseIterable, Sendable {
    case isEnabled = "DockHoverPreview.isEnabled"
    case hoverDelayMilliseconds = "DockHoverPreview.hoverDelayMilliseconds"
    case panelRetentionMode = "DockHoverPreview.panelRetentionMode"
    case maxCardCount = "DockHoverPreview.maxCardCount"
    case excludedAppBundleIdentifiers = "DockHoverPreview.excludedAppBundleIdentifiers"
    case displayLanguage = "DockHoverPreview.displayLanguage"
}

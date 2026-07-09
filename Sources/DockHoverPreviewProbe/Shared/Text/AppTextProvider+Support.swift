import Foundation

extension AppTextProvider {
    func supportText(for key: LocalizedTextKey) -> String? {
        switch language {
        case .english:
            englishSupportText(for: key)
        case .simplifiedChinese:
            simplifiedChineseSupportText(for: key)
        }
    }

    func accessibilityStatus(granted: Bool) -> String {
        switch language {
        case .english:
            "Accessibility: \(granted ? "granted" : "missing")"
        case .simplifiedChinese:
            "\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{FF1A}\(permissionStatus(granted: granted))"
        }
    }

    func screenRecordingStatus(granted: Bool) -> String {
        switch language {
        case .english:
            "Screen Recording: \(granted ? "granted" : "missing")"
        case .simplifiedChinese:
            "\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{FF1A}\(permissionStatus(granted: granted))"
        }
    }

    private func permissionStatus(granted: Bool) -> String {
        granted
            ? "\u{5DF2}\u{6388}\u{6743}"
            : "\u{7F3A}\u{5931}"
    }

    private func englishSupportText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .permissionsAndStatus:
            "Permissions & Status"
        case .requestAccessibilityPrompt:
            "Request Accessibility Prompt"
        case .openAccessibilitySettings:
            "Open Accessibility Settings"
        case .openScreenRecordingSettings:
            "Open Screen Recording Settings"
        case .refreshPermissions:
            "Refresh Permissions"
        case .currentEnumerableEnvironment:
            "Environment: Current enumerable windows"
        case .aboutStatus:
            "About & Status"
        case .copyStatus:
            "Copy Status"
        case .exportDiagnostics:
            "Export Diagnostics..."
        case .diagnosticExportFailed:
            "Diagnostics could not be saved."
        case .diagnosticSavePanelTitle:
            "Export Diagnostics"
        case .diagnosticSavePanelMessage:
            "Choose where to save the zongMacTools diagnostics file."
        case .diagnosticSavePanelPrompt:
            "Save"
        case .diagnosticSavePanelNameFieldLabel:
            "Save As:"
        default:
            nil
        }
    }

    private func simplifiedChineseSupportText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .permissionsAndStatus:
            "\u{6743}\u{9650}\u{4E0E}\u{72B6}\u{6001}"
        case .requestAccessibilityPrompt:
            "\u{8BF7}\u{6C42}\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{6388}\u{6743}\u{63D0}\u{793A}"
        case .openAccessibilitySettings:
            "\u{6253}\u{5F00}\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{8BBE}\u{7F6E}"
        case .openScreenRecordingSettings:
            "\u{6253}\u{5F00}\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{8BBE}\u{7F6E}"
        case .refreshPermissions:
            "\u{5237}\u{65B0}\u{6743}\u{9650}\u{72B6}\u{6001}"
        case .currentEnumerableEnvironment:
            "\u{73AF}\u{5883}\u{FF1A}\u{5F53}\u{524D}\u{53EF}\u{679A}\u{4E3E}\u{7A97}\u{53E3}"
        case .aboutStatus:
            "\u{5173}\u{4E8E}\u{4E0E}\u{72B6}\u{6001}"
        case .copyStatus:
            "\u{590D}\u{5236}\u{72B6}\u{6001}"
        case .exportDiagnostics:
            "\u{5BFC}\u{51FA}\u{8BCA}\u{65AD}..."
        case .diagnosticExportFailed:
            "\u{8BCA}\u{65AD}\u{6587}\u{4EF6}\u{672A}\u{80FD}\u{4FDD}\u{5B58}\u{3002}"
        case .diagnosticSavePanelTitle:
            "\u{5BFC}\u{51FA}\u{8BCA}\u{65AD}"
        case .diagnosticSavePanelMessage:
            "\u{9009}\u{62E9}\u{4FDD}\u{5B58} zongMacTools \u{8BCA}\u{65AD}\u{6587}\u{4EF6}\u{7684}\u{4F4D}\u{7F6E}\u{3002}"
        case .diagnosticSavePanelPrompt:
            "\u{4FDD}\u{5B58}"
        case .diagnosticSavePanelNameFieldLabel:
            "\u{5B58}\u{50A8}\u{4E3A}\u{FF1A}"
        default:
            nil
        }
    }
}

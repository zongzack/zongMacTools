import Foundation

extension AppTextProvider {
    func appText(for key: LocalizedTextKey) -> String? {
        switch language {
        case .english:
            englishAppText(for: key)
        case .simplifiedChinese:
            simplifiedChineseAppText(for: key)
        }
    }

    func languageDisplayName(_ language: DisplayLanguage) -> String {
        switch language {
        case .english:
            "English"
        case .simplifiedChinese:
            "\u{7B80}\u{4F53}\u{4E2D}\u{6587}"
        }
    }

    private func englishAppText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .openSettings:
            "Open Settings..."
        case .general:
            "General"
        case .settingsSectionApplications:
            "Application"
        case .settingsSectionTools:
            "Tools"
        case .settingsSectionSupport:
            "Support"
        case .contextMenuExtension:
            "Right-click Extension"
        case .finderExtensionSubtitle:
            "Finder background menu"
        case .finderExtensionEnabled:
            "Finder extension: Enabled"
        case .finderExtensionDisabled:
            "Finder extension: Not Enabled"
        case .manageFinderExtension:
            "Manage Finder Extension"
        case .notDeveloped:
            "Not Developed"
        case .language:
            "Language"
        case .launchAtLoginEnabled:
            "Launch at Login: Enabled"
        case .launchAtLoginNotRegistered:
            "Launch at Login: Not Registered"
        case .launchAtLoginRequiresApproval:
            "Launch at Login: Requires Approval"
        case .launchAtLoginNotFound:
            "Launch at Login: Not Found"
        case .enableLaunchAtLogin:
            "Enable Launch at Login"
        case .disableLaunchAtLogin:
            "Disable Launch at Login"
        case .openLoginItemsSettings:
            "Open Login Items Settings"
        case .settingsWindowTitle:
            "zongMacTools Settings"
        case .quit:
            "Quit"
        default:
            nil
        }
    }

    private func simplifiedChineseAppText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .openSettings:
            "\u{6253}\u{5F00}\u{8BBE}\u{7F6E}..."
        case .general:
            "\u{901A}\u{7528}"
        case .settingsSectionApplications:
            "\u{5E94}\u{7528}"
        case .settingsSectionTools:
            "\u{5DE5}\u{5177}"
        case .settingsSectionSupport:
            "\u{652F}\u{6301}"
        case .contextMenuExtension:
            "\u{53F3}\u{952E}\u{6269}\u{5C55}"
        case .finderExtensionSubtitle:
            "Finder \u{80CC}\u{666F}\u{83DC}\u{5355}"
        case .finderExtensionEnabled:
            "Finder \u{6269}\u{5C55}\u{FF1A}\u{5DF2}\u{542F}\u{7528}"
        case .finderExtensionDisabled:
            "Finder \u{6269}\u{5C55}\u{FF1A}\u{672A}\u{542F}\u{7528}"
        case .manageFinderExtension:
            "\u{7BA1}\u{7406} Finder \u{6269}\u{5C55}"
        case .notDeveloped:
            "\u{672A}\u{5F00}\u{53D1}"
        case .language:
            "\u{663E}\u{793A}\u{8BED}\u{8A00}"
        case .launchAtLoginEnabled:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}"
        case .launchAtLoginNotRegistered:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{672A}\u{6CE8}\u{518C}"
        case .launchAtLoginRequiresApproval:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{9700}\u{8981}\u{6279}\u{51C6}"
        case .launchAtLoginNotFound:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{672A}\u{627E}\u{5230}"
        case .enableLaunchAtLogin:
            "\u{542F}\u{7528}\u{5F00}\u{673A}\u{542F}\u{52A8}"
        case .disableLaunchAtLogin:
            "\u{505C}\u{7528}\u{5F00}\u{673A}\u{542F}\u{52A8}"
        case .openLoginItemsSettings:
            "\u{6253}\u{5F00}\u{767B}\u{5F55}\u{9879}\u{8BBE}\u{7F6E}"
        case .settingsWindowTitle:
            "zongMacTools \u{8BBE}\u{7F6E}"
        case .quit:
            "\u{9000}\u{51FA}"
        default:
            nil
        }
    }
}

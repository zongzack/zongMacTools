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
        case .finderNewFileFormats:
            "New File Formats"
        case .finderNewFileFormatName:
            "Name"
        case .finderNewFileFormatExtension:
            "Extension"
        case .finderNewFileFormatEnabled:
            "Enabled"
        case .finderNewFileFormatDisabled:
            "Disabled"
        case .finderNewFileImport:
            "Import Templates"
        case .finderNewFileRestoreDefaults:
            "Restore Defaults"
        case .finderNewFileDeleteTemplate:
            "Delete Template"
        case .finderNewFileDeleteConfirmationTitle:
            "Delete Template?"
        case .finderNewFileDeleteConfirmationMessage:
            "The template and its managed copy will be deleted."
        case .finderNewFileRestoreConfirmationTitle:
            "Restore Defaults?"
        case .finderNewFileRestoreConfirmationMessage:
            "All custom templates will be deleted and built-in formats re-enabled."
        case .finderNewFileConfirm:
            "Restore"
        case .finderNewFileCancel:
            "Cancel"
        case .finderNewFileImportResult:
            "Template Import Result"
        case .finderNewFileDone:
            "Done"
        case .finderNewFileImportRegularOnly:
            "Only regular files are supported."
        case .finderNewFileImportInvalidExtension:
            "The file must have a valid extension."
        case .finderNewFileImportInvalidName:
            "The file name is invalid."
        case .finderNewFileImportSaveFailed:
            "Failed to save configuration."
        case .finderNewFileImportDirectoryFailed:
            "Unable to prepare the template directory."
        case .finderNewFileImportCopyFailed:
            "Unable to copy the template file."
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
        case .finderNewFileFormats:
            "\u{65B0}\u{5EFA}\u{6587}\u{4EF6}\u{683C}\u{5F0F}"
        case .finderNewFileFormatName:
            "\u{540D}\u{79F0}"
        case .finderNewFileFormatExtension:
            "\u{540E}\u{7F00}"
        case .finderNewFileFormatEnabled:
            "\u{5DF2}\u{542F}\u{7528}"
        case .finderNewFileFormatDisabled:
            "\u{5DF2}\u{505C}\u{7528}"
        case .finderNewFileImport:
            "\u{5BFC}\u{5165}\u{6A21}\u{677F}"
        case .finderNewFileRestoreDefaults:
            "\u{6062}\u{590D}\u{9ED8}\u{8BA4}"
        case .finderNewFileDeleteTemplate:
            "\u{5220}\u{9664}\u{6A21}\u{677F}"
        case .finderNewFileDeleteConfirmationTitle:
            "\u{5220}\u{9664}\u{6A21}\u{677F}\u{FF1F}"
        case .finderNewFileDeleteConfirmationMessage:
            "\u{5C06}\u{5220}\u{9664}\u{6A21}\u{677F}\u{53CA}\u{5176}\u{526F}\u{672C}\u{3002}"
        case .finderNewFileRestoreConfirmationTitle:
            "\u{6062}\u{590D}\u{9ED8}\u{8BA4}\u{FF1F}"
        case .finderNewFileRestoreConfirmationMessage:
            "\u{8FD9}\u{4F1A}\u{5220}\u{9664}\u{6240}\u{6709}\u{81EA}\u{5B9A}\u{4E49}\u{6A21}\u{677F}\u{FF0C}\u{5E76}\u{542F}\u{7528}\u{5168}\u{90E8}\u{5185}\u{7F6E}\u{683C}\u{5F0F}\u{3002}"
        case .finderNewFileConfirm:
            "\u{6062}\u{590D}"
        case .finderNewFileCancel:
            "\u{53D6}\u{6D88}"
        case .finderNewFileImportResult:
            "\u{6A21}\u{677F}\u{5BFC}\u{5165}\u{7ED3}\u{679C}"
        case .finderNewFileDone:
            "\u{5B8C}\u{6210}"
        case .finderNewFileImportRegularOnly:
            "\u{4EC5}\u{652F}\u{6301}\u{666E}\u{901A}\u{6587}\u{4EF6}\u{3002}"
        case .finderNewFileImportInvalidExtension:
            "\u{6587}\u{4EF6}\u{5FC5}\u{987B}\u{5177}\u{6709}\u{6709}\u{6548}\u{540E}\u{7F00}\u{3002}"
        case .finderNewFileImportInvalidName:
            "\u{6587}\u{4EF6}\u{540D}\u{65E0}\u{6548}\u{3002}"
        case .finderNewFileImportSaveFailed:
            "\u{914D}\u{7F6E}\u{4FDD}\u{5B58}\u{5931}\u{8D25}\u{3002}"
        case .finderNewFileImportDirectoryFailed:
            "\u{65E0}\u{6CD5}\u{51C6}\u{5907}\u{6A21}\u{677F}\u{76EE}\u{5F55}\u{3002}"
        case .finderNewFileImportCopyFailed:
            "\u{65E0}\u{6CD5}\u{590D}\u{5236}\u{6A21}\u{677F}\u{6587}\u{4EF6}\u{3002}"
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

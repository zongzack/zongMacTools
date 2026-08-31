import Foundation

enum LocalizedTextKey: String, CaseIterable {
    case dockWindowQuickLook
    case dockWindowQuickLookDescription
    case desktopWindowPeek
    case desktopWindowPeekDescription
    case openSettings
    case general
    case settingsSectionApplications
    case settingsSectionTools
    case settingsSectionSupport
    case permissionsAndStatus
    case performanceAndFeel
    case exclusionRules
    case excludeCurrentApp
    case includeCurrentApp
    case addExcludedApp
    case chooseAppToExclude
    case noExcludableApp
    case noExcludedApps
    case clearAll
    case contextMenuExtension
    case finderExtensionSubtitle
    case finderExtensionEnabled
    case finderExtensionDisabled
    case finderContextMenuExtensionEnabled
    case finderContextMenuExtensionDisabled
    case manageFinderExtension
    case finderNewFileFormats
    case finderNewFileInteractionHint
    case finderNewFileFormatName
    case finderNewFileFormatExtension
    case finderNewFileFormatEnabled
    case finderNewFileFormatDisabled
    case finderNewFileImport
    case finderNewFileRestoreDefaults
    case finderNewFileDeleteTemplate
    case finderNewFileDeleteConfirmationTitle
    case finderNewFileDeleteConfirmationMessage
    case finderNewFileRestoreConfirmationTitle
    case finderNewFileRestoreConfirmationMessage
    case finderNewFileConfirm
    case finderNewFileCancel
    case finderNewFileImportResult
    case finderNewFileDone
    case finderNewFileImportRegularOnly
    case finderNewFileImportInvalidExtension
    case finderNewFileImportInvalidName
    case finderNewFileImportSaveFailed
    case finderNewFileImportDirectoryFailed
    case finderNewFileImportCopyFailed
    case notDeveloped
    case dockHoverPreviewStatusEnabled
    case dockHoverPreviewStatusDisabled
    case enableDockHoverPreview
    case disableDockHoverPreview
    case hoverDelay
    case panelRetention
    case maxCards
    case language
    case excludedApps
    case excludeApp
    case excludeNamedApp
    case includeNamedApp
    case clearExcludedApps
    case moreExcludedApps
    case launchAtLoginEnabled
    case launchAtLoginNotRegistered
    case launchAtLoginRequiresApproval
    case launchAtLoginNotFound
    case launchAtLoginNotFoundHelp
    case enableLaunchAtLogin
    case disableLaunchAtLogin
    case openLoginItemsSettings
    case requestAccessibilityPrompt
    case openAccessibilitySettings
    case openScreenRecordingSettings
    case refreshPermissions
    case debugShowPreviewForFrontmostApp
    case noThumbnail
    case activateWindow
    case hideApplication
    case closeWindow
    case minimizeWindow
    case screenUnknown
    case currentEnumerableEnvironment
    case aboutStatus
    case copyStatus
    case settingsWindowTitle
    case removeExcludedAppHelp
    case exportDiagnostics
    case diagnosticExportFailed
    case diagnosticSavePanelTitle
    case diagnosticSavePanelMessage
    case diagnosticSavePanelPrompt
    case diagnosticSavePanelNameFieldLabel
    case quit
}

struct AppTextProvider: Equatable {
    let language: DisplayLanguage

    func string(_ key: LocalizedTextKey) -> String {
        if let text = appText(for: key) {
            return text
        }
        if let text = dockWindowQuickLookText(for: key) {
            return text
        }
        if let text = supportText(for: key) {
            return text
        }
        fatalError("Missing localized text for \(key.rawValue) in \(language)")
    }
}

import Foundation

enum LocalizedTextKey: String, CaseIterable {
    case dockWindowQuickLook
    case dockWindowQuickLookDescription
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
    case noExcludableApp
    case noExcludedApps
    case clearAll
    case contextMenuExtension
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
        switch language {
        case .english:
            englishText(for: key)
        case .simplifiedChinese:
            simplifiedChineseText(for: key)
        }
    }

    func string(_ key: LocalizedTextKey, appName: String) -> String {
        string(key).replacingOccurrences(of: "%@", with: appName)
    }

    func string(_ key: LocalizedTextKey, count: Int) -> String {
        if key == .moreExcludedApps {
            return moreExcludedApps(count: count)
        }
        return string(key).replacingOccurrences(of: "%d", with: "\(count)")
    }

    func excludeNamedApp(_ appName: String) -> String {
        string(.excludeNamedApp, appName: appName)
    }

    func includeNamedApp(_ appName: String) -> String {
        string(.includeNamedApp, appName: appName)
    }

    func moreExcludedApps(count: Int) -> String {
        switch language {
        case .english where count == 1:
            "1 more excluded app"
        default:
            string(.moreExcludedApps).replacingOccurrences(of: "%d", with: "\(count)")
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

    func panelRetentionDisplayName(_ mode: PanelRetentionMode) -> String {
        switch language {
        case .english:
            switch mode {
            case .tight:
                "Tight"
            case .standard:
                "Standard"
            case .forgiving:
                "Forgiving"
            }
        case .simplifiedChinese:
            switch mode {
            case .tight:
                "\u{7D27}\u{51D1}"
            case .standard:
                "\u{6807}\u{51C6}"
            case .forgiving:
                "\u{5BBD}\u{677E}"
            }
        }
    }

    func excludedAppListTitle(appName: String?, bundleIdentifier: String) -> String {
        guard let appName, !appName.isEmpty, appName != bundleIdentifier else {
            return self.bundleIdentifier(bundleIdentifier)
        }
        return "\(externalAppName(appName)) (\(self.bundleIdentifier(bundleIdentifier)))"
    }

    func externalAppName(_ appName: String) -> String {
        appName
    }

    func externalWindowTitle(_ windowTitle: String) -> String {
        windowTitle
    }

    func bundleIdentifier(_ bundleIdentifier: String) -> String {
        bundleIdentifier
    }

    func screenDescription(_ screenName: String) -> String {
        switch language {
        case .english:
            "Screen: \(screenName)"
        case .simplifiedChinese:
            "\u{5C4F}\u{5E55}\u{FF1A}\(screenName)"
        }
    }

    private func permissionStatus(granted: Bool) -> String {
        granted
            ? "\u{5DF2}\u{6388}\u{6743}"
            : "\u{7F3A}\u{5931}"
    }

    private func englishText(for key: LocalizedTextKey) -> String {
        switch key {
        case .dockWindowQuickLook:
            "Dock Window Quick Look"
        case .dockWindowQuickLookDescription:
            "Hover over Dock app icons to quickly view that app's window cards."
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
        case .permissionsAndStatus:
            "Permissions & Status"
        case .performanceAndFeel:
            "Performance & Feel"
        case .exclusionRules:
            "Exclusion Rules"
        case .excludeCurrentApp:
            "Exclude Current App"
        case .includeCurrentApp:
            "Include Current App"
        case .noExcludableApp:
            "No excludable app"
        case .noExcludedApps:
            "No excluded apps"
        case .clearAll:
            "Clear All"
        case .contextMenuExtension:
            "Right-click Extension"
        case .notDeveloped:
            "Not Developed"
        case .dockHoverPreviewStatusEnabled:
            "Dock Window Quick Look: Enabled"
        case .dockHoverPreviewStatusDisabled:
            "Dock Window Quick Look: Disabled"
        case .enableDockHoverPreview:
            "Enable Dock Window Quick Look"
        case .disableDockHoverPreview:
            "Disable Dock Window Quick Look"
        case .hoverDelay:
            "Hover Delay"
        case .panelRetention:
            "Panel Retention"
        case .maxCards:
            "Max Cards"
        case .language:
            "Language"
        case .excludedApps:
            "Excluded Apps"
        case .excludeApp:
            "Exclude App"
        case .excludeNamedApp:
            "Exclude %@"
        case .includeNamedApp:
            "Include %@"
        case .clearExcludedApps:
            "Clear Excluded Apps"
        case .moreExcludedApps:
            "%d more excluded apps"
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
        case .requestAccessibilityPrompt:
            "Request Accessibility Prompt"
        case .openAccessibilitySettings:
            "Open Accessibility Settings"
        case .openScreenRecordingSettings:
            "Open Screen Recording Settings"
        case .refreshPermissions:
            "Refresh Permissions"
        case .debugShowPreviewForFrontmostApp:
            "Debug: Show Preview For Frontmost App"
        case .noThumbnail:
            "No thumbnail"
        case .activateWindow:
            "Activate Window"
        case .hideApplication:
            "Hide App"
        case .closeWindow:
            "Close Window"
        case .minimizeWindow:
            "Minimize Window"
        case .screenUnknown:
            "Screen: Unknown"
        case .currentEnumerableEnvironment:
            "Environment: Current enumerable windows"
        case .aboutStatus:
            "About & Status"
        case .copyStatus:
            "Copy Status"
        case .settingsWindowTitle:
            "zongMacTools Settings"
        case .removeExcludedAppHelp:
            "Remove excluded app"
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
        case .quit:
            "Quit"
        }
    }

    private func simplifiedChineseText(for key: LocalizedTextKey) -> String {
        switch key {
        case .dockWindowQuickLook:
            "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}"
        case .dockWindowQuickLookDescription:
            "\u{60AC}\u{505C}\u{5728} Dock \u{5E94}\u{7528}\u{56FE}\u{6807}\u{4E0A}\u{65F6}\u{FF0C}\u{5FEB}\u{901F}\u{67E5}\u{770B}\u{8BE5}\u{5E94}\u{7528}\u{7684}\u{7A97}\u{53E3}\u{5361}\u{7247}\u{3002}"
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
        case .permissionsAndStatus:
            "\u{6743}\u{9650}\u{4E0E}\u{72B6}\u{6001}"
        case .performanceAndFeel:
            "\u{6027}\u{80FD}\u{4E0E}\u{624B}\u{611F}"
        case .exclusionRules:
            "\u{6392}\u{9664}\u{89C4}\u{5219}"
        case .excludeCurrentApp:
            "\u{6392}\u{9664}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App"
        case .includeCurrentApp:
            "\u{6062}\u{590D}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App"
        case .noExcludableApp:
            "\u{6CA1}\u{6709}\u{53EF}\u{6392}\u{9664}\u{7684} App"
        case .noExcludedApps:
            "\u{5F53}\u{524D}\u{6CA1}\u{6709}\u{6392}\u{9664}\u{9879}"
        case .clearAll:
            "\u{6E05}\u{7A7A}\u{5168}\u{90E8}"
        case .contextMenuExtension:
            "\u{53F3}\u{952E}\u{6269}\u{5C55}"
        case .notDeveloped:
            "\u{672A}\u{5F00}\u{53D1}"
        case .dockHoverPreviewStatusEnabled:
            "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}"
        case .dockHoverPreviewStatusDisabled:
            "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}\u{FF1A}\u{5DF2}\u{505C}\u{7528}"
        case .enableDockHoverPreview:
            "\u{542F}\u{7528} Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}"
        case .disableDockHoverPreview:
            "\u{505C}\u{7528} Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}"
        case .hoverDelay:
            "\u{60AC}\u{505C}\u{5EF6}\u{8FDF}"
        case .panelRetention:
            "\u{9762}\u{677F}\u{4FDD}\u{7559}\u{624B}\u{611F}"
        case .maxCards:
            "\u{6700}\u{5927}\u{5361}\u{7247}\u{6570}"
        case .language:
            "\u{663E}\u{793A}\u{8BED}\u{8A00}"
        case .excludedApps:
            "\u{6392}\u{9664}\u{7684} App"
        case .excludeApp:
            "\u{6392}\u{9664} App"
        case .excludeNamedApp:
            "\u{6392}\u{9664} %@"
        case .includeNamedApp:
            "\u{6062}\u{590D} %@"
        case .clearExcludedApps:
            "\u{6E05}\u{7A7A}\u{6392}\u{9664}\u{5217}\u{8868}"
        case .moreExcludedApps:
            "\u{8FD8}\u{6709} %d \u{4E2A}\u{5DF2}\u{6392}\u{9664} App"
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
        case .requestAccessibilityPrompt:
            "\u{8BF7}\u{6C42}\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{6388}\u{6743}\u{63D0}\u{793A}"
        case .openAccessibilitySettings:
            "\u{6253}\u{5F00}\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{8BBE}\u{7F6E}"
        case .openScreenRecordingSettings:
            "\u{6253}\u{5F00}\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{8BBE}\u{7F6E}"
        case .refreshPermissions:
            "\u{5237}\u{65B0}\u{6743}\u{9650}\u{72B6}\u{6001}"
        case .debugShowPreviewForFrontmostApp:
            "\u{8C03}\u{8BD5}\u{FF1A}\u{9884}\u{89C8}\u{5F53}\u{524D}\u{524D}\u{53F0} App"
        case .noThumbnail:
            "\u{65E0}\u{7F29}\u{7565}\u{56FE}"
        case .activateWindow:
            "\u{6FC0}\u{6D3B}\u{7A97}\u{53E3}"
        case .hideApplication:
            "\u{9690}\u{85CF}\u{5E94}\u{7528}"
        case .closeWindow:
            "\u{5173}\u{95ED}\u{7A97}\u{53E3}"
        case .minimizeWindow:
            "\u{6700}\u{5C0F}\u{5316}\u{7A97}\u{53E3}"
        case .screenUnknown:
            "\u{5C4F}\u{5E55}\u{FF1A}\u{672A}\u{77E5}"
        case .currentEnumerableEnvironment:
            "\u{73AF}\u{5883}\u{FF1A}\u{5F53}\u{524D}\u{53EF}\u{679A}\u{4E3E}\u{7A97}\u{53E3}"
        case .aboutStatus:
            "\u{5173}\u{4E8E}\u{4E0E}\u{72B6}\u{6001}"
        case .copyStatus:
            "\u{590D}\u{5236}\u{72B6}\u{6001}"
        case .settingsWindowTitle:
            "zongMacTools \u{8BBE}\u{7F6E}"
        case .removeExcludedAppHelp:
            "\u{79FB}\u{9664}\u{6392}\u{9664}\u{9879}"
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
        case .quit:
            "\u{9000}\u{51FA}"
        }
    }
}

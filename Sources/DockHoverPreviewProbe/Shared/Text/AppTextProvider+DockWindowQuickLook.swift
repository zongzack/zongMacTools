import Foundation

extension AppTextProvider {
    func dockWindowQuickLookText(for key: LocalizedTextKey) -> String? {
        switch language {
        case .english:
            englishDockWindowQuickLookText(for: key)
        case .simplifiedChinese:
            simplifiedChineseDockWindowQuickLookText(for: key)
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

    private func englishDockWindowQuickLookText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .dockWindowQuickLook:
            "Dock Window Quick Look"
        case .dockWindowQuickLookDescription:
            "Hover over Dock app icons to quickly view that app's window cards."
        case .desktopWindowPeek:
            "Desktop Window Peek"
        case .desktopWindowPeekDescription:
            "Show a high-resolution desktop mirror when hovering a window card"
        case .performanceAndFeel:
            "Performance & Feel"
        case .exclusionRules:
            "Exclusion Rules"
        case .excludeCurrentApp:
            "Exclude Current App"
        case .includeCurrentApp:
            "Include Current App"
        case .addExcludedApp:
            "Add..."
        case .chooseAppToExclude:
            "Choose App to Exclude"
        case .noExcludableApp:
            "No excludable app"
        case .noExcludedApps:
            "No excluded apps"
        case .clearAll:
            "Clear All"
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
        case .removeExcludedAppHelp:
            "Remove excluded app"
        default:
            nil
        }
    }

    private func simplifiedChineseDockWindowQuickLookText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .dockWindowQuickLook:
            "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}"
        case .dockWindowQuickLookDescription:
            "\u{60AC}\u{505C}\u{5728} Dock \u{5E94}\u{7528}\u{56FE}\u{6807}\u{4E0A}\u{65F6}\u{FF0C}\u{5FEB}\u{901F}\u{67E5}\u{770B}\u{8BE5}\u{5E94}\u{7528}\u{7684}\u{7A97}\u{53E3}\u{5361}\u{7247}\u{3002}"
        case .desktopWindowPeek:
            "\u{684C}\u{9762}\u{7A97}\u{53E3}\u{9884}\u{89C8}"
        case .desktopWindowPeekDescription:
            "\u{60AC}\u{505C}\u{7A97}\u{53E3}\u{5361}\u{7247}\u{65F6}\u{5728}\u{684C}\u{9762}\u{663E}\u{793A}\u{9AD8}\u{6E05}\u{955C}\u{50CF}"
        case .performanceAndFeel:
            "\u{6027}\u{80FD}\u{4E0E}\u{624B}\u{611F}"
        case .exclusionRules:
            "\u{6392}\u{9664}\u{89C4}\u{5219}"
        case .excludeCurrentApp:
            "\u{6392}\u{9664}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App"
        case .includeCurrentApp:
            "\u{6062}\u{590D}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App"
        case .addExcludedApp:
            "\u{6DFB}\u{52A0}..."
        case .chooseAppToExclude:
            "\u{9009}\u{62E9}\u{8981}\u{6392}\u{9664}\u{7684} App"
        case .noExcludableApp:
            "\u{6CA1}\u{6709}\u{53EF}\u{6392}\u{9664}\u{7684} App"
        case .noExcludedApps:
            "\u{5F53}\u{524D}\u{6CA1}\u{6709}\u{6392}\u{9664}\u{9879}"
        case .clearAll:
            "\u{6E05}\u{7A7A}\u{5168}\u{90E8}"
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
        case .removeExcludedAppHelp:
            "\u{79FB}\u{9664}\u{6392}\u{9664}\u{9879}"
        default:
            nil
        }
    }
}

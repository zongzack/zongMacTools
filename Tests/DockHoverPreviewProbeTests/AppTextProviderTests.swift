import XCTest
@testable import DockHoverPreviewProbe

final class AppTextProviderTests: XCTestCase {
    func testEnglishMenuStrings() {
        let provider = AppTextProvider(language: .english)

        XCTAssertEqual(provider.string(.dockWindowQuickLook), "Dock Window Quick Look")
        XCTAssertEqual(provider.string(.dockHoverPreviewStatusEnabled), "Dock Window Quick Look: Enabled")
        XCTAssertEqual(provider.string(.enableDockHoverPreview), "Enable Dock Window Quick Look")
        XCTAssertEqual(provider.string(.openSettings), "Open Settings...")
        XCTAssertEqual(provider.string(.general), "General")
        XCTAssertEqual(provider.string(.settingsSectionApplications), "Application")
        XCTAssertEqual(provider.string(.settingsSectionTools), "Tools")
        XCTAssertEqual(provider.string(.settingsSectionSupport), "Support")
        XCTAssertEqual(provider.string(.permissionsAndStatus), "Permissions & Status")
        XCTAssertEqual(provider.string(.performanceAndFeel), "Performance & Feel")
        XCTAssertEqual(provider.string(.exclusionRules), "Exclusion Rules")
        XCTAssertEqual(provider.string(.excludeCurrentApp), "Exclude Current App")
        XCTAssertEqual(provider.string(.includeCurrentApp), "Include Current App")
        XCTAssertEqual(provider.string(.noExcludableApp), "No excludable app")
        XCTAssertEqual(provider.string(.noExcludedApps), "No excluded apps")
        XCTAssertEqual(provider.string(.clearAll), "Clear All")
        XCTAssertEqual(provider.string(.contextMenuExtension), "Right-click Extension")
        XCTAssertEqual(provider.string(.notDeveloped), "Not Developed")
        XCTAssertEqual(provider.string(.debugShowPreviewForFrontmostApp), "Debug: Show Preview For Frontmost App")
        XCTAssertEqual(provider.string(.noThumbnail), "No thumbnail")
        XCTAssertEqual(provider.string(.activateWindow), "Activate Window")
        XCTAssertEqual(provider.string(.hideApplication), "Hide App")
        XCTAssertEqual(provider.string(.closeWindow), "Close Window")
        XCTAssertEqual(provider.string(.minimizeWindow), "Minimize Window")
        XCTAssertEqual(provider.string(.screenUnknown), "Screen: Unknown")
        XCTAssertEqual(provider.string(.currentEnumerableEnvironment), "Environment: Current enumerable windows")
        XCTAssertEqual(provider.string(.aboutStatus), "About & Status")
        XCTAssertEqual(provider.string(.copyStatus), "Copy Status")
        XCTAssertEqual(provider.string(.settingsWindowTitle), "zongMacTools Settings")
        XCTAssertEqual(provider.string(.removeExcludedAppHelp), "Remove excluded app")
        XCTAssertEqual(provider.string(.exportDiagnostics), "Export Diagnostics...")
        XCTAssertEqual(provider.string(.diagnosticExportFailed), "Diagnostics could not be saved.")
        XCTAssertEqual(provider.string(.diagnosticSavePanelTitle), "Export Diagnostics")
        XCTAssertEqual(provider.string(.diagnosticSavePanelMessage), "Choose where to save the zongMacTools diagnostics file.")
        XCTAssertEqual(provider.string(.diagnosticSavePanelPrompt), "Save")
        XCTAssertEqual(provider.string(.diagnosticSavePanelNameFieldLabel), "Save As:")
        XCTAssertEqual(provider.string(.excludeNamedApp, appName: "Google Chrome"), "Exclude Google Chrome")
        XCTAssertEqual(provider.string(.moreExcludedApps, count: 108), "108 more excluded apps")
        XCTAssertEqual(provider.moreExcludedApps(count: 1), "1 more excluded app")
        XCTAssertEqual(provider.languageDisplayName(.english), "English")
        XCTAssertEqual(provider.languageDisplayName(.simplifiedChinese), "\u{7B80}\u{4F53}\u{4E2D}\u{6587}")
    }

    func testSimplifiedChineseMenuStrings() {
        let provider = AppTextProvider(language: .simplifiedChinese)

        XCTAssertEqual(provider.string(.dockWindowQuickLook), "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}")
        XCTAssertEqual(provider.string(.dockHoverPreviewStatusEnabled), "Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}")
        XCTAssertEqual(provider.string(.disableDockHoverPreview), "\u{505C}\u{7528} Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}")
        XCTAssertEqual(provider.string(.openSettings), "\u{6253}\u{5F00}\u{8BBE}\u{7F6E}...")
        XCTAssertEqual(provider.string(.general), "\u{901A}\u{7528}")
        XCTAssertEqual(provider.string(.settingsSectionApplications), "\u{5E94}\u{7528}")
        XCTAssertEqual(provider.string(.settingsSectionTools), "\u{5DE5}\u{5177}")
        XCTAssertEqual(provider.string(.settingsSectionSupport), "\u{652F}\u{6301}")
        XCTAssertEqual(provider.string(.permissionsAndStatus), "\u{6743}\u{9650}\u{4E0E}\u{72B6}\u{6001}")
        XCTAssertEqual(provider.string(.performanceAndFeel), "\u{6027}\u{80FD}\u{4E0E}\u{624B}\u{611F}")
        XCTAssertEqual(provider.string(.exclusionRules), "\u{6392}\u{9664}\u{89C4}\u{5219}")
        XCTAssertEqual(provider.string(.excludeCurrentApp), "\u{6392}\u{9664}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App")
        XCTAssertEqual(provider.string(.includeCurrentApp), "\u{6062}\u{590D}\u{5F53}\u{524D}\u{53EF}\u{6392}\u{9664} App")
        XCTAssertEqual(provider.string(.noExcludableApp), "\u{6CA1}\u{6709}\u{53EF}\u{6392}\u{9664}\u{7684} App")
        XCTAssertEqual(provider.string(.noExcludedApps), "\u{5F53}\u{524D}\u{6CA1}\u{6709}\u{6392}\u{9664}\u{9879}")
        XCTAssertEqual(provider.string(.clearAll), "\u{6E05}\u{7A7A}\u{5168}\u{90E8}")
        XCTAssertEqual(provider.string(.contextMenuExtension), "\u{53F3}\u{952E}\u{6269}\u{5C55}")
        XCTAssertEqual(provider.string(.notDeveloped), "\u{672A}\u{5F00}\u{53D1}")
        XCTAssertEqual(provider.excludeNamedApp("Google Chrome"), "\u{6392}\u{9664} Google Chrome")
        XCTAssertEqual(provider.includeNamedApp("Google Chrome"), "\u{6062}\u{590D} Google Chrome")
        XCTAssertEqual(provider.moreExcludedApps(count: 108), "\u{8FD8}\u{6709} 108 \u{4E2A}\u{5DF2}\u{6392}\u{9664} App")
        XCTAssertEqual(provider.string(.noThumbnail), "\u{65E0}\u{7F29}\u{7565}\u{56FE}")
        XCTAssertEqual(provider.string(.activateWindow), "\u{6FC0}\u{6D3B}\u{7A97}\u{53E3}")
        XCTAssertEqual(provider.string(.hideApplication), "\u{9690}\u{85CF}\u{5E94}\u{7528}")
        XCTAssertEqual(provider.string(.closeWindow), "\u{5173}\u{95ED}\u{7A97}\u{53E3}")
        XCTAssertEqual(provider.string(.minimizeWindow), "\u{6700}\u{5C0F}\u{5316}\u{7A97}\u{53E3}")
        XCTAssertEqual(provider.string(.screenUnknown), "\u{5C4F}\u{5E55}\u{FF1A}\u{672A}\u{77E5}")
        XCTAssertEqual(provider.string(.currentEnumerableEnvironment), "\u{73AF}\u{5883}\u{FF1A}\u{5F53}\u{524D}\u{53EF}\u{679A}\u{4E3E}\u{7A97}\u{53E3}")
        XCTAssertEqual(provider.string(.aboutStatus), "\u{5173}\u{4E8E}\u{4E0E}\u{72B6}\u{6001}")
        XCTAssertEqual(provider.string(.copyStatus), "\u{590D}\u{5236}\u{72B6}\u{6001}")
        XCTAssertEqual(provider.string(.settingsWindowTitle), "zongMacTools \u{8BBE}\u{7F6E}")
        XCTAssertEqual(provider.string(.removeExcludedAppHelp), "\u{79FB}\u{9664}\u{6392}\u{9664}\u{9879}")
        XCTAssertEqual(provider.string(.exportDiagnostics), "\u{5BFC}\u{51FA}\u{8BCA}\u{65AD}...")
        XCTAssertEqual(provider.string(.diagnosticExportFailed), "\u{8BCA}\u{65AD}\u{6587}\u{4EF6}\u{672A}\u{80FD}\u{4FDD}\u{5B58}\u{3002}")
        XCTAssertEqual(provider.string(.diagnosticSavePanelTitle), "\u{5BFC}\u{51FA}\u{8BCA}\u{65AD}")
        XCTAssertEqual(provider.string(.diagnosticSavePanelMessage), "\u{9009}\u{62E9}\u{4FDD}\u{5B58} zongMacTools \u{8BCA}\u{65AD}\u{6587}\u{4EF6}\u{7684}\u{4F4D}\u{7F6E}\u{3002}")
        XCTAssertEqual(provider.string(.diagnosticSavePanelPrompt), "\u{4FDD}\u{5B58}")
        XCTAssertEqual(provider.string(.diagnosticSavePanelNameFieldLabel), "\u{5B58}\u{50A8}\u{4E3A}\u{FF1A}")
        XCTAssertEqual(provider.string(.quit), "\u{9000}\u{51FA}")
    }

    func testProviderDoesNotTranslateExternalValues() {
        let provider = AppTextProvider(language: .simplifiedChinese)

        XCTAssertEqual(provider.externalAppName("Google Chrome"), "Google Chrome")
        XCTAssertEqual(provider.externalWindowTitle("Pull Request #42"), "Pull Request #42")
        XCTAssertEqual(provider.bundleIdentifier("com.google.Chrome"), "com.google.Chrome")
    }

    func testEveryKeyHasNonEmptyEnglishAndSimplifiedChineseString() {
        for key in LocalizedTextKey.allCases {
            XCTAssertFalse(AppTextProvider(language: .english).string(key).isEmpty, "\(key) missing English text")
            XCTAssertFalse(AppTextProvider(language: .simplifiedChinese).string(key).isEmpty, "\(key) missing Simplified Chinese text")
        }
    }
}

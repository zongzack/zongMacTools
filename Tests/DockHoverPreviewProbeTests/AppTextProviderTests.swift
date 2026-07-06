import XCTest
@testable import DockHoverPreviewProbe

final class AppTextProviderTests: XCTestCase {
    func testEnglishMenuStrings() {
        let provider = AppTextProvider(language: .english)

        XCTAssertEqual(provider.string(.dockHoverPreviewStatusEnabled), "Dock Hover Preview: Enabled")
        XCTAssertEqual(provider.string(.enableDockHoverPreview), "Enable Dock Hover Preview")
        XCTAssertEqual(provider.string(.debugShowPreviewForFrontmostApp), "Debug: Show Preview For Frontmost App")
        XCTAssertEqual(provider.string(.noThumbnail), "No thumbnail")
        XCTAssertEqual(provider.string(.activateWindow), "Activate Window")
        XCTAssertEqual(provider.string(.hideApplication), "Hide App")
        XCTAssertEqual(provider.string(.closeWindow), "Close Window")
        XCTAssertEqual(provider.string(.minimizeWindow), "Minimize Window")
        XCTAssertEqual(provider.string(.screenUnknown), "Screen: Unknown")
        XCTAssertEqual(provider.string(.currentEnumerableEnvironment), "Environment: Current enumerable windows")
        XCTAssertEqual(provider.string(.excludeNamedApp, appName: "Google Chrome"), "Exclude Google Chrome")
        XCTAssertEqual(provider.string(.moreExcludedApps, count: 108), "108 more excluded apps")
        XCTAssertEqual(provider.moreExcludedApps(count: 1), "1 more excluded app")
        XCTAssertEqual(provider.languageDisplayName(.english), "English")
        XCTAssertEqual(provider.languageDisplayName(.simplifiedChinese), "\u{7B80}\u{4F53}\u{4E2D}\u{6587}")
    }

    func testSimplifiedChineseMenuStrings() {
        let provider = AppTextProvider(language: .simplifiedChinese)

        XCTAssertEqual(provider.string(.dockHoverPreviewStatusEnabled), "Dock \u{60AC}\u{505C}\u{9884}\u{89C8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}")
        XCTAssertEqual(provider.string(.disableDockHoverPreview), "\u{505C}\u{7528} Dock \u{60AC}\u{505C}\u{9884}\u{89C8}")
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

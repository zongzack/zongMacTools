import Foundation
import XCTest
@testable import DockHoverPreviewProbe

final class AppStatusSnapshotTests: XCTestCase {
    func testSnapshotAggregatesAppPermissionsLoginSettingsAndSigning() {
        let snapshot = AppStatusSnapshot(
            metadata: AppMetadata(
                infoDictionary: [
                    "CFBundleDisplayName": "zongMacTools",
                    "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "2",
                    "CFBundleIdentifier": "com.zong.zongMacTools",
                    "CFBundleExecutable": "DockHoverPreviewProbe"
                ],
                bundleURL: URL(fileURLWithPath: "/Applications/zongMacTools.app"),
                signingStatus: .signed(identity: "Developer ID Application: Example Co")
            ),
            permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: false),
            launchAtLoginStatus: .requiresApproval,
            settings: .defaultsWith(
                enabled: true,
                hoverDelayMilliseconds: 250,
                maxCardCount: 8,
                retention: .standard,
                excludedApps: ["com.example.SecretEditor"],
                language: .english
            ),
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(snapshot.appName, "zongMacTools")
        XCTAssertEqual(snapshot.version, "0.1.0")
        XCTAssertEqual(snapshot.buildNumber, "2")
        XCTAssertEqual(snapshot.bundleIdentifier, "com.zong.zongMacTools")
        XCTAssertEqual(snapshot.signingSummary, "Signed: Developer ID Application: Example Co")
        XCTAssertEqual(snapshot.settingsSummary.excludedAppCount, 1)
        XCTAssertTrue(snapshot.copyStatusText().contains("Version: 0.1.0"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Accessibility: granted"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Screen Recording: missing"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Launch at Login: requires approval"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Signing: Signed: Developer ID Application: Example Co"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Dock Window Quick Look: enabled"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Panel Retention: standard"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Excluded Apps: 1"))
        XCTAssertFalse(snapshot.copyStatusText().contains("SecretEditor"))
        XCTAssertFalse(snapshot.copyStatusText().contains("com.example.SecretEditor"))
    }

    func testSnapshotUsesLocalizedStatusLabelsForChineseCopyText() {
        let snapshot = AppStatusSnapshot(
            metadata: AppMetadata(
                infoDictionary: [
                    "CFBundleDisplayName": "zongMacTools",
                    "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "2",
                    "CFBundleIdentifier": "com.zong.zongMacTools",
                    "CFBundleExecutable": "DockHoverPreviewProbe"
                ],
                bundleURL: URL(fileURLWithPath: "/Applications/zongMacTools.app"),
                signingStatus: .adHoc
            ),
            permissionState: PermissionState(accessibilityGranted: false, screenRecordingGranted: false),
            launchAtLoginStatus: .notRegistered,
            settings: .defaultsWith(language: .simplifiedChinese),
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        let text = snapshot.copyStatusText(language: .simplifiedChinese)

        XCTAssertTrue(text.contains("\u{7248}\u{672C}\u{FF1A}0.1.0"))
        XCTAssertTrue(text.contains("\u{6784}\u{5EFA}\u{FF1A}2"))
        XCTAssertTrue(text.contains("\u{5305}\u{6807}\u{8BC6}\u{7B26}\u{FF1A}com.zong.zongMacTools"))
        XCTAssertTrue(text.contains("\u{53EF}\u{6267}\u{884C}\u{6587}\u{4EF6}\u{FF1A}DockHoverPreviewProbe"))
        XCTAssertTrue(text.contains("\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{FF1A}\u{7F3A}\u{5931}"))
        XCTAssertTrue(text.contains("\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{FF1A}\u{7F3A}\u{5931}"))
        XCTAssertTrue(text.contains("\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{672A}\u{6CE8}\u{518C}"))
        XCTAssertTrue(text.contains("\u{7B7E}\u{540D}\u{FF1A}Ad-hoc \u{7B7E}\u{540D}"))
        XCTAssertTrue(text.contains("Dock \u{7A97}\u{53E3}\u{901F}\u{89C8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}"))
        XCTAssertTrue(text.contains("\u{60AC}\u{505C}\u{5EF6}\u{8FDF}\u{FF1A}250 ms"))
        XCTAssertTrue(text.contains("\u{9762}\u{677F}\u{4FDD}\u{7559}\u{624B}\u{611F}\u{FF1A}\u{6807}\u{51C6}"))
        XCTAssertTrue(text.contains("\u{6700}\u{5927}\u{5361}\u{7247}\u{6570}\u{FF1A}8"))
        XCTAssertTrue(text.contains("\u{6392}\u{9664}\u{7684} App\u{FF1A}0"))
        XCTAssertTrue(text.contains("\u{663E}\u{793A}\u{8BED}\u{8A00}\u{FF1A}\u{7B80}\u{4F53}\u{4E2D}\u{6587}"))
        XCTAssertTrue(text.contains("zongMacTools"))
        XCTAssertFalse(text.contains("Version:"))
        XCTAssertFalse(text.contains("Launch at Login:"))
        XCTAssertFalse(text.contains("Signing:"))
        XCTAssertFalse(text.contains("Dock Hover Preview:"))
        XCTAssertFalse(text.contains("not registered"))
        XCTAssertFalse(text.contains("enabled"))
    }
}

private extension DockHoverPreviewSettings {
    static func defaultsWith(
        enabled: Bool = true,
        hoverDelayMilliseconds: Int = 250,
        maxCardCount: Int = 8,
        retention: PanelRetentionMode = .standard,
        excludedApps: Set<String> = [],
        language: DisplayLanguage = .english
    ) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults
        settings.isDockHoverPreviewEnabled = enabled
        settings.hoverDelayMilliseconds = hoverDelayMilliseconds
        settings.maxCardCount = maxCardCount
        settings.panelRetentionMode = retention
        settings.excludedAppBundleIdentifiers = excludedApps
        settings.displayLanguage = language
        return settings
    }
}

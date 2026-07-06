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
        XCTAssertTrue(snapshot.copyStatusText().contains("Accessibility: granted"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Screen Recording: missing"))
        XCTAssertTrue(snapshot.copyStatusText().contains("Launch at Login: requires approval"))
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

        XCTAssertTrue(text.contains("\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{FF1A}\u{7F3A}\u{5931}"))
        XCTAssertTrue(text.contains("\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{FF1A}\u{7F3A}\u{5931}"))
        XCTAssertTrue(text.contains("zongMacTools"))
        XCTAssertTrue(text.contains("com.zong.zongMacTools"))
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

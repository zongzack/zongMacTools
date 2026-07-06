import AppKit
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class AppTargetTrackerTests: XCTestCase {
    func testPrefersCurrentPreviewAppOverHoveredAndActiveApp() {
        let tracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        tracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit"))
        tracker.updateLatestHoveredDockApp(AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"))
        tracker.updateCurrentPreviewApp(AppTarget(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code"))

        XCTAssertEqual(tracker.exclusionTarget?.bundleIdentifier, "com.microsoft.VSCode")
    }

    func testIgnoresSelfAndMissingBundleIdentifier() {
        let tracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        tracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.zong.zongMacTools", displayName: "zongMacTools"))
        tracker.updateLatestHoveredDockApp(AppTarget(bundleIdentifier: "", displayName: "Unknown"))

        XCTAssertNil(tracker.exclusionTarget)
    }

    func testWorkspaceObservationStartIsIdempotent() async throws {
        let app = try XCTUnwrap(
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier != nil }
        )
        let tracker = AppTargetTracker(selfBundleIdentifier: "com.example.NotSelf")

        tracker.startWorkspaceObservation()
        tracker.startWorkspaceObservation()
        tracker.stopWorkspaceObservation()
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app]
        )
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(tracker.exclusionTarget)
    }
}

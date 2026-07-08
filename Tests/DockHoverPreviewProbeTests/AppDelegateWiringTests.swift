import XCTest
@testable import DockHoverPreviewProbe

final class AppDelegateWiringTests: XCTestCase {
    func testConstructionOrderMatchesSettingsWiringPlan() throws {
        let source = try appDelegateSource()

        XCTAssertSource(source, contains: "logger = ProbeLogger()", before: "permissionService = SystemPermissionService(logger: logger)")
        XCTAssertSource(source, contains: "permissionService = SystemPermissionService(logger: logger)", before: "settingsStore = UserDefaultsSettingsStore(logger: logger)")
        XCTAssertSource(source, contains: "settingsStore = UserDefaultsSettingsStore(logger: logger)", before: "targetTracker = AppTargetTracker")
        XCTAssertSource(source, contains: "targetTracker.startWorkspaceObservation()", before: "launchAtLoginService = SystemLaunchAtLoginService()")
        XCTAssertSource(source, contains: "launchAtLoginService = SystemLaunchAtLoginService()", before: "previewPanelController = PreviewPanelController(logger: logger)")
        XCTAssertSource(source, contains: "diagnosticExportPresenter = DiagnosticExportPresenter", before: "settingsViewModel = SettingsViewModel")
        XCTAssertSource(source, contains: "excludedAppSelectionPresenter = AppKitExcludedAppSelectionPresenter()", before: "settingsViewModel = SettingsViewModel")
        XCTAssertSource(source, contains: "settingsViewModel = SettingsViewModel", before: "settingsWindowController = SettingsWindowController")
        XCTAssertSource(source, contains: "settingsWindowController = SettingsWindowController", before: "previewPanelController = PreviewPanelController(logger: logger)")

        XCTAssertTrue(source.contains("settingsStore: settingsStore"))
        XCTAssertTrue(source.contains("targetTracker: targetTracker"))
        XCTAssertTrue(source.contains("launchAtLoginService: launchAtLoginService"))
        XCTAssertTrue(source.contains("excludedAppSelectionPresenter: excludedAppSelectionPresenter"))
        XCTAssertTrue(source.contains("permissionService: permissionService"))
        XCTAssertTrue(source.contains("appStatusProvider: appStatusProvider"))
        XCTAssertFalse(source.contains("aboutStatusPresenter: aboutStatusWindowController"))
        XCTAssertTrue(source.contains("diagnosticExportPresenter: diagnosticExportPresenter"))
        XCTAssertTrue(source.contains("settingsWindowPresenter: settingsWindowController"))
    }

    func testTerminationStopsOrchestratorBeforeWorkspaceObservation() throws {
        let source = try appDelegateSource()

        XCTAssertSource(source, contains: "orchestrator.stop()", before: "targetTracker.stopWorkspaceObservation()")
        XCTAssertSource(source, contains: "targetTracker.stopWorkspaceObservation()", before: "logger.info(\"app.terminated\")")
    }

    private func appDelegateSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("DockHoverPreviewProbe")
            .appendingPathComponent("AppDelegate.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func XCTAssertSource(
        _ source: String,
        contains first: String,
        before second: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let firstRange = source.range(of: first) else {
            XCTFail("Missing source fragment: \(first)", file: file, line: line)
            return
        }
        guard let secondRange = source.range(of: second) else {
            XCTFail("Missing source fragment: \(second)", file: file, line: line)
            return
        }
        XCTAssertLessThan(firstRange.lowerBound, secondRange.lowerBound, file: file, line: line)
    }
}

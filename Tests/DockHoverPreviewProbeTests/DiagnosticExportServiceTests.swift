import Foundation
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class DiagnosticExportServiceTests: XCTestCase {
    func testExportsUserInitiatedDiagnosticsInsideChosenDirectory() throws {
        let directory = temporaryDirectory()
        let snapshot = makeSnapshot()
        let logger = ProbeLogger()
        let service = DiagnosticExportService(
            snapshotProvider: { snapshot },
            logCollector: FakeDiagnosticLogCollector(
                logs: [
                    "permissions.refresh accessibility=true screenRecording=true",
                    "dock.subscribed pid=42",
                    "windows.query count=2",
                    "thumbnail.success method=sck",
                    "activation.result success=true"
                ].joined(separator: "\n")
            ),
            commandRunner: FakeDiagnosticCommandRunner(outputs: [
                "/usr/bin/codesign": "Authority=Developer ID Application: Example Co",
                "/bin/bash": "bundle.verify ok"
            ]),
            logger: logger
        )

        let exportedURL = try service.export(toDirectory: directory, now: Date(timeIntervalSince1970: 60))

        XCTAssertTrue(exportedURL.path.hasPrefix(directory.path))
        XCTAssertTrue(exportedURL.lastPathComponent.contains("zongMacTools-0.1.0"))
        let content = try String(contentsOf: exportedURL, encoding: .utf8)
        XCTAssertTrue(content.contains("com.zong.zongMacTools"))
        XCTAssertTrue(content.contains("Accessibility: granted"))
        XCTAssertTrue(content.contains("Screen Recording: granted"))
        XCTAssertTrue(content.contains("Signed: Developer ID Application: Example Co"))
        XCTAssertTrue(content.contains("Hover Delay: 250 ms"))
        XCTAssertTrue(content.contains("dock.subscribed"))
        XCTAssertTrue(content.contains("thumbnail.success"))
        XCTAssertTrue(content.contains("bundle.verify ok"))
        XCTAssertFalse(content.localizedCaseInsensitiveContains("screenshot"))
        XCTAssertFalse(content.localizedCaseInsensitiveContains("thumbnail image"))
        XCTAssertFalse(content.localizedCaseInsensitiveContains("user file"))
        XCTAssertFalse(logger.snapshot().joined(separator: "\n").contains(directory.path))
    }

    func testMissingVerifyScriptUsesExplicitFallbackSummary() throws {
        let directory = temporaryDirectory()
        let service = DiagnosticExportService(
            snapshotProvider: { self.makeSnapshot() },
            logCollector: FakeDiagnosticLogCollector(logs: "dock.subscribed pid=42"),
            commandRunner: FakeDiagnosticCommandRunner(outputs: [
                "/usr/bin/codesign": "Signature=adhoc"
            ]),
            logger: ProbeLogger(),
            verifyScriptURL: directory.appendingPathComponent("missing-verify-app-bundle.sh")
        )

        let exportedURL = try service.export(toDirectory: directory, now: Date(timeIntervalSince1970: 60))
        let content = try String(contentsOf: exportedURL, encoding: .utf8)

        XCTAssertTrue(content.contains("verify_app_bundle.sh unavailable"))
        XCTAssertTrue(content.contains("Bundle ID: com.zong.zongMacTools"))
        XCTAssertFalse(content.contains("No such file"))
    }

    func testExportRedactsWindowTitlesFromRecentLogs() throws {
        let directory = temporaryDirectory()
        let service = DiagnosticExportService(
            snapshotProvider: { self.makeSnapshot() },
            logCollector: FakeDiagnosticLogCollector(
                logs: [
                    "windows.item id=12 pid=34 title=Quarterly Plan frame=(0, 0, 10, 10) axMatched=true",
                    "windowOperation.request operation=close id=12 title=/Users/zong/Documents/SecretDraft.md",
                    "activation.result id=12 title=Private Browser Tab hadAX=true raise=true appActivate=true"
                ].joined(separator: "\n")
            ),
            commandRunner: FakeDiagnosticCommandRunner(outputs: [
                "/usr/bin/codesign": "Signature=adhoc"
            ]),
            logger: ProbeLogger()
        )

        let exportedURL = try service.export(toDirectory: directory, now: Date(timeIntervalSince1970: 60))
        let content = try String(contentsOf: exportedURL, encoding: .utf8)

        XCTAssertTrue(content.contains("title=<redacted>"))
        XCTAssertFalse(content.contains("Quarterly Plan"))
        XCTAssertFalse(content.contains("SecretDraft.md"))
        XCTAssertFalse(content.contains("Private Browser Tab"))
    }

    func testExportFailureIsLoggedAndDoesNotThrowFromMenuAction() {
        let logger = ProbeLogger()
        let service = DiagnosticExportService(
            snapshotProvider: { self.makeSnapshot() },
            logCollector: FakeDiagnosticLogCollector(logs: "log"),
            commandRunner: FakeDiagnosticCommandRunner(outputs: [:]),
            logger: logger
        )

        service.exportForMenu(toDirectory: URL(fileURLWithPath: "/not-a-real-parent/zongMacTools"))

        XCTAssertTrue(logger.snapshot().contains { $0.contains("diagnostics.exportFailed") })
    }

    func testMenuExportUsesChosenFileURLAndFailurePathStaysQuiet() throws {
        let source = try sourceFile("DiagnosticExportService.swift")

        XCTAssertTrue(source.contains("exportForMenu(snapshot: snapshot, toFile: url)"))
        XCTAssertFalse(source.contains("url.deletingLastPathComponent()"))
        XCTAssertFalse(source.contains("NSAlert"))
        XCTAssertFalse(source.contains("showFailureAlert"))
    }

    private func makeSnapshot() -> AppStatusSnapshot {
        AppStatusSnapshot(
            metadata: AppMetadata(
                infoDictionary: [
                    "CFBundleDisplayName": "zongMacTools",
                    "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "1",
                    "CFBundleIdentifier": "com.zong.zongMacTools",
                    "CFBundleExecutable": "DockHoverPreviewProbe"
                ],
                bundleURL: URL(fileURLWithPath: "/Applications/zongMacTools.app"),
                signingStatus: .signed(identity: "Developer ID Application: Example Co")
            ),
            permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true),
            launchAtLoginStatus: .enabled,
            settings: .defaults,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticExportServiceTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func sourceFile(_ name: String) throws -> String {
        let url = packageRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("DockHoverPreviewProbe")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct FakeDiagnosticLogCollector: DiagnosticLogCollecting {
    let logs: String

    func collectRecentLogs() -> String {
        logs
    }
}

private struct FakeDiagnosticCommandRunner: DiagnosticCommandRunning {
    let outputs: [String: String]

    func run(_ executableURL: URL, arguments: [String]) -> DiagnosticCommandResult {
        DiagnosticCommandResult(exitCode: 0, output: outputs[executableURL.path] ?? "")
    }
}

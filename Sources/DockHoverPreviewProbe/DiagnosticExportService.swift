import AppKit
import Foundation

struct DiagnosticCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let output: String
}

protocol DiagnosticCommandRunning: Sendable {
    func run(_ executableURL: URL, arguments: [String]) -> DiagnosticCommandResult
}

protocol DiagnosticLogCollecting: Sendable {
    func collectRecentLogs() -> String
}

final class DiagnosticExportService: @unchecked Sendable {
    private let snapshotProvider: (() -> AppStatusSnapshot)?
    private let logCollector: DiagnosticLogCollecting
    private let commandRunner: DiagnosticCommandRunning
    private let logger: ProbeLogger
    private let verifyScriptURL: URL

    init(
        snapshotProvider: (() -> AppStatusSnapshot)? = nil,
        logCollector: DiagnosticLogCollecting = SystemDiagnosticLogCollector(),
        commandRunner: DiagnosticCommandRunning = ProcessDiagnosticCommandRunner(),
        logger: ProbeLogger,
        verifyScriptURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Scripts")
            .appendingPathComponent("verify_app_bundle.sh")
    ) {
        self.snapshotProvider = snapshotProvider
        self.logCollector = logCollector
        self.commandRunner = commandRunner
        self.logger = logger
        self.verifyScriptURL = verifyScriptURL
    }

    func export(toDirectory directory: URL, now: Date = Date()) throws -> URL {
        guard let snapshotProvider else {
            throw DiagnosticExportError.missingSnapshotProvider
        }
        return try export(snapshot: snapshotProvider(), toDirectory: directory, now: now)
    }

    func export(snapshot: AppStatusSnapshot, toDirectory directory: URL, now: Date = Date()) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName(for: snapshot, now: now))
        return try export(snapshot: snapshot, toFile: fileURL, now: now)
    }

    func export(snapshot: AppStatusSnapshot, toFile fileURL: URL, now: Date = Date()) throws -> URL {
        let content = diagnosticContent(snapshot: snapshot, now: now)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        logger.info("diagnostics.exported file=\(fileURL.lastPathComponent)")
        return fileURL
    }

    @discardableResult
    func exportForMenu(toDirectory directory: URL) -> URL? {
        do {
            return try export(toDirectory: directory)
        } catch {
            logger.error("diagnostics.exportFailed error=\(error)")
            return nil
        }
    }

    @discardableResult
    func exportForMenu(snapshot: AppStatusSnapshot, toDirectory directory: URL) -> URL? {
        do {
            return try export(snapshot: snapshot, toDirectory: directory)
        } catch {
            logger.error("diagnostics.exportFailed errorType=\(String(describing: type(of: error)))")
            return nil
        }
    }

    @discardableResult
    func exportForMenu(snapshot: AppStatusSnapshot, toFile fileURL: URL) -> URL? {
        do {
            return try export(snapshot: snapshot, toFile: fileURL)
        } catch {
            logger.error("diagnostics.exportFailed errorType=\(String(describing: type(of: error)))")
            return nil
        }
    }

    private func diagnosticContent(snapshot: AppStatusSnapshot, now: Date) -> String {
        let codesign = commandRunner.run(
            URL(fileURLWithPath: "/usr/bin/codesign"),
            arguments: ["-dv", "--verbose=4", snapshot.bundlePath]
        )
        let verify = bundleVerificationSummary(snapshot: snapshot)
        let recentLogs = Self.redactedLogText(logCollector.collectRecentLogs())

        return """
        # zongMacTools Diagnostics

        Generated At: \(Self.timestamp(now))

        ## Status Snapshot
        \(snapshot.copyStatusText(language: .english))

        ## Recent Unified Logs
        \(recentLogs)

        ## Codesign Summary
        exitCode=\(codesign.exitCode)
        \(codesign.output)

        ## Bundle Verification
        exitCode=\(verify.exitCode)
        \(verify.output)

        ## Privacy Boundary
        This user-initiated local diagnostic text does not include images, screen recordings, or file contents.
        Unified logs may include app names, window titles, bundle identifiers, and local environment details.
        """
    }

    private func bundleVerificationSummary(snapshot: AppStatusSnapshot) -> DiagnosticCommandResult {
        guard FileManager.default.isExecutableFile(atPath: verifyScriptURL.path) else {
            return DiagnosticCommandResult(
                exitCode: 0,
                output: """
                verify_app_bundle.sh unavailable outside the source checkout.
                Built-in bundle summary:
                Bundle Path: \(snapshot.bundlePath)
                Bundle ID: \(snapshot.bundleIdentifier)
                Executable: \(snapshot.metadata.executableName)
                Signing: \(snapshot.signingSummary)
                """
            )
        }
        return commandRunner.run(
            URL(fileURLWithPath: "/bin/bash"),
            arguments: [verifyScriptURL.path, snapshot.bundlePath]
        )
    }

    private func fileName(for snapshot: AppStatusSnapshot, now: Date) -> String {
        let safeName = snapshot.appName.replacingOccurrences(of: "/", with: "-")
        return "\(safeName)-\(snapshot.version)-\(Self.timestamp(now))-diagnostics.txt"
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "")
    }

    private static func redactedLogText(_ logs: String) -> String {
        logs
            .components(separatedBy: .newlines)
            .map(redactedLogLine)
            .joined(separator: "\n")
    }

    private static func redactedLogLine(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"title=.*?(?= (?:frame|hadAX|raise|appActivate|axMatched)=|$)"#,
            with: "title=<redacted>",
            options: .regularExpression
        )
    }
}

struct ProcessDiagnosticCommandRunner: DiagnosticCommandRunning {
    func run(_ executableURL: URL, arguments: [String]) -> DiagnosticCommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return DiagnosticCommandResult(
                exitCode: process.terminationStatus,
                output: String(data: data, encoding: .utf8) ?? ""
            )
        } catch {
            return DiagnosticCommandResult(exitCode: 127, output: "command failed: \(error)")
        }
    }
}

struct SystemDiagnosticLogCollector: DiagnosticLogCollecting {
    private let commandRunner: DiagnosticCommandRunning

    init(commandRunner: DiagnosticCommandRunning = ProcessDiagnosticCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func collectRecentLogs() -> String {
        commandRunner.run(
            URL(fileURLWithPath: "/usr/bin/log"),
            arguments: [
                "show",
                "--last", "15m",
                "--info",
                "--style", "compact",
                "--predicate", "subsystem == \"com.zong.zongMacTools\""
            ]
        ).output
    }
}

@MainActor
protocol DiagnosticExportPresenting: AnyObject {
    func exportDiagnosticsFromMenu()
}

@MainActor
final class DiagnosticExportPresenter: DiagnosticExportPresenting {
    private let exportService: DiagnosticExportService
    private let statusProvider: AppStatusProviding

    init(
        exportService: DiagnosticExportService,
        statusProvider: AppStatusProviding
    ) {
        self.exportService = exportService
        self.statusProvider = statusProvider
    }

    func exportDiagnosticsFromMenu() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "zongMacTools-diagnostics.txt"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            guard let self else {
                return
            }
            let snapshot = self.statusProvider.snapshot()
            let exportService = self.exportService
            Task.detached {
                exportService.exportForMenu(snapshot: snapshot, toFile: url)
            }
        }
    }
}

enum DiagnosticExportError: Error {
    case missingSnapshotProvider
}

@MainActor
final class NoopDiagnosticExportPresenter: DiagnosticExportPresenting {
    func exportDiagnosticsFromMenu() {}
}

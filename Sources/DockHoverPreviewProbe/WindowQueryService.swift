import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

private let axMatchThreshold = 0.72

protocol WindowQueryService: Sendable {
    func windows(for app: NSRunningApplication) async -> [PreviewWindow]
}

struct AXMatchDiagnostics {
    let axWindowCount: Int
    let minimizedCount: Int
    let threshold: Double
    let matched: Bool
    let bestScore: Double?
    let bestFrame: CGRect?

    func logLine(windowID: CGWindowID, scFrame: CGRect) -> String {
        "windows.axMatch id=\(windowID) scFrame=\(scFrame) axCount=\(axWindowCount) matched=\(matched) bestScore=\(formattedBestScore) bestAXFrame=\(formattedBestFrame) threshold=\(threshold) minimizedSkipped=\(minimizedCount)"
    }

    private var formattedBestScore: String {
        guard let bestScore else { return "nil" }
        return String(format: "%.3f", bestScore)
    }

    private var formattedBestFrame: String {
        guard let bestFrame else { return "nil" }
        return "\(bestFrame)"
    }
}

private struct AXMatchResult {
    let snapshot: AXWindowSnapshot?
    let diagnostics: AXMatchDiagnostics
}

struct AXWindowSnapshot {
    let title: String
    let frame: CGRect
    let element: AXUIElement?
}

final class ScreenCaptureWindowQueryService: WindowQueryService, @unchecked Sendable {
    private let logger: ProbeLogger
    private static let fallbackWindowIDBase: UInt32 = 0xFF00_0000

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func windows(for app: NSRunningApplication) async -> [PreviewWindow] {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let candidates = content.windows.filter { window in
                let ownerMatchesPID = window.owningApplication?.processID == app.processIdentifier
                let ownerMatchesBundle = window.owningApplication?.bundleIdentifier == app.bundleIdentifier
                return (ownerMatchesPID || ownerMatchesBundle)
                    && window.isOnScreen
                    && window.frame.width >= 80
                    && window.frame.height >= 60
                    && window.windowLayer == 0
                    && Self.isPreviewableWindow(title: window.title, frame: window.frame)
            }
            let axWindows = readAXWindows(for: app)
            let mappedCandidates = candidates.map { scWindow in
                let window = makePreviewWindow(scWindow: scWindow, app: app, axWindows: axWindows)
                logger.info(window.matchDiagnostics.logLine(windowID: scWindow.windowID, scFrame: scWindow.frame))
                return window
            }
            let matchedCandidateCount = mappedCandidates.filter(\.matchDiagnostics.matched).count
            let mapped: [PreviewWindow]
            if Self.shouldUseAXFallback(
                candidateCount: candidates.count,
                matchedCandidateCount: matchedCandidateCount,
                axWindowCount: axWindows.count
            ) {
                mapped = Self.fallbackPreviewWindows(from: axWindows, app: app)
                logger.info("windows.axFallback app=\(app.localizedName ?? "unknown") count=\(mapped.count)")
            } else {
                mapped = mappedCandidates.map(\.previewWindow)
            }
            let sorted = mapped.sorted { lhs, rhs in
                let lhsArea = lhs.frame.width * lhs.frame.height
                let rhsArea = rhs.frame.width * rhs.frame.height
                if lhsArea != rhsArea { return lhsArea > rhsArea }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.cgWindowID < rhs.cgWindowID
            }
            let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            logger.info("windows.query app=\(app.localizedName ?? "unknown") count=\(sorted.count) elapsedMS=\(elapsedMS)")
            sorted.prefix(8).forEach { window in
                logger.info("windows.item id=\(window.cgWindowID) pid=\(window.id.pid) title=\(window.title) frame=\(window.frame) axMatched=\(window.axElement != nil)")
            }
            return Array(sorted.prefix(8))
        } catch {
            logger.error("windows.queryFailed app=\(app.localizedName ?? "unknown") error=\(error)")
            return []
        }
    }

    private func readAXWindows(for app: NSRunningApplication) -> [AXWindowSnapshot] {
        guard AXIsProcessTrusted() else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let windows = AXHelpers.optionalAttribute(kAXWindowsAttribute as CFString, from: appElement, as: [AXUIElement].self) ?? []
        return windows.compactMap { window in
            guard !isMinimized(window) else { return nil }
            guard let frame = AXHelpers.frame(of: window) else { return nil }
            let title = AXHelpers.stringAttribute(kAXTitleAttribute as CFString, from: window) ?? "(untitled)"
            return AXWindowSnapshot(title: title, frame: frame, element: window)
        }
    }

    private func makePreviewWindow(scWindow: SCWindow, app: NSRunningApplication, axWindows: [AXWindowSnapshot]) -> (previewWindow: PreviewWindow, matchDiagnostics: AXMatchDiagnostics) {
        let match = bestAXMatch(for: scWindow, axWindows: axWindows)
        let title = match.snapshot?.title
            ?? scWindow.title
            ?? "(untitled)"
        let previewWindow = PreviewWindow(
            id: PreviewWindowID(pid: app.processIdentifier, windowID: scWindow.windowID),
            cgWindowID: scWindow.windowID,
            app: app,
            title: title,
            frame: scWindow.frame,
            scWindow: scWindow,
            axElement: match.snapshot?.element,
            appIcon: app.icon ?? NSImage(size: NSSize(width: 32, height: 32)),
            thumbnailSource: .screenCaptureKit(scWindow)
        )
        return (previewWindow, match.diagnostics)
    }

    private func bestAXMatch(for scWindow: SCWindow, axWindows: [AXWindowSnapshot]) -> AXMatchResult {
        let scored = axWindows.map { axWindow -> (AXWindowSnapshot, Double) in
            let score = GeometryHelpers.frameMatchScore(scFrame: scWindow.frame, axFrame: axWindow.frame)
            return (axWindow, score)
        }
        let best = scored.sorted { $0.1 > $1.1 }.first
        let matchedSnapshot = best.flatMap { $0.1 >= axMatchThreshold ? $0.0 : nil }
        return AXMatchResult(
            snapshot: matchedSnapshot,
            diagnostics: AXMatchDiagnostics(
                axWindowCount: axWindows.count,
                minimizedCount: 0,
                threshold: axMatchThreshold,
                matched: matchedSnapshot != nil,
                bestScore: best?.1,
                bestFrame: best?.0.frame
            )
        )
    }

    private func isMinimized(_ axWindow: AXUIElement) -> Bool {
        AXHelpers.optionalAttribute(kAXMinimizedAttribute as CFString, from: axWindow, as: Bool.self) ?? false
    }

    static func fallbackPreviewWindows(from axWindows: [AXWindowSnapshot], app: NSRunningApplication) -> [PreviewWindow] {
        axWindows
            .filter { isPreviewableWindow(title: $0.title, frame: $0.frame) }
            .enumerated()
            .map { index, axWindow in
                let windowID = CGWindowID(fallbackWindowIDBase + UInt32(index))
                return PreviewWindow(
                    id: PreviewWindowID(pid: app.processIdentifier, windowID: windowID),
                    cgWindowID: windowID,
                    app: app,
                    title: axWindow.title,
                    frame: axWindow.frame,
                    scWindow: nil,
                    axElement: axWindow.element,
                    appIcon: app.icon ?? NSImage(size: NSSize(width: 32, height: 32)),
                    thumbnailSource: nil
                )
            }
    }

    static func shouldUseAXFallback(candidateCount: Int, matchedCandidateCount: Int, axWindowCount: Int) -> Bool {
        axWindowCount > 0 && (candidateCount == 0 || matchedCandidateCount == 0)
    }

    static func isPreviewableWindow(title: String?, frame: CGRect) -> Bool {
        let hasTitle = !(title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasTitle { return true }

        let aspectRatio = frame.width / max(frame.height, 1)
        let isWideShallowSurface = frame.width >= 1000 && frame.height <= 180 && aspectRatio >= 6
        return !isWideShallowSurface
    }
}

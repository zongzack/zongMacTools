import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowPeekCoordinatorTests: XCTestCase {
    func testEnterWaitsForHighResolutionCaptureBeforeShowingDesktopOverlay() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)

        harness.coordinator.hoverEntered(
            windowID: window.id,
            window: window,
            coarseImage: image(),
            sessionEpoch: 1,
            sequence: 1
        )

        XCTAssertEqual(harness.overlay.events, [])
        await harness.capture.waitUntilStarted(id: 1)
        XCTAssertEqual(harness.capture.startedIDs, [1])
        XCTAssertEqual(harness.permissionScheduler.startCount, 1)
        harness.capture.finish(id: 1, result: .image(image(width: 800, height: 600)))
        await harness.overlay.waitUntilHighResolution()

        XCTAssertEqual(harness.overlay.events, [.show(.highResolution)])
    }

    func testSwitchDropsStaleResultAndOnlyCapturesLatestPendingTarget() async {
        let harness = WindowPeekCoordinatorHarness()
        let a = harness.window(id: 1)
        let b = harness.window(id: 2)
        let c = harness.window(id: 3)

        harness.coordinator.hoverEntered(windowID: a.id, window: a, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.coordinator.hoverEntered(windowID: b.id, window: b, coarseImage: image(), sessionEpoch: 1, sequence: 2)
        harness.coordinator.hoverEntered(windowID: c.id, window: c, coarseImage: image(), sessionEpoch: 1, sequence: 3)
        harness.capture.finish(id: 1, result: .image(image(width: 10, height: 10)))
        await harness.capture.waitUntilStarted(id: 3)

        XCTAssertEqual(harness.capture.startedIDs, [1, 3])
        XCTAssertEqual(harness.capture.maximumInFlight, 1)
        XCTAssertTrue(harness.capture.invalidatedTokens.contains(
            WindowPeekCaptureRequestToken(sessionEpoch: 1, peekGeneration: 1, windowID: a.id)
        ))
        XCTAssertFalse(harness.overlay.events.contains(.update(.highResolution)))
    }

    func testRepeatedEnterForCurrentTargetDoesNotStaleItsCaptureResult() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)
        harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: image(), sessionEpoch: 1, sequence: 2)
        harness.capture.finish(id: 1, result: .image(image(width: 800, height: 600)))
        await harness.overlay.waitUntilHighResolution()

        XCTAssertEqual(harness.capture.startedIDs, [1])
        XCTAssertEqual(harness.permissionScheduler.startCount, 1)
        XCTAssertTrue(harness.overlay.events.contains(.show(.highResolution)))
    }

    func testMissingInitialScreenRecordingDoesNotShowOrCapture() {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)
        harness.permission.screenRecordingGranted = false

        harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: image(), sessionEpoch: 1, sequence: 1)

        XCTAssertEqual(harness.overlay.events, [.hide])
        XCTAssertEqual(harness.capture.startedIDs, [])
        XCTAssertEqual(harness.permissionScheduler.startCount, 0)
    }

    func testExitThenNewEnterDoesNotHideNewTargetWhenExitFlushes() async {
        let harness = WindowPeekCoordinatorHarness()
        let a = harness.window(id: 1)
        let b = harness.window(id: 2)
        harness.coordinator.hoverEntered(windowID: a.id, window: a, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.coordinator.hoverExited(windowID: a.id, sessionEpoch: 1, sequence: 1)
        harness.coordinator.hoverEntered(windowID: b.id, window: b, coarseImage: image(), sessionEpoch: 1, sequence: 2)
        harness.exitScheduler.flush()

        XCTAssertNotEqual(harness.overlay.events.last, .hide)
    }

    func testIneligibleTargetStopsCurrentTargetAndInvalidatesQueuedCapture() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)
        harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.coordinator.hoverEntered(
            windowID: PreviewWindowID(pid: window.id.pid, windowID: 2),
            window: nil,
            coarseImage: nil,
            sessionEpoch: 1,
            sequence: 2
        )

        XCTAssertEqual(harness.overlay.events.last, .hide)
        XCTAssertTrue(harness.capture.invalidatedTokens.contains(
            WindowPeekCaptureRequestToken(sessionEpoch: 1, peekGeneration: 1, windowID: window.id)
        ))
        XCTAssertNil(harness.currentTarget)
    }

    func testNewSessionRejectsLateOldEpochEventsAndCompletion() async {
        let harness = WindowPeekCoordinatorHarness()
        let oldWindow = harness.window(id: 1)
        harness.coordinator.hoverEntered(windowID: oldWindow.id, window: oldWindow, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.coordinator.beginSession(epoch: 2)
        harness.coordinator.updateScreens([harness.screen], sessionEpoch: 2)
        let newWindow = harness.window(id: 2)
        harness.coordinator.hoverEntered(windowID: newWindow.id, window: newWindow, coarseImage: image(), sessionEpoch: 2, sequence: 1)
        harness.coordinator.hoverExited(windowID: oldWindow.id, sessionEpoch: 1, sequence: 99)
        harness.capture.finish(id: 1, result: .image(image()))
        await harness.capture.waitUntilStarted(id: 2)

        XCTAssertEqual(harness.capture.startedIDs, [1, 2])
        XCTAssertFalse(harness.overlay.events.contains(.update(.highResolution)))
    }

    func testPermissionRefreshRevocationHidesAlreadyDisplayedHighResolutionImage() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)
        harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: image(), sessionEpoch: 1, sequence: 1)
        await harness.capture.waitUntilStarted(id: 1)
        harness.capture.finish(id: 1, result: .image(image(width: 800, height: 600)))
        await harness.overlay.waitUntilHighResolution()

        harness.permission.screenRecordingGranted = false
        harness.permissionScheduler.fire()

        XCTAssertEqual(harness.overlay.events.last, .hide)
        XCTAssertGreaterThanOrEqual(harness.permissionScheduler.stopCount, 1)
    }

    func testStopBeforeCaptureWorkerStartsDoesNotSubmitStaleCapture() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)

        harness.coordinator.hoverEntered(
            windowID: window.id,
            window: window,
            coarseImage: image(),
            sessionEpoch: 1,
            sequence: 1
        )
        harness.coordinator.stop(reason: .sessionHidden)
        await Task.yield()

        let startedIDs = harness.capture.startedIDs
        if startedIDs.contains(1) {
            harness.capture.finish(id: 1, result: .unavailable)
        }
        XCTAssertEqual(startedIDs, [])
    }

    func testScreenParameterStopInvalidatesGeometryBeforeAnotherHover() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)

        harness.coordinator.stop(reason: .screenParametersChanged)
        harness.coordinator.hoverEntered(
            windowID: window.id,
            window: window,
            coarseImage: image(),
            sessionEpoch: 1,
            sequence: 1
        )
        await Task.yield()

        let startedIDs = harness.capture.startedIDs
        if startedIDs.contains(1) {
            harness.capture.finish(id: 1, result: .unavailable)
        }
        XCTAssertEqual(startedIDs, [])
    }

    func testHighResolutionAcceptanceLogsDocumentedShowTransition() async {
        let harness = WindowPeekCoordinatorHarness()
        let window = harness.window(id: 1)
        harness.coordinator.hoverEntered(
            windowID: window.id,
            window: window,
            coarseImage: image(),
            sessionEpoch: 1,
            sequence: 1
        )
        await harness.capture.waitUntilStarted(id: 1)
        harness.capture.finish(id: 1, result: .image(image(width: 800, height: 600)))
        await harness.overlay.waitUntilHighResolution()

        XCTAssertTrue(harness.logger.snapshot().contains {
            $0.contains("peek.show source=highResolution")
        })
    }
}

@MainActor
private final class CoordinatorTestCaptureSource: WindowPeekCaptureSource {
    let windowID: PreviewWindowID
    init(windowID: PreviewWindowID) { self.windowID = windowID }
}

@MainActor
private final class ManualWindowPeekExitScheduler: WindowPeekExitScheduling {
    private var operations: [@MainActor @Sendable () -> Void] = []
    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void) { operations.append(operation) }
    func flush() {
        let scheduled = operations
        operations.removeAll()
        scheduled.forEach { $0() }
    }
}

@MainActor
private final class GatedWindowPeekCaptureService: WindowPeekCaptureService {
    private(set) var startedIDs: [CGWindowID] = []
    private(set) var invalidatedTokens: [WindowPeekCaptureRequestToken] = []
    private(set) var maximumInFlight = 0
    private var inFlight: Set<CGWindowID> = []
    private var starts: [CGWindowID: [CheckedContinuation<Void, Never>]] = [:]
    private var finishes: [CGWindowID: CheckedContinuation<WindowPeekCaptureResult, Never>] = [:]

    func capture(token: WindowPeekCaptureRequestToken, source: (any WindowPeekCaptureSource)?, logicalSize: CGSize, backingScaleFactor: CGFloat) async -> WindowPeekCaptureResult {
        guard let source else { return .unavailable }
        let id = source.windowID.windowID
        startedIDs.append(id)
        inFlight.insert(id)
        maximumInFlight = max(maximumInFlight, inFlight.count)
        starts.removeValue(forKey: id)?.forEach { $0.resume() }
        return await withCheckedContinuation { finishes[id] = $0 }
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) { invalidatedTokens.append(token) }
    func waitUntilStarted(id: CGWindowID) async {
        guard !startedIDs.contains(id) else { return }
        await withCheckedContinuation { starts[id, default: []].append($0) }
    }
    func finish(id: CGWindowID, result: WindowPeekCaptureResult) {
        inFlight.remove(id)
        finishes.removeValue(forKey: id)?.resume(returning: result)
    }
}

@MainActor
private final class RecordingWindowPeekOverlay: WindowPeekOverlayDisplaying {
    enum Event: Equatable { case show(WindowPeekImageQuality), update(WindowPeekImageQuality), hide }
    private(set) var events: [Event] = []
    private var highResolutionWaiters: [CheckedContinuation<Void, Never>] = []
    func show(image: CGImage, layout: WindowPeekLayout, quality: WindowPeekImageQuality) { events.append(.show(quality)); resume(quality) }
    func update(image: CGImage, quality: WindowPeekImageQuality) { events.append(.update(quality)); resume(quality) }
    func hide() { events.append(.hide) }
    func waitUntilHighResolution() async {
        guard !events.contains(where: { $0 == .show(.highResolution) || $0 == .update(.highResolution) }) else { return }
        await withCheckedContinuation { highResolutionWaiters.append($0) }
    }
    private func resume(_ quality: WindowPeekImageQuality) {
        guard quality == .highResolution else { return }
        let waiters = highResolutionWaiters
        highResolutionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

@MainActor
private final class CoordinatorSettingsStore: DockWindowQuickLookSettingsStore {
    var dockWindowQuickLookSettingsSnapshot = DockWindowQuickLookSettingsSnapshot(settings: .defaults)
    private var observers: [UUID: @MainActor (DockWindowQuickLookSettingsSnapshot) -> Void] = [:]
    @discardableResult func addDockWindowQuickLookSettingsObserver(_ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void) -> UUID { let id = UUID(); observers[id] = observer; return id }
    func removeObserver(_ token: UUID) { observers[token] = nil }
    func updateDockWindowQuickLookSettings(transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void) { transform(&dockWindowQuickLookSettingsSnapshot); observers.values.forEach { $0(dockWindowQuickLookSettingsSnapshot) } }
}

@MainActor
private final class CoordinatorPermissionService: PermissionService {
    var screenRecordingGranted = true
    var currentState: PermissionState { PermissionState(accessibilityGranted: true, screenRecordingGranted: screenRecordingGranted) }
    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class ManualWindowPeekPermissionRefreshScheduler: WindowPeekPermissionRefreshScheduling {
    private var handler: (@MainActor () -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) { XCTAssertEqual(interval, WindowPeekCoordinator.permissionRefreshInterval); self.handler = handler; startCount += 1 }
    func stop() { handler = nil; stopCount += 1 }
    func fire() { handler?() }
}

@MainActor
private final class WindowPeekCoordinatorHarness {
    let capture = GatedWindowPeekCaptureService()
    let overlay = RecordingWindowPeekOverlay()
    let exitScheduler = ManualWindowPeekExitScheduler()
    let settings = CoordinatorSettingsStore()
    let permission = CoordinatorPermissionService()
    let permissionScheduler = ManualWindowPeekPermissionRefreshScheduler()
    let logger = ProbeLogger()
    let screen = WindowPeekScreen(identifier: 1, localizedName: "Test", captureFrame: CGRect(x: 0, y: 0, width: 1600, height: 900), appKitFrame: CGRect(x: 0, y: 0, width: 1600, height: 900), backingScaleFactor: 2)
    private(set) var currentTarget: PreviewWindow?
    private(set) var coordinator: WindowPeekCoordinator!
    init() {
        coordinator = WindowPeekCoordinator(captureService: capture, overlay: overlay, settingsStore: settings, permissionService: permission, logger: logger, exitScheduler: exitScheduler, permissionRefreshScheduler: permissionScheduler, onCurrentTargetChanged: { [weak self] target in self?.currentTarget = target })
        coordinator.beginSession(epoch: 1)
        coordinator.updateScreens([screen], sessionEpoch: 1)
    }
    func window(id rawID: CGWindowID) -> PreviewWindow {
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: rawID)
        return PreviewWindow(id: id, cgWindowID: rawID, app: .current, title: "Window \(rawID)", captureFrame: CGRect(x: 0, y: 0, width: 800, height: 600), axElement: nil, appIcon: NSImage(size: NSSize(width: 32, height: 32)), thumbnailSource: nil, desktopPeekCaptureSource: CoordinatorTestCaptureSource(windowID: id), desktopPeekEligible: true)
    }
}

private func image(width: Int = 2, height: Int = 2) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return context.makeImage()!
}

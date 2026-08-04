import AppKit
import Foundation

@MainActor
protocol WindowPeekCoordinating: AnyObject {
    func beginSession(epoch: UInt64)
    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64)
    func hoverEntered(windowID: PreviewWindowID, window: PreviewWindow?, coarseImage: CGImage?, sessionEpoch: UInt64, sequence: UInt64)
    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    func coarseImageDidBecomeAvailable(_ image: CGImage?, for windowID: PreviewWindowID, sessionEpoch: UInt64)
    func targetWindowDestroyed(_ windowID: PreviewWindowID)
    func targetApplicationTerminated(pid: pid_t)
    func stop(reason: WindowPeekStopReason)
    func completePrimarySelectionHandoff()
}

@MainActor
protocol WindowPeekExitScheduling: AnyObject {
    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void)
}

@MainActor
final class MainRunLoopWindowPeekExitScheduler: WindowPeekExitScheduling {
    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void) {
        RunLoop.main.perform { MainActor.assumeIsolated { operation() } }
    }
}

@MainActor
protocol WindowPeekPermissionRefreshScheduling: AnyObject {
    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class MainRunLoopWindowPeekPermissionRefreshScheduler: WindowPeekPermissionRefreshScheduling {
    private var timer: Timer?
    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            precondition(Thread.isMainThread)
            MainActor.assumeIsolated { handler() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() { timer?.invalidate(); timer = nil }
}

@MainActor
final class WindowPeekCoordinator: WindowPeekCoordinating {
    static let permissionRefreshInterval: TimeInterval = 1

    private struct Target {
        let window: PreviewWindow
        let layout: WindowPeekLayout
        let token: WindowPeekCaptureRequestToken
    }
    private struct CaptureRequest {
        let token: WindowPeekCaptureRequestToken
        let source: any WindowPeekCaptureSource
        let logicalSize: CGSize
        let backingScaleFactor: CGFloat
        let layout: WindowPeekLayout
    }
    private enum CaptureSlot {
        case idle
        case capturing(active: CaptureRequest, pendingLatest: CaptureRequest?)
    }

    private let captureService: any WindowPeekCaptureService
    private let overlay: any WindowPeekOverlayDisplaying
    private let settingsStore: any DockWindowQuickLookSettingsStore
    private let permissionService: any PermissionService
    private let logger: ProbeLogger
    private let exitScheduler: any WindowPeekExitScheduling
    private let permissionRefreshScheduler: any WindowPeekPermissionRefreshScheduling
    private let onCurrentTargetChanged: @MainActor (PreviewWindow?) -> Void
    private var settingsToken: UUID?
    private var activeSessionEpoch: UInt64?
    private var greatestSessionEpoch: UInt64 = 0
    private var peekGeneration: UInt64 = 0
    private var lastHoverSequence: UInt64 = 0
    private var currentTarget: Target?
    private var currentQuality: WindowPeekImageQuality?
    private var currentScreens: [WindowPeekScreen] = []
    private var captureSlot: CaptureSlot = .idle
    private var pendingExit: (UInt64, PreviewWindowID, UInt64, UInt64)?
    private var exitFlushScheduled = false
    private var permissionRefreshRunning = false
    private var primarySelectionVisualHandoffPending = false

    init(captureService: any WindowPeekCaptureService, overlay: any WindowPeekOverlayDisplaying, settingsStore: any DockWindowQuickLookSettingsStore, permissionService: any PermissionService, logger: ProbeLogger, exitScheduler: any WindowPeekExitScheduling = MainRunLoopWindowPeekExitScheduler(), permissionRefreshScheduler: any WindowPeekPermissionRefreshScheduling = MainRunLoopWindowPeekPermissionRefreshScheduler(), onCurrentTargetChanged: @escaping @MainActor (PreviewWindow?) -> Void = { _ in }) {
        self.captureService = captureService; self.overlay = overlay; self.settingsStore = settingsStore; self.permissionService = permissionService; self.logger = logger; self.exitScheduler = exitScheduler; self.permissionRefreshScheduler = permissionRefreshScheduler; self.onCurrentTargetChanged = onCurrentTargetChanged
    }
    func startObservingSettings() {
        guard settingsToken == nil else { return }
        settingsToken = settingsStore.addDockWindowQuickLookSettingsObserver { [weak self] snapshot in
            guard !snapshot.isDockHoverPreviewEnabled || !snapshot.isDesktopWindowPeekEnabled else { return }
            self?.stop(reason: .settingsDisabled)
        }
    }
    func stopObservingSettings() { if let settingsToken { settingsStore.removeObserver(settingsToken); self.settingsToken = nil } }

    func beginSession(epoch: UInt64) {
        guard epoch > greatestSessionEpoch else { logger.info("peek.session.stale epoch=\(epoch)"); return }
        let hadTarget = currentTarget != nil || currentQuality != nil || primarySelectionVisualHandoffPending
        invalidateActiveCapture(); stopPermissionRefresh(); currentTarget = nil; currentQuality = nil; pendingExit = nil; primarySelectionVisualHandoffPending = false
        if case let .capturing(active, _) = captureSlot { captureSlot = .capturing(active: active, pendingLatest: nil) }
        if hadTarget { overlay.hide(); onCurrentTargetChanged(nil) }
        greatestSessionEpoch = epoch; activeSessionEpoch = epoch; lastHoverSequence = 0; currentScreens = []
    }
    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64) {
        guard activeSessionEpoch == sessionEpoch else { logger.info("peek.screens.stale epoch=\(sessionEpoch)"); return }
        currentScreens = screens
    }

    func hoverEntered(windowID: PreviewWindowID, window: PreviewWindow?, coarseImage _: CGImage?, sessionEpoch: UInt64, sequence: UInt64) {
        guard activeSessionEpoch == sessionEpoch, sequence >= lastHoverSequence else { return }
        lastHoverSequence = sequence
        if currentTarget?.window.id == windowID { pendingExit = nil; return }
        invalidateActiveCapture(); peekGeneration += 1; pendingExit = nil
        guard settingsStore.dockWindowQuickLookSettingsSnapshot.isDockHoverPreviewEnabled, settingsStore.dockWindowQuickLookSettingsSnapshot.isDesktopWindowPeekEnabled, permissionService.refresh().screenRecordingGranted, let window, window.desktopPeekEligible, let source = window.desktopPeekCaptureSource, let layout = WindowPeekGeometry.layout(windowCaptureFrame: window.captureFrame, screens: currentScreens), let epoch = activeSessionEpoch else {
            stop(reason: permissionService.currentState.screenRecordingGranted ? .targetUnavailable : .permissionDenied); return
        }
        let token = WindowPeekCaptureRequestToken(sessionEpoch: epoch, peekGeneration: peekGeneration, windowID: windowID)
        let target = Target(window: window, layout: layout, token: token)
        if currentQuality != nil {
            overlay.hide()
        }
        currentQuality = nil
        currentTarget = target; onCurrentTargetChanged(window); startPermissionRefresh()
        enqueue(CaptureRequest(token: token, source: source, logicalSize: window.captureFrame.size, backingScaleFactor: layout.screen.backingScaleFactor, layout: layout))
    }
    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64) {
        guard activeSessionEpoch == sessionEpoch, sequence == lastHoverSequence, let target = currentTarget, target.window.id == windowID else { return }
        pendingExit = (sessionEpoch, windowID, sequence, peekGeneration)
        guard !exitFlushScheduled else { return }; exitFlushScheduled = true
        exitScheduler.schedule { [weak self] in self?.flushExit() }
    }
    func coarseImageDidBecomeAvailable(_: CGImage?, for _: PreviewWindowID, sessionEpoch _: UInt64) {}
    func targetWindowDestroyed(_ windowID: PreviewWindowID) { if currentTarget?.window.id == windowID { stop(reason: .targetWindowDestroyed) } }
    func targetApplicationTerminated(pid: pid_t) { if currentTarget?.window.id.pid == pid { stop(reason: .applicationTerminated) } }
    func stop(reason: WindowPeekStopReason) {
        let retainVisibleMirror = reason == .primarySelection && (
            currentTarget != nil || currentQuality != nil || primarySelectionVisualHandoffPending
        )
        stopPermissionRefresh(); peekGeneration += 1; pendingExit = nil; invalidateActiveCapture(); currentTarget = nil; currentQuality = nil; currentScreens = []; onCurrentTargetChanged(nil)
        if case let .capturing(active, _) = captureSlot { captureSlot = .capturing(active: active, pendingLatest: nil) }
        primarySelectionVisualHandoffPending = retainVisibleMirror
        guard retainVisibleMirror else {
            overlay.hide()
            logger.info("peek.hide reason=\(reason.rawValue)")
            return
        }
        logger.info("peek.handoff.begin reason=\(reason.rawValue)")
    }

    func completePrimarySelectionHandoff() {
        guard primarySelectionVisualHandoffPending else { return }
        primarySelectionVisualHandoffPending = false
        overlay.hideAfterPrimarySelectionHandoff()
        logger.info("peek.handoff.complete")
    }

    private func flushExit() {
        exitFlushScheduled = false
        guard let pendingExit, activeSessionEpoch == pendingExit.0, currentTarget?.window.id == pendingExit.1, lastHoverSequence == pendingExit.2, peekGeneration == pendingExit.3 else { return }
        stop(reason: .hoverExited)
    }
    private func enqueue(_ request: CaptureRequest) {
        switch captureSlot { case .idle: launch(request); case let .capturing(active, _): captureSlot = .capturing(active: active, pendingLatest: request) }
    }
    private func launch(_ request: CaptureRequest) {
        guard case .idle = captureSlot else { preconditionFailure("Capture slot must be idle") }
        captureSlot = .capturing(active: request, pendingLatest: nil)
        logger.info("peek.capture.started epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
        Task { @MainActor [weak self, captureService] in
            guard let self else { return }
            guard self.isCurrentCaptureRequest(request) else {
                self.captureDidNotStart(request)
                return
            }
            let result = await captureService.capture(token: request.token, source: request.source, logicalSize: request.logicalSize, backingScaleFactor: request.backingScaleFactor)
            self.captureDidFinish(request, result: result)
        }
    }
    private func captureDidFinish(_ request: CaptureRequest, result: WindowPeekCaptureResult) {
        guard case let .capturing(active, pending) = captureSlot, active.token == request.token else { logger.info("peek.capture.stale epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)"); return }
        captureSlot = .idle
        if currentTarget?.token == request.token {
            switch result {
            case let .image(image):
                if let cropped = WindowPeekGeometry.croppedImage(image, layout: request.layout) {
                    let replacesVisibleImage = currentQuality != nil
                    if replacesVisibleImage {
                        overlay.update(image: cropped, quality: .highResolution)
                    } else {
                        overlay.show(image: cropped, layout: request.layout, quality: .highResolution)
                    }
                    currentQuality = .highResolution
                    let transition = replacesVisibleImage ? "update" : "show"
                    logger.info("peek.\(transition) source=highResolution epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
                    logger.info("peek.capture.success epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
                }
            case .permissionDenied: handlePermissionRefresh()
            case .unavailable, .failed: logger.info("peek.capture.failed epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
            }
        } else { logger.info("peek.capture.stale epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)") }
        if let pending, currentTarget?.token == pending.token { launch(pending) }
    }
    private func isCurrentCaptureRequest(_ request: CaptureRequest) -> Bool {
        activeSessionEpoch == request.token.sessionEpoch && currentTarget?.token == request.token
    }
    private func captureDidNotStart(_ request: CaptureRequest) {
        guard case let .capturing(active, pending) = captureSlot, active.token == request.token else {
            logger.info("peek.capture.stale epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
            return
        }
        captureSlot = .idle
        logger.info("peek.capture.stale epoch=\(request.token.sessionEpoch) generation=\(request.token.peekGeneration) windowID=\(request.token.windowID.windowID)")
        if let pending, currentTarget?.token == pending.token { launch(pending) }
    }
    private func invalidateActiveCapture() { if case let .capturing(active, _) = captureSlot { captureService.invalidateQueuedCapture(token: active.token) } }
    private func startPermissionRefresh() { guard !permissionRefreshRunning else { return }; permissionRefreshRunning = true; permissionRefreshScheduler.start(interval: Self.permissionRefreshInterval) { [weak self] in self?.handlePermissionRefresh() } }
    private func stopPermissionRefresh() { guard permissionRefreshRunning else { return }; permissionRefreshRunning = false; permissionRefreshScheduler.stop() }
    private func handlePermissionRefresh() { if !permissionService.refresh().screenRecordingGranted { stop(reason: .permissionDenied) } }
}

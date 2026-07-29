import AppKit
import CoreGraphics

@MainActor
final class PreviewSessionController {
    private let permissionService: PermissionService
    private let windowQueryService: WindowQueryService
    private let thumbnailService: ThumbnailService
    private let activationService: ActivationService
    private let windowOperationService: WindowOperationService
    private let panelDisplay: PreviewPanelDisplaying
    private let settingsStore: DockWindowQuickLookSettingsStore
    private let targetTracker: AppTargetTracker
    private let windowPeekCoordinator: any WindowPeekCoordinating
    private let logger: ProbeLogger

    private var generation = 0
    private var nextSessionEpoch: UInt64 = 0
    private var currentSessionEpoch: UInt64?
    private var currentModel: PreviewPanelViewModel?
    private var currentWindowsByID: [PreviewWindowID: PreviewWindow] = [:]
    private var leaveTimerOwner: PreviewSessionLeaveTimerOwner?
    private var currentDockItemFrame: CGRect?
    private var currentRetentionParameters = PanelRetentionMode.standard.parameters
    private var settingsObserverToken: UUID?
    private var contextMenuDepth = 0
    private var currentWindowPeekScreens: [WindowPeekScreen] = []
    private var screenSnapshotGeneration: UInt64 = 0

    init(
        permissionService: PermissionService,
        windowQueryService: WindowQueryService,
        thumbnailService: ThumbnailService,
        activationService: ActivationService,
        windowOperationService: WindowOperationService,
        panelDisplay: PreviewPanelDisplaying,
        settingsStore: DockWindowQuickLookSettingsStore,
        targetTracker: AppTargetTracker,
        windowPeekCoordinator: any WindowPeekCoordinating,
        logger: ProbeLogger
    ) {
        self.permissionService = permissionService
        self.windowQueryService = windowQueryService
        self.thumbnailService = thumbnailService
        self.activationService = activationService
        self.windowOperationService = windowOperationService
        self.panelDisplay = panelDisplay
        self.settingsStore = settingsStore
        self.targetTracker = targetTracker
        self.windowPeekCoordinator = windowPeekCoordinator
        self.logger = logger
    }

    func showPreview(for app: NSRunningApplication, anchor: PreviewPanelAnchor) async {
        precondition(nextSessionEpoch < UInt64.max, "Preview session epoch overflow")
        if currentSessionEpoch != nil {
            windowPeekCoordinator.stop(reason: .sessionReplaced)
        }
        nextSessionEpoch += 1
        let sessionEpoch = nextSessionEpoch
        currentSessionEpoch = sessionEpoch
        currentWindowPeekScreens = []
        precondition(screenSnapshotGeneration < UInt64.max, "Screen snapshot generation overflow")
        screenSnapshotGeneration += 1
        let queryScreenSnapshotGeneration = screenSnapshotGeneration
        generation += 1
        contextMenuDepth = 0
        let sessionGeneration = generation
        windowPeekCoordinator.beginSession(epoch: sessionEpoch)

        let state = permissionService.refresh()
        guard state.screenRecordingGranted else {
            hide(reason: "screenRecording=false")
            logger.warning("preview.session.skipped screenRecording=false")
            return
        }

        let settings = settingsStore.dockWindowQuickLookSettingsSnapshot
        currentRetentionParameters = settings.panelRetentionParameters
        let queryResult = await windowQueryService.query(for: app, limit: settings.maxCardCount)
        guard
            isCurrent(sessionGeneration, sessionEpoch: sessionEpoch),
            screenSnapshotGeneration == queryScreenSnapshotGeneration
        else {
            return
        }
        currentWindowPeekScreens = queryResult.screens
        windowPeekCoordinator.updateScreens(queryResult.screens, sessionEpoch: sessionEpoch)
        let windows = queryResult.windows
        guard !windows.isEmpty else {
            hide(reason: "noWindows")
            logger.info("preview.session.noWindows app=\(app.localizedName ?? "unknown")")
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let textProvider = AppTextProvider(language: settings.displayLanguage)
        targetTracker.updateCurrentPreviewApp(AppTarget(app: app))
        let cards = windows.map { window in
            PreviewCardViewModel(
                id: window.id,
                title: window.title,
                appName: appName,
                appIcon: window.appIcon,
                thumbnail: nil,
                isLoadingThumbnail: true,
                sourceFrame: window.captureFrame,
                operationMenu: operationMenu(
                    for: window,
                    environmentDescription: WindowEnvironmentDescriptor.description(
                        forCaptureFrame: window.captureFrame,
                        screens: currentWindowPeekScreens,
                        textProvider: textProvider
                    )
                )
            )
        }
        currentWindowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        currentModel = PreviewPanelViewModel(
            appName: appName,
            cards: cards,
            maxCardCount: settings.maxCardCount,
            thumbnailUnavailableText: textProvider.string(.noThumbnail),
            operationMenuText: PreviewWindowOperationMenuText(textProvider: textProvider)
        )
        if let currentModel {
            panelDisplay.show(model: currentModel, anchor: anchor, sessionEpoch: sessionEpoch) { [weak self] action in
                self?.handle(
                    action,
                    expectedGeneration: sessionGeneration,
                    expectedSessionEpoch: sessionEpoch
                )
            }
        }
        currentDockItemFrame = anchor.dockItemFrame
        startLeavePolling()
        logger.info("preview.session.show app=\(appName) count=\(windows.count)")

        for window in windows {
            let image = await thumbnailService.thumbnail(for: window)
            guard isCurrent(sessionGeneration, sessionEpoch: sessionEpoch) else { return }
            currentModel?.updateThumbnail(image, for: window.id)
            if let currentModel {
                panelDisplay.update(model: currentModel)
            }
            windowPeekCoordinator.coarseImageDidBecomeAvailable(
                image,
                for: window.id,
                sessionEpoch: sessionEpoch
            )
            logger.info("preview.session.thumbnail id=\(window.cgWindowID) success=\(image != nil)")
        }
    }

    func startObservingSettings() {
        guard settingsObserverToken == nil else {
            return
        }

        currentRetentionParameters = settingsStore.dockWindowQuickLookSettingsSnapshot.panelRetentionParameters
        settingsObserverToken = settingsStore.addDockWindowQuickLookSettingsObserver { [weak self] settings in
            self?.currentRetentionParameters = settings.panelRetentionParameters
        }
    }

    func stopObservingSettings() {
        guard let settingsObserverToken else {
            return
        }

        settingsStore.removeObserver(settingsObserverToken)
        self.settingsObserverToken = nil
    }

    func hide(
        reason: String,
        expectedSessionEpoch: UInt64? = nil,
        immediately: Bool = false,
        shouldStopWindowPeek: Bool = true
    ) {
        guard expectedSessionEpoch == nil || expectedSessionEpoch == currentSessionEpoch else {
            logger.warning("preview.session.staleHide reason=\(reason) epoch=\(expectedSessionEpoch.map(String.init) ?? "nil") current=\(currentSessionEpoch.map(String.init) ?? "nil")")
            return
        }
        if shouldStopWindowPeek {
            windowPeekCoordinator.stop(reason: .sessionHidden)
        }
        generation += 1
        currentSessionEpoch = nil
        leaveTimerOwner?.invalidate()
        leaveTimerOwner = nil
        currentDockItemFrame = nil
        currentModel = nil
        currentWindowsByID = [:]
        currentWindowPeekScreens = []
        contextMenuDepth = 0
        targetTracker.updateCurrentPreviewApp(nil)
        if immediately {
            panelDisplay.hideImmediately(reason: reason)
        } else {
            panelDisplay.hide(reason: reason)
        }
    }

    func invalidateWindowPeekScreens(reason: WindowPeekStopReason) {
        precondition(
            reason == .activeSpaceChanged || reason == .screenParametersChanged,
            "Only display lifecycle reasons can invalidate a screen snapshot"
        )
        precondition(screenSnapshotGeneration < UInt64.max, "Screen snapshot generation overflow")
        screenSnapshotGeneration += 1
        currentWindowPeekScreens = []
        windowPeekCoordinator.stop(reason: reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        panelDisplay.isMouseInsidePanel(point)
    }

    func isMouseInsidePreviewRegion(_ point: CGPoint) -> Bool {
        if contextMenuDepth > 0 {
            return true
        }
        if panelDisplay.isMouseInsidePanel(point) {
            return true
        }
        guard let dockFrame = currentDockItemFrame else {
            return false
        }
        let retentionParameters = currentRetentionParameters
        if GeometryHelpers.contains(point, in: dockFrame, tolerance: retentionParameters.dockItemTolerance) {
            return true
        }
        guard let panelFrame = panelDisplay.panelFrame() else {
            return false
        }
        if GeometryHelpers.contains(point, in: panelFrame, tolerance: retentionParameters.panelEdgeTolerance) {
            return true
        }
        return GeometryHelpers.contains(
            point,
            in: bridgeFrame(between: dockFrame, and: panelFrame, inset: retentionParameters.bridgeInset),
            tolerance: 0
        )
    }

    func isMouseInsidePanelTransitionRegion(_ point: CGPoint) -> Bool {
        if contextMenuDepth > 0 {
            return true
        }
        if panelDisplay.isMouseInsidePanel(point) {
            return true
        }
        guard let dockFrame = currentDockItemFrame,
              let panelFrame = panelDisplay.panelFrame() else {
            return false
        }
        let retentionParameters = currentRetentionParameters
        let dockEdgeTolerance = min(CGFloat(4), retentionParameters.dockItemTolerance)
        if GeometryHelpers.contains(point, in: dockFrame, tolerance: dockEdgeTolerance) {
            return true
        }
        if GeometryHelpers.contains(point, in: panelFrame, tolerance: retentionParameters.panelEdgeTolerance) {
            return true
        }
        return GeometryHelpers.contains(
            point,
            in: bridgeFrame(between: dockFrame, and: panelFrame, inset: retentionParameters.bridgeInset),
            tolerance: 0
        )
    }

    func activate(windowID: PreviewWindowID) {
        guard let window = currentWindowsByID[windowID] else {
            logger.warning("preview.session.activateMissing id=\(windowID.windowID)")
            hide(reason: "activateMissing")
            return
        }
        windowPeekCoordinator.stop(reason: .primarySelection)
        hide(reason: "activated", immediately: true, shouldStopWindowPeek: false)
        _ = activationService.activate(window: window)
    }

    private func handle(
        _ action: PreviewPanelAction,
        expectedGeneration: Int,
        expectedSessionEpoch: UInt64
    ) {
        guard isCurrent(expectedGeneration, sessionEpoch: expectedSessionEpoch) else {
            logger.warning("preview.session.staleAction generation=\(expectedGeneration) epoch=\(expectedSessionEpoch) currentGeneration=\(generation) currentEpoch=\(currentSessionEpoch.map(String.init) ?? "nil")")
            return
        }

        switch action {
        case let .primarySelect(id):
            activate(windowID: id)
        case let .windowOperation(id, operation):
            performWindowOperation(operation, windowID: id)
        case .contextMenuWillOpen:
            windowPeekCoordinator.stop(reason: .contextMenu)
        case let .contextMenuBegan(id):
            contextMenuDepth += 1
            logger.info("preview.panel.contextMenuBegan id=\(id.windowID)")
        case let .contextMenuEnded(id):
            contextMenuDepth = max(0, contextMenuDepth - 1)
            logger.info("preview.panel.contextMenuEnded id=\(id.windowID)")
        case let .hoverEntered(id, sessionEpoch, sequence):
            guard sessionEpoch == expectedSessionEpoch else {
                logger.warning("preview.session.staleHoverAction epoch=\(sessionEpoch) expected=\(expectedSessionEpoch)")
                return
            }
            guard currentWindowsByID.count >= 2 else {
                return
            }
            let coarseImage = currentModel?.cards.first { $0.id == id }?.thumbnail
            windowPeekCoordinator.hoverEntered(
                windowID: id,
                window: currentWindowsByID[id],
                coarseImage: coarseImage,
                sessionEpoch: sessionEpoch,
                sequence: sequence
            )
        case let .hoverExited(id, sessionEpoch, sequence):
            guard sessionEpoch == expectedSessionEpoch else {
                logger.warning("preview.session.staleHoverAction epoch=\(sessionEpoch) expected=\(expectedSessionEpoch)")
                return
            }
            guard currentWindowsByID.count >= 2 else {
                return
            }
            windowPeekCoordinator.hoverExited(
                windowID: id,
                sessionEpoch: sessionEpoch,
                sequence: sequence
            )
        }
    }

    private func operationMenu(
        for window: PreviewWindow,
        environmentDescription: String
    ) -> PreviewWindowOperationMenuModel {
        PreviewWindowOperationMenuModel(
            activate: windowOperationService.availability(for: .activate, window: window),
            hideApplication: windowOperationService.availability(for: .hideApplication, window: window),
            closeWindow: windowOperationService.availability(for: .closeWindow, window: window),
            minimizeWindow: windowOperationService.availability(for: .minimizeWindow, window: window),
            environmentDescription: environmentDescription
        )
    }

    private func performWindowOperation(
        _ operation: PreviewWindowOperation,
        windowID: PreviewWindowID
    ) {
        guard operation != .activate else {
            activate(windowID: windowID)
            return
        }

        guard let window = currentWindowsByID[windowID] else {
            logger.warning("windowOperation.missingWindow id=\(windowID.windowID)")
            return
        }

        let result = windowOperationService.perform(operation, on: window)
        if result.requestSucceeded {
            hide(reason: "windowOperation.\(operation.rawValue)")
        } else {
            logger.warning(
                "windowOperation.result operation=\(operation.rawValue) id=\(windowID.windowID) requestSucceeded=false reason=\(result.failure?.reason.rawValue ?? "none") stage=\(result.failure?.stage.rawValue ?? "none") axCode=\(result.failure?.axErrorCode.map(String.init) ?? "none")"
            )
        }
    }

    private func isCurrent(_ expectedGeneration: Int, sessionEpoch: UInt64) -> Bool {
        generation == expectedGeneration && currentSessionEpoch == sessionEpoch
    }

    private func startLeavePolling() {
        leaveTimerOwner?.invalidate()
        leaveTimerOwner = PreviewSessionLeaveTimerOwner { [weak self] in
            self?.pollLeaveRegion()
        }
    }

    private func pollLeaveRegion() {
        if !isMouseInsidePreviewRegion(NSEvent.mouseLocation) {
            hide(reason: "mouseLeftPreviewRegion")
        }
    }

    private func bridgeFrame(between dockFrame: CGRect, and panelFrame: CGRect, inset: CGFloat) -> CGRect {
        let overlapMinY = max(dockFrame.minY, panelFrame.minY)
        let overlapMaxY = min(dockFrame.maxY, panelFrame.maxY)

        let hasVerticalOverlap = overlapMaxY > overlapMinY

        if hasVerticalOverlap {
            let minX = min(dockFrame.maxX, panelFrame.maxX)
            let maxX = max(dockFrame.minX, panelFrame.minX)
            return CGRect(
                x: minX,
                y: overlapMinY,
                width: max(0, maxX - minX),
                height: overlapMaxY - overlapMinY
            ).insetBy(dx: -inset, dy: -inset)
        }

        let bridgeX = min(dockFrame.midX, panelFrame.midX) - inset
        let bridgeWidth = inset * 2
        let minY = min(dockFrame.maxY, panelFrame.maxY)
        let maxY = max(dockFrame.minY, panelFrame.minY)
        return CGRect(
            x: bridgeX,
            y: minY,
            width: bridgeWidth,
            height: max(0, maxY - minY)
        ).insetBy(dx: -inset, dy: -inset)
    }
}

private final class PreviewSessionLeaveTimerOwner {
    private var timer: Timer?
    private let onTick: @MainActor @Sendable () -> Void

    init(onTick: @MainActor @escaping @Sendable () -> Void) {
        self.onTick = onTick
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [onTick] _ in
            Task { @MainActor in
                onTick()
            }
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        invalidate()
    }
}

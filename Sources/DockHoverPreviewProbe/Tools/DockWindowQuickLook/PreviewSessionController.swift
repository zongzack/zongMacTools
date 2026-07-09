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
    private let screenProvider: @MainActor () -> [WindowEnvironmentDescriptor.Screen]
    private let logger: ProbeLogger

    private var generation = 0
    private var currentModel: PreviewPanelViewModel?
    private var currentWindowsByID: [PreviewWindowID: PreviewWindow] = [:]
    private var leaveTimerOwner: PreviewSessionLeaveTimerOwner?
    private var currentDockItemFrame: CGRect?
    private var currentRetentionParameters = PanelRetentionMode.standard.parameters
    private var settingsObserverToken: UUID?
    private var contextMenuDepth = 0

    init(
        permissionService: PermissionService,
        windowQueryService: WindowQueryService,
        thumbnailService: ThumbnailService,
        activationService: ActivationService,
        windowOperationService: WindowOperationService,
        panelDisplay: PreviewPanelDisplaying,
        settingsStore: DockWindowQuickLookSettingsStore,
        targetTracker: AppTargetTracker,
        screenProvider: @MainActor @escaping () -> [WindowEnvironmentDescriptor.Screen] = WindowEnvironmentDescriptor.currentScreens,
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
        self.screenProvider = screenProvider
        self.logger = logger
    }

    func showPreview(for app: NSRunningApplication, anchor: PreviewPanelAnchor) async {
        let state = permissionService.refresh()
        guard state.screenRecordingGranted else {
            hide(reason: "screenRecording=false")
            logger.warning("preview.session.skipped screenRecording=false")
            return
        }

        generation += 1
        contextMenuDepth = 0
        let sessionGeneration = generation
        let settings = settingsStore.dockWindowQuickLookSettingsSnapshot
        currentRetentionParameters = settings.panelRetentionParameters
        let windows = await windowQueryService.windows(for: app, limit: settings.maxCardCount)
        guard isCurrent(sessionGeneration) else { return }
        guard !windows.isEmpty else {
            hide(reason: "noWindows")
            logger.info("preview.session.noWindows app=\(app.localizedName ?? "unknown")")
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let textProvider = AppTextProvider(language: settings.displayLanguage)
        let screens = screenProvider()
        targetTracker.updateCurrentPreviewApp(AppTarget(app: app))
        let cards = windows.map { window in
            PreviewCardViewModel(
                id: window.id,
                title: window.title,
                appName: appName,
                appIcon: window.appIcon,
                thumbnail: nil,
                isLoadingThumbnail: true,
                sourceFrame: window.frame,
                operationMenu: operationMenu(
                    for: window,
                    environmentDescription: WindowEnvironmentDescriptor.description(
                        for: window.frame,
                        screens: screens,
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
            panelDisplay.show(model: currentModel, anchor: anchor) { [weak self] action in
                Task { @MainActor in
                    await self?.handle(action, expectedGeneration: sessionGeneration)
                }
            }
        }
        currentDockItemFrame = anchor.dockItemFrame
        startLeavePolling()
        logger.info("preview.session.show app=\(appName) count=\(windows.count)")

        for window in windows {
            let image = await thumbnailService.thumbnail(for: window)
            guard isCurrent(sessionGeneration) else { return }
            currentModel?.updateThumbnail(image, for: window.id)
            if let currentModel {
                panelDisplay.update(model: currentModel)
            }
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

    func hide(reason: String) {
        generation += 1
        leaveTimerOwner?.invalidate()
        leaveTimerOwner = nil
        currentDockItemFrame = nil
        currentModel = nil
        currentWindowsByID = [:]
        contextMenuDepth = 0
        targetTracker.updateCurrentPreviewApp(nil)
        panelDisplay.hide(reason: reason)
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

    func activate(windowID: PreviewWindowID) async {
        guard let window = currentWindowsByID[windowID] else {
            logger.warning("preview.session.activateMissing id=\(windowID.windowID)")
            hide(reason: "activateMissing")
            return
        }
        _ = activationService.activate(window: window)
        hide(reason: "activated")
    }

    private func handle(_ action: PreviewPanelAction, expectedGeneration: Int) async {
        guard isCurrent(expectedGeneration) else {
            logger.warning("preview.session.staleAction generation=\(expectedGeneration) current=\(generation)")
            return
        }

        switch action {
        case let .primarySelect(id):
            await activate(windowID: id)
        case let .windowOperation(id, operation):
            await performWindowOperation(operation, windowID: id)
        case let .contextMenuBegan(id):
            contextMenuDepth += 1
            logger.info("preview.panel.contextMenuBegan id=\(id.windowID)")
        case let .contextMenuEnded(id):
            contextMenuDepth = max(0, contextMenuDepth - 1)
            logger.info("preview.panel.contextMenuEnded id=\(id.windowID)")
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
    ) async {
        guard operation != .activate else {
            await activate(windowID: windowID)
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

    private func isCurrent(_ expectedGeneration: Int) -> Bool {
        generation == expectedGeneration
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

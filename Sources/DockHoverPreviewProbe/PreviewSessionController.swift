import AppKit
import CoreGraphics

@MainActor
final class PreviewSessionController {
    private let permissionService: PermissionService
    private let windowQueryService: WindowQueryService
    private let thumbnailService: ThumbnailService
    private let activationService: ActivationService
    private let panelDisplay: PreviewPanelDisplaying
    private let logger: ProbeLogger

    private var generation = 0
    private var currentModel: PreviewPanelViewModel?
    private var currentWindowsByID: [PreviewWindowID: PreviewWindow] = [:]
    private var leaveTimerOwner: PreviewSessionLeaveTimerOwner?
    private var currentDockItemFrame: CGRect?

    init(
        permissionService: PermissionService,
        windowQueryService: WindowQueryService,
        thumbnailService: ThumbnailService,
        activationService: ActivationService,
        panelDisplay: PreviewPanelDisplaying,
        logger: ProbeLogger
    ) {
        self.permissionService = permissionService
        self.windowQueryService = windowQueryService
        self.thumbnailService = thumbnailService
        self.activationService = activationService
        self.panelDisplay = panelDisplay
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
        let sessionGeneration = generation
        let windows = Array(await windowQueryService.windows(for: app).prefix(8))
        guard isCurrent(sessionGeneration) else { return }
        guard !windows.isEmpty else {
            hide(reason: "noWindows")
            logger.info("preview.session.noWindows app=\(app.localizedName ?? "unknown")")
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let cards = windows.map { window in
            PreviewCardViewModel(
                id: window.id,
                title: window.title,
                appName: appName,
                appIcon: window.appIcon,
                thumbnail: nil,
                isLoadingThumbnail: true
            )
        }
        currentWindowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        currentModel = PreviewPanelViewModel(appName: appName, cards: cards)
        if let currentModel {
            panelDisplay.show(model: currentModel, anchor: anchor) { [weak self] id in
                Task { @MainActor in
                    await self?.activate(windowID: id)
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

    func hide(reason: String) {
        generation += 1
        leaveTimerOwner?.invalidate()
        leaveTimerOwner = nil
        currentDockItemFrame = nil
        currentModel = nil
        currentWindowsByID = [:]
        panelDisplay.hide(reason: reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        panelDisplay.isMouseInsidePanel(point)
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
        let mouse = NSEvent.mouseLocation
        let insideDock = currentDockItemFrame.map { GeometryHelpers.contains(mouse, in: $0, tolerance: 2) } ?? false
        let insidePanel = panelDisplay.isMouseInsidePanel(mouse)
        if !insideDock && !insidePanel {
            hide(reason: "mouseLeftPreviewRegion")
        }
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

import AppKit

@MainActor
final class ProbeOrchestrator: DockHoverMonitorDelegate {
    private let permissionService: PermissionService
    private let logger: ProbeLogger
    private let previewSessionController: PreviewSessionController
    private lazy var dockHoverMonitor = DockHoverMonitor(logger: logger)
    private var pendingHoverWorkItem: DispatchWorkItem?

    init(permissionService: PermissionService, logger: ProbeLogger, previewSessionController: PreviewSessionController) {
        self.permissionService = permissionService
        self.logger = logger
        self.previewSessionController = previewSessionController
        self.dockHoverMonitor.delegate = self
    }

    func start() {
        let state = permissionService.refresh()
        logger.info("orchestrator.start accessibility=\(state.accessibilityGranted) screenRecording=\(state.screenRecordingGranted)")
        if state.accessibilityGranted {
            dockHoverMonitor.start()
        } else {
            logger.warning("orchestrator.dockSkipped accessibility=false")
        }
    }

    func stop() {
        pendingHoverWorkItem?.cancel()
        Task { @MainActor [previewSessionController] in
            previewSessionController.hide(reason: "orchestratorStop")
        }
        dockHoverMonitor.stop()
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        guard permissionService.refresh().screenRecordingGranted else {
            Task { @MainActor [previewSessionController] in
                previewSessionController.hide(reason: "screenRecording=false")
            }
            logger.warning("debug.frontmost.skipped screenRecording=false")
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else {
            logger.warning("debug.frontmost.noApp")
            return
        }
        let anchor = makeAnchor(dockItemFrame: nil)
        logger.info("debug.frontmost.start app=\(app.localizedName ?? "unknown") bundle=\(app.bundleIdentifier ?? "nil") pid=\(app.processIdentifier)")
        Task { @MainActor [weak self] in
            await self?.previewSessionController.showPreview(for: app, anchor: anchor)
        }
    }

    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp) {
        pendingHoverWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak monitor] in
            guard let self, let monitor else { return }
            let stillHovered = monitor.resolveCurrentHoveredDockApp()
            let matches = stillHovered?.bundleIdentifier == app.bundleIdentifier
            let validationFrame = stillHovered?.dockItemFrame
            let mouseInside = validationFrame.map { GeometryHelpers.contains(NSEvent.mouseLocation, in: $0, tolerance: 2) } ?? false
            self.logger.info("dock.hoverDelayed bundle=\(app.bundleIdentifier) matches=\(matches) mouseInside=\(mouseInside) frame=\(String(describing: validationFrame))")
            guard matches, mouseInside, let hoveredApp = stillHovered else {
                self.previewSessionController.hide(reason: "hoverValidationFailed")
                return
            }
            let anchor = self.makeAnchor(dockItemFrame: validationFrame)
            Task { @MainActor [previewSessionController] in
                await previewSessionController.showPreview(for: hoveredApp.app, anchor: anchor)
            }
        }
        pendingHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
        pendingHoverWorkItem?.cancel()
        Task { @MainActor [previewSessionController] in
            previewSessionController.hide(reason: "hoverLost")
        }
        logger.info("dock.hoverLost.orchestrator")
    }

    private func makeAnchor(dockItemFrame: CGRect?) -> PreviewPanelAnchor {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { GeometryHelpers.contains(mouse, in: $0.frame, tolerance: 0) }
            ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = screen?.visibleFrame ?? screenFrame
        return PreviewPanelAnchor(
            dockItemFrame: dockItemFrame,
            mouseLocation: mouse,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
    }
}

import AppKit

final class ProbeOrchestrator: DockHoverMonitorDelegate {
    private let permissionService: PermissionService
    private let logger: ProbeLogger
    private lazy var dockHoverMonitor = DockHoverMonitor(logger: logger)
    private var pendingHoverWorkItem: DispatchWorkItem?

    init(permissionService: PermissionService, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.logger = logger
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
        dockHoverMonitor.stop()
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        logger.info("debug.frontmost.placeholder app=\(appName)")
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
        }
        pendingHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
        pendingHoverWorkItem?.cancel()
        logger.info("dock.hoverLost.orchestrator")
    }
}

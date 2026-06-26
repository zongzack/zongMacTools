import AppKit

final class ProbeOrchestrator {
    private let permissionService: PermissionService
    private let logger: ProbeLogger

    init(permissionService: PermissionService, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.logger = logger
    }

    func start() {
        let state = permissionService.refresh()
        logger.info("orchestrator.start accessibility=\(state.accessibilityGranted) screenRecording=\(state.screenRecordingGranted)")
    }

    func stop() {
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        logger.info("debug.frontmost.placeholder app=\(appName)")
    }
}

import AppKit

@MainActor
final class MenuBarController {
    private let permissionService: PermissionService
    private let orchestrator: ProbeOrchestrator
    private let logger: ProbeLogger
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(permissionService: PermissionService, orchestrator: ProbeOrchestrator, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.orchestrator = orchestrator
        self.logger = logger
    }

    func install() {
        statusItem.button?.title = "DHP"
        rebuildMenu()
        logger.info("menu.installed")
    }

    private func rebuildMenu(state: PermissionState? = nil) {
        let state = state ?? permissionService.refresh()
        let menu = NSMenu()
        menu.addItem(disabledItem("Accessibility: \(state.accessibilityGranted ? "granted" : "missing")"))
        menu.addItem(disabledItem("Screen Recording: \(state.screenRecordingGranted ? "granted" : "missing")"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Request Accessibility Prompt", #selector(requestAccessibilityPrompt)))
        menu.addItem(actionItem("Open Accessibility Settings", #selector(openAccessibilitySettings)))
        menu.addItem(actionItem("Open Screen Recording Settings", #selector(openScreenRecordingSettings)))
        menu.addItem(actionItem("Refresh Permissions", #selector(refreshPermissions)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Debug: Show Preview For Frontmost App", #selector(showFrontmostAppProbe)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit", #selector(quit)))
        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func requestAccessibilityPrompt() {
        permissionService.requestAccessibilityPrompt()
        rebuildMenu(state: permissionService.currentState)
    }

    @objc private func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        permissionService.openScreenRecordingSettings()
    }

    @objc private func refreshPermissions() {
        let state = permissionService.refresh()
        rebuildMenu(state: state)
    }

    @objc private func showFrontmostAppProbe() {
        orchestrator.showFrontmostAppProbe()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

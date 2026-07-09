import AppKit

@MainActor
protocol AppNameResolving: AnyObject {
    func displayName(forBundleIdentifier bundleIdentifier: String) -> String?
}

@MainActor
final class NoopSettingsWindowPresenter: SettingsWindowPresenting {
    func showSettings(selectedPage: SettingsPage) {}
}

@MainActor
final class WorkspaceAppNameResolver: AppNameResolving {
    func displayName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        if let bundle = Bundle(url: url),
           let displayName = [
               bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
           ]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return displayName
        }

        let filename = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return filename.isEmpty ? nil : filename
    }
}

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let permissionService: PermissionService
    private let settingsStore: DockHoverPreviewSettingsStore
    private let diagnosticExportPresenter: DiagnosticExportPresenting
    private let settingsWindowPresenter: SettingsWindowPresenting
    private let logger: ProbeLogger
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(
        permissionService: PermissionService,
        settingsStore: DockHoverPreviewSettingsStore,
        diagnosticExportPresenter: DiagnosticExportPresenting = NoopDiagnosticExportPresenter(),
        settingsWindowPresenter: SettingsWindowPresenting = NoopSettingsWindowPresenter(),
        logger: ProbeLogger
    ) {
        self.permissionService = permissionService
        self.settingsStore = settingsStore
        self.diagnosticExportPresenter = diagnosticExportPresenter
        self.settingsWindowPresenter = settingsWindowPresenter
        self.logger = logger
        super.init()
    }

    func install() {
        configureStatusButton()
        rebuildMenu()
        logger.info("menu.installed")
    }

    var statusButtonForTesting: NSStatusBarButton? {
        statusItem.button
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }
        button.title = ""
        button.image = MenuBarIcon.makeImage()
        button.imagePosition = .imageOnly
        button.toolTip = "zongMacTools"
    }

    private func rebuildMenu(state: PermissionState? = nil) {
        let state = state ?? permissionService.currentState
        let menu = makeMenu(permissionState: state)
        menu.delegate = self
        statusItem.menu = menu
    }

    var installedMenuForTesting: NSMenu? {
        statusItem.menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        replaceContents(of: menu, with: makeMenu(permissionState: permissionService.currentState))
    }

    func makeMenu(permissionState _: PermissionState) -> NSMenu {
        let settings = settingsStore.snapshot
        let text = AppTextProvider(language: settings.displayLanguage)
        let menu = NSMenu()

        let statusKey: LocalizedTextKey = settings.isDockHoverPreviewEnabled
            ? .dockHoverPreviewStatusEnabled
            : .dockHoverPreviewStatusDisabled
        let toggleKey: LocalizedTextKey = settings.isDockHoverPreviewEnabled
            ? .disableDockHoverPreview
            : .enableDockHoverPreview

        menu.addItem(disabledItem("zongMacTools"))
        menu.addItem(disabledItem(text.string(statusKey)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(text.string(.openSettings), #selector(openSettings)))
        menu.addItem(actionItem(text.string(toggleKey), #selector(toggleDockHoverPreview)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(text.string(.aboutStatus), #selector(showAboutStatus)))
        menu.addItem(actionItem(text.string(.exportDiagnostics), #selector(exportDiagnostics)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(text.string(.quit), #selector(quit)))

        return menu
    }

    private func disabledItem(_ title: String, state: NSControl.StateValue = .off) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.state = state
        return item
    }

    private func actionItem(
        _ title: String,
        _ selector: Selector,
        enabled: Bool = true,
        state: NSControl.StateValue = .off,
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        item.state = state
        item.representedObject = representedObject
        return item
    }

    private func replaceContents(of menu: NSMenu, with refreshedMenu: NSMenu) {
        menu.removeAllItems()
        while let item = refreshedMenu.items.first {
            refreshedMenu.removeItem(item)
            menu.addItem(item)
        }
        menu.delegate = self
    }

    @objc private func showAboutStatus() {
        settingsWindowPresenter.showSettings(selectedPage: .aboutStatus)
    }

    @objc private func exportDiagnostics() {
        diagnosticExportPresenter.exportDiagnostics()
    }

    @objc private func openSettings() {
        settingsWindowPresenter.showSettings(selectedPage: .dockWindowQuickLook)
    }

    @objc private func toggleDockHoverPreview() {
        settingsStore.update { settings in
            settings.isDockHoverPreviewEnabled.toggle()
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

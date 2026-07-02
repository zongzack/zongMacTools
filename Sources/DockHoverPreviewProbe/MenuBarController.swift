import AppKit

@MainActor
protocol MenuOrchestrating: AnyObject {
    func showFrontmostAppProbe()
    func cancelPendingHover(reason: String)
    func hidePreview(reason: String)
}

@MainActor
protocol AppNameResolving: AnyObject {
    func displayName(forBundleIdentifier bundleIdentifier: String) -> String?
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
    private let orchestrator: MenuOrchestrating
    private let settingsStore: DockHoverPreviewSettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let targetTracker: AppTargetTracker
    private let appNameResolver: AppNameResolving
    private let logger: ProbeLogger
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(
        permissionService: PermissionService,
        orchestrator: MenuOrchestrating,
        settingsStore: DockHoverPreviewSettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        targetTracker: AppTargetTracker,
        appNameResolver: AppNameResolving = WorkspaceAppNameResolver(),
        logger: ProbeLogger
    ) {
        self.permissionService = permissionService
        self.orchestrator = orchestrator
        self.settingsStore = settingsStore
        self.launchAtLoginService = launchAtLoginService
        self.targetTracker = targetTracker
        self.appNameResolver = appNameResolver
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
        let state = state ?? permissionService.refresh()
        let menu = makeMenu(permissionState: state)
        menu.delegate = self
        statusItem.menu = menu
    }

    var installedMenuForTesting: NSMenu? {
        statusItem.menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        replaceContents(of: menu, with: makeMenu(permissionState: permissionService.refresh()))
    }

    func makeMenu(permissionState state: PermissionState) -> NSMenu {
        let settings = settingsStore.snapshot
        let text = AppTextProvider(language: settings.displayLanguage)
        let menu = NSMenu()

        menu.addItem(disabledItem(text.accessibilityStatus(granted: state.accessibilityGranted)))
        menu.addItem(disabledItem(text.screenRecordingStatus(granted: state.screenRecordingGranted)))
        menu.addItem(NSMenuItem.separator())

        addDockHoverPreviewSection(to: menu, settings: settings, text: text)
        addSettingsSections(to: menu, settings: settings, text: text)
        addExcludedAppsSection(to: menu, settings: settings, text: text)
        addLaunchAtLoginSection(to: menu, text: text)

        menu.addItem(actionItem(text.string(.requestAccessibilityPrompt), #selector(requestAccessibilityPrompt)))
        menu.addItem(actionItem(text.string(.openAccessibilitySettings), #selector(openAccessibilitySettings)))
        menu.addItem(actionItem(text.string(.openScreenRecordingSettings), #selector(openScreenRecordingSettings)))
        menu.addItem(actionItem(text.string(.refreshPermissions), #selector(refreshPermissions)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(text.string(.debugShowPreviewForFrontmostApp), #selector(showFrontmostAppProbe)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(text.string(.quit), #selector(quit)))

        return menu
    }

    private func addDockHoverPreviewSection(
        to menu: NSMenu,
        settings: DockHoverPreviewSettings,
        text: AppTextProvider
    ) {
        let statusKey: LocalizedTextKey = settings.isDockHoverPreviewEnabled
            ? .dockHoverPreviewStatusEnabled
            : .dockHoverPreviewStatusDisabled
        let toggleKey: LocalizedTextKey = settings.isDockHoverPreviewEnabled
            ? .disableDockHoverPreview
            : .enableDockHoverPreview

        menu.addItem(disabledItem(text.string(statusKey)))
        menu.addItem(actionItem(text.string(toggleKey), #selector(toggleDockHoverPreview)))
        menu.addItem(NSMenuItem.separator())
    }

    private func addSettingsSections(
        to menu: NSMenu,
        settings: DockHoverPreviewSettings,
        text: AppTextProvider
    ) {
        menu.addItem(submenuItem(
            text.string(.hoverDelay),
            items: [150, 250, 400].map { milliseconds in
                actionItem(
                    "\(milliseconds) ms",
                    #selector(setHoverDelay(_:)),
                    state: settings.hoverDelayMilliseconds == milliseconds ? .on : .off,
                    representedObject: milliseconds
                )
            }
        ))
        menu.addItem(submenuItem(
            text.string(.panelRetention),
            items: PanelRetentionMode.allCases.map { mode in
                actionItem(
                    text.panelRetentionDisplayName(mode),
                    #selector(setPanelRetention(_:)),
                    state: settings.panelRetentionMode == mode ? .on : .off,
                    representedObject: mode.rawValue
                )
            }
        ))
        menu.addItem(submenuItem(
            text.string(.maxCards),
            items: [3, 5, 8, 12].map { count in
                actionItem(
                    "\(count)",
                    #selector(setMaxCards(_:)),
                    state: settings.maxCardCount == count ? .on : .off,
                    representedObject: count
                )
            }
        ))
        menu.addItem(submenuItem(
            text.string(.language),
            items: DisplayLanguage.allCases.map { language in
                actionItem(
                    text.languageDisplayName(language),
                    #selector(setLanguage(_:)),
                    state: settings.displayLanguage == language ? .on : .off,
                    representedObject: language.rawValue
                )
            }
        ))
        menu.addItem(NSMenuItem.separator())
    }

    private func addExcludedAppsSection(
        to menu: NSMenu,
        settings: DockHoverPreviewSettings,
        text: AppTextProvider
    ) {
        var items: [NSMenuItem] = []
        let excludedAppBundleIdentifiers = settings.excludedAppBundleIdentifiers

        if let target = targetTracker.exclusionTarget {
            let isExcluded = excludedAppBundleIdentifiers.contains(target.bundleIdentifier)
            items.append(actionItem(
                isExcluded
                    ? text.includeNamedApp(text.externalAppName(target.displayName))
                    : text.excludeNamedApp(text.externalAppName(target.displayName)),
                isExcluded ? #selector(includeTargetApp(_:)) : #selector(excludeTargetApp(_:)),
                representedObject: target
            ))
        } else {
            items.append(disabledItem(text.string(.excludeApp)))
        }

        items.append(actionItem(
            text.string(.clearExcludedApps),
            #selector(clearExcludedApps),
            enabled: !excludedAppBundleIdentifiers.isEmpty
        ))

        let sortedBundleIdentifiers = excludedAppBundleIdentifiers.sorted()
        if !sortedBundleIdentifiers.isEmpty {
            items.append(NSMenuItem.separator())
        }
        for bundleIdentifier in sortedBundleIdentifiers.prefix(20) {
            let appName = appNameResolver.displayName(forBundleIdentifier: bundleIdentifier)
            items.append(actionItem(
                text.excludedAppListTitle(appName: appName, bundleIdentifier: bundleIdentifier),
                #selector(removeExcludedApp(_:)),
                representedObject: bundleIdentifier
            ))
        }
        let remainingCount = sortedBundleIdentifiers.count - 20
        if remainingCount > 0 {
            items.append(disabledItem(text.moreExcludedApps(count: remainingCount)))
        }

        menu.addItem(submenuItem(text.string(.excludedApps), items: items))
        menu.addItem(NSMenuItem.separator())
    }

    private func addLaunchAtLoginSection(to menu: NSMenu, text: AppTextProvider) {
        let status = launchAtLoginService.status

        menu.addItem(disabledItem(text.string(status.menuTextKey)))
        switch status {
        case .enabled:
            menu.addItem(actionItem(text.string(.disableLaunchAtLogin), #selector(disableLaunchAtLogin)))
        case .notRegistered:
            menu.addItem(actionItem(text.string(.enableLaunchAtLogin), #selector(enableLaunchAtLogin)))
        case .requiresApproval:
            menu.addItem(actionItem(text.string(.openLoginItemsSettings), #selector(openLoginItemsSettings)))
        case .notFound:
            menu.addItem(actionItem(
                text.string(.enableLaunchAtLogin),
                #selector(enableLaunchAtLogin),
                enabled: false
            ))
            menu.addItem(actionItem(
                text.string(.disableLaunchAtLogin),
                #selector(disableLaunchAtLogin),
                enabled: false
            ))
            menu.addItem(actionItem(text.string(.openLoginItemsSettings), #selector(openLoginItemsSettings)))
        }
        menu.addItem(NSMenuItem.separator())
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

    private func submenuItem(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        items.forEach { submenu.addItem($0) }
        item.submenu = submenu
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

    private func representedInt(from item: NSMenuItem) -> Int? {
        if let value = item.representedObject as? Int {
            return value
        }
        return (item.representedObject as? NSNumber)?.intValue
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

    @objc private func setHoverDelay(_ sender: NSMenuItem) {
        guard let milliseconds = representedInt(from: sender) else {
            return
        }
        settingsStore.update { settings in
            settings.hoverDelayMilliseconds = milliseconds
        }
        orchestrator.cancelPendingHover(reason: "settingsChanged")
        rebuildMenu()
    }

    @objc private func setPanelRetention(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PanelRetentionMode(rawValue: rawValue) else {
            return
        }
        settingsStore.update { settings in
            settings.panelRetentionMode = mode
        }
        rebuildMenu()
    }

    @objc private func setMaxCards(_ sender: NSMenuItem) {
        guard let count = representedInt(from: sender) else {
            return
        }
        settingsStore.update { settings in
            settings.maxCardCount = count
        }
        rebuildMenu()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = DisplayLanguage(rawValue: rawValue) else {
            return
        }
        settingsStore.update { settings in
            settings.displayLanguage = language
        }
        rebuildMenu()
    }

    @objc private func toggleDockHoverPreview() {
        let wasEnabled = settingsStore.snapshot.isDockHoverPreviewEnabled
        settingsStore.update { settings in
            settings.isDockHoverPreviewEnabled.toggle()
        }
        if wasEnabled {
            orchestrator.cancelPendingHover(reason: "settingsDisabled")
            orchestrator.hidePreview(reason: "settingsDisabled")
        }
        rebuildMenu()
    }

    @objc private func excludeTargetApp(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? AppTarget else {
            return
        }
        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.insert(target.bundleIdentifier)
        }
        orchestrator.cancelPendingHover(reason: "appExcluded")
        orchestrator.hidePreview(reason: "appExcluded")
        rebuildMenu()
    }

    @objc private func includeTargetApp(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? AppTarget else {
            return
        }
        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.remove(target.bundleIdentifier)
        }
        rebuildMenu()
    }

    @objc private func removeExcludedApp(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else {
            return
        }
        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.remove(bundleIdentifier)
        }
        rebuildMenu()
    }

    @objc private func clearExcludedApps() {
        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.removeAll()
        }
        rebuildMenu()
    }

    @objc private func enableLaunchAtLogin() {
        do {
            try launchAtLoginService.enable()
        } catch {
            logger.error("launchAtLogin.enableFailed error=\(error)")
        }
        rebuildMenu()
    }

    @objc private func disableLaunchAtLogin() {
        do {
            try launchAtLoginService.disable()
        } catch {
            logger.error("launchAtLogin.disableFailed error=\(error)")
        }
        rebuildMenu()
    }

    @objc private func openLoginItemsSettings() {
        launchAtLoginService.openSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

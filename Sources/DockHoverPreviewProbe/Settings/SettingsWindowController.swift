import AppKit
import SwiftUI

@MainActor
final class SettingsWindowSelection: ObservableObject {
    @Published var selectedPage: SettingsPage

    init(selectedPage: SettingsPage = .dockWindowQuickLook) {
        self.selectedPage = selectedPage
    }
}

@MainActor
final class SettingsWindowController: NSObject, SettingsWindowPresenting {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("com.zong.zongMacTools.settingsWindow")

    private let settingsViewModel: SettingsViewModel
    private let permissionService: PermissionService
    private let appStatusProvider: AppStatusProviding
    private let diagnosticExportPresenter: DiagnosticExportPresenting
    private let selection: SettingsWindowSelection
    private let appActivator: @MainActor () -> Void
    private var window: NSWindow?
    private var activationObserver: NSObjectProtocol?

    init(
        settingsViewModel: SettingsViewModel,
        permissionService: PermissionService,
        appStatusProvider: AppStatusProviding,
        diagnosticExportPresenter: DiagnosticExportPresenting,
        selection: SettingsWindowSelection = SettingsWindowSelection(),
        appActivator: @MainActor @escaping () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.settingsViewModel = settingsViewModel
        self.permissionService = permissionService
        self.appStatusProvider = appStatusProvider
        self.diagnosticExportPresenter = diagnosticExportPresenter
        self.selection = selection
        self.appActivator = appActivator
        super.init()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.window?.isVisible == true else { return }
                self.settingsViewModel.finderExtensionSettings.refresh()
            }
        }
    }

    func showSettings(selectedPage: SettingsPage) {
        settingsViewModel.refreshForSettingsPresentation()
        selection.selectedPage = selectedPage
        let window = window ?? makeWindow()
        self.window = window
        window.title = AppTextProvider(language: settingsViewModel.displayLanguage)
            .string(.settingsWindowTitle)
        window.makeKeyAndOrderFront(nil)
        appActivator()
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsRootView(
            viewModel: settingsViewModel,
            selection: selection,
            permissionService: permissionService,
            appStatusProvider: appStatusProvider,
            diagnosticExportPresenter: diagnosticExportPresenter
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = Self.windowIdentifier
        window.title = AppTextProvider(language: settingsViewModel.displayLanguage)
            .string(.settingsWindowTitle)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        window.setContentSize(NSSize(width: 980, height: 640))
        window.center()
        return window
    }
}

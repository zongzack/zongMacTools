import Combine
import Foundation

struct AppSettingsViewState: Equatable {
    let displayLanguage: DisplayLanguage
    let launchAtLoginStatus: LaunchAtLoginStatus

    var canEnableLaunchAtLogin: Bool {
        launchAtLoginStatus.canEnable
    }

    var canDisableLaunchAtLogin: Bool {
        launchAtLoginStatus.canDisable
    }

    var canOpenLaunchAtLoginSettings: Bool {
        launchAtLoginStatus.canOpenSettings
    }
}

@MainActor
final class AppSettingsViewModel: ObservableObject {
    @Published private(set) var state: AppSettingsViewState

    private let settingsStore: DockHoverPreviewSettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let logger: ProbeLogger
    private var observerToken: UUID?

    init(
        settingsStore: DockHoverPreviewSettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        logger: ProbeLogger
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginService = launchAtLoginService
        self.logger = logger
        self.state = Self.makeState(
            snapshot: settingsStore.snapshot,
            launchAtLoginStatus: launchAtLoginService.status
        )

        observerToken = settingsStore.addObserver { [weak self] snapshot in
            self?.refresh(snapshot: snapshot)
        }
    }

    func refresh() {
        refresh(snapshot: settingsStore.snapshot)
    }

    func setDisplayLanguage(_ language: DisplayLanguage) {
        settingsStore.update { settings in
            settings.displayLanguage = language
        }
    }

    func enableLaunchAtLogin() {
        guard launchAtLoginService.status.canEnable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.enable()
        } catch {
            logger.error("launchAtLogin.enableFailed error=\(error)")
        }
        refresh()
    }

    func disableLaunchAtLogin() {
        guard launchAtLoginService.status.canDisable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.disable()
        } catch {
            logger.error("launchAtLogin.disableFailed error=\(error)")
        }
        refresh()
    }

    func openLaunchAtLoginSettings() {
        guard launchAtLoginService.status.canOpenSettings else {
            refresh()
            return
        }

        launchAtLoginService.openSettings()
        refresh()
    }

    private func refresh(snapshot: DockHoverPreviewSettings) {
        state = Self.makeState(
            snapshot: snapshot,
            launchAtLoginStatus: launchAtLoginService.status
        )
    }

    private static func makeState(
        snapshot: DockHoverPreviewSettings,
        launchAtLoginStatus: LaunchAtLoginStatus
    ) -> AppSettingsViewState {
        AppSettingsViewState(
            displayLanguage: snapshot.displayLanguage,
            launchAtLoginStatus: launchAtLoginStatus
        )
    }
}

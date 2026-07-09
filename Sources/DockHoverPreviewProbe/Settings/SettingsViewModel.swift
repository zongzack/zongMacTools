import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let appSettings: AppSettingsViewModel
    let dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel

    private var cancellables: Set<AnyCancellable> = []

    var displayLanguage: DisplayLanguage {
        appSettings.state.displayLanguage
    }

    init(
        appSettings: AppSettingsViewModel,
        dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel
    ) {
        self.appSettings = appSettings
        self.dockWindowQuickLookSettings = dockWindowQuickLookSettings

        appSettings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        dockWindowQuickLookSettings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    func refreshForSettingsPresentation() {
        appSettings.refresh()
        dockWindowQuickLookSettings.refreshForSettingsPresentation()
    }
}

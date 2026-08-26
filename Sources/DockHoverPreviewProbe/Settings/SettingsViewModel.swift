import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let appSettings: AppSettingsViewModel
    let dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel
    let finderExtensionSettings: FinderExtensionSettingsViewModel

    private var cancellables: Set<AnyCancellable> = []

    var displayLanguage: DisplayLanguage {
        appSettings.state.displayLanguage
    }

    init(
        appSettings: AppSettingsViewModel,
        dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel,
        finderExtensionSettings: FinderExtensionSettingsViewModel = FinderExtensionSettingsViewModel()
    ) {
        self.appSettings = appSettings
        self.dockWindowQuickLookSettings = dockWindowQuickLookSettings
        self.finderExtensionSettings = finderExtensionSettings

        bind(appSettings.objectWillChange)
        bind(dockWindowQuickLookSettings.objectWillChange)
        bind(finderExtensionSettings.objectWillChange)
    }

    func refreshForSettingsPresentation() {
        appSettings.refresh()
        dockWindowQuickLookSettings.refreshForSettingsPresentation()
        finderExtensionSettings.refresh()
    }

    private func bind<P: Publisher>(_ publisher: P)
    where P.Output == Void, P.Failure == Never {
        publisher
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
}

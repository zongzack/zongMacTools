import FinderSync
import Foundation

@MainActor
protocol FinderExtensionStatusProviding: AnyObject {
    var isEnabled: Bool { get }
}

@MainActor
protocol FinderExtensionManagementPresenting: AnyObject {
    func showManagementInterface()
}

@MainActor
final class SystemFinderExtensionStatusProvider: FinderExtensionStatusProviding {
    var isEnabled: Bool { FIFinderSyncController.isExtensionEnabled }
}

@MainActor
final class SystemFinderExtensionManager: FinderExtensionManagementPresenting {
    func showManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

struct FinderExtensionSettingsViewState: Equatable {
    let isEnabled: Bool
}

@MainActor
final class FinderExtensionSettingsViewModel: ObservableObject {
    @Published private(set) var state: FinderExtensionSettingsViewState

    private let statusProvider: FinderExtensionStatusProviding
    private let managementPresenter: FinderExtensionManagementPresenting

    init(
        statusProvider: FinderExtensionStatusProviding = SystemFinderExtensionStatusProvider(),
        managementPresenter: FinderExtensionManagementPresenting = SystemFinderExtensionManager()
    ) {
        self.statusProvider = statusProvider
        self.managementPresenter = managementPresenter
        self.state = FinderExtensionSettingsViewState(isEnabled: statusProvider.isEnabled)
    }

    func refresh() {
        state = FinderExtensionSettingsViewState(isEnabled: statusProvider.isEnabled)
    }

    func openManagementInterface() {
        managementPresenter.showManagementInterface()
        refresh()
    }
}

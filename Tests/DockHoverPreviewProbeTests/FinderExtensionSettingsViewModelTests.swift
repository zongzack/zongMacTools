import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class FinderExtensionSettingsViewModelTests: XCTestCase {
    func testRefreshPublishesCurrentSystemStatus() {
        let status = FakeFinderExtensionStatusProvider(isEnabled: false)
        let presenter = FakeFinderExtensionManagementPresenter()
        let viewModel = FinderExtensionSettingsViewModel(statusProvider: status, managementPresenter: presenter)

        XCTAssertFalse(viewModel.state.isEnabled)
        status.isEnabled = true
        viewModel.refresh()
        XCTAssertTrue(viewModel.state.isEnabled)
    }

    func testManagementButtonOnlyOpensPublicManagementPresenterAndRefreshesStatus() {
        let status = FakeFinderExtensionStatusProvider(isEnabled: false)
        let presenter = FakeFinderExtensionManagementPresenter {
            status.isEnabled = true
        }
        let viewModel = FinderExtensionSettingsViewModel(statusProvider: status, managementPresenter: presenter)

        viewModel.openManagementInterface()

        XCTAssertEqual(presenter.openCount, 1)
        XCTAssertTrue(viewModel.state.isEnabled)
    }
}

@MainActor
private final class FakeFinderExtensionStatusProvider: FinderExtensionStatusProviding {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

@MainActor
private final class FakeFinderExtensionManagementPresenter: FinderExtensionManagementPresenting {
    private let action: () -> Void
    private(set) var openCount = 0

    init(action: @escaping () -> Void = {}) {
        self.action = action
    }

    func showManagementInterface() {
        openCount += 1
        action()
    }
}

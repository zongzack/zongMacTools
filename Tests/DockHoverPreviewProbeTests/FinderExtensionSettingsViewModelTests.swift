import XCTest
import FinderNewFileCore
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

    func testBuiltInCatalogLoadsAndTogglePersistsEvenWhenExtensionIsDisabled() {
        let status = FakeFinderExtensionStatusProvider(isEnabled: false)
        let store = InMemoryCatalogStore()
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: status,
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )

        XCTAssertEqual(viewModel.state.items.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))
        XCTAssertTrue(viewModel.setItemEnabled(false, for: FinderNewFileFormat.json.stableID))
        XCTAssertFalse(viewModel.state.items.first(where: { $0.builtInFormat == .json })!.isEnabled)
        XCTAssertFalse(store.savedCatalog!.item(withID: FinderNewFileFormat.json.stableID)!.isEnabled)
    }

    func testRenameRejectsEmptyAndIllegalNamesButAllowsDuplicateValidNames() {
        let store = InMemoryCatalogStore()
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: FakeFinderExtensionStatusProvider(isEnabled: false),
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )
        let txtID = FinderNewFileFormat.txt.stableID
        let markdownID = FinderNewFileFormat.markdown.stableID

        XCTAssertFalse(viewModel.updateDisplayName("   ", for: txtID))
        XCTAssertFalse(viewModel.updateDisplayName("bad/name", for: txtID))
        XCTAssertNil(store.savedCatalog)
        XCTAssertTrue(viewModel.updateDisplayName("Notes", for: txtID))
        XCTAssertTrue(viewModel.updateDisplayName("Notes", for: markdownID))
        XCTAssertEqual(viewModel.state.items.filter { $0.displayName == "Notes" }.count, 2)
    }

    func testBuiltInExtensionIsLockedAndMovePersistsOrder() {
        let store = InMemoryCatalogStore()
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: FakeFinderExtensionStatusProvider(isEnabled: false),
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )

        XCTAssertEqual(viewModel.state.items.first(where: { $0.id == FinderNewFileFormat.txt.stableID })?.fileExtension, "txt")
        XCTAssertTrue(viewModel.moveItem(withID: FinderNewFileFormat.powerpoint.stableID, beforeID: FinderNewFileFormat.txt.stableID))
        XCTAssertEqual(viewModel.state.items.map(\.builtInFormat), [.powerpoint, .txt, .markdown, .json, .word, .excel])
        XCTAssertEqual(store.savedCatalog!.orderedItems.map(\.sortOrder), Array(0..<6))
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

private final class InMemoryCatalogStore: FinderNewFileCatalogStoring {
    private(set) var savedCatalog: FinderNewFileCatalog?
    private var catalog: FinderNewFileCatalog

    init(catalog: FinderNewFileCatalog = .defaultCatalog(templateDirectoryURL: URL(fileURLWithPath: "/tmp/finder-templates", isDirectory: true))) {
        self.catalog = catalog
    }

    func loadCatalog() -> FinderNewFileCatalog { catalog }

    func saveCatalog(_ catalog: FinderNewFileCatalog) throws {
        self.catalog = catalog
        savedCatalog = catalog
    }
}

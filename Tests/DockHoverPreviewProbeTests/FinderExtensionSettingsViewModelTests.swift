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

    func testBatchImportSkipsExtensionlessFilesAndKeepsIndependentCopies() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let templates = root.appendingPathComponent("Templates", isDirectory: true)
        let sourceA = root.appendingPathComponent("Note.md")
        let sourceB = root.appendingPathComponent("Other.MD")
        let noExtension = root.appendingPathComponent("README")
        try Data("A".utf8).write(to: sourceA)
        try Data("B".utf8).write(to: sourceB)
        try Data("skip".utf8).write(to: noExtension)

        let store = InMemoryCatalogStore(catalog: .defaultCatalog(templateDirectoryURL: templates))
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: FakeFinderExtensionStatusProvider(isEnabled: false),
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )

        let result = viewModel.importTemplates(from: [sourceA, sourceB, noExtension])

        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.failures.map(\.fileName), ["README"])
        let custom = viewModel.state.items.filter { $0.source == .custom }
        XCTAssertEqual(custom.map(\.displayName), ["Note", "Other"])
        XCTAssertEqual(custom.map(\.fileExtension), ["md", "md"])
        XCTAssertEqual(Set(custom.map(\.id)).count, 2)
        XCTAssertTrue(custom.allSatisfy { $0.isEnabled })
        for item in custom {
            let reference = try XCTUnwrap(item.templateReference?.relativePath)
            XCTAssertEqual(try Data(contentsOf: templates.appendingPathComponent(reference)), item.displayName == "Note" ? Data("A".utf8) : Data("B".utf8))
        }
    }

    func testDuplicateImportCreatesIndependentStableItemsAndMissingFileIsSummarized() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Template.txt")
        try Data("bytes".utf8).write(to: source)
        let missing = root.appendingPathComponent("missing.txt")
        let templates = root.appendingPathComponent("Templates", isDirectory: true)
        let store = InMemoryCatalogStore(catalog: .defaultCatalog(templateDirectoryURL: templates))
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: FakeFinderExtensionStatusProvider(isEnabled: true),
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )

        let result = viewModel.importTemplates(from: [source, source, missing])

        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.failures.map(\.fileName), ["missing.txt"])
        let custom = viewModel.state.items.filter { $0.source == .custom }
        XCTAssertEqual(custom.count, 2)
        XCTAssertNotEqual(custom[0].id, custom[1].id)
        XCTAssertNotEqual(custom[0].templateReference?.relativePath, custom[1].templateReference?.relativePath)
    }

    func testCustomExtensionValidationDeleteAndRestoreDefaultsCleanCopies() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let templates = root.appendingPathComponent("Templates", isDirectory: true)
        let source = root.appendingPathComponent("Plan.txt")
        try Data("plan".utf8).write(to: source)
        let store = InMemoryCatalogStore(catalog: .defaultCatalog(templateDirectoryURL: templates))
        let viewModel = FinderExtensionSettingsViewModel(
            statusProvider: FakeFinderExtensionStatusProvider(isEnabled: false),
            managementPresenter: FakeFinderExtensionManagementPresenter(),
            catalogStore: store
        )

        let imported = viewModel.importTemplates(from: [source]).importedItemIDs
        let itemID = try XCTUnwrap(imported.first)
        XCTAssertFalse(viewModel.updateFileExtension("bad/name", for: itemID))
        XCTAssertTrue(viewModel.updateFileExtension("md", for: itemID))
        let reference = try XCTUnwrap(viewModel.state.catalog.item(withID: itemID)?.templateReference?.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: templates.appendingPathComponent(reference).path))
        XCTAssertFalse(viewModel.deleteCustomItem(withID: itemID, confirmed: false))
        XCTAssertTrue(viewModel.deleteCustomItem(withID: itemID, confirmed: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: templates.appendingPathComponent(reference).path))

        let second = viewModel.importTemplates(from: [source]).importedItemIDs
        XCTAssertEqual(second.count, 1)
        let secondReference = try XCTUnwrap(viewModel.state.catalog.item(withID: second[0])?.templateReference?.relativePath)
        XCTAssertTrue(viewModel.restoreDefaults(confirmed: false) == false)
        XCTAssertTrue(viewModel.restoreDefaults(confirmed: true))
        XCTAssertEqual(viewModel.state.items.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))
        XCTAssertTrue(viewModel.state.items.allSatisfy(\.isEnabled))
        XCTAssertFalse(FileManager.default.fileExists(atPath: templates.appendingPathComponent(secondReference).path))
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("finder-settings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
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

import Foundation
import XCTest
import FinderNewFileCore
@testable import DockHoverPreviewProbe

final class FinderMenuCoordinatorTests: XCTestCase {
    func testOnlyValidContainerBackgroundProducesNewFileEntry() throws {
        let validator = RecordingDirectoryValidator(validURLs: [URL(fileURLWithPath: "/Users/test/Desktop")])
        let coordinator = FinderMenuCoordinator(directoryValidator: validator, title: "New File")

        let plan = coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: URL(fileURLWithPath: "/Users/test/Desktop"),
            selectedURLs: []
        ))

        XCTAssertEqual(plan, [FinderMenuItemPlan(
            identifier: FinderMenuCoordinator.newFileIdentifier,
            title: "New File",
            isEnabled: false
        )])
        XCTAssertEqual(validator.checkedURLs, [URL(fileURLWithPath: "/Users/test/Desktop")])
    }

    func testItemsSidebarToolbarVirtualAndSelectedContainerContextsAreEmpty() {
        let validator = RecordingDirectoryValidator(validURLs: [URL(fileURLWithPath: "/tmp")])
        let coordinator = FinderMenuCoordinator(directoryValidator: validator)
        let url = URL(fileURLWithPath: "/tmp")

        for kind in [
            FinderMenuKind.contextualMenuForItems,
            .contextualMenuForSidebar,
            .toolbarItemMenu
        ] {
            XCTAssertTrue(coordinator.menuPlan(for: FinderMenuRequest(kind: kind, targetedURL: url)).isEmpty)
        }
        XCTAssertTrue(coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: url,
            selectedURLs: [URL(fileURLWithPath: "/tmp/file.txt")]
        )).isEmpty)
        XCTAssertTrue(coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: nil
        )).isEmpty)
        XCTAssertTrue(validator.checkedURLs.isEmpty)
    }

    func testContainerURLInSelectedURLsIsTreatedAsEmptySelection() {
        // Real Finder behavior: for the window-background menu,
        // selectedItemURLs() reports the container URL itself. The menu must
        // still appear because that is not a genuine item selection.
        let directory = URL(fileURLWithPath: "/tmp/container")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let coordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: RecordingPublisher(), isSimplifiedChinese: { true })

        let plan = coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: directory,
            selectedURLs: [directory]
        ))
        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(plan.map(\.format), [.txt, .markdown, .json, .word, .excel, .powerpoint])
        XCTAssertEqual(plan.map(\.identifier), FinderNewFileFormat.allCases.map(\.stableID))

        // A genuine item selection still suppresses the menu.
        let selectedItem = directory.appendingPathComponent("file.txt")
        XCTAssertTrue(coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: directory,
            selectedURLs: [directory, selectedItem]
        )).isEmpty)
    }

    func testNewFileMenuContainsLocalizedFormatsAndCreationUsesFrozenDirectory() {
        let directory = URL(fileURLWithPath: "/tmp/frozen")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let coordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: RecordingPublisher(), isSimplifiedChinese: { true })
        let plan = coordinator.menuPlan(for: FinderMenuRequest(kind: .contextualMenuForContainer, targetedURL: directory, selectedURLs: []))
        XCTAssertEqual(plan.map(\.format), [.txt, .markdown, .json, .word, .excel, .powerpoint])
        XCTAssertEqual(plan.map(\.identifier), FinderNewFileFormat.allCases.map(\.stableID))
        XCTAssertEqual(plan.map(\.fileExtension), ["txt", "md", "json", "docx", "xlsx", "pptx"])
        XCTAssertEqual(plan.map(\.title), ["TXT", "Markdown", "JSON", "Word", "Excel", "PowerPoint"])
        XCTAssertTrue(plan.allSatisfy(\.isEnabled))

        let englishCoordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: RecordingPublisher(), isSimplifiedChinese: { false })
        XCTAssertEqual(
            englishCoordinator.menuPlan(for: FinderMenuRequest(kind: .contextualMenuForContainer, targetedURL: directory, selectedURLs: [])).map(\.title),
            ["TXT File", "Markdown File", "JSON File", "Word File", "Excel File", "PowerPoint File"]
        )

        let publisher = RecordingPublisher()
        let selector = RecordingSelector()
        let actionCoordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: publisher, selector: selector, isSimplifiedChinese: { false })
        let result = actionCoordinator.create(format: .json, in: directory)
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(publisher.directories, [directory])
        XCTAssertEqual(publisher.data, [Data("{}\n".utf8)])
        XCTAssertEqual(publisher.fileNames, ["New Document.json"])
        XCTAssertEqual(selector.urls, [directory.appendingPathComponent("New Document.json")])
    }

    func testMenuPlanConsumesOrderedCatalogAndFiltersDisabledItems() {
        let directory = URL(fileURLWithPath: "/tmp/catalog")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let catalog = FinderNewFileCatalog(
            items: [
                FinderNewFileCatalogItem(
                    id: FinderNewFileFormat.json.stableID,
                    source: .builtIn,
                    builtInFormat: .json,
                    displayName: "JSON",
                    fileExtension: "json",
                    isEnabled: false,
                    sortOrder: 0
                ),
                FinderNewFileCatalogItem(
                    id: "custom.alpha",
                    source: .custom,
                    displayName: "Project Note",
                    fileExtension: "txt",
                    isEnabled: true,
                    sortOrder: 1,
                    templateReference: FinderNewFileTemplateReference(relativePath: "alpha.template")
                ),
                FinderNewFileCatalogItem(
                    id: FinderNewFileFormat.markdown.stableID,
                    source: .builtIn,
                    builtInFormat: .markdown,
                    displayName: "Project Note",
                    fileExtension: "md",
                    isEnabled: true,
                    sortOrder: 2
                )
            ],
            templateDirectoryURL: URL(fileURLWithPath: "/tmp/catalog-templates", isDirectory: true)
        )
        let coordinator = FinderNewFileCoordinator(
            directoryValidator: validator,
            publisher: RecordingPublisher(),
            catalogProvider: StaticCatalogProvider(catalog: catalog),
            isSimplifiedChinese: { false }
        )

        let plan = coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: directory,
            selectedURLs: []
        ))

        XCTAssertEqual(plan.map(\.identifier), ["custom.alpha", FinderNewFileFormat.markdown.stableID])
        XCTAssertEqual(plan.map(\.title), ["Project Note", "Project Note"])
        XCTAssertEqual(plan.map(\.format), [nil, .markdown])
        XCTAssertEqual(plan.map(\.fileExtension), ["txt", "md"])
    }

    func testEmptyEnabledCatalogHidesTheMenuEntry() {
        let directory = URL(fileURLWithPath: "/tmp/catalog")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let catalog = FinderNewFileCatalog(
            items: FinderNewFileCatalog.defaultCatalog().items.map {
                var item = $0
                item.isEnabled = false
                return item
            }
        )
        let coordinator = FinderNewFileCoordinator(
            directoryValidator: validator,
            publisher: RecordingPublisher(),
            catalogProvider: StaticCatalogProvider(catalog: catalog)
        )

        XCTAssertTrue(coordinator.menuPlan(for: FinderMenuRequest(
            kind: .contextualMenuForContainer,
            targetedURL: directory,
            selectedURLs: []
        )).isEmpty)
    }

    func testCreateByStableIDUsesConfiguredItemInsteadOfDisplayNameOrLanguage() throws {
        let directory = URL(fileURLWithPath: "/tmp/stable-id")
        let templateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("finder-new-file-templates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: templateDirectory) }
        try Data("custom bytes".utf8).write(to: templateDirectory.appendingPathComponent("template.bin"))

        let catalog = FinderNewFileCatalog(
            items: [
                FinderNewFileCatalogItem(
                    id: FinderNewFileFormat.json.stableID,
                    source: .builtIn,
                    builtInFormat: .json,
                    displayName: "Same Name",
                    fileExtension: "json",
                    isEnabled: true,
                    sortOrder: 0
                ),
                FinderNewFileCatalogItem(
                    id: "custom.same-name",
                    source: .custom,
                    displayName: "Same Name",
                    fileExtension: "txt",
                    isEnabled: true,
                    sortOrder: 1,
                    templateReference: FinderNewFileTemplateReference(relativePath: "template.bin")
                )
            ],
            templateDirectoryURL: templateDirectory
        )
        let publisher = RecordingPublisher()
        let selector = RecordingSelector()
        let coordinator = FinderNewFileCoordinator(
            directoryValidator: RecordingDirectoryValidator(validURLs: [directory]),
            publisher: publisher,
            selector: selector,
            catalogProvider: StaticCatalogProvider(catalog: catalog),
            isSimplifiedChinese: { false }
        )

        XCTAssertTrue(coordinator.create(itemID: "custom.same-name", in: directory).isSuccess)
        XCTAssertTrue(coordinator.create(itemID: FinderNewFileFormat.json.stableID, in: directory).isSuccess)

        XCTAssertEqual(publisher.fileNames, ["Same Name.txt", "New Document.json"])
        XCTAssertEqual(publisher.data, [Data("custom bytes".utf8), Data("{}\n".utf8)])
        XCTAssertEqual(selector.urls, [
            directory.appendingPathComponent("Same Name.txt"),
            directory.appendingPathComponent("New Document.json")
        ])
    }

    func testCustomTemplateCreationUsesDisplayNameExtensionAndConflictIncrementing() throws {
        let directory = URL(fileURLWithPath: "/tmp/custom-template")
        let templateDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("finder-new-file-templates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: templateDirectory) }
        try Data("# Template\n".utf8).write(to: templateDirectory.appendingPathComponent("note.md"))

        let catalog = FinderNewFileCatalog(
            items: [
                FinderNewFileCatalogItem(
                    id: "custom.note",
                    source: .custom,
                    displayName: "Project Note",
                    fileExtension: "md",
                    isEnabled: true,
                    sortOrder: 0,
                    templateReference: FinderNewFileTemplateReference(relativePath: "note.md")
                )
            ],
            templateDirectoryURL: templateDirectory
        )
        let publisher = RecordingPublisher(occupied: ["Project Note.md"])
        let selector = RecordingSelector()
        let coordinator = FinderNewFileCoordinator(
            directoryValidator: RecordingDirectoryValidator(validURLs: [directory]),
            publisher: publisher,
            selector: selector,
            catalogProvider: StaticCatalogProvider(catalog: catalog),
            isSimplifiedChinese: { false }
        )

        XCTAssertTrue(coordinator.create(itemID: "custom.note", in: directory).isSuccess)

        XCTAssertEqual(publisher.fileNames, ["Project Note.md", "Project Note 2.md"])
        XCTAssertEqual(publisher.data, [Data("# Template\n".utf8), Data("# Template\n".utf8)])
        XCTAssertEqual(selector.urls, [directory.appendingPathComponent("Project Note 2.md")])
    }

    func testUnknownStableIDPresentsUnavailableItemError() {
        let directory = URL(fileURLWithPath: "/tmp/unknown")
        let publisher = RecordingPublisher()
        let errors = RecordingErrors()
        let coordinator = FinderNewFileCoordinator(
            directoryValidator: RecordingDirectoryValidator(validURLs: [directory]),
            publisher: publisher,
            errorPresenter: errors,
            catalogProvider: StaticCatalogProvider(catalog: .defaultCatalog())
        )

        XCTAssertEqual(coordinator.create(itemID: "custom.missing", in: directory).error, .itemUnavailable("custom.missing"))
        XCTAssertTrue(publisher.fileNames.isEmpty)
        XCTAssertEqual(errors.errors, [.itemUnavailable("custom.missing")])
    }

    func testOfficeTemplatesAreEmbeddedAndFormatSpecific() throws {
        for format in [FinderNewFileFormat.word, .excel, .powerpoint] {
            let data = try format.contentData()
            XCTAssertGreaterThan(data.count, 100)
            XCTAssertEqual(Array(data.prefix(2)), [0x50, 0x4b])
        }
        XCTAssertTrue(try FinderNewFileFormat.excel.contentData().count > FinderNewFileFormat.word.contentData().count)
    }

    func testNameConflictsAdvanceAndExhaustionPresentsOneError() {
        let directory = URL(fileURLWithPath: "/tmp/frozen")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let publisher = RecordingPublisher(occupied: Set(["New Document.txt", "New Document 2.txt"]))
        let selector = RecordingSelector(); let errors = RecordingErrors()
        let coordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: publisher, selector: selector, errorPresenter: errors, isSimplifiedChinese: { false })
        XCTAssertTrue(coordinator.create(format: .txt, in: directory).isSuccess)
        XCTAssertEqual(publisher.fileNames, ["New Document.txt", "New Document 2.txt", "New Document 3.txt"])
        XCTAssertEqual(selector.urls.count, 1); XCTAssertTrue(errors.errors.isEmpty)

        let exhausted = RecordingPublisher(occupyAll: true)
        let exhaustedErrors = RecordingErrors()
        let exhaustedCoordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: exhausted, errorPresenter: exhaustedErrors, isSimplifiedChinese: { false })
        XCTAssertEqual(exhaustedCoordinator.create(format: .markdown, in: directory).error, .nameExhausted)
        XCTAssertEqual(exhausted.fileNames.count, 10_000)
        XCTAssertEqual(exhaustedErrors.errors, [.nameExhausted])
    }

    func testInvalidDirectoryFailsWithoutPublishing() {
        let publisher = RecordingPublisher(); let errors = RecordingErrors()
        let coordinator = FinderNewFileCoordinator(directoryValidator: RecordingDirectoryValidator(validURLs: []), publisher: publisher, errorPresenter: errors)
        XCTAssertEqual(coordinator.create(format: .txt, in: URL(fileURLWithPath: "/tmp/nope")).error, .invalidDirectory)
        XCTAssertTrue(publisher.fileNames.isEmpty); XCTAssertEqual(errors.errors, [.invalidDirectory])
    }

    func testSecurePublisherDoesNotOverwriteAndCleansTemporaryFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("finder-new-file-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let publisher = SecureAtomicFilePublisher()
        let existing = directory.appendingPathComponent("New Document.txt")
        try Data("keep".utf8).write(to: existing)
        XCTAssertThrowsError(try publisher.publish(data: Data(), directoryURL: directory, fileName: existing.lastPathComponent)) { error in
            XCTAssertEqual(error as? FinderFilePublishError, .nameOccupied)
        }
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep".utf8))
        let created = try publisher.publish(data: Data("hello".utf8), directoryURL: directory, fileName: "New Document 2.txt")
        XCTAssertEqual(try Data(contentsOf: created), Data("hello".utf8))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix(".zongMacTools.tmp.") }
        XCTAssertTrue(leftovers.isEmpty)
    }
}

private final class RecordingDirectoryValidator: FinderDirectoryValidating {
    let validURLs: Set<URL>
    private(set) var checkedURLs: [URL] = []

    init(validURLs: Set<URL>) {
        self.validURLs = validURLs
    }

    func isValidDirectory(_ url: URL) -> Bool {
        checkedURLs.append(url)
        return validURLs.contains(url)
    }
}

private final class RecordingPublisher: FinderFilePublishing {
    var fileNames: [String] = []; var directories: [URL] = []; var data: [Data] = []
    let occupied: Set<String>; let occupyAll: Bool
    init(occupied: Set<String> = [], occupyAll: Bool = false) { self.occupied = occupied; self.occupyAll = occupyAll }
    func publish(data: Data, directoryURL: URL, fileName: String) throws -> URL {
        fileNames.append(fileName); directories.append(directoryURL); self.data.append(data)
        if occupyAll || occupied.contains(fileName) { throw FinderFilePublishError.nameOccupied }
        return directoryURL.appendingPathComponent(fileName)
    }
}
private final class RecordingSelector: FinderFileSelecting { var urls: [URL] = []; func select(fileURL: URL) { urls.append(fileURL) } }
private final class RecordingErrors: FinderErrorPresenting { var errors: [FinderNewFileError] = []; func present(error: FinderNewFileError) { errors.append(error) } }

private struct StaticCatalogProvider: FinderNewFileCatalogProviding {
    let catalog: FinderNewFileCatalog

    func loadCatalog() -> FinderNewFileCatalog {
        catalog
    }
}

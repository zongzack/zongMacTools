import Foundation
import XCTest
@testable import FinderNewFileCore

final class FinderNewFileCatalogStoreTests: XCTestCase {
    func testDefaultCatalogContainsEnabledBuiltInItemsWithStableIDs() {
        let templateDirectory = URL(fileURLWithPath: "/tmp/templates", isDirectory: true)
        let catalog = FinderNewFileCatalog.defaultCatalog(templateDirectoryURL: templateDirectory)
        let items = catalog.orderedItems

        XCTAssertEqual(catalog.templateDirectoryURL, templateDirectory)
        XCTAssertEqual(items.map(\.id), [
            "builtin.txt",
            "builtin.markdown",
            "builtin.json",
            "builtin.word",
            "builtin.excel",
            "builtin.powerpoint"
        ])
        XCTAssertEqual(items.map(\.source), Array(repeating: .builtIn, count: 6))
        XCTAssertEqual(items.map(\.builtInFormat), [.txt, .markdown, .json, .word, .excel, .powerpoint])
        XCTAssertEqual(items.map(\.displayName), ["TXT", "Markdown", "JSON", "Word", "Excel", "PowerPoint"])
        XCTAssertEqual(items.map(\.fileExtension), ["txt", "md", "json", "docx", "xlsx", "pptx"])
        XCTAssertEqual(items.map(\.iconHint.fileExtension), ["txt", "md", "json", "docx", "xlsx", "pptx"])
        XCTAssertEqual(items.map(\.sortOrder), [0, 1, 2, 3, 4, 5])
        XCTAssertTrue(items.allSatisfy(\.isEnabled))
        XCTAssertTrue(items.allSatisfy { $0.templateReference == nil })
    }

    func testStoreWritesVersionedJSONAndSeparateStoreReadsLastConfiguration() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = root.appendingPathComponent("catalog.json")
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: true)
        try Data("custom".utf8).write(to: templateDirectory.appendingPathComponent("copy.bin"))

        let catalog = FinderNewFileCatalog(
            items: [
                FinderNewFileCatalogItem(
                    id: FinderNewFileFormat.markdown.stableID,
                    source: .builtIn,
                    builtInFormat: .markdown,
                    displayName: "Notes",
                    fileExtension: "md",
                    isEnabled: false,
                    sortOrder: 1
                ),
                FinderNewFileCatalogItem(
                    id: "custom.copy",
                    source: .custom,
                    displayName: "Copy",
                    fileExtension: "bin",
                    isEnabled: true,
                    sortOrder: 0,
                    templateReference: FinderNewFileTemplateReference(relativePath: "copy.bin")
                )
            ],
            templateDirectoryURL: templateDirectory
        )

        let writingStore = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)
        try writingStore.saveCatalog(catalog)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, 1)

        let readingStore = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)
        let loaded = readingStore.loadCatalog()

        XCTAssertEqual(loaded.orderedItems.map(\.id), ["custom.copy", FinderNewFileFormat.markdown.stableID])
        XCTAssertEqual(loaded.orderedItems.map(\.displayName), ["Copy", "Notes"])
        XCTAssertEqual(loaded.orderedItems.map(\.fileExtension), ["bin", "md"])
        XCTAssertEqual(loaded.orderedItems.map(\.templateReference?.relativePath), ["copy.bin", nil])
        XCTAssertEqual(loaded.templateDirectoryURL, templateDirectory)
    }

    func testMissingCorruptUnsupportedAndAllInvalidCatalogsFallBackToDefaults() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = root.appendingPathComponent("catalog.json")
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        let store = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)

        XCTAssertEqual(store.loadCatalog().orderedItems.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))

        try writeString("{", to: catalogURL)
        XCTAssertEqual(store.loadCatalog().orderedItems.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))

        try writeJSONObject(["version": 2, "items": []], to: catalogURL)
        XCTAssertEqual(store.loadCatalog().orderedItems.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))

        try writeJSONObject([
            "version": 1,
            "items": [
                [
                    "id": "",
                    "source": "custom",
                    "displayName": "Broken",
                    "fileExtension": "tar.gz",
                    "isEnabled": true,
                    "sortOrder": -1,
                    "iconHint": ["fileExtension": "tar.gz"],
                    "templateReference": ["relativePath": "../outside"]
                ]
            ]
        ], to: catalogURL)
        XCTAssertEqual(store.loadCatalog().orderedItems.map(\.id), FinderNewFileFormat.allCases.map(\.stableID))
    }

    func testInvalidEntriesAreDiscardedWhenAtLeastOneEntryIsValid() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = root.appendingPathComponent("catalog.json")
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: true)
        try Data("valid".utf8).write(to: templateDirectory.appendingPathComponent("valid.template"))
        let store = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)

        try writeJSONObject([
            "version": 1,
            "items": [
                [
                    "id": "custom.valid",
                    "source": "custom",
                    "displayName": "Valid",
                    "fileExtension": "TXT",
                    "isEnabled": true,
                    "sortOrder": 1,
                    "iconHint": ["fileExtension": "TXT"],
                    "templateReference": ["relativePath": "valid.template"]
                ],
                [
                    "id": "custom.valid",
                    "source": "custom",
                    "displayName": "Duplicate",
                    "fileExtension": "txt",
                    "isEnabled": true,
                    "sortOrder": 2,
                    "iconHint": ["fileExtension": "txt"],
                    "templateReference": ["relativePath": "valid.template"]
                ],
                [
                    "id": FinderNewFileFormat.word.stableID,
                    "source": "builtIn",
                    "builtInFormat": "word",
                    "displayName": "Word",
                    "fileExtension": "txt",
                    "isEnabled": true,
                    "sortOrder": 0,
                    "iconHint": ["fileExtension": "txt"]
                ]
            ]
        ], to: catalogURL)

        let loaded = store.loadCatalog()

        XCTAssertEqual(loaded.orderedItems.map(\.id), ["custom.valid"])
        XCTAssertEqual(loaded.orderedItems.first?.fileExtension, "txt")
        XCTAssertEqual(loaded.orderedItems.first?.iconHint.fileExtension, "txt")
    }

    func testSavingAllDisabledBuiltInsDoesNotTriggerDefaultFallback() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = root.appendingPathComponent("catalog.json")
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        let store = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)
        let catalog = FinderNewFileCatalog(
            items: FinderNewFileCatalog.defaultCatalog(templateDirectoryURL: templateDirectory).items.map {
                var item = $0
                item.isEnabled = false
                return item
            },
            templateDirectoryURL: templateDirectory
        )

        try store.saveCatalog(catalog)
        let loaded = store.loadCatalog()

        XCTAssertEqual(loaded.orderedItems.count, 6)
        XCTAssertFalse(loaded.orderedItems.contains(where: \.isEnabled))
    }

    func testFailedReplacementLeavesPreviousCatalogReadable() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = root.appendingPathComponent("catalog.json")
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        let normalStore = JSONFinderNewFileCatalogStore(catalogURL: catalogURL, templateDirectoryURL: templateDirectory)

        var previousItems = FinderNewFileCatalog.defaultCatalog(templateDirectoryURL: templateDirectory).items
        previousItems[0].displayName = "Before"
        try normalStore.saveCatalog(FinderNewFileCatalog(items: previousItems, templateDirectoryURL: templateDirectory))

        var nextItems = previousItems
        nextItems[0].displayName = "After"
        let failingStore = JSONFinderNewFileCatalogStore(
            catalogURL: catalogURL,
            templateDirectoryURL: templateDirectory,
            disk: ReplacementFailingCatalogDiskAccess()
        )

        XCTAssertThrowsError(try failingStore.saveCatalog(FinderNewFileCatalog(items: nextItems, templateDirectoryURL: templateDirectory)))
        XCTAssertEqual(normalStore.loadCatalog().item(withID: FinderNewFileFormat.txt.stableID)?.displayName, "Before")
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("finder-catalog-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func writeString(_ string: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(string.utf8).write(to: url)
    }

    private func writeJSONObject(_ object: Any, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}

private struct ReplacementFailingCatalogDiskAccess: FinderNewFileCatalogDiskAccess {
    private let local = LocalFinderNewFileCatalogDiskAccess()

    func readData(at url: URL) throws -> Data {
        try local.readData(at: url)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try local.writeData(data, to: url)
    }

    func createDirectory(at url: URL) throws {
        try local.createDirectory(at: url)
    }

    func fileExists(at url: URL) -> Bool {
        local.fileExists(at: url)
    }

    func regularFileExists(at url: URL) -> Bool {
        local.regularFileExists(at: url)
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        throw NSError(domain: "ReplacementFailingCatalogDiskAccess", code: 1)
    }

    func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL) throws {
        throw NSError(domain: "ReplacementFailingCatalogDiskAccess", code: 2)
    }

    func removeItem(at url: URL) throws {
        try local.removeItem(at: url)
    }
}

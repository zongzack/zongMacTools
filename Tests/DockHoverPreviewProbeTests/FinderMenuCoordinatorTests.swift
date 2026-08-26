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

    func testNewFileMenuContainsLocalizedFormatsAndCreationUsesFrozenDirectory() {
        let directory = URL(fileURLWithPath: "/tmp/frozen")
        let validator = RecordingDirectoryValidator(validURLs: [directory])
        let coordinator = FinderNewFileCoordinator(directoryValidator: validator, publisher: RecordingPublisher(), isSimplifiedChinese: { true })
        let plan = coordinator.menuPlan(for: FinderMenuRequest(kind: .contextualMenuForContainer, targetedURL: directory, selectedURLs: []))
        XCTAssertEqual(plan.map(\.format), [.txt, .markdown, .json, nil, .word, .excel, .powerpoint])
        XCTAssertEqual(plan.map(\.title), ["TXT 文件", "Markdown 文件", "JSON 文件", "", "Word 文件", "Excel 文件", "PowerPoint 文件"])
        XCTAssertEqual(plan[3].identifier, "\(FinderNewFileCoordinator.newFileIdentifier).separator")
        XCTAssertTrue(plan.filter { $0.format != nil }.allSatisfy(\.isEnabled))

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

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

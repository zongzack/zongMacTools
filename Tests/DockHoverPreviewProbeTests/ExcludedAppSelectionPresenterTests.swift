import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class ExcludedAppSelectionPresenterTests: XCTestCase {
    func testOpenPanelAllowsOnlySingleApplicationBundleAndResolvesSelection() throws {
        let appURL = try makeTemporaryAppBundle(
            bundleIdentifier: "com.example.Editor",
            displayName: "Example Editor",
            appBundleName: "Example Editor"
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
        let panel = FakeExcludedAppOpenPanel(response: .OK, url: appURL)
        let presenter = AppKitExcludedAppSelectionPresenter(openPanelFactory: { panel })

        let selection = presenter.selectAppToExclude(panelTitle: "Choose App to Exclude")

        XCTAssertEqual(panel.runModalCount, 1)
        XCTAssertEqual(panel.title, "Choose App to Exclude")
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canCreateDirectories)
        XCTAssertTrue(panel.resolvesAliases)
        XCTAssertEqual(panel.allowedContentTypes, [.applicationBundle])
        XCTAssertEqual(
            selection,
            ExcludedAppSelection(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
    }

    func testWorkspaceResolverPrefersLocalizedDisplayNameForExcludedApp() throws {
        let appURL = try makeTemporaryAppBundle(
            bundleIdentifier: "com.bot.neotix.doubao",
            displayName: "Doubao",
            localizedDisplayName: "豆包",
            appBundleName: "豆包"
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
        let resolver = WorkspaceAppNameResolver(applicationURLProvider: { _ in appURL })

        XCTAssertEqual(
            resolver.displayName(forBundleIdentifier: "com.bot.neotix.doubao"),
            "豆包"
        )
    }

    func testWorkspaceResolverPrefersApplicationDisplayNameOverBundleMetadata() throws {
        let appURL = try makeTemporaryAppBundle(
            bundleIdentifier: "com.bot.neotix.doubao",
            displayName: "Doubao",
            appBundleName: "豆包"
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
        let resolver = WorkspaceAppNameResolver(applicationURLProvider: { _ in appURL })

        XCTAssertEqual(
            resolver.displayName(forBundleIdentifier: "com.bot.neotix.doubao"),
            "豆包"
        )
    }

    func testWorkspaceResolverFallsBackToAppFilenameWhenBundleNamesAreBlankOrMissing() throws {
        let appURL = try makeTemporaryAppBundle(
            bundleIdentifier: "com.example.FilenameFallback",
            displayName: " \n ",
            bundleName: nil
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
        let resolver = WorkspaceAppNameResolver(applicationURLProvider: { _ in appURL })

        XCTAssertEqual(
            resolver.displayName(forBundleIdentifier: "com.example.FilenameFallback"),
            "Example"
        )
    }

    func testOpenPanelCancelReturnsNilSelection() throws {
        let appURL = try makeTemporaryAppBundle(
            bundleIdentifier: "com.example.Cancelled",
            displayName: "Cancelled"
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
        let panel = FakeExcludedAppOpenPanel(response: .cancel, url: appURL)
        let presenter = AppKitExcludedAppSelectionPresenter(openPanelFactory: { panel })

        XCTAssertNil(presenter.selectAppToExclude(panelTitle: "Choose App to Exclude"))
        XCTAssertEqual(panel.runModalCount, 1)
    }

    func testAppKitOpenPanelWrapperMapsConfigurationToNSOpenPanel() {
        let nsPanel = NSOpenPanel()
        let panel = AppKitExcludedAppOpenPanel(panel: nsPanel)

        panel.title = "Choose App to Exclude"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]

        XCTAssertEqual(nsPanel.title, "Choose App to Exclude")
        XCTAssertTrue(nsPanel.canChooseFiles)
        XCTAssertFalse(nsPanel.canChooseDirectories)
        XCTAssertFalse(nsPanel.allowsMultipleSelection)
        XCTAssertFalse(nsPanel.canCreateDirectories)
        XCTAssertTrue(nsPanel.resolvesAliases)
        XCTAssertEqual(nsPanel.allowedContentTypes, [.applicationBundle])
    }

    private func makeTemporaryAppBundle(
        bundleIdentifier: String,
        displayName: String?,
        bundleName: String? = "Fallback Name",
        localizedDisplayName: String? = nil,
        appBundleName: String = "Example",
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExcludedAppSelectionPresenterTests-\(UUID().uuidString)", isDirectory: true)
        let appURL = rootURL.appendingPathComponent("\(appBundleName).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        var info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleDevelopmentRegion": "en",
            "CFBundlePackageType": "APPL"
        ]
        if let displayName {
            info["CFBundleDisplayName"] = displayName
        }
        if let bundleName {
            info["CFBundleName"] = bundleName
        }
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))

        if let localizedDisplayName {
            let localizationURL = contentsURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("en.lproj", isDirectory: true)
            try FileManager.default.createDirectory(at: localizationURL, withIntermediateDirectories: true)
            let localizedInfo: [String: String] = ["CFBundleDisplayName": localizedDisplayName]
            let localizedData = try PropertyListSerialization.data(
                fromPropertyList: localizedInfo,
                format: .xml,
                options: 0
            )
            try localizedData.write(to: localizationURL.appendingPathComponent("InfoPlist.strings"))
        }

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: appURL.path),
            file: file,
            line: line
        )
        return appURL
    }
}

@MainActor
private final class FakeExcludedAppOpenPanel: ExcludedAppOpenPanelProviding {
    var title: String?
    var canChooseFiles = false
    var canChooseDirectories = true
    var allowsMultipleSelection = true
    var canCreateDirectories = true
    var resolvesAliases = false
    var allowedContentTypes: [UTType] = []
    let url: URL?
    let response: NSApplication.ModalResponse
    private(set) var runModalCount = 0

    init(response: NSApplication.ModalResponse, url: URL?) {
        self.response = response
        self.url = url
    }

    func runModal() -> NSApplication.ModalResponse {
        runModalCount += 1
        return response
    }
}

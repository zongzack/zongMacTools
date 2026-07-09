import AppKit
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testShowSettingsCreatesConfiguredWindowAndActivatesApp() throws {
        _ = NSApplication.shared
        closeSettingsWindows()
        defer { closeSettingsWindows() }
        let harness = SettingsWindowHarness()

        harness.controller.showSettings(selectedPage: .support)

        let window = try XCTUnwrap(harness.visibleSettingsWindows.first)
        XCTAssertEqual(harness.visibleSettingsWindows.count, 1)
        XCTAssertEqual(harness.selection.selectedPage, .support)
        XCTAssertEqual(harness.activationSpy.count, 1)
        XCTAssertEqual(window.title, "zongMacTools Settings")
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).width, 980, accuracy: 1)
        XCTAssertEqual(window.contentRect(forFrameRect: window.frame).height, 640, accuracy: 1)
    }

    func testRepeatedShowSettingsReusesExistingWindowAndUpdatesSelection() throws {
        _ = NSApplication.shared
        closeSettingsWindows()
        defer { closeSettingsWindows() }
        let harness = SettingsWindowHarness()

        harness.controller.showSettings(selectedPage: .general)
        let firstWindow = try XCTUnwrap(harness.visibleSettingsWindows.first)

        harness.controller.showSettings(selectedPage: .dockWindowQuickLook)

        let secondWindow = try XCTUnwrap(harness.visibleSettingsWindows.first)
        XCTAssertTrue(firstWindow === secondWindow)
        XCTAssertEqual(harness.visibleSettingsWindows.count, 1)
        XCTAssertEqual(harness.selection.selectedPage, .dockWindowQuickLook)
        XCTAssertEqual(harness.activationSpy.count, 2)
    }

    func testCloseThenReopenDoesNotLeaveMultipleVisibleWindows() throws {
        _ = NSApplication.shared
        closeSettingsWindows()
        defer { closeSettingsWindows() }
        let harness = SettingsWindowHarness()

        harness.controller.showSettings(selectedPage: .dockWindowQuickLook)
        let firstWindow = try XCTUnwrap(harness.visibleSettingsWindows.first)
        firstWindow.close()

        harness.controller.showSettings(selectedPage: .general)

        let reopenedWindow = try XCTUnwrap(harness.visibleSettingsWindows.first)
        XCTAssertTrue(firstWindow === reopenedWindow)
        XCTAssertEqual(harness.visibleSettingsWindows.count, 1)
        XCTAssertEqual(harness.selection.selectedPage, .general)
    }

    func testShowSettingsCanOpenEmbeddedAboutStatusPage() throws {
        _ = NSApplication.shared
        closeSettingsWindows()
        defer { closeSettingsWindows() }
        let harness = SettingsWindowHarness()

        harness.controller.showSettings(selectedPage: .aboutStatus)

        XCTAssertEqual(harness.selection.selectedPage, .aboutStatus)
        XCTAssertEqual(harness.visibleSettingsWindows.count, 1)
    }

    func testShowSettingsRefreshesCurrentExclusionTarget() {
        _ = NSApplication.shared
        closeSettingsWindows()
        defer { closeSettingsWindows() }
        let harness = SettingsWindowHarness()
        XCTAssertNil(harness.viewModel.dockWindowQuickLookSettings.state.currentExclusionTarget)

        harness.targetTracker.updateLatestHoveredDockApp(
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
        harness.controller.showSettings(selectedPage: .dockWindowQuickLook)

        XCTAssertEqual(
            harness.viewModel.dockWindowQuickLookSettings.state.currentExclusionTarget,
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
    }

    func testSettingsRootViewIsSplitIntoFocusedFiles() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectedFiles = [
            "Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift",
            "Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift",
            "Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift",
            "Sources/DockHoverPreviewProbe/Settings/GeneralSettingsView.swift",
            "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift",
            "Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift",
            "Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift"
        ]

        for relativePath in expectedFiles {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path),
                "\(relativePath) should exist"
            )
        }

        let rootSource = try settingsRootViewSource()
        for movedViewDeclaration in [
            "struct GeneralSettingsView",
            "struct DockWindowQuickLookSettingsView",
            "struct SupportSettingsView",
            "struct AboutStatusSettingsView",
            "struct SettingsGroup"
        ] {
            XCTAssertFalse(rootSource.contains(movedViewDeclaration))
        }
    }

    func testSettingsToolsUseDescriptorRegistryForSidebarNavigation() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let descriptorRelativePath = "Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift"
        let descriptorURL = packageRoot.appendingPathComponent(descriptorRelativePath)
        let descriptorExists = FileManager.default.fileExists(atPath: descriptorURL.path)

        XCTAssertTrue(
            descriptorExists,
            "\(descriptorRelativePath) should exist"
        )
        guard descriptorExists else {
            return
        }

        let descriptorSource = try source(at: descriptorRelativePath)
        XCTAssertTrue(descriptorSource.contains("enum ToolID"))
        XCTAssertTrue(descriptorSource.contains("case dockWindowQuickLook"))
        XCTAssertTrue(descriptorSource.contains("case contextMenuExtension"))
        XCTAssertTrue(descriptorSource.contains("struct ToolDescriptor"))

        let sidebarSource = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift")
        XCTAssertTrue(sidebarSource.contains("let tools: [ToolDescriptor]"))
        XCTAssertTrue(sidebarSource.contains("ForEach(tools)"))

        let rootSource = try settingsRootViewSource()
        let compactRootSource = rootSource.filter { !$0.isWhitespace }
        XCTAssertTrue(
            compactRootSource.contains("tools:[.dockWindowQuickLook,.contextMenuExtensionPlaceholder]")
        )

        let menuBarSource = try source(at: "Sources/DockHoverPreviewProbe/App/MenuBarController.swift")
        XCTAssertFalse(menuBarSource.contains("ToolDescriptor"))
    }

    func testSettingsGroupsUseStableHoverSurfacesWithoutScale() throws {
        let source = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift")

        XCTAssertTrue(source.contains("SettingsGroupVisualStyle"))
        XCTAssertTrue(source.contains("hoverBackgroundColor"))
        XCTAssertTrue(source.contains("Color(nsColor: .systemGray)"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertTrue(source.contains(".animation(.easeOut"))
        XCTAssertFalse(source.contains("scaleEffect(isHovering ? SettingsGroupVisualStyle.hoverScale : 1)"))
        XCTAssertFalse(source.contains("SettingsGroupVisualStyle.hoverScale"))
        XCTAssertFalse(source.contains("controlBackgroundColor"))
        XCTAssertFalse(source.contains(".background(.regularMaterial)"))
    }

    func testSettingsRootViewEmbedsAboutStatusPageAndUsesThinDetailScrollbars() throws {
        let rootSource = try settingsRootViewSource()
        let sidebarSource = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift")
        let pageContainerSource = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift")
        let aboutSource = try source(at: "Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift")
        let dockSettingsSource = try source(
            at: "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift"
        )

        XCTAssertTrue(sidebarSource.contains("selection.selectedPage == .aboutStatus"))
        XCTAssertTrue(sidebarSource.contains("systemImage: \"info.circle\""))
        XCTAssertTrue(rootSource.contains("case .aboutStatus:"))
        XCTAssertTrue(rootSource.contains("AboutStatusSettingsView("))
        XCTAssertTrue(aboutSource.contains("AppStatusProviding"))
        XCTAssertTrue(aboutSource.contains("statusProvider.snapshot()"))
        XCTAssertTrue(aboutSource.contains("NSPasteboard.general.setString"))
        XCTAssertTrue(pageContainerSource.contains("SettingsScrollBarTuner"))
        XCTAssertTrue(pageContainerSource.contains("static let controlSize: NSControl.ControlSize = .mini"))
        XCTAssertTrue(pageContainerSource.contains(".background(SettingsScrollBarTuner())"))
        XCTAssertTrue(dockSettingsSource.contains("text.string(.removeExcludedAppHelp)"))
        XCTAssertFalse(dockSettingsSource.contains("\"Remove excluded app\""))
    }

    func testExcludedAppsHeaderHasAddButtonWiredToViewModelIntent() throws {
        let source = try source(
            at: "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift"
        )

        XCTAssertTrue(source.contains("Button(text.string(.addExcludedApp))"))
        XCTAssertTrue(source.contains("viewModel.addExcludedAppFromSelection()"))
        XCTAssertTrue(source.contains("Button(text.string(.clearAll))"))
        XCTAssertTrue(source.contains(".disabled(viewModel.state.excludedApps.isEmpty)"))
    }

    private func closeSettingsWindows() {
        for window in NSApplication.shared.windows
            where window.identifier == SettingsWindowController.windowIdentifier {
            window.close()
        }
    }

    private func settingsRootViewSource() throws -> String {
        try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift")
    }

    private func source(at relativePath: String) throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

@MainActor
private final class SettingsWindowHarness {
    let selection = SettingsWindowSelection()
    let activationSpy = ActivationSpy()
    let permissionService = FakePermissionService()
    let diagnosticExportPresenter = FakeDiagnosticExportPresenter()
    let appStatusProvider = FakeAppStatusProvider()
    let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
    let viewModel: SettingsViewModel
    let controller: SettingsWindowController

    init() {
        let settingsStore = FakeSettingsStore(snapshot: .defaults)
        let appSettings = AppSettingsViewModel(
            settingsStore: settingsStore,
            launchAtLoginService: FakeLaunchAtLoginService(),
            logger: ProbeLogger()
        )
        let dockWindowQuickLookSettings = DockWindowQuickLookSettingsViewModel(
            settingsStore: settingsStore,
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )
        viewModel = SettingsViewModel(
            appSettings: appSettings,
            dockWindowQuickLookSettings: dockWindowQuickLookSettings
        )
        controller = SettingsWindowController(
            settingsViewModel: viewModel,
            permissionService: permissionService,
            appStatusProvider: appStatusProvider,
            diagnosticExportPresenter: diagnosticExportPresenter,
            selection: selection,
            appActivator: activationSpy.activate
        )
    }

    var visibleSettingsWindows: [NSWindow] {
        NSApplication.shared.windows.filter {
            $0.identifier == SettingsWindowController.windowIdentifier && $0.isVisible
        }
    }
}

@MainActor
private final class ActivationSpy {
    private(set) var count = 0

    func activate() {
        count += 1
    }
}

private final class FakePermissionService: PermissionService {
    var currentState = PermissionState(accessibilityGranted: true, screenRecordingGranted: true)

    func refresh() -> PermissionState {
        currentState
    }

    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class FakeSettingsStore: DockHoverPreviewSettingsStore {
    private var observers: [UUID: @MainActor (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var snapshot: DockHoverPreviewSettings

    init(snapshot: DockHoverPreviewSettings) {
        self.snapshot = snapshot
    }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(transform: (inout DockHoverPreviewSettings) -> Void) {
        transform(&snapshot)
        observers.values.forEach { $0(snapshot) }
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus

    init(status: LaunchAtLoginStatus = .notRegistered) {
        self.status = status
    }

    func enable() throws {
        status = .enabled
    }

    func disable() throws {
        status = .notRegistered
    }

    func openSettings() {}
}

@MainActor
private final class FakeAppStatusProvider: AppStatusProviding {
    func snapshot() -> AppStatusSnapshot {
        AppStatusSnapshot(
            metadata: AppMetadata(
                appName: "zongMacTools",
                version: "0.1.0",
                buildNumber: "1",
                bundleIdentifier: "com.zong.zongMacTools",
                bundlePath: "/tmp/zongMacTools.app",
                executableName: "DockHoverPreviewProbe",
                signingStatus: .adHoc
            ),
            permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: false),
            launchAtLoginStatus: .notRegistered,
            settings: .defaults
        )
    }
}

@MainActor
private final class FakeDiagnosticExportPresenter: DiagnosticExportPresenting {
    func exportDiagnostics() {}
}

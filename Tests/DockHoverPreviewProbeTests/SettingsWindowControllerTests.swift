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
        XCTAssertNil(harness.viewModel.state.currentExclusionTarget)

        harness.targetTracker.updateLatestHoveredDockApp(
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
        harness.controller.showSettings(selectedPage: .dockWindowQuickLook)

        XCTAssertEqual(
            harness.viewModel.state.currentExclusionTarget,
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
    }

    func testSettingsGroupsUseLighterHoverAnimatedSurfaces() throws {
        let source = try settingsRootViewSource()

        XCTAssertTrue(source.contains("SettingsGroupVisualStyle"))
        XCTAssertTrue(source.contains("hoverBackgroundColor"))
        XCTAssertTrue(source.contains("Color(nsColor: .systemGray)"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertTrue(source.contains("scaleEffect(isHovering ? SettingsGroupVisualStyle.hoverScale : 1)"))
        XCTAssertTrue(source.contains(".animation(.easeOut"))
        XCTAssertFalse(source.contains("controlBackgroundColor"))
        XCTAssertFalse(source.contains(".background(.regularMaterial)"))
    }

    func testSettingsRootViewEmbedsAboutStatusPageAndUsesThinDetailScrollbars() throws {
        let source = try settingsRootViewSource()

        XCTAssertTrue(source.contains("selection.selectedPage == .aboutStatus"))
        XCTAssertTrue(source.contains("systemImage: \"info.circle\""))
        XCTAssertTrue(source.contains("case .aboutStatus:"))
        XCTAssertTrue(source.contains("AboutStatusSettingsView("))
        XCTAssertTrue(source.contains("AppStatusProviding"))
        XCTAssertTrue(source.contains("statusProvider.snapshot()"))
        XCTAssertTrue(source.contains("NSPasteboard.general.setString"))
        XCTAssertTrue(source.contains("SettingsScrollBarTuner"))
        XCTAssertTrue(source.contains("static let controlSize: NSControl.ControlSize = .mini"))
        XCTAssertTrue(source.contains(".background(SettingsScrollBarTuner())"))
        XCTAssertTrue(source.contains("text.string(.removeExcludedAppHelp)"))
        XCTAssertFalse(source.contains("\"Remove excluded app\""))
    }

    private func closeSettingsWindows() {
        for window in NSApplication.shared.windows
            where window.identifier == SettingsWindowController.windowIdentifier {
            window.close()
        }
    }

    private func settingsRootViewSource() throws -> String {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/SettingsRootView.swift")
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
        viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            launchAtLoginService: FakeLaunchAtLoginService(),
            targetTracker: targetTracker,
            logger: ProbeLogger()
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

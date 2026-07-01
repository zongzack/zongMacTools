import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class ProbeOrchestratorPreviewTests: XCTestCase {
    func testFrontmostPreviewSuppressesPanelWhenScreenRecordingIsMissing() async {
        let harness = ProbeOrchestratorPreviewHarness(screenRecordingGranted: false)

        harness.orchestrator.showFrontmostAppProbe()
        await Task.yield()

        XCTAssertEqual(harness.display.hideReasons, ["screenRecording=false"])
        XCTAssertEqual(harness.display.showCount, 0)
    }
}

private final class OrchestratorFakePermissionService: PermissionService {
    var currentState: PermissionState

    init(screenRecordingGranted: Bool) {
        currentState = PermissionState(accessibilityGranted: true, screenRecordingGranted: screenRecordingGranted)
    }

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

private final class OrchestratorFakeWindowQueryService: WindowQueryService, @unchecked Sendable {
    func windows(for app: NSRunningApplication) async -> [PreviewWindow] { [] }
}

private final class OrchestratorFakeThumbnailService: ThumbnailService, @unchecked Sendable {
    func thumbnail(for window: PreviewWindow) async -> CGImage? { nil }
}

@MainActor
private final class OrchestratorFakeActivationService: ActivationService {
    func activate(window: PreviewWindow) -> ActivationProbeResult {
        ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: false,
            raiseSucceeded: false,
            appActivateRequestSucceeded: true
        )
    }
}

@MainActor
private final class OrchestratorFakePreviewDisplay: PreviewPanelDisplaying {
    var onRequestHide: ((String) -> Void)?

    var showCount = 0
    var hideReasons: [String] = []

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        showCount += 1
    }

    func update(model: PreviewPanelViewModel) {}

    func hide(reason: String) {
        hideReasons.append(reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool { false }

    func panelFrame() -> CGRect? { nil }
}

@MainActor
private final class ProbeOrchestratorPreviewHarness {
    let permissionService: OrchestratorFakePermissionService
    let display = OrchestratorFakePreviewDisplay()
    let orchestrator: ProbeOrchestrator

    init(screenRecordingGranted: Bool) {
        let logger = ProbeLogger()
        permissionService = OrchestratorFakePermissionService(screenRecordingGranted: screenRecordingGranted)
        let previewSessionController = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: OrchestratorFakeWindowQueryService(),
            thumbnailService: OrchestratorFakeThumbnailService(),
            activationService: OrchestratorFakeActivationService(),
            panelDisplay: display,
            logger: logger
        )
        orchestrator = ProbeOrchestrator(
            permissionService: permissionService,
            logger: logger,
            previewSessionController: previewSessionController
        )
    }
}

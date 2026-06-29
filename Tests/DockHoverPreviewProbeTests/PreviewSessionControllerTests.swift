import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class PreviewSessionControllerTests: XCTestCase {
    func testScreenRecordingMissingSuppressesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: false, windows: [makeWindow(id: 1)])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["screenRecording=false"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testNoWindowsHidesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["noWindows"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testShowsPlaceholderCardsThenUpdatesThumbnails() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.showCount, 1)
        XCTAssertEqual(harness.display.updateCount, 1)
        XCTAssertEqual(harness.display.lastModel?.cards.count, 1)
        XCTAssertTrue(harness.display.lastModel?.cards.first?.isLoadingThumbnail == false)
        XCTAssertNotNil(harness.display.lastModel?.cards.first?.thumbnail)
    }

    func testHideInvalidatesStaleThumbnailUpdates() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()
        harness.thumbnailService.suspend = true

        let task = Task {
            await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        }
        await Task.yield()
        harness.controller.hide(reason: "test")
        harness.thumbnailService.resume()
        await task.value

        XCTAssertEqual(harness.display.hideReasons, ["test"])
        XCTAssertEqual(harness.display.updateCount, 0)
    }

    func testSelectingCardActivatesWindowAndHidesPanel() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        await harness.controller.activate(windowID: window.id)

        XCTAssertEqual(harness.activationService.activatedIDs, [window.id])
        XCTAssertEqual(harness.display.hideReasons, ["activated"])
    }
}

private final class FakePermissionService: PermissionService {
    var currentState: PermissionState

    init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        currentState = PermissionState(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

private final class FakeWindowQueryService: WindowQueryService, @unchecked Sendable {
    let windows: [PreviewWindow]

    init(windows: [PreviewWindow]) {
        self.windows = windows
    }

    func windows(for app: NSRunningApplication) async -> [PreviewWindow] {
        windows
    }
}

private final class FakeThumbnailService: ThumbnailService, @unchecked Sendable {
    var images: [PreviewWindowID: CGImage] = [:]
    var suspend = false
    private var continuation: CheckedContinuation<Void, Never>?

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        if suspend {
            await withCheckedContinuation { continuation = $0 }
        }
        return images[window.id]
    }

    func resume() {
        suspend = false
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class FakeActivationService: ActivationService {
    var activatedIDs: [PreviewWindowID] = []

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        activatedIDs.append(window.id)
        return ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: window.axElement != nil,
            raiseSucceeded: window.axElement != nil,
            appActivateRequestSucceeded: true
        )
    }
}

@MainActor
private final class FakePreviewPanelDisplay: PreviewPanelDisplaying {
    var showCount = 0
    var updateCount = 0
    var lastModel: PreviewPanelViewModel?
    var hideReasons: [String] = []
    var selectHandler: ((PreviewWindowID) -> Void)?

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        showCount += 1
        lastModel = model
        selectHandler = onSelect
    }

    func update(model: PreviewPanelViewModel) {
        updateCount += 1
        lastModel = model
    }

    func hide(reason: String) {
        hideReasons.append(reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        false
    }
}

@MainActor
private final class PreviewSessionHarness {
    let app = NSRunningApplication.current
    let permissionService: FakePermissionService
    let queryService: FakeWindowQueryService
    let thumbnailService = FakeThumbnailService()
    let activationService = FakeActivationService()
    let display = FakePreviewPanelDisplay()
    let logger = ProbeLogger()
    let anchor = PreviewPanelAnchor(
        dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
        mouseLocation: CGPoint(x: 726, y: 24),
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
    )
    let controller: PreviewSessionController

    init(screenRecordingGranted: Bool, windows: [PreviewWindow]) {
        permissionService = FakePermissionService(
            accessibilityGranted: true,
            screenRecordingGranted: screenRecordingGranted
        )
        queryService = FakeWindowQueryService(windows: windows)
        controller = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: queryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            panelDisplay: display,
            logger: logger
        )
    }
}

private func makeWindow(id: CGWindowID) -> PreviewWindow {
    PreviewWindow(
        id: PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: id),
        cgWindowID: id,
        app: NSRunningApplication.current,
        title: "Window \(id)",
        frame: CGRect(x: 100, y: 100, width: 800, height: 600),
        scWindow: nil,
        axElement: nil,
        appIcon: NSImage(size: NSSize(width: 32, height: 32)),
        thumbnailSource: nil
    )
}

private func makeImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

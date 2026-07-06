import AppKit
import ApplicationServices
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowOperationServiceTests: XCTestCase {
    func testAvailabilityUsesReadOnlyProbes() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXCloseButtonAttribute as String] = .found
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .missing(axErrorCode: nil)
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .settable
        let window = makeWindow()

        let close = harness.service.availability(for: .closeWindow, window: window)
        let minimize = harness.service.availability(for: .minimizeWindow, window: window)

        XCTAssertTrue(close.isEnabled)
        XCTAssertTrue(minimize.isEnabled)
        XCTAssertEqual(harness.ax.buttonProbeAttributes, [
            kAXCloseButtonAttribute as String,
            kAXMinimizeButtonAttribute as String
        ])
        XCTAssertEqual(harness.ax.pressedButtonAttributes, [])
        XCTAssertEqual(harness.ax.setBooleanAttributes, [])
    }

    func testDisabledAvailabilityRecordsStageAndAXCode() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXCloseButtonAttribute as String] = .missing(
            axErrorCode: Int32(AXError.attributeUnsupported.rawValue)
        )
        let window = makeWindow()

        let availability = harness.service.availability(for: .closeWindow, window: window)

        XCTAssertFalse(availability.isEnabled)
        XCTAssertEqual(availability.disabledReason, "Missing close button")
        XCTAssertEqual(availability.disabledStage, .copyAttribute)
        XCTAssertEqual(availability.disabledAXErrorCode, Int32(AXError.attributeUnsupported.rawValue))
        XCTAssertTrue(harness.logger.snapshot().contains {
            $0.contains("windowOperation.availability operation=closeWindow")
                && $0.contains("enabled=false")
                && $0.contains("stage=copyAttribute")
                && $0.contains("axCode=\(Int32(AXError.attributeUnsupported.rawValue))")
        })
    }

    func testCloseWindowPressesCloseButtonAndLogsResult() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXCloseButtonAttribute as String] = .found
        harness.ax.pressResults[kAXCloseButtonAttribute as String] = .success
        let window = makeWindow()

        let result = harness.service.perform(.closeWindow, on: window)

        XCTAssertTrue(result.requestSucceeded)
        XCTAssertNil(result.failure)
        XCTAssertEqual(harness.ax.pressedButtonAttributes, [kAXCloseButtonAttribute as String])
        XCTAssertTrue(harness.logger.snapshot().contains { $0.contains("windowOperation.request operation=closeWindow") })
        XCTAssertTrue(harness.logger.snapshot().contains { $0.contains("windowOperation.result operation=closeWindow") && $0.contains("requestSucceeded=true") })
    }

    func testCloseWindowMissingButtonReturnsCopyAttributeFailure() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXCloseButtonAttribute as String] = .missing(
            axErrorCode: Int32(AXError.attributeUnsupported.rawValue)
        )
        let window = makeWindow()

        let result = harness.service.perform(.closeWindow, on: window)

        XCTAssertFalse(result.requestSucceeded)
        XCTAssertEqual(result.failure?.reason, .missingButton)
        XCTAssertEqual(result.failure?.stage, .copyAttribute)
        XCTAssertEqual(result.failure?.axErrorCode, Int32(AXError.attributeUnsupported.rawValue))
        XCTAssertEqual(harness.ax.pressedButtonAttributes, [])
    }

    func testCloseWindowPressFailureRecordsAXCode() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXCloseButtonAttribute as String] = .found
        harness.ax.pressResults[kAXCloseButtonAttribute as String] = .actionUnsupported
        let window = makeWindow()

        let result = harness.service.perform(.closeWindow, on: window)

        XCTAssertFalse(result.requestSucceeded)
        XCTAssertEqual(result.failure?.reason, .actionFailed)
        XCTAssertEqual(result.failure?.stage, .pressButton)
        XCTAssertEqual(result.failure?.axErrorCode, Int32(AXError.actionUnsupported.rawValue))
    }

    func testMinimizeWindowUsesMinimizeButtonBeforeAttributeFallback() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .found
        harness.ax.pressResults[kAXMinimizeButtonAttribute as String] = .success
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .settable
        let window = makeWindow()

        let result = harness.service.perform(.minimizeWindow, on: window)

        XCTAssertTrue(result.requestSucceeded)
        XCTAssertEqual(harness.ax.pressedButtonAttributes, [kAXMinimizeButtonAttribute as String])
        XCTAssertEqual(harness.ax.setBooleanAttributes, [])
    }

    func testMinimizeWindowFallsBackToMinimizedAttribute() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .missing(axErrorCode: nil)
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .settable
        harness.ax.setResults[kAXMinimizedAttribute as String] = .success
        let window = makeWindow()

        let result = harness.service.perform(.minimizeWindow, on: window)

        XCTAssertTrue(result.requestSucceeded)
        XCTAssertEqual(harness.ax.pressedButtonAttributes, [])
        XCTAssertEqual(harness.ax.setBooleanAttributes, [kAXMinimizedAttribute as String])
    }

    func testMinimizeWindowAttributeNotSettableFailsQuietly() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .missing(axErrorCode: nil)
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .notSettable
        let window = makeWindow()

        let result = harness.service.perform(.minimizeWindow, on: window)

        XCTAssertFalse(result.requestSucceeded)
        XCTAssertEqual(result.failure?.reason, .attributeNotSettable)
        XCTAssertEqual(result.failure?.stage, .checkSettable)
        XCTAssertEqual(harness.ax.setBooleanAttributes, [])
    }

    func testMinimizeWindowSettableProbeFailureRecordsAXCode() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .missing(axErrorCode: nil)
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .failed(
            axErrorCode: Int32(AXError.cannotComplete.rawValue)
        )
        let window = makeWindow()

        let result = harness.service.perform(.minimizeWindow, on: window)

        XCTAssertFalse(result.requestSucceeded)
        XCTAssertEqual(result.failure?.reason, .attributeNotSettable)
        XCTAssertEqual(result.failure?.stage, .checkSettable)
        XCTAssertEqual(result.failure?.axErrorCode, Int32(AXError.cannotComplete.rawValue))
        XCTAssertEqual(harness.ax.setBooleanAttributes, [])
    }

    func testMinimizeAvailabilitySettableProbeFailureRecordsStageAndAXCode() {
        let harness = Harness()
        harness.ax.buttonProbeResults[kAXMinimizeButtonAttribute as String] = .missing(axErrorCode: nil)
        harness.ax.settableResults[kAXMinimizedAttribute as String] = .failed(
            axErrorCode: Int32(AXError.cannotComplete.rawValue)
        )
        let window = makeWindow()

        let availability = harness.service.availability(for: .minimizeWindow, window: window)

        XCTAssertFalse(availability.isEnabled)
        XCTAssertEqual(availability.disabledReason, "Minimize unavailable")
        XCTAssertEqual(availability.disabledStage, .checkSettable)
        XCTAssertEqual(availability.disabledAXErrorCode, Int32(AXError.cannotComplete.rawValue))
    }

    func testHideApplicationConvertsRejectedRequestToFailure() {
        let harness = Harness()
        harness.appOperations.hideResult = false
        let window = makeWindow()

        let result = harness.service.perform(.hideApplication, on: window)

        XCTAssertEqual(harness.appOperations.hideRequests, [window.id])
        XCTAssertFalse(result.requestSucceeded)
        XCTAssertEqual(result.failure?.reason, .applicationRejected)
        XCTAssertEqual(result.failure?.stage, .hideApplication)
    }

    func testActivateWindowDelegatesExistingActivationService() {
        let harness = Harness()
        harness.activation.result = ActivationProbeResult(
            windowID: 42,
            title: "Editor",
            hadAXElement: true,
            raiseSucceeded: true,
            appActivateRequestSucceeded: false
        )
        let window = makeWindow(id: 42)

        let result = harness.service.perform(.activate, on: window)

        XCTAssertEqual(harness.activation.activatedIDs, [window.id])
        XCTAssertTrue(result.requestSucceeded)
        XCTAssertNil(result.failure)
    }
}

@MainActor
private final class Harness {
    let activation = FakeWindowOperationActivationService()
    let ax = FakeAccessibilityWindowActionPerformer()
    let appOperations = FakeRunningApplicationOperationPerformer()
    let logger = ProbeLogger()
    lazy var service = AXWindowOperationService(
        activationService: activation,
        accessibilityPerformer: ax,
        applicationPerformer: appOperations,
        logger: logger
    )
}

@MainActor
private final class FakeWindowOperationActivationService: ActivationService {
    var activatedIDs: [PreviewWindowID] = []
    var result = ActivationProbeResult(
        windowID: 1,
        title: "Window 1",
        hadAXElement: false,
        raiseSucceeded: false,
        appActivateRequestSucceeded: true
    )

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        activatedIDs.append(window.id)
        return result
    }
}

@MainActor
private final class FakeAccessibilityWindowActionPerformer: AccessibilityWindowActionPerforming {
    var buttonProbeResults: [String: AccessibilityButtonProbeResult] = [:]
    var pressResults: [String: AXError] = [:]
    var settableResults: [String: AccessibilitySettableProbeResult] = [:]
    var setResults: [String: AXError] = [:]

    private(set) var buttonProbeAttributes: [String] = []
    private(set) var pressedButtonAttributes: [String] = []
    private(set) var setBooleanAttributes: [String] = []

    func buttonProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilityButtonProbeResult {
        let key = attribute as String
        buttonProbeAttributes.append(key)
        return buttonProbeResults[key] ?? .missing(axErrorCode: nil)
    }

    func pressButton(attribute: CFString, on windowElement: AXUIElement?) -> AXError {
        let key = attribute as String
        pressedButtonAttributes.append(key)
        return pressResults[key] ?? .success
    }

    func setBooleanAttribute(_ attribute: CFString, value: Bool, on windowElement: AXUIElement?) -> AXError {
        let key = attribute as String
        setBooleanAttributes.append(key)
        return setResults[key] ?? .success
    }

    func settableProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilitySettableProbeResult {
        settableResults[attribute as String] ?? .notSettable
    }
}

@MainActor
private final class FakeRunningApplicationOperationPerformer: RunningApplicationOperationPerforming {
    var hideResult = true
    private(set) var hideRequests: [PreviewWindowID] = []

    func hide(_ app: NSRunningApplication, windowID: PreviewWindowID) -> Bool {
        hideRequests.append(windowID)
        return hideResult
    }
}

private func makeWindow(id: CGWindowID = 1) -> PreviewWindow {
    PreviewWindow(
        id: PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: id),
        cgWindowID: id,
        app: NSRunningApplication.current,
        title: "Window \(id)",
        frame: CGRect(x: 100, y: 100, width: 800, height: 600),
        scWindow: nil,
        axElement: AXUIElementCreateApplication(getpid()),
        appIcon: NSImage(size: NSSize(width: 32, height: 32)),
        thumbnailSource: nil
    )
}

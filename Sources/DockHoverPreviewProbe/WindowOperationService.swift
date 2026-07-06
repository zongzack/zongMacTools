import AppKit
import ApplicationServices
import Foundation

enum AccessibilityButtonProbeResult: Equatable, Sendable {
    case found
    case missing(axErrorCode: Int32?)
}

enum AccessibilitySettableProbeResult: Equatable, Sendable {
    case settable
    case notSettable
    case failed(axErrorCode: Int32?)
}

@MainActor
protocol AccessibilityWindowActionPerforming: Sendable {
    func buttonProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilityButtonProbeResult
    func pressButton(attribute: CFString, on windowElement: AXUIElement?) -> AXError
    func setBooleanAttribute(_ attribute: CFString, value: Bool, on windowElement: AXUIElement?) -> AXError
    func settableProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilitySettableProbeResult
}

@MainActor
protocol RunningApplicationOperationPerforming: Sendable {
    func hide(_ app: NSRunningApplication, windowID: PreviewWindowID) -> Bool
}

@MainActor
protocol WindowOperationService: Sendable {
    func availability(for operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationAvailability
    func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult
}

struct SystemAccessibilityWindowActionPerformer: AccessibilityWindowActionPerforming {
    func buttonProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilityButtonProbeResult {
        guard let windowElement else {
            return .missing(axErrorCode: nil)
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowElement, attribute, &value)
        guard result == .success, value != nil else {
            return .missing(axErrorCode: Int32(result.rawValue))
        }
        return .found
    }

    func pressButton(attribute: CFString, on windowElement: AXUIElement?) -> AXError {
        guard let windowElement else {
            return .invalidUIElement
        }

        var value: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(windowElement, attribute, &value)
        guard copyResult == .success, let value else {
            return copyResult
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .illegalArgument
        }
        let button = value as! AXUIElement
        return AXUIElementPerformAction(button, kAXPressAction as CFString)
    }

    func setBooleanAttribute(_ attribute: CFString, value: Bool, on windowElement: AXUIElement?) -> AXError {
        guard let windowElement else {
            return .invalidUIElement
        }

        return AXUIElementSetAttributeValue(
            windowElement,
            attribute,
            value ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    func settableProbe(attribute: CFString, on windowElement: AXUIElement?) -> AccessibilitySettableProbeResult {
        guard let windowElement else {
            return .failed(axErrorCode: nil)
        }

        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(windowElement, attribute, &settable)
        guard result == .success else {
            return .failed(axErrorCode: Int32(result.rawValue))
        }
        return settable.boolValue ? .settable : .notSettable
    }
}

struct SystemRunningApplicationOperationPerformer: RunningApplicationOperationPerforming {
    func hide(_ app: NSRunningApplication, windowID: PreviewWindowID) -> Bool {
        app.hide()
    }
}

final class AXWindowOperationService: WindowOperationService {
    private let activationService: ActivationService
    private let accessibilityPerformer: AccessibilityWindowActionPerforming
    private let applicationPerformer: RunningApplicationOperationPerforming
    private let logger: ProbeLogger

    init(
        activationService: ActivationService,
        accessibilityPerformer: AccessibilityWindowActionPerforming = SystemAccessibilityWindowActionPerformer(),
        applicationPerformer: RunningApplicationOperationPerforming = SystemRunningApplicationOperationPerformer(),
        logger: ProbeLogger
    ) {
        self.activationService = activationService
        self.accessibilityPerformer = accessibilityPerformer
        self.applicationPerformer = applicationPerformer
        self.logger = logger
    }

    func availability(for operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationAvailability {
        let availability: WindowOperationAvailability
        switch operation {
        case .activate, .hideApplication:
            availability = .enabled(operation)
        case .closeWindow:
            availability = buttonAvailability(
                operation: operation,
                attribute: kAXCloseButtonAttribute as CFString,
                missingReason: "Missing close button",
                window: window
            )
        case .minimizeWindow:
            availability = minimizeAvailability(window: window)
        }

        logger.info(
            "windowOperation.availability operation=\(operation.rawValue) enabled=\(availability.isEnabled) reason=\(availability.disabledReason ?? "none") stage=\(availability.disabledStage?.rawValue ?? "none") axCode=\(availability.disabledAXErrorCode.map(String.init) ?? "none")"
        )
        return availability
    }

    func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult {
        logger.info("windowOperation.request operation=\(operation.rawValue) id=\(window.cgWindowID) title=\(window.title)")

        let result: WindowOperationResult
        switch operation {
        case .activate:
            result = performActivate(window)
        case .hideApplication:
            result = performHideApplication(window)
        case .closeWindow:
            result = performCloseWindow(window)
        case .minimizeWindow:
            result = performMinimizeWindow(window)
        }

        log(result)
        return result
    }

    private func buttonAvailability(
        operation: PreviewWindowOperation,
        attribute: CFString,
        missingReason: String,
        window: PreviewWindow
    ) -> WindowOperationAvailability {
        guard window.axElement != nil else {
            return .disabled(
                operation,
                reason: "Missing accessibility element",
                stage: .copyAttribute
            )
        }

        switch accessibilityPerformer.buttonProbe(attribute: attribute, on: window.axElement) {
        case .found:
            return .enabled(operation)
        case let .missing(axErrorCode):
            return .disabled(
                operation,
                reason: missingReason,
                stage: .copyAttribute,
                axErrorCode: axErrorCode
            )
        }
    }

    private func minimizeAvailability(window: PreviewWindow) -> WindowOperationAvailability {
        guard window.axElement != nil else {
            return .disabled(
                .minimizeWindow,
                reason: "Missing accessibility element",
                stage: .copyAttribute
            )
        }

        switch accessibilityPerformer.buttonProbe(attribute: kAXMinimizeButtonAttribute as CFString, on: window.axElement) {
        case .found:
            return .enabled(.minimizeWindow)
        case .missing:
            switch accessibilityPerformer.settableProbe(attribute: kAXMinimizedAttribute as CFString, on: window.axElement) {
            case .settable:
                return .enabled(.minimizeWindow)
            case .notSettable:
                return .disabled(
                    .minimizeWindow,
                    reason: "Minimize unavailable",
                    stage: .checkSettable
                )
            case let .failed(axErrorCode):
                return .disabled(
                    .minimizeWindow,
                    reason: "Minimize unavailable",
                    stage: .checkSettable,
                    axErrorCode: axErrorCode
                )
            }
        }
    }

    private func performActivate(_ window: PreviewWindow) -> WindowOperationResult {
        let activationResult = activationService.activate(window: window)
        let succeeded = activationResult.raiseSucceeded || activationResult.appActivateRequestSucceeded
        guard succeeded else {
            return failure(
                .activate,
                window: window,
                reason: .applicationRejected,
                stage: .activateApplication,
                axError: nil
            )
        }
        return success(.activate, window: window)
    }

    private func performHideApplication(_ window: PreviewWindow) -> WindowOperationResult {
        guard applicationPerformer.hide(window.app, windowID: window.id) else {
            return failure(
                .hideApplication,
                window: window,
                reason: .applicationRejected,
                stage: .hideApplication,
                axError: nil
            )
        }
        return success(.hideApplication, window: window)
    }

    private func performCloseWindow(_ window: PreviewWindow) -> WindowOperationResult {
        guard window.axElement != nil else {
            return failure(
                .closeWindow,
                window: window,
                reason: .missingAccessibilityElement,
                stage: .copyAttribute,
                axError: nil
            )
        }

        switch accessibilityPerformer.buttonProbe(attribute: kAXCloseButtonAttribute as CFString, on: window.axElement) {
        case .found:
            let pressResult = accessibilityPerformer.pressButton(
                attribute: kAXCloseButtonAttribute as CFString,
                on: window.axElement
            )
            guard pressResult == .success else {
                return failure(
                    .closeWindow,
                    window: window,
                    reason: .actionFailed,
                    stage: .pressButton,
                    axError: pressResult
                )
            }
            return success(.closeWindow, window: window)
        case let .missing(axErrorCode):
            return failure(
                .closeWindow,
                window: window,
                reason: .missingButton,
                stage: .copyAttribute,
                axErrorCode: axErrorCode
            )
        }
    }

    private func performMinimizeWindow(_ window: PreviewWindow) -> WindowOperationResult {
        guard window.axElement != nil else {
            return failure(
                .minimizeWindow,
                window: window,
                reason: .missingAccessibilityElement,
                stage: .copyAttribute,
                axError: nil
            )
        }

        switch accessibilityPerformer.buttonProbe(attribute: kAXMinimizeButtonAttribute as CFString, on: window.axElement) {
        case .found:
            let pressResult = accessibilityPerformer.pressButton(
                attribute: kAXMinimizeButtonAttribute as CFString,
                on: window.axElement
            )
            guard pressResult == .success else {
                return failure(
                    .minimizeWindow,
                    window: window,
                    reason: .actionFailed,
                    stage: .pressButton,
                    axError: pressResult
                )
            }
            return success(.minimizeWindow, window: window)
        case .missing:
            let settableProbe = accessibilityPerformer.settableProbe(
                attribute: kAXMinimizedAttribute as CFString,
                on: window.axElement
            )
            switch settableProbe {
            case .settable:
                break
            case .notSettable:
                return failure(
                    .minimizeWindow,
                    window: window,
                    reason: .attributeNotSettable,
                    stage: .checkSettable,
                    axError: nil
                )
            case let .failed(axErrorCode):
                return failure(
                    .minimizeWindow,
                    window: window,
                    reason: .attributeNotSettable,
                    stage: .checkSettable,
                    axErrorCode: axErrorCode
                )
            }

            let setResult = accessibilityPerformer.setBooleanAttribute(
                kAXMinimizedAttribute as CFString,
                value: true,
                on: window.axElement
            )
            guard setResult == .success else {
                return failure(
                    .minimizeWindow,
                    window: window,
                    reason: .actionFailed,
                    stage: .setAttribute,
                    axError: setResult
                )
            }
            return success(.minimizeWindow, window: window)
        }
    }

    private func success(_ operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationResult {
        WindowOperationResult(
            operation: operation,
            windowID: window.id,
            requestSucceeded: true,
            failure: nil
        )
    }

    private func failure(
        _ operation: PreviewWindowOperation,
        window: PreviewWindow,
        reason: WindowOperationFailureReason,
        stage: WindowOperationFailureStage,
        axError: AXError?
    ) -> WindowOperationResult {
        failure(
            operation,
            window: window,
            reason: reason,
            stage: stage,
            axErrorCode: axError.map { Int32($0.rawValue) }
        )
    }

    private func failure(
        _ operation: PreviewWindowOperation,
        window: PreviewWindow,
        reason: WindowOperationFailureReason,
        stage: WindowOperationFailureStage,
        axErrorCode: Int32?
    ) -> WindowOperationResult {
        WindowOperationResult(
            operation: operation,
            windowID: window.id,
            requestSucceeded: false,
            failure: WindowOperationFailure(
                reason: reason,
                stage: stage,
                axErrorCode: axErrorCode
            )
        )
    }

    private func log(_ result: WindowOperationResult) {
        let failure = result.failure
        logger.info(
            "windowOperation.result operation=\(result.operation.rawValue) id=\(result.windowID.windowID) requestSucceeded=\(result.requestSucceeded) reason=\(failure?.reason.rawValue ?? "none") stage=\(failure?.stage.rawValue ?? "none") axCode=\(failure?.axErrorCode.map(String.init) ?? "none")"
        )
    }
}

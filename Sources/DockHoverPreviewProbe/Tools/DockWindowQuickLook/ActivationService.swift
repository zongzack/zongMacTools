import AppKit
import ApplicationServices

protocol ActivationService: Sendable {
    @MainActor func activate(window: PreviewWindow) -> ActivationProbeResult
}

final class AXActivationService: ActivationService {
    private let logger: ProbeLogger

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        if window.app.isHidden {
            _ = window.app.unhide()
        }
        var raiseSucceeded = false
        if let axElement = window.axElement {
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            let settable = isSettable(kAXMainAttribute as CFString, on: axElement)
            var mainResult: AXError = .success
            if settable {
                mainResult = AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
            }
            raiseSucceeded = raiseResult == .success
            logger.info("activation.ax id=\(window.cgWindowID) raiseCode=\(raiseResult.rawValue) mainSettable=\(settable) mainCode=\(mainResult.rawValue)")
        } else {
            logger.warning("activation.noAX id=\(window.cgWindowID) title=\(window.title)")
        }
        let activateSucceeded = window.app.activate(options: [])
        let result = ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: window.axElement != nil,
            raiseSucceeded: raiseSucceeded,
            appActivateRequestSucceeded: activateSucceeded
        )
        logger.info("activation.result id=\(result.windowID) title=\(result.title) hadAX=\(result.hadAXElement) raise=\(result.raiseSucceeded) appActivate=\(result.appActivateRequestSucceeded)")
        return result
    }

    private func isSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }
}

import CoreGraphics
import ScreenCaptureKit

@MainActor
protocol WindowPeekCaptureSource: AnyObject {
    var windowID: PreviewWindowID { get }
}

@MainActor
protocol WindowPeekCaptureBackend: AnyObject {
    func capture(
        token: WindowPeekCaptureRequestToken,
        source: any WindowPeekCaptureSource,
        configuration: WindowPeekCaptureConfiguration
    ) async throws -> CGImage
    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken)
}

@MainActor
protocol WindowPeekCaptureService: AnyObject {
    func capture(
        token: WindowPeekCaptureRequestToken,
        source: (any WindowPeekCaptureSource)?,
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) async -> WindowPeekCaptureResult
    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken)
}

enum WindowPeekCaptureBackendError: Error {
    case unavailable
}

@MainActor
final class ScreenCaptureKitWindowPeekCaptureSource: WindowPeekCaptureSource {
    let windowID: PreviewWindowID
    let window: SCWindow

    init(windowID: PreviewWindowID, window: SCWindow) {
        self.windowID = windowID
        self.window = window
    }
}

@MainActor
final class ScreenCaptureKitWindowPeekCaptureBackend: WindowPeekCaptureBackend {
    private let logger: ProbeLogger
    private let captureBroker: ScreenCaptureKitCaptureBroker

    init(logger: ProbeLogger, captureBroker: ScreenCaptureKitCaptureBroker) {
        self.logger = logger
        self.captureBroker = captureBroker
    }

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: any WindowPeekCaptureSource,
        configuration: WindowPeekCaptureConfiguration
    ) async throws -> CGImage {
        guard let source = source as? ScreenCaptureKitWindowPeekCaptureSource else {
            logger.warning("peek.capture.backendUnavailable reason=unsupportedSource")
            throw WindowPeekCaptureBackendError.unavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: source.window)
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = configuration.pixelSize.width
        streamConfiguration.height = configuration.pixelSize.height
        streamConfiguration.showsCursor = configuration.showsCursor
        streamConfiguration.ignoreShadowsSingleWindow = configuration.ignoresSingleWindowShadow
        return try await captureBroker.captureDesktopPeek(token: token) {
            try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: streamConfiguration
            )
        }
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) {
        captureBroker.invalidateQueuedDesktopPeek(token: token)
    }
}

@MainActor
final class DefaultWindowPeekCaptureService: WindowPeekCaptureService {
    private let logger: ProbeLogger
    private let permissionProvider: () -> Bool
    private let backend: any WindowPeekCaptureBackend

    init(
        logger: ProbeLogger,
        permissionProvider: @escaping () -> Bool = CGPreflightScreenCaptureAccess,
        backend: any WindowPeekCaptureBackend
    ) {
        self.logger = logger
        self.permissionProvider = permissionProvider
        self.backend = backend
    }

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: (any WindowPeekCaptureSource)?,
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) async -> WindowPeekCaptureResult {
        guard let source else {
            logger.warning("peek.capture.unavailable reason=missingSource windowID=\(token.windowID.windowID)")
            return .unavailable
        }
        guard permissionProvider() else {
            logger.warning("peek.capture.permissionDenied stage=beforeCapture windowID=\(token.windowID.windowID)")
            return .permissionDenied
        }

        let configuration = WindowPeekCaptureConfiguration(
            pixelSize: WindowPeekGeometry.capturePixelSize(
                logicalSize: logicalSize,
                backingScaleFactor: backingScaleFactor
            ),
            showsCursor: false,
            ignoresSingleWindowShadow: true
        )
        do {
            return .image(
                try await backend.capture(
                    token: token,
                    source: source,
                    configuration: configuration
                )
            )
        } catch is WindowPeekCaptureBackendError {
            logger.warning("peek.capture.unavailable reason=backend windowID=\(token.windowID.windowID)")
            return .unavailable
        } catch WindowPeekCaptureBrokerError.superseded {
            logger.info("peek.capture.stale windowID=\(token.windowID.windowID)")
            return .unavailable
        } catch {
            if !permissionProvider() {
                logger.warning("peek.capture.permissionDenied stage=afterFailure windowID=\(token.windowID.windowID)")
                return .permissionDenied
            }
            logger.warning("peek.capture.failed windowID=\(token.windowID.windowID) reason=backendFailure")
            return .failed
        }
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) {
        backend.invalidateQueuedCapture(token: token)
    }
}

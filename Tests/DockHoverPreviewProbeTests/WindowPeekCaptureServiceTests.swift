import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowPeekCaptureServiceTests: XCTestCase {
    func testMissingSourceReturnsUnavailableWithoutCallingBackend() async {
        let backend = RecordingWindowPeekCaptureBackend()
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { true },
            backend: backend
        )

        let result = await service.capture(
            token: makeToken(),
            source: nil,
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case .unavailable = result else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertEqual(backend.callCount, 0)
    }

    func testCaptureConfigurationUsesScaleCursorAndShadowRules() async {
        let backend = RecordingWindowPeekCaptureBackend(
            result: .success(makeImage(width: 1600, height: 1200))
        )
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { true },
            backend: backend
        )
        let source = TestCaptureSource(windowID: makeToken().windowID)

        let result = await service.capture(
            token: makeToken(),
            source: source,
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case let .image(image) = result else {
            return XCTFail("Expected image")
        }
        XCTAssertEqual(image.width, 1600)
        XCTAssertEqual(backend.lastConfiguration?.pixelSize, WindowPeekPixelSize(width: 1600, height: 1200))
        XCTAssertEqual(backend.lastConfiguration?.showsCursor, false)
        XCTAssertEqual(backend.lastConfiguration?.ignoresSingleWindowShadow, true)
    }

    func testDeniedPermissionBeforeCaptureSkipsBackend() async {
        let backend = RecordingWindowPeekCaptureBackend()
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { false },
            backend: backend
        )

        let result = await service.capture(
            token: makeToken(),
            source: TestCaptureSource(windowID: makeToken().windowID),
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case .permissionDenied = result else {
            return XCTFail("Expected permissionDenied")
        }
        XCTAssertEqual(backend.callCount, 0)
    }

    func testBackendUnavailableReturnsUnavailable() async {
        let backend = RecordingWindowPeekCaptureBackend(
            result: .failure(WindowPeekCaptureBackendError.unavailable)
        )
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { true },
            backend: backend
        )

        let result = await service.capture(
            token: makeToken(),
            source: TestCaptureSource(windowID: makeToken().windowID),
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case .unavailable = result else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertEqual(backend.callCount, 1)
    }

    func testBackendFailureAfterPermissionRevocationReturnsPermissionDenied() async {
        var permissionStates = [true, false]
        let backend = RecordingWindowPeekCaptureBackend(
            result: .failure(TestCaptureError.failed)
        )
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { permissionStates.removeFirst() },
            backend: backend
        )

        let result = await service.capture(
            token: makeToken(),
            source: TestCaptureSource(windowID: makeToken().windowID),
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case .permissionDenied = result else {
            return XCTFail("Expected permissionDenied")
        }
    }

    func testBackendFailureWhilePermissionRemainsGrantedReturnsFailed() async {
        let backend = RecordingWindowPeekCaptureBackend(
            result: .failure(TestCaptureError.failed)
        )
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { true },
            backend: backend
        )

        let result = await service.capture(
            token: makeToken(),
            source: TestCaptureSource(windowID: makeToken().windowID),
            logicalSize: CGSize(width: 800, height: 600),
            backingScaleFactor: 2
        )

        guard case .failed = result else {
            return XCTFail("Expected failed")
        }
    }

    func testLargeCaptureConfigurationPreservesNativeRetinaPixels() async throws {
        let backend = RecordingWindowPeekCaptureBackend(
            result: .success(makeImage())
        )
        let service = DefaultWindowPeekCaptureService(
            logger: ProbeLogger(),
            permissionProvider: { true },
            backend: backend
        )

        _ = await service.capture(
            token: makeToken(),
            source: TestCaptureSource(windowID: makeToken().windowID),
            logicalSize: CGSize(width: 3008, height: 1692),
            backingScaleFactor: 2
        )

        let size = try XCTUnwrap(backend.lastConfiguration?.pixelSize)
        XCTAssertEqual(size, WindowPeekPixelSize(width: 6016, height: 3384))
    }

    private func makeToken() -> WindowPeekCaptureRequestToken {
        WindowPeekCaptureRequestToken(
            sessionEpoch: 1,
            peekGeneration: 1,
            windowID: PreviewWindowID(pid: 100, windowID: 7)
        )
    }
}

@MainActor
private final class TestCaptureSource: WindowPeekCaptureSource {
    let windowID: PreviewWindowID

    init(windowID: PreviewWindowID) {
        self.windowID = windowID
    }
}

@MainActor
private final class RecordingWindowPeekCaptureBackend: WindowPeekCaptureBackend {
    private(set) var callCount = 0
    private(set) var lastConfiguration: WindowPeekCaptureConfiguration?
    private let result: Result<CGImage, Error>

    init(result: Result<CGImage, Error> = .failure(WindowPeekCaptureBackendError.unavailable)) {
        self.result = result
    }

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: any WindowPeekCaptureSource,
        configuration: WindowPeekCaptureConfiguration
    ) async throws -> CGImage {
        callCount += 1
        lastConfiguration = configuration
        return try result.get()
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) {}
}

private enum TestCaptureError: Error {
    case failed
}

private func makeImage(width: Int = 2, height: Int = 2) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

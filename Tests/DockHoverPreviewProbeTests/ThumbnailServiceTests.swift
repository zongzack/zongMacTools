import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class ThumbnailServiceTests: XCTestCase {
    func testThumbnailCacheExpiresAfterTenSeconds() async {
        let logger = ProbeLogger()
        var now: CFAbsoluteTime = 100
        var captureCount = 0
        let service = StaticThumbnailService(
            logger: logger,
            now: { now },
            captureWithScreenCaptureKit: { _ in nil },
            captureWithCoreGraphics: { _ in
                captureCount += 1
                return Self.makeImage(width: 2 + captureCount, height: 2)
            }
        )
        let window = makeWindow()

        let first = await service.thumbnail(for: window)
        now += 9
        let second = await service.thumbnail(for: window)
        now += 2
        let third = await service.thumbnail(for: window)

        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
        XCTAssertFalse(first === third)
        XCTAssertEqual(captureCount, 2)
    }

    func testThumbnailSuccessLogsCoreGraphicsMethodAndFailureLogsCGFallback() async {
        let logger = ProbeLogger()
        let successService = StaticThumbnailService(
            logger: logger,
            captureWithScreenCaptureKit: { _ in nil },
            captureWithCoreGraphics: { _ in Self.makeImage(width: 3, height: 4) }
        )
        _ = await successService.thumbnail(for: makeWindow(windowID: 11))

        let failureService = StaticThumbnailService(
            logger: logger,
            captureWithScreenCaptureKit: { _ in nil },
            captureWithCoreGraphics: { _ in nil }
        )
        _ = await failureService.thumbnail(for: makeWindow(windowID: 12))

        let logs = logger.snapshot().joined(separator: "\n")
        XCTAssertTrue(logs.contains("thumbnail.success id=11 method=coreGraphics width=3 height=4"))
        XCTAssertTrue(logs.contains("thumbnail.cgFailed id=12"))
    }

    func testThumbnailSuccessLogsScreenCaptureKitMethod() async {
        let logger = ProbeLogger()
        let service = StaticThumbnailService(
            logger: logger,
            captureWithScreenCaptureKit: { _ in Self.makeImage(width: 5, height: 6) },
            captureWithCoreGraphics: { _ in XCTFail("CoreGraphics fallback should not run after SCK success"); return nil }
        )

        _ = await service.thumbnail(for: makeWindow(windowID: 13))

        XCTAssertTrue(logger.snapshot().joined(separator: "\n").contains("thumbnail.success id=13 method=sck width=5 height=6"))
    }

    private func makeWindow(windowID: CGWindowID = 10) -> PreviewWindow {
        PreviewWindow(
            id: PreviewWindowID(pid: getpid(), windowID: windowID),
            cgWindowID: windowID,
            app: NSRunningApplication.current,
            title: "Window \(windowID)",
            frame: CGRect(x: 0, y: 0, width: 640, height: 480),
            scWindow: nil,
            axElement: nil,
            appIcon: NSImage(size: NSSize(width: 32, height: 32)),
            thumbnailSource: nil
        )
    }

    private static func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}

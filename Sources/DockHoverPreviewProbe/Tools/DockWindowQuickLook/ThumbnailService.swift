import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

@MainActor
protocol ThumbnailService: AnyObject {
    func thumbnail(for window: PreviewWindow) async -> CGImage?
}

@MainActor
final class StaticThumbnailService: ThumbnailService {
    private struct CacheEntry {
        let image: CGImage
        let capturedAt: CFAbsoluteTime
    }

    private enum CaptureMethod: String {
        case screenCaptureKit = "sck"
        case coreGraphics
    }

    private let logger: ProbeLogger
    private let now: () -> CFAbsoluteTime
    private let captureBroker: ScreenCaptureKitCaptureBroker?
    private let captureWithScreenCaptureKitOverride: (@MainActor (PreviewWindow) async -> CGImage?)?
    private let captureWithCoreGraphicsOverride: (@MainActor (PreviewWindow) -> CGImage?)?
    private var cache: [ThumbnailCacheKey: CacheEntry] = [:]

    init(logger: ProbeLogger, captureBroker: ScreenCaptureKitCaptureBroker) {
        self.logger = logger
        self.now = CFAbsoluteTimeGetCurrent
        self.captureBroker = captureBroker
        self.captureWithScreenCaptureKitOverride = nil
        self.captureWithCoreGraphicsOverride = nil
    }

    init(
        logger: ProbeLogger,
        now: @escaping () -> CFAbsoluteTime = CFAbsoluteTimeGetCurrent,
        captureWithScreenCaptureKit: (@MainActor (PreviewWindow) async -> CGImage?)? = nil,
        captureWithCoreGraphics: (@MainActor (PreviewWindow) -> CGImage?)? = nil
    ) {
        self.logger = logger
        self.now = now
        self.captureBroker = nil
        self.captureWithScreenCaptureKitOverride = captureWithScreenCaptureKit
        self.captureWithCoreGraphicsOverride = captureWithCoreGraphics
    }

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        let key = ThumbnailCacheKey(id: window.id, captureFrame: window.captureFrame, title: window.title)
        if let cached = cachedImage(for: key, now: now()) {
            logger.info("thumbnail.cacheHit id=\(window.cgWindowID)")
            return cached
        }
        let start = now()
        let result = await capture(window: window)
        let elapsedMS = Int((now() - start) * 1000)
        if let result {
            cacheImage(result.image, for: key, capturedAt: now())
            logger.info("thumbnail.success id=\(window.cgWindowID) method=\(result.method.rawValue) width=\(result.image.width) height=\(result.image.height) elapsedMS=\(elapsedMS)")
        } else {
            logger.warning("thumbnail.failed id=\(window.cgWindowID) elapsedMS=\(elapsedMS)")
        }
        return result?.image
    }

    private func cachedImage(for key: ThumbnailCacheKey, now: CFAbsoluteTime) -> CGImage? {
        guard let entry = cache[key] else { return nil }
        guard now - entry.capturedAt < 10 else {
            cache[key] = nil
            return nil
        }
        return entry.image
    }

    private func cacheImage(_ image: CGImage, for key: ThumbnailCacheKey, capturedAt: CFAbsoluteTime) {
        cache[key] = CacheEntry(image: image, capturedAt: capturedAt)
    }

    private func capture(window: PreviewWindow) async -> (image: CGImage, method: CaptureMethod)? {
        if let image = await captureWithScreenCaptureKit(window: window) {
            return (image, .screenCaptureKit)
        }
        if let image = captureWithCoreGraphics(window: window) {
            return (image, .coreGraphics)
        }
        logger.warning("thumbnail.cgFailed id=\(window.cgWindowID)")
        return nil
    }

    private func captureWithScreenCaptureKit(window: PreviewWindow) async -> CGImage? {
        guard window.thumbnailSource != nil else { return nil }
        if let captureWithScreenCaptureKitOverride {
            return await captureWithScreenCaptureKitOverride(window)
        }
        let filter: SCContentFilter
        let configuration = SCStreamConfiguration()
        configuration.width = 440
        configuration.height = 248
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        switch window.thumbnailSource {
        case .screenCaptureKit(let scWindow):
            filter = SCContentFilter(desktopIndependentWindow: scWindow)
        case .coreGraphics, nil:
            return nil
        }
        guard let captureBroker else {
            preconditionFailure("ScreenCaptureKit thumbnail capture requires the app-wide broker")
        }
        do {
            return try await captureBroker.captureThumbnail {
                try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
            }
        } catch {
            logger.warning("thumbnail.sckFailed id=\(window.cgWindowID) error=\(error)")
            return nil
        }
    }

    private func captureWithCoreGraphics(window: PreviewWindow) -> CGImage? {
        guard let thumbnailSource = window.thumbnailSource else { return nil }
        if let captureWithCoreGraphicsOverride {
            return captureWithCoreGraphicsOverride(window)
        }
        let windowID: CGWindowID
        switch thumbnailSource {
        case .screenCaptureKit:
            windowID = window.cgWindowID
        case .coreGraphics(let cgWindowID):
            windowID = cgWindowID
        }
        let array = [NSNumber(value: windowID)] as CFArray
        return CGImage(
            windowListFromArrayScreenBounds: .null,
            windowArray: array,
            imageOption: [.boundsIgnoreFraming, .bestResolution]
        )
    }
}

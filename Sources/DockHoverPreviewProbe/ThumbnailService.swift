import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

protocol ThumbnailService: Sendable {
    func thumbnail(for window: PreviewWindow) async -> CGImage?
}

final class StaticThumbnailService: ThumbnailService, @unchecked Sendable {
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
    private let captureWithScreenCaptureKitOverride: ((PreviewWindow) async -> CGImage?)?
    private let captureWithCoreGraphicsOverride: ((PreviewWindow) -> CGImage?)?
    private let cacheLock = NSLock()
    private var cache: [ThumbnailCacheKey: CacheEntry] = [:]

    init(logger: ProbeLogger) {
        self.logger = logger
        self.now = CFAbsoluteTimeGetCurrent
        self.captureWithScreenCaptureKitOverride = nil
        self.captureWithCoreGraphicsOverride = nil
    }

    init(
        logger: ProbeLogger,
        now: @escaping () -> CFAbsoluteTime = CFAbsoluteTimeGetCurrent,
        captureWithScreenCaptureKit: ((PreviewWindow) async -> CGImage?)? = nil,
        captureWithCoreGraphics: ((PreviewWindow) -> CGImage?)? = nil
    ) {
        self.logger = logger
        self.now = now
        self.captureWithScreenCaptureKitOverride = captureWithScreenCaptureKit
        self.captureWithCoreGraphicsOverride = captureWithCoreGraphics
    }

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        let key = ThumbnailCacheKey(id: window.id, frame: window.frame, title: window.title)
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
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let entry = cache[key] else { return nil }
        guard now - entry.capturedAt < 10 else {
            cache[key] = nil
            return nil
        }
        return entry.image
    }

    private func cacheImage(_ image: CGImage, for key: ThumbnailCacheKey, capturedAt: CFAbsoluteTime) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
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
        if let captureWithScreenCaptureKitOverride {
            return await captureWithScreenCaptureKitOverride(window)
        }
        guard case let .screenCaptureKit(scWindow)? = window.thumbnailSource else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = 440
        configuration.height = 248
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            logger.warning("thumbnail.sckFailed id=\(window.cgWindowID) error=\(error)")
            return nil
        }
    }

    private func captureWithCoreGraphics(window: PreviewWindow) -> CGImage? {
        if let captureWithCoreGraphicsOverride {
            return captureWithCoreGraphicsOverride(window)
        }
        let array = [NSNumber(value: window.cgWindowID)] as CFArray
        return CGImage(
            windowListFromArrayScreenBounds: .null,
            windowArray: array,
            imageOption: [.boundsIgnoreFraming, .bestResolution]
        )
    }
}

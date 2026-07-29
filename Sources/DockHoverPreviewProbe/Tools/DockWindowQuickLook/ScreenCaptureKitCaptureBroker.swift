import CoreGraphics
import Foundation

enum WindowPeekCaptureBrokerError: Error, Equatable {
    case superseded
}

@MainActor
final class ScreenCaptureKitCaptureBroker {
    private enum Origin: String {
        case thumbnail
        case desktopPeek
    }

    private final class Entry {
        let origin: Origin
        let token: WindowPeekCaptureRequestToken?
        let operation: @MainActor () async throws -> CGImage
        let continuation: CheckedContinuation<CGImage, Error>

        init(
            origin: Origin,
            token: WindowPeekCaptureRequestToken?,
            operation: @escaping @MainActor () async throws -> CGImage,
            continuation: CheckedContinuation<CGImage, Error>
        ) {
            self.origin = origin
            self.token = token
            self.operation = operation
            self.continuation = continuation
        }
    }

    private let logger: ProbeLogger
    private var activeEntry: Entry?
    private var thumbnailEntries: [Entry] = []
    private var queuedDesktopPeek: Entry?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func captureThumbnail(
        operation: @MainActor @escaping () async throws -> CGImage
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            thumbnailEntries.append(
                Entry(
                    origin: .thumbnail,
                    token: nil,
                    operation: operation,
                    continuation: continuation
                )
            )
            startNextCaptureIfIdle()
        }
    }

    func captureDesktopPeek(
        token: WindowPeekCaptureRequestToken,
        operation: @MainActor @escaping () async throws -> CGImage
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            if let queuedDesktopPeek {
                queuedDesktopPeek.continuation.resume(throwing: WindowPeekCaptureBrokerError.superseded)
            }
            queuedDesktopPeek = Entry(
                origin: .desktopPeek,
                token: token,
                operation: operation,
                continuation: continuation
            )
            startNextCaptureIfIdle()
        }
    }

    func invalidateQueuedDesktopPeek(token: WindowPeekCaptureRequestToken) {
        guard queuedDesktopPeek?.token == token else { return }
        let entry = queuedDesktopPeek
        queuedDesktopPeek = nil
        entry?.continuation.resume(throwing: WindowPeekCaptureBrokerError.superseded)
    }

    private func startNextCaptureIfIdle() {
        guard activeEntry == nil else { return }

        let entry: Entry?
        if let queuedDesktopPeek {
            self.queuedDesktopPeek = nil
            entry = queuedDesktopPeek
        } else if !thumbnailEntries.isEmpty {
            entry = thumbnailEntries.removeFirst()
        } else {
            entry = nil
        }
        guard let entry else { return }

        activeEntry = entry
        let start = CFAbsoluteTimeGetCurrent()
        logger.info(logLine(prefix: "started", entry: entry, elapsedMS: nil, result: "pending", image: nil))
        Task { @MainActor in
            do {
                let image = try await entry.operation()
                finish(entry: entry, start: start, result: .success(image))
            } catch {
                finish(entry: entry, start: start, result: .failure(error))
            }
        }
    }

    private func finish(
        entry: Entry,
        start: CFAbsoluteTime,
        result: Result<CGImage, Error>
    ) {
        guard activeEntry === entry else { return }
        activeEntry = nil
        let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        switch result {
        case let .success(image):
            logger.info(logLine(prefix: "finished", entry: entry, elapsedMS: elapsedMS, result: "success", image: image))
            entry.continuation.resume(returning: image)
        case let .failure(error):
            logger.warning(logLine(prefix: "finished", entry: entry, elapsedMS: elapsedMS, result: "failed", image: nil))
            entry.continuation.resume(throwing: error)
        }
        startNextCaptureIfIdle()
    }

    private func logLine(
        prefix: String,
        entry: Entry,
        elapsedMS: Int?,
        result: String,
        image: CGImage?
    ) -> String {
        let token = entry.token.map {
            " sessionEpoch=\($0.sessionEpoch) peekGeneration=\($0.peekGeneration) windowID=\($0.windowID.windowID)"
        } ?? ""
        let elapsed = " elapsedMS=\(elapsedMS ?? 0)"
        let size = image.map { " width=\($0.width) height=\($0.height)" } ?? " width=unknown height=unknown"
        return "sck.broker.capture.\(prefix) origin=\(entry.origin.rawValue)\(token) result=\(result)\(size)\(elapsed)"
    }
}

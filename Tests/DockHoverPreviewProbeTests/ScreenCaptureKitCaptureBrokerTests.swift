import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class ScreenCaptureKitCaptureBrokerTests: XCTestCase {
    func testQueuedDesktopPeeksKeepOnlyLatestWhileThumbnailIsActive() async {
        let broker = ScreenCaptureKitCaptureBroker(logger: ProbeLogger())
        let recorder = PhysicalCaptureRecorder()
        let thumbnailGate = CaptureGate()
        let thumbnail = Task { @MainActor () -> Result<CGImage, Error> in
            do {
                return .success(try await broker.captureThumbnail {
                    recorder.start("thumbnailA")
                    await thumbnailGate.waitForRelease()
                    recorder.finish("thumbnailA")
                    return makeBrokerImage()
                })
            } catch {
                return .failure(error)
            }
        }
        await thumbnailGate.waitUntilStarted()

        let firstToken = makeToken(generation: 1)
        let secondToken = makeToken(generation: 2)
        let latestToken = makeToken(generation: 3)
        let firstPeek = captureDesktopPeek(broker, token: firstToken) {
            XCTFail("Superseded desktop peek must not start")
            return makeBrokerImage()
        }
        let secondPeek = captureDesktopPeek(broker, token: secondToken) {
            XCTFail("Superseded desktop peek must not start")
            return makeBrokerImage()
        }
        let latestPeek = captureDesktopPeek(broker, token: latestToken) {
            recorder.start("desktopC")
            recorder.finish("desktopC")
            return makeBrokerImage()
        }

        thumbnailGate.release()

        let thumbnailResult = await thumbnail.value
        let latestResult = await latestPeek.value
        let firstResult = await firstPeek.value
        let secondResult = await secondPeek.value
        XCTAssertTrue(thumbnailResult.isSuccess)
        XCTAssertTrue(latestResult.isSuccess)
        XCTAssertTrue(firstResult.isSuperseded)
        XCTAssertTrue(secondResult.isSuperseded)
        XCTAssertEqual(recorder.events, ["start thumbnailA", "finish thumbnailA", "start desktopC", "finish desktopC"])
        XCTAssertEqual(recorder.maximumPhysicalInFlight, 1)
    }

    func testActiveDesktopPeekDoesNotCancelAndThumbnailsResumeInFIFOOrder() async {
        let broker = ScreenCaptureKitCaptureBroker(logger: ProbeLogger())
        let recorder = PhysicalCaptureRecorder()
        let desktopGate = CaptureGate()
        let token = makeToken(generation: 1)
        let desktopPeek = captureDesktopPeek(broker, token: token) {
            recorder.start("desktopA")
            await desktopGate.waitForRelease()
            recorder.finish("desktopA")
            return makeBrokerImage()
        }
        await desktopGate.waitUntilStarted()
        broker.invalidateQueuedDesktopPeek(token: token)

        let thumbnailB = captureThumbnail(broker, name: "thumbnailB", recorder: recorder)
        let thumbnailC = captureThumbnail(broker, name: "thumbnailC", recorder: recorder)
        XCTAssertEqual(recorder.events, ["start desktopA"])

        desktopGate.release()

        let desktopResult = await desktopPeek.value
        let thumbnailBResult = await thumbnailB.value
        let thumbnailCResult = await thumbnailC.value
        XCTAssertTrue(desktopResult.isSuccess)
        XCTAssertTrue(thumbnailBResult.isSuccess)
        XCTAssertTrue(thumbnailCResult.isSuccess)
        XCTAssertEqual(
            recorder.events,
            ["start desktopA", "finish desktopA", "start thumbnailB", "finish thumbnailB", "start thumbnailC", "finish thumbnailC"]
        )
        XCTAssertEqual(recorder.maximumPhysicalInFlight, 1)
    }

    private func captureDesktopPeek(
        _ broker: ScreenCaptureKitCaptureBroker,
        token: WindowPeekCaptureRequestToken,
        operation: @escaping @MainActor () async throws -> CGImage
    ) -> Task<Result<CGImage, Error>, Never> {
        Task { @MainActor in
            do {
                return .success(try await broker.captureDesktopPeek(token: token, operation: operation))
            } catch {
                return .failure(error)
            }
        }
    }

    private func captureThumbnail(
        _ broker: ScreenCaptureKitCaptureBroker,
        name: String,
        recorder: PhysicalCaptureRecorder
    ) -> Task<Result<CGImage, Error>, Never> {
        Task { @MainActor in
            do {
                return .success(try await broker.captureThumbnail {
                    recorder.start(name)
                    recorder.finish(name)
                    return makeBrokerImage()
                })
            } catch {
                return .failure(error)
            }
        }
    }

    private func makeToken(generation: UInt64) -> WindowPeekCaptureRequestToken {
        WindowPeekCaptureRequestToken(
            sessionEpoch: 1,
            peekGeneration: generation,
            windowID: PreviewWindowID(pid: 100, windowID: CGWindowID(generation))
        )
    }
}

@MainActor
private final class CaptureGate {
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func waitForRelease() async {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor
private final class PhysicalCaptureRecorder {
    private(set) var events: [String] = []
    private var physicalInFlight = 0
    private(set) var maximumPhysicalInFlight = 0

    func start(_ name: String) {
        physicalInFlight += 1
        maximumPhysicalInFlight = max(maximumPhysicalInFlight, physicalInFlight)
        events.append("start \(name)")
    }

    func finish(_ name: String) {
        events.append("finish \(name)")
        physicalInFlight -= 1
    }
}

private func makeBrokerImage() -> CGImage {
    let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

private extension Result where Success == CGImage, Failure == Error {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isSuperseded: Bool {
        guard case let .failure(error) = self,
              let brokerError = error as? WindowPeekCaptureBrokerError,
              brokerError == .superseded
        else {
            return false
        }
        return true
    }
}

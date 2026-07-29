import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class WindowPeekModelsTests: XCTestCase {
    func testValueContractsPreserveGeometryCaptureAndRequestIdentity() {
        let screen = WindowPeekScreen(
            identifier: 7,
            localizedName: "Main",
            captureFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            appKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            backingScaleFactor: 2
        )
        let layout = WindowPeekLayout(
            screen: screen,
            dimmingFrame: screen.appKitFrame,
            mirrorFrame: CGRect(x: 120, y: 180, width: 640, height: 400),
            windowCaptureFrame: CGRect(x: 120, y: 320, width: 640, height: 400),
            windowAppKitFrame: CGRect(x: 120, y: 180, width: 640, height: 400),
            pointCropRect: CGRect(x: 0, y: 0, width: 640, height: 400)
        )
        let configuration = WindowPeekCaptureConfiguration(
            pixelSize: WindowPeekPixelSize(width: 1280, height: 800),
            showsCursor: false,
            ignoresSingleWindowShadow: true
        )
        let token = WindowPeekCaptureRequestToken(
            sessionEpoch: 3,
            peekGeneration: 5,
            windowID: PreviewWindowID(pid: 42, windowID: 99)
        )

        XCTAssertEqual(WindowPeekImageQuality.highResolution.rawValue, 1)
        XCTAssertEqual(layout.screen, screen)
        XCTAssertEqual(layout.pointCropRect.size, CGSize(width: 640, height: 400))
        XCTAssertEqual(configuration.pixelSize, WindowPeekPixelSize(width: 1280, height: 800))
        XCTAssertEqual(token.sessionEpoch, 3)
        XCTAssertEqual(token.peekGeneration, 5)
        XCTAssertEqual(token.windowID, PreviewWindowID(pid: 42, windowID: 99))
        XCTAssertEqual(WindowPeekStopReason.activeSpaceChanged.rawValue, "activeSpaceChanged")
    }
}

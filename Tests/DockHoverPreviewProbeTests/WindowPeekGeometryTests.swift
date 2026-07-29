import CoreGraphics
import Foundation
import XCTest
@testable import DockHoverPreviewProbe

final class WindowPeekGeometryTests: XCTestCase {
    func testSelectsLargestCaptureIntersectionAndMapsFragmentToAppKit() throws {
        let screens = [
            WindowPeekScreen(
                identifier: 1,
                localizedName: "Main",
                captureFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                appKitFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                backingScaleFactor: 2
            ),
            WindowPeekScreen(
                identifier: 2,
                localizedName: "Right",
                captureFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
                appKitFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
                backingScaleFactor: 1
            )
        ]

        let layout = try XCTUnwrap(WindowPeekGeometry.layout(
            windowCaptureFrame: CGRect(x: 900, y: 100, width: 900, height: 600),
            screens: screens
        ))

        XCTAssertEqual(layout.screen.identifier, 2)
        XCTAssertEqual(layout.dimmingFrame, screens[1].appKitFrame)
        XCTAssertEqual(layout.windowAppKitFrame, CGRect(x: 900, y: 200, width: 900, height: 600))
        XCTAssertEqual(layout.mirrorFrame, CGRect(x: 1200, y: 200, width: 600, height: 600))
        XCTAssertEqual(layout.pointCropRect, CGRect(x: 300, y: 0, width: 600, height: 600))
    }

    func testMapsTopAlignedCaptureFragmentToAppKitWithoutUsingGlobalYOrigin() {
        let screen = WindowPeekScreen(
            identifier: 7,
            localizedName: "Above",
            captureFrame: CGRect(x: -600, y: -900, width: 1200, height: 900),
            appKitFrame: CGRect(x: -600, y: 900, width: 1200, height: 900),
            backingScaleFactor: 1
        )

        XCTAssertEqual(
            WindowPeekGeometry.appKitRect(
                for: CGRect(x: -500, y: -800, width: 300, height: 200),
                on: screen
            ),
            CGRect(x: -500, y: 1500, width: 300, height: 200)
        )
    }

    func testPixelCropUsesReturnedImageSizeAndTopLeftImageRows() throws {
        let pixelRect = try XCTUnwrap(WindowPeekGeometry.pixelCropRect(
            pointCropRect: CGRect(x: 300, y: 150, width: 600, height: 300),
            windowCaptureSize: CGSize(width: 900, height: 600),
            imagePixelSize: WindowPeekPixelSize(width: 1200, height: 800)
        ))

        XCTAssertEqual(pixelRect, CGRect(x: 400, y: 200, width: 800, height: 400))
    }

    func testPixelCropFloorsMinsCeilsMaxesAndClamps() throws {
        let pixelRect = try XCTUnwrap(WindowPeekGeometry.pixelCropRect(
            pointCropRect: CGRect(x: -1.2, y: 1.1, width: 11.4, height: 7.6),
            windowCaptureSize: CGSize(width: 10, height: 10),
            imagePixelSize: WindowPeekPixelSize(width: 20, height: 20)
        ))

        XCTAssertEqual(pixelRect, CGRect(x: 0, y: 2, width: 20, height: 16))
    }

    func testCroppedImageKeepsTopLeftPixelRowDirection() throws {
        let image = makeTwoBandImage(top: .red, bottom: .blue, width: 4, height: 4)
        let layout = makeLayout(pointCropRect: CGRect(x: 0, y: 0, width: 4, height: 2))

        let cropped = try XCTUnwrap(WindowPeekGeometry.croppedImage(image, layout: layout))

        XCTAssertEqual(pixelColor(atX: 0, y: 0, in: cropped), TestPixelColor.red)
        XCTAssertEqual(pixelColor(atX: 0, y: 1, in: cropped), TestPixelColor.red)
    }

    func testPairsSCDisplayPointFrameWithAppKitScreenByDisplayID() {
        let screens = WindowPeekGeometry.makeScreens(
            captureDisplays: [
                WindowPeekCaptureDisplay(identifier: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
                WindowPeekCaptureDisplay(identifier: 2, frame: CGRect(x: -1080, y: 0, width: 1080, height: 1920))
            ],
            appKitDisplays: [
                WindowPeekAppKitDisplay(identifier: 2, localizedName: "Left", frame: CGRect(x: -1080, y: 0, width: 1080, height: 1920), backingScaleFactor: 1),
                WindowPeekAppKitDisplay(identifier: 1, localizedName: "Built-in", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), backingScaleFactor: 2)
            ]
        )

        XCTAssertEqual(screens.map(\.identifier), [1, 2])
        XCTAssertEqual(screens[0].captureFrame.size, CGSize(width: 1512, height: 982))
        XCTAssertEqual(screens[0].backingScaleFactor, 2)
    }

    func testCaptureSizePreservesNativeRetinaPixelDimensions() {
        let size = WindowPeekGeometry.capturePixelSize(
            logicalSize: CGSize(width: 3008, height: 1692),
            backingScaleFactor: 2
        )

        XCTAssertEqual(size, WindowPeekPixelSize(width: 6016, height: 3384))
        XCTAssertGreaterThan(size.width * size.height, 8_000_000)
    }

    private func makeLayout(pointCropRect: CGRect) -> WindowPeekLayout {
        let screen = WindowPeekScreen(
            identifier: 1,
            localizedName: "Main",
            captureFrame: CGRect(x: 0, y: 0, width: 4, height: 4),
            appKitFrame: CGRect(x: 0, y: 0, width: 4, height: 4),
            backingScaleFactor: 1
        )
        return WindowPeekLayout(
            screen: screen,
            dimmingFrame: screen.appKitFrame,
            mirrorFrame: screen.appKitFrame,
            windowCaptureFrame: screen.captureFrame,
            windowAppKitFrame: screen.appKitFrame,
            pointCropRect: pointCropRect
        )
    }
}

private enum TestPixelColor: Equatable {
    case red
    case blue
}

private func makeTwoBandImage(
    top: TestPixelColor,
    bottom: TestPixelColor,
    width: Int,
    height: Int
) -> CGImage {
    precondition(height.isMultiple(of: 2))
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        let color = y < height / 2 ? top : bottom
        let rgba: (UInt8, UInt8, UInt8, UInt8) = color == .red ? (255, 0, 0, 255) : (0, 0, 255, 255)
        for x in 0 ..< width {
            let offset = (y * width + x) * 4
            bytes[offset] = rgba.0
            bytes[offset + 1] = rgba.1
            bytes[offset + 2] = rgba.2
            bytes[offset + 3] = rgba.3
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

private func pixelColor(atX x: Int, y: Int, in image: CGImage) -> TestPixelColor {
    let providerData = image.dataProvider!.data!
    let bytes = CFDataGetBytePtr(providerData)!
    let offset = y * image.bytesPerRow + x * 4
    return bytes[offset] > bytes[offset + 2] ? .red : .blue
}

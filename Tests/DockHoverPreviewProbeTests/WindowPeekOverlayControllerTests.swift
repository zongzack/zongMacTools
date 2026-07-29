import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowPeekOverlayControllerTests: XCTestCase {
    func testMirrorOverlayIsNonActivatingMouseTransparentAndDoesNotCreateDimmingPanel() throws {
        let controller = WindowPeekOverlayController(logger: ProbeLogger())
        controller.show(image: makeImage(), layout: makeLayout(), quality: .highResolution)
        defer { controller.hide() }

        let inspection = controller.inspection()
        let mirror = try XCTUnwrap(inspection.mirrorPanel)

        XCTAssertTrue(mirror.ignoresMouseEvents)
        XCTAssertFalse(mirror.canBecomeKey)
        XCTAssertFalse(mirror.canBecomeMain)
        XCTAssertNil(inspection.dimmingPanel)
        XCTAssertLessThan(mirror.level.rawValue, NSWindow.Level.floating.rawValue)
        XCTAssertLessThan(mirror.level.rawValue, Int(CGWindowLevelForKey(.dockWindow)))
    }

    func testCoarseImageUsesFullWindowViewOffsetAndMirrorPanelClipping() {
        let controller = WindowPeekOverlayController(logger: ProbeLogger())
        let layout = makeLayout(
            windowAppKitFrame: CGRect(x: 900, y: 200, width: 900, height: 600),
            mirrorFrame: CGRect(x: 1200, y: 200, width: 600, height: 600)
        )
        defer { controller.hide() }

        controller.show(image: makeImage(), layout: layout, quality: .coarse)

        XCTAssertEqual(
            controller.inspection().imageViewFrame,
            CGRect(x: -300, y: 0, width: 900, height: 600)
        )
        XCTAssertTrue(controller.inspection().mirrorContentClips)
    }

    func testHighResolutionImageFillsMirrorBoundsAfterPixelCrop() {
        let controller = WindowPeekOverlayController(logger: ProbeLogger())
        let layout = makeLayout(mirrorFrame: CGRect(x: 1200, y: 200, width: 600, height: 600))
        defer { controller.hide() }

        controller.show(image: makeImage(width: 601, height: 599), layout: layout, quality: .highResolution)

        let inspection = controller.inspection()
        XCTAssertEqual(inspection.imageViewFrame, CGRect(origin: .zero, size: layout.mirrorFrame.size))
        XCTAssertEqual(inspection.imageScaling, .scaleAxesIndependently)
        XCTAssertTrue(inspection.mirrorContentClips)
    }

    func testHighResolutionMirrorFadesInWithEaseOutAnimation() throws {
        let controller = WindowPeekOverlayController(
            logger: ProbeLogger(),
            motionPreferences: OverlayMotionPreferences(shouldReduceMotion: false)
        )
        controller.show(image: makeImage(), layout: makeLayout(), quality: .highResolution)
        defer { controller.hide() }

        let mirror = try XCTUnwrap(controller.inspection().mirrorPanel)
        let layer = try XCTUnwrap(mirror.contentView?.layer)
        let animation = try XCTUnwrap(
            layer.animation(forKey: "dockWindowPeekMirrorAppearance") as? CABasicAnimation
        )

        XCTAssertEqual(animation.keyPath, "opacity")
        XCTAssertEqual(animation.duration, 0.14, accuracy: 0.001)
        XCTAssertNotNil(animation.timingFunction)
    }

    func testReducedMotionShowsHighResolutionMirrorWithoutFadeAnimation() throws {
        let controller = WindowPeekOverlayController(
            logger: ProbeLogger(),
            motionPreferences: OverlayMotionPreferences(shouldReduceMotion: true)
        )
        controller.show(image: makeImage(), layout: makeLayout(), quality: .highResolution)
        defer { controller.hide() }

        let mirror = try XCTUnwrap(controller.inspection().mirrorPanel)
        let layer = try XCTUnwrap(mirror.contentView?.layer)

        XCTAssertNil(layer.animation(forKey: "dockWindowPeekMirrorAppearance"))
    }

    func testUpdateOnlyReplacesImageAndHideClearsReferences() {
        let controller = WindowPeekOverlayController(logger: ProbeLogger())
        let layout = makeLayout()
        controller.show(image: makeImage(width: 2), layout: layout, quality: .coarse)
        controller.update(image: makeImage(width: 4), quality: .highResolution)

        XCTAssertEqual(controller.inspection().logicalMirrorFrame, layout.mirrorFrame)
        XCTAssertEqual(controller.inspection().imagePixelSize, WindowPeekPixelSize(width: 4, height: 2))

        controller.hide()

        let inspection = controller.inspection()
        XCTAssertNil(inspection.logicalMirrorFrame)
        XCTAssertNil(inspection.imagePixelSize)
        XCTAssertFalse(inspection.dimmingPanel?.isVisible == true)
        XCTAssertFalse(inspection.mirrorPanel?.isVisible == true)
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

    private func makeLayout(
        windowAppKitFrame: CGRect = CGRect(x: 900, y: 200, width: 900, height: 600),
        mirrorFrame: CGRect = CGRect(x: 1200, y: 200, width: 600, height: 600)
    ) -> WindowPeekLayout {
        let screen = WindowPeekScreen(
            identifier: 1,
            localizedName: "Test",
            captureFrame: CGRect(x: 0, y: 0, width: 1800, height: 900),
            appKitFrame: CGRect(x: 0, y: 0, width: 1800, height: 900),
            backingScaleFactor: 2
        )
        return WindowPeekLayout(
            screen: screen,
            dimmingFrame: screen.appKitFrame,
            mirrorFrame: mirrorFrame,
            windowCaptureFrame: CGRect(x: 900, y: 100, width: 900, height: 600),
            windowAppKitFrame: windowAppKitFrame,
            pointCropRect: CGRect(x: 300, y: 0, width: 600, height: 600)
        )
    }
}

@MainActor
private struct OverlayMotionPreferences: MotionPreferenceProviding {
    let accessibilityDisplayShouldReduceMotion: Bool

    init(shouldReduceMotion: Bool) {
        accessibilityDisplayShouldReduceMotion = shouldReduceMotion
    }
}

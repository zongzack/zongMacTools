import CoreGraphics

struct WindowPeekCaptureDisplay: Equatable, Sendable {
    let identifier: UInt32
    let frame: CGRect
}

struct WindowPeekAppKitDisplay: Equatable, Sendable {
    let identifier: UInt32
    let localizedName: String?
    let frame: CGRect
    let backingScaleFactor: CGFloat
}

enum WindowPeekGeometry {
    static func makeScreens(
        captureDisplays: [WindowPeekCaptureDisplay],
        appKitDisplays: [WindowPeekAppKitDisplay]
    ) -> [WindowPeekScreen] {
        let captureCounts = Dictionary(grouping: captureDisplays, by: \.identifier)
        let appKitCounts = Dictionary(grouping: appKitDisplays, by: \.identifier)

        return captureDisplays
            .filter { captureCounts[$0.identifier]?.count == 1 }
            .compactMap { captureDisplay in
                guard let appKitDisplay = appKitCounts[captureDisplay.identifier]?.first,
                      appKitCounts[captureDisplay.identifier]?.count == 1,
                      isUsable(captureDisplay.frame),
                      isUsable(appKitDisplay.frame),
                      appKitDisplay.backingScaleFactor > 0
                else {
                    return nil
                }
                return WindowPeekScreen(
                    identifier: captureDisplay.identifier,
                    localizedName: appKitDisplay.localizedName,
                    captureFrame: captureDisplay.frame,
                    appKitFrame: appKitDisplay.frame,
                    backingScaleFactor: appKitDisplay.backingScaleFactor
                )
            }
            .sorted { $0.identifier < $1.identifier }
    }

    static func capturePixelSize(
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) -> WindowPeekPixelSize {
        let logicalWidth = max(logicalSize.width, 1)
        let logicalHeight = max(logicalSize.height, 1)
        let scale = max(backingScaleFactor, 1)
        return WindowPeekPixelSize(
            width: max(1, Int((logicalWidth * scale).rounded(.up))),
            height: max(1, Int((logicalHeight * scale).rounded(.up)))
        )
    }

    static func layout(
        windowCaptureFrame: CGRect,
        screens: [WindowPeekScreen]
    ) -> WindowPeekLayout? {
        guard isUsable(windowCaptureFrame),
              let screenIndex = WindowScreenSelection.largestIntersectionIndex(
                  windowFrame: windowCaptureFrame,
                  screenFrames: screens.map(\.captureFrame)
              )
        else {
            return nil
        }

        let screen = screens[screenIndex]
        let windowAppKitFrame = appKitRect(for: windowCaptureFrame, on: screen)
        let mirrorFrame = windowAppKitFrame.intersection(screen.appKitFrame)
        guard isUsable(mirrorFrame) else {
            return nil
        }

        let mirrorCaptureFrame = captureRect(for: mirrorFrame, on: screen)
        let pointCropRect = mirrorCaptureFrame.offsetBy(
            dx: -windowCaptureFrame.minX,
            dy: -windowCaptureFrame.minY
        )
        guard isUsable(pointCropRect) else {
            return nil
        }

        return WindowPeekLayout(
            screen: screen,
            dimmingFrame: screen.appKitFrame,
            mirrorFrame: mirrorFrame,
            windowCaptureFrame: windowCaptureFrame,
            windowAppKitFrame: windowAppKitFrame,
            pointCropRect: pointCropRect
        )
    }

    static func appKitRect(for captureRect: CGRect, on screen: WindowPeekScreen) -> CGRect {
        CGRect(
            x: screen.appKitFrame.minX + captureRect.minX - screen.captureFrame.minX,
            y: screen.appKitFrame.maxY - (captureRect.maxY - screen.captureFrame.minY),
            width: captureRect.width,
            height: captureRect.height
        )
    }

    static func pixelCropRect(
        pointCropRect: CGRect,
        windowCaptureSize: CGSize,
        imagePixelSize: WindowPeekPixelSize
    ) -> CGRect? {
        guard isUsable(pointCropRect),
              windowCaptureSize.width > 0,
              windowCaptureSize.height > 0,
              imagePixelSize.width > 0,
              imagePixelSize.height > 0
        else {
            return nil
        }

        let scaleX = CGFloat(imagePixelSize.width) / windowCaptureSize.width
        let scaleY = CGFloat(imagePixelSize.height) / windowCaptureSize.height
        let minX = clamp(Int(floor(pointCropRect.minX * scaleX)), to: 0...imagePixelSize.width)
        let minY = clamp(Int(floor(pointCropRect.minY * scaleY)), to: 0...imagePixelSize.height)
        let maxX = clamp(Int(ceil(pointCropRect.maxX * scaleX)), to: 0...imagePixelSize.width)
        let maxY = clamp(Int(ceil(pointCropRect.maxY * scaleY)), to: 0...imagePixelSize.height)
        guard maxX > minX, maxY > minY else {
            return nil
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func croppedImage(_ image: CGImage, layout: WindowPeekLayout) -> CGImage? {
        guard let pixelRect = pixelCropRect(
            pointCropRect: layout.pointCropRect,
            windowCaptureSize: layout.windowCaptureFrame.size,
            imagePixelSize: WindowPeekPixelSize(width: image.width, height: image.height)
        ) else {
            return nil
        }
        return image.cropping(to: pixelRect)
    }

    private static func captureRect(for appKitRect: CGRect, on screen: WindowPeekScreen) -> CGRect {
        CGRect(
            x: screen.captureFrame.minX + appKitRect.minX - screen.appKitFrame.minX,
            y: screen.captureFrame.minY + (screen.appKitFrame.maxY - appKitRect.maxY),
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    private static func isUsable(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isEmpty && frame.width > 0 && frame.height > 0
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

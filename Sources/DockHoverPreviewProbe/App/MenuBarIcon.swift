import AppKit

enum MenuBarIcon {
    static let size = NSSize(width: 18, height: 18)

    private static let backingScale = 2
    private static let sourceLogoFileName = "zong-mac-tools-logo"
    private static let alphaThreshold = 12.0
    fileprivate static let cropThreshold = 20.0
    fileprivate static let cropPaddingRatio = 0.10
    fileprivate static let alphaContrastGamma = 0.25
    fileprivate static let alphaBoostScale = 1.35
    fileprivate static let solidAlphaThreshold = 170.0

    static func makeImage() -> NSImage {
        guard let sourceImage = loadSourceLogoImage() else {
            return makeFallbackImage()
        }
        return makeImage(sourceImage: sourceImage)
    }

    static func makeImage(sourceImage: NSImage) -> NSImage {
        guard
            let sourcePixels = SourcePixels(image: sourceImage, size: pixelSize),
            let image = makeTemplateImage(from: sourcePixels)
        else {
            return makeFallbackImage()
        }
        return image
    }

    private static func loadSourceLogoImage() -> NSImage? {
        for url in sourceLogoCandidateURLs() {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func sourceLogoCandidateURLs() -> [URL] {
        var urls: [URL] = []
        if let bundledURL = Bundle.main.url(forResource: sourceLogoFileName, withExtension: "png") {
            urls.append(bundledURL)
        }

        let packageURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets")
            .appendingPathComponent("AppIcon")
            .appendingPathComponent("\(sourceLogoFileName).png")
        urls.append(packageURL)
        return urls
    }

    private static func makeTemplateImage(from sourcePixels: SourcePixels) -> NSImage? {
        let width = sourcePixels.width
        let height = sourcePixels.height
        let bytesPerRow = width * 4
        var destination = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let alpha = sourcePixels.templateAlpha(x: x, y: y, threshold: alphaThreshold)
                let offset = y * bytesPerRow + x * 4
                destination[offset] = 0
                destination[offset + 1] = 0
                destination[offset + 2] = 0
                destination[offset + 3] = alpha
            }
        }

        let data = Data(destination)
        guard
            let provider = CGDataProvider(data: data as CFData),
            let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: rgbaBitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return nil
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        representation.size = size

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.isTemplate = true
        return image
    }

    private static func makeFallbackImage() -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3.7, y: 14.0))
        path.line(to: NSPoint(x: 15.0, y: 14.0))
        path.line(to: NSPoint(x: 8.5, y: 4.0))
        path.line(to: NSPoint(x: 14.2, y: 4.0))
        path.line(to: NSPoint(x: 13.0, y: 2.0))
        path.line(to: NSPoint(x: 3.6, y: 2.0))
        path.line(to: NSPoint(x: 10.1, y: 12.0))
        path.line(to: NSPoint(x: 5.0, y: 12.0))
        path.close()
        path.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    fileprivate static var rgbaBitmapInfo: CGBitmapInfo {
        CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    }

    private static var pixelSize: NSSize {
        NSSize(width: size.width * CGFloat(backingScale), height: size.height * CGFloat(backingScale))
    }
}

private struct SourcePixels {
    let width: Int
    let height: Int
    private let bytesPerRow: Int
    private let bytes: [UInt8]

    init?(image: NSImage, size: NSSize) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let sourceImage = Self.croppedLogoImage(from: cgImage) ?? cgImage
        let imageWidth = Int(size.width)
        let imageHeight = Int(size.height)
        let rowByteCount = imageWidth * 4
        var buffer = [UInt8](repeating: 0, count: rowByteCount * imageHeight)
        let didDraw = buffer.withUnsafeMutableBytes { pointer -> Bool in
            guard
                let baseAddress = pointer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: imageWidth,
                    height: imageHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: rowByteCount,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: MenuBarIcon.rgbaBitmapInfo.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .high
            context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            return true
        }
        guard didDraw else {
            return nil
        }
        width = imageWidth
        height = imageHeight
        bytesPerRow = rowByteCount
        bytes = buffer
    }

    private static func croppedLogoImage(from image: CGImage) -> CGImage? {
        guard let contentRect = contentRect(in: image) else {
            return nil
        }
        let cropRect = squareCropRect(containing: contentRect, imageWidth: image.width, imageHeight: image.height)
        return image.cropping(to: cropRect)
    }

    private static func contentRect(in image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let didDraw = buffer.withUnsafeMutableBytes { pointer -> Bool in
            guard
                let baseAddress = pointer.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: MenuBarIcon.rgbaBitmapInfo.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else {
            return nil
        }

        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let red = Double(buffer[offset])
                let green = Double(buffer[offset + 1])
                let blue = Double(buffer[offset + 2])
                let sourceAlpha = Double(buffer[offset + 3]) / 255.0
                let luminance = (red * 0.2126 + green * 0.7152 + blue * 0.0722) * sourceAlpha
                guard luminance > MenuBarIcon.cropThreshold else {
                    continue
                }
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minY = Swift.min(minY, y)
                maxY = Swift.max(maxY, y)
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static func squareCropRect(containing rect: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let maxFittingSide = Swift.min(imageWidth, imageHeight)
        let contentSide = Swift.max(rect.width, rect.height)
        let paddedSide = contentSide * (1 + MenuBarIcon.cropPaddingRatio * 2)
        let side = Swift.min(Int(ceil(paddedSide)), maxFittingSide)
        let halfSide = CGFloat(side) / 2
        let centerX = rect.midX
        let centerY = rect.midY
        let maxOriginX = imageWidth - side
        let maxOriginY = imageHeight - side
        let originX = Swift.max(0, Swift.min(Int(floor(centerX - halfSide)), maxOriginX))
        let originY = Swift.max(0, Swift.min(Int(floor(centerY - halfSide)), maxOriginY))
        return CGRect(x: originX, y: originY, width: side, height: side)
    }

    func templateAlpha(x: Int, y: Int, threshold: Double) -> UInt8 {
        let offset = y * bytesPerRow + x * 4
        let red = Double(bytes[offset])
        let green = Double(bytes[offset + 1])
        let blue = Double(bytes[offset + 2])
        let sourceAlpha = Double(bytes[offset + 3]) / 255.0
        let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
        let normalizedLuminance = min(1.0, luminance / 255.0)
        let boostedAlpha = pow(normalizedLuminance, MenuBarIcon.alphaContrastGamma)
            * 255.0
            * sourceAlpha
            * MenuBarIcon.alphaBoostScale
        let alpha = luminance < threshold
            ? 0
            : (boostedAlpha >= MenuBarIcon.solidAlphaThreshold ? 255 : boostedAlpha)
        return UInt8(max(0, min(255, alpha.rounded())))
    }
}

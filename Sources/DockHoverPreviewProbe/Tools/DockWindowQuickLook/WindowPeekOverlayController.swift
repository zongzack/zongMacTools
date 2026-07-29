import AppKit
import CoreGraphics

@MainActor
protocol WindowPeekOverlayDisplaying: AnyObject {
    func show(image: CGImage, layout: WindowPeekLayout, quality: WindowPeekImageQuality)
    func update(image: CGImage, quality: WindowPeekImageQuality)
    func hide()
}

@MainActor
struct WindowPeekOverlayInspection {
    let dimmingPanel: NSPanel?
    let mirrorPanel: NSPanel?
    let logicalMirrorFrame: CGRect?
    let imageViewFrame: CGRect
    let imageScaling: NSImageScaling
    let mirrorContentClips: Bool
    let imagePixelSize: WindowPeekPixelSize?
}

@MainActor
final class WindowPeekOverlayController: WindowPeekOverlayDisplaying {
    private static let mirrorAppearanceAnimationKey = "dockWindowPeekMirrorAppearance"
    private static let mirrorAppearanceDuration: TimeInterval = 0.14

    private let logger: ProbeLogger
    private let motionPreferences: any MotionPreferenceProviding
    private var mirrorPanel: WindowPeekNonKeyPanel?
    private var imageView: NSImageView?
    private var currentLayout: WindowPeekLayout?
    private var currentQuality: WindowPeekImageQuality?
    private var currentImagePixelSize: WindowPeekPixelSize?

    init(
        logger: ProbeLogger,
        motionPreferences: any MotionPreferenceProviding = SystemMotionPreferenceProvider()
    ) {
        self.logger = logger
        self.motionPreferences = motionPreferences
    }

    func show(image: CGImage, layout: WindowPeekLayout, quality: WindowPeekImageQuality) {
        let mirrorPanel = ensureMirrorPanel()
        mirrorPanel.setFrame(layout.mirrorFrame, display: true)
        currentLayout = layout
        apply(image: image, quality: quality, layout: layout)
        animateMirrorAppearance(for: mirrorPanel)
        mirrorPanel.orderFront(nil)
        logger.info("peek.overlay.show quality=\(quality)")
    }

    func update(image: CGImage, quality: WindowPeekImageQuality) {
        guard let currentLayout else { return }
        apply(image: image, quality: quality, layout: currentLayout)
        logger.info("peek.overlay.update quality=\(quality)")
    }

    func hide() {
        cancelMirrorAppearanceAnimation()
        imageView?.image = nil
        mirrorPanel?.orderOut(nil)
        currentLayout = nil
        currentQuality = nil
        currentImagePixelSize = nil
        logger.info("peek.overlay.hide")
    }

    func inspection() -> WindowPeekOverlayInspection {
        WindowPeekOverlayInspection(
            dimmingPanel: nil,
            mirrorPanel: mirrorPanel,
            logicalMirrorFrame: currentLayout?.mirrorFrame,
            imageViewFrame: imageView?.frame ?? .zero,
            imageScaling: imageView?.imageScaling ?? .scaleProportionallyUpOrDown,
            mirrorContentClips: mirrorPanel?.contentView?.layer?.masksToBounds ?? false,
            imagePixelSize: currentImagePixelSize
        )
    }

    private func apply(
        image: CGImage,
        quality: WindowPeekImageQuality,
        layout: WindowPeekLayout
    ) {
        guard let mirrorPanel, let imageView else { return }
        currentQuality = quality
        currentImagePixelSize = WindowPeekPixelSize(width: image.width, height: image.height)
        imageView.image = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )

        switch quality {
        case .coarse:
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.frame = CGRect(
                x: layout.windowAppKitFrame.minX - layout.mirrorFrame.minX,
                y: layout.windowAppKitFrame.minY - layout.mirrorFrame.minY,
                width: layout.windowAppKitFrame.width,
                height: layout.windowAppKitFrame.height
            )
        case .highResolution:
            imageView.imageScaling = .scaleAxesIndependently
            imageView.frame = mirrorPanel.contentView?.bounds ?? CGRect(origin: .zero, size: layout.mirrorFrame.size)
        }
    }

    private func ensureMirrorPanel() -> WindowPeekNonKeyPanel {
        if let mirrorPanel { return mirrorPanel }
        let panel = makePanel(level: WindowPeekPanelLevels.mirror, ignoresMouseEvents: true)
        panel.hasShadow = true
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        let imageView = NSImageView(frame: .zero)
        contentView.addSubview(imageView)
        panel.contentView = contentView
        mirrorPanel = panel
        self.imageView = imageView
        return panel
    }

    private func animateMirrorAppearance(for panel: WindowPeekNonKeyPanel) {
        guard let layer = panel.contentView?.layer else { return }
        layer.removeAnimation(forKey: Self.mirrorAppearanceAnimationKey)
        layer.opacity = 1

        guard !motionPreferences.accessibilityDisplayShouldReduceMotion else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = Self.mirrorAppearanceDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: Self.mirrorAppearanceAnimationKey)
    }

    private func cancelMirrorAppearanceAnimation() {
        guard let layer = mirrorPanel?.contentView?.layer else { return }
        layer.removeAnimation(forKey: Self.mirrorAppearanceAnimationKey)
        layer.opacity = 1
    }

    private func makePanel(
        level: NSWindow.Level,
        ignoresMouseEvents: Bool
    ) -> WindowPeekNonKeyPanel {
        let panel = WindowPeekNonKeyPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.isReleasedWhenClosed = false
        return panel
    }
}

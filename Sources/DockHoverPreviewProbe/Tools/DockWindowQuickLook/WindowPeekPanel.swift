import AppKit

enum WindowPeekPanelLevels {
    static let preview = NSWindow.Level.floating
    static let mirror = NSWindow.Level(rawValue: preview.rawValue - 1)
    static let dimming = NSWindow.Level(rawValue: preview.rawValue - 2)
}

@MainActor
final class WindowPeekNonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

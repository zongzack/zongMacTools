import AppKit

@MainActor
protocol AboutStatusPresenting: AnyObject {
    func showAboutStatus()
}

@MainActor
final class AboutStatusWindowController: NSObject, AboutStatusPresenting {
    private let statusProvider: AppStatusProviding
    private var window: NSWindow?
    private var latestStatusText = ""

    init(statusProvider: AppStatusProviding) {
        self.statusProvider = statusProvider
        super.init()
    }

    func showAboutStatus() {
        let snapshot = statusProvider.snapshot()
        let window = window ?? makeWindow()
        self.window = window
        update(window: window, snapshot: snapshot)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "zongMacTools"
        window.center()
        return window
    }

    private func update(window: NSWindow, snapshot: AppStatusSnapshot) {
        let text = AppTextProvider(language: snapshot.settingsSummary.displayLanguage)
        latestStatusText = snapshot.copyStatusText()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let title = NSTextField(labelWithString: snapshot.appName)
        title.font = .boldSystemFont(ofSize: 22)
        stack.addArrangedSubview(title)

        let status = NSTextField(wrappingLabelWithString: snapshot.copyStatusText())
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        stack.addArrangedSubview(status)

        let button = NSButton(
            title: text.string(.copyStatus),
            target: self,
            action: #selector(copyStatus)
        )
        stack.addArrangedSubview(button)

        window.contentView = stack
    }

    @objc private func copyStatus(_ sender: NSButton) {
        guard !latestStatusText.isEmpty else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestStatusText, forType: .string)
    }
}

@MainActor
final class NoopAboutStatusPresenter: AboutStatusPresenting {
    func showAboutStatus() {}
}

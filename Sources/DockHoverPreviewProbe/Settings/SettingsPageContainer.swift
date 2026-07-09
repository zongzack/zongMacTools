import AppKit
import SwiftUI

struct SettingsPageContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
            .background(SettingsScrollBarTuner())
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsScrollBarTuner: NSViewRepresentable {
    func makeNSView(context _: Context) -> SettingsScrollBarTuningView {
        SettingsScrollBarTuningView()
    }

    func updateNSView(_ nsView: SettingsScrollBarTuningView, context _: Context) {
        nsView.tuneScrollBarsSoon()
    }
}

private final class SettingsScrollBarTuningView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tuneScrollBarsSoon()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        tuneScrollBarsSoon()
    }

    fileprivate func tuneScrollBarsSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.tuneScrollBars()
        }
    }

    private func tuneScrollBars() {
        guard let scrollView = enclosingScrollView else {
            return
        }
        scrollView.verticalScroller?.controlSize = SettingsScrollBarStyle.controlSize
        scrollView.horizontalScroller?.controlSize = SettingsScrollBarStyle.controlSize
    }
}

private enum SettingsScrollBarStyle {
    static let controlSize: NSControl.ControlSize = .mini
}

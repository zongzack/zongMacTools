import AppKit
import SwiftUI

struct AboutStatusSettingsView: View {
    let text: AppTextProvider
    let statusProvider: AppStatusProviding
    @State private var snapshot: AppStatusSnapshot

    init(text: AppTextProvider, statusProvider: AppStatusProviding) {
        self.text = text
        self.statusProvider = statusProvider
        _snapshot = State(initialValue: statusProvider.snapshot())
    }

    private var statusText: String {
        snapshot.copyStatusText(language: text.language)
    }

    var body: some View {
        SettingsPageContainer(
            title: text.string(.aboutStatus),
            subtitle: "zongMacTools"
        ) {
            SettingsGroup {
                VStack(alignment: .leading, spacing: 16) {
                    Text(snapshot.appName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(statusText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(text.string(.copyStatus)) {
                        copyStatus()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            snapshot = statusProvider.snapshot()
        }
    }

    private func copyStatus() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(statusText, forType: .string)
    }
}

import SwiftUI

@MainActor
struct FinderExtensionSettingsView: View {
    @ObservedObject var viewModel: FinderExtensionSettingsViewModel
    let text: AppTextProvider

    var body: some View {
        SettingsPageContainer(
            title: text.string(.contextMenuExtension),
            subtitle: text.string(.finderExtensionSubtitle)
        ) {
            SettingsGroup {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.state.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.state.isEnabled ? .green : .secondary)
                    Text(text.string(viewModel.state.isEnabled ? .finderExtensionEnabled : .finderExtensionDisabled))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Divider()

                Button(text.string(.manageFinderExtension)) {
                    viewModel.openManagementInterface()
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

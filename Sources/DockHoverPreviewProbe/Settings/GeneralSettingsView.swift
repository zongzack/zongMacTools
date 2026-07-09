import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let text: AppTextProvider

    var body: some View {
        SettingsPageContainer(
            title: text.string(.general),
            subtitle: "zongMacTools"
        ) {
            SettingsGroup {
                Picker(
                    text.string(.language),
                    selection: Binding(
                        get: { viewModel.state.displayLanguage },
                        set: { viewModel.setDisplayLanguage($0) }
                    )
                ) {
                    ForEach(DisplayLanguage.allCases, id: \.self) { language in
                        Text(text.languageDisplayName(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(text.string(viewModel.state.launchAtLoginStatus.menuTextKey))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button(text.string(.enableLaunchAtLogin)) {
                            viewModel.enableLaunchAtLogin()
                        }
                        .disabled(!viewModel.state.canEnableLaunchAtLogin)

                        Button(text.string(.disableLaunchAtLogin)) {
                            viewModel.disableLaunchAtLogin()
                        }
                        .disabled(!viewModel.state.canDisableLaunchAtLogin)

                        Button(text.string(.openLoginItemsSettings)) {
                            viewModel.openLaunchAtLoginSettings()
                        }
                        .disabled(!viewModel.state.canOpenLaunchAtLoginSettings)
                    }
                }
            }
        }
    }
}

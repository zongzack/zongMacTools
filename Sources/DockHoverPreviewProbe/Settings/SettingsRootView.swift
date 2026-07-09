import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var selection: SettingsWindowSelection
    let permissionService: PermissionService
    let appStatusProvider: AppStatusProviding
    let diagnosticExportPresenter: DiagnosticExportPresenting

    private var text: AppTextProvider {
        AppTextProvider(language: viewModel.displayLanguage)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 240)
                .frame(maxHeight: .infinity)
                .background(.bar)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 820, minHeight: 540)
    }

    private var sidebar: some View {
        SettingsSidebarView(
            selection: selection,
            text: text,
            tools: [.dockWindowQuickLook, .contextMenuExtensionPlaceholder]
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection.selectedPage {
        case .general:
            GeneralSettingsView(viewModel: viewModel.appSettings, text: text)
        case .dockWindowQuickLook:
            DockWindowQuickLookSettingsView(viewModel: viewModel.dockWindowQuickLookSettings, text: text)
        case .support:
            SupportSettingsView(
                text: text,
                permissionService: permissionService,
                diagnosticExportPresenter: diagnosticExportPresenter
            )
        case .aboutStatus:
            AboutStatusSettingsView(text: text, statusProvider: appStatusProvider)
        }
    }
}

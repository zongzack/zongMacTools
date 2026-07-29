import SwiftUI

@MainActor
struct SupportSettingsView: View {
    let text: AppTextProvider
    let permissionService: PermissionService
    let diagnosticExportPresenter: DiagnosticExportPresenting
    @State private var permissionState: PermissionState

    init(
        text: AppTextProvider,
        permissionService: PermissionService,
        diagnosticExportPresenter: DiagnosticExportPresenting
    ) {
        self.text = text
        self.permissionService = permissionService
        self.diagnosticExportPresenter = diagnosticExportPresenter
        _permissionState = State(initialValue: permissionService.currentState)
    }

    var body: some View {
        SettingsPageContainer(
            title: text.string(.permissionsAndStatus),
            subtitle: "zongMacTools"
        ) {
            SettingsGroup {
                PermissionStatusRow(title: text.accessibilityStatus(granted: permissionState.accessibilityGranted))
                PermissionStatusRow(title: text.screenRecordingStatus(granted: permissionState.screenRecordingGranted))

                Divider()

                HStack(spacing: 10) {
                    Button(text.string(.requestAccessibilityPrompt)) {
                        permissionService.requestAccessibilityPrompt()
                        permissionState = permissionService.currentState
                    }

                    Button(text.string(.openAccessibilitySettings)) {
                        permissionService.openAccessibilitySettings()
                    }

                    Button(text.string(.openScreenRecordingSettings)) {
                        permissionService.openScreenRecordingSettings()
                    }

                    Button(text.string(.refreshPermissions)) {
                        permissionState = permissionService.refresh()
                    }
                }
            }

            SettingsGroup {
                Button(text.string(.exportDiagnostics)) {
                    diagnosticExportPresenter.exportDiagnostics()
                }
            }
        }
    }
}

private struct PermissionStatusRow: View {
    let title: String

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

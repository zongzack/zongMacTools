import FinderSync
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
                PermissionStatusRow(title: finderExtensionStatusText)

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

    private var finderExtensionStatusText: String {
        let enabled = FIFinderSyncController.isExtensionEnabled
        switch text.language {
        case .english:
            return "Right-click Extension: \(enabled ? "Enabled" : "Not Enabled")"
        case .simplifiedChinese:
            return "\u{53F3}\u{952E}\u{6269}\u{5C55}\u{FF1A}\(enabled ? "\u{5DF2}\u{542F}\u{7528}" : "\u{672A}\u{542F}\u{7528}")"
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

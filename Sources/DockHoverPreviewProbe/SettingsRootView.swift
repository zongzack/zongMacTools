import AppKit
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var selection: SettingsWindowSelection
    let permissionService: PermissionService
    let appStatusProvider: AppStatusProviding
    let diagnosticExportPresenter: DiagnosticExportPresenting

    private var text: AppTextProvider {
        AppTextProvider(language: viewModel.state.displayLanguage)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SidebarSection(title: text.string(.settingsSectionApplications)) {
                    SidebarButton(
                        title: text.string(.general),
                        systemImage: "gearshape",
                        isSelected: selection.selectedPage == .general
                    ) {
                        selection.selectedPage = .general
                    }
                }

                SidebarSection(title: text.string(.settingsSectionTools)) {
                    SidebarButton(
                        title: text.string(.dockWindowQuickLook),
                        systemImage: "dock.rectangle",
                        isSelected: selection.selectedPage == .dockWindowQuickLook
                    ) {
                        selection.selectedPage = .dockWindowQuickLook
                    }

                    DisabledSidebarItem(
                        title: text.string(.contextMenuExtension),
                        badge: text.string(.notDeveloped),
                        systemImage: "contextualmenu.and.cursorarrow"
                    )
                }

                SidebarSection(title: text.string(.settingsSectionSupport)) {
                    SidebarButton(
                        title: text.string(.permissionsAndStatus),
                        systemImage: "checkmark.shield",
                        isSelected: selection.selectedPage == .support
                    ) {
                        selection.selectedPage = .support
                    }

                    SidebarButton(
                        title: text.string(.aboutStatus),
                        systemImage: "info.circle",
                        isSelected: selection.selectedPage == .aboutStatus
                    ) {
                        selection.selectedPage = .aboutStatus
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection.selectedPage {
        case .general:
            GeneralSettingsView(viewModel: viewModel, text: text)
        case .dockWindowQuickLook:
            DockWindowQuickLookSettingsView(viewModel: viewModel, text: text)
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

private struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            content
        }
    }
}

private struct SidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(SidebarButtonVisualStyle.selectedBackgroundOpacity)
        }
        if isHovering {
            return Color.primary.opacity(SidebarButtonVisualStyle.hoverBackgroundOpacity)
        }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: SidebarButtonVisualStyle.cornerRadius))
                .scaleEffect(isHovering ? SidebarButtonVisualStyle.hoverScale : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .contentShape(RoundedRectangle(cornerRadius: SidebarButtonVisualStyle.cornerRadius))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: SidebarButtonVisualStyle.animationDuration), value: isHovering)
    }
}

private enum SidebarButtonVisualStyle {
    static let cornerRadius: CGFloat = 6
    static let selectedBackgroundOpacity = 0.16
    static let hoverBackgroundOpacity = 0.05
    static let hoverScale: CGFloat = 1.01
    static let animationDuration = 0.16
}

private struct DisabledSidebarItem: View {
    let title: String
    let badge: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .frame(width: 16)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(badge)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .foregroundStyle(.secondary)
        .opacity(0.72)
    }
}

private struct GeneralSettingsView: View {
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

private struct DockWindowQuickLookSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let text: AppTextProvider

    var body: some View {
        SettingsPageContainer(
            title: text.string(.dockWindowQuickLook),
            subtitle: text.string(.dockWindowQuickLookDescription)
        ) {
            SettingsGroup {
                Toggle(
                    text.string(.dockWindowQuickLook),
                    isOn: Binding(
                        get: { viewModel.state.isDockWindowQuickLookEnabled },
                        set: { isEnabled in
                            if isEnabled != viewModel.state.isDockWindowQuickLookEnabled {
                                viewModel.toggleDockWindowQuickLook()
                            }
                        }
                    )
                )
            }

            SettingsGroup(title: text.string(.performanceAndFeel)) {
                DiscreteSliderRow(
                    title: text.string(.hoverDelay),
                    valueText: "\(viewModel.state.hoverDelayMilliseconds) ms",
                    tickLabels: ["150", "250", "400"],
                    sliderIndex: Binding(
                        get: { viewModel.state.hoverDelaySliderIndex },
                        set: { viewModel.setHoverDelaySliderIndex($0) }
                    )
                )

                Divider()

                DiscreteSliderRow(
                    title: text.string(.panelRetention),
                    valueText: text.panelRetentionDisplayName(viewModel.state.panelRetentionMode),
                    tickLabels: PanelRetentionMode.allCases.map { text.panelRetentionDisplayName($0) },
                    sliderIndex: Binding(
                        get: { viewModel.state.panelRetentionSliderIndex },
                        set: { viewModel.setPanelRetentionSliderIndex($0) }
                    )
                )

                Divider()

                DiscreteSliderRow(
                    title: text.string(.maxCards),
                    valueText: "\(viewModel.state.maxCardCount)",
                    tickLabels: ["3", "5", "8", "12"],
                    sliderIndex: Binding(
                        get: { viewModel.state.maxCardSliderIndex },
                        set: { viewModel.setMaxCardSliderIndex($0) }
                    )
                )
            }

            SettingsGroup(title: text.string(.exclusionRules)) {
                CurrentExclusionTargetView(viewModel: viewModel, text: text)

                Divider()

                ExcludedAppsListView(viewModel: viewModel, text: text)
            }
        }
    }
}

private struct CurrentExclusionTargetView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let text: AppTextProvider

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    viewModel.state.isCurrentExclusionTargetExcluded
                        ? text.string(.includeCurrentApp)
                        : text.string(.excludeCurrentApp)
                )
                if let target = viewModel.state.currentExclusionTarget {
                    Text(text.externalAppName(target.displayName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(text.string(.noExcludableApp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(
                viewModel.state.isCurrentExclusionTargetExcluded
                    ? text.string(.includeCurrentApp)
                    : text.string(.excludeCurrentApp)
            ) {
                viewModel.toggleCurrentExclusionTarget()
            }
            .disabled(viewModel.state.currentExclusionTarget == nil)
        }
    }
}

private struct ExcludedAppsListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let text: AppTextProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text.string(.excludedApps))
                    .font(.headline)
                Spacer()
                Button(text.string(.clearAll)) {
                    viewModel.clearExcludedApps()
                }
                .disabled(viewModel.state.excludedApps.isEmpty)
            }

            if viewModel.state.excludedApps.isEmpty {
                Text(text.string(.noExcludedApps))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.state.excludedApps) { app in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.displayName ?? app.bundleIdentifier)
                                    if app.displayName != nil {
                                        Text(text.bundleIdentifier(app.bundleIdentifier))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    viewModel.removeExcludedApp(bundleIdentifier: app.bundleIdentifier)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help(text.string(.removeExcludedAppHelp))
                            }
                            .padding(.vertical, 6)

                            if app.id != viewModel.state.excludedApps.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }
}

private struct DiscreteSliderRow: View {
    let title: String
    let valueText: String
    let tickLabels: [String]
    @Binding var sliderIndex: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $sliderIndex,
                in: 0...Double(max(tickLabels.count - 1, 0)),
                step: 1
            )

            HStack {
                ForEach(Array(tickLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if label != tickLabels.last {
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct SupportSettingsView: View {
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

private struct AboutStatusSettingsView: View {
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

private struct PermissionStatusRow: View {
    let title: String

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsPageContainer<Content: View>: View {
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

private struct SettingsGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content
    @State private var isHovering = false

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    private var backgroundColor: Color {
        isHovering ? hoverBackgroundColor : baseBackgroundColor
    }

    private var baseBackgroundColor: Color {
        Color(nsColor: .systemGray).opacity(SettingsGroupVisualStyle.baseBackgroundOpacity)
    }

    private var hoverBackgroundColor: Color {
        Color(nsColor: .systemGray).opacity(SettingsGroupVisualStyle.hoverBackgroundOpacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous)
                    .stroke(
                        Color.primary.opacity(
                            isHovering
                                ? SettingsGroupVisualStyle.hoverBorderOpacity
                                : SettingsGroupVisualStyle.borderOpacity
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous))
            .scaleEffect(isHovering ? SettingsGroupVisualStyle.hoverScale : 1)
            .shadow(
                color: Color.black.opacity(isHovering ? SettingsGroupVisualStyle.hoverShadowOpacity : 0),
                radius: isHovering ? SettingsGroupVisualStyle.hoverShadowRadius : 0,
                x: 0,
                y: isHovering ? SettingsGroupVisualStyle.hoverShadowYOffset : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: SettingsGroupVisualStyle.animationDuration), value: isHovering)
        }
    }
}

private enum SettingsGroupVisualStyle {
    static let cornerRadius: CGFloat = 8
    static let baseBackgroundOpacity = 0.13
    static let hoverBackgroundOpacity = 0.18
    static let borderOpacity = 0.05
    static let hoverBorderOpacity = 0.11
    static let hoverShadowOpacity = 0.06
    static let hoverShadowRadius: CGFloat = 8
    static let hoverShadowYOffset: CGFloat = 3
    static let hoverScale: CGFloat = 1.004
    static let animationDuration = 0.18
}

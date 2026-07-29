import SwiftUI

struct DockWindowQuickLookSettingsView: View {
    @ObservedObject var viewModel: DockWindowQuickLookSettingsViewModel
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

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Toggle(
                        text.string(.desktopWindowPeek),
                        isOn: Binding(
                            get: { viewModel.state.isDesktopWindowPeekEnabled },
                            set: { viewModel.setDesktopWindowPeekEnabled($0) }
                        )
                    )
                    .disabled(!viewModel.state.isDesktopWindowPeekControlEnabled)

                    Text(text.string(.desktopWindowPeekDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    @ObservedObject var viewModel: DockWindowQuickLookSettingsViewModel
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
    @ObservedObject var viewModel: DockWindowQuickLookSettingsViewModel
    let text: AppTextProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text.string(.excludedApps))
                    .font(.headline)
                Spacer()
                Button(text.string(.addExcludedApp)) {
                    viewModel.addExcludedAppFromSelection()
                }

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

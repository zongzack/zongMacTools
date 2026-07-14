# Multi-Tool Code Structure Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the current single-tool codebase so `zongMacTools` can add more tools without growing `AppDelegate`, `SettingsRootView`, `SettingsViewModel`, and `AppTextProvider` into catch-all files.

**Architecture:** Keep the existing SwiftPM executable target and all existing `UserDefaults` keys for this refactor. First split files by product responsibility inside the current target, then split the settings UI/view-model/store seams into app-level and Dock Window Quick Look-level units. Introduce only a small settings-navigation registry after those seams are stable; menu/status/content composition stays explicit until a second real tool proves the next abstraction.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, XCTest, macOS 14+.

---

## Scope

This plan is a behavior-preserving structure refactor. It must not rename the SwiftPM package, executable, product, target, app bundle identifier, existing source types, or existing `UserDefaults` keys.

In scope:

- Move source files into app, shared, settings, support, and tool-domain folders under the existing `Sources/DockHoverPreviewProbe` target.
- Split `SettingsRootView.swift` into focused SwiftUI component files.
- Split `SettingsViewModel` into app-level and Dock Window Quick Look-level view models while preserving existing UI behavior.
- Introduce genuinely narrow settings-store protocols backed by the existing UserDefaults implementation, using app-level and Dock-level snapshots instead of duplicating the full store API.
- Add a lightweight settings-navigation registry seam for future tools.
- Keep tests green after each task and commit frequently.

Out of scope:

- Renaming `DockHoverPreviewProbe` package/product/target/executable.
- Changing `CFBundleIdentifier`.
- Changing persisted `UserDefaults` keys.
- Adding the next real tool.
- Replacing the settings UI design.
- Creating a plugin system or multiple SwiftPM targets.

## Current Structure Risks

- `Sources/DockHoverPreviewProbe/AppDelegate.swift` wires every service directly and will keep expanding as tools are added.
- `Sources/DockHoverPreviewProbe/SettingsRootView.swift` contains root navigation, page components, page chrome, scroll-bar tuning, and shared group styling in one file.
- `Sources/DockHoverPreviewProbe/SettingsViewModel.swift` mixes app settings, Launch at Login, Dock Window Quick Look settings, and manual app exclusion intents.
- `Sources/DockHoverPreviewProbe/DockHoverPreviewSettings.swift` mixes app-level `displayLanguage` with Dock Window Quick Look settings, so it should remain in the settings boundary until a later data-model split can be done safely.
- `Sources/DockHoverPreviewProbe/AppTextProvider.swift` has one global enum and switch for every string domain.
- `Sources/DockHoverPreviewProbe/MenuBarController.swift` knows only the Dock Window Quick Look tool status and toggle.

## Target Source Layout

Create these directories inside the current SwiftPM target:

```text
Sources/DockHoverPreviewProbe/
  App/
  Shared/
  Settings/
  Support/
  Tools/
    DockWindowQuickLook/
```

Target responsibility:

- `App/`: app launch, menu bar shell, app composition root, app-level services such as Launch at Login.
- `Shared/`: small reusable helpers and cross-domain models.
- `Settings/`: settings window shell, navigation, page container/group components, app-level settings view model, and the current compatibility settings model/store.
- `Support/`: permissions, diagnostics, about/status.
- `Tools/DockWindowQuickLook/`: everything specific to Dock hover preview behavior, preview UI, window operations, Dock settings UI, and Dock settings view model.

Keep tests in `Tests/DockHoverPreviewProbeTests` for the first pass. Moving tests into mirrored folders can be a later cleanup after the source split is stable.

## Validation Commands

Run these after every task:

```bash
git diff --check
swift test
```

Expected:

- `git diff --check` exits 0 with no output.
- `swift test` exits 0 with all XCTest tests passing.

## Task 1: Move Source Files Into Domain Folders

**Files:**

- Move source files and update only tests that hard-code moved source paths.
- Keep `Sources/DockHoverPreviewProbe/Info.plist` at the target root because `Package.swift` excludes it by relative path.
- Do not move tests in this task.
- Modify: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/AppDelegateWiringTests.swift`

- [ ] **Step 1: Confirm baseline**

Run:

```bash
git status --short --branch
git diff --check
swift test
```

Expected:

- Branch is clean or only contains this plan if the plan was just added.
- `git diff --check` exits 0.
- `swift test` exits 0.

- [ ] **Step 2: Create target directories**

Run:

```bash
mkdir -p Sources/DockHoverPreviewProbe/App
mkdir -p Sources/DockHoverPreviewProbe/Shared
mkdir -p Sources/DockHoverPreviewProbe/Settings
mkdir -p Sources/DockHoverPreviewProbe/Support
mkdir -p Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook
```

Expected: directories exist under `Sources/DockHoverPreviewProbe`.

- [ ] **Step 3: Move app shell files**

Run:

```bash
git mv Sources/DockHoverPreviewProbe/AppDelegate.swift Sources/DockHoverPreviewProbe/App/AppDelegate.swift
git mv Sources/DockHoverPreviewProbe/ProbeApp.swift Sources/DockHoverPreviewProbe/App/ProbeApp.swift
git mv Sources/DockHoverPreviewProbe/MenuBarController.swift Sources/DockHoverPreviewProbe/App/MenuBarController.swift
git mv Sources/DockHoverPreviewProbe/MenuBarIcon.swift Sources/DockHoverPreviewProbe/App/MenuBarIcon.swift
git mv Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift Sources/DockHoverPreviewProbe/App/LaunchAtLoginService.swift
```

Expected: SwiftPM still sees these files because they remain inside the executable target path.

- [ ] **Step 4: Move shared files**

Run:

```bash
git mv Sources/DockHoverPreviewProbe/AppTextProvider.swift Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift
git mv Sources/DockHoverPreviewProbe/BundleIdentifierValidator.swift Sources/DockHoverPreviewProbe/Shared/BundleIdentifierValidator.swift
git mv Sources/DockHoverPreviewProbe/ProbeLogger.swift Sources/DockHoverPreviewProbe/Shared/ProbeLogger.swift
```

Expected: no import changes are needed because all files remain in one target.

- [ ] **Step 5: Move support files**

Run:

```bash
git mv Sources/DockHoverPreviewProbe/PermissionService.swift Sources/DockHoverPreviewProbe/Support/PermissionService.swift
git mv Sources/DockHoverPreviewProbe/DiagnosticExportService.swift Sources/DockHoverPreviewProbe/Support/DiagnosticExportService.swift
git mv Sources/DockHoverPreviewProbe/AppMetadata.swift Sources/DockHoverPreviewProbe/Support/AppMetadata.swift
git mv Sources/DockHoverPreviewProbe/AppStatusSnapshot.swift Sources/DockHoverPreviewProbe/Support/AppStatusSnapshot.swift
git mv Sources/DockHoverPreviewProbe/AboutStatusWindowController.swift Sources/DockHoverPreviewProbe/Support/AboutStatusWindowController.swift
```

Expected: diagnostics, permissions, and about/status code live together.

- [ ] **Step 6: Move settings files**

Run:

```bash
git mv Sources/DockHoverPreviewProbe/SettingsPage.swift Sources/DockHoverPreviewProbe/Settings/SettingsPage.swift
git mv Sources/DockHoverPreviewProbe/SettingsWindowController.swift Sources/DockHoverPreviewProbe/Settings/SettingsWindowController.swift
git mv Sources/DockHoverPreviewProbe/SettingsRootView.swift Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift
git mv Sources/DockHoverPreviewProbe/SettingsViewModel.swift Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift
git mv Sources/DockHoverPreviewProbe/SettingsStore.swift Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift
git mv Sources/DockHoverPreviewProbe/DockHoverPreviewSettings.swift Sources/DockHoverPreviewProbe/Settings/DockHoverPreviewSettings.swift
```

Expected: settings shell and the current compatibility settings model remain behaviorally unchanged.

- [ ] **Step 7: Move Dock Window Quick Look files**

Run:

```bash
git mv Sources/DockHoverPreviewProbe/AXHelpers.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/AXHelpers.swift
git mv Sources/DockHoverPreviewProbe/ActivationService.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ActivationService.swift
git mv Sources/DockHoverPreviewProbe/AppTargetTracker.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/AppTargetTracker.swift
git mv Sources/DockHoverPreviewProbe/DockHoverMonitor.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockHoverMonitor.swift
git mv Sources/DockHoverPreviewProbe/ExcludedAppSelectionPresenter.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ExcludedAppSelectionPresenter.swift
git mv Sources/DockHoverPreviewProbe/GeometryHelpers.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/GeometryHelpers.swift
git mv Sources/DockHoverPreviewProbe/HoverDelayScheduler.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/HoverDelayScheduler.swift
git mv Sources/DockHoverPreviewProbe/PreviewPanelController.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift
git mv Sources/DockHoverPreviewProbe/PreviewPanelLayoutEngine.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelLayoutEngine.swift
git mv Sources/DockHoverPreviewProbe/PreviewPanelModels.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift
git mv Sources/DockHoverPreviewProbe/PreviewPanelView.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift
git mv Sources/DockHoverPreviewProbe/PreviewSessionController.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift
git mv Sources/DockHoverPreviewProbe/ProbeModels.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift
git mv Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeOrchestrator.swift
git mv Sources/DockHoverPreviewProbe/ThumbnailService.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift
git mv Sources/DockHoverPreviewProbe/WindowEnvironmentDescriptor.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowEnvironmentDescriptor.swift
git mv Sources/DockHoverPreviewProbe/WindowOperationService.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowOperationService.swift
git mv Sources/DockHoverPreviewProbe/WindowQueryService.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift
```

Expected: all Dock hover preview implementation files live under the tool domain.

- [ ] **Step 8: Update source-path tests for moved files**

In `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`, update `settingsRootViewSource()` so it reads the moved file:

```swift
private func settingsRootViewSource() throws -> String {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
```

In `Tests/DockHoverPreviewProbeTests/AppDelegateWiringTests.swift`, update `appDelegateSource()` so it reads the moved file:

```swift
private func appDelegateSource() throws -> String {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = packageRoot
        .appendingPathComponent("Sources")
        .appendingPathComponent("DockHoverPreviewProbe")
        .appendingPathComponent("App")
        .appendingPathComponent("AppDelegate.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
```

Expected: tests that inspect moved source files still inspect the same source content at the new paths.

- [ ] **Step 9: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass.

- [ ] **Step 10: Commit**

Run:

```bash
git add -A
git commit -m "Restructure source files by app domain"
```

Expected: one commit containing source moves plus the minimum test path updates required for `swift test` to stay green.

## Task 2: Split SettingsRootView Into Focused View Files

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/GeneralSettingsView.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift`
- Create: `Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift`
- Create: `Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`

- [ ] **Step 1: Write a source-structure test**

Modify `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift` by adding this test next to the other source-shape tests:

```swift
func testSettingsRootViewIsSplitIntoFocusedFiles() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let expectedFiles = [
        "Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift",
        "Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift",
        "Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift",
        "Sources/DockHoverPreviewProbe/Settings/GeneralSettingsView.swift",
        "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift",
        "Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift",
        "Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift"
    ]

    for relativePath in expectedFiles {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path),
            "\(relativePath) should exist"
        )
    }

    let rootSource = try String(
        contentsOf: packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift"),
        encoding: .utf8
    )
    XCTAssertFalse(rootSource.contains("private struct GeneralSettingsView"))
    XCTAssertFalse(rootSource.contains("private struct DockWindowQuickLookSettingsView"))
    XCTAssertFalse(rootSource.contains("private struct SupportSettingsView"))
    XCTAssertFalse(rootSource.contains("private struct AboutStatusSettingsView"))
    XCTAssertFalse(rootSource.contains("private struct SettingsGroup"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SettingsWindowControllerTests/testSettingsRootViewIsSplitIntoFocusedFiles
```

Expected: FAIL because the focused files do not exist yet.

- [ ] **Step 3: Create `SettingsSidebarView.swift`**

Move these types out of `SettingsRootView.swift` into `Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift`:

```swift
import SwiftUI

struct SettingsSidebarView: View {
    @ObservedObject var selection: SettingsWindowSelection
    let text: AppTextProvider

    var body: some View {
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
```

Then replace the `sidebar` computed property in `SettingsRootView.swift` with:

```swift
private var sidebar: some View {
    SettingsSidebarView(selection: selection, text: text)
}
```

- [ ] **Step 4: Move page chrome and group styling**

Create `Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift` with `SettingsPageContainer`, `SettingsScrollBarTuner`, `SettingsScrollBarTuningView`, and `SettingsScrollBarStyle` moved from the current file.

Create `Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift` with `SettingsGroup` and `SettingsGroupVisualStyle` moved from the current file.

Keep `SettingsGroup` without any `.scaleEffect` on hover:

```swift
.clipShape(RoundedRectangle(cornerRadius: SettingsGroupVisualStyle.cornerRadius, style: .continuous))
.shadow(
    color: Color.black.opacity(isHovering ? SettingsGroupVisualStyle.hoverShadowOpacity : 0),
    radius: isHovering ? SettingsGroupVisualStyle.hoverShadowRadius : 0,
    x: 0,
    y: isHovering ? SettingsGroupVisualStyle.hoverShadowYOffset : 0
)
```

- [ ] **Step 5: Move page-specific views**

Move page structs into these files:

- `GeneralSettingsView` to `Sources/DockHoverPreviewProbe/Settings/GeneralSettingsView.swift`
- `DockWindowQuickLookSettingsView`, `CurrentExclusionTargetView`, `ExcludedAppsListView`, and `DiscreteSliderRow` to `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift`
- `SupportSettingsView` and `PermissionStatusRow` to `Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift`
- `AboutStatusSettingsView` to `Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift`

Use the current implementations as the source of truth. Change only top-level access from `private` to internal where another file needs to construct the view.

- [ ] **Step 6: Update existing source-shape tests to read the new files**

In `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`, keep the behavior tests as-is, but update the source-reading helper and the existing source-shape tests so each assertion reads the file that now owns the code.

Replace `settingsRootViewSource()` with these helpers:

```swift
private func settingsRootViewSource() throws -> String {
    try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift")
}

private func source(at relativePath: String) throws -> String {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = packageRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
```

Update `testSettingsGroupsUseStableHoverSurfacesWithoutScale()` so it reads `SettingsGroup.swift`:

```swift
func testSettingsGroupsUseStableHoverSurfacesWithoutScale() throws {
    let source = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsGroup.swift")

    XCTAssertTrue(source.contains("SettingsGroupVisualStyle"))
    XCTAssertTrue(source.contains("hoverBackgroundColor"))
    XCTAssertTrue(source.contains("Color(nsColor: .systemGray)"))
    XCTAssertTrue(source.contains(".onHover"))
    XCTAssertTrue(source.contains(".animation(.easeOut"))
    XCTAssertFalse(source.contains("scaleEffect(isHovering ? SettingsGroupVisualStyle.hoverScale : 1)"))
    XCTAssertFalse(source.contains("SettingsGroupVisualStyle.hoverScale"))
    XCTAssertFalse(source.contains("controlBackgroundColor"))
    XCTAssertFalse(source.contains(".background(.regularMaterial)"))
}
```

Update `testSettingsRootViewEmbedsAboutStatusPageAndUsesThinDetailScrollbars()` so each assertion follows the split ownership:

```swift
func testSettingsRootViewEmbedsAboutStatusPageAndUsesThinDetailScrollbars() throws {
    let rootSource = try settingsRootViewSource()
    let sidebarSource = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift")
    let pageContainerSource = try source(at: "Sources/DockHoverPreviewProbe/Settings/SettingsPageContainer.swift")
    let aboutSource = try source(at: "Sources/DockHoverPreviewProbe/Support/AboutStatusSettingsView.swift")
    let dockSettingsSource = try source(
        at: "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift"
    )

    XCTAssertTrue(sidebarSource.contains("selection.selectedPage == .aboutStatus"))
    XCTAssertTrue(sidebarSource.contains("systemImage: \"info.circle\""))
    XCTAssertTrue(rootSource.contains("case .aboutStatus:"))
    XCTAssertTrue(rootSource.contains("AboutStatusSettingsView("))
    XCTAssertTrue(aboutSource.contains("AppStatusProviding"))
    XCTAssertTrue(aboutSource.contains("statusProvider.snapshot()"))
    XCTAssertTrue(aboutSource.contains("NSPasteboard.general.setString"))
    XCTAssertTrue(pageContainerSource.contains("SettingsScrollBarTuner"))
    XCTAssertTrue(pageContainerSource.contains("static let controlSize: NSControl.ControlSize = .mini"))
    XCTAssertTrue(pageContainerSource.contains(".background(SettingsScrollBarTuner())"))
    XCTAssertTrue(dockSettingsSource.contains("text.string(.removeExcludedAppHelp)"))
    XCTAssertFalse(dockSettingsSource.contains("\"Remove excluded app\""))
}
```

Update `testExcludedAppsHeaderHasAddButtonWiredToViewModelIntent()` so it reads the Dock settings view file:

```swift
func testExcludedAppsHeaderHasAddButtonWiredToViewModelIntent() throws {
    let source = try source(
        at: "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift"
    )

    XCTAssertTrue(source.contains("Button(text.string(.addExcludedApp))"))
    XCTAssertTrue(source.contains("viewModel.addExcludedAppFromSelection()"))
    XCTAssertTrue(source.contains("Button(text.string(.clearAll))"))
    XCTAssertTrue(source.contains(".disabled(viewModel.state.excludedApps.isEmpty)"))
}
```

Expected: the tests still assert the important structure and behavior hooks, but no longer require all page code to stay inside `SettingsRootView.swift`.

- [ ] **Step 7: Run focused test**

Run:

```bash
swift test --filter SettingsWindowControllerTests/testSettingsRootViewIsSplitIntoFocusedFiles
```

Expected: PASS.

- [ ] **Step 8: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass.

- [ ] **Step 9: Commit**

Run:

```bash
git add -A
git commit -m "Split settings window views by responsibility"
```

Expected: one commit containing focused SwiftUI file splits.

## Task 3: Split SettingsViewModel Into App and Dock Tool View Models

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/AppSettingsViewModel.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/GeneralSettingsView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift`
- Modify: `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsWindowController.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`

- [ ] **Step 1: Add source-structure tests**

Add tests to `SettingsViewModelTests.swift`:

```swift
func testSettingsViewModelHasAppAndDockToolChildren() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let appViewModelPath = packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/AppSettingsViewModel.swift")
    let dockViewModelPath = packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift")
    XCTAssertTrue(FileManager.default.fileExists(atPath: appViewModelPath.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: dockViewModelPath.path))

    let rootSource = try String(
        contentsOf: packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift"),
        encoding: .utf8
    )
    XCTAssertTrue(rootSource.contains("let appSettings: AppSettingsViewModel"))
    XCTAssertTrue(rootSource.contains("let dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SettingsViewModelTests/testSettingsViewModelHasAppAndDockToolChildren
```

Expected: FAIL because the child view model files do not exist.

- [ ] **Step 3: Create AppSettingsViewModel**

Create `Sources/DockHoverPreviewProbe/Settings/AppSettingsViewModel.swift`:

```swift
import Combine
import Foundation

struct AppSettingsViewState: Equatable {
    let displayLanguage: DisplayLanguage
    let launchAtLoginStatus: LaunchAtLoginStatus

    var canEnableLaunchAtLogin: Bool {
        launchAtLoginStatus.canEnable
    }

    var canDisableLaunchAtLogin: Bool {
        launchAtLoginStatus.canDisable
    }

    var canOpenLaunchAtLoginSettings: Bool {
        launchAtLoginStatus.canOpenSettings
    }
}

@MainActor
final class AppSettingsViewModel: ObservableObject {
    @Published private(set) var state: AppSettingsViewState

    private let settingsStore: DockHoverPreviewSettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let logger: ProbeLogger
    private var observerToken: UUID?

    init(
        settingsStore: DockHoverPreviewSettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        logger: ProbeLogger
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginService = launchAtLoginService
        self.logger = logger
        self.state = Self.makeState(
            snapshot: settingsStore.snapshot,
            launchAtLoginStatus: launchAtLoginService.status
        )

        observerToken = settingsStore.addObserver { [weak self] snapshot in
            self?.refresh(snapshot: snapshot)
        }
    }

    func refresh() {
        refresh(snapshot: settingsStore.snapshot)
    }

    func setDisplayLanguage(_ language: DisplayLanguage) {
        settingsStore.update { settings in
            settings.displayLanguage = language
        }
    }

    func enableLaunchAtLogin() {
        guard launchAtLoginService.status.canEnable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.enable()
        } catch {
            logger.error("launchAtLogin.enableFailed error=\(error)")
        }
        refresh()
    }

    func disableLaunchAtLogin() {
        guard launchAtLoginService.status.canDisable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.disable()
        } catch {
            logger.error("launchAtLogin.disableFailed error=\(error)")
        }
        refresh()
    }

    func openLaunchAtLoginSettings() {
        guard launchAtLoginService.status.canOpenSettings else {
            refresh()
            return
        }

        launchAtLoginService.openSettings()
        refresh()
    }

    private func refresh(snapshot: DockHoverPreviewSettings) {
        state = Self.makeState(
            snapshot: snapshot,
            launchAtLoginStatus: launchAtLoginService.status
        )
    }

    private static func makeState(
        snapshot: DockHoverPreviewSettings,
        launchAtLoginStatus: LaunchAtLoginStatus
    ) -> AppSettingsViewState {
        AppSettingsViewState(
            displayLanguage: snapshot.displayLanguage,
            launchAtLoginStatus: launchAtLoginStatus
        )
    }
}
```

- [ ] **Step 4: Create DockWindowQuickLookSettingsViewModel**

Create `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift` by moving Dock-specific state and intents out of the current `SettingsViewModel`.

The new state should be:

```swift
struct DockWindowQuickLookSettingsViewState: Equatable {
    let isDockWindowQuickLookEnabled: Bool
    let hoverDelayMilliseconds: Int
    let hoverDelaySliderIndex: Double
    let panelRetentionMode: PanelRetentionMode
    let panelRetentionSliderIndex: Double
    let maxCardCount: Int
    let maxCardSliderIndex: Double
    let displayLanguage: DisplayLanguage
    let excludedApps: [ExcludedAppState]
    let currentExclusionTarget: AppTarget?
    let isCurrentExclusionTargetExcluded: Bool
}
```

Move these methods into `DockWindowQuickLookSettingsViewModel`:

- `refresh()`
- `refreshForSettingsPresentation()`
- `toggleDockWindowQuickLook()`
- `setHoverDelaySliderIndex(_:)`
- `setPanelRetentionSliderIndex(_:)`
- `setMaxCardSliderIndex(_:)`
- `toggleCurrentExclusionTarget()`
- `addExcludedAppFromSelection()`
- `addExcludedApp(_:)`
- `removeExcludedApp(bundleIdentifier:)`
- `clearExcludedApps()`

Preserve existing filtering behavior for manual exclusions:

```swift
guard let bundleIdentifier = BundleIdentifierValidator.sanitized(selection.bundleIdentifier) else {
    logger.warning("settings.excludedAppManualAddSkipped reason=invalidBundleIdentifier")
    return false
}

guard bundleIdentifier != selfBundleIdentifier else {
    logger.info("settings.excludedAppManualAddSkipped reason=self bundle=\(bundleIdentifier)")
    return false
}

guard !settingsStore.snapshot.excludedAppBundleIdentifiers.contains(bundleIdentifier) else {
    logger.info("settings.excludedAppManualAddSkipped reason=duplicate bundle=\(bundleIdentifier)")
    return false
}
```

- [ ] **Step 5: Turn SettingsViewModel into a coordinator**

Replace `SettingsViewModel` with a small coordinator that forwards child model changes so `SettingsRootView` still refreshes sidebar/page text when display language changes:

```swift
import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let appSettings: AppSettingsViewModel
    let dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel

    private var cancellables: Set<AnyCancellable> = []

    var displayLanguage: DisplayLanguage {
        appSettings.state.displayLanguage
    }

    init(
        appSettings: AppSettingsViewModel,
        dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel
    ) {
        self.appSettings = appSettings
        self.dockWindowQuickLookSettings = dockWindowQuickLookSettings

        appSettings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        dockWindowQuickLookSettings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    func refreshForSettingsPresentation() {
        appSettings.refresh()
        dockWindowQuickLookSettings.refreshForSettingsPresentation()
    }
}
```

Update `AppDelegate` to construct `AppSettingsViewModel`, `DockWindowQuickLookSettingsViewModel`, and then `SettingsViewModel`.

Update `SettingsWindowController` title calculation to use the coordinator language property:

```swift
window.title = AppTextProvider(language: settingsViewModel.displayLanguage)
    .string(.settingsWindowTitle)
```

- [ ] **Step 6: Update settings views to observe narrow models**

Update `GeneralSettingsView` so it takes:

```swift
@ObservedObject var viewModel: AppSettingsViewModel
let text: AppTextProvider
```

Update `DockWindowQuickLookSettingsView`, `CurrentExclusionTargetView`, and `ExcludedAppsListView` so they take:

```swift
@ObservedObject var viewModel: DockWindowQuickLookSettingsViewModel
let text: AppTextProvider
```

Update `SettingsRootView` detail switch so `.general` passes `viewModel.appSettings` and `.dockWindowQuickLook` passes `viewModel.dockWindowQuickLookSettings`.

Update `SettingsRootView` text construction so it no longer reads the removed `SettingsViewModel.state`:

```swift
private var text: AppTextProvider {
    AppTextProvider(language: viewModel.displayLanguage)
}
```

Update `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift` so the harness constructs the child view models and the current-exclusion assertions read the Dock child state:

```swift
XCTAssertNil(harness.viewModel.dockWindowQuickLookSettings.state.currentExclusionTarget)

harness.targetTracker.updateLatestHoveredDockApp(
    AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
)
harness.controller.showSettings(selectedPage: .dockWindowQuickLook)

XCTAssertEqual(
    harness.viewModel.dockWindowQuickLookSettings.state.currentExclusionTarget,
    AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
)
```

In the same harness initializer, replace direct construction of `SettingsViewModel(settingsStore:...)` with construction of `AppSettingsViewModel`, `DockWindowQuickLookSettingsViewModel`, and the coordinator.

- [ ] **Step 7: Restore behavior tests**

Update `SettingsViewModelTests` by splitting tests into app-level and Dock-level sections:

- Launch at Login and display language tests construct `AppSettingsViewModel`.
- slider, exclusion, and manual app selection tests construct `DockWindowQuickLookSettingsViewModel`.
- one coordinator test confirms `SettingsViewModel.refreshForSettingsPresentation()` refreshes both children.
- one coordinator publishing test confirms language changes in `AppSettingsViewModel` trigger `SettingsViewModel.objectWillChange`.

Keep the existing behavior assertions. Do not weaken tests to only check source strings.

Add this coordinator publishing test and import Combine if needed:

```swift
func testCoordinatorPublishesWhenAppSettingsChange() async {
    let store = RecordingSettingsStore(snapshot: .defaults)
    let appViewModel = AppSettingsViewModel(
        settingsStore: store,
        launchAtLoginService: FakeLaunchAtLoginService(),
        logger: ProbeLogger()
    )
    let dockViewModel = DockWindowQuickLookSettingsViewModel(
        settingsStore: store,
        targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
        logger: ProbeLogger()
    )
    let coordinator = SettingsViewModel(
        appSettings: appViewModel,
        dockWindowQuickLookSettings: dockViewModel
    )
    let published = expectation(description: "coordinator publishes child changes")
    let cancellable = coordinator.objectWillChange.sink { _ in
        published.fulfill()
    }

    appViewModel.setDisplayLanguage(.simplifiedChinese)

    await fulfillment(of: [published], timeout: 1)
    XCTAssertEqual(coordinator.displayLanguage, .simplifiedChinese)
    withExtendedLifetime(cancellable) {}
}
```

- [ ] **Step 8: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass.

- [ ] **Step 9: Commit**

Run:

```bash
git add -A
git commit -m "Split settings view models by app and tool domain"
```

Expected: one commit with view-model extraction and updated tests.

## Task 4: Introduce Narrow App and Dock Settings Store Protocols

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/AppSettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

- [ ] **Step 1: Add behavior tests for genuinely narrow protocols**

Add to `SettingsStoreTests.swift`:

```swift
func testAppSettingsStoreOnlyMutatesAppSettings() {
    let (defaults, suiteName) = makeTemporaryDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    var initial = DockHoverPreviewSettings.defaults
    initial.isDockHoverPreviewEnabled = false
    initial.hoverDelayMilliseconds = 400
    initial.panelRetentionMode = .forgiving
    initial.maxCardCount = 12
    initial.excludedAppBundleIdentifiers = ["com.example.Editor"]
    initial.displayLanguage = .english
    let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
    store.update { settings in
        settings = initial
    }
    let appStore: AppSettingsStore = store

    appStore.updateAppSettings { settings in
        settings.displayLanguage = .simplifiedChinese
    }

    XCTAssertEqual(appStore.appSettingsSnapshot.displayLanguage, .simplifiedChinese)
    XCTAssertFalse(store.snapshot.isDockHoverPreviewEnabled)
    XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 400)
    XCTAssertEqual(store.snapshot.panelRetentionMode, .forgiving)
    XCTAssertEqual(store.snapshot.maxCardCount, 12)
    XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.example.Editor"])
}

func testDockWindowQuickLookSettingsStoreDoesNotExposeDisplayLanguageMutation() {
    let (defaults, suiteName) = makeTemporaryDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
    let dockStore: DockWindowQuickLookSettingsStore = store

    dockStore.updateDockWindowQuickLookSettings { settings in
        settings.isDockWindowQuickLookEnabled = false
        settings.hoverDelayMilliseconds = 400
        settings.panelRetentionMode = .forgiving
        settings.maxCardCount = 12
        settings.excludedAppBundleIdentifiers = ["com.example.Editor"]
    }

    XCTAssertFalse(dockStore.dockWindowQuickLookSettingsSnapshot.isDockWindowQuickLookEnabled)
    XCTAssertEqual(dockStore.dockWindowQuickLookSettingsSnapshot.displayLanguage, .english)
    XCTAssertEqual(store.snapshot.displayLanguage, .english)
    XCTAssertEqual(defaults.string(forKey: SettingsKey.displayLanguage.rawValue), "en")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SettingsStoreTests/testAppSettingsStoreOnlyMutatesAppSettings
swift test --filter SettingsStoreTests/testDockWindowQuickLookSettingsStoreDoesNotExposeDisplayLanguageMutation
```

Expected: FAIL because the narrow protocols and snapshots do not exist yet.

- [ ] **Step 3: Add narrow snapshots and protocols backed by the existing store**

Modify `Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift` to add:

```swift
struct AppSettingsSnapshot: Equatable, Sendable {
    var displayLanguage: DisplayLanguage

    init(displayLanguage: DisplayLanguage) {
        self.displayLanguage = displayLanguage
    }

    init(settings: DockHoverPreviewSettings) {
        self.displayLanguage = settings.displayLanguage
    }
}

struct DockWindowQuickLookSettingsSnapshot: Equatable, Sendable {
    var isDockWindowQuickLookEnabled: Bool
    var hoverDelayMilliseconds: Int
    var panelRetentionMode: PanelRetentionMode
    var maxCardCount: Int
    var excludedAppBundleIdentifiers: Set<String>
    let displayLanguage: DisplayLanguage

    init(settings: DockHoverPreviewSettings) {
        self.isDockWindowQuickLookEnabled = settings.isDockHoverPreviewEnabled
        self.hoverDelayMilliseconds = settings.hoverDelayMilliseconds
        self.panelRetentionMode = settings.panelRetentionMode
        self.maxCardCount = settings.maxCardCount
        self.excludedAppBundleIdentifiers = settings.excludedAppBundleIdentifiers
        self.displayLanguage = settings.displayLanguage
    }

    var panelRetentionParameters: PanelRetentionParameters {
        panelRetentionMode.parameters
    }

    func apply(to settings: inout DockHoverPreviewSettings) {
        settings.isDockHoverPreviewEnabled = isDockWindowQuickLookEnabled
        settings.hoverDelayMilliseconds = hoverDelayMilliseconds
        settings.panelRetentionMode = panelRetentionMode
        settings.maxCardCount = maxCardCount
        settings.excludedAppBundleIdentifiers = excludedAppBundleIdentifiers
        // displayLanguage is carried for Dock UI localization but remains app-owned.
    }
}

@MainActor
protocol AppSettingsStore: AnyObject {
    var appSettingsSnapshot: AppSettingsSnapshot { get }

    @discardableResult
    func addAppSettingsObserver(_ observer: @MainActor @escaping (AppSettingsSnapshot) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func updateAppSettings(transform: (inout AppSettingsSnapshot) -> Void)
}

@MainActor
protocol DockWindowQuickLookSettingsStore: AnyObject {
    var dockWindowQuickLookSettingsSnapshot: DockWindowQuickLookSettingsSnapshot { get }

    @discardableResult
    func addDockWindowQuickLookSettingsObserver(
        _ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void
    ) -> UUID
    func removeObserver(_ token: UUID)
    func updateDockWindowQuickLookSettings(transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void)
}
```

Then update the class declaration:

```swift
final class UserDefaultsSettingsStore: DockHoverPreviewSettingsStore, AppSettingsStore, DockWindowQuickLookSettingsStore {
```

Add protocol implementations that adapt to the existing full snapshot without changing any persisted keys:

```swift
var appSettingsSnapshot: AppSettingsSnapshot {
    AppSettingsSnapshot(settings: snapshot)
}

var dockWindowQuickLookSettingsSnapshot: DockWindowQuickLookSettingsSnapshot {
    DockWindowQuickLookSettingsSnapshot(settings: snapshot)
}

@discardableResult
func addAppSettingsObserver(_ observer: @MainActor @escaping (AppSettingsSnapshot) -> Void) -> UUID {
    addObserver { snapshot in
        observer(AppSettingsSnapshot(settings: snapshot))
    }
}

func updateAppSettings(transform: (inout AppSettingsSnapshot) -> Void) {
    update { settings in
        var appSettings = AppSettingsSnapshot(settings: settings)
        transform(&appSettings)
        settings.displayLanguage = appSettings.displayLanguage
    }
}

@discardableResult
func addDockWindowQuickLookSettingsObserver(
    _ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void
) -> UUID {
    addObserver { snapshot in
        observer(DockWindowQuickLookSettingsSnapshot(settings: snapshot))
    }
}

func updateDockWindowQuickLookSettings(transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void) {
    update { settings in
        var dockSettings = DockWindowQuickLookSettingsSnapshot(settings: settings)
        transform(&dockSettings)
        dockSettings.apply(to: &settings)
    }
}
```

Keep `DockHoverPreviewSettingsStore` during this task as a compatibility protocol for `MenuBarController`, `LiveAppStatusProvider`, and diagnostics/status code that intentionally read both app and Dock settings.

- [ ] **Step 4: Update consumers to use narrow protocols**

Update constructor dependencies:

- `AppSettingsViewModel.settingsStore`: `AppSettingsStore`
- `DockWindowQuickLookSettingsViewModel.settingsStore`: `DockWindowQuickLookSettingsStore`
- `ProbeOrchestrator.settingsStore`: `DockWindowQuickLookSettingsStore`
- `PreviewSessionController.settingsStore`: `DockWindowQuickLookSettingsStore`

Update code to use the narrow API:

- `AppSettingsViewModel` reads `settingsStore.appSettingsSnapshot`, observes with `addAppSettingsObserver`, and writes with `updateAppSettings`.
- `DockWindowQuickLookSettingsViewModel` reads `settingsStore.dockWindowQuickLookSettingsSnapshot`, observes with `addDockWindowQuickLookSettingsObserver`, and writes with `updateDockWindowQuickLookSettings`.
- `ProbeOrchestrator` and `PreviewSessionController` read `dockWindowQuickLookSettingsSnapshot`; their settings observers receive `DockWindowQuickLookSettingsSnapshot`.

Keep `MenuBarController` on the existing compatibility protocol for now because it reads app language and Dock tool status in the same menu.

- [ ] **Step 5: Update test fakes to conform to the narrow protocols they are passed as**

Update fake stores in:

- `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`
- `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`
- `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

For any fake passed to an app settings view model, conform to `AppSettingsStore`. For any fake passed to Dock view models, `ProbeOrchestrator`, or `PreviewSessionController`, conform to `DockWindowQuickLookSettingsStore`. Fakes used by menu/status tests can remain on `DockHoverPreviewSettingsStore`.

- [ ] **Step 6: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add -A
git commit -m "Add narrow settings store protocols"
```

Expected: one commit introducing protocol seams without changing persisted keys.

## Task 5: Introduce Lightweight Tool Registry

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift`

- [ ] **Step 1: Add registry source test**

Add to `SettingsWindowControllerTests.swift`:

```swift
func testSettingsUsesToolDescriptorRegistryForToolNavigation() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let descriptorURL = packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift")
    XCTAssertTrue(FileManager.default.fileExists(atPath: descriptorURL.path))

    let descriptorSource = try String(contentsOf: descriptorURL, encoding: .utf8)
    XCTAssertTrue(descriptorSource.contains("struct ToolDescriptor"))
    XCTAssertTrue(descriptorSource.contains("static let dockWindowQuickLook"))

    let sidebarSource = try String(
        contentsOf: packageRoot.appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/SettingsSidebarView.swift"),
        encoding: .utf8
    )
    XCTAssertTrue(sidebarSource.contains("ForEach(tools)"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter SettingsWindowControllerTests/testSettingsUsesToolDescriptorRegistryForToolNavigation
```

Expected: FAIL because `ToolDescriptor.swift` does not exist yet.

- [ ] **Step 3: Create ToolDescriptor**

Create `Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift`:

```swift
import Foundation

enum ToolID: String, Hashable, CaseIterable, Sendable {
    case dockWindowQuickLook
    case contextMenuExtension
}

struct ToolDescriptor: Identifiable, Equatable {
    let id: ToolID
    let titleKey: LocalizedTextKey
    let systemImage: String
    let settingsPage: SettingsPage
    let isEnabled: Bool
    let badgeKey: LocalizedTextKey?

    static let dockWindowQuickLook = ToolDescriptor(
        id: .dockWindowQuickLook,
        titleKey: .dockWindowQuickLook,
        systemImage: "dock.rectangle",
        settingsPage: .dockWindowQuickLook,
        isEnabled: true,
        badgeKey: nil
    )

    static let contextMenuExtensionPlaceholder = ToolDescriptor(
        id: .contextMenuExtension,
        titleKey: .contextMenuExtension,
        systemImage: "contextualmenu.and.cursorarrow",
        settingsPage: .dockWindowQuickLook,
        isEnabled: false,
        badgeKey: .notDeveloped
    )
}
```

The placeholder has its own `ToolID` but points at the existing Dock page because it is disabled and cannot be selected. Do not add a fake selectable page until the context-menu tool has real scope.

- [ ] **Step 4: Update sidebar to receive tools**

Update `SettingsSidebarView` initializer properties:

```swift
let tools: [ToolDescriptor]
```

Render the tools section with:

```swift
SidebarSection(title: text.string(.settingsSectionTools)) {
    ForEach(tools) { tool in
        if tool.isEnabled {
            SidebarButton(
                title: text.string(tool.titleKey),
                systemImage: tool.systemImage,
                isSelected: selection.selectedPage == tool.settingsPage
            ) {
                selection.selectedPage = tool.settingsPage
            }
        } else {
            DisabledSidebarItem(
                title: text.string(tool.titleKey),
                badge: tool.badgeKey.map { text.string($0) } ?? "",
                systemImage: tool.systemImage
            )
        }
    }
}
```

Update `SettingsRootView` to pass:

```swift
tools: [.dockWindowQuickLook, .contextMenuExtensionPlaceholder]
```

- [ ] **Step 5: Keep menu behavior stable**

Do not generate the menu from the registry yet. The registry is intentionally scoped to settings navigation only. Run `MenuBarControllerTests` unchanged to prove the menu still exposes only the current primary Dock Window Quick Look actions.

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --filter SettingsWindowControllerTests/testSettingsUsesToolDescriptorRegistryForToolNavigation
swift test --filter MenuBarControllerTests
```

Expected: both commands pass.

- [ ] **Step 7: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add -A
git commit -m "Introduce tool descriptor registry for settings"
```

Expected: one commit with a small registry seam and unchanged user behavior.

## Task 6: Split Text Provider by Domain Without Changing Strings

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift`
- Create: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+App.swift`
- Create: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+DockWindowQuickLook.swift`
- Create: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+Support.swift`
- Test: `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`

- [ ] **Step 1: Add source-structure test**

Add to `AppTextProviderTests.swift`:

```swift
func testTextKeysAreSplitByDomain() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let expectedFiles = [
        "Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+App.swift",
        "Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+DockWindowQuickLook.swift",
        "Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+Support.swift"
    ]

    for relativePath in expectedFiles {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path),
            "\(relativePath) should exist"
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AppTextProviderTests/testTextKeysAreSplitByDomain
```

Expected: FAIL because the text domain extension files do not exist.

- [ ] **Step 3: Create text domain folders and extension files**

Run:

```bash
mkdir -p Sources/DockHoverPreviewProbe/Shared/Text
```

Create three extension files and move both domain-specific helper methods and domain-specific string switch branches out of `AppTextProvider.swift` while keeping the public `LocalizedTextKey` enum intact. Do not attempt to add enum cases from extensions.

Update `AppTextProvider.swift` so `string(_:)` still calls `englishText(for:)` and `simplifiedChineseText(for:)`, but those methods delegate to domain files:

```swift
private func englishText(for key: LocalizedTextKey) -> String {
    if let text = appEnglishText(for: key) {
        return text
    }
    if let text = dockWindowQuickLookEnglishText(for: key) {
        return text
    }
    if let text = supportEnglishText(for: key) {
        return text
    }
    assertionFailure("Missing English text for \(key)")
    return key.rawValue
}

private func simplifiedChineseText(for key: LocalizedTextKey) -> String {
    if let text = appSimplifiedChineseText(for: key) {
        return text
    }
    if let text = dockWindowQuickLookSimplifiedChineseText(for: key) {
        return text
    }
    if let text = supportSimplifiedChineseText(for: key) {
        return text
    }
    assertionFailure("Missing Simplified Chinese text for \(key)")
    return key.rawValue
}
```

Move this existing method into `AppTextProvider+App.swift`:

```swift
import Foundation

extension AppTextProvider {
    func appEnglishText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .openSettings:
            "Open Settings..."
        case .general:
            "General"
        case .settingsSectionApplications:
            "Application"
        case .settingsSectionTools:
            "Tools"
        case .settingsSectionSupport:
            "Support"
        case .contextMenuExtension:
            "Right-click Extension"
        case .notDeveloped:
            "Not Developed"
        case .language:
            "Language"
        case .launchAtLoginEnabled:
            "Launch at Login: Enabled"
        case .launchAtLoginNotRegistered:
            "Launch at Login: Not Registered"
        case .launchAtLoginRequiresApproval:
            "Launch at Login: Requires Approval"
        case .launchAtLoginNotFound:
            "Launch at Login: Not Found"
        case .enableLaunchAtLogin:
            "Enable Launch at Login"
        case .disableLaunchAtLogin:
            "Disable Launch at Login"
        case .openLoginItemsSettings:
            "Open Login Items Settings"
        case .settingsWindowTitle:
            "zongMacTools Settings"
        case .quit:
            "Quit"
        default:
            nil
        }
    }

    func appSimplifiedChineseText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .openSettings:
            "\u{6253}\u{5F00}\u{8BBE}\u{7F6E}..."
        case .general:
            "\u{901A}\u{7528}"
        case .settingsSectionApplications:
            "\u{5E94}\u{7528}"
        case .settingsSectionTools:
            "\u{5DE5}\u{5177}"
        case .settingsSectionSupport:
            "\u{652F}\u{6301}"
        case .contextMenuExtension:
            "\u{53F3}\u{952E}\u{6269}\u{5C55}"
        case .notDeveloped:
            "\u{672A}\u{5F00}\u{53D1}"
        case .language:
            "\u{663E}\u{793A}\u{8BED}\u{8A00}"
        case .launchAtLoginEnabled:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}"
        case .launchAtLoginNotRegistered:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{672A}\u{6CE8}\u{518C}"
        case .launchAtLoginRequiresApproval:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{9700}\u{8981}\u{6279}\u{51C6}"
        case .launchAtLoginNotFound:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}\u{FF1A}\u{672A}\u{627E}\u{5230}"
        case .enableLaunchAtLogin:
            "\u{542F}\u{7528}\u{5F00}\u{673A}\u{542F}\u{52A8}"
        case .disableLaunchAtLogin:
            "\u{505C}\u{7528}\u{5F00}\u{673A}\u{542F}\u{52A8}"
        case .openLoginItemsSettings:
            "\u{6253}\u{5F00}\u{767B}\u{5F55}\u{9879}\u{8BBE}\u{7F6E}"
        case .settingsWindowTitle:
            "zongMacTools \u{8BBE}\u{7F6E}"
        case .quit:
            "\u{9000}\u{51FA}"
        default:
            nil
        }
    }

    func languageDisplayName(_ language: DisplayLanguage) -> String {
        switch language {
        case .english:
            "English"
        case .simplifiedChinese:
            "\u{7B80}\u{4F53}\u{4E2D}\u{6587}"
        }
    }
}
```

Move Dock Window Quick Look switch branches and these existing helper methods into `AppTextProvider+DockWindowQuickLook.swift`. The file must define:

```swift
import Foundation

extension AppTextProvider {
    func dockWindowQuickLookEnglishText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .dockWindowQuickLook:
            "Dock Window Quick Look"
        case .dockWindowQuickLookDescription:
            "Hover over Dock app icons to quickly view that app's window cards."
        case .performanceAndFeel:
            "Performance & Feel"
        case .exclusionRules:
            "Exclusion Rules"
        case .excludeCurrentApp:
            "Exclude Current App"
        case .includeCurrentApp:
            "Include Current App"
        case .addExcludedApp:
            "Add..."
        case .chooseAppToExclude:
            "Choose App to Exclude"
        case .noExcludableApp:
            "No excludable app"
        case .noExcludedApps:
            "No excluded apps"
        case .clearAll:
            "Clear All"
        case .dockHoverPreviewStatusEnabled:
            "Dock Window Quick Look: Enabled"
        case .dockHoverPreviewStatusDisabled:
            "Dock Window Quick Look: Disabled"
        case .enableDockHoverPreview:
            "Enable Dock Window Quick Look"
        case .disableDockHoverPreview:
            "Disable Dock Window Quick Look"
        case .hoverDelay:
            "Hover Delay"
        case .panelRetention:
            "Panel Retention"
        case .maxCards:
            "Max Cards"
        case .excludedApps:
            "Excluded Apps"
        case .excludeApp:
            "Exclude App"
        case .excludeNamedApp:
            "Exclude %@"
        case .includeNamedApp:
            "Include %@"
        case .clearExcludedApps:
            "Clear Excluded Apps"
        case .moreExcludedApps:
            "%d more excluded apps"
        case .debugShowPreviewForFrontmostApp:
            "Debug: Show Preview For Frontmost App"
        case .noThumbnail:
            "No thumbnail"
        case .activateWindow:
            "Activate Window"
        case .hideApplication:
            "Hide App"
        case .closeWindow:
            "Close Window"
        case .minimizeWindow:
            "Minimize Window"
        case .screenUnknown:
            "Screen: Unknown"
        case .currentEnumerableEnvironment:
            "Environment: Current enumerable windows"
        case .removeExcludedAppHelp:
            "Remove excluded app"
        default:
            nil
        }
    }

    func dockWindowQuickLookSimplifiedChineseText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .dockWindowQuickLook:
            "Dock 窗口速览"
        case .dockWindowQuickLookDescription:
            "悬停在 Dock 应用图标上时，快速查看该应用的窗口卡片。"
        case .performanceAndFeel:
            "性能与手感"
        case .exclusionRules:
            "排除规则"
        case .excludeCurrentApp:
            "排除当前可排除 App"
        case .includeCurrentApp:
            "恢复当前可排除 App"
        case .addExcludedApp:
            "添加..."
        case .chooseAppToExclude:
            "选择要排除的 App"
        case .noExcludableApp:
            "没有可排除的 App"
        case .noExcludedApps:
            "当前没有排除项"
        case .clearAll:
            "清空全部"
        case .dockHoverPreviewStatusEnabled:
            "Dock 窗口速览：已启用"
        case .dockHoverPreviewStatusDisabled:
            "Dock 窗口速览：已停用"
        case .enableDockHoverPreview:
            "启用 Dock 窗口速览"
        case .disableDockHoverPreview:
            "停用 Dock 窗口速览"
        case .hoverDelay:
            "悬停延迟"
        case .panelRetention:
            "面板保留手感"
        case .maxCards:
            "最大卡片数"
        case .excludedApps:
            "排除的 App"
        case .excludeApp:
            "排除 App"
        case .excludeNamedApp:
            "排除 %@"
        case .includeNamedApp:
            "恢复 %@"
        case .clearExcludedApps:
            "清空排除列表"
        case .moreExcludedApps:
            "还有 %d 个已排除 App"
        case .debugShowPreviewForFrontmostApp:
            "调试：预览当前前台 App"
        case .noThumbnail:
            "无缩略图"
        case .activateWindow:
            "激活窗口"
        case .hideApplication:
            "隐藏应用"
        case .closeWindow:
            "关闭窗口"
        case .minimizeWindow:
            "最小化窗口"
        case .screenUnknown:
            "屏幕：未知"
        case .currentEnumerableEnvironment:
            "环境：当前可枚举窗口"
        case .removeExcludedAppHelp:
            "移除排除项"
        default:
            return nil
        }
    }

    func panelRetentionDisplayName(_ mode: PanelRetentionMode) -> String {
        switch language {
        case .english:
            switch mode {
            case .tight:
                "Tight"
            case .standard:
                "Standard"
            case .forgiving:
                "Forgiving"
            }
        case .simplifiedChinese:
            switch mode {
            case .tight:
                "\u{7D27}\u{51D1}"
            case .standard:
                "\u{6807}\u{51C6}"
            case .forgiving:
                "\u{5BBD}\u{677E}"
            }
        }
    }

    func excludedAppListTitle(appName: String?, bundleIdentifier: String) -> String {
        guard let appName, !appName.isEmpty, appName != bundleIdentifier else {
            return self.bundleIdentifier(bundleIdentifier)
        }
        return "\(externalAppName(appName)) (\(self.bundleIdentifier(bundleIdentifier)))"
    }

    func externalAppName(_ appName: String) -> String {
        appName
    }

    func externalWindowTitle(_ windowTitle: String) -> String {
        windowTitle
    }

    func bundleIdentifier(_ bundleIdentifier: String) -> String {
        bundleIdentifier
    }

    func screenDescription(_ screenName: String) -> String {
        switch language {
        case .english:
            "Screen: \(screenName)"
        case .simplifiedChinese:
            "\u{5C4F}\u{5E55}\u{FF1A}\(screenName)"
        }
    }
}
```

Move support/about/diagnostic switch branches and these existing helper methods into `AppTextProvider+Support.swift`. The file must define `supportEnglishText(for:)`, `supportSimplifiedChineseText(for:)`, `accessibilityStatus(granted:)`, and `screenRecordingStatus(granted:)`.

```swift
import Foundation

extension AppTextProvider {
    func supportEnglishText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .permissionsAndStatus:
            "Permissions & Status"
        case .requestAccessibilityPrompt:
            "Request Accessibility Prompt"
        case .openAccessibilitySettings:
            "Open Accessibility Settings"
        case .openScreenRecordingSettings:
            "Open Screen Recording Settings"
        case .refreshPermissions:
            "Refresh Permissions"
        case .aboutStatus:
            "About & Status"
        case .copyStatus:
            "Copy Status"
        case .exportDiagnostics:
            "Export Diagnostics..."
        case .diagnosticExportFailed:
            "Diagnostics could not be saved."
        case .diagnosticSavePanelTitle:
            "Export Diagnostics"
        case .diagnosticSavePanelMessage:
            "Choose where to save the zongMacTools diagnostics file."
        case .diagnosticSavePanelPrompt:
            "Save"
        case .diagnosticSavePanelNameFieldLabel:
            "Save As:"
        default:
            nil
        }
    }

    func supportSimplifiedChineseText(for key: LocalizedTextKey) -> String? {
        switch key {
        case .permissionsAndStatus:
            "权限与状态"
        case .requestAccessibilityPrompt:
            "请求辅助功能授权提示"
        case .openAccessibilitySettings:
            "打开辅助功能设置"
        case .openScreenRecordingSettings:
            "打开屏幕录制设置"
        case .refreshPermissions:
            "刷新权限状态"
        case .aboutStatus:
            "关于与状态"
        case .copyStatus:
            "复制状态"
        case .exportDiagnostics:
            "导出诊断..."
        case .diagnosticExportFailed:
            "诊断文件未能保存。"
        case .diagnosticSavePanelTitle:
            "导出诊断"
        case .diagnosticSavePanelMessage:
            "选择保存 zongMacTools 诊断文件的位置。"
        case .diagnosticSavePanelPrompt:
            "保存"
        case .diagnosticSavePanelNameFieldLabel:
            "存储为："
        default:
            return nil
        }
    }

    func accessibilityStatus(granted: Bool) -> String {
        switch language {
        case .english:
            "Accessibility: \(granted ? "granted" : "missing")"
        case .simplifiedChinese:
            "\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{FF1A}\(permissionStatus(granted: granted))"
        }
    }

    func screenRecordingStatus(granted: Bool) -> String {
        switch language {
        case .english:
            "Screen Recording: \(granted ? "granted" : "missing")"
        case .simplifiedChinese:
            "\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{FF1A}\(permissionStatus(granted: granted))"
        }
    }

    private func permissionStatus(granted: Bool) -> String {
        granted
            ? "\u{5DF2}\u{6388}\u{6743}"
            : "\u{7F3A}\u{5931}"
    }
}
```

After moving the methods and switch branches, delete their original definitions from `AppTextProvider.swift`. Keep `LocalizedTextKey`, `string(_:)`, `string(_:appName:)`, `string(_:count:)`, `excludeNamedApp(_:)`, `includeNamedApp(_:)`, `moreExcludedApps(count:)`, `englishText(for:)`, and `simplifiedChineseText(for:)` in `AppTextProvider.swift` for this task.

- [ ] **Step 4: Run validation**

Run:

```bash
git diff --check
swift test
```

Expected: both commands pass and existing strings are unchanged.

- [ ] **Step 5: Commit**

Run:

```bash
git add -A
git commit -m "Split localized text definitions by domain"
```

Expected: one commit that only changes text organization, not user-facing strings.

## Task 7: Final Architecture Verification

**Files:**

- Modify: `docs/architecture/dock-hover-preview-technical-design.md`
- Modify: `README.md`
- Test-only changes only if a verification expectation needs to be recorded.

- [ ] **Step 1: Run full validation**

Run:

```bash
git diff --check
swift test
swift build
Scripts/build_probe_app.sh
```

Expected:

- `git diff --check` exits 0.
- `swift test` exits 0.
- `swift build` exits 0.
- `Scripts/build_probe_app.sh` exits 0 and still creates `build/zongMacTools.app` with executable `DockHoverPreviewProbe`.

- [ ] **Step 2: Inspect source layout**

Run:

```bash
find Sources/DockHoverPreviewProbe -maxdepth 4 -type f | sort
```

Expected:

- App shell files are under `App/`.
- Settings shell files are under `Settings/`.
- Support files are under `Support/`.
- Dock Window Quick Look files are under `Tools/DockWindowQuickLook/`.
- Shared helpers are under `Shared/`.
- `Sources/DockHoverPreviewProbe/Info.plist` remains at target root.

- [ ] **Step 3: Review large files**

Run:

```bash
find Sources/DockHoverPreviewProbe -name '*.swift' -print0 | xargs -0 wc -l | sort -nr | head -20
```

Expected:

- `SettingsRootView.swift` is no longer near the top.
- `SettingsViewModel.swift` is small enough to act as a coordinator.
- Any remaining large files are domain files with cohesive responsibilities, such as preview rendering or window operation implementation.

- [ ] **Step 4: Update architecture docs**

Modify `docs/architecture/dock-hover-preview-technical-design.md` so the module structure section mentions that Dock Window Quick Look now lives under:

```text
Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/
```

Also mention that the app remains a single SwiftPM executable target for now.

Modify `README.md` so the architecture section reflects the new source folders:

- `App/` for app launch and menu bar shell.
- `Settings/` for settings shell, settings view models, compatibility settings model/store, and settings-navigation registry.
- `Support/` for permissions, diagnostics, metadata, and about/status.
- `Shared/` for cross-domain helpers and text provider files.
- `Tools/DockWindowQuickLook/` for Dock Window Quick Look implementation and settings UI.

- [ ] **Step 5: Record manual smoke test requirements**

Add a short manual verification note to `docs/architecture/dock-hover-preview-technical-design.md` or an existing verification checklist:

```text
After this source-structure refactor, manually smoke test:
- launch build/zongMacTools.app
- open the settings window from the menu bar
- switch General, Dock Window Quick Look, Permissions & Status, and About & Status pages
- switch display language and confirm sidebar/page/menu titles refresh
- toggle Dock Window Quick Look from settings and from the menu bar
- copy About & Status text
```

Do not mark the manual smoke test as passed unless it was actually run.

- [ ] **Step 6: Run final validation**

Run:

```bash
git diff --check
swift test
swift build
```

Expected: all commands pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add -A
git commit -m "Document multi-tool source structure"
```

Expected: final docs commit.

## Rollback Strategy

Each task is a separate commit. If a later step causes churn or reveals that a boundary is wrong, revert the latest task commit only:

```bash
git revert <commit-sha>
```

Do not use `git reset --hard` in this repository unless the user explicitly requests destructive cleanup.

## Completion Criteria

The refactor is complete when:

- `swift test` passes after every task.
- `git diff --check` passes after every task.
- Existing app behavior is unchanged.
- Existing `UserDefaults` keys are unchanged.
- `SettingsRootView` no longer owns all settings pages and shared settings chrome.
- `SettingsViewModel` no longer owns both app-level and Dock tool-level intents directly.
- Dock Window Quick Look source files live under `Tools/DockWindowQuickLook`.
- A future tool can add a settings sidebar entry through `ToolDescriptor`; adding real settings content may still require extending `SettingsPage` and the root detail switch until a second real tool justifies a content registry.

## Recommended Execution Mode

Use subagent-driven development if available:

- one subagent per task,
- main agent reviews diff and runs validation after each task,
- commit after each task passes.

Use inline execution only if the workspace needs tight manual control.

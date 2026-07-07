# Multi-Tool Settings Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the multi-tool settings window redesign described in `docs/superpowers/specs/2026-07-06-multi-tool-settings-window-design.md`.

**Architecture:** Keep existing Dock hover preview internals and `UserDefaults` keys. Move user-facing configuration from the menu into a reusable AppKit-hosted SwiftUI settings window, with `SettingsViewModel` as the only settings-writing adapter and `ProbeOrchestrator` as the single source of preview cancel/hide side effects.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, XCTest.

---

## File Boundaries

- Shared public surface, owned by the main agent:
  - `Sources/DockHoverPreviewProbe/SettingsPage.swift`
  - `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
  - `Sources/DockHoverPreviewProbe/DiagnosticExportService.swift`
  - `Sources/DockHoverPreviewProbe/AppDelegate.swift`
  - `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`
  - `Tests/DockHoverPreviewProbeTests/AppDelegateWiringTests.swift`
- Agent A write scope:
  - `Sources/DockHoverPreviewProbe/MenuBarController.swift`
  - `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift`
- Agent B write scope:
  - `Sources/DockHoverPreviewProbe/SettingsWindowController.swift`
  - `Sources/DockHoverPreviewProbe/SettingsRootView.swift`
  - `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`
- Agent C write scope:
  - `Sources/DockHoverPreviewProbe/SettingsViewModel.swift`
  - `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`
- Agent D write scope:
  - `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
  - `Sources/DockHoverPreviewProbe/AppTargetTracker.swift`
  - `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`
  - `Tests/DockHoverPreviewProbeTests/AppTargetTrackerTests.swift`
- Agent E write scope:
  - `README.md`
  - `docs/verification/dock-hover-preview-multi-tool-settings-window-manual-checklist.md`

If a task needs a file outside its write scope, the worker must stop and report the required change for the main agent to integrate.

## Task 1: Lock Shared Surface

- [ ] Add `SettingsPage` with only `.general`, `.dockWindowQuickLook`, and `.support`.
- [ ] Add `SettingsWindowPresenting` with `showSettings(selectedPage:)`.
- [ ] Add new localized keys for the design document only, including `Dock 窗口速览`, `打开设置...`, `关于与状态`, sidebar section labels, preset section labels, empty states, and disabled `右键扩展`.
- [ ] Rename the diagnostic presenter protocol method to neutral `exportDiagnostics()`, preserving the same save-panel behavior.
- [ ] Run `swift test --filter AppTextProviderTests` and `swift test --filter AppDelegateWiringTests` after tests are added.

## Task 2: Menu Bar Minimal Menu

- [ ] Replace the current long menu with the design's minimal menu: app title, Dock Window Quick Look status, open settings, toggle, about/status, diagnostics, quit.
- [ ] Remove direct menu entries for hover delay, panel retention, max cards, language, excluded apps, permissions, Launch at Login, and debug preview.
- [ ] Make `openSettings` call `SettingsWindowPresenting.showSettings(selectedPage: .dockWindowQuickLook)`.
- [ ] Ensure toggle only writes `settingsStore.update`; it must not call cancel/hide directly.
- [ ] Update menu tests to assert old configuration submenus are absent and menu-side side effects are gone.
- [ ] Run `swift test --filter MenuBarControllerTests`.

## Task 3: Settings View Model

- [ ] Add `SettingsViewModel` as the only SwiftUI-facing settings writer.
- [ ] Expose snapshot-backed state and intent methods for enabled, language, launch at login, hover delay preset index, retention preset index, max card preset index, target exclusion, row removal, and clear all.
- [ ] Bind sliders to preset indexes, not raw setting values.
- [ ] Clamp/round incoming indexes and write only values from `150/250/400`, `tight/standard/forgiving`, and `3/5/8/12`.
- [ ] Use `AppTargetTracker.exclusionTarget` for “排除当前可排除 App”; never replace it with a plain frontmost-app concept.
- [ ] Keep preview side effects out of the view model.
- [ ] Run `swift test --filter SettingsViewModelTests`.

## Task 4: Settings Window and SwiftUI Pages

- [ ] Add `SettingsWindowController` that owns/reuses an `NSWindow`, hosts SwiftUI, and activates the accessory app with `NSApp.activate(ignoringOtherApps: true)`.
- [ ] Make repeated opens reuse and front the same window; closing then reopening must not leave duplicate windows.
- [ ] Build the sidebar groups exactly as the design states: 应用/通用, 工具/Dock 窗口速览 plus disabled 右键扩展, 支持/权限与状态.
- [ ] Do not add `右键扩展` to `SettingsPage`.
- [ ] Implement General, Dock Window Quick Look, and Support pages using existing services and `SettingsViewModel`.
- [ ] Run `swift test --filter SettingsWindowControllerTests`.

## Task 5: Orchestrator Settings Side Effects

- [ ] Track previous settings in `ProbeOrchestrator` observer.
- [ ] On enabled true -> false, cancel pending hover and hide preview with `settingsDisabled`.
- [ ] On hover delay changes, cancel pending hover with `settingsChanged`.
- [ ] On newly excluded bundle identifiers, cancel/hide only when the pending hover app or current preview app is affected.
- [ ] Add a current-preview target accessor to `AppTargetTracker` only if needed for exact observer decisions.
- [ ] Ensure unrelated exclusion list changes do not hide preview.
- [ ] Run `swift test --filter ProbeOrchestratorPreviewTests` and `swift test --filter AppTargetTrackerTests`.

## Task 6: AppDelegate Wiring

- [ ] Instantiate `SettingsViewModel` and `SettingsWindowController` after shared services exist.
- [ ] Inject existing `settingsStore`, `targetTracker`, `launchAtLoginService`, `permissionService`, `aboutStatusPresenter`, `diagnosticExportPresenter`, `appNameResolver`, and `logger`.
- [ ] Inject `SettingsWindowPresenting` into `MenuBarController`.
- [ ] Keep target/source directory names unchanged.
- [ ] Run `swift test --filter AppDelegateWiringTests`.

## Task 7: Documentation

- [ ] Update README usage text from old P1 menu settings to “minimal menu + settings window”.
- [ ] Add a manual verification checklist for the settings window redesign.
- [ ] Do not claim manual validation has passed.

## Task 8: Final Verification

- [ ] Run `swift test`.
- [ ] Run `swift build`.
- [ ] Run `Scripts/build_probe_app.sh`.
- [ ] Run `git diff --check`.
- [ ] Review `git diff` for scope, key compatibility, and no accidental target/source-directory renames.

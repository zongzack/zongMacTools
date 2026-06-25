# Dock Hover Preview MVP Technical Design

Date: 2026-06-25

## 1. Goal

Build a personal macOS menu bar utility that reproduces the smallest useful slice of the Windows taskbar preview behavior:

- Hover a Dock application icon.
- Show that application's currently visible windows on the current desktop.
- Display up to 8 preview cards in a horizontal panel above the Dock.
- Each card shows app icon, static thumbnail, and window title.
- Click a card to switch to that window.

The implementation must be generic for all regular macOS apps. Acceptance samples are VS Code, Chrome, WPS, Typora, and IINA.

## 2. Confirmed Product Scope

In scope for MVP:

- Native macOS app written in Swift with AppKit and SwiftUI.
- Menu bar resident app; the tool itself should not appear in the Dock.
- Manual permission handling for Accessibility and Screen Recording.
- Main trigger: Dock icon hover.
- Fallback trigger: menu bar debug action for the frontmost app.
- Current desktop visible windows only.
- Static thumbnails only.
- Up to 8 windows per app, horizontally scrollable.
- Click-to-activate behavior.
- Quiet failure behavior: if exact window raise fails, activate the app and hide the preview.
- No preview panel when the app has no eligible windows.
- Permission problems appear only in the menu bar/status UI, not as repeated Dock hover popups.

Out of scope for MVP:

- Real-time video thumbnails.
- Minimized windows.
- Windows on other Spaces.
- Full-screen Space switching.
- Close/minimize/full-screen buttons on preview cards.
- Keyboard switcher, Cmd+Tab replacement, search, media widgets, calendar widgets, Dock locking, app filters, or settings pages.
- App Store distribution.

## 3. Reference: DockDoor

Reference project: https://github.com/ejbills/DockDoor

Use DockDoor as an implementation reference, not as a code source to copy. DockDoor is GPLv3, so copying source into this project would require GPL-compatible licensing and attribution. For this personal MVP, use it to validate architecture and macOS API strategy.

Relevant reference files:

- `DockDoor/Utilities/DockObserver.swift`: listens to Dock Accessibility selection changes and resolves the hovered Dock item.
- `DockDoor/Utilities/Window Management/WindowUtil.swift`: combines ScreenCaptureKit, Accessibility, and CoreGraphics/window-server metadata to find windows and capture images.
- `DockDoor/Utilities/Window Management/WindowInfo.swift`: wraps window identity, app ownership, AX element, title, image, and activation behavior.
- `DockDoor/Views/Hover Window/Shared Components/SharedPreviewWindowCoordinator.swift`: owns the floating preview panel lifecycle and positioning.
- `DockDoor/Components/PermissionsView/PermissionsChecker.swift`: checks Accessibility and Screen Recording permission state.

Reference lessons to reuse:

- Prefer Dock Accessibility notifications over coordinate-only Dock icon guessing.
- Keep Dock hover detection, window discovery, thumbnail capture, preview UI, and activation as separate subsystems.
- Use a floating `NSPanel` for preview display.
- Revalidate that the mouse is still on the expected Dock item before showing a delayed preview.
- Add a recovery/reset path because Dock can restart or rebuild its Accessibility tree.

Reference choices to avoid for MVP:

- No global window seeding at launch.
- No large persistent window cache.
- No private APIs in V1 unless public API probing fails and the tradeoff is explicitly accepted later.
- No embedded widgets or broad window management behaviors.

## 4. Development Preconditions

Current local environment facts:

- macOS version: 26.5.1.
- Swift available: Apple Swift 6.3.2 via Command Line Tools.
- Full Xcode is not currently active; `xcodebuild` reports that only Command Line Tools are selected.

Implementation preconditions:

- Install and select full Xcode before building the final `.app` target:
  - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- The built app must request and receive:
  - Accessibility permission for Dock AX inspection and window activation.
  - Screen Recording permission for thumbnail capture.
- During local development, use a stable bundle identifier such as `com.zong.DockHoverPreview`.

Full Xcode setup guidance:

- Document generation does not require full Xcode.
- Probe implementation can start with Swift Command Line Tools, but final AppKit app creation and signing should use full Xcode.
- Install Xcode from the Mac App Store or Apple Developer downloads.
- After installation, open Xcode once so it can finish installing additional components.
- Select full Xcode for command-line builds:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

- Verify the active developer directory:

```sh
xcode-select -p
xcodebuild -version
```

- If the command asks to accept the license, run:

```sh
sudo xcodebuild -license accept
```

- If multiple Xcode versions exist, replace `/Applications/Xcode.app` with the exact app path, for example `/Applications/Xcode-26.app`.

## 5. Architecture

Use a small native app with these modules:

### 5.1 AppBootstrap

Responsibilities:

- Start an `NSApplication`.
- Install `AppDelegate`.
- Set app activation policy to accessory/menu-bar style.
- Create the menu bar item.
- Initialize permission checking, Dock hover monitoring, window query service, thumbnail service, preview panel controller, and activation service.

Implementation notes:

- Prefer an Xcode macOS App target for the final app.
- Set `LSUIElement` to `true` in `Info.plist` so the app does not show in the Dock.
- Keep dependency footprint at zero for MVP.

### 5.2 PermissionService

Responsibilities:

- Check Accessibility permission with `AXIsProcessTrusted()`.
- Prompt for Accessibility permission with `AXIsProcessTrustedWithOptions`.
- Check Screen Recording permission with `CGPreflightScreenCaptureAccess()`.
- Open the relevant System Settings panes from menu actions.
- Publish permission state to the menu bar status.

Public interface:

```swift
struct PermissionState: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

protocol PermissionService {
    var currentState: PermissionState { get }
    func refresh() -> PermissionState
    func requestAccessibilityPrompt()
    func openAccessibilitySettings()
    func openScreenRecordingSettings()
}
```

Behavior:

- Poll permission state every 1 second while the app is running.
- Never show permission alerts from Dock hover.
- Menu bar title/icon should indicate whether permissions are complete.

### 5.3 DockHoverMonitor

Responsibilities:

- Attach to the Dock process through Accessibility.
- Subscribe to `kAXSelectedChildrenChangedNotification` on the Dock list element.
- Resolve the selected Dock item to an app bundle URL and bundle identifier.
- Return the running app if present.
- Notify the orchestrator when a new Dock app item is hovered.
- Recover if Dock restarts or the subscribed AX element becomes invalid.

Public interface:

```swift
struct HoveredDockApp: Equatable {
    let app: NSRunningApplication
    let bundleIdentifier: String
    let dockItemElement: AXUIElement
    let dockItemFrame: CGRect?
}

protocol DockHoverMonitorDelegate: AnyObject {
    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp)
    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor)
}
```

Implementation detail:

- Find Dock with `NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first`.
- Create Dock app AX element with `AXUIElementCreateApplication(dockPID)`.
- Find the Dock list child by checking `kAXRoleAttribute == kAXListRole`.
- Subscribe to `kAXSelectedChildrenChangedNotification`.
- On notification, read `kAXSelectedChildrenAttribute`.
- Only accept items whose subrole is `AXApplicationDockItem`.
- Read `kAXURLAttribute` from the Dock item and resolve `Bundle(url: appURL)?.bundleIdentifier`.
- Match running apps with `NSRunningApplication.runningApplications(withBundleIdentifier:)`.
- If multiple running apps share a bundle ID, use the first instance for MVP.

Recovery:

- Every 5 seconds, check whether the Dock PID changed or the subscribed Dock list element returns `.invalidUIElement` / `.cannotComplete`.
- On failure, tear down and resubscribe.

Delay and validation:

- `HoverOrchestrator` applies a 250 ms delay before showing preview.
- Before showing the preview, re-read the selected Dock item and confirm it still has the same bundle identifier.

### 5.4 WindowQueryService

Responsibilities:

- Given an `NSRunningApplication`, return eligible windows for the current desktop.
- Include only visible, on-screen, non-minimized windows.
- Return title, window ID, owning PID, frame, AX element if available, app icon, and optional thumbnail source metadata.

Public model:

```swift
struct PreviewWindow: Identifiable, Hashable {
    let id: CGWindowID
    let app: NSRunningApplication
    let title: String
    let frame: CGRect
    let axElement: AXUIElement?
    let appIcon: NSImage
    let thumbnail: CGImage?
}
```

Recommended V1 discovery path:

- Use `SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)` as the primary source.
- Filter `SCWindow` entries by:
  - owning app process ID matches the hovered app's PID, or owning bundle ID matches the hovered app bundle ID;
  - `isOnScreen == true`;
  - frame width and height are greater than a small threshold, for example 80 x 60;
  - window layer is normal enough for app windows, initially `windowLayer == 0`.
- Sort by a stable, simple order for MVP:
  - larger on-screen area first when no better recency signal is available;
  - then title alphabetically;
  - then window ID.
- Take the first 8 windows.

AX enrichment:

- Build app AX element with `AXUIElementCreateApplication(app.processIdentifier)`.
- Read AX windows via `kAXWindowsAttribute`.
- Try to map AX windows to `SCWindow` entries by window ID if `_AXUIElementGetWindow` is available.
- If mapping fails, keep `axElement` nil and allow app-level activation fallback.

Current desktop behavior:

- For MVP, treat `SCShareableContent(... onScreenWindowsOnly: true)` plus `SCWindow.isOnScreen` as the current visible desktop source.
- Do not try to enumerate windows from other Spaces.
- Do not restore minimized windows.

WPS and document app note:

- WPS may expose child/helper windows differently. Keep the generic filtering but allow validation to reveal whether WPS needs a V2-specific owner mapping.

### 5.5 ThumbnailService

Responsibilities:

- Produce a static image for each `PreviewWindow`.
- Return nil on failure, allowing UI fallback to app icon and title.

Public interface:

```swift
protocol ThumbnailService {
    func thumbnail(for window: PreviewWindow) async -> CGImage?
}
```

V1 strategy:

- First try `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)` with an `SCContentFilter` targeting the matching `SCWindow`.
- If that proves too heavy during Probe, use `CGWindowListCreateImage` / `CGWindowListCreateImageFromArray` for a static snapshot.
- Cache thumbnails by `pid + windowID` for 10 seconds.
- Refuse to capture if Screen Recording permission is not granted.

Fallback UI:

- If thumbnail is nil, show an app-icon placeholder and the title.
- Do not block the preview panel waiting for every thumbnail; show cards as data arrives.

Private API decision:

- DockDoor uses private/window-server capture paths for robust static screenshots.
- V1 should avoid private APIs unless public capture produces unusable results for the acceptance apps.
- If private APIs are introduced later, isolate them behind `ThumbnailService` so they can be removed or swapped.

### 5.6 PreviewPanelController

Responsibilities:

- Own a single floating `NSPanel`.
- Render a SwiftUI preview panel.
- Position the panel near the hovered Dock icon.
- Hide when the mouse leaves both Dock and preview panel.
- Hide on click, permission failure, app/window disappearance, or Escape key.

Panel configuration:

- `NSPanel` style mask: `.nonactivatingPanel`, `.borderless`, `.fullSizeContentView`.
- `level`: `.statusBar` or `.floating`.
- `isOpaque = false`, `backgroundColor = .clear`.
- `collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]`.
- `hidesOnDeactivate = false`.

SwiftUI panel layout:

- Container uses macOS material/blur style, subtle border, and small shadow.
- Horizontal scroll view with up to 8 cards.
- Card fixed size:
  - width: 220 pt.
  - thumbnail area: 220 x 124 pt.
  - title row height: 28 pt.
  - icon size: 18 pt.
- Title truncates in the middle or tail.
- No close/minimize buttons.

Positioning:

- If `dockItemFrame` is available, anchor to it.
- For bottom Dock:
  - panel x is centered on Dock icon and clamped to screen visible frame.
  - panel y is above Dock icon plus 10 pt.
- For left/right Dock:
  - use the same controller, but first implementation may be best-effort.
- For missing Dock frame:
  - anchor around current mouse location and clamp to screen.

### 5.7 ActivationService

Responsibilities:

- Activate the owning app.
- Attempt to raise the selected window.
- Hide the preview panel regardless of exact raise success.

Public interface:

```swift
protocol ActivationService {
    func activate(window: PreviewWindow)
}
```

Behavior:

- Call `window.app.activate(options: [.activateIgnoringOtherApps])`.
- If `axElement` exists, perform `kAXRaiseAction`.
- Try setting `kAXMainWindowAttribute` to true when supported.
- Ignore AX raise errors and keep the UX quiet.

Do not implement:

- Close window.
- Minimize window.
- Full-screen toggle.
- Move window between Spaces.

### 5.8 MenuBarController

Responsibilities:

- Show a menu bar icon.
- Expose simple status and debug controls.

Menu items:

- Permission status: Accessibility granted/missing.
- Permission status: Screen Recording granted/missing.
- Open Accessibility Settings.
- Open Screen Recording Settings.
- Refresh Permissions.
- Debug: Show Preview For Frontmost App.
- Pause/Resume Dock Hover.
- Quit.

Debug action behavior:

- Get `NSWorkspace.shared.frontmostApplication`.
- Query windows through `WindowQueryService`.
- Show the same preview panel centered above the Dock or near mouse location.
- This bypasses Dock hover detection, but still uses the same window/query/thumbnail/activation pipeline.

## 6. Orchestration Flow

Dock hover flow:

1. `DockHoverMonitor` receives Dock selected-child notification.
2. It resolves a `HoveredDockApp`.
3. `HoverOrchestrator` cancels any previous pending show.
4. It waits 250 ms.
5. It verifies the same Dock item/app is still hovered.
6. It checks permissions.
7. It calls `WindowQueryService.windows(for:)`.
8. If no eligible windows exist, it hides/does not show the panel.
9. It shows `PreviewPanelController` with placeholder cards.
10. It requests thumbnails asynchronously.
11. Cards update as thumbnails arrive.
12. Clicking a card calls `ActivationService.activate(window:)`.
13. Panel hides immediately after click.

Mouse-leave flow:

1. Track mouse with a local/global monitor or timer at 30-60 Hz while the panel is visible.
2. Keep panel open while mouse is inside the preview panel or still over the same Dock item.
3. Hide after the mouse is outside both areas for 150 ms.

Dock recovery flow:

1. Health check detects invalid Dock observer or Dock PID change.
2. Monitor tears down AX observer and run loop source.
3. Monitor resubscribes.
4. Menu bar status remains available even if Dock hover is temporarily offline.

## 7. Probe Phase

Before building polished UI, implement a Probe target/mode in the same app.

Probe acceptance:

- Accessibility prompt appears and state changes after permission is granted.
- Screen Recording state is detected.
- Dock hover over VS Code/Chrome/WPS/Typora/IINA logs:
  - app name;
  - bundle identifier;
  - PID;
  - Dock item frame if available.
- Frontmost-app debug action logs eligible windows:
  - window ID;
  - title;
  - frame;
  - thumbnail success/failure.
- Clicking/selecting a logged window can activate the app and attempt to raise the window.

Probe UI:

- Menu bar item only.
- A lightweight log window or Console logging is enough.
- No polished preview panel required.

Probe exit criteria:

- Dock hover detection is stable across the five acceptance apps.
- Window query returns correct windows for at least VS Code, Chrome, Typora, and IINA.
- WPS behavior is characterized, even if it needs a V2 adjustment.
- At least one static thumbnail method works for ordinary app windows after Screen Recording permission is granted.
- Activation fallback never leaves the app stuck or visibly broken.

## 8. MVP Implementation Milestones

Milestone 1: Project skeleton

- Create native macOS app target.
- Add `Info.plist` with `LSUIElement = true`.
- Add menu bar controller.
- Add permission checker and status menu.

Milestone 2: Dock hover Probe

- Implement Dock AX observer.
- Log hovered Dock app identity.
- Add health check and reset behavior.

Milestone 3: Window query Probe

- Implement ScreenCaptureKit window enumeration.
- Filter to current visible desktop windows.
- Add AX enrichment best effort.
- Add menu action to query frontmost app.

Milestone 4: Thumbnail Probe

- Implement static thumbnail capture.
- Add short TTL cache.
- Log failures without crashing.

Milestone 5: Activation Probe

- Implement app activation and AX raise.
- Test click/select behavior against acceptance apps.

Milestone 6: Preview panel

- Implement single `NSPanel`.
- Add SwiftUI horizontal card layout.
- Implement positioning and mouse-leave hiding.
- Wire card click to activation.

Milestone 7: Hardening

- Handle missing permissions quietly.
- Handle Dock restart.
- Clamp panel to screen.
- Ensure no panel appears for apps with zero eligible windows.
- Test acceptance samples.

## 9. Test Plan

Manual tests:

- VS Code: open three separate project windows; hover Dock icon; verify three cards; click each card and confirm correct window raises.
- Chrome: open two separate browser windows; verify two cards; tabs must not appear as separate windows.
- WPS: open multiple document windows; verify visible windows appear or document exact mismatch for V2.
- Typora: open one or more documents; verify preview and activation.
- IINA: play a video; verify static thumbnail or placeholder appears; real-time playback is not required.
- No-window app: hover an app with no eligible current-desktop windows; verify no panel appears.
- Missing Accessibility permission: menu shows missing state; Dock hover does not spam alerts.
- Missing Screen Recording permission: menu shows missing state; panel may show icon/title placeholders but must not crash.
- Dock restart: run `killall Dock`; app should recover observer after Dock returns.
- Multi-monitor: panel appears on the screen containing the Dock/mouse and stays inside visible bounds.

Non-goals to explicitly verify:

- Minimized windows do not need to appear.
- Other Space windows do not need to appear.
- Full-screen app windows do not need to be handled.
- Closing/minimizing from preview is absent.

## 10. Risks And Decisions

Risk: Dock AX selected-child events may change across macOS versions.

Decision: Use DockDoor's proven AX notification strategy first, with a fallback debug menu action. Add a health check and reset path.

Risk: Public screenshot APIs may produce blank or stale images for some apps.

Decision: Keep thumbnails optional. Static image failure degrades to app icon plus title. Do not block MVP on perfect screenshots.

Risk: WPS may expose windows through helper processes or nonstandard AX hierarchy.

Decision: Keep generic matching by PID/bundle first. Characterize WPS during Probe and only add owner-mapping logic if needed.

Risk: Exact AX window raise may fail for some apps.

Decision: Always activate the app first. AX raise is best effort. Failure is silent.

Risk: Full Xcode is not currently active locally.

Decision: Document full Xcode as a build prerequisite for the final app. Swift Command Line Tools are sufficient for some experiments, but not the preferred final app workflow.

## 11. Acceptance Criteria

The MVP is complete when:

- The app runs as a menu bar utility and does not show its own Dock icon.
- It detects required permissions and provides menu actions to resolve missing permissions.
- Hovering Dock icons for the acceptance apps shows previews for eligible current-desktop windows.
- The panel shows at most 8 cards with app icon, static thumbnail or placeholder, and title.
- Clicking a card activates the app and best-effort raises the selected window.
- The panel hides when the mouse leaves or after a card click.
- Missing thumbnails, missing AX raise, and apps with no windows do not produce disruptive UI.

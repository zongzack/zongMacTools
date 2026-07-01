# Dock Hover Preview MVP Technical Design

Date: 2026-06-25
Updated: 2026-06-26

## 1. Goal

Build a personal macOS menu bar utility that reproduces the smallest useful slice of the Windows taskbar preview behavior:

- Hover a Dock application icon.
- Show that application's eligible windows from the current interactive Space approximation.
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
- Current interactive Space visible-window approximation only.
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
- Exact occlusion detection. A window can be listed even if another window partially covers it.
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
- Treat Dock Accessibility notifications as wake-up signals, not as proof that the mouse is still on the Dock item.
- Keep Dock hover detection, window discovery, thumbnail capture, preview UI, and activation as separate subsystems.
- Use a floating `NSPanel` for preview display.
- Revalidate that the mouse is still inside the expected Dock item frame before showing a delayed preview.
- Add a recovery/reset path because Dock can restart or rebuild its Accessibility tree.
- Keep exact window activation isolated because robust implementations may need WindowServer/private fallbacks that are not acceptable by default in V1.

Reference choices to avoid for MVP:

- No global window seeding at launch.
- No large persistent window cache.
- No private APIs in V1. If public API probing fails, make an explicit post-Probe design decision before changing this constraint.
- Do not copy, translate, or mechanically rewrite DockDoor source, helper extensions, comments, file structure, or private API wrappers. Only reuse observed API strategy and behavioral lessons.
- No embedded widgets or broad window management behaviors.

## 4. Development Preconditions

Current local environment facts:

- macOS version: 26.5.1.
- Swift available: Apple Swift 6.3.2 via Command Line Tools.
- Full Xcode is currently active at `/Applications/Xcode.app/Contents/Developer`.

Implementation preconditions:

- Ensure full Xcode is installed and selected before building the final `.app` target:
  - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- The built app must request and receive:
  - Accessibility permission for Dock AX inspection and window activation.
  - Screen Recording permission for ScreenCaptureKit window enumeration and thumbnail capture.
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
- If Accessibility permission is missing, do not attach Dock observers and do not attempt AX activation.
- If Screen Recording permission is missing, normal Dock hover previews are suppressed because V1 window discovery depends on ScreenCaptureKit. The menu bar should show the missing permission and the debug action may log an AX-only diagnostic list, but that list is not considered MVP preview behavior.

### 5.3 DockHoverMonitor

Responsibilities:

- Attach to the Dock process through Accessibility.
- Subscribe to `kAXSelectedChildrenChangedNotification` on the Dock list element.
- Resolve the Dock item currently under the mouse to an app bundle URL and bundle identifier.
- Return the running app if present.
- Notify the orchestrator when a new Dock app item is hovered.
- Notify the orchestrator when the mouse is no longer over the expected Dock app item.
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
- On notification, read `kAXSelectedChildrenAttribute` as a candidate item only.
- Only accept items whose subrole is `AXApplicationDockItem`.
- Read `kAXURLAttribute` from the Dock item and resolve `Bundle(url: appURL)?.bundleIdentifier`.
- Match running apps with `NSRunningApplication.runningApplications(withBundleIdentifier:)`.
- If multiple running apps share a bundle ID, use the first instance for MVP.
- Read the Dock item frame from AX position/size attributes when available.
- Validate that the current mouse location is inside the candidate Dock item frame before emitting `didHover`.
- If the selected child persists after the mouse leaves the Dock, treat it as stale and emit `didLoseHover` from the orchestrator polling loop.

Recovery:

- Every 5 seconds, check whether the Dock PID changed or the subscribed Dock list element returns `.invalidUIElement` / `.cannotComplete`.
- On failure, tear down and resubscribe.

Delay and validation:

- `HoverOrchestrator` applies a 250 ms delay before showing preview.
- Before showing the preview, re-read the current candidate Dock item and confirm both:
  - it resolves to the same bundle identifier;
  - the current mouse location is still inside the same Dock item frame, or inside a best-effort frame reconstructed from the item position and size.
- If no reliable Dock item frame can be read, fallback to current mouse location for panel positioning but do not show the panel after the mouse leaves the Dock list bounds.

### 5.4 WindowQueryService

Responsibilities:

- Given an `NSRunningApplication`, return eligible windows for the current interactive Space approximation.
- Include only ScreenCaptureKit-visible, on-screen, non-minimized, normal application windows.
- Return title, window ID, owning PID, frame, AX element if available, app icon, and thumbnail source metadata.

Public model:

```swift
struct PreviewWindowID: Hashable {
    let pid: pid_t
    let windowID: CGWindowID
}

enum ThumbnailSource {
    case screenCaptureKit(SCWindow)
    case coreGraphics(CGWindowID)
}

struct PreviewWindow: Identifiable {
    let id: PreviewWindowID
    let cgWindowID: CGWindowID
    let app: NSRunningApplication
    let title: String
    let frame: CGRect
    let scWindow: SCWindow?
    let axElement: AXUIElement?
    let appIcon: NSImage
    let thumbnailSource: ThumbnailSource?
}
```

Model notes:

- Do not rely on automatic `Hashable` synthesis for `PreviewWindow`; AppKit, CoreGraphics, ScreenCaptureKit, and AX object references are not stable value fields.
- Keep thumbnails in preview view state or a cache, not in the immutable window query result.
- Use `(pid, windowID)` as identity. Re-query before activation because a `CGWindowID` can become stale after the window closes or the app restarts.

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
- Public V1 mapping strategy:
  - read AX title, position, size, minimized, and role/subrole;
  - discard minimized AX windows;
  - match AX windows to `SCWindow` entries by close frame overlap plus compatible title when available;
  - prefer exact title + near-equal frame, but tolerate empty titles for apps such as browsers and media players.
- `_AXUIElementGetWindow` is private. It may be tested in Probe under an explicitly isolated experiment flag, but it is not part of the default V1 implementation path.
- If public mapping fails, keep `axElement` nil and allow app-level activation fallback. Probe must measure how often this happens for the acceptance apps.

Current interactive Space behavior:

- For MVP, treat `SCShareableContent(... onScreenWindowsOnly: true)` plus `SCWindow.isOnScreen` as a best-effort source for windows present in the user's current interactive environment.
- This is not a strict Space API. It must be probed with:
  - another normal Space;
  - a full-screen Space;
  - Stage Manager enabled and disabled;
  - separate Spaces on multiple displays.
- The MVP should not promise exact occlusion or exact Mission Control Space membership. It should promise no minimized windows, no intentional cross-Space restoration, and no disruptive behavior if ScreenCaptureKit returns fewer windows than expected.
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

- First try `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)` with `SCContentFilter(desktopIndependentWindow:)` for the matching `SCWindow`.
- Configure the screenshot close to the card thumbnail size and current backing scale instead of capturing full-resolution windows when possible.
- If ScreenCaptureKit capture is too slow or returns blank images during Probe, use `CGWindowListCreateImage` / `CGWindowListCreateImageFromArray` for a static snapshot fallback.
- Cache thumbnails by `pid + windowID + frame.size + title` for 10 seconds.
- Cancel or ignore thumbnail tasks when the hover target changes.
- Refuse to capture if Screen Recording permission is not granted.

Fallback UI:

- If thumbnail is nil, show an app-icon placeholder and the title.
- Do not block the preview panel waiting for every thumbnail; show cards as data arrives.

Private API decision:

- DockDoor uses private/window-server capture paths for robust static screenshots.
- V1 does not use private screenshot APIs.
- If public capture produces unusable results for the acceptance apps, stop after Probe and make an explicit design decision before adding private capture paths.
- If private APIs are introduced in a later revision, isolate them behind `ThumbnailService` so they can be removed or swapped.

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
  - infer side from the Dock item frame and nearest screen edge;
  - position beside the Dock icon and clamp to the same screen visible frame;
  - if side inference fails, fallback to current mouse location.
- For missing Dock frame:
  - anchor around current mouse location and clamp to screen.
- Do not use private CoreDock orientation APIs in V1. Dock side inference should be based on public screen geometry and the AX item frame.

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

- Re-query or validate the selected window immediately before activation when feasible.
- If the app is hidden, call `window.app.unhide()`.
- If `axElement` exists:
  - perform `kAXRaiseAction`;
  - if `kAXMainWindowAttribute` is settable, set it to true;
  - then call `window.app.activate(options: [])`.
- Do not rely on `.activateIgnoringOtherApps`; it is deprecated on modern macOS and must not be treated as a correctness guarantee.
- If `axElement` is nil or AX raise fails, call `window.app.activate(options: [])` and hide the preview.
- Exact window raise failure is quiet, but Probe must record the failure rate because too many fallbacks means the MVP does not satisfy click-to-window switching.
- Private WindowServer/front-process helpers are out of V1 unless public activation fails the Probe gate and the tradeoff is explicitly accepted.

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
2. It resolves a candidate Dock item and validates that the mouse is currently inside that Dock item frame.
3. `HoverOrchestrator` cancels any previous pending show.
4. It waits 250 ms.
5. It verifies the same Dock item/app is still hovered and the mouse is still inside the Dock item frame or Dock list bounds.
6. It checks permissions. If Accessibility or Screen Recording is missing, it does not show the preview and relies on menu bar status.
7. It calls `WindowQueryService.windows(for:)`.
8. If no eligible windows exist, it hides/does not show the panel.
9. It shows `PreviewPanelController` with placeholder cards.
10. It requests thumbnails asynchronously.
11. Cards update as thumbnails arrive. Thumbnail results from a stale hover generation are ignored.
12. Clicking a card calls `ActivationService.activate(window:)`.
13. Panel hides immediately after click.

Mouse-leave flow:

1. Track mouse with a local/global monitor or timer at 30-60 Hz while the panel is visible.
2. Keep panel open while mouse is inside the preview panel or still inside the same Dock item frame.
3. Hide after the mouse is outside both areas for 150 ms.
4. If the Dock item frame is unavailable, use the Dock list bounds plus the preview panel frame as the leave region.

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
  - Dock item frame;
  - whether the mouse is inside the Dock item frame at notification time and again after the 250 ms delay.
- Frontmost-app debug action logs eligible windows:
  - window ID;
  - title;
  - frame;
  - `SCWindow.isOnScreen`;
  - window layer;
  - matched AX element yes/no;
  - AX title/frame/minimized state when available;
  - thumbnail success/failure.
- Clicking/selecting a logged window can activate the app and attempt to raise the exact window.

Probe UI:

- Menu bar item only.
- A lightweight log window or Console logging is enough.
- No polished preview panel required.

Hard Probe gates before preview UI:

- Dock hover detection is stable across the five acceptance apps with bottom Dock and auto-hide off:
  - no preview candidate is emitted after the mouse has left the Dock item;
  - Dock item frame is available or a reliable Dock list bounds fallback is available.
- Window query returns the expected visible, non-minimized windows for VS Code, Chrome, Typora, and IINA on the current interactive Space.
- AX mapping succeeds for at least VS Code, Chrome, Typora, and IINA well enough that clicking each logged window raises the exact selected window.
- At least one static thumbnail method works for ordinary app windows after Screen Recording permission is granted.
- Window query plus first placeholder render path is fast enough for hover use. Target: initial card data available within 150 ms after the 250 ms hover delay on the local machine.
- Dock observer recovers after `killall Dock` within 10 seconds.

Characterization Probe items:

- WPS behavior is characterized, including whether documents belong to helper processes, child windows, or nonstandard AX hierarchies.
- Another Space, a full-screen Space, Stage Manager, and multiple displays are tested and documented.
- Screen Recording denied behavior is tested. Expected V1 behavior: no normal Dock preview, no crash, menu bar shows missing permission.
- Missing Accessibility behavior is tested. Expected V1 behavior: no Dock observer, no hover preview, menu bar shows missing permission.
- Activation fallback never leaves the app stuck or visibly broken, but exact raise failures are counted. If exact raise fails often for the main acceptance apps, do not proceed to polished UI until the activation strategy is revised.

## 8. MVP Implementation Milestones

Milestone 1: Project skeleton

- Create native macOS app target.
- Add `Info.plist` with `LSUIElement = true`.
- Add menu bar controller.
- Add permission checker and status menu.

Milestone 2: Dock hover Probe

- Implement Dock AX observer.
- Log hovered Dock app identity.
- Validate mouse-inside-Dock-item at notification time and after hover delay.
- Implement mouse-leave polling using Dock item frame or Dock list bounds.
- Add health check and reset behavior.

Milestone 3: Window query Probe

- Implement ScreenCaptureKit window enumeration.
- Filter to current interactive Space visible-window approximation.
- Add AX enrichment best effort.
- Log AX mapping success/failure for each returned window.
- Add menu action to query frontmost app.

Milestone 4: Thumbnail Probe

- Implement static thumbnail capture.
- Add short TTL cache.
- Log failures without crashing.

Milestone 5: Activation Probe

- Implement app activation and AX raise.
- Test exact click/select behavior against acceptance apps.
- Do not proceed to polished preview UI if VS Code, Chrome, Typora, or IINA cannot raise selected windows reliably through public APIs.

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
- No-window app: hover an app with no eligible current interactive Space windows; verify no panel appears.
- Missing Accessibility permission: menu shows missing state; Dock hover does not spam alerts.
- Missing Screen Recording permission: menu shows missing state; normal Dock hover preview is suppressed and must not crash.
- Dock restart: run `killall Dock`; app should recover observer after Dock returns.
- Multi-monitor: panel appears on the screen containing the Dock/mouse and stays inside visible bounds.
- Dock auto-hide: with Dock auto-hide enabled, hover should show preview only while the Dock item is actually under the mouse; panel hides cleanly when Dock hides.
- Left/right Dock: panel is positioned beside the Dock item or falls back to mouse location without leaving screen bounds.
- Other Space: open an app window on another Space; verify the MVP does not intentionally list or switch to it from the current Space.
- Full-screen Space: full-screen windows do not need previews; hover must not trigger disruptive Space switching.
- Stage Manager: characterize whether hidden/recent sets appear in ScreenCaptureKit and document any mismatch.
- Hidden app: hide an app with windows; hover should not show stale unusable cards unless ScreenCaptureKit reports eligible on-screen windows.
- Partially covered window: window may still appear; exact occlusion is not part of V1.

Non-goals to explicitly verify:

- Minimized windows do not need to appear.
- Other Space windows do not need to appear.
- Full-screen app windows do not need to be handled.
- Closing/minimizing from preview is absent.

## 10. Risks And Decisions

Risk: Dock AX selected-child events may change across macOS versions.

Decision: Use DockDoor's proven AX notification strategy as a wake-up path, but validate the mouse against Dock item geometry before showing UI. Add a health check and reset path.

Risk: Dock AX selected child may persist after the mouse leaves the Dock item.

Decision: Mouse-leave polling and delayed-show validation must use Dock item frame containment or Dock list bounds. Bundle ID equality alone is not sufficient.

Risk: Public screenshot APIs may produce blank or stale images for some apps.

Decision: Keep thumbnails optional. Static image failure degrades to app icon plus title. Do not block MVP on perfect screenshots.

Risk: ScreenCaptureKit on-screen windows may not exactly equal current Mission Control Space membership, especially with Stage Manager and multiple displays.

Decision: Treat ScreenCaptureKit as a current-interactive-environment approximation. Probe and document mismatches. Do not attempt private Space enumeration in V1.

Risk: WPS may expose windows through helper processes or nonstandard AX hierarchy.

Decision: Keep generic matching by PID/bundle first. Characterize WPS during Probe and only add owner-mapping logic if needed.

Risk: Exact AX window raise may fail for some apps.

Decision: Use public AX raise/main-window setting first and record exact raise success during Probe. Failure is silent in UX, but a high failure rate blocks polished UI. Do not rely on `.activateIgnoringOtherApps` because it is deprecated and has no effect on modern macOS.

Risk: Private APIs may be tempting for AX-window ID mapping, Dock orientation, or exact activation.

Decision: V1 does not use private APIs. Private experiments may be isolated behind Probe-only code paths and require an explicit post-Probe decision before becoming product code.

Risk: Missing Screen Recording permission can break both thumbnail capture and ScreenCaptureKit window enumeration.

Decision: Suppress normal Dock hover previews when Screen Recording is missing. Show permission state in the menu bar and avoid repeated hover prompts.

Risk: Xcode selection can drift between Command Line Tools and full Xcode.

Decision: Full Xcode is now active locally. Keep full Xcode as a build prerequisite for the final app and re-check `xcode-select -p` before implementation.

## 11. Acceptance Criteria

The MVP is complete when:

- The app runs as a menu bar utility and does not show its own Dock icon.
- It detects required permissions and provides menu actions to resolve missing permissions.
- Hovering Dock icons for the acceptance apps shows previews only while the mouse is still on the target Dock item.
- Previews list eligible windows from the current interactive Space approximation and do not intentionally include minimized or other-Space windows.
- The panel shows at most 8 cards with app icon, static thumbnail or placeholder, and title.
- Clicking a card activates the app and raises the selected window for VS Code, Chrome, Typora, and IINA in the tested Probe scenarios.
- WPS is either supported generically or documented as a characterized V2 exception with no crash or disruptive behavior.
- The panel hides when the mouse leaves or after a card click.
- Missing thumbnails and apps with no windows do not produce disruptive UI.
- Missing Accessibility or Screen Recording permissions suppress normal hover previews and are reported through the menu bar/status UI.
- Dock restart, Dock auto-hide, and multi-monitor positioning are handled without stuck panels.

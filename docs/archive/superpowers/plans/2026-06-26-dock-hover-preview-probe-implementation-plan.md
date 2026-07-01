# Dock Hover Preview Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable macOS menu bar Probe app that validates Dock hover detection, ScreenCaptureKit window discovery, thumbnail capture, and exact window activation before any polished preview UI work begins.

**Architecture:** Create a small SwiftPM-based AppKit probe that can be packaged as a `.app` with a stable bundle identifier for TCC permissions. The app exposes a status-item menu, writes structured probe logs, and implements each risky subsystem behind small services so Probe results can directly inform the later MVP app. The Probe deliberately avoids private APIs and avoids the final SwiftUI preview panel.

**Tech Stack:** Swift 6.3, AppKit, ApplicationServices Accessibility API, ScreenCaptureKit, CoreGraphics, Swift Concurrency, XCTest, shell scripts for local `.app` bundling.

---

## Source Spec

Use this design document as the source of truth:

- `docs/superpowers/specs/2026-06-25-dock-hover-preview-mvp-technical-design.md`

Probe implementation must stop before polished UI. The deliverable is a menu bar utility with debug actions and logs proving or disproving the hard Probe gates.

## Planned File Structure

- Create: `Package.swift`
  SwiftPM package with one executable target and one test target.
- Create: `Sources/DockHoverPreviewProbe/ProbeApp.swift`
  App entry point and `NSApplication` bootstrap.
- Create: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
  Wires services, status menu, and lifecycle.
- Create: `Sources/DockHoverPreviewProbe/MenuBarController.swift`
  Status item and debug menu actions.
- Create: `Sources/DockHoverPreviewProbe/ProbeLogger.swift`
  Structured console and in-memory log sink.
- Create: `Sources/DockHoverPreviewProbe/ProbeModels.swift`
  Shared models for permissions, Dock hover, preview windows, thumbnails, and activation results.
- Create: `Sources/DockHoverPreviewProbe/PermissionService.swift`
  Accessibility and Screen Recording permission checks and settings openers.
- Create: `Sources/DockHoverPreviewProbe/DockHoverMonitor.swift`
  Dock AX observer, selected-child wake-up, frame validation, and recovery.
- Create: `Sources/DockHoverPreviewProbe/AXHelpers.swift`
  Small typed wrappers for AX attribute reads, frame extraction, and errors.
- Create: `Sources/DockHoverPreviewProbe/GeometryHelpers.swift`
  Pure geometry helpers for frame containment and AX/ScreenCaptureKit frame matching.
- Create: `Sources/DockHoverPreviewProbe/WindowQueryService.swift`
  ScreenCaptureKit window enumeration and AX enrichment.
- Create: `Sources/DockHoverPreviewProbe/ThumbnailService.swift`
  Static thumbnail capture through public ScreenCaptureKit first, CoreGraphics fallback second.
- Create: `Sources/DockHoverPreviewProbe/ActivationService.swift`
  Public AX raise and app activation path.
- Create: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
  Coordinates menu actions, hover delay, permission gates, query, thumbnail, and activation probes.
- Create: `Sources/DockHoverPreviewProbe/Info.plist`
  Bundle metadata with `LSUIElement`, stable bundle id, and privacy descriptions.
- Create: `Scripts/build_probe_app.sh`
  Builds SwiftPM executable and packages `build/DockHoverPreviewProbe.app`.
- Create: `Scripts/run_probe_app.sh`
  Builds and opens the packaged app.
- Create: `Tests/DockHoverPreviewProbeTests/GeometryHelpersTests.swift`
  Unit tests for geometry and matching helpers.
- Create: `Tests/DockHoverPreviewProbeTests/ProbeModelsTests.swift`
  Unit tests for identities, cache keys, and log summaries.
- Create: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`
  Manual Probe evidence checklist.

## Hard Gates

Do not proceed to the polished preview panel until these are true and recorded in `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`:

- Dock hover candidate is not emitted after the mouse leaves the Dock item.
- Dock item frame or Dock list bounds fallback is available.
- VS Code, Chrome, Typora, and IINA visible windows are listed correctly on the current interactive Space.
- AX mapping for VS Code, Chrome, Typora, and IINA is good enough to raise the exact selected window.
- At least one static thumbnail method works after Screen Recording permission is granted.
- Query plus first placeholder data is available within 150 ms after the 250 ms hover delay on the local machine.
- `killall Dock` recovery happens within 10 seconds.

## Task 1: SwiftPM Probe Skeleton And App Bundle

**Files:**
- Create: `Package.swift`
- Create: `Sources/DockHoverPreviewProbe/ProbeApp.swift`
- Create: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Create: `Sources/DockHoverPreviewProbe/Info.plist`
- Create: `Scripts/build_probe_app.sh`
- Create: `Scripts/run_probe_app.sh`

- [ ] **Step 1: Create the SwiftPM package manifest**

Write `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockHoverPreviewProbe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DockHoverPreviewProbe", targets: ["DockHoverPreviewProbe"])
    ],
    targets: [
        .executableTarget(
            name: "DockHoverPreviewProbe",
            path: "Sources/DockHoverPreviewProbe",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .testTarget(
            name: "DockHoverPreviewProbeTests",
            dependencies: ["DockHoverPreviewProbe"],
            path: "Tests/DockHoverPreviewProbeTests"
        )
    ]
)
```

- [ ] **Step 2: Add the app entry point**

Write `Sources/DockHoverPreviewProbe/ProbeApp.swift`:

```swift
import AppKit

@main
enum ProbeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
```

- [ ] **Step 3: Add a minimal app delegate**

Write `Sources/DockHoverPreviewProbe/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var menuBarController: MenuBarController!
    private var orchestrator: ProbeOrchestrator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger = ProbeLogger()
        permissionService = SystemPermissionService(logger: logger)
        orchestrator = ProbeOrchestrator(permissionService: permissionService, logger: logger)
        menuBarController = MenuBarController(permissionService: permissionService, orchestrator: orchestrator, logger: logger)
        menuBarController.install()
        orchestrator.start()
        logger.info("app.launched bundleIdentifier=com.zong.DockHoverPreviewProbe")
    }

    func applicationWillTerminate(_ notification: Notification) {
        orchestrator.stop()
        logger.info("app.terminated")
    }
}
```

- [ ] **Step 4: Add bundle metadata**

Write `Sources/DockHoverPreviewProbe/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DockHoverPreviewProbe</string>
    <key>CFBundleIdentifier</key>
    <string>com.zong.DockHoverPreviewProbe</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DockHoverPreviewProbe</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>DockHoverPreviewProbe uses public activation APIs while testing window switching behavior.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>DockHoverPreviewProbe captures static window thumbnails during local probe testing.</string>
</dict>
</plist>
```

- [ ] **Step 5: Add the app bundling script**

Write `Scripts/build_probe_app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockHoverPreviewProbe"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_DIR="$ROOT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

EXECUTABLE_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Sources/DockHoverPreviewProbe/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
```

- [ ] **Step 6: Add the run script**

Write `Scripts/run_probe_app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/Scripts/build_probe_app.sh")"
open "$APP_PATH"
echo "Opened $APP_PATH"
```

- [ ] **Step 7: Make scripts executable**

Run:

```bash
chmod +x Scripts/build_probe_app.sh Scripts/run_probe_app.sh
```

Expected: no output and exit code 0.

- [ ] **Step 8: Run the initial build and observe expected compile failures**

Run:

```bash
swift build
```

Expected: failure naming missing symbols such as `ProbeLogger`, `PermissionService`, `MenuBarController`, and `ProbeOrchestrator`. This confirms the skeleton is wired and the next tasks define the dependencies.

- [ ] **Step 9: Commit the skeleton**

Run:

```bash
git add Package.swift Sources/DockHoverPreviewProbe/ProbeApp.swift Sources/DockHoverPreviewProbe/AppDelegate.swift Sources/DockHoverPreviewProbe/Info.plist Scripts/build_probe_app.sh Scripts/run_probe_app.sh
git commit -m "chore: add dock hover preview probe skeleton"
```

Expected: commit succeeds.

## Task 2: Models, Logging, And Pure Geometry Tests

**Files:**
- Create: `Sources/DockHoverPreviewProbe/ProbeLogger.swift`
- Create: `Sources/DockHoverPreviewProbe/ProbeModels.swift`
- Create: `Sources/DockHoverPreviewProbe/GeometryHelpers.swift`
- Create: `Tests/DockHoverPreviewProbeTests/GeometryHelpersTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/ProbeModelsTests.swift`

- [ ] **Step 1: Write geometry tests first**

Write `Tests/DockHoverPreviewProbeTests/GeometryHelpersTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class GeometryHelpersTests: XCTestCase {
    func testContainsWithToleranceAcceptsSlightlyOutsidePoint() {
        let rect = CGRect(x: 100, y: 200, width: 50, height: 60)
        XCTAssertTrue(GeometryHelpers.contains(CGPoint(x: 99.5, y: 230), in: rect, tolerance: 1))
        XCTAssertFalse(GeometryHelpers.contains(CGPoint(x: 98.5, y: 230), in: rect, tolerance: 1))
    }

    func testFrameMatchScorePrefersCloseFrames() {
        let scFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        let closeAXFrame = CGRect(x: 102, y: 99, width: 798, height: 602)
        let farAXFrame = CGRect(x: 600, y: 500, width: 300, height: 200)
        XCTAssertGreaterThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: closeAXFrame), 0.95)
        XCTAssertLessThan(GeometryHelpers.frameMatchScore(scFrame: scFrame, axFrame: farAXFrame), 0.40)
    }
}
```

- [ ] **Step 2: Write model tests first**

Write `Tests/DockHoverPreviewProbeTests/ProbeModelsTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class ProbeModelsTests: XCTestCase {
    func testPreviewWindowIdentityUsesPidAndWindowID() {
        let lhs = PreviewWindowID(pid: 10, windowID: 20)
        let rhs = PreviewWindowID(pid: 10, windowID: 20)
        let other = PreviewWindowID(pid: 11, windowID: 20)
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, other)
    }

    func testThumbnailCacheKeyIncludesFrameSizeAndTitle() {
        let id = PreviewWindowID(pid: 1, windowID: 2)
        let key = ThumbnailCacheKey(id: id, frame: CGRect(x: 0, y: 0, width: 640, height: 480), title: "One")
        let changedTitle = ThumbnailCacheKey(id: id, frame: CGRect(x: 0, y: 0, width: 640, height: 480), title: "Two")
        XCTAssertNotEqual(key, changedTitle)
    }
}
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
swift test --filter GeometryHelpersTests
swift test --filter ProbeModelsTests
```

Expected: failures for missing `GeometryHelpers`, `PreviewWindowID`, and `ThumbnailCacheKey`.

- [ ] **Step 4: Add structured logging**

Write `Sources/DockHoverPreviewProbe/ProbeLogger.swift`:

```swift
import Foundation

final class ProbeLogger: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    func info(_ message: String) {
        append(level: "INFO", message: message)
    }

    func warning(_ message: String) {
        append(level: "WARN", message: message)
    }

    func error(_ message: String) {
        append(level: "ERROR", message: message)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    private func append(level: String, message: String) {
        let line = "\(Self.timestamp()) [\(level)] \(message)"
        lock.lock()
        entries.append(line)
        lock.unlock()
        NSLog("%@", line)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
```

- [ ] **Step 5: Add Probe models**

Write `Sources/DockHoverPreviewProbe/ProbeModels.swift`:

```swift
import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

struct PermissionState: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

struct HoveredDockApp: Equatable {
    let app: NSRunningApplication
    let bundleIdentifier: String
    let dockItemElement: AXUIElement
    let dockItemFrame: CGRect?
}

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

struct ThumbnailCacheKey: Hashable {
    let id: PreviewWindowID
    let width: Int
    let height: Int
    let title: String

    init(id: PreviewWindowID, frame: CGRect, title: String) {
        self.id = id
        self.width = Int(frame.width.rounded())
        self.height = Int(frame.height.rounded())
        self.title = title
    }
}

struct ActivationProbeResult {
    let windowID: CGWindowID
    let title: String
    let hadAXElement: Bool
    let raiseSucceeded: Bool
    let appActivateRequestSucceeded: Bool
}
```

- [ ] **Step 6: Add pure geometry helpers**

Write `Sources/DockHoverPreviewProbe/GeometryHelpers.swift`:

```swift
import CoreGraphics

enum GeometryHelpers {
    static func contains(_ point: CGPoint, in rect: CGRect, tolerance: CGFloat) -> Bool {
        rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    static func frameMatchScore(scFrame: CGRect, axFrame: CGRect) -> Double {
        guard scFrame.width > 0, scFrame.height > 0, axFrame.width > 0, axFrame.height > 0 else {
            return 0
        }
        let intersection = scFrame.intersection(axFrame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = scFrame.width * scFrame.height + axFrame.width * axFrame.height - intersectionArea
        guard unionArea > 0 else {
            return 0
        }
        return Double(intersectionArea / unionArea)
    }
}
```

- [ ] **Step 7: Run tests and verify they pass**

Run:

```bash
swift test --filter GeometryHelpersTests
swift test --filter ProbeModelsTests
```

Expected: both test filters pass.

- [ ] **Step 8: Commit models and tests**

Run:

```bash
git add Sources/DockHoverPreviewProbe/ProbeLogger.swift Sources/DockHoverPreviewProbe/ProbeModels.swift Sources/DockHoverPreviewProbe/GeometryHelpers.swift Tests/DockHoverPreviewProbeTests/GeometryHelpersTests.swift Tests/DockHoverPreviewProbeTests/ProbeModelsTests.swift
git commit -m "test: add probe models and geometry helpers"
```

Expected: commit succeeds.

## Task 3: Permission Service And Status Menu

**Files:**
- Create: `Sources/DockHoverPreviewProbe/PermissionService.swift`
- Create: `Sources/DockHoverPreviewProbe/MenuBarController.swift`
- Create: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`

- [ ] **Step 1: Add permission service interfaces and implementation**

Write `Sources/DockHoverPreviewProbe/PermissionService.swift`:

```swift
import AppKit
import ApplicationServices
import CoreGraphics

protocol PermissionService: AnyObject {
    var currentState: PermissionState { get }
    func refresh() -> PermissionState
    func requestAccessibilityPrompt()
    func openAccessibilitySettings()
    func openScreenRecordingSettings()
}

final class SystemPermissionService: PermissionService {
    private(set) var currentState: PermissionState
    private let logger: ProbeLogger

    init(logger: ProbeLogger) {
        self.logger = logger
        self.currentState = PermissionState(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    func refresh() -> PermissionState {
        currentState = PermissionState(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
        logger.info("permissions.refresh accessibility=\(currentState.accessibilityGranted) screenRecording=\(currentState.screenRecordingGranted)")
        return currentState
    }

    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("permissions.accessibilityPrompt trusted=\(trusted)")
        _ = refresh()
    }

    func openAccessibilitySettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSettings(urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.error("permissions.openSettings.invalidURL \(urlString)")
            return
        }
        NSWorkspace.shared.open(url)
        logger.info("permissions.openSettings \(urlString)")
    }
}
```

- [ ] **Step 2: Add a no-op orchestrator shell**

Write `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`:

```swift
import AppKit

final class ProbeOrchestrator {
    private let permissionService: PermissionService
    private let logger: ProbeLogger

    init(permissionService: PermissionService, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.logger = logger
    }

    func start() {
        let state = permissionService.refresh()
        logger.info("orchestrator.start accessibility=\(state.accessibilityGranted) screenRecording=\(state.screenRecordingGranted)")
    }

    func stop() {
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        logger.info("debug.frontmost.placeholder app=\(appName)")
    }
}
```

- [ ] **Step 3: Add the status menu**

Write `Sources/DockHoverPreviewProbe/MenuBarController.swift`:

```swift
import AppKit

final class MenuBarController {
    private let permissionService: PermissionService
    private let orchestrator: ProbeOrchestrator
    private let logger: ProbeLogger
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(permissionService: PermissionService, orchestrator: ProbeOrchestrator, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.orchestrator = orchestrator
        self.logger = logger
    }

    func install() {
        statusItem.button?.title = "DHP"
        rebuildMenu()
        logger.info("menu.installed")
    }

    private func rebuildMenu() {
        let state = permissionService.refresh()
        let menu = NSMenu()
        menu.addItem(disabledItem("Accessibility: \(state.accessibilityGranted ? "granted" : "missing")"))
        menu.addItem(disabledItem("Screen Recording: \(state.screenRecordingGranted ? "granted" : "missing")"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Request Accessibility Prompt", #selector(requestAccessibilityPrompt)))
        menu.addItem(actionItem("Open Accessibility Settings", #selector(openAccessibilitySettings)))
        menu.addItem(actionItem("Open Screen Recording Settings", #selector(openScreenRecordingSettings)))
        menu.addItem(actionItem("Refresh Permissions", #selector(refreshPermissions)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Debug: Show Preview For Frontmost App", #selector(showFrontmostAppProbe)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit", #selector(quit)))
        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func requestAccessibilityPrompt() {
        permissionService.requestAccessibilityPrompt()
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        permissionService.openScreenRecordingSettings()
    }

    @objc private func refreshPermissions() {
        _ = permissionService.refresh()
        rebuildMenu()
    }

    @objc private func showFrontmostAppProbe() {
        orchestrator.showFrontmostAppProbe()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 4: Build the app**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Package and open the app**

Run:

```bash
Scripts/run_probe_app.sh
```

Expected: `build/DockHoverPreviewProbe.app` opens and a `DHP` menu bar item appears.

- [ ] **Step 6: Manually verify permission menu behavior**

Run:

```bash
log stream --style compact --predicate 'process == "DockHoverPreviewProbe"'
```

Expected: logs include `app.launched`, `permissions.refresh`, and `menu.installed`. Use menu actions to open Accessibility and Screen Recording settings. Record permission state in the Probe checklist.

- [ ] **Step 7: Commit permission and menu work**

Run:

```bash
git add Sources/DockHoverPreviewProbe/PermissionService.swift Sources/DockHoverPreviewProbe/MenuBarController.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift
git commit -m "feat: add probe permission status menu"
```

Expected: commit succeeds.

## Task 4: Dock AX Hover Monitor Probe

**Files:**
- Create: `Sources/DockHoverPreviewProbe/AXHelpers.swift`
- Create: `Sources/DockHoverPreviewProbe/DockHoverMonitor.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`

- [ ] **Step 1: Add AX helper wrappers**

Write `Sources/DockHoverPreviewProbe/AXHelpers.swift`:

```swift
import ApplicationServices
import CoreGraphics

enum AXReadError: Error, CustomStringConvertible {
    case copyFailed(attribute: String, code: AXError)
    case typeMismatch(attribute: String)

    var description: String {
        switch self {
        case let .copyFailed(attribute, code):
            return "AX copy failed attribute=\(attribute) code=\(code.rawValue)"
        case let .typeMismatch(attribute):
            return "AX type mismatch attribute=\(attribute)"
        }
    }
}

enum AXHelpers {
    static func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement, as type: T.Type) throws -> T {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            throw AXReadError.copyFailed(attribute: attribute as String, code: result)
        }
        guard let typed = value as? T else {
            throw AXReadError.typeMismatch(attribute: attribute as String)
        }
        return typed
    }

    static func optionalAttribute<T>(_ attribute: CFString, from element: AXUIElement, as type: T.Type) -> T? {
        try? copyAttribute(attribute, from: element, as: type)
    }

    static func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        optionalAttribute(attribute, from: element, as: String.self)
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = optionalAttribute(kAXPositionAttribute as CFString, from: element, as: AXValue.self),
            let sizeValue = optionalAttribute(kAXSizeAttribute as CFString, from: element, as: AXValue.self)
        else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }
}
```

- [ ] **Step 2: Add Dock hover monitor**

Write `Sources/DockHoverPreviewProbe/DockHoverMonitor.swift`:

```swift
import AppKit
import ApplicationServices
import CoreGraphics

protocol DockHoverMonitorDelegate: AnyObject {
    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp)
    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor)
}

private func dockAXObserverCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let monitor = Unmanaged<DockHoverMonitor>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.processSelectedChildNotification()
    }
}

final class DockHoverMonitor {
    weak var delegate: DockHoverMonitorDelegate?

    private let logger: ProbeLogger
    private var observer: AXObserver?
    private var dockListElement: AXUIElement?
    private var dockPID: pid_t?
    private var healthTimer: Timer?
    private var pollTimer: Timer?
    private var lastHovered: HoveredDockApp?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func start() {
        stop()
        subscribe()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.healthCheck()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.pollMouseLeave()
        }
        logger.info("dock.start")
    }

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        healthTimer?.invalidate()
        pollTimer?.invalidate()
        observer = nil
        dockListElement = nil
        dockPID = nil
        lastHovered = nil
        logger.info("dock.stop")
    }

    func processSelectedChildNotification() {
        guard let hovered = resolveCurrentHoveredDockApp() else {
            if lastHovered != nil {
                logger.info("dock.hoverLost reason=noCandidate")
                lastHovered = nil
                delegate?.dockHoverMonitorDidLoseHover(self)
            }
            return
        }
        lastHovered = hovered
        logger.info("dock.hover app=\(hovered.app.localizedName ?? "unknown") bundle=\(hovered.bundleIdentifier) pid=\(hovered.app.processIdentifier) frame=\(String(describing: hovered.dockItemFrame))")
        delegate?.dockHoverMonitor(self, didHover: hovered)
    }

    func resolveCurrentHoveredDockApp() -> HoveredDockApp? {
        guard let dockListElement else { return nil }
        guard let selected = AXHelpers.optionalAttribute(kAXSelectedChildrenAttribute as CFString, from: dockListElement, as: [AXUIElement].self)?.first else {
            return nil
        }
        let subrole = AXHelpers.stringAttribute(kAXSubroleAttribute as CFString, from: selected)
        guard subrole == "AXApplicationDockItem" else {
            logger.info("dock.selectedIgnored subrole=\(subrole ?? "nil")")
            return nil
        }
        guard let url = AXHelpers.optionalAttribute(kAXURLAttribute as CFString, from: selected, as: URL.self) else {
            logger.warning("dock.selectedMissingURL")
            return nil
        }
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            logger.warning("dock.bundleResolveFailed url=\(url.path)")
            return nil
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            logger.info("dock.appNotRunning bundle=\(bundleIdentifier)")
            return nil
        }
        let frame = AXHelpers.frame(of: selected)
        if let frame {
            let mouse = NSEvent.mouseLocation
            guard GeometryHelpers.contains(mouse, in: frame, tolerance: 2) else {
                logger.info("dock.selectedStale bundle=\(bundleIdentifier) mouse=\(mouse) frame=\(frame)")
                return nil
            }
        }
        return HoveredDockApp(app: app, bundleIdentifier: bundleIdentifier, dockItemElement: selected, dockItemFrame: frame)
    }

    private func subscribe() {
        guard AXIsProcessTrusted() else {
            logger.warning("dock.subscribeSkipped accessibility=false")
            return
        }
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            logger.error("dock.notRunning")
            return
        }
        dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let children = AXHelpers.optionalAttribute(kAXChildrenAttribute as CFString, from: dockElement, as: [AXUIElement].self) else {
            logger.error("dock.childrenMissing")
            return
        }
        guard let list = children.first(where: { AXHelpers.stringAttribute(kAXRoleAttribute as CFString, from: $0) == kAXListRole }) else {
            logger.error("dock.listMissing")
            return
        }
        var newObserver: AXObserver?
        let createResult = AXObserverCreate(dockApp.processIdentifier, dockAXObserverCallback, &newObserver)
        guard createResult == .success, let newObserver else {
            logger.error("dock.observerCreateFailed code=\(createResult.rawValue)")
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(newObserver, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
        guard addResult == .success else {
            logger.error("dock.notificationSubscribeFailed code=\(addResult.rawValue)")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        observer = newObserver
        dockListElement = list
        logger.info("dock.subscribed pid=\(dockApp.processIdentifier)")
    }

    private func healthCheck() {
        let currentDock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        if currentDock?.processIdentifier != dockPID {
            logger.warning("dock.pidChanged old=\(String(describing: dockPID)) new=\(String(describing: currentDock?.processIdentifier))")
            stop()
            start()
            return
        }
        guard let dockListElement else {
            logger.warning("dock.healthMissingList")
            stop()
            start()
            return
        }
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(dockListElement, kAXRoleAttribute as CFString, &role)
        if result == .invalidUIElement || result == .cannotComplete {
            logger.warning("dock.healthInvalid code=\(result.rawValue)")
            stop()
            start()
        }
    }

    private func pollMouseLeave() {
        guard let lastHovered else { return }
        guard let frame = lastHovered.dockItemFrame else { return }
        if !GeometryHelpers.contains(NSEvent.mouseLocation, in: frame, tolerance: 2) {
            self.lastHovered = nil
            logger.info("dock.hoverLost reason=mouseOutside frame=\(frame)")
            delegate?.dockHoverMonitorDidLoseHover(self)
        }
    }
}
```

- [ ] **Step 3: Wire Dock monitor into orchestrator**

Replace `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift` with:

```swift
import AppKit

final class ProbeOrchestrator: DockHoverMonitorDelegate {
    private let permissionService: PermissionService
    private let logger: ProbeLogger
    private lazy var dockHoverMonitor = DockHoverMonitor(logger: logger)
    private var pendingHoverWorkItem: DispatchWorkItem?

    init(permissionService: PermissionService, logger: ProbeLogger) {
        self.permissionService = permissionService
        self.logger = logger
        self.dockHoverMonitor.delegate = self
    }

    func start() {
        let state = permissionService.refresh()
        logger.info("orchestrator.start accessibility=\(state.accessibilityGranted) screenRecording=\(state.screenRecordingGranted)")
        if state.accessibilityGranted {
            dockHoverMonitor.start()
        } else {
            logger.warning("orchestrator.dockSkipped accessibility=false")
        }
    }

    func stop() {
        pendingHoverWorkItem?.cancel()
        dockHoverMonitor.stop()
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
        logger.info("debug.frontmost.placeholder app=\(appName)")
    }

    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp) {
        pendingHoverWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak monitor] in
            guard let self, let monitor else { return }
            let stillHovered = monitor.resolveCurrentHoveredDockApp()
            let matches = stillHovered?.bundleIdentifier == app.bundleIdentifier
            let mouseInside = app.dockItemFrame.map { GeometryHelpers.contains(NSEvent.mouseLocation, in: $0, tolerance: 2) } ?? false
            self.logger.info("dock.hoverDelayed bundle=\(app.bundleIdentifier) matches=\(matches) mouseInside=\(mouseInside) frame=\(String(describing: app.dockItemFrame))")
        }
        pendingHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
        pendingHoverWorkItem?.cancel()
        logger.info("dock.hoverLost.orchestrator")
    }
}
```

- [ ] **Step 4: Build and run**

Run:

```bash
swift build
Scripts/run_probe_app.sh
```

Expected: build succeeds, app opens, and logs include `dock.subscribed` after Accessibility permission is granted.

- [ ] **Step 5: Manual Dock hover Probe**

Run:

```bash
log stream --style compact --predicate 'process == "DockHoverPreviewProbe"'
```

Hover VS Code, Chrome, WPS, Typora, and IINA Dock icons. Expected logs for each app include:

```text
dock.hover app=<name> bundle=<bundle id> pid=<pid> frame=Optional(...)
dock.hoverDelayed bundle=<bundle id> matches=true mouseInside=true frame=Optional(...)
```

Move the mouse away before 250 ms. Expected: no `mouseInside=true` delayed line for the stale hover.

- [ ] **Step 6: Verify Dock restart recovery**

Run:

```bash
killall Dock
```

Expected: within 10 seconds logs include `dock.pidChanged` followed by `dock.subscribed`.

- [ ] **Step 7: Create Probe checklist and record Dock results**

Write `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`:

```markdown
# Dock Hover Preview Probe Checklist

Date: 2026-06-26

## Environment

- macOS: not run
- Xcode: not run
- Dock position: not run
- Dock auto-hide: not run
- Stage Manager: not run
- Displays: not run

## Permissions

- Accessibility: not run
- Screen Recording: not run

## Dock Hover

| App | Bundle ID | PID Logged | Dock Frame Logged | 250 ms Mouse-Inside Validation | Leave Before Delay Suppressed |
| --- | --- | --- | --- | --- | --- |
| VS Code | not run | not run | not run | not run | not run |
| Chrome | not run | not run | not run | not run | not run |
| WPS | not run | not run | not run | not run | not run |
| Typora | not run | not run | not run | not run | not run |
| IINA | not run | not run | not run | not run | not run |

## Dock Restart

- `killall Dock` recovery time: not run
- Recovery notes: not run
```

- [ ] **Step 8: Commit Dock hover Probe**

Run:

```bash
git add Sources/DockHoverPreviewProbe/AXHelpers.swift Sources/DockHoverPreviewProbe/DockHoverMonitor.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md
git commit -m "feat: add dock hover probe monitor"
```

Expected: commit succeeds.

## Task 5: ScreenCaptureKit Window Query And AX Matching Probe

**Files:**
- Create: `Sources/DockHoverPreviewProbe/WindowQueryService.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`

- [ ] **Step 1: Add window query service**

Write `Sources/DockHoverPreviewProbe/WindowQueryService.swift`:

```swift
import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

protocol WindowQueryService {
    func windows(for app: NSRunningApplication) async -> [PreviewWindow]
}

final class ScreenCaptureWindowQueryService: WindowQueryService {
    private let logger: ProbeLogger

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func windows(for app: NSRunningApplication) async -> [PreviewWindow] {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let candidates = content.windows.filter { window in
                let ownerMatchesPID = window.owningApplication?.processID == app.processIdentifier
                let ownerMatchesBundle = window.owningApplication?.bundleIdentifier == app.bundleIdentifier
                return (ownerMatchesPID || ownerMatchesBundle)
                    && window.isOnScreen
                    && window.frame.width >= 80
                    && window.frame.height >= 60
                    && window.windowLayer == 0
            }
            let axWindows = readAXWindows(for: app)
            let mapped = candidates.map { scWindow in
                makePreviewWindow(scWindow: scWindow, app: app, axWindows: axWindows)
            }
            let sorted = mapped.sorted { lhs, rhs in
                let lhsArea = lhs.frame.width * lhs.frame.height
                let rhsArea = rhs.frame.width * rhs.frame.height
                if lhsArea != rhsArea { return lhsArea > rhsArea }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.cgWindowID < rhs.cgWindowID
            }
            let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            logger.info("windows.query app=\(app.localizedName ?? "unknown") count=\(sorted.count) elapsedMS=\(elapsedMS)")
            sorted.prefix(8).forEach { window in
                logger.info("windows.item id=\(window.cgWindowID) pid=\(window.id.pid) title=\(window.title) frame=\(window.frame) axMatched=\(window.axElement != nil)")
            }
            return Array(sorted.prefix(8))
        } catch {
            logger.error("windows.queryFailed app=\(app.localizedName ?? "unknown") error=\(error)")
            return []
        }
    }

    private func readAXWindows(for app: NSRunningApplication) -> [AXUIElement] {
        guard AXIsProcessTrusted() else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        return AXHelpers.optionalAttribute(kAXWindowsAttribute as CFString, from: appElement, as: [AXUIElement].self) ?? []
    }

    private func makePreviewWindow(scWindow: SCWindow, app: NSRunningApplication, axWindows: [AXUIElement]) -> PreviewWindow {
        let axElement = bestAXMatch(for: scWindow, axWindows: axWindows)
        let title = AXHelpers.stringAttribute(kAXTitleAttribute as CFString, from: axElement ?? AXUIElementCreateSystemWide())
            ?? scWindow.title
            ?? "(untitled)"
        return PreviewWindow(
            id: PreviewWindowID(pid: app.processIdentifier, windowID: scWindow.windowID),
            cgWindowID: scWindow.windowID,
            app: app,
            title: title,
            frame: scWindow.frame,
            scWindow: scWindow,
            axElement: axElement,
            appIcon: app.icon ?? NSImage(size: NSSize(width: 32, height: 32)),
            thumbnailSource: .screenCaptureKit(scWindow)
        )
    }

    private func bestAXMatch(for scWindow: SCWindow, axWindows: [AXUIElement]) -> AXUIElement? {
        let scored = axWindows.compactMap { ax -> (AXUIElement, Double)? in
            guard !isMinimized(ax), let frame = AXHelpers.frame(of: ax) else { return nil }
            let score = GeometryHelpers.frameMatchScore(scFrame: scWindow.frame, axFrame: frame)
            guard score >= 0.72 else { return nil }
            return (ax, score)
        }
        return scored.sorted { $0.1 > $1.1 }.first?.0
    }

    private func isMinimized(_ axWindow: AXUIElement) -> Bool {
        AXHelpers.optionalAttribute(kAXMinimizedAttribute as CFString, from: axWindow, as: Bool.self) ?? false
    }
}
```

- [ ] **Step 2: Wire frontmost debug action to window query**

Replace `showFrontmostAppProbe()` and add a property in `ProbeOrchestrator`:

```swift
private lazy var windowQueryService: WindowQueryService = ScreenCaptureWindowQueryService(logger: logger)

func showFrontmostAppProbe() {
    guard permissionService.refresh().screenRecordingGranted else {
        logger.warning("debug.frontmost.skipped screenRecording=false")
        return
    }
    guard let app = NSWorkspace.shared.frontmostApplication else {
        logger.warning("debug.frontmost.noApp")
        return
    }
    logger.info("debug.frontmost.start app=\(app.localizedName ?? "unknown") bundle=\(app.bundleIdentifier ?? "nil") pid=\(app.processIdentifier)")
    Task { [windowQueryService, logger] in
        let windows = await windowQueryService.windows(for: app)
        logger.info("debug.frontmost.done app=\(app.localizedName ?? "unknown") count=\(windows.count)")
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 4: Manual frontmost app query Probe**

Run the app, focus VS Code with three project windows, then select menu item `Debug: Show Preview For Frontmost App`.

Expected logs:

```text
debug.frontmost.start app=...
windows.query app=... count=3 elapsedMS=<number>
windows.item id=... title=... frame=... axMatched=true
debug.frontmost.done app=... count=3
```

Repeat for Chrome, Typora, IINA, and WPS. Record expected count, actual count, and AX matched count in the checklist.

- [ ] **Step 5: Add checklist section for window query**

Append to `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`:

```markdown

## Window Query And AX Mapping

| App | Expected Visible Windows | Returned Windows | AX Matched Windows | Query Time ms | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | not run | not run | not run | not run | not run |
| Chrome | not run | not run | not run | not run | not run |
| Typora | not run | not run | not run | not run | not run |
| IINA | not run | not run | not run | not run | not run |
| WPS | not run | not run | not run | not run | not run |

## Space And Display Characterization

- Other normal Space result: not run
- Full-screen Space result: not run
- Stage Manager result: not run
- Multiple display result: not run
```

- [ ] **Step 6: Commit window query work**

Run:

```bash
git add Sources/DockHoverPreviewProbe/WindowQueryService.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md
git commit -m "feat: add window query probe"
```

Expected: commit succeeds.

## Task 6: Static Thumbnail Probe

**Files:**
- Create: `Sources/DockHoverPreviewProbe/ThumbnailService.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`

- [ ] **Step 1: Add thumbnail service**

Write `Sources/DockHoverPreviewProbe/ThumbnailService.swift`:

```swift
import CoreGraphics
import CoreMedia
import ScreenCaptureKit

protocol ThumbnailService {
    func thumbnail(for window: PreviewWindow) async -> CGImage?
}

final class StaticThumbnailService: ThumbnailService {
    private let logger: ProbeLogger
    private var cache: [ThumbnailCacheKey: CGImage] = [:]

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        let key = ThumbnailCacheKey(id: window.id, frame: window.frame, title: window.title)
        if let cached = cache[key] {
            logger.info("thumbnail.cacheHit id=\(window.cgWindowID)")
            return cached
        }
        let start = CFAbsoluteTimeGetCurrent()
        let image = await captureWithScreenCaptureKit(window: window) ?? captureWithCoreGraphics(window: window)
        let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        if let image {
            cache[key] = image
            logger.info("thumbnail.success id=\(window.cgWindowID) width=\(image.width) height=\(image.height) elapsedMS=\(elapsedMS)")
        } else {
            logger.warning("thumbnail.failed id=\(window.cgWindowID) elapsedMS=\(elapsedMS)")
        }
        return image
    }

    private func captureWithScreenCaptureKit(window: PreviewWindow) async -> CGImage? {
        guard case let .screenCaptureKit(scWindow)? = window.thumbnailSource else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = 440
        configuration.height = 248
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            logger.warning("thumbnail.sckFailed id=\(window.cgWindowID) error=\(error)")
            return nil
        }
    }

    private func captureWithCoreGraphics(window: PreviewWindow) -> CGImage? {
        let array = [NSNumber(value: window.cgWindowID)] as CFArray
        return CGWindowListCreateImageFromArray(.null, array, [.boundsIgnoreFraming, .bestResolution])
    }
}
```

- [ ] **Step 2: Wire thumbnails into frontmost debug**

Add this property to `ProbeOrchestrator`:

```swift
private lazy var thumbnailService: ThumbnailService = StaticThumbnailService(logger: logger)
```

Update the `Task` body inside `showFrontmostAppProbe()`:

```swift
Task { [windowQueryService, thumbnailService, logger] in
    let windows = await windowQueryService.windows(for: app)
    logger.info("debug.frontmost.done app=\(app.localizedName ?? "unknown") count=\(windows.count)")
    for window in windows {
        let image = await thumbnailService.thumbnail(for: window)
        logger.info("debug.thumbnail.result id=\(window.cgWindowID) success=\(image != nil)")
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 4: Manual thumbnail Probe**

Run app with Screen Recording granted. Trigger frontmost debug for VS Code, Chrome, Typora, IINA, and WPS.

Expected logs include:

```text
thumbnail.success id=... width=... height=... elapsedMS=...
debug.thumbnail.result id=... success=true
```

If some windows log `thumbnail.failed`, record the app/window and whether the UI could fall back to app icon/title.

- [ ] **Step 5: Add checklist section for thumbnails**

Append to `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`:

```markdown

## Thumbnail Capture

| App | Windows Tested | ScreenCaptureKit Success | CoreGraphics Fallback Success | Blank/Stale Observed | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | not run | not run | not run | not run | not run |
| Chrome | not run | not run | not run | not run | not run |
| Typora | not run | not run | not run | not run | not run |
| IINA | not run | not run | not run | not run | not run |
| WPS | not run | not run | not run | not run | not run |
```

- [ ] **Step 6: Commit thumbnail Probe**

Run:

```bash
git add Sources/DockHoverPreviewProbe/ThumbnailService.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md
git commit -m "feat: add static thumbnail probe"
```

Expected: commit succeeds.

## Task 7: Activation Probe

**Files:**
- Create: `Sources/DockHoverPreviewProbe/ActivationService.swift`
- Modify: `Sources/DockHoverPreviewProbe/MenuBarController.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`

- [ ] **Step 1: Add activation service**

Write `Sources/DockHoverPreviewProbe/ActivationService.swift`:

```swift
import AppKit
import ApplicationServices

protocol ActivationService {
    func activate(window: PreviewWindow) -> ActivationProbeResult
}

final class AXActivationService: ActivationService {
    private let logger: ProbeLogger

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        if window.app.isHidden {
            _ = window.app.unhide()
        }
        var raiseSucceeded = false
        if let axElement = window.axElement {
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            let settable = isSettable(kAXMainWindowAttribute as CFString, on: axElement)
            var mainResult: AXError = .success
            if settable {
                mainResult = AXUIElementSetAttributeValue(axElement, kAXMainWindowAttribute as CFString, kCFBooleanTrue)
            }
            raiseSucceeded = raiseResult == .success && (!settable || mainResult == .success)
            logger.info("activation.ax id=\(window.cgWindowID) raiseCode=\(raiseResult.rawValue) mainSettable=\(settable) mainCode=\(mainResult.rawValue)")
        } else {
            logger.warning("activation.noAX id=\(window.cgWindowID) title=\(window.title)")
        }
        let activateSucceeded = window.app.activate(options: [])
        let result = ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: window.axElement != nil,
            raiseSucceeded: raiseSucceeded,
            appActivateRequestSucceeded: activateSucceeded
        )
        logger.info("activation.result id=\(result.windowID) title=\(result.title) hadAX=\(result.hadAXElement) raise=\(result.raiseSucceeded) appActivate=\(result.appActivateRequestSucceeded)")
        return result
    }

    private func isSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }
}
```

- [ ] **Step 2: Add menu item for activation of first frontmost window**

Add this menu item in `MenuBarController.rebuildMenu()` after `Debug: Show Preview For Frontmost App`:

```swift
menu.addItem(actionItem("Debug: Activate First Frontmost Window", #selector(activateFirstFrontmostWindow)))
```

Add this method to `MenuBarController`:

```swift
@objc private func activateFirstFrontmostWindow() {
    orchestrator.activateFirstFrontmostWindowProbe()
}
```

- [ ] **Step 3: Wire activation into orchestrator**

Add this property to `ProbeOrchestrator`:

```swift
private lazy var activationService: ActivationService = AXActivationService(logger: logger)
```

Add this method to `ProbeOrchestrator`:

```swift
func activateFirstFrontmostWindowProbe() {
    guard let app = NSWorkspace.shared.frontmostApplication else {
        logger.warning("activation.debug.noApp")
        return
    }
    Task { [windowQueryService, activationService, logger] in
        let windows = await windowQueryService.windows(for: app)
        guard let first = windows.first else {
            logger.warning("activation.debug.noWindows app=\(app.localizedName ?? "unknown")")
            return
        }
        let result = activationService.activate(window: first)
        logger.info("activation.debug.done id=\(result.windowID) raise=\(result.raiseSucceeded)")
    }
}
```

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Manual exact activation Probe**

For each app, put multiple windows on screen, focus the app, and choose `Debug: Activate First Frontmost Window`.

Expected logs:

```text
activation.ax id=... raiseCode=0 mainSettable=... mainCode=...
activation.result id=... hadAX=true raise=true appActivate=true
```

Manually confirm the expected window is raised. Record failures. A high failure rate for VS Code, Chrome, Typora, or IINA blocks polished UI work.

- [ ] **Step 6: Add checklist section for activation**

Append to `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`:

```markdown

## Activation

| App | Windows Tested | AX Matched | Exact Raise Success | App Activation Fallback Observed | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | not run | not run | not run | not run | not run |
| Chrome | not run | not run | not run | not run | not run |
| Typora | not run | not run | not run | not run | not run |
| IINA | not run | not run | not run | not run | not run |
| WPS | not run | not run | not run | not run | not run |
```

- [ ] **Step 7: Commit activation Probe**

Run:

```bash
git add Sources/DockHoverPreviewProbe/ActivationService.swift Sources/DockHoverPreviewProbe/MenuBarController.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md
git commit -m "feat: add window activation probe"
```

Expected: commit succeeds.

## Task 8: Probe Gate Review And Final Evidence

**Files:**
- Modify: `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`
- Create: `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`

- [ ] **Step 1: Run automated verification**

Run:

```bash
swift test
swift build
Scripts/build_probe_app.sh
```

Expected: tests pass, build succeeds, and the script prints `build/DockHoverPreviewProbe.app`.

- [ ] **Step 2: Run permission-denied checks**

Remove or deny Screen Recording permission for `DockHoverPreviewProbe` in System Settings, then run the app.

Expected:

```text
permissions.refresh accessibility=<true-or-false> screenRecording=false
debug.frontmost.skipped screenRecording=false
```

Record that normal hover preview work is suppressed. Restore Screen Recording permission before continuing.

- [ ] **Step 3: Run Dock boundary checks**

With Dock bottom and auto-hide off, hover and leave VS Code, Chrome, WPS, Typora, and IINA.

Expected:

```text
dock.hoverDelayed bundle=... matches=true mouseInside=true
dock.hoverLost reason=mouseOutside ...
```

For a leave-before-delay case, expected delayed validation logs do not show `mouseInside=true` for the stale item.

- [ ] **Step 4: Run Dock restart check**

Run:

```bash
killall Dock
```

Expected: `dock.pidChanged` and `dock.subscribed` occur within 10 seconds. Record the measured time.

- [ ] **Step 5: Run acceptance app window query checks**

For VS Code, Chrome, Typora, IINA, and WPS, trigger `Debug: Show Preview For Frontmost App`.

Expected:

```text
windows.query app=... count=... elapsedMS=...
windows.item id=... axMatched=...
thumbnail.success id=...
```

Record expected vs actual windows, AX match count, query time, and thumbnail status.

- [ ] **Step 6: Run exact activation checks**

For VS Code, Chrome, Typora, IINA, and WPS, trigger `Debug: Activate First Frontmost Window`.

Expected:

```text
activation.result id=... hadAX=true raise=true appActivate=true
```

Record exact raise successes and failures. If exact raise fails for VS Code, Chrome, Typora, or IINA, mark Probe gate failed.

- [ ] **Step 7: Run environment characterization checks**

Record behavior for:

```text
other normal Space
full-screen Space
Stage Manager enabled
Stage Manager disabled
multiple displays
Dock auto-hide enabled
left Dock
right Dock
```

Expected: no crash, no stuck panel, no intentional cross-Space switching, and enough logs to decide whether MVP can proceed.

- [ ] **Step 8: Write Probe summary**

Write `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`:

```markdown
# Dock Hover Preview Probe Summary

Date: 2026-06-26

## Verdict

- Proceed to MVP UI: not evaluated
- Blocking issues: not evaluated

## Hard Gate Results

| Gate | Result | Evidence |
| --- | --- | --- |
| Dock hover stale item suppressed | not run | not run |
| Dock frame or list fallback available | not run | not run |
| VS Code windows listed and AX matched | not run | not run |
| Chrome windows listed and AX matched | not run | not run |
| Typora windows listed and AX matched | not run | not run |
| IINA windows listed and AX matched | not run | not run |
| Static thumbnail works | not run | not run |
| Query timing within target | not run | not run |
| Dock restart recovery under 10 seconds | not run | not run |

## WPS Characterization

- Process ownership: not run
- AX hierarchy: not run
- Window query result: not run
- Activation result: not run

## Space And Display Characterization

- Other Space: not run
- Full-screen Space: not run
- Stage Manager: not run
- Multiple displays: not run

## Required Design Changes Before MVP UI

- Initial state: not evaluated
```

Replace each `not run` or `not evaluated` value with the observed result before committing. Use `fail` where evidence does not satisfy a gate.

- [ ] **Step 9: Commit Probe evidence**

Run:

```bash
git add docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md
git commit -m "docs: record dock hover preview probe results"
```

Expected: commit succeeds.

## Plan Self-Review

- Spec coverage: Tasks cover project skeleton, permissions, Dock AX hover detection, delayed mouse validation, Dock restart recovery, ScreenCaptureKit window query, AX mapping, thumbnail capture, activation, permission-denied behavior, Space/display characterization, and Probe evidence.
- Placeholder scan: The plan contains no unresolved placeholder markers and no deferred implementation steps.
- Type consistency: `PreviewWindowID`, `ThumbnailCacheKey`, `PermissionState`, `HoveredDockApp`, `PreviewWindow`, `WindowQueryService`, `ThumbnailService`, and `ActivationService` are introduced before use.
- Scope check: The plan stops at Probe evidence and does not implement the polished preview panel.

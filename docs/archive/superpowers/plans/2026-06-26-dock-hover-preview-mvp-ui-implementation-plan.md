# Dock Hover Preview MVP UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable Dock hover preview UI: a DockDoor-inspired macOS floating preview strip that shows static window cards and activates a selected window.

**Architecture:** Reuse the proven Probe services for Dock hover, permission checks, window query, thumbnail capture, and activation. Add a thin UI layer made of pure layout/state models, one AppKit `NSPanel` controller, SwiftUI preview/card views, and a `PreviewSessionController` that owns preview session state and cancels stale async work.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, ScreenCaptureKit, Accessibility, CoreGraphics, XCTest.

---

## Reference And Scope

Use [ejbills/DockDoor](https://github.com/ejbills/DockDoor) only as a visual and interaction reference:

- Preserve the native Dock and show a compact horizontal preview strip on hover.
- Use a translucent macOS material panel with compact cards, thumbnails, window titles, and click-to-activate behavior.
- Keep the preview near the hovered Dock icon and hide quickly when the hover is no longer valid.

Do not copy, translate, mechanically rewrite, or mirror DockDoor source files, helper extensions, comments, private API wrappers, or file structure. DockDoor is GPLv3; this plan keeps the MVP implementation original and uses only public APIs by default.

MVP UI boundaries:

- In scope: one floating panel, up to 8 cards, app icon, static thumbnail or placeholder, window title, click-to-activate, progressive thumbnail updates, stale-hover cancellation, permission suppression.
- Out of scope: live thumbnails, close/minimize/full-screen buttons, settings UI, app filters, keyboard switcher, search, animations beyond subtle show/hide, private APIs, polished final branding.
- Current evidence supports the normal, single-display, bottom-Dock, auto-hide-disabled environment. Other Spaces, full-screen Spaces, Stage Manager enabled, multi-display, auto-hide enabled, and left/right Dock need explicit manual runs during or after this plan.

## Existing Context

- Existing technical design: `docs/superpowers/specs/2026-06-25-dock-hover-preview-mvp-technical-design.md`
- Existing Probe summary: `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`
- Existing Probe app target: `Sources/DockHoverPreviewProbe`
- Existing tests: `Tests/DockHoverPreviewProbeTests`
- Existing build script: `Scripts/build_probe_app.sh`

Probe services already available:

- `DockHoverMonitor`: Dock AX hover notification, geometry validation, Dock restart recovery.
- `PermissionService`: Accessibility and Screen Recording state.
- `WindowQueryService`: ScreenCaptureKit window query plus AX matching.
- `ThumbnailService`: static thumbnail capture with ScreenCaptureKit first and CoreGraphics fallback.
- `ActivationService`: AX raise plus app activation.
- `ProbeLogger`: structured text logs.

## UI Design Contract

The first UI should feel like a native macOS utility, not a marketing surface:

- Panel: single borderless non-activating `NSPanel`, clear background, `.regularMaterial` SwiftUI container, 8 pt corner radius, subtle 1 px border, small shadow.
- Layout: horizontal scroll strip, 12 pt outer padding, 8 pt card spacing.
- Card: fixed 220 pt width, 124 pt thumbnail area, 28 pt title row, 18 pt app icon.
- Thumbnail: scaled to fill a fixed region, clipped to 6 pt radius. If unavailable, show a quiet placeholder using the app icon on material.
- Text: one-line title, tail truncation, system caption font. The UI should avoid instructional copy.
- Interaction: hover/press highlight on cards, click activates selected window and hides panel. Escape hides panel.
- Motion: optional 120-180 ms opacity/scale transition. Respect reduced-motion by allowing instant show/hide.
- Accessibility: each card has an accessibility label containing app name and window title. The panel does not steal app focus.

## File Structure

Create:

- `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
  - Pure preview UI state models: anchor, card view model, panel view model.
- `Sources/DockHoverPreviewProbe/PreviewPanelLayoutEngine.swift`
  - Pure geometry for bottom/left/right/missing Dock frame panel placement.
- `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
  - SwiftUI `PreviewPanelView`, `PreviewCardView`, thumbnail/placeholder rendering.
- `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`
  - AppKit `NSPanel` owner and `PreviewPanelDisplaying` implementation.
- `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
  - MainActor session coordinator for permissions, query, panel show/update, thumbnails, activation, stale cancellation.
- `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

Modify:

- `Sources/DockHoverPreviewProbe/AppDelegate.swift`
  - Create `PreviewPanelController` and pass it into `ProbeOrchestrator`.
- `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
  - Replace hover-only logging with UI preview session calls after delayed validation passes.
  - Keep existing debug logging.
- `Sources/DockHoverPreviewProbe/MenuBarController.swift`
  - Keep debug action, but make frontmost debug action use the same preview UI path.
- `Package.swift`
  - Add `SwiftUI` linked framework only if the build requires it. Try importing SwiftUI first without linker changes.

## Task Execution Rules

- Execute tasks in order.
- Use a fresh subagent for each task if using Subagent-Driven Development.
- After each task, run the listed tests and do two reviews:
  - Spec compliance review: compare task output to this plan and the technical design.
  - Code quality review: concurrency, ownership, UI lifecycle, stale async cancellation, logging, and test quality.
- Commit after each task with the listed commit message.
- Do not implement private API fallbacks.
- Do not copy DockDoor code.
- Pause for user action when macOS TCC permissions or manual UI verification are required.

---

### Task 1: Preview Panel Anchor And Layout Engine

**Files:**
- Create: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Create: `Sources/DockHoverPreviewProbe/PreviewPanelLayoutEngine.swift`
- Create: `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`

- [ ] **Step 1: Write failing layout tests**

Create `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelLayoutEngineTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let visibleFrame = CGRect(x: 0, y: 50, width: 1512, height: 900)
    private let panelSize = CGSize(width: 720, height: 180)

    func testBottomDockAnchorsPanelAboveIconAndClampsHorizontally() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 730, y: 0, width: 52, height: 48),
            mouseLocation: CGPoint(x: 756, y: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.origin.x, 396, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 58, accuracy: 0.001)
        XCTAssertEqual(frame.size.width, 720, accuracy: 0.001)
        XCTAssertEqual(frame.size.height, 180, accuracy: 0.001)
    }

    func testBottomDockNearRightEdgeClampsInsideVisibleFrame() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 1480, y: 0, width: 40, height: 48),
            mouseLocation: CGPoint(x: 1500, y: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 58, accuracy: 0.001)
    }

    func testLeftDockPlacesPanelBesideIcon() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 0, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 24, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.origin.x, 58, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 456, accuracy: 0.001)
    }

    func testRightDockPlacesPanelBesideIcon() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 1464, y: 430, width: 48, height: 52),
            mouseLocation: CGPoint(x: 1488, y: 456),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, 1454, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 456, accuracy: 0.001)
    }

    func testMissingDockFrameFallsBackToMouseLocationAndClamps() {
        let anchor = PreviewPanelAnchor(
            dockItemFrame: nil,
            mouseLocation: CGPoint(x: 1400, y: 600),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 610, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter PreviewPanelLayoutEngineTests
```

Expected: fails because `PreviewPanelAnchor` and `PreviewPanelLayoutEngine` do not exist.

- [ ] **Step 3: Add models and layout implementation**

Create `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`:

```swift
import CoreGraphics

enum DockEdge: Equatable {
    case bottom
    case left
    case right
}

struct PreviewPanelAnchor: Equatable {
    let dockItemFrame: CGRect?
    let mouseLocation: CGPoint
    let screenFrame: CGRect
    let visibleFrame: CGRect
}
```

Create `Sources/DockHoverPreviewProbe/PreviewPanelLayoutEngine.swift`:

```swift
import CoreGraphics

enum PreviewPanelLayoutEngine {
    private static let spacing: CGFloat = 10

    static func frame(for panelSize: CGSize, anchor: PreviewPanelAnchor) -> CGRect {
        let edge = inferDockEdge(anchor: anchor)
        let proposedOrigin: CGPoint
        if let dockFrame = anchor.dockItemFrame {
            switch edge {
            case .bottom:
                proposedOrigin = CGPoint(
                    x: dockFrame.midX - panelSize.width / 2,
                    y: dockFrame.maxY + spacing
                )
            case .left:
                proposedOrigin = CGPoint(
                    x: dockFrame.maxX + spacing,
                    y: dockFrame.midY - panelSize.height / 2
                )
            case .right:
                proposedOrigin = CGPoint(
                    x: dockFrame.minX - spacing - panelSize.width,
                    y: dockFrame.midY - panelSize.height / 2
                )
            }
        } else {
            proposedOrigin = CGPoint(
                x: anchor.mouseLocation.x - panelSize.width / 2,
                y: anchor.mouseLocation.y + spacing
            )
        }

        return CGRect(
            origin: clamp(origin: proposedOrigin, panelSize: panelSize, visibleFrame: anchor.visibleFrame),
            size: panelSize
        )
    }

    static func inferDockEdge(anchor: PreviewPanelAnchor) -> DockEdge {
        guard let frame = anchor.dockItemFrame else { return .bottom }
        let edgeBand: CGFloat = 80
        if frame.minX <= anchor.screenFrame.minX + edgeBand {
            return .left
        }
        if frame.maxX >= anchor.screenFrame.maxX - edgeBand {
            return .right
        }
        return .bottom
    }

    private static func clamp(origin: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        )
    }
}
```

- [ ] **Step 4: Run layout tests**

Run:

```bash
swift test --filter PreviewPanelLayoutEngineTests
```

Expected: all `PreviewPanelLayoutEngineTests` pass.

- [ ] **Step 5: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Review and commit**

Spec compliance review:

- Panel can be anchored to bottom, left, right, or mouse fallback.
- No private Dock orientation API is used.
- Task creates only anchor and geometry state.

Code quality review:

- Pure layout code is deterministic and unit tested.
- Geometry uses `visibleFrame` clamping.
- Models contain no AppKit panel ownership.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/PreviewPanelModels.swift Sources/DockHoverPreviewProbe/PreviewPanelLayoutEngine.swift Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift
git commit -m "feat: add preview panel layout models"
```

---

### Task 2: SwiftUI Preview Panel View

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Create: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Create: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`

- [ ] **Step 1: Write failing view model tests**

Create `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`:

```swift
import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelViewModelTests: XCTestCase {
    func testPanelViewModelCapsCardsAtEight() {
        let cards = (0..<10).map { index in
            makeCard(id: CGWindowID(index + 1), title: "Window \(index + 1)")
        }

        let model = PreviewPanelViewModel(appName: "Code", cards: cards)

        XCTAssertEqual(model.cards.count, 8)
        XCTAssertEqual(model.cards.last?.title, "Window 8")
    }

    func testUpdateThumbnailStopsLoadingForMatchingCardOnly() {
        var model = PreviewPanelViewModel(
            appName: "Code",
            cards: [
                makeCard(id: 1, title: "One"),
                makeCard(id: 2, title: "Two")
            ]
        )
        let image = makeImage()

        model.updateThumbnail(image, for: PreviewWindowID(pid: 100, windowID: 2))

        XCTAssertNil(model.cards[0].thumbnail)
        XCTAssertTrue(model.cards[0].isLoadingThumbnail)
        XCTAssertNotNil(model.cards[1].thumbnail)
        XCTAssertFalse(model.cards[1].isLoadingThumbnail)
    }

    func testCardAccessibilityLabelIncludesAppNameAndTitle() {
        let card = makeCard(id: 1, title: "Project")

        XCTAssertEqual(card.accessibilityLabel, "Code, Project")
    }

    private func makeCard(id: CGWindowID, title: String) -> PreviewCardViewModel {
        PreviewCardViewModel(
            id: PreviewWindowID(pid: 100, windowID: id),
            title: title,
            appName: "Code",
            appIcon: NSImage(size: NSSize(width: 32, height: 32)),
            thumbnail: nil,
            isLoadingThumbnail: true
        )
    }

    private func makeImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
swift test --filter PreviewPanelViewModelTests
```

Expected: fails because `PreviewCardViewModel` and `PreviewPanelViewModel` do not exist.

- [ ] **Step 3: Add card and panel view models**

Update the import block in `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`:

```swift
import AppKit
import CoreGraphics
```

Then append the view models:

```swift

struct PreviewCardViewModel: Identifiable {
    let id: PreviewWindowID
    let title: String
    let appName: String
    let appIcon: NSImage
    var thumbnail: CGImage?
    var isLoadingThumbnail: Bool

    var accessibilityLabel: String {
        "\(appName), \(title)"
    }
}

struct PreviewPanelViewModel {
    let appName: String
    private(set) var cards: [PreviewCardViewModel]

    init(appName: String, cards: [PreviewCardViewModel]) {
        self.appName = appName
        self.cards = Array(cards.prefix(8))
    }

    mutating func updateThumbnail(_ thumbnail: CGImage?, for id: PreviewWindowID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].thumbnail = thumbnail
        cards[index].isLoadingThumbnail = false
    }
}
```

- [ ] **Step 4: Add SwiftUI panel and card views**

Create `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`:

```swift
import AppKit
import SwiftUI

struct PreviewPanelView: View {
    let model: PreviewPanelViewModel
    let onSelect: (PreviewWindowID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: model.cards.count > 3) {
            HStack(spacing: 8) {
                ForEach(model.cards) { card in
                    PreviewCardView(card: card) {
                        onSelect(card.id)
                    }
                }
            }
            .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
        .fixedSize()
    }
}

struct PreviewCardView: View {
    let card: PreviewCardViewModel
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                thumbnail
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                HStack(spacing: 6) {
                    Image(nsImage: card.appIcon)
                        .resizable()
                        .frame(width: 18, height: 18)

                    Text(card.title)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
                .frame(width: 208, height: 28, alignment: .leading)
            }
            .padding(6)
            .frame(width: 232, height: 172)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHovered ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(card.accessibilityLabel)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnail = card.thumbnail {
            Image(decorative: thumbnail, scale: 1, orientation: .up)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                Image(nsImage: card.appIcon)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .opacity(card.isLoadingThumbnail ? 0.55 : 0.80)
                if card.isLoadingThumbnail {
                    ProgressView()
                        .controlSize(.small)
                        .offset(y: 38)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --filter PreviewPanelViewModelTests
```

Expected: all `PreviewPanelViewModelTests` pass.

- [ ] **Step 6: Run build and full tests**

Run:

```bash
swift test
swift build
```

Expected: tests pass and SwiftUI imports compile.

- [ ] **Step 7: Review and commit**

Spec compliance review:

- Panel visually matches the MVP contract: material strip, compact horizontal cards, static thumbnail area, app icon, title.
- No settings UI or polished extra controls were added.
- Card labels are accessible.
- View models cap cards at 8.

Code quality review:

- View has stable fixed dimensions to avoid layout shifts as thumbnails load.
- No visible instructional text is introduced.
- Button style does not activate the app panel itself.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/PreviewPanelModels.swift Sources/DockHoverPreviewProbe/PreviewPanelView.swift Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift
git commit -m "feat: add SwiftUI preview panel view"
```

---

### Task 3: AppKit Preview Panel Controller

**Files:**
- Create: `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`

- [ ] **Step 1: Add display protocol and controller**

Create `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
protocol PreviewPanelDisplaying: AnyObject {
    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void)
    func update(model: PreviewPanelViewModel)
    func hide(reason: String)
    func isMouseInsidePanel(_ point: CGPoint) -> Bool
}

@MainActor
final class PreviewPanelController: PreviewPanelDisplaying {
    private let logger: ProbeLogger
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PreviewPanelView>?
    private var currentOnSelect: ((PreviewWindowID) -> Void)?
    private var currentAnchor: PreviewPanelAnchor?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        currentOnSelect = onSelect
        currentAnchor = anchor
        let panel = ensurePanel()
        let view = PreviewPanelView(model: model) { [weak self] id in
            self?.currentOnSelect?(id)
        }
        if let hostingController {
            hostingController.rootView = view
        } else {
            let controller = NSHostingController(rootView: view)
            hostingController = controller
            panel.contentViewController = controller
        }
        panel.layoutSubtreeIfNeeded()
        let fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 256, height: 180)
        let frame = PreviewPanelLayoutEngine.frame(for: fittingSize, anchor: anchor)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        logger.info("preview.panel.show app=\(model.appName) count=\(model.cards.count) frame=\(frame)")
    }

    func update(model: PreviewPanelViewModel) {
        guard let currentAnchor else { return }
        let onSelect = currentOnSelect ?? { _ in }
        show(model: model, anchor: currentAnchor, onSelect: onSelect)
        logger.info("preview.panel.update app=\(model.appName) count=\(model.cards.count)")
    }

    func hide(reason: String) {
        guard let panel else { return }
        panel.orderOut(nil)
        currentAnchor = nil
        currentOnSelect = nil
        logger.info("preview.panel.hide reason=\(reason)")
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return GeometryHelpers.contains(point, in: panel.frame, tolerance: 2)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 256, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        self.panel = panel
        return panel
    }
}
```

- [ ] **Step 2: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 3: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 4: Review and commit**

Spec compliance review:

- Uses a single non-activating borderless `NSPanel`.
- Does not steal focus.
- Uses `PreviewPanelLayoutEngine` rather than private Dock APIs.

Code quality review:

- Panel lifetime is owned by one MainActor controller.
- `hide(reason:)` clears select handler and anchor state.
- Controller does not query windows or thumbnails.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/PreviewPanelController.swift
git commit -m "feat: add preview panel controller"
```

---

### Task 4: Preview Session Controller

**Files:**
- Create: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Create: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

- [ ] **Step 1: Write failing session tests**

Create `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift` with fakes for permissions, query, thumbnails, activation, and panel display:

```swift
import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class PreviewSessionControllerTests: XCTestCase {
    func testScreenRecordingMissingSuppressesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: false, windows: [makeWindow(id: 1)])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["screenRecording=false"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testNoWindowsHidesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["noWindows"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testShowsPlaceholderCardsThenUpdatesThumbnails() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.showCount, 1)
        XCTAssertEqual(harness.display.lastModel?.cards.count, 1)
        XCTAssertTrue(harness.display.lastModel?.cards.first?.isLoadingThumbnail == false)
        XCTAssertNotNil(harness.display.lastModel?.cards.first?.thumbnail)
    }

    func testHideInvalidatesStaleThumbnailUpdates() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()
        harness.thumbnailService.suspend = true

        let task = Task {
            await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        }
        await Task.yield()
        harness.controller.hide(reason: "test")
        harness.thumbnailService.resume()
        await task.value

        XCTAssertEqual(harness.display.hideReasons, ["test"])
    }

    func testSelectingCardActivatesWindowAndHidesPanel() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        await harness.controller.activate(windowID: window.id)

        XCTAssertEqual(harness.activationService.activatedIDs, [window.id])
        XCTAssertEqual(harness.display.hideReasons, ["activated"])
    }
}
```

The fakes in the same test file should implement the existing protocols directly. Keep each fake small:

```swift
private final class FakePermissionService: PermissionService {
    var currentState: PermissionState

    init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        currentState = PermissionState(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

private final class FakeWindowQueryService: WindowQueryService, @unchecked Sendable {
    let windows: [PreviewWindow]
    init(windows: [PreviewWindow]) { self.windows = windows }
    func windows(for app: NSRunningApplication) async -> [PreviewWindow] { windows }
}

private final class FakeThumbnailService: ThumbnailService, @unchecked Sendable {
    var images: [PreviewWindowID: CGImage] = [:]
    var suspend = false
    private var continuation: CheckedContinuation<Void, Never>?

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        if suspend {
            await withCheckedContinuation { continuation = $0 }
        }
        return images[window.id]
    }

    func resume() {
        suspend = false
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class FakeActivationService: ActivationService {
    var activatedIDs: [PreviewWindowID] = []

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        activatedIDs.append(window.id)
        return ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: window.axElement != nil,
            raiseSucceeded: window.axElement != nil,
            appActivateRequestSucceeded: true
        )
    }
}

@MainActor
private final class FakePreviewPanelDisplay: PreviewPanelDisplaying {
    var showCount = 0
    var lastModel: PreviewPanelViewModel?
    var hideReasons: [String] = []
    var selectHandler: ((PreviewWindowID) -> Void)?

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        showCount += 1
        lastModel = model
        selectHandler = onSelect
    }

    func update(model: PreviewPanelViewModel) {
        lastModel = model
    }

    func hide(reason: String) {
        hideReasons.append(reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        false
    }
}
```

Add helpers in the same file:

```swift
@MainActor
private final class PreviewSessionHarness {
    let app = NSRunningApplication.current
    let permissionService: FakePermissionService
    let queryService: FakeWindowQueryService
    let thumbnailService = FakeThumbnailService()
    let activationService = FakeActivationService()
    let display = FakePreviewPanelDisplay()
    let logger = ProbeLogger()
    let anchor = PreviewPanelAnchor(
        dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
        mouseLocation: CGPoint(x: 726, y: 24),
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
    )
    let controller: PreviewSessionController

    init(screenRecordingGranted: Bool, windows: [PreviewWindow]) {
        permissionService = FakePermissionService(accessibilityGranted: true, screenRecordingGranted: screenRecordingGranted)
        queryService = FakeWindowQueryService(windows: windows)
        controller = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: queryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            panelDisplay: display,
            logger: logger
        )
    }
}

private func makeWindow(id: CGWindowID) -> PreviewWindow {
    PreviewWindow(
        id: PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: id),
        cgWindowID: id,
        app: NSRunningApplication.current,
        title: "Window \(id)",
        frame: CGRect(x: 100, y: 100, width: 800, height: 600),
        scWindow: nil,
        axElement: nil,
        appIcon: NSImage(size: NSSize(width: 32, height: 32)),
        thumbnailSource: nil
    )
}

private func makeImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter PreviewSessionControllerTests
```

Expected: fails because `PreviewSessionController` does not exist.

- [ ] **Step 3: Add session controller**

Create `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`:

```swift
import AppKit
import CoreGraphics

@MainActor
final class PreviewSessionController {
    private let permissionService: PermissionService
    private let windowQueryService: WindowQueryService
    private let thumbnailService: ThumbnailService
    private let activationService: ActivationService
    private let panelDisplay: PreviewPanelDisplaying
    private let logger: ProbeLogger

    private var generation = 0
    private var currentModel: PreviewPanelViewModel?
    private var currentWindowsByID: [PreviewWindowID: PreviewWindow] = [:]

    init(
        permissionService: PermissionService,
        windowQueryService: WindowQueryService,
        thumbnailService: ThumbnailService,
        activationService: ActivationService,
        panelDisplay: PreviewPanelDisplaying,
        logger: ProbeLogger
    ) {
        self.permissionService = permissionService
        self.windowQueryService = windowQueryService
        self.thumbnailService = thumbnailService
        self.activationService = activationService
        self.panelDisplay = panelDisplay
        self.logger = logger
    }

    func showPreview(for app: NSRunningApplication, anchor: PreviewPanelAnchor) async {
        let state = permissionService.refresh()
        guard state.screenRecordingGranted else {
            hide(reason: "screenRecording=false")
            logger.warning("preview.session.skipped screenRecording=false")
            return
        }

        generation += 1
        let sessionGeneration = generation
        let windows = await windowQueryService.windows(for: app)
        guard isCurrent(sessionGeneration) else { return }
        guard !windows.isEmpty else {
            hide(reason: "noWindows")
            logger.info("preview.session.noWindows app=\(app.localizedName ?? "unknown")")
            return
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let cards = windows.map { window in
            PreviewCardViewModel(
                id: window.id,
                title: window.title,
                appName: appName,
                appIcon: window.appIcon,
                thumbnail: nil,
                isLoadingThumbnail: true
            )
        }
        currentWindowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        currentModel = PreviewPanelViewModel(appName: appName, cards: cards)
        if let currentModel {
            panelDisplay.show(model: currentModel, anchor: anchor) { [weak self] id in
                Task { @MainActor in
                    await self?.activate(windowID: id)
                }
            }
        }
        logger.info("preview.session.show app=\(appName) count=\(windows.count)")

        for window in windows {
            let image = await thumbnailService.thumbnail(for: window)
            guard isCurrent(sessionGeneration) else { return }
            currentModel?.updateThumbnail(image, for: window.id)
            if let currentModel {
                panelDisplay.update(model: currentModel)
            }
            logger.info("preview.session.thumbnail id=\(window.cgWindowID) success=\(image != nil)")
        }
    }

    func hide(reason: String) {
        generation += 1
        currentModel = nil
        currentWindowsByID = [:]
        panelDisplay.hide(reason: reason)
    }

    func activate(windowID: PreviewWindowID) async {
        guard let window = currentWindowsByID[windowID] else {
            logger.warning("preview.session.activateMissing id=\(windowID.windowID)")
            hide(reason: "activateMissing")
            return
        }
        _ = await activationService.activate(window: window)
        hide(reason: "activated")
    }

    private func isCurrent(_ expectedGeneration: Int) -> Bool {
        generation == expectedGeneration
    }
}
```

- [ ] **Step 4: Run session tests**

Run:

```bash
swift test --filter PreviewSessionControllerTests
```

Expected: all `PreviewSessionControllerTests` pass.

- [ ] **Step 5: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Review and commit**

Spec compliance review:

- Screen Recording missing suppresses UI.
- Apps with no eligible windows do not show a panel.
- Thumbnails load progressively.
- Stale async results are ignored after hide.
- Card click routes to activation and hides the panel.

Code quality review:

- MainActor owns mutable UI session state.
- Services remain injectable and testable.
- Stale generation logic is simple and covered by tests.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/PreviewSessionController.swift Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift
git commit -m "feat: add preview session controller"
```

---

### Task 5: Wire Hover And Debug Actions To MVP UI

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/MenuBarController.swift`

- [ ] **Step 1: Update orchestrator dependencies**

Modify `ProbeOrchestrator` to accept a prebuilt `PreviewSessionController`:

```swift
final class ProbeOrchestrator: DockHoverMonitorDelegate {
    private let permissionService: PermissionService
    private let logger: ProbeLogger
    private let previewSessionController: PreviewSessionController
    private lazy var dockHoverMonitor = DockHoverMonitor(logger: logger)
    private var pendingHoverWorkItem: DispatchWorkItem?

    init(permissionService: PermissionService, logger: ProbeLogger, previewSessionController: PreviewSessionController) {
        self.permissionService = permissionService
        self.logger = logger
        self.previewSessionController = previewSessionController
        self.dockHoverMonitor.delegate = self
    }
}
```

Remove `windowQueryService`, `thumbnailService`, and `activationService` from `ProbeOrchestrator` after the debug actions no longer use them directly.

- [ ] **Step 2: Add anchor construction helper**

Add to `ProbeOrchestrator`:

```swift
private func makeAnchor(dockItemFrame: CGRect?) -> PreviewPanelAnchor {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { GeometryHelpers.contains(mouse, in: $0.frame, tolerance: 0) }
        ?? NSScreen.main
    let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
    let visibleFrame = screen?.visibleFrame ?? screenFrame
    return PreviewPanelAnchor(
        dockItemFrame: dockItemFrame,
        mouseLocation: mouse,
        screenFrame: screenFrame,
        visibleFrame: visibleFrame
    )
}
```

- [ ] **Step 3: Show UI after delayed hover validation**

Replace the delayed hover closure body after logging validation with:

```swift
guard matches, mouseInside, let hoveredApp = stillHovered else {
    Task { @MainActor [weak self] in
        self?.previewSessionController.hide(reason: "hoverValidationFailed")
    }
    return
}
let anchor = self.makeAnchor(dockItemFrame: validationFrame)
Task { @MainActor [weak self] in
    await self?.previewSessionController.showPreview(for: hoveredApp.app, anchor: anchor)
}
```

Keep the existing log line:

```swift
self.logger.info("dock.hoverDelayed bundle=\(app.bundleIdentifier) matches=\(matches) mouseInside=\(mouseInside) frame=\(String(describing: validationFrame))")
```

- [ ] **Step 4: Hide UI on hover lost and stop**

Update `dockHoverMonitorDidLoseHover(_:)`:

```swift
func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
    pendingHoverWorkItem?.cancel()
    Task { @MainActor [previewSessionController] in
        previewSessionController.hide(reason: "hoverLost")
    }
    logger.info("dock.hoverLost.orchestrator")
}
```

Update `stop()`:

```swift
func stop() {
    pendingHoverWorkItem?.cancel()
    Task { @MainActor [previewSessionController] in
        previewSessionController.hide(reason: "orchestratorStop")
    }
    dockHoverMonitor.stop()
    logger.info("orchestrator.stop")
}
```

- [ ] **Step 5: Route frontmost debug action through the UI path**

Update `showFrontmostAppProbe()` to show the panel for the frontmost app while preserving permission gating:

```swift
func showFrontmostAppProbe() {
    guard permissionService.refresh().screenRecordingGranted else {
        Task { @MainActor [previewSessionController] in
            previewSessionController.hide(reason: "screenRecording=false")
        }
        logger.warning("debug.frontmost.skipped screenRecording=false")
        return
    }
    guard let app = NSWorkspace.shared.frontmostApplication else {
        logger.warning("debug.frontmost.noApp")
        return
    }
    let anchor = makeAnchor(dockItemFrame: nil)
    logger.info("debug.frontmost.start app=\(app.localizedName ?? "unknown") bundle=\(app.bundleIdentifier ?? "nil") pid=\(app.processIdentifier)")
    Task { @MainActor [weak self] in
        await self?.previewSessionController.showPreview(for: app, anchor: anchor)
    }
}
```

- [ ] **Step 6: Update AppDelegate construction**

Modify `AppDelegate` properties:

```swift
private var previewPanelController: PreviewPanelController!
private var previewSessionController: PreviewSessionController!
```

Modify `applicationDidFinishLaunching(_:)`:

```swift
logger = ProbeLogger()
permissionService = SystemPermissionService(logger: logger)
previewPanelController = PreviewPanelController(logger: logger)
let windowQueryService: WindowQueryService = ScreenCaptureWindowQueryService(logger: logger)
let thumbnailService: ThumbnailService = StaticThumbnailService(logger: logger)
let activationService: ActivationService = AXActivationService(logger: logger)
previewSessionController = PreviewSessionController(
    permissionService: permissionService,
    windowQueryService: windowQueryService,
    thumbnailService: thumbnailService,
    activationService: activationService,
    panelDisplay: previewPanelController,
    logger: logger
)
orchestrator = ProbeOrchestrator(
    permissionService: permissionService,
    logger: logger,
    previewSessionController: previewSessionController
)
menuBarController = MenuBarController(permissionService: permissionService, orchestrator: orchestrator, logger: logger)
menuBarController.install()
orchestrator.start()
logger.info("app.launched bundleIdentifier=com.zong.DockHoverPreviewProbe")
```

- [ ] **Step 7: Build and run tests**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and the executable builds.

- [ ] **Step 8: Build packaged app**

Run:

```bash
Scripts/build_probe_app.sh
```

Expected: prints:

```text
/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
```

- [ ] **Step 9: Review and commit**

Spec compliance review:

- Hover UI appears only after delayed validation confirms same item and mouse-inside.
- Hover loss hides the panel.
- Debug frontmost path uses the same preview session.
- Screen Recording missing still suppresses UI.

Code quality review:

- `ProbeOrchestrator` coordinates but does not own AppKit panel details.
- Async UI calls are MainActor-bound.
- Existing Probe logs remain useful.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/AppDelegate.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift Sources/DockHoverPreviewProbe/MenuBarController.swift
git commit -m "feat: wire dock hover preview UI"
```

---

### Task 6: Escape And Mouse Leave Behavior

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

- [ ] **Step 1: Add panel close callback**

Extend `PreviewPanelDisplaying`:

```swift
var onRequestHide: ((String) -> Void)? { get set }
```

Update `PreviewPanelController`:

```swift
var onRequestHide: ((String) -> Void)?
private var localMonitor: Any?
private var globalMonitor: Any?
```

Install local and global key monitors when creating the panel. The local monitor covers events delivered to the app; the global monitor covers Escape while another app remains active and the non-activating panel is visible:

```swift
localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
    guard event.keyCode == 53 else { return event }
    self?.onRequestHide?("escape")
    return nil
}
globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
    guard event.keyCode == 53 else { return }
    self?.onRequestHide?("escape")
}
```

Remove the monitors in `deinit`:

```swift
deinit {
    if let localMonitor {
        NSEvent.removeMonitor(localMonitor)
    }
    if let globalMonitor {
        NSEvent.removeMonitor(globalMonitor)
    }
}
```

Update `FakePreviewPanelDisplay` in `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`:

```swift
var onRequestHide: ((String) -> Void)?
```

- [ ] **Step 2: Preserve panel while mouse is inside panel**

Add to `PreviewSessionController`:

```swift
func isMouseInsidePanel(_ point: CGPoint) -> Bool {
    panelDisplay.isMouseInsidePanel(point)
}
```

Update `ProbeOrchestrator.dockHoverMonitorDidLoseHover(_:)` to avoid immediate hide when the mouse has entered the panel:

```swift
func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
    pendingHoverWorkItem?.cancel()
    let mouse = NSEvent.mouseLocation
    Task { @MainActor [weak self] in
        guard let self else { return }
        if self.previewSessionController.isMouseInsidePanel(mouse) {
            self.logger.info("dock.hoverLost.panelRetained")
            return
        }
        self.previewSessionController.hide(reason: "hoverLost")
        self.logger.info("dock.hoverLost.orchestrator")
    }
}
```

- [ ] **Step 3: Add periodic leave polling for panel**

Add a lightweight timer in `PreviewSessionController`:

```swift
private var leaveTimer: Timer?
private var currentDockItemFrame: CGRect?
```

Start it after showing a panel:

```swift
currentDockItemFrame = anchor.dockItemFrame
startLeavePolling()
```

Implement:

```swift
private func startLeavePolling() {
    leaveTimer?.invalidate()
    leaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.pollLeaveRegion()
        }
    }
}

private func pollLeaveRegion() {
    let mouse = NSEvent.mouseLocation
    let insideDock = currentDockItemFrame.map { GeometryHelpers.contains(mouse, in: $0, tolerance: 2) } ?? false
    let insidePanel = panelDisplay.isMouseInsidePanel(mouse)
    if !insideDock && !insidePanel {
        hide(reason: "mouseLeftPreviewRegion")
    }
}
```

Stop it in `hide(reason:)`:

```swift
leaveTimer?.invalidate()
leaveTimer = nil
currentDockItemFrame = nil
```

- [ ] **Step 4: Wire Escape callback**

In `AppDelegate.applicationDidFinishLaunching(_:)`, after `previewSessionController` is created:

```swift
previewPanelController.onRequestHide = { [weak previewSessionController] reason in
    Task { @MainActor in
        previewSessionController?.hide(reason: reason)
    }
}
```

- [ ] **Step 5: Build and test**

Run:

```bash
swift test
swift build
```

Expected: all tests pass.

- [ ] **Step 6: Review and commit**

Spec compliance review:

- Panel hides on Escape.
- Panel remains while pointer is over the panel.
- Panel hides when pointer leaves both Dock item and panel.

Code quality review:

- Event monitor is removed in `deinit`.
- Leave timer is invalidated on hide.
- Timer work is MainActor-confined.
- Test fake remains conformant to the display protocol.

Commit:

```bash
git add Sources/DockHoverPreviewProbe/PreviewPanelController.swift Sources/DockHoverPreviewProbe/PreviewSessionController.swift Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift Sources/DockHoverPreviewProbe/AppDelegate.swift Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift
git commit -m "feat: add preview panel dismissal behavior"
```

---

### Task 7: Manual UI Checklist And Probe Result Update

**Files:**
- Create: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
- Modify: `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`

- [ ] **Step 1: Create manual checklist**

Create `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`:

```markdown
# Dock Hover Preview MVP UI Manual Checklist

Date: 2026-06-26

## Build

- [ ] `swift test` passes.
- [ ] `swift build` passes.
- [ ] `Scripts/build_probe_app.sh` produces `build/DockHoverPreviewProbe.app`.

## Permissions

- [ ] Accessibility granted for `DockHoverPreviewProbe.app`.
- [ ] Screen Recording granted for `DockHoverPreviewProbe.app`.
- [ ] With Screen Recording disabled, Dock hover does not show a panel and logs `screenRecording=false`.

## Hover UI

| App | Expected | Result | Notes |
| --- | --- | --- | --- |
| VS Code | Shows 3 cards for 3 windows | not run | |
| Chrome | Shows separate browser windows, not tabs | not run | |
| Typora | Shows 1 card | not run | |
| IINA | Shows static thumbnail or icon placeholder | not run | |
| WPS | Shows 1 card for `首页` | not run | |

## Interaction

- [ ] Card click activates the selected window and hides the panel.
- [ ] Quick leave before 250 ms does not show a stale panel.
- [ ] Moving from Dock icon into panel keeps the panel visible.
- [ ] Moving outside Dock icon and panel hides the panel.
- [ ] Escape hides the panel.
- [ ] `killall Dock` recovers without leaving a stuck panel.

## Visual Acceptance

- [ ] Panel is anchored near the hovered Dock icon.
- [ ] Panel is clamped inside the visible screen frame.
- [ ] Card titles fit without overlapping thumbnails.
- [ ] Missing thumbnail fallback is quiet and usable.
- [ ] Panel works in light and dark appearance.

## Environment Variants

- [ ] Other normal Space.
- [ ] Full-screen Space.
- [ ] Stage Manager enabled.
- [ ] Dock auto-hide enabled.
- [ ] Dock on left.
- [ ] Dock on right.
- [ ] Multiple displays.
```

- [ ] **Step 2: Update probe summary with MVP UI plan link**

Append to `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`:

```markdown
## MVP UI Plan

- Plan: `docs/superpowers/plans/2026-06-26-dock-hover-preview-mvp-ui-implementation-plan.md`
- Manual UI checklist: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
- DockDoor is a visual and interaction reference only. The MVP UI implementation must not copy DockDoor GPLv3 source, file structure, helper code, comments, or private API wrappers.
```

- [ ] **Step 3: Run documentation checks**

Run:

```bash
git diff --check
rg -n "T[B]D|TO[D]O|fill[[:space:]]+in|implement[[:space:]]+later|copy[[:space:]]+DockDoor[[:space:]]+source" docs/superpowers/plans/2026-06-26-dock-hover-preview-mvp-ui-implementation-plan.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md
```

Expected:

- `git diff --check` prints no errors.
- `rg` exits with no matches.

- [ ] **Step 4: Review and commit**

Spec compliance review:

- Checklist covers permissions, hover, stale behavior, activation, visual acceptance, and environment variants.
- Summary links to the UI plan and repeats DockDoor GPL boundary.

Code quality review:

- Documentation uses concrete checklist items.
- No ambiguous placeholders are present.

Commit:

```bash
git add docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md
git commit -m "docs: add MVP UI manual checklist"
```

---

### Task 8: Packaged App Manual Verification

**Files:**
- Modify after manual run: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Build packaged app**

Run:

```bash
Scripts/build_probe_app.sh
```

Expected:

```text
/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
```

- [ ] **Step 2: Launch app**

Run:

```bash
open /Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
```

Expected:

- Menu bar shows `DHP`.
- If TCC permissions reset, pause and ask the user to re-add `DockHoverPreviewProbe.app` under Accessibility and Screen Recording.

- [ ] **Step 3: Verify Screen Recording denied path**

Manual user action:

1. Open System Settings > Privacy & Security > Screen Recording.
2. Disable `DockHoverPreviewProbe.app`.
3. Relaunch `DockHoverPreviewProbe.app`.
4. Hover a Dock app or use `DHP > Debug: Show Preview For Frontmost App`.

Expected:

- No preview panel appears.
- Logs contain `screenRecording=false`.

Manual user action:

1. Re-enable Screen Recording for `DockHoverPreviewProbe.app`.
2. Relaunch the app.

- [ ] **Step 4: Verify app samples**

Manual runs:

- VS Code: open three windows, hover Dock icon, verify three cards, click each card.
- Chrome: open two windows, hover Dock icon, verify two cards, click each card.
- Typora: verify one card and click activation.
- IINA: verify static thumbnail or placeholder and click activation.
- WPS: verify one card for `首页` and click activation.

Expected:

- Panel appears after hover delay.
- Cards update thumbnails without resizing.
- Click activates the selected window and hides panel.
- Quick leave before delay does not show a stale panel.

- [ ] **Step 5: Verify dismissal**

Manual runs:

- Hover app icon, move into panel, confirm panel remains visible.
- Move out of Dock item and panel, confirm panel hides.
- Hover app icon, press Escape, confirm panel hides.
- Run `killall Dock`, confirm no stuck panel remains and later hover still works.

- [ ] **Step 6: Update checklist results**

Edit `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`:

- Change each completed item from `[ ]` to `[x]`.
- Replace `not run` table cells with `pass`, `fail`, or `blocked`.
- Add concise notes with app name, window count, and observed behavior.

- [ ] **Step 7: Run final verification**

Run:

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected: all pass.

- [ ] **Step 8: Review and commit**

Spec compliance review:

- Manual evidence confirms the MVP UI works for the sampled apps or records concrete blockers.
- Environment variants remain marked until actually run.

Code quality review:

- Manual results are factual and do not overstate untested environments.

Commit:

```bash
git add docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: record MVP UI manual verification"
```

---

## Final Completion Criteria

The MVP UI plan is complete when:

- `swift test` passes.
- `swift build` passes.
- `Scripts/build_probe_app.sh` produces `build/DockHoverPreviewProbe.app`.
- Accessibility and Screen Recording granted path shows preview UI for sampled apps.
- Screen Recording denied path suppresses UI and logs the reason.
- Hover stale suppression prevents panels after quick leave.
- Card click activates the selected window and hides panel.
- Escape and mouse-leave dismissal work.
- Manual checklist is updated with pass/fail/blocked evidence.
- Probe summary links to this MVP UI plan and checklist.

## Suggested Final Verdict Template

Use this shape after Task 8:

```markdown
## MVP UI Result

- MVP UI status: pass / pass with concerns / blocked
- Recommended next step: polish UI / run environment variants / revisit architecture
- Main evidence:
  - `swift test`: pass/fail
  - `swift build`: pass/fail
  - `Scripts/build_probe_app.sh`: pass/fail
  - Sample apps: pass/fail/blocked summary
- Remaining risks:
  - Other Spaces:
  - Full-screen Spaces:
  - Stage Manager:
  - Dock auto-hide:
  - Left/right Dock:
  - Multiple displays:
```

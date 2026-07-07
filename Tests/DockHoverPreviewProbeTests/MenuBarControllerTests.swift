import AppKit
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testInstallUsesTemplateLogoInsteadOfTextTitle() {
        let harness = MenuHarness()

        harness.controller.install()

        XCTAssertEqual(harness.statusButton.title, "")
        XCTAssertNotNil(harness.statusButton.image)
        XCTAssertEqual(harness.statusButton.image?.size, NSSize(width: 18, height: 18))
        XCTAssertEqual(harness.statusButton.image?.isTemplate, true)
        XCTAssertEqual(harness.statusButton.imagePosition, .imageOnly)
        XCTAssertEqual(harness.statusButton.toolTip, "zongMacTools")
    }

    func testMenuBarIconIsTemplateSizedForStatusBar() {
        let image = MenuBarIcon.makeImage()

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
    }

    func testMenuBarIconProvidesRetinaBackingPixels() {
        let image = MenuBarIcon.makeImage()

        XCTAssertTrue(
            image.representations.contains { representation in
                representation.pixelsWide >= 36
                    && representation.pixelsHigh >= 36
                    && representation.size == NSSize(width: 18, height: 18)
            }
        )
    }

    func testMenuBarIconConversionUsesBrightPixelsAsTemplateAlpha() throws {
        let source = makeHalfWhiteHalfBlackImage()
        let image = MenuBarIcon.makeImage(sourceImage: source)
        let alphaRows = try rasterizedAlphaRows(for: image)

        for row in alphaRows {
            XCTAssertGreaterThan(row[4], 220)
            XCTAssertLessThan(row[14], 10)
        }
    }

    func testMenuBarIconCanBeDerivedFromAppLogoSource() throws {
        let source = try XCTUnwrap(NSImage(contentsOf: appLogoURL()))
        let image = MenuBarIcon.makeImage(sourceImage: source)
        let alphaRows = try rasterizedAlphaRows(for: image)
        let prominentPixels = alphaRows.flatMap { $0 }.filter { $0 > 100 }.count
        let solidPixels = alphaRows.flatMap { $0 }.filter { $0 > 180 }.count
        let transparentPixels = alphaRows.flatMap { $0 }.filter { $0 < 10 }.count
        let bounds = try XCTUnwrap(alphaRows.alphaBounds(threshold: 30))

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(prominentPixels, 40)
        XCTAssertGreaterThan(solidPixels, 10)
        XCTAssertGreaterThan(transparentPixels, 100)
        XCTAssertLessThan(alphaRows[0][0], 10)
        XCTAssertGreaterThan(bounds.width, 10)
        XCTAssertGreaterThan(bounds.height, 10)
    }

    func testMenuBarIconCropsSourceLogoMarginsToFillStatusBar() throws {
        let source = try XCTUnwrap(NSImage(contentsOf: appLogoURL()))
        let image = MenuBarIcon.makeImage(sourceImage: source)
        let alphaRows = try rasterizedAlphaRows(for: image)
        let bounds = try XCTUnwrap(alphaRows.alphaBounds(threshold: 30))

        XCTAssertGreaterThanOrEqual(bounds.minX, 2)
        XCTAssertGreaterThanOrEqual(bounds.maxX, 15)
        XCTAssertLessThanOrEqual(bounds.maxX, 15)
        XCTAssertGreaterThanOrEqual(bounds.minY, 1)
        XCTAssertGreaterThanOrEqual(bounds.maxY, 15)
        XCTAssertLessThanOrEqual(bounds.maxY, 16)
        XCTAssertGreaterThanOrEqual(bounds.width, 14)
        XCTAssertGreaterThanOrEqual(bounds.height, 14)
    }

    func testMenuBarIconBoostsLogoStrokeAlphaForReadability() throws {
        let source = try XCTUnwrap(NSImage(contentsOf: appLogoURL()))
        let image = MenuBarIcon.makeImage(sourceImage: source)
        let alphaRows = try rasterizedAlphaRows(for: image, pixelDimension: 36)
        let visibleAlphas = alphaRows.flatMap { $0 }.filter { $0 > 30 }
        let averageVisibleAlpha = visibleAlphas.reduce(0) { $0 + Int($1) } / visibleAlphas.count

        XCTAssertGreaterThan(averageVisibleAlpha, 220)
        XCTAssertGreaterThan(visibleAlphas.filter { $0 > 245 }.count, 220)
    }

    func testMinimalMenuContainsOnlyPrimaryActionsWhenEnabled() {
        let harness = MenuHarness()

        let menu = harness.makeMenu()

        XCTAssertEqual(
            menu.visibleTitles(),
            [
                "zongMacTools",
                "Dock Window Quick Look: Enabled",
                "Open Settings...",
                "Disable Dock Window Quick Look",
                "About & Status",
                "Export Diagnostics...",
                "Quit"
            ]
        )
    }

    func testMinimalMenuShowsEnableActionWhenDockWindowQuickLookIsDisabled() {
        let harness = MenuHarness(settings: .defaultsWith(enabled: false))

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "Dock Window Quick Look: Disabled"))
        XCTAssertNotNil(menu.findItem(title: "Enable Dock Window Quick Look"))
        XCTAssertNil(menu.findItem(title: "Disable Dock Window Quick Look"))
    }

    func testMinimalMenuDoesNotContainLegacySettingsOrDebugEntries() {
        let harness = MenuHarness()

        let menu = harness.makeMenu()

        XCTAssertTrue(menu.items.allSatisfy { $0.submenu == nil })
        XCTAssertNil(menu.findItem(title: "Hover Delay"))
        XCTAssertNil(menu.findItem(title: "Panel Retention"))
        XCTAssertNil(menu.findItem(title: "Max Cards"))
        XCTAssertNil(menu.findItem(title: "Language"))
        XCTAssertNil(menu.findItem(title: "Excluded Apps"))
        XCTAssertNil(menu.findItem(title: "Launch at Login: Not Registered"))
        XCTAssertNil(menu.findItem(title: "Request Accessibility Prompt"))
        XCTAssertNil(menu.findItem(title: "Open Accessibility Settings"))
        XCTAssertNil(menu.findItem(title: "Open Screen Recording Settings"))
        XCTAssertNil(menu.findItem(title: "Debug: Show Preview For Frontmost App"))
    }

    func testControllerDoesNotExposeLegacySettingsSelectors() {
        let harness = MenuHarness()

        [
            "setHoverDelay:",
            "setPanelRetention:",
            "setMaxCards:",
            "setLanguage:",
            "excludeTargetApp:",
            "includeTargetApp:",
            "removeExcludedApp:",
            "clearExcludedApps",
            "enableLaunchAtLogin",
            "disableLaunchAtLogin",
            "openLoginItemsSettings",
            "requestAccessibilityPrompt",
            "openAccessibilitySettings",
            "openScreenRecordingSettings",
            "refreshPermissions",
            "showFrontmostAppProbe"
        ].forEach { selectorName in
            XCTAssertFalse(
                harness.controller.responds(to: NSSelectorFromString(selectorName)),
                "\(selectorName) should not remain reachable from the minimal menu controller"
            )
        }
    }

    func testOpenSettingsActionShowsDockWindowQuickLookSettingsPage() {
        let settingsWindowPresenter = FakeSettingsWindowPresenter()
        let harness = MenuHarness(settingsWindowPresenter: settingsWindowPresenter)
        let menu = harness.makeMenu()

        menu.performItem(title: "Open Settings...")

        XCTAssertEqual(settingsWindowPresenter.selectedPages, [.dockWindowQuickLook])
    }

    func testToggleDockWindowQuickLookOnlyWritesSettingsAndRebuildsMenu() {
        let harness = MenuHarness()
        harness.controller.install()

        harness.installedMenu.performItem(title: "Disable Dock Window Quick Look")
        XCTAssertFalse(harness.settingsStore.snapshot.isDockHoverPreviewEnabled)
        XCTAssertNotNil(harness.installedMenu.findItem(title: "Enable Dock Window Quick Look"))

        harness.installedMenu.performItem(title: "Enable Dock Window Quick Look")
        XCTAssertTrue(harness.settingsStore.snapshot.isDockHoverPreviewEnabled)
        XCTAssertNotNil(harness.installedMenu.findItem(title: "Disable Dock Window Quick Look"))
    }

    func testAboutStatusOpensEmbeddedSettingsPageAndExportDiagnosticsCallsInjectedService() {
        let diagnosticPresenter = FakeDiagnosticExportPresenter()
        let settingsWindowPresenter = FakeSettingsWindowPresenter()
        let harness = MenuHarness(
            diagnosticExportPresenter: diagnosticPresenter,
            settingsWindowPresenter: settingsWindowPresenter
        )
        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "About & Status"))
        XCTAssertNotNil(menu.findItem(title: "Export Diagnostics..."))

        menu.performItem(title: "About & Status")
        menu.performItem(title: "Export Diagnostics...")

        XCTAssertEqual(settingsWindowPresenter.selectedPages, [.aboutStatus])
        XCTAssertEqual(diagnosticPresenter.exportCount, 1)
    }

    func testSimplifiedChineseMinimalMenuLocalizesPrimaryActions() {
        let harness = MenuHarness(settings: .defaultsWith(language: .simplifiedChinese))

        let menu = harness.makeMenu()

        XCTAssertEqual(
            menu.visibleTitles(),
            [
                "zongMacTools",
                "\u{0044}\u{006f}\u{0063}\u{006b} \u{7A97}\u{53E3}\u{901F}\u{89C8}\u{FF1A}\u{5DF2}\u{542F}\u{7528}",
                "\u{6253}\u{5F00}\u{8BBE}\u{7F6E}...",
                "\u{505C}\u{7528} \u{0044}\u{006f}\u{0063}\u{006b} \u{7A97}\u{53E3}\u{901F}\u{89C8}",
                "\u{5173}\u{4E8E}\u{4E0E}\u{72B6}\u{6001}",
                "\u{5BFC}\u{51FA}\u{8BCA}\u{65AD}...",
                "\u{9000}\u{51FA}"
            ]
        )
    }
}

@MainActor
private final class MenuHarness {
    let permissionService = FakePermissionService()
    let settingsStore: FakeSettingsStore
    let controller: MenuBarController

    init(
        settings: DockHoverPreviewSettings = .defaults,
        diagnosticExportPresenter: FakeDiagnosticExportPresenter = FakeDiagnosticExportPresenter(),
        settingsWindowPresenter: FakeSettingsWindowPresenter = FakeSettingsWindowPresenter()
    ) {
        _ = NSApplication.shared
        self.settingsStore = FakeSettingsStore(snapshot: settings)
        controller = MenuBarController(
            permissionService: permissionService,
            settingsStore: settingsStore,
            diagnosticExportPresenter: diagnosticExportPresenter,
            settingsWindowPresenter: settingsWindowPresenter,
            logger: ProbeLogger()
        )
    }

    func makeMenu(
        permissionState: PermissionState = PermissionState(accessibilityGranted: true, screenRecordingGranted: true)
    ) -> NSMenu {
        controller.makeMenu(permissionState: permissionState)
    }

    var installedMenu: NSMenu {
        return controller.installedMenuForTesting!
    }

    var statusButton: NSStatusBarButton {
        return controller.statusButtonForTesting!
    }
}

private final class FakePermissionService: PermissionService {
    var currentState = PermissionState(accessibilityGranted: true, screenRecordingGranted: true)

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class FakeSettingsStore: DockHoverPreviewSettingsStore {
    private(set) var observers: [UUID: @MainActor (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var snapshot: DockHoverPreviewSettings

    init(snapshot: DockHoverPreviewSettings) {
        self.snapshot = snapshot
    }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(transform: (inout DockHoverPreviewSettings) -> Void) {
        transform(&snapshot)
        observers.values.forEach { $0(snapshot) }
    }
}

@MainActor
private final class FakeDiagnosticExportPresenter: DiagnosticExportPresenting {
    private(set) var exportCount = 0

    func exportDiagnostics() {
        exportCount += 1
    }
}

@MainActor
private final class FakeSettingsWindowPresenter: SettingsWindowPresenting {
    private(set) var selectedPages: [SettingsPage] = []

    func showSettings(selectedPage: SettingsPage) {
        selectedPages.append(selectedPage)
    }
}

@MainActor
private extension NSMenu {
    func findItem(title: String, state: NSControl.StateValue? = nil) -> NSMenuItem? {
        flattenedItems().first { item in
            item.title == title && (state.map { item.state == $0 } ?? true)
        }
    }

    func performItem(title: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let item = findItem(title: title) else {
            XCTFail("Missing menu item titled \(title)", file: file, line: line)
            return
        }
        guard item.isEnabled else {
            XCTFail("Menu item titled \(title) is disabled", file: file, line: line)
            return
        }
        guard let action = item.action else {
            XCTFail("Menu item titled \(title) has no action", file: file, line: line)
            return
        }
        XCTAssertTrue(NSApplication.shared.sendAction(action, to: item.target, from: item), file: file, line: line)
    }

    func visibleTitles() -> [String] {
        items.compactMap { item in
            item.isSeparatorItem ? nil : item.title
        }
    }

    private func flattenedItems() -> [NSMenuItem] {
        items.flatMap { item in
            [item] + (item.submenu?.flattenedItems() ?? [])
        }
    }
}

private func makeHalfWhiteHalfBlackImage() -> NSImage {
    let width = 4
    let height = 4
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * 4
            let value: UInt8 = x < 2 ? 255 : 0
            bytes[offset] = value
            bytes[offset + 1] = value
            bytes[offset + 2] = value
            bytes[offset + 3] = 255
        }
    }
    let data = Data(bytes)
    let provider = CGDataProvider(data: data as CFData)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
    return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
}

private func rasterizedAlphaRows(for image: NSImage, pixelDimension: Int? = nil) throws -> [[UInt8]] {
    let width = pixelDimension ?? Int(image.size.width)
    let height = pixelDimension ?? Int(image.size.height)
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let didDraw = bytes.withUnsafeMutableBytes { pointer -> Bool in
        guard
            let baseAddress = pointer.baseAddress,
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    XCTAssertTrue(didDraw)

    return (0..<height).map { y in
        (0..<width).map { x in
            bytes[y * bytesPerRow + x * 4 + 3]
        }
    }
}

private func appLogoURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Assets/AppIcon/zong-mac-tools-logo.png")
}

private struct AlphaBounds {
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

private extension Array where Element == [UInt8] {
    func alphaBounds(threshold: UInt8) -> AlphaBounds? {
        var minX = Int.max
        var maxX = Int.min
        var minY = Int.max
        var maxY = Int.min

        for (y, row) in enumerated() {
            for (x, alpha) in row.enumerated() where alpha > threshold {
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minY = Swift.min(minY, y)
                maxY = Swift.max(maxY, y)
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return nil
        }
        return AlphaBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
}

private extension DockHoverPreviewSettings {
    static func defaultsWith(
        enabled: Bool = true,
        hoverDelayMilliseconds: Int = 250,
        maxCardCount: Int = 8,
        retention: PanelRetentionMode = .standard,
        excludedApps: Set<String> = [],
        language: DisplayLanguage = .english
    ) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults
        settings.isDockHoverPreviewEnabled = enabled
        settings.hoverDelayMilliseconds = hoverDelayMilliseconds
        settings.maxCardCount = maxCardCount
        settings.panelRetentionMode = retention
        settings.excludedAppBundleIdentifiers = excludedApps
        settings.displayLanguage = language
        return settings
    }
}

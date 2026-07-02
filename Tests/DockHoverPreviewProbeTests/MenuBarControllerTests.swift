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

    func testMenuChecksCurrentSettingsChoices() {
        let harness = MenuHarness(
            settings: .defaultsWith(
                hoverDelayMilliseconds: 400,
                maxCardCount: 12,
                retention: .forgiving,
                language: .simplifiedChinese
            )
        )

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "400 ms", state: .on))
        XCTAssertNotNil(menu.findItem(title: "\u{5BBD}\u{677E}", state: .on))
        XCTAssertNotNil(menu.findItem(title: "12", state: .on))
        XCTAssertNotNil(menu.findItem(title: "\u{7B80}\u{4F53}\u{4E2D}\u{6587}", state: .on))
    }

    func testSimplifiedChineseMenuLocalizesStaticPermissionAndRetentionLabels() {
        let harness = MenuHarness(settings: .defaultsWith(language: .simplifiedChinese))

        let menu = harness.makeMenu(
            permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: false)
        )

        XCTAssertNotNil(menu.findItem(title: "\u{8F85}\u{52A9}\u{529F}\u{80FD}\u{FF1A}\u{5DF2}\u{6388}\u{6743}"))
        XCTAssertNotNil(menu.findItem(title: "\u{5C4F}\u{5E55}\u{5F55}\u{5236}\u{FF1A}\u{7F3A}\u{5931}"))
        XCTAssertNotNil(menu.findItem(title: "\u{7D27}\u{51D1}"))
        XCTAssertNotNil(menu.findItem(title: "\u{6807}\u{51C6}", state: .on))
        XCTAssertNotNil(menu.findItem(title: "\u{5BBD}\u{677E}"))
    }

    func testExcludedAppListDisplaysResolvedAppNameWithBundleIdentifier() {
        let appNameResolver = FakeAppNameResolver(displayNames: ["com.example.Editor": "Example Editor"])
        let harness = MenuHarness(
            settings: .defaultsWith(excludedApps: ["com.example.Editor"]),
            appNameResolver: appNameResolver
        )

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "Example Editor (com.example.Editor)"))
    }

    func testExcludedAppTargetTitleIsExplicit() {
        let harness = MenuHarness()
        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "Exclude Google Chrome"))
    }

    func testLongExcludedListIsSummarized() {
        let excludedApps = Set((0..<30).map { String(format: "com.example.App%02d", $0) })
        let harness = MenuHarness(settings: .defaultsWith(excludedApps: excludedApps))

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(containing: "more excluded apps"))
    }

    func testDisableActionWritesSettingCancelsPendingAndHidesPreview() {
        let harness = MenuHarness()
        let menu = harness.makeMenu()

        menu.performItem(title: "Disable Dock Hover Preview")

        XCTAssertFalse(harness.settingsStore.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(harness.orchestrator.cancelReasons, ["settingsDisabled"])
        XCTAssertEqual(harness.orchestrator.hideReasons, ["settingsDisabled"])
    }

    func testExcludeTargetActionWritesSettingCancelsPendingAndHidesPreview() {
        let harness = MenuHarness()
        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )
        let menu = harness.makeMenu()

        menu.performItem(title: "Exclude Google Chrome")

        XCTAssertTrue(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.google.Chrome"))
        XCTAssertEqual(harness.orchestrator.cancelReasons, ["appExcluded"])
        XCTAssertEqual(harness.orchestrator.hideReasons, ["appExcluded"])
    }

    func testExcludeActionUsesTargetRepresentedByMenuItem() {
        let harness = MenuHarness()
        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )
        let menu = harness.makeMenu()
        harness.targetTracker.updateCurrentPreviewApp(
            AppTarget(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit")
        )

        menu.performItem(title: "Exclude Google Chrome")

        XCTAssertTrue(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.google.Chrome"))
        XCTAssertFalse(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.apple.TextEdit"))
    }

    func testIncludeActionUsesTargetRepresentedByMenuItem() {
        let harness = MenuHarness(settings: .defaultsWith(excludedApps: ["com.google.Chrome", "com.apple.TextEdit"]))
        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )
        let menu = harness.makeMenu()
        harness.targetTracker.updateCurrentPreviewApp(
            AppTarget(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit")
        )

        menu.performItem(title: "Include Google Chrome")

        XCTAssertFalse(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.google.Chrome"))
        XCTAssertTrue(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.apple.TextEdit"))
    }

    func testExcludeTargetIsDisabledForSelfApp() {
        let harness = MenuHarness()
        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.zong.DockHoverPreviewProbe", displayName: "DockHoverPreviewProbe")
        )

        let menu = harness.makeMenu()

        let item = menu.findItem(title: "Exclude App")
        XCTAssertNotNil(item)
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testMenuOpeningRebuildsWithLatestExcludedTarget() {
        let harness = MenuHarness()
        harness.controller.install()

        harness.targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )
        harness.controller.menuWillOpen(harness.installedMenu)

        XCTAssertNotNil(harness.installedMenu.findItem(title: "Exclude Google Chrome"))
    }

    func testSettingsActionsWriteValuesAndCancelDelayChanges() {
        let harness = MenuHarness()
        var menu = harness.makeMenu()

        menu.performItem(title: "400 ms")
        XCTAssertEqual(harness.settingsStore.snapshot.hoverDelayMilliseconds, 400)
        XCTAssertEqual(harness.orchestrator.cancelReasons, ["settingsChanged"])

        menu = harness.makeMenu()
        menu.performItem(title: "Forgiving")
        XCTAssertEqual(harness.settingsStore.snapshot.panelRetentionMode, .forgiving)

        menu = harness.makeMenu()
        menu.performItem(title: "12")
        XCTAssertEqual(harness.settingsStore.snapshot.maxCardCount, 12)

        menu = harness.makeMenu()
        menu.performItem(title: "\u{7B80}\u{4F53}\u{4E2D}\u{6587}")
        XCTAssertEqual(harness.settingsStore.snapshot.displayLanguage, .simplifiedChinese)
    }

    func testExcludedAppListActionsRemoveAndClearEntries() {
        let harness = MenuHarness(settings: .defaultsWith(excludedApps: ["com.example.One", "com.example.Two"]))
        var menu = harness.makeMenu()

        menu.performItem(title: "com.example.One")
        XCTAssertFalse(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.example.One"))
        XCTAssertTrue(harness.settingsStore.snapshot.excludedAppBundleIdentifiers.contains("com.example.Two"))

        menu = harness.makeMenu()
        menu.performItem(title: "Clear Excluded Apps")
        XCTAssertEqual(harness.settingsStore.snapshot.excludedAppBundleIdentifiers, [])
    }

    func testLaunchAndDebugActionsCallServices() {
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notRegistered)
        let harness = MenuHarness(launchAtLoginService: launchAtLoginService)
        var menu = harness.makeMenu()

        menu.performItem(title: "Enable Launch at Login")
        XCTAssertEqual(launchAtLoginService.enableCount, 1)

        launchAtLoginService.status = .enabled
        menu = harness.makeMenu()
        menu.performItem(title: "Disable Launch at Login")
        XCTAssertEqual(launchAtLoginService.disableCount, 1)

        launchAtLoginService.status = .requiresApproval
        menu = harness.makeMenu()
        menu.performItem(title: "Open Login Items Settings")
        XCTAssertEqual(launchAtLoginService.openSettingsCount, 1)

        menu.performItem(title: "Debug: Show Preview For Frontmost App")
        XCTAssertEqual(harness.orchestrator.debugPreviewCount, 1)
    }

    func testLaunchAtLoginNotFoundDisablesToggleAndKeepsOpenSettingsEnabled() {
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notFound)
        let harness = MenuHarness(launchAtLoginService: launchAtLoginService)

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "Launch at Login: Not Found"))
        XCTAssertFalse(menu.findItem(title: "Enable Launch at Login")?.isEnabled ?? true)
        XCTAssertFalse(menu.findItem(title: "Disable Launch at Login")?.isEnabled ?? true)
        XCTAssertTrue(menu.findItem(title: "Open Login Items Settings")?.isEnabled ?? false)
    }

    func testEnableLaunchAtLoginActionCallsService() {
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notRegistered)
        let harness = MenuHarness(launchAtLoginService: launchAtLoginService)
        let menu = harness.makeMenu()

        menu.performItem(title: "Enable Launch at Login")

        XCTAssertEqual(launchAtLoginService.enableCount, 1)
    }

    func testLaunchAtLoginEnableFailureDoesNotCrash() {
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notRegistered)
        launchAtLoginService.enableError = LaunchAtLoginTestError.failed
        let harness = MenuHarness(launchAtLoginService: launchAtLoginService)
        let menu = harness.makeMenu()

        menu.performItem(title: "Enable Launch at Login")

        XCTAssertEqual(launchAtLoginService.enableCount, 1)
    }

    func testRequiresApprovalOnlyOffersOpenSettings() {
        let launchAtLoginService = FakeLaunchAtLoginService(status: .requiresApproval)
        let harness = MenuHarness(launchAtLoginService: launchAtLoginService)

        let menu = harness.makeMenu()

        XCTAssertNotNil(menu.findItem(title: "Launch at Login: Requires Approval"))
        XCTAssertNil(menu.findItem(title: "Enable Launch at Login"))
        XCTAssertNil(menu.findItem(title: "Disable Launch at Login"))
        XCTAssertTrue(menu.findItem(title: "Open Login Items Settings")?.isEnabled ?? false)
    }
}

private enum LaunchAtLoginTestError: Error {
    case failed
}

@MainActor
private final class MenuHarness {
    let permissionService = FakePermissionService()
    let settingsStore: FakeSettingsStore
    let orchestrator = FakeMenuOrchestrator()
    let launchAtLoginService: FakeLaunchAtLoginService
    let appNameResolver: FakeAppNameResolver
    let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.DockHoverPreviewProbe")
    let controller: MenuBarController

    init(
        settings: DockHoverPreviewSettings = .defaults,
        launchAtLoginService: FakeLaunchAtLoginService = FakeLaunchAtLoginService(),
        appNameResolver: FakeAppNameResolver = FakeAppNameResolver()
    ) {
        _ = NSApplication.shared
        self.settingsStore = FakeSettingsStore(snapshot: settings)
        self.launchAtLoginService = launchAtLoginService
        self.appNameResolver = appNameResolver
        controller = MenuBarController(
            permissionService: permissionService,
            orchestrator: orchestrator,
            settingsStore: settingsStore,
            launchAtLoginService: launchAtLoginService,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver,
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
private final class FakeMenuOrchestrator: MenuOrchestrating {
    private(set) var hideReasons: [String] = []
    private(set) var cancelReasons: [String] = []
    private(set) var debugPreviewCount = 0

    func showFrontmostAppProbe() {
        debugPreviewCount += 1
    }

    func cancelPendingHover(reason: String) {
        cancelReasons.append(reason)
    }

    func hidePreview(reason: String) {
        hideReasons.append(reason)
    }
}

@MainActor
private final class FakeAppNameResolver: AppNameResolving {
    var displayNames: [String: String]

    init(displayNames: [String: String] = [:]) {
        self.displayNames = displayNames
    }

    func displayName(forBundleIdentifier bundleIdentifier: String) -> String? {
        displayNames[bundleIdentifier]
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus
    var enableError: Error?
    var disableError: Error?
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginStatus = .notRegistered) {
        self.status = status
    }

    func enable() throws {
        enableCount += 1
        if let enableError {
            throw enableError
        }
    }

    func disable() throws {
        disableCount += 1
        if let disableError {
            throw disableError
        }
    }

    func openSettings() {
        openSettingsCount += 1
    }
}

@MainActor
private extension NSMenu {
    func findItem(title: String, state: NSControl.StateValue? = nil) -> NSMenuItem? {
        flattenedItems().first { item in
            item.title == title && (state.map { item.state == $0 } ?? true)
        }
    }

    func findItem(containing text: String) -> NSMenuItem? {
        flattenedItems().first { $0.title.contains(text) }
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

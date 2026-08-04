import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelViewRenderingTests: XCTestCase {
    func testContextMenuWillOpenIsSentBeforeMenuBegan() {
        let id = PreviewWindowID(pid: 100, windowID: 1)
        var actions: [PreviewPanelAction] = []

        PreviewCardContextMenuEventOrder.emitBeforeMenuTracking(
            for: id,
            onAction: { actions.append($0) }
        )

        XCTAssertEqual(actions, [.contextMenuWillOpen(id), .contextMenuBegan(id)])
    }

    func testFillThumbnailUsesFillSizingAndFixedClippedContainer() {
        let card = makeCard(sourceFrame: CGRect(x: 0, y: 0, width: 1600, height: 900), thumbnail: makeImage())

        let plan = PreviewThumbnailRenderPlan.plan(for: card, unavailableText: "No thumbnail")

        XCTAssertEqual(plan.imageSizing, .fill)
        XCTAssertEqual(plan.containerSize.width, PreviewPanelMetrics.thumbnailWidth, accuracy: 0.001)
        XCTAssertEqual(plan.containerSize.height, PreviewPanelMetrics.thumbnailHeight, accuracy: 0.001)
        XCTAssertTrue(plan.clipsToContainer)
        XCTAssertFalse(plan.showsSpinner)
        XCTAssertNil(plan.unavailableText)
    }

    func testFitThumbnailUsesFitSizingAndFixedClippedContainer() {
        let card = makeCard(sourceFrame: CGRect(x: 0, y: 0, width: 600, height: 700), thumbnail: makeImage())

        let plan = PreviewThumbnailRenderPlan.plan(for: card, unavailableText: "No thumbnail")

        XCTAssertEqual(plan.imageSizing, .fit)
        XCTAssertEqual(plan.containerSize.width, PreviewPanelMetrics.thumbnailWidth, accuracy: 0.001)
        XCTAssertEqual(plan.containerSize.height, PreviewPanelMetrics.thumbnailHeight, accuracy: 0.001)
        XCTAssertTrue(plan.clipsToContainer)
    }

    func testLoadingAndUnavailableUseDifferentPlaceholderPlans() {
        let loading = makeCard(isLoadingThumbnail: true)
        var unavailable = makeCard(isLoadingThumbnail: true)
        unavailable.isLoadingThumbnail = false

        let loadingPlan = PreviewThumbnailRenderPlan.plan(for: loading, unavailableText: "No thumbnail")
        let unavailablePlan = PreviewThumbnailRenderPlan.plan(for: unavailable, unavailableText: "No thumbnail")

        XCTAssertNil(loadingPlan.imageSizing)
        XCTAssertTrue(loadingPlan.showsSpinner)
        XCTAssertNil(loadingPlan.unavailableText)
        XCTAssertNil(unavailablePlan.imageSizing)
        XCTAssertFalse(unavailablePlan.showsSpinner)
        XCTAssertEqual(unavailablePlan.unavailableText, "No thumbnail")
    }

    func testTitleMetricsUseCardGeometry() {
        XCTAssertEqual(
            PreviewPanelMetrics.titleRowWidth,
            PreviewPanelMetrics.cardWidth - PreviewPanelMetrics.cardPadding * 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PreviewPanelMetrics.titleTextWidth,
            PreviewPanelMetrics.titleRowWidth
                - PreviewPanelMetrics.iconSize
                - PreviewPanelMetrics.titleIconSpacing
                - PreviewPanelMetrics.closeButtonSpacing
                - PreviewPanelMetrics.closeButtonSize,
            accuracy: 0.001
        )
    }

    func testCloseControlPlanShowsOnlyDuringHoverAndPreservesAvailability() {
        let enabledCard = makeCard()
        let disabledCard = makeCard(operationMenu: .init(
            activate: .enabled(.activate),
            hideApplication: .enabled(.hideApplication),
            closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
            minimizeWindow: .enabled(.minimizeWindow),
            environmentDescription: "Screen: Built-in Display"
        ))

        XCTAssertEqual(
            PreviewCardCloseControlPlan.plan(for: enabledCard, isHovered: false),
            .init(isVisible: false, isEnabled: true)
        )
        XCTAssertEqual(
            PreviewCardCloseControlPlan.plan(for: enabledCard, isHovered: true),
            .init(isVisible: true, isEnabled: true)
        )
        XCTAssertEqual(
            PreviewCardCloseControlPlan.plan(for: disabledCard, isHovered: true),
            .init(isVisible: true, isEnabled: false)
        )
    }

    func testCloseActionDispatcherEmitsDedicatedCloseIntentOnlyWhenEnabled() {
        let id = PreviewWindowID(pid: 100, windowID: 7)
        let enabledCard = makeCard(id: id)
        let disabledCard = makeCard(id: id, operationMenu: .init(
            activate: .enabled(.activate),
            hideApplication: .enabled(.hideApplication),
            closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
            minimizeWindow: .enabled(.minimizeWindow),
            environmentDescription: "Screen: Built-in Display"
        ))
        var actions: [PreviewPanelAction] = []

        PreviewCardCloseActionDispatcher.dispatch(for: enabledCard) { actions.append($0) }
        PreviewCardCloseActionDispatcher.dispatch(for: disabledCard) { actions.append($0) }

        XCTAssertEqual(actions, [.closePreviewCard(id)])
    }

    func testTitleMetricsReserveTheCloseControlWithoutChangingCardGeometry() {
        XCTAssertEqual(PreviewPanelMetrics.cardWidth, 232, accuracy: 0.001)
        XCTAssertEqual(PreviewPanelMetrics.cardHeight, 172, accuracy: 0.001)
        XCTAssertEqual(
            PreviewPanelMetrics.titleTextWidth,
            PreviewPanelMetrics.titleRowWidth
                - PreviewPanelMetrics.iconSize
                - PreviewPanelMetrics.titleIconSpacing
                - PreviewPanelMetrics.closeButtonSpacing
                - PreviewPanelMetrics.closeButtonSize,
            accuracy: 0.001
        )
    }

    func testRemovingCardKeepsOtherCardsAndReturnsWhetherModelChanged() {
        let first = makeCard(id: .init(pid: 100, windowID: 1))
        let second = makeCard(id: .init(pid: 100, windowID: 2))
        var model = PreviewPanelViewModel(appName: "Code", cards: [first, second], maxCardCount: 8)

        XCTAssertTrue(model.removeCard(for: first.id))
        XCTAssertEqual(model.cards.map(\.id), [second.id])
        XCTAssertFalse(model.removeCard(for: first.id))
    }

    func testOperationMenuPlanIncludesFourOperationsAndEnvironmentHint() {
        let card = makeCard(operationMenu: PreviewWindowOperationMenuModel(
            activate: .enabled(.activate),
            hideApplication: .enabled(.hideApplication),
            closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
            minimizeWindow: .enabled(.minimizeWindow),
            environmentDescription: "Screen: Built-in Display"
        ))
        let text = PreviewWindowOperationMenuText(textProvider: AppTextProvider(language: .english))

        let items = PreviewWindowOperationMenuPlan.items(for: card, text: text)

        XCTAssertEqual(items.map(\.kind), [
            .operation(.activate),
            .operation(.hideApplication),
            .operation(.closeWindow),
            .operation(.minimizeWindow),
            .separator,
            .information
        ])
        XCTAssertEqual(items.map(\.title), [
            "Activate Window",
            "Hide App",
            "Close Window",
            "Minimize Window",
            "",
            "Screen: Built-in Display"
        ])
        XCTAssertEqual(items[2].isEnabled, false)
        XCTAssertEqual(items[5].isEnabled, false)
    }

    func testDisabledOperationMenuItemDoesNotDispatchAction() {
        let id = PreviewWindowID(pid: 100, windowID: 1)
        let card = makeCard(
            id: id,
            operationMenu: PreviewWindowOperationMenuModel(
                activate: .enabled(.activate),
                hideApplication: .enabled(.hideApplication),
                closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
                minimizeWindow: .enabled(.minimizeWindow),
                environmentDescription: "Screen: Built-in Display"
            )
        )
        var actions: [PreviewPanelAction] = []

        PreviewWindowOperationMenuActionDispatcher.dispatch(.closeWindow, for: card) {
            actions.append($0)
        }
        PreviewWindowOperationMenuActionDispatcher.dispatch(.minimizeWindow, for: card) {
            actions.append($0)
        }

        XCTAssertEqual(actions, [.windowOperation(id, .minimizeWindow)])
    }

    private func makeCard(
        id: PreviewWindowID = PreviewWindowID(pid: 100, windowID: 1),
        sourceFrame: CGRect = CGRect(x: 0, y: 0, width: 1600, height: 900),
        thumbnail: CGImage? = nil,
        isLoadingThumbnail: Bool = true,
        operationMenu: PreviewWindowOperationMenuModel = .allEnabled()
    ) -> PreviewCardViewModel {
        PreviewCardViewModel(
            id: id,
            title: "Project",
            appName: "Code",
            appIcon: NSImage(size: NSSize(width: 16, height: 16)),
            thumbnail: thumbnail,
            isLoadingThumbnail: isLoadingThumbnail,
            sourceFrame: sourceFrame,
            operationMenu: operationMenu
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

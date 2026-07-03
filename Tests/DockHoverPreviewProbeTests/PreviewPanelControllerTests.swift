import CoreGraphics
import SwiftUI
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class PreviewPanelControllerTests: XCTestCase {
    func testMouseInsidePanelIsFalseBeforePanelIsShown() {
        let controller = PreviewPanelController(logger: ProbeLogger())

        XCTAssertFalse(controller.isMouseInsidePanel(CGPoint(x: 0, y: 0)))
    }

    func testShowAndHideUseStandardAnimationWhenReduceMotionIsOff() {
        let motionPreferences = FakeMotionPreferenceProvider(shouldReduceMotion: false)
        let animator = RecordingPanelAnimationController()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: motionPreferences,
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        controller.show(model: makeModel(), anchor: makeAnchor(), onSelect: { _ in })
        controller.hide(reason: "test")

        let calls = animator.animationCalls
        XCTAssertEqual(calls, [
            .init(kind: .show, mode: .standard),
            .init(kind: .hide, mode: .standard)
        ])
        XCTAssertTrue(calls.allSatisfy { $0.mode?.usesScaleOrOffset == true })
    }

    func testShowAndHideUseReducedMotionPathWhenReduceMotionIsOn() {
        let motionPreferences = FakeMotionPreferenceProvider(shouldReduceMotion: true)
        let animator = RecordingPanelAnimationController()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: motionPreferences,
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        controller.show(model: makeModel(), anchor: makeAnchor(), onSelect: { _ in })
        controller.hide(reason: "test")

        let calls = animator.animationCalls
        XCTAssertEqual(calls, [
            .init(kind: .show, mode: .reducedMotion),
            .init(kind: .hide, mode: .reducedMotion)
        ])
        XCTAssertFalse(calls.contains { $0.mode?.usesScaleOrOffset == true })
    }

    func testUpdateRerendersWithoutRepeatingShowAnimation() throws {
        let animator = RecordingPanelAnimationController()
        let anchor = makeAnchor()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: FakeMotionPreferenceProvider(shouldReduceMotion: false),
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        controller.show(model: makeModel(appName: "Initial", windowIDs: [1]), anchor: anchor, onSelect: { _ in })
        controller.update(model: makeModel(appName: "Updated", windowIDs: [1, 2, 3]))

        XCTAssertEqual(animator.animationCalls.filter { $0.kind == .show }.count, 1)
        XCTAssertEqual(animator.animationCalls.filter { $0.kind == .hide }.count, 0)
        XCTAssertEqual(
            controller.panelFrame(),
            PreviewPanelLayoutEngine.frame(
                for: PreviewPanelMetrics.panelSize(cardCount: 3, layout: .horizontal),
                anchor: anchor
            )
        )

        let hostedView = try XCTUnwrap(animator.hostedView)
        XCTAssertEqual(hostedView.model.appName, "Updated")
        XCTAssertEqual(hostedView.model.cards.count, 3)
    }

    func testHideImmediatelyClearsInteractiveFrameWhileAnimationIsPending() throws {
        let animator = RecordingPanelAnimationController()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: FakeMotionPreferenceProvider(shouldReduceMotion: false),
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        controller.show(model: makeModel(), anchor: makeAnchor(), onSelect: { _ in })
        let visibleFrame = try XCTUnwrap(controller.panelFrame())

        controller.hide(reason: "mouseLeftPreviewRegion")

        XCTAssertNil(controller.panelFrame())
        XCTAssertFalse(controller.isMouseInsidePanel(CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)))
        XCTAssertEqual(animator.latestPanel?.ignoresMouseEvents, true)
        XCTAssertEqual(animator.pendingHideCompletionCount, 1)
    }

    func testStaleHideCompletionDoesNotOrderOutPanelShownAgain() throws {
        let animator = RecordingPanelAnimationController()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: FakeMotionPreferenceProvider(shouldReduceMotion: false),
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        var selectedIDs: [PreviewWindowID] = []
        controller.show(model: makeModel(appName: "First", windowIDs: [1]), anchor: makeAnchor(dockItemX: 200)) {
            selectedIDs.append($0)
        }
        controller.hide(reason: "transition")
        XCTAssertNil(controller.panelFrame())
        XCTAssertEqual(animator.pendingHideCompletionCount, 1)

        controller.show(model: makeModel(appName: "Second", windowIDs: [2]), anchor: makeAnchor(dockItemX: 700)) {
            selectedIDs.append($0)
        }
        let frameAfterSecondShow = try XCTUnwrap(controller.panelFrame())
        let panel = try XCTUnwrap(animator.latestPanel)
        XCTAssertTrue(panel.isVisible)
        XCTAssertFalse(panel.ignoresMouseEvents)

        animator.completeNextHideAnimation()

        XCTAssertEqual(controller.panelFrame(), frameAfterSecondShow)
        XCTAssertTrue(panel.isVisible)

        let hostedView = try XCTUnwrap(animator.hostedView)
        XCTAssertEqual(hostedView.model.appName, "Second")
        let latestID = try XCTUnwrap(hostedView.model.cards.first?.id)

        hostedView.onSelect(latestID)

        XCTAssertEqual(selectedIDs, [latestID])
    }

    func testStaleHideCompletionDoesNotResetCurrentPanelPresentationState() throws {
        let animator = CompletionSideEffectPanelAnimationController()
        let controller = PreviewPanelController(
            logger: ProbeLogger(),
            motionPreferences: FakeMotionPreferenceProvider(shouldReduceMotion: false),
            animator: animator
        )
        defer { animator.orderOutTrackedPanels() }

        controller.show(model: makeModel(appName: "First", windowIDs: [1]), anchor: makeAnchor(dockItemX: 200)) { _ in }
        controller.hide(reason: "transition")
        controller.show(model: makeModel(appName: "Second", windowIDs: [2]), anchor: makeAnchor(dockItemX: 700)) { _ in }

        let panel = try XCTUnwrap(animator.latestPanel)
        panel.alphaValue = 0.37

        animator.completeNextHideAnimation()

        XCTAssertEqual(panel.alphaValue, 0.37, accuracy: 0.001)
        XCTAssertTrue(panel.isVisible)
    }
}

@MainActor
private final class FakeMotionPreferenceProvider: MotionPreferenceProviding {
    var accessibilityDisplayShouldReduceMotion: Bool

    init(shouldReduceMotion: Bool) {
        accessibilityDisplayShouldReduceMotion = shouldReduceMotion
    }
}

@MainActor
private final class RecordingPanelAnimationController: PanelAnimationControlling {
    struct Call: Equatable {
        enum Kind: Equatable {
            case cancel
            case show
            case hide
        }

        let kind: Kind
        let mode: PreviewPanelAnimationMode?
    }

    private(set) var calls: [Call] = []
    private(set) var trackedPanels: [NSPanel] = []
    private var pendingHideCompletions: [@MainActor @Sendable () -> Bool] = []

    var latestPanel: NSPanel? { trackedPanels.last }
    var hostedView: PreviewPanelView? {
        (latestPanel?.contentViewController as? NSHostingController<PreviewPanelView>)?.rootView
    }
    var animationCalls: [Call] {
        calls.filter { $0.kind != .cancel }
    }
    var pendingHideCompletionCount: Int {
        pendingHideCompletions.count
    }

    func cancelAnimations(for panel: NSPanel) {
        track(panel)
        calls.append(.init(kind: .cancel, mode: nil))
    }

    func animateShow(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        track(panel)
        calls.append(.init(kind: .show, mode: mode))
        _ = completion()
    }

    func animateHide(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        track(panel)
        calls.append(.init(kind: .hide, mode: mode))
        pendingHideCompletions.append(completion)
    }

    func completeNextHideAnimation() {
        guard !pendingHideCompletions.isEmpty else { return }
        _ = pendingHideCompletions.removeFirst()()
    }

    func orderOutTrackedPanels() {
        trackedPanels.forEach { $0.orderOut(nil) }
    }

    private func track(_ panel: NSPanel) {
        guard !trackedPanels.contains(where: { $0 === panel }) else { return }
        trackedPanels.append(panel)
    }
}

@MainActor
private final class CompletionSideEffectPanelAnimationController: PanelAnimationControlling {
    private(set) var trackedPanels: [NSPanel] = []
    private var pendingHideCompletions: [(panel: NSPanel, completion: @MainActor @Sendable () -> Bool)] = []

    var latestPanel: NSPanel? { trackedPanels.last }

    func cancelAnimations(for panel: NSPanel) {
        track(panel)
    }

    func animateShow(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        track(panel)
        _ = completion()
    }

    func animateHide(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        track(panel)
        pendingHideCompletions.append((panel, completion))
    }

    func completeNextHideAnimation() {
        guard !pendingHideCompletions.isEmpty else { return }
        let next = pendingHideCompletions.removeFirst()
        if next.completion() {
            next.panel.alphaValue = 1
        }
    }

    func orderOutTrackedPanels() {
        trackedPanels.forEach { $0.orderOut(nil) }
    }

    private func track(_ panel: NSPanel) {
        guard !trackedPanels.contains(where: { $0 === panel }) else { return }
        trackedPanels.append(panel)
    }
}

private func makeModel(
    appName: String = "Preview",
    windowIDs: [CGWindowID] = [1]
) -> PreviewPanelViewModel {
    PreviewPanelViewModel(
        appName: appName,
        cards: windowIDs.map { windowID in
            PreviewCardViewModel(
                id: PreviewWindowID(pid: 100, windowID: windowID),
                title: "Window \(windowID)",
                appName: appName,
                appIcon: NSImage(size: NSSize(width: 16, height: 16)),
                thumbnail: nil,
                isLoadingThumbnail: true
            )
        },
        maxCardCount: 8
    )
}

private func makeAnchor(dockItemX: CGFloat = 700) -> PreviewPanelAnchor {
    PreviewPanelAnchor(
        dockItemFrame: CGRect(x: dockItemX, y: 0, width: 52, height: 48),
        mouseLocation: CGPoint(x: dockItemX + 26, y: 24),
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
    )
}

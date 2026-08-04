import AppKit
@preconcurrency import ApplicationServices
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowPeekLifecycleObserverTests: XCTestCase {
    func testMultipleDestroyedSubscriptionsDeliverOnlyToTheirMatchingWindow() {
        let observer = RecordingWindowDestroyedObserver()
        let first = PreviewWindowID(pid: 100, windowID: 1)
        let second = PreviewWindowID(pid: 100, windowID: 2)
        var destroyed: [PreviewWindowID] = []

        _ = observer.observeWindow(id: first, element: AXUIElementCreateApplication(first.pid)) {
            destroyed.append($0)
        }
        _ = observer.observeWindow(id: second, element: AXUIElementCreateApplication(second.pid)) {
            destroyed.append($0)
        }
        observer.emitDestroyed(id: second)
        observer.emitDestroyed(id: first)

        XCTAssertEqual(destroyed, [second, first])
    }

    func testCancellingDestroyedSubscriptionSuppressesItsLateCallback() throws {
        let observer = RecordingWindowDestroyedObserver()
        let id = PreviewWindowID(pid: 100, windowID: 1)
        var destroyed: [PreviewWindowID] = []

        let token = try XCTUnwrap(observer.observeWindow(
            id: id,
            element: AXUIElementCreateApplication(id.pid)
        ) {
            destroyed.append($0)
        })
        token.cancel()
        observer.emitDestroyed(id: id)

        XCTAssertEqual(destroyed, [])
    }

    func testNotificationsAndCurrentDestroyedTargetMapToLifecycleEvents() {
        let workspaceCenter = NotificationCenter()
        let applicationCenter = NotificationCenter()
        let destroyedObserver = RecordingWindowDestroyedObserver()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: applicationCenter,
            destroyedObserver: destroyedObserver,
            logger: ProbeLogger()
        )
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        let element = AXUIElementCreateApplication(id.pid)
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }

        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        applicationCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        workspaceCenter.post(
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current]
        )
        observer.observeTargetWindow(id: id, element: element)
        destroyedObserver.emitDestroyed(id: id)

        XCTAssertEqual(events, [
            .activeSpaceChanged,
            .screenParametersChanged,
            .applicationTerminated(NSRunningApplication.current.processIdentifier),
            .targetWindowDestroyed(id)
        ])
    }

    func testReplacingAndClearingTargetDropsOldDestroyedCallbacks() {
        let destroyedObserver = RecordingWindowDestroyedObserver()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: NotificationCenter(),
            applicationNotificationCenter: NotificationCenter(),
            destroyedObserver: destroyedObserver,
            logger: ProbeLogger()
        )
        let first = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        let second = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 2)
        let element = AXUIElementCreateApplication(first.pid)
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }

        observer.observeTargetWindow(id: first, element: element)
        observer.observeTargetWindow(id: second, element: element)
        destroyedObserver.emitDestroyed(id: first)
        destroyedObserver.emitDestroyed(id: second)
        observer.observeTargetWindow(id: nil, element: nil)
        destroyedObserver.emitDestroyed(id: second)

        XCTAssertEqual(events, [.targetWindowDestroyed(second)])
        XCTAssertEqual(destroyedObserver.activeIDs, Set<PreviewWindowID>())
    }

    func testReplacingDesktopPeekTargetDoesNotCancelIndependentDestroyedSubscription() throws {
        let destroyedObserver = RecordingWindowDestroyedObserver()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: NotificationCenter(),
            applicationNotificationCenter: NotificationCenter(),
            destroyedObserver: destroyedObserver,
            logger: ProbeLogger()
        )
        let previewClose = PreviewWindowID(pid: 100, windowID: 1)
        let firstTarget = PreviewWindowID(pid: 100, windowID: 2)
        let secondTarget = PreviewWindowID(pid: 100, windowID: 3)
        var externallyDestroyed: [PreviewWindowID] = []
        var lifecycleEvents: [WindowPeekLifecycleEvent] = []
        observer.start { lifecycleEvents.append($0) }

        let token = try XCTUnwrap(destroyedObserver.observeWindow(
            id: previewClose,
            element: AXUIElementCreateApplication(previewClose.pid)
        ) {
            externallyDestroyed.append($0)
        })
        observer.observeTargetWindow(
            id: firstTarget,
            element: AXUIElementCreateApplication(firstTarget.pid)
        )
        observer.observeTargetWindow(
            id: secondTarget,
            element: AXUIElementCreateApplication(secondTarget.pid)
        )
        observer.observeTargetWindow(id: nil, element: nil)
        destroyedObserver.emitDestroyed(id: previewClose)

        XCTAssertEqual(externallyDestroyed, [previewClose])
        XCTAssertEqual(lifecycleEvents, [])
        token.cancel()
    }

    func testStopRemovesNotificationHandlersAndClearsTargetSubscriber() {
        let workspaceCenter = NotificationCenter()
        let applicationCenter = NotificationCenter()
        let destroyedObserver = RecordingWindowDestroyedObserver()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: applicationCenter,
            destroyedObserver: destroyedObserver,
            logger: ProbeLogger()
        )
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }
        observer.observeTargetWindow(id: id, element: AXUIElementCreateApplication(id.pid))
        observer.stop()

        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        applicationCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        destroyedObserver.emitDestroyed(id: id)

        XCTAssertEqual(events, [])
        XCTAssertEqual(destroyedObserver.activeIDs, Set<PreviewWindowID>())
    }

    func testStartAndStopAreIdempotent() {
        let workspaceCenter = NotificationCenter()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: NotificationCenter(),
            destroyedObserver: RecordingWindowDestroyedObserver(),
            logger: ProbeLogger()
        )
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }
        observer.start { _ in events.append(.screenParametersChanged) }

        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        observer.stop()
        observer.stop()
        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        XCTAssertEqual(events, [.activeSpaceChanged])
    }
}

@MainActor
private final class RecordingWindowDestroyedObserver: WindowDestroyedObserving {
    private var handlers: [UUID: (PreviewWindowID, @MainActor (PreviewWindowID) -> Void)] = [:]

    var activeIDs: Set<PreviewWindowID> {
        Set(handlers.values.map(\.0))
    }

    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)? {
        guard element != nil else { return nil }
        let tokenID = UUID()
        handlers[tokenID] = (id, onDestroyed)
        return Token { [weak self] in self?.handlers.removeValue(forKey: tokenID) }
    }

    func emitDestroyed(id: PreviewWindowID) {
        let callbacks = handlers.values.filter { $0.0 == id }
        callbacks.forEach { $0.1(id) }
    }

    @MainActor
    private final class Token: WindowDestroyedObservation {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }
}

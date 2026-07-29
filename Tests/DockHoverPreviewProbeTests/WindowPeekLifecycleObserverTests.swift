import AppKit
@preconcurrency import ApplicationServices
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class WindowPeekLifecycleObserverTests: XCTestCase {
    func testDestroyedSubscriptionRejectsCallbackForAReplacedElement() {
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        let currentElement = AXUIElementCreateApplication(id.pid)
        let staleElement = AXUIElementCreateSystemWide()
        let subscription = WindowPeekTargetDestroyedSubscription(
            id: id,
            element: currentElement
        )

        XCTAssertTrue(subscription.matches(currentElement))
        XCTAssertFalse(subscription.matches(staleElement))
    }

    func testNotificationsAndCurrentDestroyedTargetMapToLifecycleEvents() {
        let workspaceCenter = NotificationCenter()
        let applicationCenter = NotificationCenter()
        let subscriber = RecordingTargetDestroyedSubscriber()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: applicationCenter,
            targetDestroyedSubscriber: subscriber,
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
        subscriber.emitDestroyed(id: id)

        XCTAssertEqual(events, [
            .activeSpaceChanged,
            .screenParametersChanged,
            .applicationTerminated(NSRunningApplication.current.processIdentifier),
            .targetWindowDestroyed(id)
        ])
    }

    func testReplacingAndClearingTargetDropsOldDestroyedCallbacks() {
        let subscriber = RecordingTargetDestroyedSubscriber()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: NotificationCenter(),
            applicationNotificationCenter: NotificationCenter(),
            targetDestroyedSubscriber: subscriber,
            logger: ProbeLogger()
        )
        let first = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        let second = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 2)
        let element = AXUIElementCreateApplication(first.pid)
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }

        observer.observeTargetWindow(id: first, element: element)
        observer.observeTargetWindow(id: second, element: element)
        subscriber.emitDestroyed(id: first)
        subscriber.emitDestroyed(id: second)
        observer.observeTargetWindow(id: nil, element: nil)
        subscriber.emitDestroyed(id: second)

        XCTAssertEqual(subscriber.events, [.clear, .replaced(first), .clear, .replaced(second), .clear])
        XCTAssertEqual(events, [.targetWindowDestroyed(second)])
    }

    func testStopRemovesNotificationHandlersAndClearsTargetSubscriber() {
        let workspaceCenter = NotificationCenter()
        let applicationCenter = NotificationCenter()
        let subscriber = RecordingTargetDestroyedSubscriber()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: applicationCenter,
            targetDestroyedSubscriber: subscriber,
            logger: ProbeLogger()
        )
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: 1)
        var events: [WindowPeekLifecycleEvent] = []
        observer.start { events.append($0) }
        observer.observeTargetWindow(id: id, element: AXUIElementCreateApplication(id.pid))
        observer.stop()

        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        applicationCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        subscriber.emitDestroyed(id: id)

        XCTAssertEqual(events, [])
        XCTAssertEqual(subscriber.events.last, .clear)
    }

    func testStartAndStopAreIdempotent() {
        let workspaceCenter = NotificationCenter()
        let observer = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: workspaceCenter,
            applicationNotificationCenter: NotificationCenter(),
            targetDestroyedSubscriber: RecordingTargetDestroyedSubscriber(),
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
private final class RecordingTargetDestroyedSubscriber: WindowPeekTargetDestroyedSubscribing {
    enum Event: Equatable {
        case clear
        case replaced(PreviewWindowID)
    }

    private(set) var events: [Event] = []
    private var currentID: PreviewWindowID?
    private var handler: (@MainActor (PreviewWindowID) -> Void)?

    func replaceTarget(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) {
        clear()
        events.append(.replaced(id))
        currentID = id
        handler = onDestroyed
    }

    func clear() {
        events.append(.clear)
        currentID = nil
        handler = nil
    }

    func emitDestroyed(id: PreviewWindowID) {
        guard currentID == id else { return }
        handler?(id)
    }
}

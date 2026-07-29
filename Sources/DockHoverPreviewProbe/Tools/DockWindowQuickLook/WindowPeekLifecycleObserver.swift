import AppKit
@preconcurrency import ApplicationServices

enum WindowPeekLifecycleEvent: Equatable, Sendable {
    case activeSpaceChanged
    case screenParametersChanged
    case applicationTerminated(pid_t)
    case targetWindowDestroyed(PreviewWindowID)
}

@MainActor
protocol WindowPeekLifecycleObserving: AnyObject {
    func start(_ handler: @escaping @MainActor (WindowPeekLifecycleEvent) -> Void)
    func observeTargetWindow(id: PreviewWindowID?, element: AXUIElement?)
    func stop()
}

@MainActor
protocol WindowPeekTargetDestroyedSubscribing: AnyObject {
    func replaceTarget(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    )

    func clear()
}

@MainActor
struct WindowPeekTargetDestroyedSubscription {
    let id: PreviewWindowID
    let element: AXUIElement

    func matches(_ callbackElement: AXUIElement) -> Bool {
        CFEqual(element, callbackElement)
    }
}

@MainActor
final class WindowPeekLifecycleObserver: WindowPeekLifecycleObserving {
    private let workspaceNotificationCenter: NotificationCenter
    private let applicationNotificationCenter: NotificationCenter
    private let targetDestroyedSubscriber: any WindowPeekTargetDestroyedSubscribing
    private let logger: ProbeLogger
    private var workspaceTokens: [NSObjectProtocol] = []
    private var applicationTokens: [NSObjectProtocol] = []
    private var handler: (@MainActor (WindowPeekLifecycleEvent) -> Void)?

    init(
        workspaceNotificationCenter: NotificationCenter,
        applicationNotificationCenter: NotificationCenter,
        targetDestroyedSubscriber: any WindowPeekTargetDestroyedSubscribing,
        logger: ProbeLogger
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.applicationNotificationCenter = applicationNotificationCenter
        self.targetDestroyedSubscriber = targetDestroyedSubscriber
        self.logger = logger
    }

    func start(_ handler: @escaping @MainActor (WindowPeekLifecycleEvent) -> Void) {
        guard self.handler == nil else { return }
        self.handler = handler

        workspaceTokens = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                precondition(Thread.isMainThread)
                MainActor.assumeIsolated {
                    self?.emit(.activeSpaceChanged)
                }
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let pid = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .processIdentifier
                precondition(Thread.isMainThread)
                MainActor.assumeIsolated {
                    guard let pid else {
                        self?.logger.warning("peek.lifecycle.terminationMissingApplication")
                        return
                    }
                    self?.emit(.applicationTerminated(pid))
                }
            }
        ]

        applicationTokens = [
            applicationNotificationCenter.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                precondition(Thread.isMainThread)
                MainActor.assumeIsolated {
                    self?.emit(.screenParametersChanged)
                }
            }
        ]
    }

    func observeTargetWindow(id: PreviewWindowID?, element: AXUIElement?) {
        guard let id, let element else {
            targetDestroyedSubscriber.clear()
            return
        }
        targetDestroyedSubscriber.replaceTarget(id: id, element: element) { [weak self] destroyedID in
            self?.emit(.targetWindowDestroyed(destroyedID))
        }
    }

    func stop() {
        handler = nil
        workspaceTokens.forEach(workspaceNotificationCenter.removeObserver)
        workspaceTokens.removeAll()
        applicationTokens.forEach(applicationNotificationCenter.removeObserver)
        applicationTokens.removeAll()
        targetDestroyedSubscriber.clear()
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    private func emit(_ event: WindowPeekLifecycleEvent) {
        handler?(event)
    }
}

@MainActor
final class SystemWindowPeekTargetDestroyedSubscriber: WindowPeekTargetDestroyedSubscribing {
    private let logger: ProbeLogger
    private var observer: AXObserver?
    private var subscription: WindowPeekTargetDestroyedSubscription?
    private var observerSource: CFRunLoopSource?
    private var handler: (@MainActor (PreviewWindowID) -> Void)?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func replaceTarget(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) {
        clear()
        guard let element else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=noElement")
            return
        }

        var newObserver: AXObserver?
        let createResult = AXObserverCreate(id.pid, windowPeekTargetDestroyedCallback, &newObserver)
        guard createResult == .success, let newObserver else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=\(createResult.rawValue)")
            return
        }

        let addResult = AXObserverAddNotification(
            newObserver,
            element,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard addResult == .success else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=\(addResult.rawValue)")
            return
        }

        let source = AXObserverGetRunLoopSource(newObserver)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        observer = newObserver
        subscription = WindowPeekTargetDestroyedSubscription(id: id, element: element)
        observerSource = source
        handler = onDestroyed
    }

    func clear() {
        if let observer, let subscription {
            AXObserverRemoveNotification(observer, subscription.element, kAXUIElementDestroyedNotification as CFString)
        }
        if let observerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerSource, .commonModes)
        }
        observer = nil
        subscription = nil
        observerSource = nil
        handler = nil
    }

    deinit {
        MainActor.assumeIsolated {
            clear()
        }
    }

    fileprivate func handleDestroyedNotification(from callbackElement: AXUIElement) {
        guard let subscription, subscription.matches(callbackElement) else { return }
        handler?(subscription.id)
    }
}

private let windowPeekTargetDestroyedCallback: AXObserverCallback = { _, element, _, refcon in
    guard let refcon else { return }
    precondition(Thread.isMainThread)
    let subscriber = Unmanaged<SystemWindowPeekTargetDestroyedSubscriber>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated {
        subscriber.handleDestroyedNotification(from: element)
    }
}

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
protocol WindowDestroyedObservation: AnyObject {
    func cancel()
}

@MainActor
protocol WindowDestroyedObserving: AnyObject {
    @discardableResult
    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)?
}

@MainActor
final class WindowPeekLifecycleObserver: WindowPeekLifecycleObserving {
    private let workspaceNotificationCenter: NotificationCenter
    private let applicationNotificationCenter: NotificationCenter
    private let destroyedObserver: any WindowDestroyedObserving
    private let logger: ProbeLogger
    private var workspaceTokens: [NSObjectProtocol] = []
    private var applicationTokens: [NSObjectProtocol] = []
    private var targetDestroyedObservation: (any WindowDestroyedObservation)?
    private var handler: (@MainActor (WindowPeekLifecycleEvent) -> Void)?

    init(
        workspaceNotificationCenter: NotificationCenter,
        applicationNotificationCenter: NotificationCenter,
        destroyedObserver: any WindowDestroyedObserving,
        logger: ProbeLogger
    ) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.applicationNotificationCenter = applicationNotificationCenter
        self.destroyedObserver = destroyedObserver
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
        targetDestroyedObservation?.cancel()
        targetDestroyedObservation = nil
        guard let id else { return }
        targetDestroyedObservation = destroyedObserver.observeWindow(id: id, element: element) { [weak self] destroyedID in
            self?.emit(.targetWindowDestroyed(destroyedID))
        }
    }

    func stop() {
        handler = nil
        targetDestroyedObservation?.cancel()
        targetDestroyedObservation = nil
        workspaceTokens.forEach(workspaceNotificationCenter.removeObserver)
        workspaceTokens.removeAll()
        applicationTokens.forEach(applicationNotificationCenter.removeObserver)
        applicationTokens.removeAll()
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
final class SystemWindowDestroyedObserver: WindowDestroyedObserving {
    private let logger: ProbeLogger
    private var observations: [UUID: SystemWindowDestroyedObservation] = [:]

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    @discardableResult
    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)? {
        guard let element else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=noElement")
            return nil
        }

        var axObserver: AXObserver?
        let createResult = AXObserverCreate(id.pid, windowDestroyedCallback, &axObserver)
        guard createResult == .success, let axObserver else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=\(createResult.rawValue)")
            return nil
        }

        let tokenID = UUID()
        let source = AXObserverGetRunLoopSource(axObserver)
        let observation = SystemWindowDestroyedObservation(
            id: id,
            element: element,
            axObserver: axObserver,
            source: source,
            onDestroyed: onDestroyed,
            onCancel: { [weak self] in
                self?.removeObservation(id: tokenID)
            }
        )

        let addResult = AXObserverAddNotification(
            axObserver,
            element,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(observation).toOpaque()
        )
        guard addResult == .success else {
            logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=\(addResult.rawValue)")
            return nil
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        observations[tokenID] = observation
        return observation
    }

    private func removeObservation(id: UUID) {
        observations.removeValue(forKey: id)
    }

    deinit {
        MainActor.assumeIsolated {
            let activeObservations = Array(observations.values)
            activeObservations.forEach { $0.cancel() }
        }
    }
}

@MainActor
private final class SystemWindowDestroyedObservation: WindowDestroyedObservation {
    private let id: PreviewWindowID
    private let element: AXUIElement
    private let axObserver: AXObserver
    private let source: CFRunLoopSource
    private let onDestroyed: @MainActor (PreviewWindowID) -> Void
    private var onCancel: (() -> Void)?
    private var isCancelled = false

    init(
        id: PreviewWindowID,
        element: AXUIElement,
        axObserver: AXObserver,
        source: CFRunLoopSource,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.id = id
        self.element = element
        self.axObserver = axObserver
        self.source = source
        self.onDestroyed = onDestroyed
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        AXObserverRemoveNotification(axObserver, element, kAXUIElementDestroyedNotification as CFString)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        onCancel?()
        onCancel = nil
    }

    fileprivate func handleDestroyedNotification(from callbackElement: AXUIElement) {
        guard !isCancelled, CFEqual(element, callbackElement) else { return }
        onDestroyed(id)
    }
}

private let windowDestroyedCallback: AXObserverCallback = { _, element, _, refcon in
    guard let refcon else { return }
    precondition(Thread.isMainThread)
    let observation = Unmanaged<SystemWindowDestroyedObservation>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated {
        observation.handleDestroyedNotification(from: element)
    }
}

import AppKit
import Foundation

@MainActor
protocol HoverDelayCancellation: AnyObject {
    func cancel()
}

@MainActor
protocol HoverDelayScheduling: AnyObject {
    func schedule(
        afterMilliseconds milliseconds: Int,
        action: @escaping @MainActor () -> Void
    ) -> HoverDelayCancellation
}

@MainActor
final class DispatchHoverDelayScheduler: HoverDelayScheduling {
    func schedule(
        afterMilliseconds milliseconds: Int,
        action: @escaping @MainActor () -> Void
    ) -> HoverDelayCancellation {
        let delayNanoseconds = UInt64(max(milliseconds, 0)) * 1_000_000
        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }
            action()
        }
        return DispatchHoverDelayCancellation(task: task)
    }
}

@MainActor
private final class DispatchHoverDelayCancellation: HoverDelayCancellation {
    private var task: Task<Void, Never>?

    init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
protocol FrontmostApplicationProviding: AnyObject {
    func frontmostApplication() -> NSRunningApplication?
}

@MainActor
final class WorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {
    func frontmostApplication() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }
}

import Foundation

final class ProbeLogger: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    func info(_ message: String) {
        append(level: "INFO", message: message)
    }

    func warning(_ message: String) {
        append(level: "WARN", message: message)
    }

    func error(_ message: String) {
        append(level: "ERROR", message: message)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    private func append(level: String, message: String) {
        let line = "\(Self.timestamp()) [\(level)] \(message)"
        lock.lock()
        entries.append(line)
        lock.unlock()
        NSLog("%@", line)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

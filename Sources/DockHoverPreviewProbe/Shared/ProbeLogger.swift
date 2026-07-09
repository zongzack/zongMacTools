import Foundation
import OSLog

final class ProbeLogger: @unchecked Sendable {
    private let lock = NSLock()
    private let systemLogger = Logger(subsystem: "com.zong.zongMacTools", category: "probe")
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

        switch level {
        case "INFO":
            systemLogger.info("\(line, privacy: .public)")
        case "WARN":
            systemLogger.warning("\(line, privacy: .public)")
        case "ERROR":
            systemLogger.error("\(line, privacy: .public)")
        default:
            systemLogger.notice("\(line, privacy: .public)")
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

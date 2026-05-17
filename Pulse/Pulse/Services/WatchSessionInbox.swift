import Foundation

/// UserDefaults-backed queue for breath sessions the watch shipped back via
/// `transferUserInfo`. WCSession's delegate callbacks come on a background queue,
/// so the delegate appends payloads here; `AppState.bootstrap()` drains the queue
/// on the main actor and writes the sessions into SwiftData.
enum WatchSessionInbox {
    nonisolated private static let key = "pulse.watchSessions.queue.v1"

    nonisolated static func enqueue(_ payload: [String: Any]) {
        var queue = (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
        queue.append(payload)
        UserDefaults.standard.set(queue, forKey: key)
    }

    /// Drains and clears the queue atomically. Returns whatever was pending.
    static func drainAll() -> [[String: Any]] {
        let queue = (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
        UserDefaults.standard.removeObject(forKey: key)
        return queue
    }
}

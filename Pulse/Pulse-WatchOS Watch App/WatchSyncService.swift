import Foundation
import WatchConnectivity
import Observation

/// Watch half of the iPhone ↔ Apple Watch handoff.
///
/// **Phone → Watch:** receives `updateApplicationContext` payloads in the delegate
/// (background queue), then hands them to the main actor to update @Observable state.
/// The most recent context is cached to UserDefaults so the watch home shows the
/// last-known next event immediately on launch, even if the phone isn't reachable yet.
///
/// **Watch → Phone:** `shipCompletedSession(...)` is called when the user finishes a
/// 60-second breath on the wrist. `transferUserInfo` guarantees delivery — the
/// payload is queued by the system until the phone is reachable, then dropped into
/// `WatchSessionInbox` on the phone for SwiftData persistence.
@Observable
@MainActor
final class WatchSyncService {
    static let shared = WatchSyncService()

    var nextEventTitle: String?
    var nextEventStart: Date?
    var nextEventSymbol: String?
    var patternKey: String = "box"

    var pattern: BreathingPattern { .from(rawKey: patternKey) }

    private let delegate: SessionDelegate
    private let session = WCSession.default
    nonisolated private static let cacheKey = "pulse.watch.lastContext.v1"

    init() {
        delegate = SessionDelegate()
        delegate.owner = self
        if WCSession.isSupported() {
            session.delegate = delegate
            session.activate()
        }
        // Restore last-known phone state so the home shows event info immediately,
        // even before the first applicationContext push arrives.
        if let cached = UserDefaults.standard.dictionary(forKey: Self.cacheKey) {
            apply(context: cached)
        }
    }

    func apply(context: [String: Any]) {
        nextEventTitle = context["eventTitle"] as? String
        if let startSince = context["eventStart"] as? Double {
            nextEventStart = Date(timeIntervalSinceReferenceDate: startSince)
        } else {
            nextEventStart = nil
        }
        nextEventSymbol = context["eventSymbol"] as? String
        if let key = context["patternKey"] as? String { patternKey = key }
        UserDefaults.standard.set(context, forKey: Self.cacheKey)
    }

    func shipCompletedSession(startedAt: Date, patternKey: String, eventTitle: String?) {
        guard WCSession.isSupported() else { return }
        var payload: [String: Any] = [
            "startedAt": startedAt.timeIntervalSinceReferenceDate,
            "patternKey": patternKey
        ]
        if let eventTitle { payload["eventTitle"] = eventTitle }
        session.transferUserInfo(payload)
    }
}

private final class SessionDelegate: NSObject, WCSessionDelegate {
    weak var owner: WatchSyncService?

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor [weak owner] in
            owner?.apply(context: applicationContext)
        }
    }
}

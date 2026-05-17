import Foundation
import WatchConnectivity
import SwiftData
import Observation

/// Phone half of the iPhone ↔ Apple Watch handoff. Two flows:
///
/// **Phone → Watch:** `publish(...)` ships the next monitored calendar event +
/// the user's chosen breathing pattern via `updateApplicationContext`. Last-write-
/// wins is the right semantic here — the watch only ever cares about "what's
/// current right now."
///
/// **Watch → Phone:** the watch calls `transferUserInfo` after a completed breath.
/// Our delegate (running on a background queue) drops the payload into
/// `WatchSessionInbox`. `AppState.bootstrap()` drains the inbox on the main actor
/// and writes a `BreathingSession` into SwiftData so the moment appears in History.
@Observable
@MainActor
final class PhoneSyncService {
    private let delegate = SessionDelegate()
    private let session = WCSession.default

    init() {
        guard WCSession.isSupported() else { return }
        session.delegate = delegate
        session.activate()
    }

    /// Sends the current state to the watch. Cheap to call — WCSession diffs the
    /// context and only sends if it actually changed.
    func publish(nextEvent: WidgetSnapshot.Event?, patternKey: String) {
        guard WCSession.isSupported() else { return }
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        var context: [String: Any] = ["patternKey": patternKey]
        if let event = nextEvent {
            context["eventTitle"] = event.title
            context["eventStart"] = event.start.timeIntervalSinceReferenceDate
            context["eventSymbol"] = event.categorySymbolName
        }
        try? session.updateApplicationContext(context)
    }

    /// Decode every queued watch session and persist as a BreathingSession.
    /// Called from `AppState.bootstrap()` so any watch moments that arrived while
    /// the phone was backgrounded land in History on next launch.
    static func drainSessionInbox(into context: ModelContext) {
        for payload in WatchSessionInbox.drainAll() {
            guard let startedSince = payload["startedAt"] as? Double else { continue }
            let startedAt = Date(timeIntervalSinceReferenceDate: startedSince)
            let patternKey = payload["patternKey"] as? String
            let eventTitle = payload["eventTitle"] as? String ?? "A moment on the wrist"

            let session = BreathingSession(
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(60),
                eventTitle: eventTitle,
                eventCategory: .other,
                breathingPatternRaw: patternKey
            )
            context.insert(session)
        }
        PulseStorage.save(context, reason: "drain watch sessions")
    }
}

private final class SessionDelegate: NSObject, WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    // iOS requires both of these — see WCSessionDelegate docs.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Required to reactivate after a session swap (e.g. user switched watches).
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        // Background queue — write to defaults inbox; main app drains on bootstrap.
        WatchSessionInbox.enqueue(userInfo)
    }
}

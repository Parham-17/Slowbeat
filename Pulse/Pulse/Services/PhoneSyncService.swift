import Foundation
import WatchConnectivity
import SwiftData
import Observation

/// Phone half of the iPhone ↔ Apple Watch handoff. Two flows:
///
/// **Phone → Watch:** `publish(...)` ships the current state via
/// `updateApplicationContext`. Last-write-wins is the right semantic here — the
/// watch only ever cares about "what's current right now." The context carries:
///   • next monitored calendar event (title / start / category symbol)
///   • patternKey (the user's chosen breathing pattern)
///   • haptics + eyesUp toggles
///   • `recent` — up to 5 most-recent completed sessions for the Recent tab
///
/// **Watch → Phone:** the watch calls `transferUserInfo` from four flows. The
/// delegate (background queue) drops them into `WatchSessionInbox`.
/// `AppState.bootstrap()` drains the inbox on the main actor and applies each
/// `kind` (completedSession, outcome, patternChange).
///   • completedSession — a wrist breath finished; persist as `BreathingSession`
///   • outcome          — user picked Smooth/Steady/Tough in reflection; merge into the row
///   • patternChange    — user switched pattern on the wrist; mirror into PulseSettings
@Observable
@MainActor
final class PhoneSyncService {
    private let delegate = SessionDelegate()
    private let session = WCSession.default

    /// Set by `AppState.bootstrap` to a closure that drains the WatchSessionInbox
    /// and republishes to the watch. The WC delegate calls this on every
    /// `didReceiveUserInfo` so a watch-shipped session lands in History
    /// immediately, instead of waiting for the next scenePhase active to run
    /// bootstrap. Without this, a session finished on the wrist while the iPhone
    /// app is in the foreground sits in the inbox until the user backgrounds
    /// and returns.
    var onUserInfoArrived: (@MainActor () -> Void)?

    init() {
        guard WCSession.isSupported() else { return }
        delegate.owner = self
        session.delegate = delegate
        session.activate()
    }

    /// Sends the current state to the watch. Cheap to call — WCSession diffs the
    /// context and only sends if it actually changed.
    ///
    /// Two event slots travel together: `nextEvent` (the upcoming one Pulse is
    /// preparing for) and `ongoingEvent` (the meeting the user is currently
    /// inside). `ongoingEnd` is a sidecar because the widget snapshot Event
    /// shape doesn't carry an end (the widget doesn't need it). Either or both
    /// can be nil.
    func publish(
        nextEvent: WidgetSnapshot.Event?,
        ongoingEvent: WidgetSnapshot.Event?,
        ongoingEnd: Date?,
        patternKey: String,
        haptics: Bool,
        eyesUp: Bool,
        recent: [RecentSessionDTO]
    ) {
        guard WCSession.isSupported() else { return }
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        var context: [String: Any] = [
            "patternKey": patternKey,
            "haptics":    haptics,
            "eyesUp":     eyesUp,
            "recent":     recent.map(\.dictionary),
            "publishedAt": Date.now.timeIntervalSinceReferenceDate
        ]
        if let event = nextEvent {
            context["eventTitle"]  = event.title
            context["eventStart"]  = event.start.timeIntervalSinceReferenceDate
            context["eventSymbol"] = event.categorySymbolName
        }
        if let event = ongoingEvent {
            context["ongoingTitle"]  = event.title
            context["ongoingStart"]  = event.start.timeIntervalSinceReferenceDate
            context["ongoingSymbol"] = event.categorySymbolName
            if let ongoingEnd {
                context["ongoingEnd"] = ongoingEnd.timeIntervalSinceReferenceDate
            }
        }
        try? session.updateApplicationContext(context)
    }

    /// Decode every queued watch payload and apply it. Dispatches by `kind`:
    /// completedSession → insert; outcome → patch existing; patternChange → settings.
    /// Called from `AppState.bootstrap()` so anything that landed while the phone
    /// was backgrounded gets processed on next active.
    static func drainSessionInbox(into context: ModelContext, settings: PulseSettings) {
        for payload in WatchSessionInbox.drainAll() {
            let kind = (payload["kind"] as? String) ?? "completedSession"
            switch kind {
            case "completedSession":  applyCompletedSession(payload, into: context)
            case "outcome":           applyOutcome(payload, into: context)
            case "patternChange":     applyPatternChange(payload, settings: settings)
            default:                  break
            }
        }
        PulseStorage.save(context, reason: "drain watch sessions")
    }

    private static func applyCompletedSession(_ payload: [String: Any], into context: ModelContext) {
        guard let startedSince = payload["startedAt"] as? Double else { return }
        let startedAt = Date(timeIntervalSinceReferenceDate: startedSince)
        let patternKey = payload["patternKey"] as? String
        let rawTitle = payload["eventTitle"] as? String
        // Time-of-day fallback ("Morning breath", etc.) keyed to when the
        // breath actually happened — so wrist sessions read varied in the
        // iPhone's Moments list, and the title isn't long enough to clip
        // next to the wrist glyph in the History row.
        let eventTitle = rawTitle ?? SessionTitle.generic(for: startedAt)
        let moodRaw = payload["moodRaw"] as? String
        let sessionIDString = payload["sessionID"] as? String

        // Idempotency: if a session with this UUID already exists (e.g. the
        // payload was re-delivered after a connectivity blip), skip the insert
        // so we don't create duplicate History rows. WCSession sometimes
        // re-delivers transferUserInfo on activation if the prior delivery
        // wasn't acked cleanly. `try?` flattens optionals, so the chain
        // produces `BreathingSession?` directly — a non-nil result means the
        // row is already in SwiftData.
        if let id = sessionIDString.flatMap(UUID.init(uuidString:)) {
            let descriptor = FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> { $0.id == id }
            )
            if (try? context.fetch(descriptor).first) != nil {
                return
            }
        }

        // Auto-suggest a category from the title when we have one — gives the
        // session a meaningful icon + accent in iPhone Moments instead of the
        // generic "Other" sparkles. Generic wrist titles still fall back to
        // .other since none of the keywords match.
        let category: EventCategory = rawTitle.map(EventCategory.suggest(for:)) ?? .other

        let session = BreathingSession(
            id: sessionIDString.flatMap(UUID.init(uuidString:)) ?? UUID(),
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(60),
            eventTitle: eventTitle,
            eventCategory: category,
            preMood: moodRaw.flatMap(PreMood.resolve(rawValue:)),
            breathingPatternRaw: patternKey,
            source: .watch
        )
        context.insert(session)
    }

    private static func applyOutcome(_ payload: [String: Any], into context: ModelContext) {
        guard let idString = payload["sessionID"] as? String,
              let id = UUID(uuidString: idString),
              let outcomeRaw = payload["outcomeRaw"] as? String,
              let outcome = Outcome(rawValue: outcomeRaw)
        else { return }
        let descriptor = FetchDescriptor<BreathingSession>(
            predicate: #Predicate<BreathingSession> { $0.id == id }
        )
        if let session = try? context.fetch(descriptor).first {
            session.outcome = outcome
        }
    }

    private static func applyPatternChange(_ payload: [String: Any], settings: PulseSettings) {
        guard let raw = payload["patternKey"] as? String,
              let key = BreathingPattern.Key(rawValue: raw)
        else { return }
        settings.breathingPattern = BreathingPattern.from(key: key)
    }
}

private final class SessionDelegate: NSObject, WCSessionDelegate {
    weak var owner: PhoneSyncService?

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    // iOS requires both of these — see WCSessionDelegate docs.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Required to reactivate after a session swap (e.g. user switched watches).
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        // Background queue — write to defaults inbox so anything that arrives
        // while the iPhone is suspended still gets caught by the next bootstrap.
        WatchSessionInbox.enqueue(userInfo)
        // Also nudge the owner on the main actor so a foregrounded iPhone drains
        // and republishes immediately. Without this, History only updates on the
        // next scenePhase active transition.
        Task { @MainActor [weak owner] in
            owner?.onUserInfoArrived?()
        }
    }
}

/// Phone-side DTO for the Recent tab on the watch. Mirrors the watch's
/// `RecentSession` shape exactly — the watch decodes from this dictionary.
struct RecentSessionDTO {
    let id: String
    let title: String
    let completedAt: Date
    let patternKey: String?
    let moodRaw: String?
    let outcomeRaw: String?

    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "title": title,
            "completedAt": completedAt.timeIntervalSinceReferenceDate
        ]
        if let patternKey { d["patternKey"] = patternKey }
        if let moodRaw    { d["moodRaw"]    = moodRaw }
        if let outcomeRaw { d["outcomeRaw"] = outcomeRaw }
        return d
    }

    init(session: BreathingSession) {
        self.id = session.id.uuidString
        self.title = session.eventTitle
        self.completedAt = session.completedAt ?? session.startedAt
        self.patternKey = session.breathingPatternRaw
        self.moodRaw = session.preMood?.rawValue
        self.outcomeRaw = session.outcome?.rawValue
    }
}

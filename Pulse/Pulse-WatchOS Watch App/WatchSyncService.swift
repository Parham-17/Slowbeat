import Foundation
import WatchConnectivity
import Observation

/// Watch half of the iPhone ↔ Apple Watch handoff.
///
/// **Phone → Watch:** receives `updateApplicationContext` payloads in the delegate
/// (background queue), then hands them to the main actor to update @Observable state.
/// The most recent context is cached to UserDefaults so the watch home shows the
/// last-known data immediately on launch, even if the phone isn't reachable yet.
///
/// Payload keys (all optional, only present keys are applied):
///   • eventTitle, eventStart, eventSymbol — the next monitored calendar event
///   • patternKey   — the user's chosen breathing pattern (mirrors Settings)
///   • haptics      — Bool, whether the breath plays haptics
///   • eyesUp       — Bool, dim the visual chrome
///   • recent       — [[String: Any]] of up to 5 RecentSession dictionaries
///
/// **Watch → Phone:** four flows, all via `transferUserInfo` (queues until reachable):
///   1. Completed breath session (`shipCompletedSession`)
///   2. Pattern changed on the wrist (`shipPatternChange`)
///   3. Outcome chosen on the wrist after a breath (`shipOutcome`)
///   4. Mood picked on the wrist before a breath travels with (1).
@Observable
@MainActor
final class WatchSyncService {
    static let shared = WatchSyncService()

    var nextEventTitle: String?
    var nextEventStart: Date?
    var nextEventSymbol: String?
    /// A meeting the user is currently inside (start ≤ now < end), pushed by the
    /// iPhone. nil when nothing is happening right now. Lets the Now tab show a
    /// "Happening now" badge so the user knows where they are at a glance.
    var ongoingTitle: String?
    var ongoingStart: Date?
    var ongoingEnd: Date?
    var ongoingSymbol: String?
    var patternKey: String = "box"
    var hapticsEnabled: Bool = true
    var eyesUpEnabled: Bool = false
    var recent: [RecentSession] = []
    /// When the phone last pushed an applicationContext (server time, decoded
    /// from the payload). Used to age-check titles before stamping them onto a
    /// completed session — a cached context from yesterday must not produce a
    /// breath labeled "Standup with Bob" on the iPhone's History.
    var lastPublishedAt: Date?

    var pattern: BreathingPattern { .from(rawKey: patternKey) }

    /// Treat ongoing/next event titles as nil if the phone hasn't published a
    /// fresh context within this window. Five minutes is long enough to cover a
    /// brief WC drop, short enough that an overnight-stale context isn't trusted.
    private let titleFreshnessWindow: TimeInterval = 5 * 60

    /// True when the cached event data is recent enough to trust as "what's
    /// happening right now." False if we've never received a context, or the
    /// last one is older than `titleFreshnessWindow`. UI that reads
    /// ongoing/next titles directly is fine — it's only when we *persist* a
    /// title onto a session that staleness matters.
    var hasFreshContext: Bool {
        guard let at = lastPublishedAt else { return false }
        return Date.now.timeIntervalSince(at) < titleFreshnessWindow
    }

    private let delegate: SessionDelegate
    private let session = WCSession.default
    nonisolated private static let cacheKey = "pulse.watch.lastContext.v3"

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
            apply(context: cached, cache: false)
        }
    }

    func apply(context: [String: Any], cache: Bool = true) {
        // Next-event keys: present-or-absent semantics mean a missing key wipes the
        // existing value, so a phone that has no upcoming event clears the watch.
        nextEventTitle  = context["eventTitle"]  as? String
        nextEventStart  = (context["eventStart"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
        nextEventSymbol = context["eventSymbol"] as? String

        // Ongoing-event keys — same semantics.
        ongoingTitle  = context["ongoingTitle"]  as? String
        ongoingStart  = (context["ongoingStart"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
        ongoingEnd    = (context["ongoingEnd"]   as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
        ongoingSymbol = context["ongoingSymbol"] as? String

        if let key = context["patternKey"] as? String { patternKey = key }
        if let h   = context["haptics"]    as? Bool   { hapticsEnabled = h }
        if let e   = context["eyesUp"]     as? Bool   { eyesUpEnabled  = e }

        if let arr = context["recent"] as? [[String: Any]] {
            // Merge rather than overwrite: any locally-prepended optimistic
            // session that hasn't round-tripped through the phone yet stays at
            // the top, so the user doesn't see their just-finished breath
            // vanish from Moments. Phone-canonical entries replace local ones
            // when their IDs match.
            let phoneList = arr.compactMap(RecentSession.init(dictionary:))
            let phoneIDs = Set(phoneList.map(\.id))
            let pendingLocal = recent.filter { phoneIDs.contains($0.id) == false }
            recent = (pendingLocal + phoneList).prefix(5).map { $0 }
        }

        lastPublishedAt = (context["publishedAt"] as? Double)
            .map(Date.init(timeIntervalSinceReferenceDate:))

        if cache {
            UserDefaults.standard.set(context, forKey: Self.cacheKey)
        }
    }

    /// True when there is currently an ongoing meeting (and it hasn't expired).
    /// Watches and clocks drift; this check keeps the badge from sticking around
    /// after the meeting actually ends if the phone hasn't republished yet.
    var hasOngoing: Bool {
        guard let end = ongoingEnd else { return ongoingTitle != nil }
        return end > .now && ongoingTitle != nil
    }

    /// Local pattern change on the watch. Optimistically updates local state and
    /// also notifies the phone so the canonical setting and widgets follow.
    func setPattern(_ key: BreathingPattern.Key) {
        patternKey = key.rawValue
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        session.transferUserInfo([
            "kind": "patternChange",
            "patternKey": key.rawValue
        ])
    }

    /// Called when the user finishes a 60-second breath on the wrist. Includes the
    /// mood the user reported pre-breath (if any), so the phone can persist it on
    /// the same session record. Returns the session UUID for callers that want to
    /// chain a later outcome update — marked `@discardableResult` because callers
    /// that don't need that chain (the summary-only flow) shouldn't have to ignore it.
    @discardableResult
    func shipCompletedSession(
        startedAt: Date,
        patternKey: String,
        eventTitle: String?,
        mood: WatchPreMood?
    ) -> UUID {
        let id = UUID()
        // Optimistically prepend to the watch's local Recent list so the Moments
        // tab updates immediately, without waiting for the phone to drain its
        // inbox and republish the context back to us. Without this, a session
        // finished on the wrist doesn't appear in the watch's own Moments tab
        // until the iPhone app is foregrounded.
        let local = RecentSession(
            id: id.uuidString,
            // Mirrors SessionTitle on the phone — must produce the same string
            // for the same start time, so the optimistic prepend stays
            // identical after the phone republishes the canonical row back.
            title: eventTitle ?? SessionTitle.generic(for: startedAt),
            completedAt: startedAt.addingTimeInterval(60),
            patternKey: patternKey,
            moodRaw: mood?.rawValue,
            outcomeRaw: nil
        )
        recent.insert(local, at: 0)
        if recent.count > 5 { recent = Array(recent.prefix(5)) }

        guard WCSession.isSupported() else { return id }
        var payload: [String: Any] = [
            "kind": "completedSession",
            "sessionID": id.uuidString,
            "startedAt": startedAt.timeIntervalSinceReferenceDate,
            "patternKey": patternKey
        ]
        if let eventTitle { payload["eventTitle"] = eventTitle }
        if let mood       { payload["moodRaw"]    = mood.rawValue }
        session.transferUserInfo(payload)
        return id
    }

    /// Called from the post-breath reflection screen when the user picks an outcome.
    /// `sessionID` ties the outcome back to the session the watch just shipped.
    func shipOutcome(sessionID: UUID, outcome: WatchOutcome) {
        guard WCSession.isSupported() else { return }
        session.transferUserInfo([
            "kind": "outcome",
            "sessionID": sessionID.uuidString,
            "outcomeRaw": outcome.rawValue
        ])
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

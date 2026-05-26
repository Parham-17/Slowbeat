import Foundation
import SwiftData

/// Where a session was recorded. Lets the History UI badge wrist-originated
/// sessions and lets future analytics distinguish input modalities. Stored as
/// an optional raw string so SwiftData performs a lightweight migration —
/// existing rows read back as nil and the accessor falls back to `.iphone`.
enum SessionSource: String, Codable {
    case iphone
    case watch
}

@Model
final class BreathingSession {
    var id: UUID
    var startedAt: Date
    var completedAt: Date?

    var eventTitle: String
    var eventStartAt: Date?
    var eventCategoryRaw: String

    var preMoodRaw: String?

    var outcomeRaw: String?
    var note: String?

    /// Implementation-intention plan the user formed at the end of the ritual.
    /// Two short strings — "If <situation>" / "I will <response>" — captured because
    /// Gollwitzer & Sheeran's 2006 meta-analysis (d=0.65) shows if-then plans
    /// reliably translate intentions into action.
    var intentionIf: String?
    var intentionThen: String?

    /// Which breathing pattern was used for this session (raw key from BreathingPattern.Key).
    /// Optional so older sessions don't need migration; nil reads as "box".
    var breathingPatternRaw: String?

    /// Which device the breath happened on. Optional for back-compat with pre-source
    /// records — those read as `.iphone` via the computed accessor below.
    var sourceRaw: String?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        eventTitle: String,
        eventStartAt: Date? = nil,
        eventCategory: EventCategory = .other,
        preMood: PreMood? = nil,
        outcome: Outcome? = nil,
        note: String? = nil,
        intentionIf: String? = nil,
        intentionThen: String? = nil,
        breathingPatternRaw: String? = nil,
        source: SessionSource = .iphone
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.eventTitle = eventTitle
        self.eventStartAt = eventStartAt
        self.eventCategoryRaw = eventCategory.rawValue
        self.preMoodRaw = preMood?.rawValue
        self.outcomeRaw = outcome?.rawValue
        self.note = note
        self.intentionIf = intentionIf
        self.intentionThen = intentionThen
        self.breathingPatternRaw = breathingPatternRaw
        self.sourceRaw = source.rawValue
    }

    var category: EventCategory {
        get { EventCategory(rawValue: eventCategoryRaw) ?? .other }
        set { eventCategoryRaw = newValue.rawValue }
    }

    var preMood: PreMood? {
        get { preMoodRaw.flatMap(PreMood.resolve(rawValue:)) }
        set { preMoodRaw = newValue?.rawValue }
    }

    var outcome: Outcome? {
        get { outcomeRaw.flatMap(Outcome.init(rawValue:)) }
        set { outcomeRaw = newValue?.rawValue }
    }

    /// Where this session was recorded. Defaults to `.iphone` for legacy rows
    /// that predate the source field (their raw is nil).
    var source: SessionSource {
        get { sourceRaw.flatMap(SessionSource.init(rawValue:)) ?? .iphone }
        set { sourceRaw = newValue.rawValue }
    }

    /// True iff the user filled in at least one half of the if-then plan.
    var hasIntention: Bool {
        let i = intentionIf?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let t = intentionThen?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return i || t
    }
}

import Foundation

/// Light DTO the phone ships to the watch for the Recent tab. Just enough to render
/// a row — no SwiftData, no foreign types, no nested PreMood/Outcome enums (the watch
/// reconstructs those from the raw strings, just like the phone does).
struct RecentSession: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let completedAt: Date
    let patternKey: String?
    let moodRaw: String?
    let outcomeRaw: String?

    var mood: WatchPreMood? { moodRaw.flatMap(WatchPreMood.init(rawValue:)) }
    var outcome: WatchOutcome? { outcomeRaw.flatMap(WatchOutcome.init(rawValue:)) }
    var patternName: String { BreathingPattern.from(rawKey: patternKey).name }

    /// Encodes/decodes against the [String: Any] dictionary WatchConnectivity allows.
    /// Dates round-trip as seconds-since-reference-date (Double) for cheap PLIST encoding.
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

    init(id: String, title: String, completedAt: Date,
         patternKey: String? = nil, moodRaw: String? = nil, outcomeRaw: String? = nil) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
        self.patternKey = patternKey
        self.moodRaw = moodRaw
        self.outcomeRaw = outcomeRaw
    }

    init?(dictionary d: [String: Any]) {
        guard let id    = d["id"] as? String,
              let title = d["title"] as? String,
              let since = d["completedAt"] as? Double
        else { return nil }
        self.id = id
        self.title = title
        self.completedAt = Date(timeIntervalSinceReferenceDate: since)
        self.patternKey = d["patternKey"] as? String
        self.moodRaw    = d["moodRaw"]    as? String
        self.outcomeRaw = d["outcomeRaw"] as? String
    }
}

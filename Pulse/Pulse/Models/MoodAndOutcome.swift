import SwiftUI

/// Pre-breath affective state. Grounded in Russell's (1980) circumplex model of affect —
/// emotions live in a 2D space of valence (negative↔positive) and arousal (low↔high).
/// Each case corresponds to one quadrant; the (valence, arousal) coordinates are exposed
/// for future analysis.
enum PreMood: String, CaseIterable, Identifiable, Codable {
    case anxious     // high arousal, negative valence
    case energized   // high arousal, positive valence
    case settled     // low arousal, positive valence
    case flat        // low arousal, negative valence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anxious:   "Anxious"
        case .energized: "Energized"
        case .settled:   "Settled"
        case .flat:      "Flat"
        }
    }

    var symbol: String {
        switch self {
        case .anxious:   "wind"
        case .energized: "bolt"
        case .settled:   "leaf"
        case .flat:      "circle.dotted"
        }
    }

    /// Russell circumplex coordinates. Range [-1, 1] on each axis.
    var valence: Double {
        switch self {
        case .anxious, .flat:        return -0.6
        case .energized, .settled:   return  0.6
        }
    }

    var arousal: Double {
        switch self {
        case .anxious, .energized:   return  0.7
        case .settled, .flat:        return -0.7
        }
    }

    /// Migrates legacy raw values from earlier builds.
    /// Old cases (calm/alert/racing/scattered) map to the four circumplex quadrants.
    /// `nonisolated` so SwiftData model accessors (which run off the main actor) can call it.
    nonisolated static func resolve(rawValue: String) -> PreMood? {
        if let direct = PreMood(rawValue: rawValue) { return direct }
        switch rawValue {
        case "calm":      return .settled
        case "alert":     return .energized
        case "racing":    return .anxious
        case "scattered": return .flat
        default:          return nil
        }
    }
}

enum Outcome: String, CaseIterable, Identifiable, Codable {
    case smooth, steady, tough

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smooth: "Went smoothly"
        case .steady: "Held steady"
        case .tough:  "Was tough"
        }
    }

    var symbol: String {
        switch self {
        case .smooth: "sun.max"
        case .steady: "circle.dashed"
        case .tough:  "cloud.rain"
        }
    }

    /// 0..1 — used for charting trend over time.
    var score: Double {
        switch self {
        case .smooth: 1.0
        case .steady: 0.5
        case .tough:  0.0
        }
    }
}

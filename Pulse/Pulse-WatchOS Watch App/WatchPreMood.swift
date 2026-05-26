import SwiftUI

/// watchOS mirror of `PreMood`. Identical raw values so a mood picked on the wrist
/// rehydrates to the same case on the phone.
enum WatchPreMood: String, CaseIterable, Identifiable, Codable {
    case anxious
    case energized
    case settled
    case flat

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

    /// Tint color for chips, accent strokes and the breath ring — keyed to the
    /// same halo variant the user sees when they begin a breath in this state.
    var tint: Color { WatchTheme.accent(for: self) }
}

/// watchOS mirror of `Outcome`. Three options for post-breath reflection.
enum WatchOutcome: String, CaseIterable, Identifiable, Codable {
    case smooth
    case steady
    case tough

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smooth: "Smooth"
        case .steady: "Steady"
        case .tough:  "Tough"
        }
    }

    var symbol: String {
        switch self {
        case .smooth: "sun.max"
        case .steady: "circle.dashed"
        case .tough:  "cloud.rain"
        }
    }
}

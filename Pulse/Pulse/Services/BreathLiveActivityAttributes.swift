import Foundation
import ActivityKit

/// Attributes + content state for the breath-in-progress Live Activity.
///
/// MIRRORED in `Pulse Widget/BreathLiveActivityAttributes.swift`. ActivityKit matches
/// activities across processes by attribute type identity — the type name, properties,
/// and Codable shape MUST stay identical between the two copies.
struct BreathLiveActivityAttributes: ActivityAttributes {
    /// Stateless context the activity is started with — never changes for the duration.
    var eventTitle: String
    var patternName: String
    var totalSeconds: Double
    var startedAt: Date

    /// Updates over the life of the activity. Kept small; ActivityKit re-renders the
    /// Lock Screen + Dynamic Island whenever this state object changes.
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable {
            case inhale, holdFull, exhale, holdEmpty, done
        }
        var phase: Phase
        /// 0...1 progress through the entire 60-second session.
        var progress: Double
        /// Whole seconds remaining; widget renders this monospaced.
        var secondsRemaining: Int
    }
}

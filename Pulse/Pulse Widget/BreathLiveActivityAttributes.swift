import Foundation
import ActivityKit

/// MIRROR of `Pulse/Services/BreathLiveActivityAttributes.swift`. Both copies must hold
/// identical types — ActivityKit matches activities across processes via type identity.
struct BreathLiveActivityAttributes: ActivityAttributes {
    var eventTitle: String
    var patternName: String
    var totalSeconds: Double
    var startedAt: Date

    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable {
            case inhale, holdFull, exhale, holdEmpty, done
        }
        var phase: Phase
        var progress: Double
        var secondsRemaining: Int
    }
}

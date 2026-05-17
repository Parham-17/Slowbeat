import Foundation

/// Phase durations + display strings for one breathing method.
///
/// Zero-duration phases are skipped at runtime (e.g. coherent has no holds).
/// All durations are in seconds.
struct BreathingPattern: Identifiable, Hashable {
    enum Key: String, CaseIterable, Codable, Identifiable {
        case box
        case cyclicSigh
        case coherent
        var id: String { rawValue }
    }

    let key: Key
    let name: String
    let summary: String
    let evidenceLine: String

    let inhale: Double
    let holdFull: Double
    let exhale: Double
    let holdEmpty: Double

    let inhaleLabel: String
    let holdFullLabel: String?
    let exhaleLabel: String
    let holdEmptyLabel: String?

    let inhaleVoice: String
    let holdFullVoice: String?
    let exhaleVoice: String
    let holdEmptyVoice: String?

    var id: Key { key }
    var cycleDuration: Double { inhale + holdFull + exhale + holdEmpty }

    /// Box breathing — equal four-count. The Pulse default.
    static let box = BreathingPattern(
        key: .box,
        name: "Box",
        summary: "Four counts in, four hold, four out, four rest. Symmetric and grounding.",
        evidenceLine: "Slow-paced breathing with direct RCT support for acute state change.",
        inhale: 4, holdFull: 4, exhale: 4, holdEmpty: 4,
        inhaleLabel: "Breathe in",
        holdFullLabel: "Hold",
        exhaleLabel: "Breathe out",
        holdEmptyLabel: "Rest",
        inhaleVoice: "Breathe in slowly",
        holdFullVoice: "Hold gently",
        exhaleVoice: "Breathe out slowly",
        holdEmptyVoice: "Rest"
    )

    /// Cyclic sighing — double inhale through the nose, long exhale through the mouth.
    /// Strongest direct evidence in the 2023 Stanford RCT for mood improvement.
    static let cyclicSigh = BreathingPattern(
        key: .cyclicSigh,
        name: "Cyclic sigh",
        summary: "Short inhale, second small inhale, long exhale through the mouth.",
        evidenceLine: "Strongest mood-improvement effect in Balban et al., Cell Reports Medicine 2023.",
        inhale: 2, holdFull: 1, exhale: 6, holdEmpty: 0,
        inhaleLabel: "Breathe in",
        holdFullLabel: "Sip in",
        exhaleLabel: "Long exhale",
        holdEmptyLabel: nil,
        inhaleVoice: "Breathe in through the nose",
        holdFullVoice: "A small second breath in",
        exhaleVoice: "Long exhale through the mouth",
        holdEmptyVoice: nil
    )

    /// Coherent / resonance breathing — five in, five out, ~6 breaths per minute.
    /// Targets the cardiac–respiratory resonance frequency for maximal HRV.
    static let coherent = BreathingPattern(
        key: .coherent,
        name: "Coherent",
        summary: "Five seconds in, five seconds out. Six breaths a minute, no holds.",
        evidenceLine: "Aligns breathing with HRV resonance frequency (Lehrer et al.; Steffen et al.).",
        inhale: 5, holdFull: 0, exhale: 5, holdEmpty: 0,
        inhaleLabel: "Breathe in",
        holdFullLabel: nil,
        exhaleLabel: "Breathe out",
        holdEmptyLabel: nil,
        inhaleVoice: "Breathe in slowly",
        holdFullVoice: nil,
        exhaleVoice: "Breathe out slowly",
        holdEmptyVoice: nil
    )

    static let all: [BreathingPattern] = [.box, .cyclicSigh, .coherent]

    static func from(key: Key) -> BreathingPattern {
        switch key {
        case .box:        return .box
        case .cyclicSigh: return .cyclicSigh
        case .coherent:   return .coherent
        }
    }

    static func from(rawKey: String?) -> BreathingPattern {
        guard let raw = rawKey, let key = Key(rawValue: raw) else { return .box }
        return .from(key: key)
    }
}

import Foundation

/// MIRROR of `Pulse/Models/BreathingPattern.swift`. Must stay shape-aligned with the
/// iOS version so a key sent over WatchConnectivity resolves to the same pattern.
struct BreathingPattern: Identifiable, Hashable {
    enum Key: String, CaseIterable, Codable, Identifiable {
        case box
        case cyclicSigh
        case coherent
        var id: String { rawValue }
    }

    let key: Key
    let name: String

    let inhale: Double
    let holdFull: Double
    let exhale: Double
    let holdEmpty: Double

    let inhaleLabel: String
    let holdFullLabel: String?
    let exhaleLabel: String
    let holdEmptyLabel: String?

    var id: Key { key }
    var cycleDuration: Double { inhale + holdFull + exhale + holdEmpty }

    static let box = BreathingPattern(
        key: .box, name: "Box",
        inhale: 4, holdFull: 4, exhale: 4, holdEmpty: 4,
        inhaleLabel: "Breathe in", holdFullLabel: "Hold",
        exhaleLabel: "Breathe out", holdEmptyLabel: "Rest"
    )

    static let cyclicSigh = BreathingPattern(
        key: .cyclicSigh, name: "Cyclic sigh",
        inhale: 2, holdFull: 1, exhale: 6, holdEmpty: 0,
        inhaleLabel: "Breathe in", holdFullLabel: "Sip in",
        exhaleLabel: "Long exhale", holdEmptyLabel: nil
    )

    static let coherent = BreathingPattern(
        key: .coherent, name: "Coherent",
        inhale: 5, holdFull: 0, exhale: 5, holdEmpty: 0,
        inhaleLabel: "Breathe in", holdFullLabel: nil,
        exhaleLabel: "Breathe out", holdEmptyLabel: nil
    )

    static func from(rawKey: String?) -> BreathingPattern {
        guard let raw = rawKey, let key = Key(rawValue: raw) else { return .box }
        switch key {
        case .box:        return .box
        case .cyclicSigh: return .cyclicSigh
        case .coherent:   return .coherent
        }
    }
}

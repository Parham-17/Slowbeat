import Foundation
import CoreHaptics
import Observation

/// Plays the breath rhythm as a continuous Core Haptics pattern: a rising hum on inhale,
/// a soft transient at the top of hold, a falling hum on exhale, silence on rest. Each
/// phase has its own texture, so the user can do the ritual eyes-up if they want.
///
/// Designed to fail open: on devices/simulators without haptic hardware, every call
/// silently no-ops and the visual breath still works.
@Observable
@MainActor
final class HapticEngine {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?

    var isAvailable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Lazy-prepares the engine. Safe to call multiple times.
    func prepare() {
        guard isAvailable, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            try e.start()
            e.resetHandler = { [weak e] in try? e?.start() }
            e.stoppedHandler = { _ in }
            engine = e
        } catch {
            engine = nil
        }
    }

    /// Stop any in-flight pattern and free the player.
    func stop() {
        try? player?.stop(atTime: 0)
        player = nil
    }

    /// Plays the breath sequence for `cycleCount` cycles of `pattern`. Pattern is built
    /// once and played start-to-finish; no per-frame scheduling. If the player can't
    /// start (engine missing, hardware unsupported, etc.) it silently no-ops.
    func playBreathSequence(pattern: BreathingPattern, cycleCount: Int) {
        guard isAvailable else { return }
        prepare()
        guard let engine else { return }

        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []
        var t: TimeInterval = 0

        for _ in 0..<cycleCount {
            // Inhale: continuous event, intensity curve ramps 0 → 1 over its duration.
            if pattern.inhale > 0 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.40),
                        .init(parameterID: .hapticSharpness, value: 0.30)
                    ],
                    relativeTime: t,
                    duration: pattern.inhale
                ))
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0,                value: 0.0),
                        .init(relativeTime: pattern.inhale,   value: 1.0)
                    ],
                    relativeTime: t
                ))
            }
            t += pattern.inhale

            // Top of hold: single soft transient (a barely-perceptible "you're full").
            if pattern.holdFull > 0 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.25),
                        .init(parameterID: .hapticSharpness, value: 0.20)
                    ],
                    relativeTime: t
                ))
            }
            t += pattern.holdFull

            // Exhale: continuous event, intensity curve falls 1 → 0 over its duration.
            if pattern.exhale > 0 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.35),
                        .init(parameterID: .hapticSharpness, value: 0.20)
                    ],
                    relativeTime: t,
                    duration: pattern.exhale
                ))
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0,              value: 1.0),
                        .init(relativeTime: pattern.exhale, value: 0.0)
                    ],
                    relativeTime: t
                ))
            }
            t += pattern.exhale

            // Rest: silence. Nothing scheduled.
            t += pattern.holdEmpty
        }

        do {
            let chPattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let p = try engine.makeAdvancedPlayer(with: chPattern)
            p.loopEnabled = false
            try p.start(atTime: CHHapticTimeImmediate)
            self.player = p
        } catch {
            // Playback failed — silently no-op.
        }
    }
}

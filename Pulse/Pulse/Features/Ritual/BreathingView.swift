import SwiftUI
import UIKit

/// Keystone screen: a 60-second paced-breathing animation that follows a `BreathingPattern`.
/// Default is box (4-4-4-4); cyclic sighing and coherent breathing are also supported.
struct BreathingView: View {
    enum Phase: Int {
        case inhale, holdFull, exhale, holdEmpty
    }

    let pattern: BreathingPattern
    var durationSeconds: Double = 60
    /// Title for the Live Activity (Lock Screen / Dynamic Island) so the user knows
    /// what moment is currently in progress. Defaults to the brand for manual moments.
    var eventTitle: String = "Slowbeat"
    /// Pre-breath affective state, if reported. Drives the halo's color tint
    /// (saturation modulation along iso-principle lines).
    var mood: PreMood? = nil
    /// When true, plays the rising-hum / hold-tap / falling-pulse haptic pattern
    /// alongside the visual breath. Disabled in Settings turns it off.
    var hapticsEnabled: Bool = true
    /// When true, dims the visual chrome heavily so the haptic carries the ritual
    /// and the screen is a glance-target, not a focus-target.
    var eyesUp: Bool = false
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date = .now
    @State private var hasCompleted = false
    @State private var haptics = HapticEngine()
    @State private var activityController = BreathActivityController()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let remaining = max(0, durationSeconds - elapsed)
            let phase = currentPhase(at: elapsed)
            let progress = haloProgress(at: elapsed, phase: phase)

            ZStack {
                VStack(spacing: 24) {
                    Spacer()

                    Text(label(for: phase))
                        .font(PulseType.display(48))
                        .foregroundStyle(Theme.inkPrimary)
                        .opacity(eyesUp ? 0.45 : 1.0)
                        .contentTransition(.opacity)
                        .accessibilityLabel(voice(for: phase))
                        .accessibilityAddTraits(.updatesFrequently)
                        .padding(.bottom, -8)

                    Text(secondsInPhaseText(at: elapsed, phase: phase))
                        .font(PulseType.body(15))
                        .foregroundStyle(Theme.inkTertiary)
                        .opacity(eyesUp ? 0 : 1)
                        .monospacedDigit()
                        .accessibilityHidden(true)

                    BreathingHalo(progress: progress, emphasized: phase == .holdFull, mood: mood)
                        .opacity(eyesUp ? 0.30 : 1.0)
                        .padding(.vertical, 12)

                    Spacer()

                    timeRow(remaining: remaining)
                        .opacity(eyesUp ? 0 : 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

                VStack {
                    HStack {
                        Spacer()
                        Button("Stop") {
                            triggerComplete()
                        }
                        .font(PulseType.headline(15))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.cardFill))
                        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
                        .opacity(eyesUp ? 0.45 : 1.0)
                        .accessibilityHint("Ends the breathing session early")
                    }
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
            }
            .onChange(of: remaining <= 0) { _, finished in
                if finished { triggerComplete() }
            }
        }
        .onAppear {
            startedAt = .now
            UIApplication.shared.isIdleTimerDisabled = true
            if hapticsEnabled {
                let cycles = max(1, Int(ceil(durationSeconds / max(pattern.cycleDuration, 1))))
                haptics.playBreathSequence(pattern: pattern, cycleCount: cycles)
            }
            activityController.start(
                eventTitle: eventTitle,
                patternName: pattern.name,
                totalSeconds: durationSeconds
            )
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            haptics.stop()
            activityController.end()
        }
        .task {
            // Drive the Live Activity at 1 Hz, independent of the visual TimelineView's
            // 30 Hz render. ActivityKit budgets these updates, so a per-frame push would
            // burn the quota fast.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let elapsed = max(0, Date.now.timeIntervalSince(startedAt))
                let remaining = max(0, durationSeconds - elapsed)
                if remaining <= 0 { break }
                let phase = currentPhase(at: elapsed)
                activityController.update(
                    phase: activityPhase(from: phase),
                    progress: 1 - (remaining / durationSeconds),
                    secondsRemaining: Int(ceil(remaining))
                )
            }
        }
        .dynamicTypeSize(.large ... .accessibility2)
    }

    private func activityPhase(from local: Phase) -> BreathLiveActivityAttributes.ContentState.Phase {
        switch local {
        case .inhale:    return .inhale
        case .holdFull:  return .holdFull
        case .exhale:    return .exhale
        case .holdEmpty: return .holdEmpty
        }
    }

    // MARK: - Phase math

    /// Walks the cycle in order (inhale → holdFull → exhale → holdEmpty), skipping zero-duration phases.
    private func currentPhase(at elapsed: Double) -> Phase {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return .inhale }
        let inCycle = elapsed.truncatingRemainder(dividingBy: cycle)

        var cumulative: Double = 0
        cumulative += pattern.inhale
        if pattern.inhale > 0 && inCycle < cumulative { return .inhale }
        cumulative += pattern.holdFull
        if pattern.holdFull > 0 && inCycle < cumulative { return .holdFull }
        cumulative += pattern.exhale
        if pattern.exhale > 0 && inCycle < cumulative { return .exhale }
        return .holdEmpty
    }

    private func phaseStart(for phase: Phase) -> Double {
        switch phase {
        case .inhale:    return 0
        case .holdFull:  return pattern.inhale
        case .exhale:    return pattern.inhale + pattern.holdFull
        case .holdEmpty: return pattern.inhale + pattern.holdFull + pattern.exhale
        }
    }

    private func duration(for phase: Phase) -> Double {
        switch phase {
        case .inhale:    return pattern.inhale
        case .holdFull:  return pattern.holdFull
        case .exhale:    return pattern.exhale
        case .holdEmpty: return pattern.holdEmpty
        }
    }

    private func haloProgress(at elapsed: Double, phase: Phase) -> Double {
        if reduceMotion {
            switch phase {
            case .inhale, .holdFull: return 1
            case .exhale, .holdEmpty: return 0.3
            }
        }
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return 0 }
        let inCycle = elapsed.truncatingRemainder(dividingBy: cycle)
        let phaseLen = duration(for: phase)
        guard phaseLen > 0 else {
            return (phase == .inhale || phase == .holdFull) ? 1 : 0
        }
        let inPhase = (inCycle - phaseStart(for: phase)) / phaseLen

        switch phase {
        case .inhale:    return min(1, max(0, inPhase))
        case .holdFull:  return 1
        case .exhale:    return min(1, max(0, 1 - inPhase))
        case .holdEmpty: return 0
        }
    }

    // MARK: - Labels (from pattern)

    private func label(for phase: Phase) -> String {
        switch phase {
        case .inhale:    return pattern.inhaleLabel
        case .holdFull:  return pattern.holdFullLabel ?? pattern.inhaleLabel
        case .exhale:    return pattern.exhaleLabel
        case .holdEmpty: return pattern.holdEmptyLabel ?? pattern.exhaleLabel
        }
    }

    private func voice(for phase: Phase) -> String {
        switch phase {
        case .inhale:    return pattern.inhaleVoice
        case .holdFull:  return pattern.holdFullVoice ?? pattern.inhaleVoice
        case .exhale:    return pattern.exhaleVoice
        case .holdEmpty: return pattern.holdEmptyVoice ?? pattern.exhaleVoice
        }
    }

    private func secondsInPhaseText(at elapsed: Double, phase: Phase) -> String {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return "0" }
        let inCycle = elapsed.truncatingRemainder(dividingBy: cycle)
        let inPhase = inCycle - phaseStart(for: phase)
        let phaseLen = duration(for: phase)
        let remaining = max(0, Int(ceil(phaseLen - inPhase)))
        return "\(remaining)"
    }

    // MARK: - Bottom row

    private func timeRow(remaining: Double) -> some View {
        let total = durationSeconds
        let progress = 1 - (remaining / total)
        return VStack(spacing: 6) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Theme.warmA)
                .frame(maxWidth: 220)
            Text(formattedRemaining(remaining))
                .font(PulseType.caption(13))
                .foregroundStyle(Theme.inkTertiary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(Int(remaining)) seconds, \(Int(progress * 100)) percent complete")
    }

    private func formattedRemaining(_ remaining: Double) -> String {
        let secs = Int(ceil(remaining))
        if secs <= 60 { return "\(secs)s" }
        let m = secs / 60
        let s = secs % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private func triggerComplete() {
        guard hasCompleted == false else { return }
        hasCompleted = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        AccessibilityNotification.Announcement("Sixty seconds complete. You're ready.").post()
        onComplete()
    }
}

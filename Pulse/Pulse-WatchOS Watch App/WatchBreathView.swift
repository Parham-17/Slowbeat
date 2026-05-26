import SwiftUI
import WatchKit

/// Haptic-led breath ritual on the wrist.
///
/// Layout — phase label / mood-tinted halo / horizontal `ProgressView` filling
/// across 60 s. The X button lives in the toolbar's `.cancellationAction`
/// slot so it aligns with the system back-chevron position on every other
/// pushed view.
///
/// Two callbacks split the exit paths cleanly so the parent state machine in
/// `WatchRitualFlow` can route the user:
///   • `onCancel` — user tapped X. No session is shipped. Close the ritual.
///   • `onComplete` — the 60-second timer reached 0. A `BreathingSession`
///     has been shipped to the phone via WatchConnectivity. Show the summary.
///
/// This view no longer pushes its own summary destination — that nested
/// `.navigationDestination(isPresented:)` was the source of an observation
/// tracking feedback loop on watchOS (the navigation bar invalidated
/// repeatedly while the parent state was also trying to transition).
struct WatchBreathView: View {
    enum Phase: Int {
        case inhale, holdFull, exhale, holdEmpty
    }

    var pattern: BreathingPattern = .box
    var eventTitle: String?
    var mood: WatchPreMood?
    var hapticsEnabled: Bool = true
    var eyesUp: Bool = false
    var onCancel: () -> Void
    var onComplete: () -> Void

    private let totalSeconds: Double = 60

    @State private var startedAt: Date?
    @State private var hasCompleted = false
    @State private var haptics = HapticEngine()
    /// Keeps the display lit for the full 60s. watchOS's default wake duration
    /// is shorter than the breath, so without this the screen dims before the
    /// session ends and the user loses the phase cues.
    @State private var awake = WatchAwakeSession()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { mood?.tint ?? WatchTheme.lavender }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let elapsed = startedAt.map { max(0, timeline.date.timeIntervalSince($0)) } ?? 0
            let remaining = max(0, totalSeconds - elapsed)
            let phase = currentPhase(at: elapsed)
            let haloProgress = haloProgress(at: elapsed, phase: phase)
            let sessionProgress = min(1, elapsed / totalSeconds)

            VStack(spacing: 10) {
                Text(label(for: phase))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                    .opacity(eyesUp ? 0.40 : 1.0)

                WatchBreathingHalo(
                    progress: haloProgress,
                    emphasized: phase == .holdFull,
                    mood: mood,
                    size: 100
                )
                .opacity(eyesUp ? 0.45 : 1.0)

                ProgressView(value: sessionProgress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(maxWidth: 140)
                    .opacity(eyesUp ? 0.30 : 1.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .onChange(of: remaining <= 0) { _, finished in
                if finished && startedAt != nil { triggerComplete() }
            }
        }
        // No `.navigationTitle` — the breath itself is the screen, the
        // halo + phase label tell the user what's happening, and a faded
        // word floating under the clock just adds noise.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    haptics.stop()
                    awake.stop()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Stop breathing session")
            }
        }
        .containerBackground(accent.gradient, for: .navigation)
        .onAppear {
            startedAt = .now
            // Keep the screen lit for the full 60s — see WatchAwakeSession.
            awake.start()
            if hapticsEnabled {
                let cycles = max(1, Int(ceil(totalSeconds / max(pattern.cycleDuration, 1))))
                haptics.playBreathSequence(pattern: pattern, cycleCount: cycles)
            }
        }
        .onDisappear {
            haptics.stop()
            // Belt-and-suspenders: if the view goes away for any reason the
            // explicit exit paths didn't catch (system back gesture, etc.),
            // release the extended runtime session.
            awake.stop()
        }
    }

    // MARK: - Phase + progress math

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

    /// 0..1 — the halo grows on the inhale, holds at the top, shrinks on the
    /// exhale, rests at the bottom. With reduce-motion, just snaps between
    /// two values.
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

    private func label(for phase: Phase) -> String {
        switch phase {
        case .inhale:    return pattern.inhaleLabel
        case .holdFull:  return pattern.holdFullLabel ?? pattern.inhaleLabel
        case .exhale:    return pattern.exhaleLabel
        case .holdEmpty: return pattern.holdEmptyLabel ?? pattern.exhaleLabel
        }
    }

    private func triggerComplete() {
        guard hasCompleted == false else { return }
        hasCompleted = true
        haptics.stop()
        awake.stop()
        WatchSyncService.shared.shipCompletedSession(
            startedAt: startedAt ?? .now,
            patternKey: pattern.key.rawValue,
            eventTitle: eventTitle,
            mood: mood
        )
        onComplete()
    }
}

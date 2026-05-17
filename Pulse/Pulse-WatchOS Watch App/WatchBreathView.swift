import SwiftUI
import WatchKit

/// Haptic-led breath ritual on the wrist. The thin progress arc fills clockwise
/// across the full 60 seconds, the centre shows the current phase label, and the
/// haptic engine carries the rhythm so the user can drop the wrist if they want.
///
/// On completion, ships a session record back to the iPhone via WatchConnectivity
/// so the moment lands in History — even if the phone is unreachable, the system
/// queues the transfer until it can be delivered.
struct WatchBreathView: View {
    var pattern: BreathingPattern = .box
    var eventTitle: String?
    var onComplete: () -> Void

    private let totalSeconds: Double = 60

    @State private var startedAt: Date = .now
    @State private var hasCompleted = false
    @State private var haptics = HapticEngine()

    private let accent = Color(red: 0.68, green: 0.66, blue: 0.88)
    private let track = Color.white.opacity(0.12)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let remaining = max(0, totalSeconds - elapsed)
            let progress = min(1, elapsed / totalSeconds)
            let phaseLabel = label(at: elapsed)

            ZStack {
                Circle()
                    .stroke(track, lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0 / 20.0), value: progress)

                VStack(spacing: 6) {
                    Text(phaseLabel)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.opacity)
                    Text("\(Int(ceil(remaining)))s")
                        .font(.system(.caption2, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .onChange(of: remaining <= 0) { _, finished in
                if finished { triggerComplete() }
            }
        }
        .onAppear {
            startedAt = .now
            let cycles = max(1, Int(ceil(totalSeconds / max(pattern.cycleDuration, 1))))
            haptics.playBreathSequence(pattern: pattern, cycleCount: cycles)
        }
        .onDisappear { haptics.stop() }
    }

    private func label(at elapsed: Double) -> String {
        let cycle = pattern.cycleDuration
        guard cycle > 0 else { return pattern.inhaleLabel }
        let inCycle = elapsed.truncatingRemainder(dividingBy: cycle)
        var c: Double = 0
        c += pattern.inhale
        if inCycle < c { return pattern.inhaleLabel }
        c += pattern.holdFull
        if inCycle < c { return pattern.holdFullLabel ?? pattern.inhaleLabel }
        c += pattern.exhale
        if inCycle < c { return pattern.exhaleLabel }
        return pattern.holdEmptyLabel ?? pattern.exhaleLabel
    }

    private func triggerComplete() {
        guard hasCompleted == false else { return }
        hasCompleted = true
        WKInterfaceDevice.current().play(.success)
        WatchSyncService.shared.shipCompletedSession(
            startedAt: startedAt,
            patternKey: pattern.key.rawValue,
            eventTitle: eventTitle
        )
        Task {
            try? await Task.sleep(for: .seconds(1))
            onComplete()
        }
    }
}

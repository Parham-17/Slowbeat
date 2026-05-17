import Foundation
import WatchKit
import Observation

/// Watch-side breath haptics. Plays WKInterfaceDevice haptics at each phase boundary —
/// `.start` at inhale, `.click` at the top of hold, `.stop` at exhale, silence at rest.
///
/// Coarser than the iPhone's CHHaptic rising/falling envelope (CoreHaptics's full engine
/// isn't exposed as a module on watchOS), but still phase-textured: the user can feel
/// where in the cycle they are without looking at the wrist. The visual progress arc
/// fills in the gaps for sighted users.
@Observable
@MainActor
final class HapticEngine {
    private var task: Task<Void, Never>?

    /// Plays `cycleCount` cycles of the pattern. Cancellable via `stop()`.
    func playBreathSequence(pattern: BreathingPattern, cycleCount: Int) {
        task?.cancel()
        task = Task { [pattern] in
            for _ in 0..<cycleCount {
                if Task.isCancelled { return }
                if pattern.inhale > 0 {
                    WKInterfaceDevice.current().play(.start)
                    try? await Task.sleep(for: .seconds(pattern.inhale))
                }
                if Task.isCancelled { return }
                if pattern.holdFull > 0 {
                    WKInterfaceDevice.current().play(.click)
                    try? await Task.sleep(for: .seconds(pattern.holdFull))
                }
                if Task.isCancelled { return }
                if pattern.exhale > 0 {
                    WKInterfaceDevice.current().play(.stop)
                    try? await Task.sleep(for: .seconds(pattern.exhale))
                }
                if Task.isCancelled { return }
                if pattern.holdEmpty > 0 {
                    try? await Task.sleep(for: .seconds(pattern.holdEmpty))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

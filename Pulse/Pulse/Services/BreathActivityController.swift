import Foundation
import ActivityKit
import Observation

/// Thin wrapper around ActivityKit that lets `BreathingView` push the current phase /
/// remaining-seconds to the Lock Screen and Dynamic Island. Fail-open: if Live
/// Activities are disabled at the OS level or the request fails, every method
/// silently no-ops and the in-app breath is unaffected.
@Observable
@MainActor
final class BreathActivityController {
    private var activity: Activity<BreathLiveActivityAttributes>?

    /// True when the OS allows new Live Activities. The user can disable this
    /// globally in Settings → Face ID & Passcode → Allow Access When Locked.
    var isAuthorized: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(
        eventTitle: String,
        patternName: String,
        totalSeconds: Double
    ) {
        guard isAuthorized, activity == nil else { return }
        let attributes = BreathLiveActivityAttributes(
            eventTitle: eventTitle,
            patternName: patternName,
            totalSeconds: totalSeconds,
            startedAt: .now
        )
        let initialState = BreathLiveActivityAttributes.ContentState(
            phase: .inhale,
            progress: 0,
            secondsRemaining: Int(totalSeconds)
        )
        // Stale date is the safety net: if the user kills the app mid-breath, onDisappear
        // never fires and we can't call end() — but ActivityKit will auto-dismiss the
        // activity after this date passes (plus a system grace window). Set to the moment
        // the breath would naturally have completed.
        let staleDate = Date.now.addingTimeInterval(totalSeconds + 10)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: staleDate)
            )
        } catch {
            activity = nil
        }
    }

    func update(
        phase: BreathLiveActivityAttributes.ContentState.Phase,
        progress: Double,
        secondsRemaining: Int
    ) {
        guard let activity else { return }
        let newState = BreathLiveActivityAttributes.ContentState(
            phase: phase,
            progress: progress,
            secondsRemaining: secondsRemaining
        )
        Task { await activity.update(.init(state: newState, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        let finalState = BreathLiveActivityAttributes.ContentState(
            phase: .done,
            progress: 1,
            secondsRemaining: 0
        )
        let current = activity
        self.activity = nil
        Task {
            await current.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    /// Sweep any breath activities left over from a previous app launch (e.g. the user
    /// killed the app mid-breath before staleDate kicked in). Called from AppState on
    /// bootstrap so a stale activity never persists across launches.
    static func endOrphanedActivities() async {
        for activity in Activity<BreathLiveActivityAttributes>.activities {
            let finalState = BreathLiveActivityAttributes.ContentState(
                phase: .done,
                progress: 1,
                secondsRemaining: 0
            )
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}

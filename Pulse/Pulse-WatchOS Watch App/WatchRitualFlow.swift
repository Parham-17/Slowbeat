import SwiftUI

/// The full breath ritual, hosted in a sheet. Three steps, swapped by a single
/// `@State step` enum rather than pushed via NavigationStack:
///
///   .moodPicker  ← user opens the ritual
///   .breath      ← after a mood pick (or skip)
///   .summary     ← after the 60s timer completes naturally
///
/// Why a sheet and not navigation: a NavigationStack with both `.navigationDestination(for:)`
/// (for the path) AND a nested `.navigationDestination(isPresented:)` (for the summary
/// inside the breath view) caused an observation tracking feedback loop on
/// watchOS — the navigation bar invalidated repeatedly because the parent
/// state was changing while the child was mid-transition. Direct view swap
/// inside a sheet has none of those edges.
///
/// `onClose` is called on every exit path (cancel from breath, Done from
/// summary, auto-dismiss after the summary's 6s timeout) and dismisses the
/// sheet back to the Now tab.
struct WatchRitualFlow: View {
    let sync: WatchSyncService
    var onClose: () -> Void

    @State private var step: Step = .moodPicker
    @State private var pickedMood: WatchPreMood?

    enum Step { case moodPicker, breath, summary }

    var body: some View {
        // Wrapping in a NavigationStack so child views' `.navigationTitle`,
        // `.toolbar`, and `.containerBackground(... for: .navigation)` work
        // — but the stack has NO `.navigationDestination`s, so the
        // feedback-loop conditions can't arise. Each step is just the
        // current root view.
        NavigationStack {
            currentStep
        }
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .moodPicker:
            WatchMoodPickerView { mood in
                pickedMood = mood
                step = .breath
            }
        case .breath:
            WatchBreathView(
                pattern: sync.pattern,
                // Only stamp a meeting title onto the session if the phone has
                // pushed a context within the freshness window. A watch that
                // hasn't synced in a day has cached titles from yesterday's
                // events — without this guard, those stale titles end up on
                // brand-new breaths in iPhone Moments ("Standup with Bob"
                // appearing on a breath the user did at the airport).
                eventTitle: sync.hasFreshContext
                    ? (sync.ongoingTitle ?? sync.nextEventTitle)
                    : nil,
                mood: pickedMood,
                hapticsEnabled: sync.hapticsEnabled,
                eyesUp: sync.eyesUpEnabled,
                onCancel: onClose,
                onComplete: { step = .summary }
            )
        case .summary:
            WatchRitualSummaryView(onClose: onClose)
        }
    }
}

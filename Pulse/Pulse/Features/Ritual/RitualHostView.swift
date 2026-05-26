import SwiftUI
import SwiftData

/// Owns the staged flow of a single "moment": intro → breathing → reflection → done.
/// The session is persisted at the end of breathing so it counts even if the user skips reflection.
struct RitualHostView: View {
    enum Stage { case intro, breathing, reflect, summary }

    let event: UpcomingEvent

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage = .intro
    @State private var session: BreathingSession?
    @State private var preMood: PreMood?

    @Query private var settingsRows: [PulseSettings]

    /// Currently-selected breathing pattern. Defaults to box if nothing is persisted.
    private var pattern: BreathingPattern {
        settingsRows.first?.breathingPattern ?? .box
    }

    var body: some View {
        ZStack {
            // Subtle inner glow that intensifies during breathing.
            // State-tinted to match the halo when the user reported a pre-mood.
            Theme.haloGradient(for: preMood)
                .opacity(stage == .breathing ? 0.55 : 0.20)
                .blur(radius: 80)
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.6), value: stage)

            switch stage {
            case .intro:
                RitualIntroView(event: event, preMood: $preMood) {
                    startBreathing()
                }
                .transition(stageTransition)
            case .breathing:
                BreathingView(
                    pattern: pattern,
                    durationSeconds: 60,
                    eventTitle: event.title,
                    mood: preMood,
                    hapticsEnabled: settingsRows.first?.haptics ?? true,
                    eyesUp: settingsRows.first?.eyesUp ?? false
                ) {
                    finishBreathing()
                }
                .transition(.opacity)
            case .reflect:
                IntentionView(session: session, event: event) {
                    advance(to: .summary)
                }
                .transition(stageTransition)
            case .summary:
                RitualSummaryView(session: session) {
                    app.endRitual()
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .pulseBackground()
        .navigationBarBackButtonHidden(stage != .intro)
        .toolbar {
            if stage == .intro {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        app.endRitual()
                        dismiss()
                    }
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private func startBreathing() {
        let s = BreathingSession(
            startedAt: .now,
            eventTitle: event.title,
            eventStartAt: event.start,
            eventCategory: event.suggestedCategory,
            preMood: preMood,
            breathingPatternRaw: pattern.key.rawValue
        )
        context.insert(s)
        session = s
        advance(to: .breathing)
    }

    private func finishBreathing() {
        session?.completedAt = .now
        PulseStorage.save(context, reason: "complete breath")
        if event.id.hasPrefix("manual-") {
            app.clearManualPlaceholder()
        }
        // Push the new session to the watch's Recent tab.
        let settings = app.ensureSettings(in: context)
        app.publishExternalSurfaces(settings: settings, modelContext: context)
        advance(to: .reflect)
    }

    private func advance(to next: Stage) {
        if reduceMotion {
            stage = next
        } else {
            withAnimation(.easeInOut(duration: 0.7)) { stage = next }
        }
    }

    private var stageTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))
    }
}

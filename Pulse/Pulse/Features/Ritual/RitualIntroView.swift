import SwiftUI

struct RitualIntroView: View {
    let event: UpcomingEvent
    @Binding var preMood: PreMood?
    var onBegin: () -> Void

    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                eventHeader
                heartContext
                moodPicker
                Spacer(minLength: 24)
                PulseButton(title: "Begin 60 seconds", systemImage: "wind", style: .warm) {
                    onBegin()
                }
                Text("A short pause. You can stop anytime.")
                    .font(PulseType.caption())
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: event.suggestedCategory.symbol)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(event.suggestedCategory.accent.opacity(0.85)))
                Text(event.suggestedCategory.displayName.uppercased())
                    .font(PulseType.caption(12))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Text(event.title)
                .font(PulseType.title(34))
                .foregroundStyle(Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(timeLine)
                .font(PulseType.body(16))
                .foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var timeLine: String {
        let minutes = event.minutesUntilStart
        if minutes <= 0 { return "Now" }
        if minutes < 60 { return "In \(minutes) minutes" }
        return event.start.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private var heartContext: some View {
        if app.health.hasFreshReading, let bpm = app.health.latestHeartRate {
            GlassCard(padding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.warmA)
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(bpm)) bpm")
                            .font(PulseType.headline())
                            .foregroundStyle(Theme.inkPrimary)
                        Text("Your most recent reading.")
                            .font(PulseType.caption())
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                }
            }
            .accessibilityLabel("Most recent heart rate \(Int(bpm)) beats per minute")
        }
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where are you right now?")
                .font(PulseType.headline(17))
                .foregroundStyle(Theme.inkPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(PreMood.allCases) { mood in
                    Button {
                        preMood = (preMood == mood) ? nil : mood
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mood.symbol)
                            Text(mood.label)
                        }
                        .font(PulseType.caption(14))
                        .foregroundStyle(preMood == mood ? .white : Theme.inkPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule()
                                .fill(preMood == mood ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Theme.cardFill))
                        )
                        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.label)
                    .accessibilityValue(preMood == mood ? "Selected" : "")
                    .accessibilityAddTraits(preMood == mood ? .isSelected : [])
                    .accessibilityHint(preMood == mood ? "Tap to clear this selection" : "Tap to mark this as where you are right now")
                }
            }
            Text("Optional — picking one tunes the halo color to where you are.")
                .font(PulseType.caption(12))
                .foregroundStyle(Theme.inkTertiary)
        }
    }
}

import SwiftUI

struct UpcomingEventCard: View {
    var event: UpcomingEvent
    var isFeatured: Bool = false
    var onBegin: () -> Void

    var body: some View {
        GlassCard(padding: isFeatured ? 24 : 18) {
            VStack(alignment: .leading, spacing: isFeatured ? 18 : 10) {
                HStack(spacing: 10) {
                    categoryBadge
                    Spacer(minLength: 0)
                    Text(relativeStart)
                        .font(PulseType.caption())
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityLabel("Starts \(relativeStart)")
                }

                Text(event.title)
                    .font(isFeatured ? PulseType.title(26) : PulseType.headline())
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(2)

                if let location = event.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(PulseType.caption())
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                }

                if isFeatured {
                    PulseButton(title: "Begin a moment", systemImage: "wind", style: .warm) {
                        onBegin()
                    }
                    .padding(.top, 4)
                } else {
                    Button(action: onBegin) {
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                            Text("Begin")
                        }
                        .font(PulseType.caption(14))
                        .foregroundStyle(Theme.inkPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Theme.cardFill))
                        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Begin a moment before \(event.title)")
                    .accessibilityHint("Starts a 60-second breathing check-in")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var categoryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: event.suggestedCategory.symbol)
            Text(event.suggestedCategory.displayName)
        }
        .font(PulseType.caption(12))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(event.suggestedCategory.accent.opacity(0.85)))
    }

    private var relativeStart: String {
        let minutes = event.minutesUntilStart
        if minutes < 1   { return "starting now" }
        if minutes < 60  { return "in \(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours < 24 {
            return mins == 0 ? "in \(hours) h" : "in \(hours) h \(mins) m"
        }
        return event.start.formatted(date: .abbreviated, time: .shortened)
    }
}

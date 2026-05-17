import SwiftUI
import SwiftData

struct EventTypesSection: View {
    let settings: PulseSettings
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    private var focusFilterActive: Bool { FocusFilterStore.read() != nil }

    var body: some View {
        SettingsSectionCard(title: "Watch for these") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Slowbeat will only nudge you before events that look like one of these.")
                    .font(PulseType.body(14))
                    .foregroundStyle(Theme.inkSecondary)

                if focusFilterActive {
                    Text("A Focus filter is overriding these right now. End that Focus to use your default selection.")
                        .font(PulseType.caption(12))
                        .foregroundStyle(Theme.coolA)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }

                FlowLayout(spacing: 8) {
                    ForEach(EventCategory.allCases) { category in
                        chip(for: category)
                    }
                }
            }
        }
    }

    private func chip(for category: EventCategory) -> some View {
        let selected = settings.monitoredCategories.contains(category)
        return Button {
            toggle(category)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.symbol)
                Text(category.displayName)
            }
            .font(PulseType.caption(13))
            .foregroundStyle(selected ? .white : Theme.inkPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? AnyShapeStyle(category.accent) : AnyShapeStyle(Theme.cardFill))
            )
            .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityValue(selected ? "On" : "Off")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "Tap to stop watching these events" : "Tap to start watching these events")
    }

    private func toggle(_ category: EventCategory) {
        var current = settings.monitoredCategories
        if current.contains(category) { current.remove(category) } else { current.insert(category) }
        settings.monitoredCategories = current
        PulseStorage.save(context, reason: "category toggled")
        Task {
            // Use effective categories so the loaded list reflects what's actually
            // applied — if a Focus filter is active the user's chip change persists
            // (in settings.monitoredCategories) but won't take visual effect until
            // the Focus ends.
            await app.calendar.loadUpcoming(monitoring: app.effectiveCategories(for: settings))
            if settings.notificationsEnabled {
                await app.notifier.reschedule(for: app.calendar.upcoming, minutesBefore: settings.reminderMinutesBefore)
            }
            app.publishExternalSurfaces(settings: settings)
        }
    }
}

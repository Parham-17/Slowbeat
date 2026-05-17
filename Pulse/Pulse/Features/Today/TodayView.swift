import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var settings: [PulseSettings]

    var body: some View {
        @Bindable var appBindable = app

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    heartLine
                    content
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(length, 560)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .refreshable { await refresh() }
            .pulseBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $appBindable.activeRitualEvent) { event in
                RitualHostView(event: event)
            }
            .task { await refresh() }
            .onChange(of: app.calendar.access) { _, newAccess in
                // Access flipped to granted (e.g. user just allowed it in Settings) —
                // reload so events appear without waiting for scenePhase to cycle.
                // Revocation is already handled: CalendarService clears `upcoming` and
                // the `content` switch automatically renders the permission gate.
                if newAccess == .granted {
                    Task { await refresh() }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(PulseType.title(32))
                .foregroundStyle(Theme.inkPrimary)
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default:      return "Hello, gently."
        }
    }

    // MARK: Heart context line

    @ViewBuilder
    private var heartLine: some View {
        if app.health.hasFreshReading, let bpm = app.health.latestHeartRate, let at = app.health.latestHeartRateAt {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Theme.warmA)
                Text("\(Int(bpm)) bpm")
                    .font(PulseType.headline(15))
                    .foregroundStyle(Theme.inkPrimary)
                Text("• \(relativeFromNow(at))")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.cardFill))
            .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
            .accessibilityLabel("Most recent heart rate \(Int(bpm)) beats per minute, \(relativeFromNow(at))")
        }
    }

    private func relativeFromNow(_ date: Date) -> String {
        let minutes = max(0, Int(Date.now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60) h ago"
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch app.calendar.access {
        case .granted:
            if app.calendar.upcoming.isEmpty {
                emptyState
            } else {
                eventList
            }
        case .denied, .restricted:
            permissionState(
                title: "Calendar is off",
                body: "Slowbeat needs calendar access to know when an important moment is approaching. You can turn it on anytime.",
                action: "Open Settings",
                onTap: openSystemSettings
            )
        case .unknown:
            permissionState(
                title: "Let Slowbeat see your calendar",
                body: "We use it only to suggest moments — events stay on your device.",
                action: "Allow calendar",
                onTap: requestCalendar
            )
        }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let next = app.calendar.upcoming.first {
                Text("Next up")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                UpcomingEventCard(event: next, isFeatured: true) {
                    app.startRitual(for: next)
                }
                .padding(.bottom, 4)
            }

            if app.calendar.upcoming.count > 1 {
                Text("Later")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                VStack(spacing: 12) {
                    ForEach(app.calendar.upcoming.dropFirst().prefix(8), id: \.id) { event in
                        UpcomingEventCard(event: event, isFeatured: false) {
                            app.startRitual(for: event)
                        }
                    }
                }
            }

            // Manual entry — for moments not on the calendar.
            Button {
                app.startRitual(for: app.manualMoment())
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                    Text("Start a moment without an event")
                }
                .font(PulseType.caption(14))
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Theme.cardFill.opacity(0.6)))
                .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 14) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.haloA)
                Text("Nothing pressing today.")
                    .font(PulseType.title(22))
                    .foregroundStyle(Theme.inkPrimary)
                    .multilineTextAlignment(.center)
                Text("When something important shows up on your calendar, it'll appear here.")
                    .font(PulseType.body(15))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                PulseButton(title: "Start a moment anyway", systemImage: "wind", style: .warm) {
                    app.startRitual(for: app.manualMoment())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func permissionState(title: String, body: String, action: String, onTap: @escaping () -> Void) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.haloA)
                Text(title)
                    .font(PulseType.title(22))
                    .foregroundStyle(Theme.inkPrimary)
                Text(body)
                    .font(PulseType.body(15))
                    .foregroundStyle(Theme.inkSecondary)
                PulseButton(title: action, style: .warm, action: onTap)
            }
        }
    }

    // MARK: Actions

    private func refresh() async {
        let s = app.ensureSettings(in: context)
        await app.calendar.loadUpcoming(monitoring: app.effectiveCategories(for: s))
        await app.health.loadLatest()
        if s.notificationsEnabled {
            await app.notifier.reschedule(for: app.calendar.upcoming, minutesBefore: s.reminderMinutesBefore)
        }
    }

    private func requestCalendar() {
        Task {
            _ = await app.calendar.requestAccess()
            await refresh()
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

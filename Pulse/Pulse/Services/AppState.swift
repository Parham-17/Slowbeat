import Foundation
import SwiftData
import SwiftUI
import Observation
import UserNotifications

/// Top-level coordinator. Owns the long-lived services and exposes a handful of intents
/// (refresh events, start a ritual, etc.) to the views.
@Observable
final class AppState {
    let calendar  = CalendarService()
    let notifier  = NotificationService()
    let watchSync = PhoneSyncService()

    /// The event currently being prepared for, if any.
    var activeRitualEvent: UpcomingEvent?

    /// Set by the notification delegate when the user taps a Pulse reminder.
    /// ContentView observes this and routes the user into the ritual for the event.
    /// Cleared by the consumer after handling.
    var pendingEventID: String?

    private var lastManualPlaceholder: UpcomingEvent?
    private var lastManualPlaceholderAt: Date?
    private let manualPlaceholderResumeWindow: TimeInterval = 300

    /// Retained here so iOS keeps the delegate alive. Registers itself as the
    /// UNUserNotificationCenter delegate on init.
    private let notificationDelegate = PulseNotificationDelegate()

    init() {
        notificationDelegate.appState = self
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    /// Loads settings (creating defaults on first run) and refreshes data.
    func bootstrap(modelContext: ModelContext) async {
        let settings = ensureSettings(in: modelContext)
        await refreshPermissions()
        await calendar.loadUpcoming(monitoring: effectiveCategories(for: settings))
        if settings.notificationsEnabled {
            await notifier.reschedule(
                for: calendar.upcoming,
                minutesBefore: settings.reminderMinutesBefore
            )
        }
        publishExternalSurfaces(settings: settings, modelContext: modelContext)
        // Drain any breath sessions the watch shipped over while we were closed.
        PhoneSyncService.drainSessionInbox(into: modelContext, settings: settings)
        // Republish so the freshly-drained sessions show up in the watch's Recent tab.
        publishExternalSurfaces(settings: settings, modelContext: modelContext)
        // Reactive drain: if the watch ships a session while the iPhone is in
        // the foreground, WCSession's delegate fires `didReceiveUserInfo` and
        // calls this closure on the main actor. Without it, the inbox would
        // sit untouched until the next scenePhase active transition and
        // History wouldn't refresh.
        watchSync.onUserInfoArrived = { [weak self] in
            guard let self else { return }
            let settings = self.ensureSettings(in: modelContext)
            PhoneSyncService.drainSessionInbox(into: modelContext, settings: settings)
            self.publishExternalSurfaces(settings: settings, modelContext: modelContext)
        }
        // End any breath Live Activities left over from a killed-mid-breath previous
        // run. Skip if a ritual is currently active — bootstrap fires on every
        // scenePhase active, and we don't want to kill the Live Activity for a breath
        // that's still in progress just because the user backgrounded and returned.
        if activeRitualEvent == nil {
            await BreathActivityController.endOrphanedActivities()
        }
    }

    /// Publishes the current next-event + ongoing-event + pattern + settings +
    /// recent sessions to both external surfaces (widget App Group + paired
    /// Apple Watch). Call after any change to calendar.upcoming, settings, or
    /// after a new session lands.
    func publishExternalSurfaces(settings: PulseSettings, modelContext: ModelContext) {
        publishWidgetSnapshot()
        let firstEvent = calendar.upcoming.first.map { event in
            WidgetSnapshot.Event(
                id: event.id,
                title: event.title,
                start: event.start,
                accentHex: event.suggestedCategory.accent.hexString(),
                categorySymbolName: event.suggestedCategory.symbol
            )
        }
        let ongoingEvent = calendar.ongoing.map { event in
            WidgetSnapshot.Event(
                id: event.id,
                title: event.title,
                start: event.start,
                accentHex: event.suggestedCategory.accent.hexString(),
                categorySymbolName: event.suggestedCategory.symbol
            )
        }
        let recent = recentSessions(in: modelContext)
        watchSync.publish(
            nextEvent:    firstEvent,
            ongoingEvent: ongoingEvent,
            ongoingEnd:   calendar.ongoing?.end,
            patternKey:   settings.breathingPattern.key.rawValue,
            haptics:      settings.haptics,
            eyesUp:       settings.eyesUp,
            recent:       recent
        )
    }

    /// Five most-recent completed sessions, newest first, as the wire-format DTO.
    private func recentSessions(in context: ModelContext) -> [RecentSessionDTO] {
        var descriptor = FetchDescriptor<BreathingSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        guard let sessions = try? context.fetch(descriptor) else { return [] }
        return sessions.map(RecentSessionDTO.init(session:))
    }

    /// The set of categories to filter the calendar against, honoring an active Focus
    /// filter if one was set via the iOS Focus configuration UI. When no filter is
    /// active, falls back to the user's persisted preference from PulseSettings.
    func effectiveCategories(for settings: PulseSettings) -> Set<EventCategory> {
        FocusFilterStore.read() ?? settings.monitoredCategories
    }

    /// Writes the current monitored-upcoming-events list to the App Group so the widget
    /// extension can render the next moments without re-fetching from EventKit (which it
    /// has no permission to do). Call this after any calendar load that the views care
    /// about — bootstrap covers the common path; EventTypesSection re-publishes after
    /// the user toggles which categories Pulse watches.
    func publishWidgetSnapshot() {
        let events = calendar.upcoming.prefix(8).map { event in
            WidgetSnapshot.Event(
                id: event.id,
                title: event.title,
                start: event.start,
                accentHex: event.suggestedCategory.accent.hexString(),
                categorySymbolName: event.suggestedCategory.symbol
            )
        }
        WidgetSnapshotStore.write(WidgetSnapshot(events: Array(events), generatedAt: .now))
    }

    /// Re-reads OS-level permission state so that toggles the user changed in iOS Settings
    /// while Pulse was backgrounded propagate before any data loads run. Without this,
    /// `notifier.access` would only update on the next process launch.
    private func refreshPermissions() async {
        calendar.refreshAccessStatus()
        await notifier.refreshAccessStatus()
    }

    func ensureSettings(in context: ModelContext) -> PulseSettings {
        let descriptor = FetchDescriptor<PulseSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = PulseSettings()
        context.insert(fresh)
        PulseStorage.save(context, reason: "create default settings")
        return fresh
    }

    func startRitual(for event: UpcomingEvent) {
        activeRitualEvent = event
    }

    func endRitual() {
        activeRitualEvent = nil
    }

    /// Returns the in-flight manual placeholder if it was created within the last 5 minutes,
    /// otherwise mints a new one. Lets a user who backed out of the intro and re-taps the
    /// "start a moment without an event" button resume the same placeholder rather than
    /// see the suggested time silently shift.
    func manualMoment() -> UpcomingEvent {
        if let last = lastManualPlaceholder,
           let at = lastManualPlaceholderAt,
           Date.now.timeIntervalSince(at) < manualPlaceholderResumeWindow {
            return last
        }
        let event = UpcomingEvent(
            id: "manual-\(UUID().uuidString)",
            // Time-of-day title (Morning breath / Evening breath / …) so a
            // Moments list of generic sessions isn't five identical rows.
            // See SessionTitle for the rationale on keeping the vocabulary
            // small.
            title: SessionTitle.generic(),
            start: .now.addingTimeInterval(60),
            end: .now.addingTimeInterval(60 * 30),
            suggestedCategory: .other,
            location: nil
        )
        lastManualPlaceholder = event
        lastManualPlaceholderAt = .now
        return event
    }

    /// Called from the summary screen when a manual moment has actually completed —
    /// don't reuse a placeholder the user already breathed through.
    func clearManualPlaceholder() {
        lastManualPlaceholder = nil
        lastManualPlaceholderAt = nil
    }
}

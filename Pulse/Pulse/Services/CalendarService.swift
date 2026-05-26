import Foundation
import EventKit
import Observation

@Observable
final class CalendarService {
    enum Access {
        case unknown, denied, restricted, granted
    }

    private let store = EKEventStore()
    var access: Access = .unknown
    var upcoming: [UpcomingEvent] = []
    /// The one calendar event the user is currently inside (start ≤ now < end).
    /// Lets the watch/widget surface a "happening now" badge without the user
    /// having to fish for context. Pulse never persists this — it's recomputed
    /// from EventKit on each `loadUpcoming` call.
    var ongoing: UpcomingEvent?

    private var storeObserver: NSObjectProtocol?

    init() {
        refreshAccessStatus()
        // External revocations or event edits (e.g. iPad split-view, user opens Settings
        // and turns calendar off) reach us through this notification — without it we'd
        // only catch the change on the next scenePhase active or app launch.
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // The observer queue is `.main`, so we are already on the main thread; the hop
            // is just to satisfy the Swift 6 isolation checker about MainActor-isolated state.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshAccessStatus()
                if self.access != .granted {
                    self.upcoming = []
                }
            }
        }
    }

    deinit {
        if let storeObserver { NotificationCenter.default.removeObserver(storeObserver) }
    }

    func refreshAccessStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly, .authorized: access = .granted
        case .denied:                                 access = .denied
        case .restricted:                             access = .restricted
        case .notDetermined:                          access = .unknown
        @unknown default:                             access = .unknown
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            refreshAccessStatus()
            return granted
        } catch {
            refreshAccessStatus()
            return false
        }
    }

    /// Pulls events between now and 48h ahead, filtering by the user's monitored categories
    /// (passed in so we don't reach back into SwiftData from here).
    ///
    /// Produces two outputs in one fetch:
    ///   • `upcoming` — future events (`start > now`), sorted earliest first
    ///   • `ongoing`  — the single event the user is currently inside (`start ≤ now < end`)
    func loadUpcoming(monitoring: Set<EventCategory>) async {
        refreshAccessStatus()
        guard access == .granted else {
            upcoming = []
            ongoing = nil
            return
        }
        let calendars = store.calendars(for: .event)
        let now = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 48, to: now) ?? now.addingTimeInterval(48 * 3600)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        // Map every event once into UpcomingEvent (with a flag for "is in progress")
        // so we can route them into the right bucket without double-walking.
        struct MappedEvent {
            let event: UpcomingEvent
            let isInProgress: Bool
        }

        let mapped: [MappedEvent] = events.compactMap { event in
            guard let title = event.title?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
            guard let start = event.startDate, let end = event.endDate else { return nil }
            guard event.isAllDay == false else { return nil }
            guard event.isDeclinedByCurrentUser == false else { return nil }

            let suggested = EventCategory.suggest(for: title)
            if monitoring.isEmpty == false, monitoring.contains(suggested) == false {
                return nil
            }
            let projection = UpcomingEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: title,
                start: start,
                end: end,
                suggestedCategory: suggested,
                location: event.location?.isEmpty == false ? event.location : nil
            )
            return MappedEvent(event: projection, isInProgress: start <= now && end > now)
        }

        // Ongoing: the earliest-started in-progress event (most relevant).
        ongoing = mapped
            .filter { $0.isInProgress }
            .sorted { $0.event.start < $1.event.start }
            .first?.event

        // Upcoming: future events, deduped.
        let future = mapped
            .filter { !$0.isInProgress }
            .map(\.event)
            .sorted { $0.start < $1.start }
        upcoming = Self.deduplicated(future)
    }

    /// Removes mirror duplicates — the same meeting appearing in multiple connected
    /// calendars (e.g. work Exchange + personal iCloud). Two events with the same title
    /// starting within one minute of each other are treated as the same moment; we keep
    /// the first one (which by sort order is the earliest start).
    private static func deduplicated(_ events: [UpcomingEvent]) -> [UpcomingEvent] {
        var seen: [String: Date] = [:]
        var result: [UpcomingEvent] = []
        for event in events {
            let key = event.title.lowercased()
            if let prior = seen[key], abs(event.start.timeIntervalSince(prior)) < 60 {
                continue
            }
            seen[key] = event.start
            result.append(event)
        }
        return result
    }
}

private extension EKEvent {
    /// True when an attendee marked `isCurrentUser` has `participantStatus == .declined`.
    /// EventKit doesn't expose a top-level "did I decline this" property, so we have to
    /// walk attendees. Events with no attendees (single-user calendars) are never declined.
    var isDeclinedByCurrentUser: Bool {
        guard let attendees, attendees.isEmpty == false else { return false }
        return attendees.contains { $0.isCurrentUser && $0.participantStatus == .declined }
    }
}

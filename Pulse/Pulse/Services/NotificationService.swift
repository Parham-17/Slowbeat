import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationService {
    enum Access {
        case unknown, denied, granted, provisional
    }

    var access: Access = .unknown

    private let center = UNUserNotificationCenter.current()
    private let prefix = "pulse.event."

    init() { Task { await refreshAccessStatus() } }

    func refreshAccessStatus() async {
        let settings = await center.notificationSettings()
        access = switch settings.authorizationStatus {
        case .authorized:    .granted
        case .provisional:   .provisional
        case .denied:        .denied
        default:             .unknown
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAccessStatus()
            return granted
        } catch {
            await refreshAccessStatus()
            return false
        }
    }

    /// Cancels any previously scheduled Pulse reminders and replaces them with new ones for `events`.
    func reschedule(for events: [UpcomingEvent], minutesBefore: Int) async {
        let existing = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier))

        for event in events {
            guard let fire = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: event.start),
                  fire > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title  = "A moment, before \(event.title)"
            content.body   = "Take 60 seconds to settle."
            content.sound  = .default
            content.userInfo = ["eventId": event.id]

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fire
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(
                identifier: prefix + event.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(req)
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
    }
}

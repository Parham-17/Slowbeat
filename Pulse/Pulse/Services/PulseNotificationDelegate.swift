import Foundation
import UserNotifications

/// Routes notification taps back into AppState so ContentView can deep-link the user
/// straight into the ritual for the event the notification was for. Kept as a small
/// NSObject so AppState itself doesn't need NSObject inheritance.
@MainActor
final class PulseNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Weak so the delegate doesn't keep AppState alive past its natural lifetime.
    weak var appState: AppState?

    /// Show the banner / play the sound even when the app is foregrounded — the user
    /// scheduled a reminder, they should see it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// User tapped the notification. Pull the event ID out of userInfo and stash it
    /// on AppState — ContentView observes pendingEventID and handles the navigation.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let eventId = response.notification.request.content.userInfo["eventId"] as? String
        completionHandler()
        if let id = eventId {
            Task { @MainActor in
                self.appState?.pendingEventID = id
            }
        }
    }
}

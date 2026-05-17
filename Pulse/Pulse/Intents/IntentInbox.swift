import Foundation

/// Tiny UserDefaults-backed mailbox for AppIntent → ContentView communication.
///
/// AppIntents run outside the SwiftUI view tree and can fire when the app is cold,
/// foregrounded, or backgrounded. NotificationCenter doesn't survive a cold launch.
/// A flag here is read on every scenePhase active and on the first ContentView task,
/// so the requested action runs regardless of launch state.
enum IntentInbox {
    nonisolated private static let key = "pulse.intent.startManualBreath"

    // nonisolated because AppIntent.perform() is nonisolated and UserDefaults is
    // thread-safe. The default project actor-isolation would otherwise force a hop.
    nonisolated static func requestManualBreath() {
        UserDefaults.standard.set(true, forKey: key)
    }

    /// Returns true once if a request is pending, and clears it. Idempotent — calling
    /// twice in a row returns false the second time.
    nonisolated static func consumeManualBreathRequest() -> Bool {
        guard UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }
}

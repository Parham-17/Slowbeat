import Foundation

/// App Group identifier shared between the main Pulse app and the Pulse Widget extension.
///
/// IMPORTANT: this string MUST match the App Group capability registered on both
/// targets (Project → target → Signing & Capabilities → App Groups) AND the App Group
/// you registered on the Apple Developer portal. If those don't match, the widget will
/// silently read an empty snapshot.
enum AppGroup {
    static let identifier = "group.com.parhamkarbasi.Slowbeat"

    /// Suite-scoped UserDefaults used to ship the next-event snapshot across the process
    /// boundary. Falls back to `.standard` if the group isn't actually wired up, so the
    /// main app keeps working (the widget will just stay on its placeholder).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

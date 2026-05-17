import Foundation

/// MIRROR of `Pulse/Services/WidgetSnapshot.swift` in the main app. Both copies must hold
/// identical Codable shapes — the widget can't import main-app modules, so the only
/// contract between them is the JSON written into App Group UserDefaults.
struct WidgetSnapshot: Codable, Equatable {
    struct Event: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var start: Date
        var accentHex: String
        var categorySymbolName: String
    }

    var events: [Event]
    var generatedAt: Date

    static let empty = WidgetSnapshot(events: [], generatedAt: .distantPast)

    /// First event whose start time is strictly in the future relative to `now`.
    /// Mirrors the main app's `start > now` filter so widget and Today screen agree.
    func nextEvent(after now: Date = .now) -> Event? {
        events.first { $0.start > now }
    }
}

/// App Group identifier — MUST match the constant in the main app's `AppGroup.swift`
/// and the App Group capability registered on both targets.
enum AppGroup {
    static let identifier = "group.com.parhamkarbasi.Slowbeat"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Read-side store. The widget never writes; the main app owns publication.
enum WidgetSnapshotStore {
    private static let key = "pulse.widget.snapshot.v1"

    static func read() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? .empty
    }
}

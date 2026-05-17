import Foundation

/// Tiny payload the main app writes for the widget to read. Deliberately Codable + value-
/// typed so it survives the App Group boundary cleanly, and so the widget extension can
/// hold an identical (mirrored) definition without depending on the main app's modules.
///
/// MIRRORED in `Pulse Widget/WidgetSnapshot.swift` — both copies must stay in lock-step
/// with the JSON shape. Don't add fields without updating both sides.
struct WidgetSnapshot: Codable, Equatable {
    struct Event: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var start: Date
        /// Hex string ("RRGGBB", no #) of the category accent so the widget can render
        /// the tint without needing the EventCategory enum from the main app.
        var accentHex: String
        var categorySymbolName: String
    }

    var events: [Event]
    var generatedAt: Date

    static let empty = WidgetSnapshot(events: [], generatedAt: .distantPast)
}

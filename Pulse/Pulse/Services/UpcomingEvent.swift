import Foundation

/// A privacy-respecting projection of a calendar event.
/// We never persist the underlying EKEvent — only what's needed for the ritual moment.
struct UpcomingEvent: Identifiable, Hashable {
    var id: String           // EKEvent.eventIdentifier
    var title: String
    var start: Date
    var end: Date
    var suggestedCategory: EventCategory
    var location: String?
    var minutesUntilStart: Int { Int(start.timeIntervalSinceNow / 60) }
}

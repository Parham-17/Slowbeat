import Foundation

/// Short, calm titles for sessions that have no calendar event attached
/// (manual moments, wrist breaths with no fresh context). Keyed to time of
/// day so a Moments list of five generic sessions reads as a varied,
/// honest record — "Morning breath", "Evening breath" — instead of five
/// identical "A moment for you" entries.
///
/// Deliberately small vocabulary (five labels). Adding random poetic
/// flourishes would conflict with Pulse's calm/minimal voice and risk
/// reading as twee after the tenth session. Time-of-day gives natural
/// variety without that cost.
enum SessionTitle {
    /// Returns a generic title appropriate for a session that started at
    /// `date`. Boundaries are intentionally human (morning ends around noon,
    /// late starts when most people are winding down) rather than aligned
    /// to any calendar quartile.
    static func generic(for date: Date = .now, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:  return "Morning breath"
        case 11..<14: return "Midday pause"
        case 14..<17: return "Afternoon reset"
        case 17..<21: return "Evening breath"
        default:      return "Late breath"
        }
    }
}

import Foundation

/// MIRROR of `Pulse/Services/SessionTitle.swift`. Must stay shape-aligned with
/// the iPhone version so a wrist session optimistically prepended to the
/// watch's local Recent list reads the same as the canonical row the phone
/// republishes back.
///
/// Generic titles for sessions that have no calendar context — keyed to the
/// breath's start time so adjacent moments don't all read identically.
enum SessionTitle {
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

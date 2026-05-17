import SwiftUI

enum EventCategory: String, CaseIterable, Identifiable, Codable {
    case presentation
    case interview
    case exam
    case meeting
    case conversation
    case performance
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .presentation: "Presentation"
        case .interview:    "Interview"
        case .exam:         "Exam"
        case .meeting:      "Meeting"
        case .conversation: "Difficult talk"
        case .performance:  "Performance"
        case .other:        "Other"
        }
    }

    var symbol: String {
        switch self {
        case .presentation: "rectangle.on.rectangle.angled"
        case .interview:    "person.line.dotted.person"
        case .exam:         "pencil.and.scribble"
        case .meeting:      "bubble.left.and.bubble.right"
        case .conversation: "ear.and.waveform"
        case .performance:  "music.mic"
        case .other:        "sparkles"
        }
    }

    // Accent colors — calibrated for analogous harmony in the cool arc of the color wheel
    // (roughly 130° to 290° on the HSL wheel). All low-to-medium saturation.
    // Saturation drives physiological arousal more than hue does (Wilms & Oberfeld 2018),
    // so previously warm/saturated accents (coral, peach, pink) were shifted toward
    // desaturated cool/neutral equivalents while keeping enough hue separation to remain
    // distinguishable at a glance.
    var accent: Color {
        switch self {
        case .presentation: Color(red: 0.62, green: 0.78, blue: 0.66)   // soft sage   (~130°)
        case .exam:         Color(red: 0.55, green: 0.80, blue: 0.78)   // dusty teal  (~175°)
        case .meeting:      Color(red: 0.58, green: 0.74, blue: 0.92)   // cornflower  (~210°)
        case .interview:    Color(red: 0.72, green: 0.66, blue: 0.90)   // soft lilac  (~250°)
        case .performance:  Color(red: 0.68, green: 0.60, blue: 0.86)   // soft plum   (~265°)
        case .other:        Color(red: 0.78, green: 0.74, blue: 0.90)   // pale lavender (~270°)
        case .conversation: Color(red: 0.82, green: 0.70, blue: 0.86)   // dusty mauve (~290°)
        }
    }

    /// Default keyword hints used to suggest a category from a calendar event title.
    var keywords: [String] {
        switch self {
        case .presentation: ["present", "demo", "pitch", "talk", "keynote"]
        case .interview:    ["interview", "screen", "loop"]
        case .exam:         ["exam", "test", "quiz", "midterm", "final"]
        case .meeting:      ["meeting", "1:1", "sync", "review", "standup"]
        case .conversation: ["1:1", "feedback", "difficult", "performance review"]
        case .performance:  ["recital", "performance", "show", "concert", "audition"]
        case .other:        []
        }
    }

    static func suggest(for title: String) -> EventCategory {
        let lower = title.lowercased()
        for category in EventCategory.allCases where category != .other {
            if category.keywords.contains(where: lower.contains) { return category }
        }
        return .other
    }
}

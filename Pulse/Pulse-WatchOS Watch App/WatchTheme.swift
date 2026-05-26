import SwiftUI

/// Palette for the watch app, kept minimal and HIG-aligned.
///
/// watchOS 10+ wants per-page tinted backgrounds applied via `containerBackground`,
/// not a global `.background()` on the root. The colors here are designed to be
/// used as `.gradient` shape styles in that modifier — they then animate during
/// page transitions, follow the system "rich background" look, and let the rest
/// of the UI default to system text styles and tints.
enum WatchTheme {

    // MARK: Brand accents
    //
    // Same hues as the iPhone `Theme` (calibrated for the calm cool-arc palette
    // in `project_color_evidence.md`). They're the source for both:
    //   • container background gradients (per tab)
    //   • the breathing halo gradient
    //   • the .tint() the rest of the controls inherit
    static let lavender   = Color(red: 0.68, green: 0.66, blue: 0.88)
    static let periwinkle = Color(red: 0.62, green: 0.74, blue: 0.92)
    static let teal       = Color(red: 0.50, green: 0.80, blue: 0.78)
    static let rose       = Color(red: 0.96, green: 0.72, blue: 0.72)
    static let indigo     = Color(red: 0.42, green: 0.50, blue: 0.80)
    static let slate      = Color(red: 0.30, green: 0.32, blue: 0.46)

    // MARK: Halo gradient
    //
    // Slightly tighter `endRadius` than the phone halo because the watch orb is
    // half the diameter. Same gradient stops so the visual reads continuous
    // between devices.
    static func haloGradient(for mood: WatchPreMood?) -> RadialGradient {
        let (a, b): (Color, Color)
        switch mood {
        case .anxious:   (a, b) = (indigo,    Color(red: 0.58, green: 0.66, blue: 0.90))
        case .energized: (a, b) = (Color(red: 0.38, green: 0.72, blue: 0.78), teal)
        case .flat:      (a, b) = (rose,      Color(red: 0.98, green: 0.85, blue: 0.78))
        case .settled, .none:
            (a, b) = (Color(red: 0.75, green: 0.70, blue: 0.98),
                      Color(red: 0.92, green: 0.82, blue: 0.96))
        }
        return RadialGradient(
            colors: [a.opacity(0.92), b.opacity(0.65), b.opacity(0.0)],
            center: .center,
            startRadius: 2,
            endRadius: 70
        )
    }

    /// Base tint color for a given mood — feeds `.tint()` and the container
    /// background gradient on the Now tab.
    static func accent(for mood: WatchPreMood?) -> Color {
        switch mood {
        case .anxious:   return indigo
        case .energized: return teal
        case .flat:      return rose
        case .settled, .none: return lavender
        }
    }
}

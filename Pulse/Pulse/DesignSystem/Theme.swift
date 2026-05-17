import SwiftUI
import UIKit

/// Single source of truth for Pulse's visual language.
/// Dark-first, calm gradient palette. Each color works in both schemes via the asset-less `Color(light:dark:)` initializer.
enum Theme {

    // MARK: Surface
    static let bgTop      = Color(light: Color(red: 0.98, green: 0.96, blue: 0.99),
                                   dark:  Color(red: 0.04, green: 0.05, blue: 0.14))
    static let bgBottom   = Color(light: Color(red: 0.92, green: 0.91, blue: 0.97),
                                   dark:  Color(red: 0.10, green: 0.07, blue: 0.22))
    static let bgAccent   = Color(light: Color(red: 0.88, green: 0.84, blue: 0.96),
                                   dark:  Color(red: 0.17, green: 0.10, blue: 0.30))

    // MARK: Ink (text)
    static let inkPrimary   = Color(light: Color(red: 0.10, green: 0.09, blue: 0.18),
                                     dark:  Color(red: 0.96, green: 0.96, blue: 0.99))
    static let inkSecondary = Color(light: Color(red: 0.36, green: 0.34, blue: 0.46),
                                     dark:  Color(red: 0.78, green: 0.76, blue: 0.88))
    // Darkened in light mode to pass WCAG AA on small-size text (was 0.56,0.54,0.64 ≈ 3.0:1).
    static let inkTertiary  = Color(light: Color(red: 0.40, green: 0.38, blue: 0.48),
                                     dark:  Color(red: 0.62, green: 0.60, blue: 0.74))

    // MARK: Glass card
    static let cardFill   = Color(light: Color.white.opacity(0.78),
                                   dark:  Color.white.opacity(0.08))
    static let cardStroke = Color(light: Color.black.opacity(0.06),
                                   dark:  Color.white.opacity(0.12))

    // MARK: Accents
    //
    // Palette is calibrated from the color-psychology literature: saturation drives
    // physiological arousal more strongly than hue (Wilms & Oberfeld 2018; Royal Society
    // Open Science 2023), cool hues lower arousal vs. warm, and pure red is uniquely
    // arousing (Elliot 2007). All accent colors are deliberately low-to-medium saturation.
    // Names are kept as warmA/warmB/etc. to avoid invasive renames, but the gradient
    // now reads "soft lavender → periwinkle" instead of "coral → amber."

    /// Primary-action gradient — soft lavender → periwinkle.
    /// Replaces the previous warm coral/amber, which had the highest saturation in the
    /// palette and was incongruent with a calming pre-event app.
    static let warmA = Color(red: 0.68, green: 0.66, blue: 0.88)
    static let warmB = Color(red: 0.62, green: 0.74, blue: 0.92)

    /// Completion gradient — soft teal → mint. Cool, low saturation, evidence-aligned.
    static let coolA = Color(red: 0.50, green: 0.80, blue: 0.78)
    static let coolB = Color(red: 0.62, green: 0.88, blue: 0.84)

    /// Breathing halo — soft lavender → blush. Cool-leaning, low-luminance friendly.
    /// This is the base / "settled" halo; state-contingent variants (haloAnxious,
    /// haloEnergized, haloFlat) below modulate saturation along iso-principle lines.
    static let haloA = Color(red: 0.75, green: 0.70, blue: 0.98)
    static let haloB = Color(red: 0.92, green: 0.82, blue: 0.96)

    // MARK: State-contingent halo variants
    //
    // Each variant lives in a clearly different hue zone of the cool/calm arc so the
    // four states are visually distinguishable through the heavy blur of the halo
    // rendering. Pure saturation-only shifts were not enough — they read as the same
    // color on screen. We still keep saturation low across all variants (so none of
    // them is "arousing" — Wilms & Oberfeld 2018), but we spread the hues across
    // ~150° of the color wheel for visible distinction.

    /// Anxious (HA-NV): deep indigo-blue. The most calming variant — pulls the eye
    /// toward "night sky" tones. Strongest down-regulation for high arousal.
    static let haloAnxiousA = Color(red: 0.42, green: 0.50, blue: 0.80)
    static let haloAnxiousB = Color(red: 0.58, green: 0.66, blue: 0.90)

    /// Energized (HA-PV): cool blue-teal. Focused, fresh, holds attention without
    /// arousing. Distinct from anxious by being more green-leaning.
    static let haloEnergizedA = Color(red: 0.38, green: 0.72, blue: 0.78)
    static let haloEnergizedB = Color(red: 0.58, green: 0.84, blue: 0.86)

    /// Flat (LA-NV): warm rose-peach. The single intentional warm spot in the app,
    /// reserved for the one state that benefits from gentle uplift (iso-principle /
    /// CBT mood-repair). NOT pink (Baker-Miller is debunked) and NOT high saturation —
    /// this is a soft sunset-rose, kept desaturated.
    static let haloFlatA = Color(red: 0.96, green: 0.72, blue: 0.72)
    static let haloFlatB = Color(red: 0.98, green: 0.85, blue: 0.78)

    /// Returns the halo gradient tuned for a given pre-mood (nil or settled → base).
    /// Gradient opacities (0.92 / 0.65 / 0.0) are tuned to preserve color through
    /// the multi-layer blur in BreathingHalo.
    static func haloGradient(for mood: PreMood?) -> RadialGradient {
        let (a, b): (Color, Color)
        switch mood {
        case .anxious:   (a, b) = (haloAnxiousA,   haloAnxiousB)
        case .energized: (a, b) = (haloEnergizedA, haloEnergizedB)
        case .flat:      (a, b) = (haloFlatA,      haloFlatB)
        case .settled, .none: (a, b) = (haloA,     haloB)
        }
        return RadialGradient(
            colors: [a.opacity(0.92), b.opacity(0.65), b.opacity(0.0)],
            center: .center,
            startRadius: 4,
            endRadius: 200
        )
    }

    // MARK: Gradients
    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [bgTop, bgBottom],
            startPoint: .topLeading,
            endPoint:   .bottomTrailing
        )
    }

    static let warmGradient = LinearGradient(colors: [warmA, warmB],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing)
    static let coolGradient = LinearGradient(colors: [coolA, coolB],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing)
    static let haloGradient = RadialGradient(colors: [haloA.opacity(0.85),
                                                       haloB.opacity(0.55),
                                                       haloB.opacity(0.0)],
                                              center: .center,
                                              startRadius: 4,
                                              endRadius: 200)
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

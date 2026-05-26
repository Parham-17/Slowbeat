import SwiftUI

/// Downscaled, watch-friendly version of the iPhone `BreathingHalo`. Same visual
/// language (lit sphere with diffuse aura and a pearl highlight), but trimmed for
/// the wrist's CPU/GPU budget:
///   • three layers instead of seven (aura → core → highlight)
///   • no rotating angular shimmer (most expensive on iPhone, drops frames on watch)
///   • no light-mode backplate (the watch is always rendered on the black bezel)
///   • TimelineView at 20 Hz instead of 30 Hz
///
/// `progress` follows the same convention as the phone — 0 = small / exhaled,
/// 1 = full / inhaled — so the same phase-math from `WatchBreathView` slots in.
struct WatchBreathingHalo: View {
    /// 0..1 — the current breath progress (0 = small, 1 = full).
    var progress: Double
    /// Top-of-hold emphasis: brightens the orb slightly and shows the inner ring.
    var emphasized: Bool = false
    /// Pre-breath state, if reported. Drives the gradient (lavender by default).
    var mood: WatchPreMood? = nil
    /// Outer diameter of the orb. Tuned for 44 mm by default; callers shrink for
    /// the home-tab miniature.
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let baseScale: CGFloat = reduceMotion ? 0.92 : 0.55
        let scale = baseScale + CGFloat(progress) * (reduceMotion ? 0.08 : 0.55)
        let opacity = 0.65 + (emphasized ? 0.20 : 0.10) * progress
        let gradient = WatchTheme.haloGradient(for: mood)

        ZStack {
            // 1. Outer aura — diffuse glow.
            Circle()
                .fill(gradient)
                .blur(radius: 16)
                .scaleEffect(scale + 0.22)
                .opacity(opacity * 0.40)

            // 2. Core sphere — keeps the body of the orb.
            Circle()
                .fill(gradient)
                .blur(radius: 1)
                .scaleEffect(scale)
                .opacity(min(1.0, opacity))

            // 3. Pearl highlight — fixed light spot. Offset scales with the sphere
            //    so the highlight follows the orb's effective radius.
            Circle()
                .fill(Color.white.opacity(0.22))
                .blur(radius: 5)
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(x: -size * 0.16 * scale, y: -size * 0.14 * scale)
                .scaleEffect(scale)

            // 4. Hold-emphasis ring — only during hold-full.
            if emphasized {
                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    .scaleEffect(scale * 0.86)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

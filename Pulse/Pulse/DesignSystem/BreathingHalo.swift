import SwiftUI

/// The breathing orb. Composited from a few soft layers so it reads as a 3D lit
/// sphere rather than a flat glowing disc — but tightened up from the first pass
/// so the orb has body, not a powdery diffusion.
///
/// Light mode gets two compensations the dark mode doesn't need: (1) blurs are
/// scaled down so edges stay crisper against the bright background, and (2) a
/// soft dark backplate goes behind everything to anchor the light halo colors
/// (Settled lavender / Flat rose) which would otherwise wash out.
struct BreathingHalo: View {
    /// 0..1 — the current breath progress (0 = small, 1 = full).
    var progress: Double
    /// Hint for opacity / inner-ring emphasis at the top of hold.
    var emphasized: Bool = false
    /// Pre-breath affective state, if reported. nil → base lavender palette.
    var mood: PreMood? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let shimmerAngle: Double = reduceMotion
                ? 0
                : (elapsed.truncatingRemainder(dividingBy: 180)) / 180 * 360

            let baseScale: CGFloat = reduceMotion ? 0.92 : 0.55
            let scale = baseScale + CGFloat(progress) * (reduceMotion ? 0.08 : 0.55)
            let opacity = 0.55 + (emphasized ? 0.22 : 0.10) * progress

            // Light-mode compensations: less blur (sharper), more opacity (more body),
            // and the shimmer's white pixels go invisible on a light background so we
            // dial it back too.
            let isLight = scheme == .light
            let blurMul: CGFloat = isLight ? 0.65 : 1.0
            let opacityMul: Double = isLight ? 1.45 : 1.0
            let shimmerMul: Double = isLight ? 0.35 : 1.0
            let gradient = Theme.haloGradient(for: mood)

            ZStack {
                // 0. Light-mode backplate — a very soft dark circle behind everything
                //    so the light halo colors have something to contrast against.
                //    Invisible in dark mode (uses transparent black).
                if isLight {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .blur(radius: 36)
                        .scaleEffect(scale + 0.40)
                }

                // 1. Outer aura — diffuse halo (tightened from the first pass: smaller
                //    radius and smaller scale gain so the orb keeps its centre of mass).
                Circle()
                    .fill(gradient)
                    .blur(radius: 32 * blurMul)
                    .scaleEffect(scale + 0.22)
                    .opacity(opacity * 0.38 * opacityMul)

                // 2. Mid corona
                Circle()
                    .fill(gradient)
                    .blur(radius: 14 * blurMul)
                    .scaleEffect(scale + 0.08)
                    .opacity(opacity * 0.65 * opacityMul)

                // 3. Core sphere — crisp now (blur radius 1 instead of 3). This is what
                //    gives the orb its body; the auras above sit around it as glow.
                Circle()
                    .fill(gradient)
                    .blur(radius: 1)
                    .scaleEffect(scale)
                    .opacity(min(1.0, opacity * opacityMul))

                // 4. Angular shimmer — slowly-rotating bright sweep gives the orb the
                //    sense of light catching a slightly textured surface.
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0.00), location: 0.00),
                                .init(color: .white.opacity(0.10), location: 0.20),
                                .init(color: .white.opacity(0.00), location: 0.40),
                                .init(color: .white.opacity(0.07), location: 0.60),
                                .init(color: .white.opacity(0.00), location: 0.85),
                                .init(color: .white.opacity(0.00), location: 1.00)
                            ]),
                            center: .center
                        )
                    )
                    .blur(radius: 3)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(shimmerAngle))
                    .opacity(opacity * shimmerMul * (reduceMotion ? 0 : 1))

                // 5. Pearl highlight — fixed light spot. Offset scales with the sphere
                //    so the highlight stays in the same relative position as the orb
                //    grows and shrinks.
                Circle()
                    .fill(Color.white.opacity(isLight ? 0.35 : 0.22))
                    .blur(radius: 10)
                    .frame(width: 58, height: 58)
                    .offset(x: -42 * scale, y: -38 * scale)
                    .scaleEffect(scale)

                // 6. Hold-emphasis ring — only during hold-full.
                if emphasized {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.30), lineWidth: 1.5)
                        .blur(radius: 0.5)
                        .scaleEffect(scale * 0.86)
                        .transition(.opacity)
                }

                // 7. Contour stroke — a touch heavier in light mode for edge definition
                //    against the bright background; barely-there in dark mode.
                Circle()
                    .strokeBorder(
                        (isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.18)),
                        lineWidth: 0.6
                    )
                    .scaleEffect(scale)
            }
            .frame(width: 260, height: 260)
            .compositingGroup()
            .accessibilityHidden(true)
        }
    }
}

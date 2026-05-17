import SwiftUI

/// Rounded, calm typography. Body/caption/headline/title use system text styles so they
/// honor Dynamic Type fully. Display sizes stay fixed (for the breathing phase label) —
/// screens that use them should apply `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`
/// to allow some scaling without breaking the layout.
enum PulseType {
    /// Fixed display size — used only for the giant breathing phase label.
    /// Pair with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` at the call site.
    static func display(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Title — scales with Dynamic Type. The `size` argument picks an approximate text style.
    static func title(_ size: CGFloat = 28) -> Font {
        let style: Font.TextStyle = switch size {
        case ..<24:  .title3
        case ..<30:  .title2
        case ..<34:  .title
        default:     .largeTitle
        }
        return .system(style, design: .rounded, weight: .semibold)
    }

    /// Headline — scales with Dynamic Type.
    static func headline(_ size: CGFloat = 18) -> Font {
        let style: Font.TextStyle = (size <= 15) ? .subheadline : .headline
        return .system(style, design: .rounded, weight: .semibold)
    }

    /// Body — scales with Dynamic Type.
    static func body(_ size: CGFloat = 16) -> Font {
        let style: Font.TextStyle = (size <= 14) ? .callout : .body
        return .system(style, design: .rounded, weight: .regular)
    }

    /// Caption — scales with Dynamic Type.
    static func caption(_ size: CGFloat = 13) -> Font {
        let style: Font.TextStyle = (size <= 11) ? .caption2 : .caption
        return .system(style, design: .rounded, weight: .medium)
    }
}

extension View {
    /// Adds the standard background gradient. Lets feature views just ask for it.
    func pulseBackground() -> some View {
        modifier(PulseBackgroundModifier())
    }
}

private struct PulseBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            Theme.backgroundGradient(scheme)
                .ignoresSafeArea()
            // Soft halo behind everything to add organic depth.
            // When Reduce Motion is on, soften the halo so it never animates with content.
            Theme.haloGradient
                .opacity(reduceMotion ? 0.10 : 0.18)
                .blur(radius: 60)
                .offset(y: -120)
                .ignoresSafeArea()
            content
        }
    }
}

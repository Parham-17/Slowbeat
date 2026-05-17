import SwiftUI

enum PulseButtonStyle {
    case warm   // primary "Begin"
    case cool   // post-event / "Done"
    case ghost  // secondary

    var gradient: LinearGradient? {
        switch self {
        case .warm:  Theme.warmGradient
        case .cool:  Theme.coolGradient
        case .ghost: nil
        }
    }
}

struct PulseButton: View {
    var title: String
    var systemImage: String? = nil
    var style: PulseButtonStyle = .warm
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(PulseType.headline())
            .foregroundStyle(style == .ghost ? Theme.inkPrimary : .white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if let gradient = style.gradient {
                    Capsule().fill(gradient)
                        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                } else {
                    Capsule().fill(Theme.cardFill)
                        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

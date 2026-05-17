import SwiftUI

struct RitualSummaryView: View {
    let session: BreathingSession?
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.coolGradient)
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)
                    .opacity(0.7)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white)
                    .padding(28)
                    .background(Circle().fill(Theme.coolGradient))
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            }
            .padding(.bottom, 8)

            Text("That counts.")
                .font(PulseType.title(32))
                .foregroundStyle(Theme.inkPrimary)

            Text("Sixty seconds of attention. Go gently into what's next.")
                .font(PulseType.body(16))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            PulseButton(title: "Done", systemImage: "checkmark", style: .cool, action: onClose)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .accessibilityElement(children: .combine)
    }
}

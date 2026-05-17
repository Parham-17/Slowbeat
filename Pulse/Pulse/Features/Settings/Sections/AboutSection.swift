import SwiftUI

struct AboutSection: View {
    var body: some View {
        SettingsSectionCard(title: "About") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Slowbeat is not a medical app. It's a small ritual — sixty seconds of attention before the moments that matter.")
                    .font(PulseType.body(14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Made with care.")
                    .font(PulseType.caption(12))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.top, 6)
            }
        }
    }
}

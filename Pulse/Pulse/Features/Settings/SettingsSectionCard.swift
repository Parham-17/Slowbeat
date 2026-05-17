import SwiftUI

/// Header + GlassCard wrapper used by every Settings section. Centralised so all sections
/// share the exact same padding, tracking, and typography — and so adding a new section
/// is a one-call affair, not a re-implementation.
struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PulseType.caption(13))
                .foregroundStyle(Theme.inkTertiary)
                .textCase(.uppercase)
                .tracking(1.2)
            GlassCard { content() }
        }
    }
}

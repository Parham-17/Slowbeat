import SwiftUI
import SwiftData

struct DuringTheBreathSection: View {
    let settings: PulseSettings
    @Environment(\.modelContext) private var context

    var body: some View {
        SettingsSectionCard(title: "During the breath") {
            VStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { settings.haptics },
                    set: { settings.haptics = $0; PulseStorage.save(context, reason: "haptics toggle") }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic guidance")
                            .font(PulseType.body(15))
                            .foregroundStyle(Theme.inkPrimary)
                        Text("A soft rising hum on inhale, a tap at the top, a falling pulse on exhale.")
                            .font(PulseType.caption(12))
                            .foregroundStyle(Theme.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Theme.coolA)

                Toggle(isOn: Binding(
                    get: { settings.eyesUp },
                    set: { settings.eyesUp = $0; PulseStorage.save(context, reason: "eyes-up toggle") }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eyes-up mode")
                            .font(PulseType.body(15))
                            .foregroundStyle(Theme.inkPrimary)
                        Text("Dims the screen so the haptic leads. For walking, hallways, or stage wings.")
                            .font(PulseType.caption(12))
                            .foregroundStyle(Theme.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Theme.coolA)
            }
        }
    }
}

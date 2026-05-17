import SwiftUI
import SwiftData

struct PrivacySection: View {
    @Query private var sessions: [BreathingSession]
    @Environment(\.modelContext) private var context
    @State private var showResetConfirm = false

    var body: some View {
        SettingsSectionCard(title: "Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                privacyRow(symbol: "iphone", text: "Everything stays on this device. No accounts. No cloud.")
                privacyRow(symbol: "antenna.radiowaves.left.and.right.slash", text: "Slowbeat never connects to the internet.")
                privacyRow(symbol: "calendar.badge.exclamationmark", text: "Calendar event titles are kept only while you have an upcoming moment.")
                privacyRow(symbol: "lock.fill", text: "Heart rate is read-only and never written back.")

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear all moments (\(sessions.count))")
                    }
                    .font(PulseType.headline(15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Theme.warmA.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityLabel("Clear all \(sessions.count) moments")
            }
        }
        .confirmationDialog(
            "Clear all moments?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear everything", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes every breathing session, reflection, and preference on this device. Nothing is sent anywhere.")
        }
    }

    private func privacyRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.coolA)
                .frame(width: 20)
            Text(text)
                .font(PulseType.body(14))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func resetAllData() {
        for s in sessions { context.delete(s) }
        PulseStorage.save(context, reason: "reset all moments")
    }
}

import SwiftUI
import SwiftData

struct BreathingMethodSection: View {
    let settings: PulseSettings
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    var body: some View {
        SettingsSectionCard(title: "Breathing method") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the pattern that works best for you. Try each over a few sessions.")
                    .font(PulseType.body(14))
                    .foregroundStyle(Theme.inkSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(BreathingPattern.all.enumerated()), id: \.element.id) { index, pattern in
                        row(pattern: pattern)
                        if index < BreathingPattern.all.count - 1 {
                            Divider().background(Theme.cardStroke)
                        }
                    }
                }
            }
        }
    }

    private func row(pattern: BreathingPattern) -> some View {
        let isSelected = settings.breathingPattern.key == pattern.key
        return Button {
            settings.breathingPattern = pattern
            PulseStorage.save(context, reason: "breathing method changed")
            UISelectionFeedbackGenerator().selectionChanged()
            // Push the new pattern key to widget + watch so external surfaces stay in sync.
            app.publishExternalSurfaces(settings: settings)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.coolA : Theme.inkTertiary.opacity(0.5))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(PulseType.headline(16))
                        .foregroundStyle(Theme.inkPrimary)
                    Text(pattern.summary)
                        .font(PulseType.body(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pattern.evidenceLine)
                        .font(PulseType.caption(11))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pattern.name). \(pattern.summary)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to switch to this method")
    }
}

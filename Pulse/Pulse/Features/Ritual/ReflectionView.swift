import SwiftUI
import SwiftData

/// Soft post-ritual prompt. Saving is optional — the breathing session is already persisted.
struct ReflectionView: View {
    let session: BreathingSession?
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var selectedOutcome: Outcome?
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                outcomeCards
                noteField
                Spacer(minLength: 8)
                actions
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You're ready.")
                .font(PulseType.title(32))
                .foregroundStyle(Theme.inkPrimary)
            Text("If you have a moment, mark how it went. You can also come back to this later from History.")
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var outcomeCards: some View {
        VStack(spacing: 10) {
            ForEach(Outcome.allCases) { outcome in
                Button {
                    selectedOutcome = outcome
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: outcome.symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(selectedOutcome == outcome ? .white : Theme.inkPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(
                                selectedOutcome == outcome
                                    ? AnyShapeStyle(Theme.coolGradient)
                                    : AnyShapeStyle(Theme.cardFill)
                            ))
                        Text(outcome.label)
                            .font(PulseType.headline(17))
                            .foregroundStyle(Theme.inkPrimary)
                        Spacer()
                        if selectedOutcome == outcome {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.coolA)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                selectedOutcome == outcome ? Theme.coolA.opacity(0.6) : Theme.cardStroke,
                                lineWidth: selectedOutcome == outcome ? 1.5 : 0.7
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(outcome.label)
                .accessibilityValue(selectedOutcome == outcome ? "Selected" : "")
                .accessibilityHint("Marks how this moment felt")
                .accessibilityAddTraits(selectedOutcome == outcome ? .isSelected : [])
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anything to remember?")
                .font(PulseType.caption(13))
                .foregroundStyle(Theme.inkTertiary)
                .textCase(.uppercase)
                .tracking(1.2)
            TextField("", text: $note, axis: .vertical)
                .focused($noteFocused)
                .lineLimit(3...5)
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkPrimary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.cardStroke, lineWidth: 0.7)
                )
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PulseButton(title: "Save", style: .cool) {
                save(includeReflection: true)
            }
            .disabled(selectedOutcome == nil)
            .opacity(selectedOutcome == nil ? 0.6 : 1)

            Button("Skip for now") {
                save(includeReflection: false)
            }
            .font(PulseType.headline(15))
            .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func save(includeReflection: Bool) {
        if let session, includeReflection {
            session.outcome = selectedOutcome
            session.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : note.trimmingCharacters(in: .whitespacesAndNewlines)
            PulseStorage.save(context, reason: "save reflection")
        }
        onDone()
    }
}

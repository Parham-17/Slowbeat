import SwiftUI
import SwiftData
import UIKit

/// Post-breath, pre-event: capture one if-then plan to take into the moment.
///
/// Grounded in implementation-intention research (Gollwitzer & Sheeran, 2006 meta-analysis;
/// d=0.65 across 94 tests). Pre-committing to a concrete response under a specific trigger
/// reliably increases the likelihood that the planned response actually happens.
///
/// Example: "If she interrupts me, I will pause for one breath before continuing."
struct IntentionView: View {
    let session: BreathingSession?
    let event: UpcomingEvent
    var onContinue: () -> Void

    @Environment(\.modelContext) private var context
    @FocusState private var focused: Field?

    @State private var ifText: String = ""
    @State private var thenText: String = ""

    private enum Field: Hashable { case ifField, thenField }

    private var examples: (ifExample: String, thenExample: String) {
        intentionExamples(for: event.suggestedCategory)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                ifThenCard
                hint
                Spacer(minLength: 8)
                actions
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .foregroundStyle(Theme.inkPrimary)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("One plan to take in")
                .font(PulseType.title(30))
                .foregroundStyle(Theme.inkPrimary)
            Text("Picture the moment. Pick one thing that might happen — then decide now how you'll meet it.")
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ifThenCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField(
                prefix: "If",
                placeholder: examples.ifExample,
                text: $ifText,
                field: .ifField,
                next: .thenField
            )
            labeledField(
                prefix: "I will",
                placeholder: examples.thenExample,
                text: $thenText,
                field: .thenField,
                next: nil
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.cardStroke, lineWidth: 0.7)
        )
    }

    private func labeledField(
        prefix: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        next: Field?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(prefix)
                .font(PulseType.headline(15))
                .foregroundStyle(event.suggestedCategory.accent)
                .frame(width: 48, alignment: .leading)
                .accessibilityHidden(true)

            TextField(placeholder, text: text, axis: .vertical)
                .focused($focused, equals: field)
                .lineLimit(1...3)
                .font(PulseType.body(16))
                .foregroundStyle(Theme.inkPrimary)
                .submitLabel(next == nil ? .done : .next)
                .onSubmit {
                    if let next { focused = next } else { focused = nil }
                }
                .accessibilityLabel(prefix)
                .accessibilityHint("For example, \(placeholder)")
        }
    }

    private var hint: some View {
        Text("Concrete works best. \"If X happens, I will do Y.\" One sentence each.")
            .font(PulseType.caption(12))
            .foregroundStyle(Theme.inkTertiary)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PulseButton(title: "Save and finish", systemImage: "checkmark", style: .cool) {
                save(includeIntention: true)
            }
            .disabled(hasAnyInput == false)
            .opacity(hasAnyInput ? 1 : 0.55)

            Button("Skip for now") {
                save(includeIntention: false)
            }
            .font(PulseType.headline(15))
            .foregroundStyle(Theme.inkSecondary)
            .accessibilityHint("Continues without saving a plan")
        }
    }

    private var hasAnyInput: Bool {
        let i = ifText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let t = thenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return i || t
    }

    private func save(includeIntention: Bool) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if let session, includeIntention {
            let trimmedIf = ifText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedThen = thenText.trimmingCharacters(in: .whitespacesAndNewlines)
            session.intentionIf = trimmedIf.isEmpty ? nil : trimmedIf
            session.intentionThen = trimmedThen.isEmpty ? nil : trimmedThen
            PulseStorage.save(context, reason: "save intention")
        }
        onContinue()
    }
}

// MARK: - Examples

/// Category-aware example placeholders. Examples lean concrete and behavioral,
/// matching the implementation-intention format ("If X, then I will Y").
private func intentionExamples(for category: EventCategory) -> (ifExample: String, thenExample: String) {
    switch category {
    case .presentation: return ("I lose my place", "pause and take one breath")
    case .interview:    return ("I'm asked something I don't know", "say so honestly, then think")
    case .exam:         return ("I get stuck on a question", "skip it and come back later")
    case .meeting:      return ("I get interrupted", "finish my sentence, then yield")
    case .conversation: return ("I feel defensive", "ask one clarifying question")
    case .performance:  return ("my hands start shaking", "slow my exhale")
    case .other:        return ("something throws me off", "take one breath before reacting")
    }
}

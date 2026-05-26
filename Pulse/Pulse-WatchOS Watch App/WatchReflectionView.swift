import SwiftUI
import WatchKit

/// Post-breath reflection on the wrist. Three options — Smooth / Steady / Tough —
/// each shipped back to the iPhone as a follow-up to the just-completed session.
/// Auto-dismisses after a pick so the user can drop the wrist immediately.
///
/// HIG-aligned: a native `List` of buttons inside `NavigationStack`, with the
/// rich-background gradient applied via `containerBackground(for: .navigation)`
/// so the push from the breath screen animates correctly.
///
/// `sessionID` is the UUID `WatchSyncService.shipCompletedSession` returned, so
/// the phone can attach this outcome to the same `BreathingSession` row.
struct WatchReflectionView: View {
    let sessionID: UUID?
    var onDismiss: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(WatchOutcome.allCases) { outcome in
                    Button {
                        choose(outcome)
                    } label: {
                        Label(outcome.label, systemImage: outcome.symbol)
                            .font(.body.weight(.medium))
                    }
                }
            } header: {
                Text("How did that land?")
            } footer: {
                Text("Optional — tells the phone how you're settling.")
            }

            Section {
                Button("Skip") { onDismiss() }
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Done")
        .navigationBarBackButtonHidden(true)
        .containerBackground(WatchTheme.teal.gradient, for: .navigation)
    }

    private func choose(_ outcome: WatchOutcome) {
        if let id = sessionID {
            WatchSyncService.shared.shipOutcome(sessionID: id, outcome: outcome)
        }
        WKInterfaceDevice.current().play(.click)
        onDismiss()
    }
}

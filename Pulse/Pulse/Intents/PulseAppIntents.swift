import AppIntents
import SwiftUI

/// Opens Pulse and begins a 60-second manual moment — same flow as tapping
/// "Start a moment without an event" from Today.
///
/// Why this exists: implementation-intention research (Gollwitzer & Sheeran 2006,
/// d=0.65) shows that pre-committing a response to a specific cue is the active
/// ingredient in behavior-change. Letting the user attach Pulse to their own cues
/// via Shortcuts (arriving at the office, opening their calendar app, plugging in
/// CarPlay) is the cleanest expression of that mechanism we can ship today.
struct StartBreathIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a breath"
    static let description = IntentDescription(
        "Open Pulse and begin a 60-second breath ritual."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentInbox.requestManualBreath()
        return .result()
    }
}

/// Surfaces Pulse's intents in the Shortcuts app gallery and to Siri without
/// requiring the user to manually build a shortcut. Voice phrases use
/// `\(.applicationName)` so localization picks up the user's preferred app name.
struct PulseAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBreathIntent(),
            phrases: [
                "Start a breath in \(.applicationName)",
                "Begin a moment in \(.applicationName)",
                "Open \(.applicationName) and breathe"
            ],
            shortTitle: "Start a breath",
            systemImageName: "wind"
        )
    }
}

//
//  PulseApp.swift
//  Pulse
//

import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @State private var appState = AppState()

    let modelContainer: ModelContainer = {
        let schema = Schema([
            BreathingSession.self,
            PulseSettings.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Privacy by design: never sync.
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .tint(Theme.warmA)
                .preferredColorScheme(nil) // Respect the system; the palette works in both.
        }
        .modelContainer(modelContainer)
    }
}

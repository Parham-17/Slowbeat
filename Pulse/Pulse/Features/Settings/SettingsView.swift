import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [PulseSettings]

    private var settings: PulseSettings { settingsList.first ?? app.ensureSettings(in: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BreathingMethodSection(settings: settings)
                    DuringTheBreathSection(settings: settings)
                    EventTypesSection(settings: settings)
                    RemindersSection(settings: settings)
                    PermissionsSection(settings: settings)
                    PrivacySection()
                    AboutSection()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                // Lock width to the ScrollView's viewport (capped at 560 on iPad).
                // Using `containerRelativeFrame` instead of `.frame(maxWidth:)` is
                // what fixes the horizontal-scroll bug: it sizes to the *actual*
                // container width rather than relying on parent width inference,
                // which iOS 26's new TabView container doesn't propagate cleanly.
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(length, 560)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .pulseBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

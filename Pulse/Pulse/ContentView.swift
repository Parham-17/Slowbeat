//
//  ContentView.swift
//  Pulse
//

import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab: Hashable { case today, history, settings }

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [PulseSettings]

    @State private var showOnboarding = false
    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(Tab.today)
                .tabItem { Label("Today", systemImage: "sun.horizon") }

            HistoryView()
                .tag(Tab.history)
                .tabItem { Label("Moments", systemImage: "wind") }

            SettingsView()
                .tag(Tab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.warmA)
        .task {
            let settings = app.ensureSettings(in: context)
            if settings.hasCompletedOnboarding == false {
                showOnboarding = true
            } else {
                await app.bootstrap(modelContext: context)
                consumePendingIntents()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    let settings = app.ensureSettings(in: context)
                    if settings.hasCompletedOnboarding {
                        await app.bootstrap(modelContext: context)
                        consumePendingIntents()
                    }
                }
            }
        }
        .onChange(of: app.pendingEventID) { _, newID in
            guard newID != nil else { return }
            Task { await handlePendingDeepLink() }
        }
        .onOpenURL { url in
            handleWidgetURL(url)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }

    /// Routes a widget or external `pulse://` deep-link into the same flows the rest of
    /// the app uses. Recognized URLs:
    ///   - `pulse://breath?eventID=<id>`  → start a ritual for that calendar event
    ///   - `pulse://breath`               → start a manual moment
    ///   - `pulse://` (anything else)     → just bring the app forward, no action
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "pulse" else { return }
        if url.host == "breath" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let eventID = components?.queryItems?.first(where: { $0.name == "eventID" })?.value,
               eventID.isEmpty == false {
                app.pendingEventID = eventID
            } else {
                selectedTab = .today
                app.startRitual(for: app.manualMoment())
            }
        }
    }

    /// Consumes any AppIntent requests parked in IntentInbox while we were cold/backgrounded.
    /// Currently a single intent: "Start a breath" routes to a manual moment, same as the
    /// Today tab's "Start a moment without an event" button.
    private func consumePendingIntents() {
        if IntentInbox.consumeManualBreathRequest() {
            selectedTab = .today
            app.startRitual(for: app.manualMoment())
        }
    }

    /// Resolves a pending notification deep-link into a ritual: switches to the Today tab
    /// and sets `activeRitualEvent` so TodayView's `navigationDestination` pushes the ritual.
    /// Refreshes the calendar first if the event isn't already loaded.
    private func handlePendingDeepLink() async {
        guard let id = app.pendingEventID else { return }

        if app.calendar.upcoming.contains(where: { $0.id == id }) == false {
            let settings = app.ensureSettings(in: context)
            await app.calendar.loadUpcoming(monitoring: settings.monitoredCategories)
        }

        if let event = app.calendar.upcoming.first(where: { $0.id == id }) {
            selectedTab = .today
            app.startRitual(for: event)
        }
        app.pendingEventID = nil
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [BreathingSession.self, PulseSettings.self], inMemory: true)
}

import SwiftUI
import WatchKit

/// Watch home. Three vertically-paged tabs (HIG: Digital Crown-driven):
///   • Now      — status banner (ongoing or next meeting) + Begin
///   • Settings — pattern picker + during-the-breath toggles
///   • Recent   — list of last 5 moments (scrolling tab, placed last)
///
/// Tapping Begin presents `WatchRitualFlow` as a sheet — a modal state
/// machine over MoodPicker → BreathView → Summary. Sheet-based hosting
/// (instead of NavigationStack pushes) avoids the observation-tracking
/// feedback loop the nested navigation destinations triggered on watchOS.
/// The pre-breath mood pick is a real list (44pt rows) rather than chip
/// buttons, and the Now tab itself no longer carries decorative animation —
/// both per the user feedback and to keep the home glanceable in the HIG
/// sense.
///
/// No "How did that land?" outcome question on the watch — that reflection is
/// about what happens *after* the breath (the meeting, the conversation), so
/// the watch shows only the leaf summary and lets the iPhone's History view
/// own outcome capture later.
struct ContentView: View {
    @State private var sync = WatchSyncService.shared
    @State private var ritualActive = false

    var body: some View {
        TabView {
            // PAGE 1 — Now (status + Begin). Presenting the ritual as a sheet
            // (rather than pushing it onto a NavigationStack) avoids the
            // observation-tracking feedback loop that arose when the breath
            // view nested its own navigation destination for the summary
            // while the parent path was also mutating.
            NavigationStack {
                NowTab(sync: sync) {
                    ritualActive = true
                }
                .navigationTitle("Now")
            }
            .containerBackground(WatchTheme.lavender.gradient, for: .tabView)

            // PAGE 2 — Settings
            NavigationStack {
                WatchSettingsTab(sync: sync)
                    .navigationTitle("Settings")
            }
            .containerBackground(WatchTheme.slate.gradient, for: .tabView)

            // PAGE 3 — Recent (the scrolling tab, HIG-recommended placement)
            NavigationStack {
                RecentTab(sync: sync)
                    .navigationTitle("Moments")
            }
            .containerBackground(WatchTheme.teal.gradient, for: .tabView)
        }
        .tabViewStyle(.verticalPage)
        .tint(WatchTheme.lavender)
        .sheet(isPresented: $ritualActive) {
            WatchRitualFlow(sync: sync) { ritualActive = false }
        }
    }
}

// MARK: - Now tab

private struct NowTab: View {
    let sync: WatchSyncService
    var onBegin: () -> Void

    var body: some View {
        // No ScrollView: a ScrollView on the first tab of a `.verticalPage`
        // TabView swallows the Digital Crown, so the user can never advance
        // to Settings / Recent. With the halo + chips removed, the content
        // fits on a single screen even on a 40 mm watch.
        //
        // `.padding(.top, 22)` offsets the first child past the floating
        // navigation title — without a scroll container, the title lays
        // over the top of the body, so the status banner would otherwise
        // sit at the same Y as "Now".
        VStack(spacing: 8) {
            EventStatusCard(sync: sync)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("Sixty seconds")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Pause before the moment.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            Button(action: onBegin) {
                Label("Begin", systemImage: "wind")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("\(sync.pattern.name) · synced")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 4)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }
}

/// The status card at the top of the Now tab. Three states (in priority order):
///   • Live meeting in progress (red dot, end-time)
///   • Next monitored meeting coming up (calendar icon, "in 6m")
///   • Nothing scheduled
///
/// Refreshes every 30s via a TimelineView so the relative time stays current
/// without a global timer.
private struct EventStatusCard: View {
    let sync: WatchSyncService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        if sync.hasOngoing, let title = sync.ongoingTitle {
            statusRow(
                dotColor: .red,
                symbol: sync.ongoingSymbol ?? "calendar",
                title: title,
                detail: ongoingDetail
            )
        } else if let title = sync.nextEventTitle, let start = sync.nextEventStart {
            statusRow(
                dotColor: WatchTheme.lavender,
                symbol: sync.nextEventSymbol ?? "calendar",
                title: title,
                detail: relativeText(start)
            )
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                Text("Nothing scheduled")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func statusRow(dotColor: Color, symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Image(systemName: symbol)
                .font(.caption2)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }

    private var ongoingDetail: String {
        guard let end = sync.ongoingEnd else { return "Happening now" }
        let mins = Int(end.timeIntervalSince(.now) / 60)
        if mins <= 0 { return "Wrapping up" }
        if mins < 60 { return "Until \(end.formatted(date: .omitted, time: .shortened)) · \(mins)m left" }
        return "Until \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func relativeText(_ start: Date) -> String {
        let minutes = Int(start.timeIntervalSince(.now) / 60)
        if minutes <= 0 { return "Now" }
        if minutes < 60 { return "in \(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
    }
}

// MARK: - Settings tab

private struct WatchSettingsTab: View {
    let sync: WatchSyncService

    var body: some View {
        List {
            Section {
                Picker(
                    selection: Binding(
                        get: { sync.pattern.key },
                        set: { sync.setPattern($0) }
                    ),
                    label: Label("Pattern", systemImage: "wind")
                ) {
                    ForEach(BreathingPattern.Key.allCases) { key in
                        Text(BreathingPattern.from(rawKey: key.rawValue).name)
                            .tag(key)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Breathing method")
            } footer: {
                Text("Synced with iPhone")
            }

            Section {
                LabeledContent("Haptics") {
                    Text(sync.hapticsEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Eyes-up") {
                    Text(sync.eyesUpEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("During the breath")
            } footer: {
                Text("Change on iPhone")
            }
        }
    }
}

// MARK: - Recent tab

private struct RecentTab: View {
    let sync: WatchSyncService

    var body: some View {
        Group {
            if sync.recent.isEmpty {
                ContentUnavailableView {
                    Label("No moments yet", systemImage: "wind")
                } description: {
                    Text("Your finished breaths land here.")
                }
            } else {
                List(sync.recent) { row in
                    RecentRow(session: row)
                }
            }
        }
    }
}

private struct RecentRow: View {
    let session: RecentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(session.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let outcome = session.outcome {
                    Image(systemName: outcome.symbol)
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
            HStack(spacing: 4) {
                if let mood = session.mood {
                    Image(systemName: mood.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(mood.tint)
                }
                Text(session.patternName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(session.completedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}

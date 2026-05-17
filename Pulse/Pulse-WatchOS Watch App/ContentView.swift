import SwiftUI

/// Watch home. Single-purpose: tap to begin a 60-second breath ritual.
/// When the iPhone has shared a next monitored event, surfaces it above Begin so
/// the wrist itself can see the moment that's coming up.
struct ContentView: View {
    @State private var begin = false
    @State private var sync = WatchSyncService.shared

    private let accent = Color(red: 0.68, green: 0.66, blue: 0.88) // soft lavender

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer(minLength: 2)
                eventBanner
                Image(systemName: "wind")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(accent)
                Text("Sixty seconds.")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text(sync.pattern.name + " · haptic-led")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 2)
                Button {
                    begin = true
                } label: {
                    Text("Begin")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .padding(.horizontal, 4)
            .navigationDestination(isPresented: $begin) {
                WatchBreathView(
                    pattern: sync.pattern,
                    eventTitle: sync.nextEventTitle
                ) {
                    begin = false
                }
            }
        }
    }

    @ViewBuilder
    private var eventBanner: some View {
        if let title = sync.nextEventTitle, let start = sync.nextEventStart {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if let symbol = sync.nextEventSymbol {
                        Image(systemName: symbol).font(.system(size: 10))
                    }
                    Text(title)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                }
                Text(relativeText(start))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(accent.opacity(0.18))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next moment: \(title), \(relativeText(start))")
        }
    }

    private func relativeText(_ start: Date) -> String {
        let minutes = Int(start.timeIntervalSince(.now) / 60)
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
    }
}

#Preview {
    ContentView()
}

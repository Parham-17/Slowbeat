import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct PulseNextEventEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var nextEvent: WidgetSnapshot.Event? { snapshot.nextEvent(after: date) }
}

// MARK: - Provider

/// Builds the timeline from the snapshot the main app published into the App Group.
/// One entry per event-start gives the widget a natural cadence: it always shows the
/// soonest future event, and rolls to the next one the moment the current one starts.
struct PulseNextEventProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseNextEventEntry {
        PulseNextEventEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseNextEventEntry) -> Void) {
        completion(PulseNextEventEntry(date: .now, snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseNextEventEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        let now = Date()
        // One entry now, then one at every event start so the widget rolls forward as
        // events begin. Bounded at 6 to keep the timeline cheap.
        var entries: [PulseNextEventEntry] = [PulseNextEventEntry(date: now, snapshot: snapshot)]
        for event in snapshot.events.prefix(6) where event.start > now {
            entries.append(PulseNextEventEntry(date: event.start, snapshot: snapshot))
        }
        // After the last event we re-fetch — the main app should have published a fresh
        // snapshot by then. .atEnd is fine because reloadAllTimelines() is called on
        // every snapshot write.
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Entry view

struct PulseNextEventView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseNextEventEntry

    var body: some View {
        let event = entry.nextEvent
        Group {
            switch family {
            case .systemSmall:        smallBody(event)
            case .systemMedium:       mediumBody(event)
            case .accessoryRectangular: lockBody(event)
            default:                  smallBody(event)
            }
        }
        .widgetURL(deepLink(for: event))
    }

    // MARK: System small

    @ViewBuilder
    private func smallBody(_ event: WidgetSnapshot.Event?) -> some View {
        if let event {
            VStack(alignment: .leading, spacing: 8) {
                categoryDot(event)
                Text(event.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                relativeLine(event)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            emptyView
        }
    }

    // MARK: System medium

    @ViewBuilder
    private func mediumBody(_ event: WidgetSnapshot.Event?) -> some View {
        if let event {
            HStack(alignment: .top, spacing: 14) {
                categoryDot(event, size: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT MOMENT")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                    Text(event.title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    relativeLine(event)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            emptyView
        }
    }

    // MARK: Lock Screen rectangular

    @ViewBuilder
    private func lockBody(_ event: WidgetSnapshot.Event?) -> some View {
        if let event {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                Text("\(relativeText(event.start)) · breathe")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetAccentable()
        } else {
            Text("Nothing pressing.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Shared bits

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "moon.stars")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("Nothing pressing.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
            Text("When something important is on your calendar, it'll appear here.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func categoryDot(_ event: WidgetSnapshot.Event, size: CGFloat = 28) -> some View {
        Image(systemName: event.categorySymbolName)
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(Color(hex: event.accentHex).opacity(0.9))
            )
    }

    private func relativeLine(_ event: WidgetSnapshot.Event) -> some View {
        Text(relativeText(event.start))
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private func relativeText(_ start: Date) -> String {
        let minutes = max(0, Int(start.timeIntervalSince(.now) / 60))
        if minutes == 0 { return "now" }
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "in \(hours)h" : "in \(hours)h \(mins)m"
    }

    private func deepLink(for event: WidgetSnapshot.Event?) -> URL? {
        if let event {
            return URL(string: "pulse://breath?eventID=\(event.id)")
        }
        return URL(string: "pulse://")
    }
}

// MARK: - Widget configuration

struct Pulse_Widget: Widget {
    let kind: String = "Pulse_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseNextEventProvider()) { entry in
            PulseNextEventView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next moment")
        .description("A glance at what's coming up — tap to take a breath.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Hex Color

extension Color {
    /// "RRGGBB" hex string → SwiftUI Color. Used to receive category accents from the
    /// main app without dragging the EventCategory enum across the target boundary.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >>  8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    Pulse_Widget()
} timeline: {
    PulseNextEventEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            events: [
                .init(
                    id: "preview",
                    title: "Quarterly review",
                    start: .now.addingTimeInterval(6 * 60),
                    accentHex: "B2A8E6",
                    categorySymbolName: "person.2.wave.2"
                )
            ],
            generatedAt: .now
        )
    )
    PulseNextEventEntry(date: .now, snapshot: .empty)
}

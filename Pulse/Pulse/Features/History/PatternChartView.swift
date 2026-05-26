import SwiftUI
import Charts

/// Weekly summary of how the user has been arriving at their breaths.
///
/// Each day is a bar; the bar's segments are colored by the pre-breath mood
/// the user reported, stacked anxious → energized → settled → flat from
/// bottom to top. Sessions without a reported mood form a neutral segment
/// on top so the bar height still honestly reflects the day's total.
///
/// **Why mood, not outcome.** The previous version colored bars by average
/// post-breath outcome (smooth/steady/tough), but most sessions don't have
/// outcomes — Reflect is optional — so the chart collapsed to one color and
/// the legend read as "what's that supposed to mean." Mood is captured pre-
/// breath and is the more reliable signal of how the user was feeling that
/// day, which is what a weekly summary should actually convey at a glance.
struct PatternChartView: View {
    let sessions: [BreathingSession]

    /// One bar segment: a (day, mood) pair with its count. The chart stacks
    /// segments for the same `day` automatically because `BarMark` adds at
    /// the same x-position get summed.
    private struct MoodSegment: Identifiable {
        let day: Date
        let mood: PreMood?
        let count: Int
        var id: String { "\(day.timeIntervalSinceReferenceDate)-\(mood?.rawValue ?? "none")" }
        /// Stable scale key for `chartForegroundStyleScale`. Charts derives
        /// the per-segment color from this string.
        var moodKey: String { mood?.rawValue ?? "none" }
        /// Stable ordering of moods inside a single day's bar. Anxious at the
        /// bottom, "no mood reported" on top so the colored segments stay
        /// adjacent for easier visual comparison across days.
        var stackOrder: Int {
            switch mood {
            case .anxious?:   return 0
            case .energized?: return 1
            case .settled?:   return 2
            case .flat?:      return 3
            case nil:         return 4
            }
        }
    }

    /// Last 7 days. Every day produces at least one segment so the x-axis
    /// always shows seven slots — without that placeholder, Swift Charts auto-
    /// fits the plot area to whichever days *have* data, so one day's data
    /// stretches into a single panel-wide bar and a second day cuts each bar
    /// in half. Days with no sessions emit a single `count: 0` placeholder
    /// (invisible bar, x-position still anchored).
    private var segments: [MoodSegment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var result: [MoodSegment] = []
        for offset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let inDay = sessions.filter { $0.startedAt >= day && $0.startedAt < dayEnd }
            if inDay.isEmpty {
                // Zero-height placeholder so the day still has an x-position.
                // Mood is nil so it doesn't pollute the legend or the
                // VoiceOver readout (which already says "no moments" via the
                // segmentVoiceOver branch).
                result.append(MoodSegment(day: day, mood: nil, count: 0))
                continue
            }
            let grouped = Dictionary(grouping: inDay, by: { $0.preMood })
            let moodOrder: [PreMood?] = [.anxious, .energized, .settled, .flat, nil]
            for mood in moodOrder {
                let count = grouped[mood]?.count ?? 0
                guard count > 0 else { continue }
                result.append(MoodSegment(day: day, mood: mood, count: count))
            }
        }
        return result
    }

    /// Half-open range [start of 7-days-ago … end of today]. Used as the
    /// chart's explicit x-domain so the plot area always reserves seven
    /// day-slots, regardless of how many days actually have data. Without
    /// this the bar width changes every time the user records on a new
    /// day — the chart shrinks bars to fit, breaking visual consistency.
    private var weekDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return start...end
    }

    /// Color map fed to `chartForegroundStyleScale`. Keys must match
    /// `MoodSegment.moodKey`. The "none" segment uses the card stroke so
    /// untagged moments fade into the background — present but not loud.
    private var moodColorScale: KeyValuePairs<String, Color> {
        [
            PreMood.anxious.rawValue:   PreMood.anxious.tint,
            PreMood.energized.rawValue: PreMood.energized.tint,
            PreMood.settled.rawValue:   PreMood.settled.tint,
            PreMood.flat.rawValue:      PreMood.flat.tint,
            "none":                     Theme.cardStroke
        ]
    }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header

                if sessions.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "wind")
                            .foregroundStyle(Theme.inkTertiary)
                        Text("Your first moments will appear here.")
                            .font(PulseType.body(15))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                } else {
                    chart
                        .frame(height: 140)
                        .accessibilityLabel("Weekly summary of moments by mood")
                        .accessibilityValue(accessibilitySummary)
                    legend
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("This week")
                .font(PulseType.caption(13))
                .foregroundStyle(Theme.inkTertiary)
                .textCase(.uppercase)
                .tracking(1.2)
            // Tiny supporting line so the chart legend isn't just floating
            // labels — the user knows what they're seeing in one read.
            if sessions.isEmpty == false {
                Text("How you arrived at each breath")
                    .font(PulseType.caption(12))
                    .foregroundStyle(Theme.inkTertiary.opacity(0.85))
            }
        }
    }

    private var chart: some View {
        Chart(segments.sorted(by: { $0.stackOrder < $1.stackOrder })) { segment in
            BarMark(
                x: .value("Day", segment.day, unit: .day),
                // `.ratio(0.55)` makes each bar take ~55% of its day-slot
                // width — bars read as bars (with breathing room between
                // them) instead of filling their slot edge-to-edge. The
                // weekDomain x-scale handles consistency across day counts;
                // this just sets the visual style.
                y: .value("Moments", segment.count),
                width: .ratio(0.55)
            )
            .cornerRadius(4)
            .foregroundStyle(by: .value("Mood", segment.moodKey))
            .accessibilityLabel(Text(segment.day, format: .dateTime.weekday(.wide)))
            .accessibilityValue(Text(segmentVoiceOver(segment)))
        }
        // Lock the x-axis to a full 7-day window. Without this, Charts
        // auto-fits the plot area to whichever days have data, so a single
        // recorded day blows up into one panel-wide bar — the consistency
        // bug visible in the screenshot.
        .chartXScale(domain: weekDomain)
        .chartForegroundStyleScale(moodColorScale)
        .chartLegend(.hidden) // Custom legend below maps mood → label cleaner than Charts's default.
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
                    .font(PulseType.caption(11))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }

    private func segmentVoiceOver(_ segment: MoodSegment) -> String {
        guard segment.count > 0 else { return "no moments" }
        let moodLabel = segment.mood?.label.lowercased() ?? "no mood reported"
        let unit = segment.count == 1 ? "moment" : "moments"
        return "\(segment.count) \(moodLabel) \(unit)"
    }

    /// Custom legend: always shows all four moods so the user can read the
    /// chart's color language even on days with sparse data. "Untagged" is
    /// left out — the gray segment is self-explanatory and naming it would
    /// imply it's a category the user picked, which it isn't.
    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(PreMood.allCases) { mood in
                legendDot(mood.tint, mood.label.lowercased())
            }
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(PulseType.caption(11))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    private var accessibilitySummary: String {
        let total = sessions.filter { session in
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: .now)) ?? .now
            return session.startedAt >= sevenDaysAgo
        }.count
        return "\(total) moments in the last seven days, colored by pre-breath mood"
    }
}

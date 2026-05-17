import SwiftUI
import Charts

/// A calm weekly summary. Avoids axes/numbers — focus is on rhythm, not data density.
struct PatternChartView: View {
    let sessions: [BreathingSession]

    private struct DayBucket: Identifiable {
        let id: Date
        let day: Date
        let count: Int
        let averageScore: Double?
    }

    private var buckets: [DayBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayStart = day
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let inDay = sessions.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            let scores = inDay.compactMap { $0.outcome?.score }
            let avg = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
            return DayBucket(id: day, day: day, count: inDay.count, averageScore: avg)
        }
    }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("This week")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)

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
                        .accessibilityLabel("Weekly summary of moments")
                        .accessibilityValue(accessibilitySummary)
                    legend
                }
            }
        }
    }

    private var chart: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Day", bucket.day, unit: .day),
                y: .value("Moments", max(bucket.count, 0))
            )
            .cornerRadius(6)
            .foregroundStyle(barFill(for: bucket))
            .annotation(position: .top, alignment: .center, spacing: 4) {
                if bucket.count > 0 {
                    Circle()
                        .fill(scoreColor(bucket.averageScore))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityLabel(Text(bucket.day, format: .dateTime.weekday(.wide)))
            .accessibilityValue(Text(barVoiceOverValue(for: bucket)))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
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

    private func barVoiceOverValue(for bucket: DayBucket) -> String {
        guard bucket.count > 0 else { return "no moments" }
        let count = "\(bucket.count) moment\(bucket.count == 1 ? "" : "s")"
        guard let score = bucket.averageScore else { return count }
        let mood: String
        switch score {
        case 0.66...: mood = "mostly smooth"
        case 0.33..<0.66: mood = "steady"
        default: mood = "tougher"
        }
        return "\(count), \(mood)"
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(Theme.coolA, "smooth")
            legendDot(Theme.haloA, "steady")
            legendDot(Theme.warmA, "tough")
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

    private func barFill(for bucket: DayBucket) -> AnyShapeStyle {
        if bucket.count == 0 { return AnyShapeStyle(Theme.cardStroke) }
        return AnyShapeStyle(scoreColor(bucket.averageScore).opacity(0.85))
    }

    private func scoreColor(_ score: Double?) -> Color {
        guard let score else { return Theme.haloA }
        if score >= 0.66 { return Theme.coolA }
        if score >= 0.33 { return Theme.haloA }
        return Theme.warmA
    }

    private var accessibilitySummary: String {
        let total = buckets.reduce(0) { $0 + $1.count }
        return "\(total) moments in the last seven days"
    }
}

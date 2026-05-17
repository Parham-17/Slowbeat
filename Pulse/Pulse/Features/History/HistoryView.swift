import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \BreathingSession.startedAt, order: .reverse) private var sessions: [BreathingSession]
    @Environment(\.modelContext) private var context

    @State private var sessionForReflection: BreathingSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    PatternChartView(sessions: sessions)
                    streakLine
                    list
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(length, 560)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .pulseBackground()
            .navigationTitle("Moments")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $sessionForReflection) { session in
                NavigationStack {
                    ReflectionView(session: session) {
                        sessionForReflection = nil
                    }
                    .pulseBackground()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { sessionForReflection = nil }
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your patterns")
                .font(PulseType.headline(15))
                .foregroundStyle(Theme.inkTertiary)
            Text(sessions.isEmpty ? "Nothing yet. That's a good place to begin." : summaryLine)
                .font(PulseType.title(22))
                .foregroundStyle(Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryLine: String {
        let count = sessions.count
        let units = count == 1 ? "moment" : "moments"
        return "\(count) \(units) recorded."
    }

    @ViewBuilder
    private var streakLine: some View {
        if let streak = currentStreak, streak > 1 {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.warmA)
                Text("\(streak) days in a row")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.cardFill))
            .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
            .accessibilityElement(children: .combine)
        }
    }

    private var currentStreak: Int? {
        guard sessions.isEmpty == false else { return nil }
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        var count = 0
        let bucketed = Dictionary(grouping: sessions, by: { cal.startOfDay(for: $0.startedAt) })
        while bucketed[day] != nil {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count == 0 ? nil : count
    }

    @ViewBuilder
    private var list: some View {
        if sessions.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recent")
                    .font(PulseType.caption(13))
                    .foregroundStyle(Theme.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                ForEach(sessions.prefix(50)) { session in
                    SessionRow(session: session) {
                        sessionForReflection = session
                    } onDelete: {
                        context.delete(session)
                        PulseStorage.save(context, reason: "delete session")
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: BreathingSession
    var onReflect: () -> Void
    var onDelete: () -> Void

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: session.category.symbol)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(session.category.accent.opacity(0.85)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.eventTitle)
                        .font(PulseType.headline(16))
                        .foregroundStyle(Theme.inkPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(session.startedAt.formatted(.relative(presentation: .named)))
                        if let outcome = session.outcome {
                            Text("•")
                            HStack(spacing: 4) {
                                Image(systemName: outcome.symbol)
                                Text(outcome.label)
                            }
                            .foregroundStyle(outcomeColor)
                        }
                    }
                    .font(PulseType.caption(12))
                    .foregroundStyle(Theme.inkTertiary)

                    if let plan = intentionLine {
                        Text(plan)
                            .font(PulseType.caption(12))
                            .foregroundStyle(session.category.accent)
                            .lineLimit(2)
                            .padding(.top, 2)
                            .accessibilityLabel("Plan: \(plan)")
                    }
                }

                Spacer()

                if session.outcome == nil {
                    Button("Reflect", action: onReflect)
                        .font(PulseType.caption(13))
                        .foregroundStyle(Theme.inkPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Theme.cardFill))
                        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 0.7))
                        .buttonStyle(.plain)
                        .accessibilityHint("Mark how this moment felt")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Reflect", systemImage: "pencil", action: onReflect)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var outcomeColor: Color {
        switch session.outcome {
        case .smooth?: Theme.coolA
        case .steady?: Theme.haloA
        case .tough?:  Theme.warmA
        case nil:      Theme.inkTertiary
        }
    }

    private var intentionLine: String? {
        let i = session.intentionIf?.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = session.intentionThen?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (i?.isEmpty == false ? i : nil, t?.isEmpty == false ? t : nil) {
        case (let i?, let t?): return "If \(i), I will \(t)."
        case (let i?, nil):    return "If \(i)…"
        case (nil, let t?):    return "I will \(t)."
        default:               return nil
        }
    }

    private var accessibilityLabel: String {
        var parts = [session.eventTitle, session.category.displayName]
        if let outcome = session.outcome { parts.append("Outcome: \(outcome.label)") }
        return parts.joined(separator: ", ")
    }
}

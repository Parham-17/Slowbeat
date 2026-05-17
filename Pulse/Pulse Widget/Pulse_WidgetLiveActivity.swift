import ActivityKit
import WidgetKit
import SwiftUI

/// The Lock Screen + Dynamic Island presentation for a breath in progress.
///
/// Design intent: minimal — phase label, thin progress, remaining seconds. No category
/// tints or wallpapers because the Lock Screen / Dynamic Island already sits on top of
/// the user's chosen background. The wind glyph is the only branding.
struct Pulse_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathLiveActivityAttributes.self) { context in
            // Lock Screen / banner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(context.attributes.eventTitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(context.state.secondsRemaining)s")
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(context.state.phase.displayLabel)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                ProgressView(value: context.state.progress)
                    .progressViewStyle(.linear)
                    .tint(.primary)
            }
            .padding(16)
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                            .font(.system(size: 14, weight: .medium))
                        Text(context.state.phase.displayLabel)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                    }
                    .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.secondsRemaining)s")
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(.primary)
                        .padding(.horizontal, 2)
                }
            } compactLeading: {
                Image(systemName: "wind")
                    .font(.system(size: 14, weight: .medium))
            } compactTrailing: {
                Text("\(context.state.secondsRemaining)s")
                    .font(.system(.caption, design: .rounded).monospacedDigit())
            } minimal: {
                Image(systemName: "wind")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
}

private extension BreathLiveActivityAttributes.ContentState.Phase {
    var displayLabel: String {
        switch self {
        case .inhale:    return "Breathe in"
        case .holdFull:  return "Hold"
        case .exhale:    return "Breathe out"
        case .holdEmpty: return "Rest"
        case .done:      return "Done"
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: BreathLiveActivityAttributes(
    eventTitle: "Quarterly review",
    patternName: "Box",
    totalSeconds: 60,
    startedAt: .now
)) {
    Pulse_WidgetLiveActivity()
} contentStates: {
    BreathLiveActivityAttributes.ContentState(phase: .inhale, progress: 0.10, secondsRemaining: 54)
    BreathLiveActivityAttributes.ContentState(phase: .holdFull, progress: 0.33, secondsRemaining: 40)
    BreathLiveActivityAttributes.ContentState(phase: .exhale, progress: 0.66, secondsRemaining: 20)
}

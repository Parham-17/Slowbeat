import SwiftUI
import WatchKit

/// Pre-breath mood pick on the wrist. Each option is a full-width list row so
/// the tap target is the row, not a 28pt chip — well above the 44pt minimum
/// the watchOS HIG recommends.
///
/// The picker mirrors the iPhone's `RitualIntroView` step: the user reports
/// their state, that tints the halo on the breath view, and the chosen mood is
/// shipped with the completed session.
///
/// Tapping a row OR Skip dismisses straight into `WatchBreathView`. A Skip
/// row at the bottom keeps the mood step strictly optional (HIG: every modal
/// step should offer a quick escape).
struct WatchMoodPickerView: View {
    var onBegin: (WatchPreMood?) -> Void

    var body: some View {
        List {
            Section {
                ForEach(WatchPreMood.allCases) { mood in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        onBegin(mood)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mood.symbol)
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(mood.tint.opacity(0.55)))
                            Text(mood.label)
                                .font(.body.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
            } header: {
                Text("How are you?")
            } footer: {
                Text("Optional — tints the halo for your state.")
            }

            Section {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    onBegin(nil)
                } label: {
                    HStack {
                        Text("Skip")
                            .font(.body)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Before")
        .containerBackground(WatchTheme.lavender.gradient, for: .navigation)
    }
}

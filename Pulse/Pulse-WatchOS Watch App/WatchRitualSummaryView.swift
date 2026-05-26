import SwiftUI
import WatchKit

/// End-of-ritual screen on the wrist. Mirrors the iPhone's `RitualSummaryView`:
/// a leaf glyph in a teal gradient circle, the "That counts." headline, and a
/// Done button. The "How did that land?" outcome question lives elsewhere (the
/// iPhone's History view) — that reflection is meant for *after* the meeting,
/// not the moment a 60-second breath ends.
///
/// Auto-dismisses after 6 seconds so the watch doesn't sit on this view if the
/// user lets the wrist drop. The user can also tap Done to leave immediately,
/// or right-swipe (system back).
struct WatchRitualSummaryView: View {
    var onClose: () -> Void

    @State private var autoDismiss: Task<Void, Never>?

    var body: some View {
        // ScrollView so the content stays fully reachable on the smallest
        // watch faces (40/41 mm). The previous fixed-height VStack — 80 pt halo
        // + title3 + caption + .controlSize(.large) button — overflowed the
        // available height on those sizes and the Done button bottom edge
        // clipped under the bezel. With a scroll container plus a slightly
        // smaller halo, everything fits without scrolling on 44+ mm and the
        // user can flick up to reach Done if Dynamic Type or text wrap pushes
        // it past the fold on the smaller faces.
        ScrollView {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(WatchTheme.teal.gradient)
                        .frame(width: 60, height: 60)
                        .blur(radius: 12)
                        .opacity(0.7)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Circle().fill(WatchTheme.teal.gradient))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                }
                .padding(.top, 2)

                Text("That counts.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)

                Text("Sixty seconds of attention.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: dismiss) {
                    Label("Done", systemImage: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white.opacity(0.22))
                .foregroundStyle(.white)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Complete")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .containerBackground(WatchTheme.teal.gradient, for: .navigation)
        .onAppear {
            WKInterfaceDevice.current().play(.success)
            autoDismiss = Task {
                try? await Task.sleep(for: .seconds(6))
                if !Task.isCancelled { dismiss() }
            }
        }
        .onDisappear { autoDismiss?.cancel() }
    }

    private func dismiss() {
        autoDismiss?.cancel()
        onClose()
    }
}

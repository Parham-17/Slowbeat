import SwiftUI
import SwiftData

/// Three-page onboarding. Each page demonstrates rather than describes:
/// page 1 is the breath itself running live, page 2 is a worked example of the
/// pre-event nudge with the actual UI we'd show, page 3 is the privacy promise.
///
/// Calendar permission is requested in-flow on page 2 (the moment the user is
/// being shown why we need it). Notifications + Health are deliberately not
/// asked here — they're requested only when the user first reaches a screen
/// that needs them, so the cold-start prompts stay focused on the core value.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [PulseSettings]

    @State private var page = 0

    var body: some View {
        ZStack {
            Group {
                switch page {
                case 0: WelcomePage { advance(to: 1) }
                case 1: TriggerPage { advance(to: 2) }
                default: ReadyPage(done: complete)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: 0.55), value: page)
        .pulseBackground()
    }

    private func advance(to newPage: Int) {
        withAnimation(.easeInOut(duration: 0.55)) { page = newPage }
    }

    private func complete() {
        let settings = settingsList.first ?? app.ensureSettings(in: context)
        settings.hasCompletedOnboarding = true
        PulseStorage.save(context, reason: "complete onboarding")
        Task { await app.bootstrap(modelContext: context) }
        dismiss()
    }
}

// MARK: - Page 1: Welcome (live breath)

private struct WelcomePage: View {
    var next: () -> Void
    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            BreathingHalo(progress: progress)
                .padding(.bottom, 44)
            Text("Arrive ready.")
                .font(PulseType.title(36))
                .foregroundStyle(Theme.inkPrimary)
            Text("A sixty-second breath, before the moments that matter.")
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .padding(.top, 14)
            Spacer()
            PulseButton(title: "Continue", systemImage: "arrow.right", style: .warm, action: next)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to Slowbeat. A sixty-second breath, before the moments that matter.")
        .onAppear {
            guard reduceMotion == false else { progress = 0.85; return }
            // 6s up, 6s down — a meditative cadence that's slower than the actual 4s
            // breath rhythm, so the onboarding feels contemplative rather than urgent.
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                progress = 1
            }
        }
    }
}

// MARK: - Page 2: The trigger (calendar permission)

private struct TriggerPage: View {
    @Environment(AppState.self) private var app
    var next: () -> Void
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            MockEventCard()
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            Text("Your calendar is the trigger.")
                .font(PulseType.title(28))
                .foregroundStyle(Theme.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Text("Slowbeat notices what's coming and offers a moment — without you having to ask.")
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 12)
            Spacer()
            VStack(spacing: 12) {
                PulseButton(
                    title: requesting ? "Asking…" : "Connect calendar",
                    systemImage: "calendar",
                    style: .warm
                ) {
                    requesting = true
                    Task {
                        _ = await app.calendar.requestAccess()
                        requesting = false
                        next()
                    }
                }
                .padding(.horizontal, 28)
                .disabled(requesting)
                Button("Not now", action: next)
                    .font(PulseType.headline(15))
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityHint("Skip without connecting your calendar — you can change this later in Settings.")
            }
            .padding(.bottom, 44)
        }
    }
}

/// A static event card with a soft pulsing border — visually demonstrates what
/// Pulse will show before each monitored event, without needing real data.
private struct MockEventCard: View {
    @State private var pulse = false

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: "person.2.wave.2")
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(Color(red: 0.62, green: 0.78, blue: 0.66).opacity(0.85))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quarterly review")
                        .font(PulseType.headline(16))
                        .foregroundStyle(Theme.inkPrimary)
                    Text("in 6 min")
                        .font(PulseType.caption(12))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                Text("Begin")
                    .font(PulseType.caption(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.warmGradient))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.warmA.opacity(pulse ? 0.55 : 0.0), lineWidth: 2)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
        )
        .accessibilityHidden(true)
        .onAppear { pulse = true }
    }
}

// MARK: - Page 3: Yours, only (privacy promise)

private struct ReadyPage: View {
    var done: () -> Void
    @State private var glow = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            focalGlyph
                .padding(.bottom, 36)
            Text("Yours, only.")
                .font(PulseType.title(32))
                .foregroundStyle(Theme.inkPrimary)
            Text("Nothing leaves this device. You can clear everything anytime.")
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 14)
            promisesCard
                .padding(.horizontal, 28)
                .padding(.top, 28)
            Spacer()
            PulseButton(title: "Begin", systemImage: "checkmark", style: .cool, action: done)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
        }
    }

    /// A soft glowing lock glyph mirrors the visual weight of the halo on page 1 and
    /// the mock event card on page 2 — gives this page the same "focal element on top"
    /// structure rather than starting with a list.
    private var focalGlyph: some View {
        ZStack {
            Circle()
                .fill(Theme.coolA.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 16)
                .scaleEffect(glow ? 1.05 : 0.95)
            Circle()
                .fill(Theme.coolA.opacity(0.22))
                .frame(width: 88, height: 88)
                .blur(radius: 2)
            Image(systemName: "lock.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 140, height: 140)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityHidden(true)
    }

    private var promisesCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                row(symbol: "iphone", text: "Stays on this device.")
                Divider().background(Theme.cardStroke)
                row(symbol: "antenna.radiowaves.left.and.right.slash", text: "No accounts, no cloud.")
                Divider().background(Theme.cardStroke)
                row(symbol: "arrow.up.right.square", text: "You can leave anytime.")
            }
        }
    }

    private func row(symbol: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.coolA)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(text)
                .font(PulseType.body(15))
                .foregroundStyle(Theme.inkPrimary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

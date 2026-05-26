import Foundation
import WatchKit

/// Keeps the Apple Watch display lit for the duration of a breath ritual.
///
/// watchOS dims the screen after the system "wake duration" (15–70s) — well
/// short of the 60-second breath — so without intervention the user loses
/// sight of the phase label and halo mid-session. `WKExtendedRuntimeSession`
/// is the Apple-blessed primitive for short foreground exercises like
/// mindfulness and breathing: the system keeps the display awake and the app
/// foregrounded until we invalidate, the session expires, or the user
/// switches away.
///
/// We start the session in `WatchBreathView.onAppear` and invalidate it on
/// every exit path (cancel, timer completion, or `onDisappear` as a
/// belt-and-suspenders). `start()` is re-entrant — calling it again
/// invalidates any prior session first — so we don't accumulate sessions if
/// the view re-renders.
@MainActor
final class WatchAwakeSession: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?

    func start() {
        // Defensive: drop any previous session before starting a fresh one.
        // Without this, a re-entered `onAppear` (e.g. after a brief sheet
        // re-presentation) would leave the old session orphaned.
        session?.invalidate()
        let new = WKExtendedRuntimeSession()
        new.delegate = self
        new.start()
        session = new
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: WKExtendedRuntimeSessionDelegate
    //
    // All callbacks arrive on a system queue. We don't touch any state here —
    // the breath view manages its own lifecycle — so empty implementations
    // are correct. The delegate methods are required by the protocol; without
    // them the system won't actually start the session.

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {}
}

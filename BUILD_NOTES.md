# Slowbeat — Build Notes

> Originally codenamed **Pulse** during development. Renamed to **Slowbeat** at launch
> (the name "Pulse" was heavily taken on the App Store). Internal target / folder names
> remain "Pulse" — only user-visible display name and copy were updated. Bundle IDs
> (com.parhamkarbasi.Pulse, group.com.parhamkarbasi.Pulse) were intentionally kept to
> avoid App Store Connect / App Group / certificate churn.

**Status:** v1 feature-complete. Every P0 fix, P2 polish item, and P1 surface (Shortcuts / Smart Stack widget / Lock Screen Live Activity / Apple Watch / iOS Focus filter) has shipped. Most recent passes added WatchConnectivity handoff, a redesigned onboarding, a redesigned breathing halo, and the rename to Slowbeat. All three schemes — Pulse (iOS), Pulse WidgetExtension, Pulse-WatchOS Watch App — build clean for their respective simulators.

---

## Iteration 11 — Rename to Slowbeat (May 17 2026)

The App Store has too many apps called "Pulse" — picked **Slowbeat** as the public name. Tagline: **"Pause. Breathe. Begin."**

Renamed user-visible surfaces only; internal target / folder / bundle-ID identity kept stable so App Store Connect records and the App Group capability don't need to be re-created.

### Changed
- `Pulse/Info.plist` — added `CFBundleDisplayName = Slowbeat`; updated the two usage-description strings (calendar, health) to start with "Slowbeat."
- `INFOPLIST_KEY_CFBundleDisplayName` for the widget extension (was "Pulse Widget" → "Slowbeat") and the watch app (was "Pulse-WatchOS" → "Slowbeat"), edited directly in `project.pbxproj`.
- 9 user-visible in-app strings ("Pulse" → "Slowbeat"): AboutSection, PrivacySection, EventTypesSection, two TodayView permission-state messages, two OnboardingView strings (the welcome a11y label and the page-2 body), BreathingView's `eventTitle` default for manual moments, and the `MonitoredCategoriesFilter` description shown in the iOS Focus configuration UI.

### Deliberately unchanged
- Bundle IDs (`com.parhamkarbasi.Pulse`, `com.parhamkarbasi.Pulse.Pulse-Widget`, `com.parhamkarbasi.Pulse.watchkitapp`).
- App Group (`group.com.parhamkarbasi.Pulse`).
- Xcode target names, folder paths, file names, scheme names.
- Internal Swift module / file references that say "Pulse" in MIRROR comments.

The home-screen icon now reads **Slowbeat**; everything else continues to work without re-provisioning.

---

## Iteration 10 — WatchConnectivity sync, onboarding redesign, halo redesign (May 17 2026)

### Watch ↔ iPhone handoff

The watch is no longer standalone. Two flows, both fail-open:

- **Phone → Watch (state):** `PhoneSyncService` uses `WCSession.updateApplicationContext` to push the current next monitored event (title / start / category symbol) plus the user's selected `BreathingPattern.key`. Last-write-wins is the right semantic — the watch only cares about "what's current now." Called from `AppState.publishExternalSurfaces(settings:)`, which is invoked at every place the widget snapshot is also published (bootstrap, EventTypesSection toggle, BreathingMethodSection pattern change).
- **Watch → Phone (completed sessions):** `WatchSyncService.shipCompletedSession(...)` uses `transferUserInfo` after the 60-second wrist breath finishes. The system guarantees delivery, queueing offline until the phone is reachable. The phone-side delegate (background queue) appends the payload to `WatchSessionInbox` (UserDefaults). `AppState.bootstrap()` drains the inbox on the main actor and creates `BreathingSession`s in SwiftData — so watch moments land in History on next phone launch.

Watch home now shows the next event in a small capsule above the Begin button when one has been synced, and the breath uses the user's chosen pattern (Box / Cyclic sigh / Coherent) instead of hardcoded Box. Watch `BreathingPattern.swift` was expanded to mirror all three statics and gain a `from(rawKey:)` lookup.

### Onboarding — full rewrite

Old onboarding was three text-heavy pages that listed features. New onboarding is three pages that **demonstrate** value:

1. **Welcome** — the redesigned `BreathingHalo` runs live with a 6-second autoreverse cadence (slow, contemplative — deliberately slower than the actual 4-second box rhythm). Title "Arrive ready." + one subtitle. Continue.
2. **The trigger** — a `MockEventCard` ("Quarterly review · in 6 min") with a soft 1.8s pulsing border showing what the actual pre-event nudge looks like. Title "Your calendar is the trigger." Primary CTA "Connect calendar" runs the EventKit prompt inline; "Not now" skips.
3. **Yours, only** — three privacy bullets (on-device / no cloud / leave anytime) + "Begin."

Health and notification permissions are deliberately not asked in onboarding any more — they're requested when the user first interacts with those surfaces, so the cold-start prompts stay focused on the core value.

### Halo redesign

Six composited layers (was four) for more depth and life without overdesign:

1. Outer aura (60pt blur, scale +0.32, opacity 0.40 × core).
2. Mid corona (22pt blur, scale +0.12, opacity 0.70 × core).
3. Core sphere (3pt blur, full opacity).
4. **Angular shimmer overlay** — `AngularGradient` of alternating white-opacity stops rotating once per 180s. Adds the sense of light catching a slightly textured surface. Locked at 0° under Reduce Motion (overlay's opacity also goes to 0).
5. **Pearl highlight** — fixed bright spot in the upper-left, offset scaled with the sphere so it stays in the same relative position as the orb grows. Implies a single light source so the eye reads the orb as 3D.
6. **Hold-emphasis ring** — appears only during `emphasized: true` (hold-full phase), a quiet confirmation that the breath reached its top.
7. Thin contour stroke for crisp edge against dark background.

### Bug-fix pass (real-device testing)

- **Live Activity stuck after app close** — `Activity.request` now passes `staleDate: .now + duration + 10s`, so ActivityKit auto-dismisses after the breath would have completed even if the user kills the app. `BreathActivityController.endOrphanedActivities()` runs at bootstrap as defense-in-depth.
- **Settings horizontal scroll on iOS 26** — replaced the dual `.frame(maxWidth:)` trick (which iOS 26's new floating-pill TabView container didn't propagate cleanly) with `containerRelativeFrame(.horizontal) { length, _ in min(length, 560) }` + `.scrollBounceBehavior(.basedOnSize, axes: .horizontal)`. Applied to all three tabs.
- **Mystery non-functional button in Today top-leading** — was a `ToolbarItem(.topBarLeading) Text("Pulse")` wordmark that iOS 26 was rendering as a touch target. Removed; the nav bar is now hidden on Today.

---

## Iteration 9 — External surfaces: Shortcuts, Smart Stack widget, Live Activity, Focus filter (May 16 2026)

### App Intents / Shortcuts (P1.E)

- `StartBreathIntent` (`openAppWhenRun = true`) — opens Pulse and runs the same flow as the "Start a moment without an event" button. `IntentInbox` is a UserDefaults mailbox so the intent survives cold launch — `ContentView` consumes the pending request on first `.task` and every `scenePhase` active.
- `PulseAppShortcuts` (`AppShortcutsProvider`) — exposes three Siri phrases ("Start a breath in Pulse," "Begin a moment in Pulse," "Open Pulse and breathe") and auto-populates the Shortcuts gallery.

### Smart Stack widget + URL deep-link (P1.B)

- App Group `group.com.parhamkarbasi.Pulse` shared between main app and `Pulse WidgetExtension`. `WidgetSnapshot` (Codable, up to 8 events with id / title / start / accentHex / symbol) is published by `AppState.publishWidgetSnapshot()` and read by the widget. `WidgetCenter.shared.reloadAllTimelines()` is called on every write so the widget refreshes promptly.
- `Pulse_Widget.swift` replaces the emoji boilerplate with `PulseNextEventWidget`: three families (`.systemSmall`, `.systemMedium`, `.accessoryRectangular`) all rendering "next event title + relative time" with category-tinted dot. Timeline rolls forward as each event begins. Empty state mirrors Today's "Nothing pressing." copy.
- URL scheme `pulse://breath?eventID=<id>` — `widgetURL` on every entry. Required converting the main app from `GENERATE_INFOPLIST_FILE = YES` to a real `Pulse/Info.plist` because nested-array Info.plist keys (CFBundleURLTypes) don't survive the `INFOPLIST_KEY_` build-setting flow. Added a `PBXFileSystemSynchronizedBuildFileExceptionSet` matching the widget's pattern so the synchronized folder doesn't try to copy Info.plist as both bundle plist and resource.
- `ContentView.handleWidgetURL(_:)` parses `pulse://breath?eventID=...` into `app.pendingEventID` reusing the notification deep-link flow. `pulse://breath` with no eventID starts a manual moment.

### Live Activity for breath in progress (P1.D)

- `BreathLiveActivityAttributes` (mirrored in main app + widget extension — ActivityKit matches activities across processes via type identity). Attributes hold event title / pattern name / total seconds / startedAt; content state is current phase + 0..1 progress + secondsRemaining.
- `Pulse_WidgetLiveActivity` replaces the emoji boilerplate. Lock Screen banner shows wind glyph + event title + remaining seconds across the top, large phase label as the headline, thin linear progress beneath. Dynamic Island expanded shows phase + remaining + progress bar; compact and minimal are wind glyph + countdown.
- `BreathActivityController` (fail-open, `@MainActor`) wraps `Activity.request / update / end`. `BreathingView` starts on `.onAppear`, runs a separate 1 Hz `.task` to push updates to ActivityKit (independent of the visual 30 Hz TimelineView so we don't burn the ActivityKit update budget), and ends on `.onDisappear`.
- `INFOPLIST_KEY_NSSupportsLiveActivities = YES` injected via pbxproj.

### iOS Focus Filter (P1.C)

- `PulseCategoryEntity` (`AppEntity` over `EventCategory`) + `PulseCategoryEntityQuery` surface the seven categories in the iOS Focus configuration UI.
- `MonitoredCategoriesFilter` (`SetFocusFilterIntent`) takes an optional `[PulseCategoryEntity]` (required to be Optional by the protocol). `perform()` writes the resolved set to `FocusFilterStore` (UserDefaults).
- `AppState.effectiveCategories(for:)` returns the Focus-filter set if one is active, otherwise the user's persisted `monitoredCategories`. All three calendar-load callers route through it: bootstrap, TodayView.refresh, EventTypesSection.toggle.
- EventTypesSection shows a soft teal note above the chips when a filter is active: "A Focus filter is overriding these right now."

No competitor in the breathing space uses FocusFilter or `RelevantContext` for Smart Stack — this round shipped three uniquely-Pulse-shaped external surfaces.

---

## Iteration 8 — Foundation hardening + accessibility polish (May 15-16 2026)

### Bug fixes (P0)

- **Silent SwiftData failures** — 13 `try? context.save()` sites swallowed errors. New `PulseStorage.save(_, reason:)` helper logs via `os.Logger` with the call-site reason. All call sites converted.
- **Calendar permission revoked mid-session** — `CalendarService` now subscribes to `.EKEventStoreChanged` (with `MainActor.assumeIsolated` for Swift 6 strict isolation). When access drops, `upcoming` is cleared; the view layer re-renders the permission gate. TodayView also reacts to access flipping to granted with an immediate reload.
- **Recurring / declined event leaks** — `loadUpcoming` filters out events the current user declined (`EKParticipant.participantStatus == .declined`) and deduplicates mirror copies (same title within 60 seconds across calendars).
- **Past-start events shown as Next up** — events whose `start <= now` are now filtered. The 9 AM meeting EventKit still returns at 9:02 no longer flips Today.
- **Manual "moment without an event" orphan** — `AppState.manualMoment()` reuses the same placeholder if dismissed and re-tapped within 5 minutes. Cleared on completion.
- **Notification permission stale across launches** — `AppState.bootstrap()` now calls `refreshPermissions()` which re-reads calendar + notification authorization state, so iOS Settings toggles propagate without a process relaunch. (HealthKit deliberately doesn't expose read-permission status — Apple privacy design.)

### Settings refactor

`SettingsView.swift` went from **487 lines → 25 lines**. Each section is now its own file under `Features/Settings/Sections/` (BreathingMethodSection, DuringTheBreathSection, EventTypesSection, RemindersSection, PermissionsSection, PrivacySection, AboutSection). Shared `SettingsSectionCard` wrapper centralises the header + GlassCard pattern. `FlowLayout` extracted to its own file. Adding a future Settings section is now one new file + one line in the body.

### Accessibility & polish (P2)

- IntentionView VoiceOver label fix — was reading "If — I'm asked something I don't know" (the dash was a visual cue baked into the label); now reads "If" + the placeholder as natural value + an example hint.
- RitualIntroView mood chips — `.accessibilityHint` added so VoiceOver users hear what tapping does in both selected and unselected states.
- BreathingView time row — exposes both seconds-remaining AND percentage-complete via `accessibilityValue` (was only seconds).
- RitualHostView halo opacity transition between stages now respects Reduce Motion (1.6s ease-in-out becomes immediate snap).
- Onboarding evidence line added under the three steps on "How it works": *"Slow-paced breathing has 12+ randomised trials and consistent meta-analytic support."*

---

## Iteration 5 — Phase-Textured Haptics (Core Haptics)

The breath now has a tactile layer: a soft rising hum on inhale, a barely-perceptible transient at the top of hold, a falling pulse on exhale, silence on rest. Designed so the user can do the ritual eyes-up if they want — the haptic carries the rhythm.

### Implementation

`Services/HapticEngine.swift` *(new)* — `@Observable @MainActor` service over `CHHapticEngine`. The entire breath sequence is built as a single `CHHapticPattern` with `CHHapticParameterCurve`s for intensity envelopes (0→1 on inhale, 1→0 on exhale). Played once via `CHHapticAdvancedPatternPlayer.start(atTime: .immediate)`. Stops on `BreathingView.onDisappear`.

### Intensity tuning

Kept deliberately gentle — base intensities 0.25 (hold) / 0.35 (exhale) / 0.40 (inhale), sharpness 0.20–0.30. Designed to feel like a soft wave on the wrist, not a notification buzz. Matches the user's earlier love for iBreathe's haptics but adds *phase texture* (different feel per phase) which iBreathe doesn't have.

### Fail-open behavior

`CHHapticEngine.capabilitiesForHardware().supportsHaptics` is checked first. On the simulator and pre-iPhone-7 hardware, every method silently no-ops. The visual breath is unaffected.

---

## Iteration 6 — Notification Tap → Direct to Breath

Tapping a Pulse reminder notification now opens the app directly into the ritual for the event the reminder was for, instead of just landing on Today.

### Implementation

`Services/PulseNotificationDelegate.swift` *(new)* — small `NSObject` that conforms to `UNUserNotificationCenterDelegate`. Pulls `eventId` out of `userInfo`, hands it to `AppState.pendingEventID`.

`Services/AppState.swift` — now imports `UserNotifications`, owns a `PulseNotificationDelegate` (registers it as `UNUserNotificationCenter.current().delegate` in `init`), exposes `var pendingEventID: String?`.

`ContentView.swift` — `TabView` now has a `selectedTab` binding, observes `app.pendingEventID`. When a tap arrives, refreshes the calendar if needed, switches to the Today tab, sets `activeRitualEvent` so the existing `navigationDestination` push runs.

### When the tap delivers

Works in three scenarios: app foregrounded (banner shown via `willPresent`), app backgrounded (`didReceive` fires on return), app killed cold-start (`didReceive` fires after `init`). All three paths feed `pendingEventID`; the deep-link handler is idempotent.

### Userinfo key

The `NotificationService` already wrote `userInfo["eventId"] = event.id` when scheduling, so no changes there.

---

## Iteration 7 — Eyes-Up Mode

Optional toggle in Settings. When on, the breath screen dims aggressively so the haptic leads and the user can glance rather than stare. Designed for hallways, walking to a meeting, stage wings, anywhere the user can't comfortably look at the phone.

### Implementation

`Models/PulseSettings.swift` — added `eyesUpMode: Bool?` (optional for clean migration) with a non-optional `eyesUp` accessor.

`Features/Ritual/BreathingView.swift` — accepts `eyesUp: Bool` parameter. When true: phase label opacity 0.45, halo opacity 0.30, time-remaining row and seconds-in-phase hidden, Stop button at 0.45 opacity. The breath logic is unchanged; only the chrome dims.

`Features/Settings/SettingsView.swift` — new "During the breath" section with two toggles: Haptic guidance + Eyes-up mode. Sits right under Breathing method.

### Why this is the right default-off

Eyes-up is a deliberate stance. Default-off keeps the first-time user's experience visual and clear; once they discover it, it's there for them.

---

## What was NOT shipped, and why

**Walk-sync (was in original Iter 6 list).**
Detect walking via `CMMotionActivityManager` and align breath pacing to footstep cadence. Skipped on purpose: dynamically changing phase durations would break the *validated* breathing protocols (especially Coherent's 6bpm resonance frequency, which is what makes it work). The cadence is the active ingredient. If the user is walking, they get the same evidence-based pattern; their footsteps don't matter to the lungs.

**Watch app target.**
Requires Xcode UI (File → New → Target → Watch App). Cannot be added programmatically. To enable later:
1. Xcode → File → New → Target → "Watch App for iOS App" (not "Watch App").
2. Move the `BreathingView`, `BreathingHalo`, `BreathingPattern`, and `HapticEngine` files into a shared target membership.
3. Build a minimal Watch view that hosts `BreathingView` haptic-only (`eyesUp: true`, no halo). The haptic engine works the same on watchOS.
4. Add a deep-link from Watch app to phone app for the after-breath intention capture, OR keep the watch experience purely haptic and capture intention on phone afterwards.

This is genuinely just a target-creation step plus a thin host view — most of the code already runs on watchOS as-is.

---



---

## Iteration 4 — Circumplex-Grounded Pre-Mood + State-Tinted Halo + Tighter Palette

Three changes driven by the affect-measurement literature, the iso-principle (music therapy), and color harmony theory. The previous `PreMood` cases (calm/alert/racing/scattered) were unprincipled — "scattered" is a cognitive control state, not an affective one. Replaced with the four quadrants of Russell's (1980) circumplex model.

### Change A: Russell circumplex affect model

`PreMood` now reflects the [Russell 1980 circumplex](https://pdodds.w3.uvm.edu/research/papers/others/1980/russell1980a.pdf) — emotions live in a 2D space of valence (negative↔positive) × arousal (low↔high). Each case is one quadrant:

| Case | Valence | Arousal | Replaces |
|---|---|---|---|
| `.anxious`   | negative | high | racing |
| `.energized` | positive | high | alert |
| `.settled`   | positive | low  | calm |
| `.flat`      | negative | low  | scattered |

`PreMood.resolve(rawValue:)` decodes both the new raw values and the legacy ones, so existing sessions don't break. `valence` and `arousal` (Double, −1...1) are exposed for future analysis. Marked `nonisolated` so SwiftData property accessors (off the main actor) can call it.

### Change B: State-tinted halo (hue + saturation modulation)

> **Iter 4.1 retune:** initial implementation modulated *saturation only*, keeping all four halos in the same lavender-purple hue range. Through the halo's multi-layer blur rendering they looked nearly identical on screen. Retuned to spread the four variants across ~150° of the color wheel while keeping saturation low across all of them. Each variant is now clearly distinct visually. Trade-off acknowledged: pure-saturation modulation was theoretically cleaner; hue shifts pull in the iso-principle extrapolation more strongly. Gradient opacities also raised from (0.85, 0.55) to (0.92, 0.65) to preserve color through the blur layers.

The breathing halo's color now shifts based on the user's reported pre-mood. Evidence basis:

- **Direct evidence**: Color *saturation* affects physiological arousal regardless of hue ([Wilms & Oberfeld 2018](https://link.springer.com/article/10.1007/s00426-017-0880-8)). This is what we modulate.
- **Adjacent evidence**: The music-therapy iso-principle ([Heiderscheit & Madson 2015](https://academic.oup.com/mtp/article/33/1/45/1134120), [Starcke & von Georgi 2024](https://journals.sagepub.com/doi/10.1177/10298649231175029)) motivates the *direction* of each shift — meet the user at their current state, then guide toward target. Note: limited direct evidence for color iso-principle specifically; this is extrapolation from music.

Four halo variants in `Theme`:

| Mood | Halo color | Wheel pos | Rationale |
|---|---|---|---|
| `.anxious` | deep indigo-blue (0.42, 0.50, 0.80) | ~225° | strongest down-regulation; "night sky" tones |
| `.energized` | cool blue-teal (0.38, 0.72, 0.78) | ~185° | focused/cool without arousing |
| `.settled` | base lavender → blush (0.75, 0.70, 0.98) | ~265° | no shift; already in target state |
| `.flat` | soft sunset-rose (0.96, 0.72, 0.72) | ~5° | the one intentional warm tint, reserved for the one state that benefits from uplift; deliberately desaturated to avoid arousing |

The halo gradient is resolved via `Theme.haloGradient(for: PreMood?)`. Used in both `BreathingHalo` (the breathing orb) and `RitualHostView`'s background glow during the breath stage.

### Change C: Tighter analogous palette

Pulled `presentation` from dusty olive (~80° on the color wheel, breaking the cool arc) to soft sage (~130°). All `EventCategory` accents now sit within the cool arc 130°–290° on the HSL wheel, all at low-to-medium saturation — a true analogous palette.

| Category | Before (Iter 3) | After (Iter 4) | Wheel position |
|---|---|---|---|
| presentation | dusty olive (0.72, 0.74, 0.60) | **soft sage (0.62, 0.78, 0.66)** | ~130° |
| exam | dusty teal | unchanged | ~175° |
| meeting | soft cornflower (0.62, 0.76, 0.92) | **slightly bluer (0.58, 0.74, 0.92)** | ~210° |
| interview | muted lilac (0.72, 0.66, 0.88) | **slightly more saturated (0.72, 0.66, 0.90)** | ~250° |
| performance | soft plum (0.66, 0.62, 0.84) | **slightly warmer (0.68, 0.60, 0.86)** | ~265° |
| other | pale lavender (0.78, 0.78, 0.90) | **slightly desaturated (0.78, 0.74, 0.90)** | ~270° |
| conversation | dusty mauve (0.74, 0.72, 0.80) | **more violet (0.82, 0.70, 0.86)** | ~290° |

Analogous palettes can fail WCAG contrast (luminance overlap warning from [LogRocket](https://blog.logrocket.com/ux-design/using-analogous-color-scheme-ux-design/)) — verified all accents pass against the dark navy background.

### Files changed (Iter 4)

| File | Change |
|---|---|
| `Models/MoodAndOutcome.swift` | `PreMood` cases reworked to circumplex quadrants. `valence`/`arousal` computed. `resolve(rawValue:)` decodes legacy raw values; marked `nonisolated`. |
| `Models/BreathingSession.swift` | `preMood` accessor uses `PreMood.resolve` so old data still reads. |
| `Models/EventCategory.swift` | Accent palette tightened for analogous harmony. |
| `DesignSystem/Theme.swift` | Added `haloAnxious*`, `haloEnergized*`, `haloFlat*` color tokens and `haloGradient(for:)` resolver. |
| `DesignSystem/BreathingHalo.swift` | Now accepts a `mood: PreMood?` parameter and tunes its gradient via `Theme.haloGradient(for:)`. |
| `Features/Ritual/BreathingView.swift` | Accepts `mood: PreMood?` and forwards to `BreathingHalo`. |
| `Features/Ritual/RitualHostView.swift` | Passes `preMood` to `BreathingView`. Background glow during the breath stage also state-tinted. |
| `Features/Ritual/RitualIntroView.swift` | Updated prompt copy and helper text to reflect the new four-quadrant picker. |

---



---

## Iteration 3 — Evidence-Aligned Palette

Replaced color values in `Theme.swift` and `EventCategory.swift` based on the color-psychology literature. **No structural changes**; this is purely a values refresh.

### What the literature actually supports

- **Saturation drives arousal more than hue** (Wilms & Oberfeld 2018; Royal Society Open Science 2023). A saturated blue is more arousing than a desaturated red.
- **Cool hues (blue, green) measurably lower HR/BP** vs. warm hues. Healthcare environment studies are consistent.
- **Red impairs performance and increases arousal** (Elliot et al. 2007 — 4 experiments). Never use for calming.
- **Pure black isn't calming** either — HR increases in very dark rooms vs. medium lightness.

### Debunked, deliberately avoided

- **"Baker-Miller pink"** as a calming color. Original Schauss findings have failed to replicate (Genschow et al. 2014); the previous `performance` accent was shifted to soft plum.

### Color changes

| Token | Before | After | Rationale |
|---|---|---|---|
| `Theme.warmA` (primary-action gradient start) | coral 0.98, 0.62, 0.50 | soft lavender 0.68, 0.66, 0.88 | Was the highest-saturation warm color in the palette — worst combo for a calming app. |
| `Theme.warmB` (primary-action gradient end) | amber 0.96, 0.78, 0.45 | periwinkle 0.62, 0.74, 0.92 | Same — replaced with a cool, low-saturation companion to lavender. |
| `Theme.haloB` (halo gradient end) | blush 0.98, 0.78, 0.92 | softer rose-lilac 0.92, 0.82, 0.96 | Pulled toward purple, away from any "pink-as-calming" implication. |
| `Theme.coolA / coolB` | teal / mint | unchanged | Already evidence-aligned. |
| `EventCategory.presentation` accent | coral 0.95, 0.62, 0.46 | dusty olive 0.72, 0.74, 0.60 | Desaturated; still distinct from the other six. |
| `EventCategory.conversation` accent | peach 0.95, 0.78, 0.65 | dusty mauve 0.74, 0.72, 0.80 | Desaturated; cooled. |
| `EventCategory.performance` accent | pink 0.92, 0.65, 0.78 | soft plum 0.66, 0.62, 0.84 | Pink-as-calming is debunked; plum is cool and low-saturation. |
| `EventCategory.interview / exam / meeting / other` | various cool hues | mildly desaturated | Already cool; saturation lowered slightly to harmonize. |

The token names `warmA / warmB / warmGradient` were kept (even though they're no longer literally warm) to avoid an invasive rename across PulseButton, BreathingView, HistoryView, SettingsView, etc. The doc comment in Theme.swift documents the change.

---



---

## Iteration 1 — Reverted

The Carry Word concept (a single contextual word handed to the user after the breath) was built and then **removed** after an evidence review. The closest research support (Hatzigeorgiadis 2011 meta-analysis on cue-word self-talk, d = 0.48) is in **athletic-performance contexts only** — extrapolating to "one word before a meeting" had no direct empirical support. Pulse is being built as an evidence-based intervention, not a vibes-based one, so the feature was pulled rather than shipped on extrapolation.

---

## Iteration 2 — Implementation Intentions + Multi-Method Breathing

Two changes driven by direct empirical evidence.

### Change A: Implementation-intention prompt (replaces Carry Word)

After the breath, the user fills in one if-then plan: *"If \<situation\>, I will \<response\>."* Grounded in the strongest finding in this corner of behavioral science:

- **Gollwitzer & Sheeran, 2006** meta-analysis: 94 independent tests, >8,000 participants, **d = 0.65** (medium-to-large). Implementation intentions reliably translate intentions into action. The effect is *additional* to simply having a goal — the if-then format itself is the active ingredient.

The IntentionView is deliberately concrete and short: two text fields, category-aware example placeholders (e.g. interview → "If I'm asked something I don't know" / "say so honestly, then think"), save-or-skip. The prompt is "Picture the moment. Pick one thing that might happen — then decide now how you'll meet it."

### Change B: Multi-method breathing engine

Pulse now ships three evidence-backed breathing patterns. The user picks one in Settings; it applies to all future rituals.

| Pattern | Cadence | Evidence |
|---|---|---|
| **Box** *(default)* | 4-4-4-4 | Slow-paced breathing with direct RCT support for acute state change. Currently the most familiar pattern. |
| **Cyclic Sigh** | 2-1-6-0 | **Strongest direct evidence for mood improvement** — Balban et al., *Cell Reports Medicine* 2023. Significantly beat box breathing and mindfulness meditation in their RCT (n=111). |
| **Coherent** | 5-0-5-0 | ~6 bpm aligns breathing with cardiac–respiratory resonance frequency, maximizing HRV (Lehrer et al.; Steffen et al.). |

4-7-8 deliberately excluded: only small studies in clinical populations (post-bariatric, COPD), no large healthy-adult RCTs.

### Files changed

| File | Change |
|---|---|
| `Models/BreathingSession.swift` | Removed `carryWord` + `eventEndAt`. Added `intentionIf`, `intentionThen`, `breathingPatternRaw` (all optional). |
| `Models/BreathingPattern.swift` *(new)* | Struct describing one breathing method: phase durations + display labels + VoiceOver phrasing + one-line evidence note. Three statics: `.box`, `.cyclicSigh`, `.coherent`. |
| `Models/PulseSettings.swift` | Added optional `breathingPatternRaw` (defaults to "box"). |
| `Services/AppState.swift` | Removed `activity` service (no longer needed without Live Activity). |
| `Features/Ritual/IntentionView.swift` *(new)* | Two-field if-then capture. Category-aware example placeholders. |
| `Features/Ritual/BreathingView.swift` | Now takes a `BreathingPattern` parameter. Phase math generalized to handle asymmetric durations (cyclic sigh is 2-1-6-0) and zero-duration phases (coherent has no holds). Phase labels come from the pattern. |
| `Features/Ritual/RitualHostView.swift` | Reads the active pattern from `PulseSettings` and passes it to `BreathingView`. Session creation records the pattern used. `.reflect` stage hosts `IntentionView`. |
| `Features/History/HistoryView.swift` | `SessionRow` now shows the if-then plan inline below the metadata row (tinted with the category accent). |
| `Features/Settings/SettingsView.swift` | New "Breathing method" section at the top of Settings — three radio rows with name, summary, and evidence line. Tapping switches the active pattern. |

### Files deleted

- `Models/CarryWord.swift`
- `Models/CarryWordActivityAttributes.swift`
- `Services/LiveActivityService.swift`
- `Features/Ritual/CarryWordView.swift`

The Xcode project uses synchronized folder groups, so filesystem deletions removed these from the build automatically — no project file edits needed.

### Backward compatibility

`BreathingSession.carryWord`, `BreathingSession.eventEndAt`, and the Activity-related code were live for the brief Iter 1 build but have been removed cleanly. New optional fields (`intentionIf`, `intentionThen`, `breathingPatternRaw`) are SwiftData lightweight migrations — they appear as `nil` for any pre-existing sessions, no schema migration step required.

---



A calm, single-purpose iOS app for a 60-second check-in before important moments. Built end-to-end as a complete, runnable iOS app; the architecture is set up so that a watchOS target can be added later in one Xcode step without code reorganization.

---

## What was built

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Project structure & SwiftData models | ✅ | `BreathingSession`, `PulseSettings`, plus `EventCategory`, `PreMood`, `Outcome` enums. Replaced default `Item` placeholder. |
| 2 | Design system | ✅ | Dark-first dual-tone gradient palette, SF Rounded typography, `GlassCard`, `PulseButton`, `BreathingHalo`, `pulseBackground()` modifier. |
| 3 | Services | ✅ | `CalendarService` (EventKit, iOS 17+ full-access API), `HealthService` (read-only HR), `NotificationService` (local reminders), `AppState` coordinator. All `@Observable`. |
| 4 | Today screen | ✅ | Time-aware greeting, optional heart-rate chip, "Next up" featured card + "Later" list, manual "moment without an event", permission gate states. |
| 5 | Ritual intro | ✅ | Event header, optional HR context, optional 4-chip pre-mood picker, "Begin 60 seconds" primary action. |
| 6 | Breathing screen (keystone) | ✅ | 60s box-breathing (4-4-4-4 cycle) via `TimelineView`. Halo expands/contracts with phase. Reduce-Motion fallback (text-only pulse). Soft haptic on completion. Idle timer disabled during breath. |
| 7 | Reflection + Summary | ✅ | Three soft outcome cards (smooth/steady/tough), optional note, "Save" or "Skip for now". Summary celebrates the moment without scoring it. |
| 8 | History + Pattern chart | ✅ | Swift Charts weekly bar chart colored by average outcome, current-day streak chip, swipe-to-delete session list, sheet-style late reflection. |
| 9 | Settings | ✅ | Category chip toggles, reminder timing picker, three permission rows (calendar / health / notifications), explicit privacy facts, destructive "Clear all moments". |
| 10 | Onboarding + app wiring | ✅ | Three-page onboarding (welcome → how it works → permissions). TabView root, `.scenePhase`-driven refresh, first-run sheet. |
| 11 | Info.plist usage strings | ✅ | `NSCalendarsFullAccessUsageDescription` and `NSHealthShareUsageDescription` injected directly into both build configs of `project.pbxproj` (uses synchronized root group + auto-generated Info.plist). |
| 12 | Accessibility + polish | ✅ | VoiceOver labels on every interactive element, Reduce Motion path in `BreathingHalo` and `BreathingView`, Dynamic Type via `system(.rounded)` fonts, large-tap targets (44–56pt), colors checked in both schemes. |

---

## Key design decisions

**Single-purpose surfaces.** Every screen has one primary thing. Today shows you what's next and one button. Breathing shows one word and one halo. Reflection shows three cards. The user is never asked to scan a dashboard.

**Box breathing (4-4-4-4) over 4-7-8.** Box breathing has a calmer, more symmetric cadence and fits the "ritual" framing better than the more clinical 4-7-8. Five clean cycles fit the 60-second window with no awkward partial cycle.

**Dark-first calm gradient.** The "before an event" moment usually happens in fluorescent rooms, hallway corners, or right before standing up. The dark indigo→plum surface is soft on the eyes and feels intimate. Light mode mirrors with cream→lavender.

**Warm gradient for "begin", cool gradient for "done".** Two-emotion gradient system — coral/amber to invite action, teal/mint to acknowledge completion. The halo itself uses a separate lavender/blush radial gradient so it feels alive and slightly otherworldly.

**No medical or clinical language.** "Moment", "ritual", "check-in", "nudge", "settle". Never "stress detection", "anxiety", "intervention". The breathing label is "Breathe in / Hold / Breathe out / Rest" — not numbers.

**Privacy by construction, not by promise.** SwiftData container is initialized with `cloudKitDatabase: .none`. The `UpcomingEvent` projection is built deliberately to strip everything the ritual doesn't need from the underlying `EKEvent`. The Settings screen lists four specific privacy facts plus a one-tap "clear all moments" destructor.

**Accessibility paths exist on day one.** The `BreathingHalo` reads the `accessibilityReduceMotion` environment and switches to a calm opacity-only pulse. The breathing phase label reads "Breathe in slowly" / "Hold gently" to VoiceOver instead of the visual one-word version. Every chip carries an "on/off" or "selected" hint. Buttons are 44pt+ minimum.

---

## Architecture

```
Pulse/
  PulseApp.swift          ← @main; SwiftData container w/o CloudKit
  ContentView.swift       ← TabView root + onboarding sheet + scenePhase refresh
  Models/
    EventCategory.swift   ← 7 categories + display/symbol/accent/keywords
    MoodAndOutcome.swift  ← PreMood, Outcome enums
    BreathingSession.swift← @Model: the persisted "moment"
    PulseSettings.swift   ← @Model: single-row settings doc
  Services/
    UpcomingEvent.swift   ← Privacy-respecting projection (no EKEvent stored)
    CalendarService.swift ← EventKit; uses iOS 17 requestFullAccessToEvents
    HealthService.swift   ← HealthKit read-only HR; graceful "unavailable" path
    NotificationService.swift ← Local reminders w/ stable identifier prefix
    AppState.swift        ← Coordinator; bootstrap() refreshes everything
  DesignSystem/
    Theme.swift           ← Light/dark colors; warm/cool/halo gradients
    PulseTypography.swift ← Rounded font tokens + pulseBackground() modifier
    GlassCard.swift       ← Reusable glass surface
    PulseButton.swift     ← warm / cool / ghost styles
    BreathingHalo.swift   ← The animated orb (Reduce-Motion aware)
  Features/
    Today/      TodayView, UpcomingEventCard
    Ritual/     RitualHostView, RitualIntroView, BreathingView, ReflectionView, RitualSummaryView
    History/    HistoryView, PatternChartView
    Settings/   SettingsView (incl. FlowLayout)
    Onboarding/ OnboardingView
```

The `@Observable` service classes are MainActor-isolated by the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting, which simplifies SwiftUI integration considerably.

---

## Limitations encountered, and how they were handled

| Limitation | Mitigation |
|---|---|
| No watchOS target was pre-created in the Xcode project | Built iOS-first with the same emotional UX. The `BreathingView`, `BreathingHalo`, and ritual flow translate to Watch with no logical changes — just smaller frames. To add Watch later: in Xcode → File → New → Target → Watch App for iOS App. |
| iPhone alone can't read **live** heart rate | Show only **most recent** HR sample from the last hour (`hasFreshReading`), framed as "context", never as a stress indicator. If older than 1h, hide the chip entirely. |
| HealthKit requires a capability that isn't enabled in the project yet | `HealthService` returns `.unavailable` cleanly; the rest of the app works perfectly without it. To enable: Xcode → Pulse target → Signing & Capabilities → + Capability → HealthKit. The Info.plist usage string is already wired. |
| EventKit access prompt requires `requestFullAccessToEvents` on iOS 17+ | Service uses `#available` to call the modern API; older fallback included for safety. |
| Switch-as-expression with a preceding `let` was rejected by Swift 5 language mode | Restructured greeting to put the switch as the sole body expression with explicit returns. |
| `@ViewBuilder content:` parameter must be `@escaping` when passed into a stored-closure view | Marked the `section(…)` helper's content parameter `@escaping`. |

---

## What's *not* in this build, and why

- **watchOS target** — requires Xcode UI to add; deferred so iOS app is delivered complete.
- **WidgetKit / Smart Stack** — out of scope for the 120-min budget.
- **Notifications open the ritual directly** — currently they nudge the user to open the app; deep-linking via `UNNotificationContent.userInfo.eventId` is wired but not yet routed in `ContentView`.
- **CloudKit / iCloud sync** — deliberately omitted (privacy decision).

---

## To run

1. Open `Pulse/Pulse.xcodeproj` in Xcode.
2. Optional, for the heart-rate context chip: target → Signing & Capabilities → + Capability → **HealthKit**.
3. Run on iOS Simulator or device.
4. First launch shows the three-page onboarding. Grant Calendar to see real events; grant Notifications to get nudges.

---

## File-by-file line summary

```
Models/EventCategory.swift          73 lines
Models/MoodAndOutcome.swift         50 lines
Models/BreathingSession.swift       60 lines
Models/PulseSettings.swift          29 lines
Services/UpcomingEvent.swift        13 lines
Services/CalendarService.swift      69 lines
Services/HealthService.swift        81 lines
Services/NotificationService.swift  70 lines
Services/AppState.swift             49 lines
DesignSystem/Theme.swift            71 lines
DesignSystem/PulseTypography.swift  47 lines
DesignSystem/GlassCard.swift        25 lines
DesignSystem/PulseButton.swift      45 lines
DesignSystem/BreathingHalo.swift    44 lines
Features/Today/UpcomingEventCard    79 lines
Features/Today/TodayView            217 lines
Features/Ritual/RitualHostView      80 lines
Features/Ritual/RitualIntroView     112 lines
Features/Ritual/BreathingView       143 lines
Features/Ritual/ReflectionView      127 lines
Features/Ritual/RitualSummaryView   39 lines
Features/History/PatternChartView   105 lines
Features/History/HistoryView        153 lines
Features/Settings/SettingsView      280 lines
Features/Onboarding/OnboardingView  175 lines
PulseApp.swift                      38 lines
ContentView.swift                   54 lines
```

Approximately **2,200 lines** of Swift across 27 files. Zero dependencies beyond Apple's frameworks (SwiftUI, SwiftData, EventKit, HealthKit, UserNotifications, Charts).

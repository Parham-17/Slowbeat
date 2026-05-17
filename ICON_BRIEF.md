# Slowbeat — App Icon Brief

A reference for AI image generators (Midjourney, DALL-E, Imagen, etc.) to produce
icon concepts that match Slowbeat's vibe. Copy whatever sections are useful into
your prompts.

---

## The app in one line

**Slowbeat — Pause. Breathe. Begin.**
A 60-second guided breath ritual that surfaces *before* important moments on
your calendar.

## What it does

Slowbeat watches your calendar for events that matter — presentations, interviews,
hard conversations, performances, exams — and offers a single 60-second
box-breathing ritual right before each one. The breath is guided visually (a soft
breathing orb) and tactilely (phase-textured haptics: rising hum on inhale, soft
tap at the top of hold, falling pulse on exhale). After the breath, the user
writes one if-then plan ("If X happens, I will Y") to carry into the moment.

It's not a meditation library, not a content app, not a wellness tracker. It is
**a single ritual, performed at a specific moment**.

## Core experience

- Calm, dark-first interface (lavender / indigo gradient backgrounds)
- A soft glowing **halo** is the visual centrepiece of the breath ritual — it
  grows on inhale, holds on hold, shrinks on exhale, rests on rest
- Minimal, intimate, focused — one thing per screen
- Haptics are first-class — the haptic carries the rhythm so users can do the
  ritual eyes-up if they want
- Not sedated, not sleepy — the target emotion is *grounded and ready for
  what's next*, not *relaxed and drowsy*

## Aesthetic principles

- **Minimal over content-rich.** Empty space is intentional.
- **Calm, not sedated.** Grounded readiness, not sleep.
- **Soft, organic, layered.** Multiple subtle blur layers, gentle gradients,
  a sense of depth without busyness.
- **Original.** Must NOT visually echo Calm, Headspace, Breathwrk, Othership,
  iBreathe, Oak, Apple Mindfulness, or Insight Timer.

## Color palette

Tuned from the color-psychology literature (saturation drives arousal more than
hue does; cool low-saturation hues reduce arousal). Hex values:

**Backgrounds (dark mode):**
- `#0A0D24` (deep night indigo) — primary background top
- `#1A1238` (plum night) — primary background bottom
- `#2C1A4D` (royal indigo) — accent

**Primary halo / breath orb:**
- `#BFB3FA` (soft lavender) — main halo colour
- `#EAD2F5` (rose-lilac) — halo highlight
- `#A8B3E6` (periwinkle) — primary action gradient end
- `#ADA8E0` (soft lavender) — primary action gradient start

**Completion / restorative:**
- `#80CCC8` (soft teal) — completion gradient start
- `#9EE0D6` (mint) — completion gradient end

**State-tinted halo variants** (for the in-app pre-mood picker, also reference
for icon mood):
- `#6B80CC` (deep indigo-blue) — Anxious mood
- `#5EB7C7` (cool blue-teal) — Energized mood
- `#F5B7B7` (sunset rose) — Flat mood (the one warm spot, kept desaturated)

## What the icon should evoke

- A soft, glowing sphere of light suspended in calm darkness
- A held breath, a pause, a single focal point of stillness
- Layered, organic depth (think jellyfish translucency, aurora softness, a
  lit pearl, sunrise through fog)
- Quiet authority — the icon belongs on the home screen of a serious person,
  not a self-care fluff app

## What to AVOID

Hard constraints — these would make the icon look derivative:

- **No human silhouettes / heads / brains** — clinical & overdone
- **No leaves, lotuses, flowers, mandalas** — wellness clichés
- **No clock faces, hourglasses, stopwatches** — too literal
- **No hearts, EKG lines, pulse waveforms** — clinical/medical
- **No petals folding** (Apple Mindfulness pattern)
- **No simple geometric circle on solid color** (iBreathe pattern)
- **No landscape vistas / sunsets / mountains** (Calm / Othership pattern)
- **No mascots, cartoons, faces** (Headspace pattern)
- **No app name in the icon** — Apple discourages text
- **No saturated reds, oranges, hot pinks** — these increase arousal
  (Elliot 2007), wrong for a calming app

## Visual reference points (draw from these, NOT from breathing apps)

- A **single glowing pearl** with soft inner light
- An **aurora** seen through frosted glass
- A **jellyfish bell** — translucent, layered, gently lit
- A **paper lantern** at dusk
- The **moon halo** through high cirrus cloud
- A **light orb** in dark velvet
- **Vantablack with a single pinprick of softly-spreading light**

## Technical specs (App Store)

- Square 1024 × 1024 px
- No transparency (PNG with solid background)
- No rounded corners (Apple applies the corner mask system-wide)
- No text overlays
- Readable at 29 × 29 px (the smallest the system shows it)
- Solid background or a tight gradient — avoid intricate detail that
  disappears at small sizes

## Existing concepts to reference / improve on

The `AppIconConcepts/` folder in this repo contains four earlier explorations:
- `01_halo.{svg,png}` — the breathing-halo direction
- `02_rings.{svg,png}` — concentric rings
- `03_dawn.{svg,png}` — dawn-gradient direction
- `04_breath.{svg,png}` — breath-stylized concept
- `_grid.png` — all four side by side
- `_home_preview.png` — how they look on a home screen

Use these as starting points; the brief above explains the direction we want to push them in.

---

## Ready-to-paste prompt (Midjourney / DALL-E / Imagen style)

> A minimal iOS app icon for "Slowbeat", a 60-second breath ritual app. A soft
> glowing pearl-like sphere of light suspended in a deep indigo-purple void.
> The sphere is translucent and layered, like a jellyfish bell or an aurora
> seen through frosted glass, with a subtle inner highlight in the upper-left
> suggesting a single light source. Soft lavender (#BFB3FA) and rose-lilac
> (#EAD2F5) inner glow fading to deep night-indigo (#0A0D24) background.
> Calm, contemplative, professional. No text, no faces, no leaves, no clocks,
> no hearts, no waveforms. Square 1:1 composition, single focal element,
> read clearly at small sizes. Style: organic minimalism, soft gradients,
> not flat-design, not photo-realistic.

---

## After you have candidates

When you have 3-5 strong directions you like:
1. Drop them into `AppIconConcepts/` in this repo
2. Pick the winner
3. I'll generate the full size set (all 17 sizes Apple requires) into
   `Pulse/Pulse/Assets.xcassets/AppIcon.appiconset/`

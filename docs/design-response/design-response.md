# Posture · Design Response

**Direction:** Daylight
**Owner:** Design pass against v0.1.0 handoff
**Date:** 2026-05-15
**Companion files:** `Daylight - Design Pass.html` (interactive review surface) · `mockups/` (b/w composition PNGs) · `change-list.md` (engineering checklist)

---

## 1. Identity proposal

**Daylight** is a calm, paper-and-sage wellness identity. The mood is closer to **Oak**, **Reflectly**, and the visual restraint of **Things 3** than to Calm/Headspace's marketing-led photography, or to Duolingo-style gamification.

The anchor metaphor is **a horizon line** — uprightness as the level of the sun. The three-step quality scale (`aligned · drifting · resting`) replaces the green/amber/red traffic light and is intentionally non-imperative: a posture reading is an observation, never a command.

The brand reads quiet, intelligent, and slightly slow — a tool you reach for once an hour, not a streak you defend. Type pairing is system-only: SF Serif (display, sparingly) + SF Pro Rounded (numerals & rhythm) + SF Pro (UI). No licensed font ships.

The brand gradient is **cut**. So is the SF-Symbol traffic-light icon set on result screens.

---

## 2. Color system

### Brand · Light

| Token | Hex | Use |
|---|---|---|
| `paper` | `#F6F1E8` | Page background. Replaces `Color(.systemBackground)`. |
| `paper-2` | `#EFE7D6` | Card surface. Replaces `Color(.secondarySystemBackground)`. |
| `paper-3` | `#E5DDC9` | Hairline borders, dividers. Replaces `Color(.systemFill)` for non-control fills. |
| `ink` | `#1F1B16` | Primary text. Replaces `Color(.label)`. |
| `ink-2` | `#5A5247` | Secondary text. Replaces `Color(.secondaryLabel)`. |
| `ink-3` | `#948A7A` | Tertiary / disabled. Replaces `Color(.tertiaryLabel)`. |
| `sage` | `#6B8E7A` | Primary brand · CTA, "aligned" quality. Replaces `brandPrimary`. |
| `sage-tint` | `#DCE6DD` | Tonal sage surfaces (Pro card, "aligned" result tint). |
| `sand` | `#C68F4D` | "drifting" quality. Replaces `borderline`. |
| `clay` | `#B8654A` | "resting" quality. Replaces `bad`. Warmer + less alarming than the current red. |

### Brand · Dark

| Token | Hex |
|---|---|
| `paper` | `#171614` |
| `paper-2` | `#211F1B` |
| `paper-3` | `#2A2722` |
| `ink` | `#EFE9DC` |
| `ink-2` | `#B7AE9D` |
| `ink-3` | `#7C7464` |
| `sage` | `#8FB39E` |
| `sand` | `#DDB07A` |
| `clay` | `#E0967A` |

### What goes away

- **`brandSecondary` (`#8C6BF2`)** — deleted. The gradient it defined is gone.
- **`brandGradient`** — deleted. Solid `sage` everywhere a gradient was used.
- **`streakFlame` (`#FF8C1A`)** — deleted. The streak loses its icon entirely; it's a numeric in the nav.

### Contrast

All sage-on-paper combinations clear WCAG AA at body text size in both light and dark. The clay-on-paper combination is reserved for chip backgrounds with darkened text or as a tint behind dark ink — it does **not** carry body copy on its own.

---

## 3. Typography scale

System fonts only.

| Role | SwiftUI call | Size / weight | Used on |
|---|---|---|---|
| Display · serif | `.system(size: 96, weight: .regular, design: .serif).italic()` | 96pt italic, -4% tracking | TodayView alignment numeric, paywall headline |
| Title · serif | `.system(.largeTitle, design: .serif).italic()` | ~34pt italic | Acknowledgment headlines, history sentence, paywall H2 |
| Result · serif | `.system(size: 64, weight: .regular, design: .serif).italic()` | 64pt italic | Acknowledgment Done word (`aligned.` / `drifting.` / `resting.` / `noted.`) |
| Title 2 · rounded | `.title2.weight(.semibold)` | 22pt | Card titles |
| Headline | `.headline` | 17pt semibold | CTA labels, nav titles when not serif |
| Body | `.body` | 15pt | Long paragraphs, banner body |
| Tip · serif italic | `.callout.italic()` with `.serif` design | 17pt italic | Tip lines, journal callouts |
| Caption · rounded | `.caption.weight(.semibold).monospacedDigit()` | 12pt 16% tracking | Eyebrows, "NEXT NUDGE 3:00 PM" meta |

**Capitalization rule:** UI chrome (eyebrows, chips, labels) is lowercase. Body and tip text use sentence case. Only ALL CAPS is for `eye`-class meta with 16%+ letter-spacing.

**Why serif?** The Daylight identity wants two visual registers — system chrome you don't notice (SF Pro) and ritual moments you pause for (SF Serif italic). Posture's wellness moments — your today reading, the result word, the paywall headline, the history sentence — get italics. Everything else stays neutral.

---

## 4. Component patterns

### 4.1 CTA · sage pill

- Solid `sage` fill, `paper`-color label.
- 52pt height, 999px radius (pill), full-width by default.
- Font: `.headline` (17pt semibold) in `.rounded` design.
- **Variants:** `ghost` (transparent, ink-2 text, 44pt) · `tonal` (sage-tint fill, sage-2 text) · `secondary` (1px paper-3 border, ink text).
- **Replaces:** the brand-gradient rectangle that's currently used everywhere a primary CTA appears.

```swift
struct DaylightCTA: ViewModifier { ... } // sage, pill, 52pt, weight .semibold, design .rounded
```

### 4.2 Quality chip

- 26pt tall, 999px radius, lowercase label, optional 6pt dot on the left, optional score on the right.
- Three tinted variants: `sage` (sage-tint bg, sage-2 text) · `sand` · `clay`.
- **Replaces:** `PostureLiveIndicator`. The colored capsule pattern stays — the language softens and the icons are removed.

### 4.3 Horizon meter

- A horizontal line (`ink` at 35% opacity) with a 22pt circular sun-dot at center.
- The line **tilts** by an angle that maps to alignment quality:
  - aligned → `-1.5° to -2°` (a slight optimistic upward tilt)
  - drifting → `5°`
  - resting → `12°`
  - manual → `0°` (flat — we have no opinion)
- Sun-dot color recolors by quality with a 22% color-mixed glow ring.
- Animation: tilt eases over 600ms with `.easeInOut` after a scan completes.
- **Replaces:** `Image(systemName: "checkmark.circle.fill")` / `triangle.fill` / `xmark.octagon.fill` on `AcknowledgmentView` Done state.

```swift
struct HorizonMeter: View {
  let quality: PostureQuality?
  // tilt + sun-dot color animate from .zero on appear
}
```

### 4.4 Day strip (TodayView hero)

- 12 vertical bars representing two-hour buckets of the active window (default 8a–8p).
- Each bar's color = quality of that bucket's check-ins (most-recent wins). Bars with no data are paper-3 placeholders; future hours are 1px dashed lines.
- Current hour bar carries a 2pt ink tick under it.
- Height encodes **count** of scans in that bucket (0–4+, capped). Color encodes **quality**.
- **Replaces:** the response-rate progress bar AND the three-tile today summary card. The two metrics merge into one signal.

### 4.5 Week strip (HistoryView hero)

- 7 vertical bars (M–S), each is a paper-3 outer track with an inner fill.
- **Bar height** (outer) = response rate (acks / scheduled reminders).
- **Inner fill** = average quality color (sage / sand / clay) — or a banded gradient when the day's mix is mixed.
- Today is marked with a small `ink` dot above the bar, never with a different bar style.
- **Replaces:** the two near-identical bar charts in HistoryView. The single chart absorbs both signals.

### 4.6 Postcard

- Background `paper-2`, 14pt radius, 1px `paper-3` border, no shadow.
- Used for the Paywall preview, the Pro upsell in Settings, and the "your july" look-back card.
- Postcards always carry an eyebrow (`eye` type) + a serif sentence + content.

### 4.7 Form section (preserved)

The native iOS `Form` semantics stay. We change the section header treatment (lowercase eyebrow at 11pt 12% tracking) and the row spacing inside.

### 4.8 Banner (new — see §6)

The single empty/error/permission pattern. Spec'd in section 6.

### What we removed

- **`StreakFlame` icon** — flame.fill icon is gone everywhere. The component becomes a quiet numeric in the nav toolbar (no icon, no pill chrome).
- **`PostureRing`** — actually kept, but used **only inside `CalibrationView`** where a circular progress for the 5-second capture countdown reads literally. It does **not** appear on Today.
- **Drop shadows** — all of them. Surfaces stack with 1px hairlines.

---

## 5. Per-screen redesigns

### 5.1 TodayView (priority: highest)

**Intent:** Above the fold answers a single question — *"how am I doing today?"* — with a second answer right under it — *"what do I do next?"* The 8-card stack collapses to: alignment readout, day strip, CTA, meta, one tip line. Streak demotes to the nav.

**Composition:** see `Daylight - Design Pass.html` § 04 and `mockups/05-today-redesign.png`.

```
┌─────────────────────────────┐
│ today          12 days      │  ← nav (italic serif title, numeric streak right)
│                             │
│ TODAY'S ALIGNMENT           │  ← eyebrow
│   82°  aligned              │  ← serif italic numeric + tonal label
│        5 of 7 scans on track│
│                             │
│ ▆ ▇ ▆ ▃ █ ▂ ▇ · · · · ·     │  ← day strip (12 bars; future = dashed)
│ 8a  10  12  2  4  6p        │
│                             │
│ [        check in now      ]│  ← sage pill, full-width
│ next nudge 3:00 pm · 5 left │  ← meta row
│                             │
│ · shoulders heavier than    │  ← single-line italic tip
│   ears.                     │
│                             │
│ today  history  settings    │  ← tab bar
└─────────────────────────────┘
```

**Changes against `TodayView.swift:36–99`:**

- Delete the `StreakFlame` insertion at line ~40 (top of body). The streak appears as a `Text("\(streak) days")` in `.toolbar { ToolbarItem(placement: .topBarTrailing) }`.
- Delete the `reminderStatusCard` / `remindersOffCard` block. The reminder status collapses into the single `meta-row` under the CTA.
- Delete the `responseProgressCard` (the broken response-rate ProgressView, P1-9). The day strip carries this signal.
- Delete the `todaySummaryCard` (3 stat tiles). The day strip carries this signal.
- Delete the `statsRow` (Longest / Freezes / Total check-ins). These can live in a Settings → Stats sub-view if anyone needs them — they don't belong on Today.
- Replace `checkInCard` (gradient rectangle) with a `DaylightCTA` pill labelled `check in now`.
- Replace the `PostureTipCard` block with a single-line italic `.tipline` showing only `tip.text` — no header, no icon, no card chrome. Tap → expand to full tip in place (animate inline).
- Add: alignment readout (serif italic number + quality label). Compute alignment as the mean of today's scored acks, mapped to 0–100°.
- Add: day strip component, rendering 12 two-hour buckets from `acknowledgments.filter { same day }`.

**Empty state (no acks today):** see `mockups/05-today-empty-redesign.png`. The readout becomes `—°` at 35% opacity with label `no scans yet`, the day strip shows 12 dashed lines, and a muted `PostureBanner` carries the invitation.

### 5.2 AcknowledgmentView (priority: highest)

This view fires up to 24× per day. Every interaction must be fast and slightly rewarding.

#### 5.2a · Choice state

**Intent:** One decision — scan or manual — never two equal-weight buttons. Always an escape hatch.

**Changes against `AcknowledgmentView.swift:55–130` (`choiceView`):**

- Delete the large `figure.stand` icon (62pt). Replace with a small eyebrow at the top showing `wednesday · 3:00 pm` in `.eye` style.
- Replace "Time to check in" / "How's your posture right now?" with a single serif italic question — *"how's your posture right now?"* — at 34–38pt, weight .regular.
- The secondary "I Sat Up Straight" pill becomes a `cta ghost` text link below the primary `cta` ("scan").
- Add an always-visible close button (×) at the top-trailing corner. Fixes audit **P1-12**. Notification-context is no longer required for dismissal.
- Body copy under the question: *"A three-second scan. Or just tell us — we trust you."*

#### 5.2b · Scanning state

**Intent:** The camera is the focus. Drop the inset card.

**Changes against `QuickScanView` (inside `AcknowledgmentView.scanningView`):**

- The camera preview goes **full-bleed** instead of a 3:4 inset with a gradient border. The brand gradient border is deleted.
- Add a soft dashed-stroke oval head guide (CSS-equivalent: 56% width, aspect 0.72, 1.2pt dashed white at 45% opacity).
- Countdown digit moves on top of the preview, centered above the oval guide, rendered in `.system(size: 72, design: .serif).italic()` at 95% white.
- Quality chip pill stays — but the iOS-default-capsule look becomes a tonal pill with backdrop blur, lowercase label, 6pt sage dot when face is detected, 6pt clay dot when not.
- Caption "hold still. look straight ahead." at the bottom in serif italic, 70% white.
- Close button (×) in the top-trailing remains.

#### 5.2c · Done state (the reward moment)

**Intent:** Three distinct tonal-color tints — sage / sand / clay — full-screen, plus a horizon meter, plus a single italic verb. Never scolding.

**Changes against `AcknowledgmentView.swift:140–222` (`doneView`):**

- Delete the SF Symbol icon (`checkmark.circle.fill` / `triangle.fill` / `xmark.octagon.fill`). Replace with the `HorizonMeter` component.
- Tint the whole screen background with the quality color at ~12% (use `sage-tint` / `sand-tint` / `clay-tint` from the palette — already pre-mixed).
- Replace the title strings:
  - `"Looking good!"` → `aligned.` (serif italic, 64pt, sage period)
  - `"Shift back a bit"` → `drifting.` (sand period)
  - `"Straighten up"` → `resting.` (clay period)
  - `"Checked in!"` (manual path) → `noted.` (ink-3 period)
- Replace the imperative subtitles:
  - good: `"Crown over hips. Shoulders soft. You're holding the shape well."`
  - borderline: `"Head's a little forward. A small reset is all this needs."`
  - bad: `"Curled forward. Take a slow breath, lift the crown of your head."`
  - manual: `"Logged without a scan. That counts — staying mindful is most of it."`
- Tip card → single-line italic tip in the same `.tipline` style as Today.
- "Done" CTA becomes a `cta ghost` (less heavy than the gradient pill it currently is). Tapping it dismisses the cover.

### 5.3 HistoryView (priority: high)

**Intent:** Tell a story. One chart, one sentence, one journal.

**Composition:** see `Daylight - Design Pass.html` § 06 and `mockups/09-history-redesign.png`.

```
┌─────────────────────────────┐
│ history       this week ▾   │
│                             │
│ NOV 11 — NOV 17             │
│ Your best stretch was       │
│ Tuesday morning. Friday     │
│ afternoon slipped.          │
│                             │
│  ▁  ▆  ▃  █  ▁  ▁  ▅        │
│  M  T  W  T  F  S  S        │
│              today●         │
│                             │
│ 74% aligned    +11 vs last  │
│ ─────────────────────────── │
│ 3:00p  aligned · scan    ●  │
│ 2:00p  resting · scan    ●  │
│ 1:00p  noted · manual    ○  │
│ 11:30  aligned · scan    ●  │
└─────────────────────────────┘
```

**Changes against `HistoryView.swift`:**

- Delete one of the two weekly bar charts (response-rate and quality-mean). The remaining `WeekStripView` (new) absorbs both signals — bar height = response rate, fill color = average quality.
- Add `narrativeSentence(week:)` — a small text generator that picks one of ~6 templates based on the data:
  - "Your best stretch was {weekday} {morning|afternoon}."
  - "Mornings are gold this week."
  - "{weekday} afternoon slipped." …
  - This sentence renders in serif italic at 22–24pt above the chart. Add a fallback "We need a few more days." for weeks with < 4 days of data.
- Replace the recent-acks "interleaved timeline" list (currently styled like a Settings table) with a **journal feed**: time on left, body in sentence case, optional serif italic tip callout under the body, colored dot on right (sage / sand / clay / outlined for manual).
- The Pro `PassiveTimelineView` block — keep the position, change the bars from `Theme.bad` opacity to the `sand`/`clay` warm scale, and add a narrative line above ("Most slouching: 2 — 3 pm.").
- **Empty state:** see `mockups/09-history-empty-redesign.png`. The page renders a single 64pt horizon-and-sun stroke, an eyebrow `no history yet`, a serif italic sentence `"Check in once and a story begins."`, a 13pt body line about needing a few days, and a `cta` to "check in now" that opens AcknowledgmentView.

### 5.4 PaywallView (priority: highest)

**Intent:** Stop selling features. Sell a vision of the next month.

**Composition:** see `Daylight - Design Pass.html` § 07 and `mockups/12-paywall-redesign.png`.

**Changes against `PaywallView.swift:45–142`:**

- Delete the crown icon, the gradient hero, the four-row `Image(systemName:) + Text` feature list, and the two purchase rectangles.
- Replace with:
  1. Eyebrow `posture · pro`, top-leading. Close × top-trailing.
  2. Serif italic H2: `"The long way is the only way."` (34pt, weight .regular).
  3. Subtitle body: `"Pro adds the parts of the practice you only see after a few weeks."`
  4. **"Your July · a preview"** postcard: 30-day mini bar grid showing a synthetic month of aligned/sand/clay bars with one stretch outlined in ink ("14-day stretch"). Header right shows "84% aligned" in sage-2. This **is** the paywall — a personalized look-forward in lieu of stock photos.
  5. Three plain-text included rows (no checkmarks, no icons):
     - *24-hour rhythm — when you slip, hour by hour*
     - *Quiet AirPods background monitoring*
     - *Every month kept — free shows a week*
  6. Single CTA: `try 7 days · then $29.99 / year` (RevenueCat injects the actual prices — we keep the visual exact).
  7. Footer row: monthly fallback "$4.99 / month" · "restore" · "maybe later".
- A second, **quieter alt** is mocked at `mockups/12-paywall-alt-redesign.png` for users whose first paywall view comes from settings (lower intent moment) — no postcard, more whitespace, the horizon meter as the only ornament.
- **No medical claims** anywhere. The postcard is explicitly a "preview" not a projection.
- **App-store review:** the postcard's mocked data does not reference real before/after photos, so it doesn't trip the wellness/medical line.

### 5.5 PassiveTimelineView (priority: medium)

Folded into the HistoryView Pro variant (`mockups/09-history-pro-redesign.png`). The Pro 24-hour rhythm view now sits at the **top** of HistoryView (above the week strip), with:

- Eyebrow `today's rhythm · pro`.
- A line of narrative: `"Most slouching: 2 — 3 pm. From AirPods + Watch."` (bold the time).
- The hour-by-hour bars rendered in `paper-3` for empty/light hours, `sand` for moderate, `clay` for heavy — instead of `Theme.bad` opacity.
- Two source chips below (`airpods` sage tonal, `watch` neutral).

### 5.6 SettingsView (priority: medium)

**Intent:** Keep the native `Form` (it earns Dynamic Type and a11y for free). Change only the Pro upsell row and the recalibrate UX.

**Changes against `SettingsView.swift`:**

- Replace the top `NavigationLink { PaywallView() }` chevron row with a **tonal sage postcard** (full-width inside the form's first section). Tap → presents PaywallView as a sheet. The card carries:
  - Eyebrow `posture · pro`
  - Serif italic line: `"Keep the whole year. See your slouch hours."`
  - CTA-style row: `try 7 days · $29.99/yr →`
- Replace the recalibrate `confirmationDialog` (audit P2 weakness) with a `sheet` that surfaces a small `RecalibrationOptionsView`: two `cta secondary` buttons (Quick / Full) and a `cta ghost` cancel.
- The AirPods status sub-view inside the Pro toggle becomes a `chip sage` ("airpods · linked") that opens a detail sheet rather than rendering inline inside the toggle row.

### 5.7 CalibrationView — AirPods question (priority: medium)

**Changes:**

- The two stacked buttons get different visual weight. "yes — link them" becomes the **secondary** (`cta secondary` — outlined). "no, use my camera" becomes the **primary** sage pill. Rationale: most users don't have AirPods to hand at calibration time; the safe path should be the bold one.
- Trim the explainer paragraph to two short lines: *"If yes, we'll use their motion sensor to catch slouches without staring at the camera."*
- Add the close × top-trailing.

### 5.8 CalibrationView — Capture (priority: high)

**Changes:**

- Camera goes **full-bleed** (already covered in 5.2b but applies here too).
- Oval head guide (same as scan).
- Countdown digit in 72pt serif italic on top of the preview.
- "Capture" CTA when disabled gets an inline reason **above** it: `"we'll enable this once we can see your face."` — fixes the current silent-grey state. The button background switches to `paper-3` opacity 0.5 with `ink-3` text.

---

## 6. Empty / error / permission pattern

One reusable SwiftUI component: **`PostureBanner`**.

```swift
struct PostureBanner: View {
  enum Tone { case muted, warn, error }
  let tone: Tone
  let title: String
  let body: String
  var action: (label: String, perform: () -> Void)? = nil
}
```

**Anatomy:** a 1px `paper-3` border, 14pt radius, 16pt internal padding, an 8pt round mark left (sand for muted, sand for warn, clay for error), title in `.subheadline.weight(.semibold)`, body in `.caption` ink-2, optional action link in `cta-ghost` style sage-2.

**Three usages:**

1. **`.muted`** — *"No history yet. A few days of check-ins and patterns appear here."* Used wherever a surface needs to show "data is coming" without alarm. (TodayView day strip when empty, HistoryView, the Pro preview on free when < 3 days.)
2. **`.warn`** — *"Notifications are off. Reminders won't fire until you allow notifications."* + `allow →` action. Wired to `UNUserNotificationCenter.requestAuthorization`. Fixes audit **P1-3**.
3. **`.error`** — *"Camera access denied. Posture needs the front camera for quick scans. Manual check-ins still work."* + `open settings →` action.

**Fullscreen variant:** for first-run roadblocks, the same component renders inside a `VStack` with a 64pt horizon-and-sun stroke above it. Used only when the user explicitly cannot proceed (no camera *and* no AirPods after calibration).

---

## 7. Decisions on `open-questions.md`

1. **Streak prominence** — demote. Numeric only, nav toolbar. Keep `StreakService` intact (still drives history journal entries and the year-end look-back).
2. **"Bad posture" framing** — tonal three-step: `aligned · drifting · resting`. Result copy avoids imperatives; favor observations ("Curled forward. Take a slow breath." not "Straighten up.").
3. **Pro affordances** — preview-with-lock. Pro features are visible to free users with a tonal sage card overlaying the preview. Nothing is hidden. Wellness apps lose trust when surfaces vanish on tier changes.
4. **Calibration intensity** — stay utility. Full-bleed camera + oval guide is enough of a brand moment for a 5-second capture.
5. **Camera framing** — full-bleed in both QuickScan and Calibration. The inset rectangle is killed.
6. **Brand voice** — lowercase, observational, never imperative. Reminder titles all-lowercase: "next nudge · 3:00 pm" / "a small check-in" / "two minutes — how are you sitting?". A single tone spec ships with `change-list.md`.
7. **App icon** — flag for a follow-up icon pass. Current `figure.stand` motif is incompatible with the horizon metaphor; recommend a horizon-and-sun icon at v1.0. Design ships v1.0 with the existing icon untouched.
8. **Empty-state philosophy** — illustrate the future, never hide. Every empty surface gets a one-line italic invitation + `PostureBanner` muted.
9. **AirPods orange indicator** — if engineering keeps the feature, name it: Settings shows the toggle row labelled `"Quiet AirPods background"` and a one-line caption: `"iOS shows an orange dot when this is on — that's Posture listening to silence so it can feel your slouch."` If the feature is cut, no design is owed.

---

## 8. Open follow-ups (deferred)

These are real but out-of-scope for the v1.0 submission and called out so they don't get lost:

- **App icon pass.** Daylight's horizon metaphor will look bad next to a `figure.stand` icon on the home screen. Recommend a separate 1–2 day icon pass before public launch.
- **Reminder copy.** A full rotation of 10–12 reminder titles in the new voice — Engineering should generate these and we'll review. A starter set is in `change-list.md`.
- **Onboarding.** Kept as single screen for v1.0. Open question: would a 2-screen onboarding (1 = identity moment, 2 = "what the day looks like" preview) materially lift activation? Worth a Q3 A/B test, not a v1.0 design.
- **Year-end look-back.** The Paywall postcard concept ("your july · a preview") wants a real version — generate a December "your year" sharable image as a January surprise for retained users. Defer to a v1.1 pass.
- **Watch UI handoff.** Separate handoff explicitly per `brief.md`.

---

## Appendix · Files in this handoff

- `Daylight - Design Pass.html` — interactive review surface (color, type, components, every redesigned screen).
- `mockups/` — b/w composition PNGs per redesigned screen (engineering reference).
- `change-list.md` — bulleted, line-numbered diff plan to hand to Claude Code first.

# Posture · Change List

Code-level diff plan for the **Daylight** design pass.
This is the file the engineer hands Claude Code first.
Companion: `design-response.md` (rationale) · `Daylight - Design Pass.html` (visual reference) · `mockups/` (b/w composition PNGs).

Line numbers are against the current `main` (v0.1.0). All Swift paths are relative to repository root.

---

## 0 · Tokens — `Shared/Utilities/Theme.swift`

Replace the file body. **Keep the `PostureQuality` switch helper** at the bottom — only the constants change.

```swift
// Replace lines 23–30 (Brand + Posture quality) with:

// MARK: - Daylight brand
static let sage         = Color("DaylightSage")      // light #6B8E7A / dark #8FB39E
static let sageTint     = Color("DaylightSageTint")  // light #DCE6DD / dark #2A3B33
static let sand         = Color("DaylightSand")      // light #C68F4D / dark #DDB07A
static let sandTint     = Color("DaylightSandTint")  // light #F4E2C5 / dark #3A2F1E
static let clay         = Color("DaylightClay")      // light #B8654A / dark #E0967A
static let clayTint     = Color("DaylightClayTint")  // light #F1D9CC / dark #3B2920

// MARK: - Daylight neutrals (replace systemBackground-family)
static let paper        = Color("DaylightPaper")     // light #F6F1E8 / dark #171614
static let paper2       = Color("DaylightPaper2")    // light #EFE7D6 / dark #211F1B
static let paper3       = Color("DaylightPaper3")    // light #E5DDC9 / dark #2A2722
static let ink          = Color("DaylightInk")       // light #1F1B16 / dark #EFE9DC
static let ink2         = Color("DaylightInk2")      // light #5A5247 / dark #B7AE9D
static let ink3         = Color("DaylightInk3")      // light #948A7A / dark #7C7464

// MARK: - Posture quality
static let good         = sage   // alignment ≥ 80 — "aligned"
static let borderline   = sand   // alignment 50–79 — "drifting"
static let bad          = clay   // alignment < 50 — "resting"
```

**Delete:**
- `brandPrimary`, `brandSecondary`, `brandGradient` (lines 29, 30, 38–44).
- `streakFlame` (line 31).

**Aliases for existing references (keep until call-sites are migrated, then remove):**
- `background` → `paper`
- `cardSurface` → `paper2`
- `cardSurfaceLight` → `paper3`
- `ringTrack` → `paper3`
- `textPrimary` → `ink`
- `textSecondary` → `ink2`
- `textTertiary` → `ink3`

Add color sets `DaylightSage`, `DaylightSageTint`, `DaylightSand`, `DaylightSandTint`, `DaylightClay`, `DaylightClayTint`, `DaylightPaper`, `DaylightPaper2`, `DaylightPaper3`, `DaylightInk`, `DaylightInk2`, `DaylightInk3` to `Posture/Assets.xcassets/` with light + dark variants per `design-response.md` §2.

**Type:** add the following helpers below the existing `bigNumber`:

```swift
static func displaySerif(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .serif).italic()
}
static func roundedNumeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded).monospacedDigit()
}
```

---

## 1 · New components

### 1.1 `Posture/Views/Components/DaylightCTA.swift` (new)

```swift
struct DaylightCTA: ViewModifier {
    enum Style { case primary, secondary, tonal, ghost }
    let style: Style
    func body(content: Content) -> some View { /* sage pill, 52pt, weight .semibold, design .rounded */ }
}
extension View {
    func daylightCTA(_ style: DaylightCTA.Style = .primary) -> some View { modifier(DaylightCTA(style: style)) }
}
```

Spec — see `design-response.md` §4.1.

### 1.2 `Posture/Views/Components/HorizonMeter.swift` (new)

```swift
struct HorizonMeter: View {
    let quality: PostureQuality?
    // animates tilt from 0° on appear:
    //   .good → -2°   .borderline → 5°   .bad → 12°   nil → 0°
}
```

Used inside `AcknowledgmentView.doneView` and the Paywall alt mockup. Spec — see `design-response.md` §4.3.

### 1.3 `Posture/Views/Components/DayStrip.swift` (new)

```swift
struct DayStrip: View {
    let acks: [AcknowledgmentRecord]          // today only — pre-filtered
    let now: Date
    let activeWindow: ClosedRange<Int> = 8...20  // hours
    // 12 bars; current-hour tick; future = dashed
}
```

Spec — see `design-response.md` §4.4.

### 1.4 `Posture/Views/Components/WeekStrip.swift` (new)

```swift
struct WeekStrip: View {
    let days: [DaySummary]    // 7 entries — most-recent week
    let todayIndex: Int
}
struct DaySummary {
    let responseRate: Double          // 0...1   → bar height
    let averageQuality: PostureQuality?  // → fill color, or .mixed for banded gradient
}
```

Spec — see `design-response.md` §4.5.

### 1.5 `Posture/Views/Components/PostureBanner.swift` (new)

Empty/error/permission. Three tones: `.muted`, `.warn`, `.error`. Spec — see `design-response.md` §6.

### 1.6 `Posture/Views/Components/QualityChip.swift` (rename + refactor)

Rename `PostureLiveIndicator.swift` → `QualityChip.swift`. Drop the SF Symbol prefix. Lowercase label, optional 6pt color dot, optional trailing score.

### 1.7 `Posture/Views/Components/TipLine.swift` (new)

A single-line italic serif tip used on TodayView and the Done state, replacing the heavy `PostureTipCard` in those two contexts. The full `PostureTipCard` stays on `PostureHabitsView`.

```swift
struct TipLine: View {
    let tip: PostureTip
    // serif italic, 17pt, ink2; tap → expands to full text inline with .animation
}
```

---

## 2 · `Posture/Views/TodayView.swift` (lines 36–99) — restructured

**Delete:**
- `StreakFlame(streak:)` at line ~40.
- `reminderStatusCard` block (lines 121–145) and the `remindersOffCard` block (lines 147–166).
- `responseProgressCard` (lines 170–190) — broken anyway (audit P1-9).
- `todaySummaryCard` (lines 194–242) — the 3 stat tiles.
- `checkInCard` (lines 246–262) — keep the button but rewrite using `daylightCTA(.primary)`.
- `statsRow` and `statTile(...)` helpers (lines 266–286) — these stats move to a future Settings → Stats sub-view, **out of scope for this pass**.
- The current `PostureTipCard` block in the main `body` (lines 62–80).
- The "All posture tips" `Button` (lines 82–94).

**Add at top of body (`ScrollView` content):**

```swift
NavigationStack {
    ScrollView {
        VStack(spacing: 22) {
            alignmentReadout    // 1
            DayStrip(acks: todayAcks, now: .now)   // 2
            VStack(spacing: 10) {
                Button { showingAck = true } label: { Text("check in now") }
                    .daylightCTA(.primary)
                metaRow         // "next nudge 3:00 pm · 5 left"
            }
            if let tip = currentTip {
                TipLine(tip: tip)
                    .onTapGesture { withAnimation { currentTip = PostureTipService.randomTip() } }
            }
            // empty state — if acks.isEmpty:
            PostureBanner(tone: .muted,
                          title: "A daylight habit takes about a week.",
                          body: "Check in three or four times today. We'll show you the shape of it.")
        }
        .padding(.horizontal, 20)
    }
    .background(Theme.paper.ignoresSafeArea())
    .navigationTitle("today")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            if streak.currentStreak > 0 {
                Text("\(streak.currentStreak) days")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }
}
```

**`alignmentReadout` view:**

```swift
private var alignmentReadout: some View {
    let score = todayAlignmentScore()    // mean of scored acks → 0...100
    return VStack(alignment: .leading, spacing: 6) {
        Text("TODAY'S ALIGNMENT")
            .font(.caption.weight(.semibold))
            .tracking(2)
            .foregroundStyle(Theme.ink3)
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            Text(score.map { "\($0)°" } ?? "—°")
                .font(Theme.displaySerif(96))
                .foregroundStyle(score == nil ? Theme.ink3 : Theme.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(qualityLabel(score)).foregroundStyle(qualityColor(score))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(qualitySubtitle(score)).font(.caption).foregroundStyle(Theme.ink2)
            }
        }
    }
}
```

**Title format:** the navigation title is set as `"today"` (lowercase). Use `.toolbarTitleDisplayMode(.inline)` with a custom appearance — italic serif at 22pt — by applying `Font` to the title via SwiftUI 17 `.navigationTitle(...)` + `.toolbar { ToolbarItem(placement: .principal) { ... } }` if needed. (Engineering decision; current `.navigationTitle("Today")` change is the minimum required.)

---

## 3 · `Posture/Views/AcknowledgmentView.swift`

### 3.1 Choice state (`choiceView`, lines 55–130)

**Delete:**
- Lines 60–66: the `figure.stand` 64pt icon.
- Line 68: "Time to check in" — replace with eyebrow above.
- Lines 78–96: the two stacked buttons with figure icons. Replace with the layout below.

**Replace with:**

```swift
VStack(alignment: .leading, spacing: 0) {
    // Top eyebrow + close
    HStack {
        Text(formattedAckEyebrow(.now))   // "wednesday · 3:00 pm"
            .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.ink3)
        Spacer()
        Button(action: { dismiss() }) { Image(systemName: "xmark").font(.body.weight(.medium)) }
            .foregroundStyle(Theme.ink3)
            .accessibilityLabel("Close")
    }
    .padding(.top, 12).padding(.bottom, 40)

    Text("how's your posture\nright now?")
        .font(Theme.displaySerif(42))
        .foregroundStyle(Theme.ink)
        .lineSpacing(-4)
    Text("A three-second scan. Or just tell us — we trust you.")
        .font(.body).foregroundStyle(Theme.ink2)
        .padding(.top, 14)
    Spacer()

    Button { phase = .scanning } label: { Text("scan") }
        .daylightCTA(.primary)
    Button {
        recordAcknowledgment(method: .manual, quality: nil)
        withAnimation { phase = .done }
    } label: { Text("just checking in — manual →") }
        .daylightCTA(.ghost)
        .padding(.bottom, 16)
}
.padding(.horizontal, 24)
```

**Fixes:**
- Audit **P1-12** — the close button is always available, not gated on `notificationIndex > 0`. Remove the `if let idx = notificationIndex, idx > 0` block (lines 113–122).

### 3.2 Scanning state (`scanningView`, lines 134–158)

**Delete:**
- The `Text("Checking your posture")` header (lines 136–139).
- The `.padding(.horizontal, 16)` on `QuickScanView` (line 156). The scan goes full-bleed.

**Inside `QuickScanView` (`Posture/Views/Components/QuickScanView.swift` — separate file):**

- Change the camera preview to full-bleed (remove the 3:4 inset + gradient border).
- Add `OvalHeadGuide` overlay: 56% width, aspect 0.72, 1.2pt dashed `Color.white.opacity(0.45)` stroke.
- Move the countdown digit on top of the preview, centered above the oval, in `Theme.displaySerif(72)` at 95% white.
- Replace the existing `PostureLiveIndicator` capsule at the bottom with a `QualityChip` in tonal blur style (`Material.ultraThinMaterial`).
- Add a serif italic caption at the bottom: `"hold still. look straight ahead."` (`Theme.displaySerif(13)` is OK or use `.callout.italic()` with `.serif` design).
- Add a close button (×) top-trailing, always visible.

### 3.3 Done state (`doneView`, lines 162–222)

**Delete entirely.** Replace with:

```swift
private var doneView: some View {
    ZStack {
        tintForDone.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(eyebrowForDone).font(.caption.weight(.semibold)).tracking(2)
                    .foregroundStyle(eyebrowColor)
                Spacer()
                Button(action: { dismiss() }) { Image(systemName: "xmark") }
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text(eyebrowForDone).font(.caption.weight(.semibold)).tracking(2)
                    .foregroundStyle(eyebrowColor).accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(resultWord).font(Theme.displaySerif(64)).foregroundStyle(Theme.ink)
                    Text(".").font(Theme.displaySerif(64)).foregroundStyle(resultColor)
                }
                Text(resultSubtitle).font(.body).foregroundStyle(Theme.ink2)
            }
            HorizonMeter(quality: recordedQuality).frame(height: 64)
            if let tip = currentTip { TipLine(tip: tip) }
            Spacer()
            Button { dismiss() } label: { Text("done") }.daylightCTA(.ghost)
        }
        .padding(.horizontal, 24).padding(.bottom, 32)
    }
}
```

**Helpers:**

```swift
private var resultWord: String {
    switch recordedQuality {
    case .good: return "aligned"
    case .borderline: return "drifting"
    case .bad: return "resting"
    case nil: return "noted"
    }
}
private var resultColor: Color {
    switch recordedQuality {
    case .good: return Theme.sage
    case .borderline: return Theme.sand
    case .bad: return Theme.clay
    case nil: return Theme.ink3
    }
}
private var tintForDone: Color {
    switch recordedQuality {
    case .good: return Theme.sageTint
    case .borderline: return Theme.sandTint
    case .bad: return Theme.clayTint
    case nil: return Theme.paper2
    }
}
private var resultSubtitle: String {
    switch recordedQuality {
    case .good:       return "Crown over hips. Shoulders soft. You're holding the shape well."
    case .borderline: return "Head's a little forward. A small reset is all this needs."
    case .bad:        return "Curled forward. Take a slow breath, lift the crown of your head."
    case nil:         return "Logged without a scan. That counts — staying mindful is most of it."
    }
}
```

---

## 4 · `Posture/Views/HistoryView.swift` — restructured

**Delete:**
- The second weekly bar chart (whichever of response-rate / quality-mean ends up duplicative — keep response rate as the bar-height signal).
- The current "recent acknowledgments" list rendering (the one styled like a Settings table).

**Add at top of body:**

```swift
VStack(alignment: .leading, spacing: 18) {
    weekHeader            // "NOV 11 — NOV 17" eyebrow + serif sentence
    WeekStrip(days: weekSummaries, todayIndex: todayIndex)
    HStack {
        Text("\(weekAlignmentPercent)% aligned").font(.subheadline.weight(.semibold))
        Spacer()
        Text(deltaVsLastWeek).font(.subheadline.weight(.semibold)).foregroundStyle(.ink2)
    }
    Divider().background(Theme.paper3)
    JournalFeed(acks: recentAcks)
    if subscription.isPro {
        PassiveTimelineRowGroup()      // (see §5 below)
    } else {
        ProPreviewCard()               // tonal sage card with "see your slouch hours" CTA
    }
}
.padding(.horizontal, 20)
```

**`weekHeader`:**

```swift
private var weekHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(weekRangeLabel).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.ink3)
        Text(narrativeSentence(weekSummaries))
            .font(Theme.displaySerif(24))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

**`narrativeSentence(_:)`:** add to a new helper file `Shared/Utilities/HistoryNarrative.swift`. Returns one of ~6 templates based on which day has the highest mean quality, which has the lowest, whether the week trends up/down, etc. Fallback for sparse weeks: `"We need a few more days."`

**`JournalFeed`:** replaces the interleaved-timeline card. One row per ack:

```
┌─────────────────────────────────────────────┐
│ 3:00p  aligned · scan                      ● │
│        "crown over hips. shoulders soft."    │ ← italic serif if tip attached
├─────────────────────────────────────────────┤
│ 2:00p  resting · scan                      ● │
└─────────────────────────────────────────────┘
```

### 4.1 Empty state

When `acks.isEmpty`:

```swift
VStack(alignment: .leading, spacing: 18) {
    HorizonStroke()         // 64pt SVG-ish horizon-and-sun (a Path + Circle.stroke)
    Text("NO HISTORY YET").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.ink3)
    Text("Check in once and a story begins.").font(Theme.displaySerif(28)).foregroundStyle(Theme.ink)
    Text("We need a few days before patterns are worth showing. Until then, today is plenty.")
        .font(.body).foregroundStyle(Theme.ink2)
    Button { /* present AcknowledgmentView */ } label: { Text("check in now") }
        .daylightCTA(.primary)
}
```

---

## 5 · `Posture/Views/PassiveTimelineView.swift`

**Changes:**

- Move this view to **top of HistoryView** when Pro is active (currently it sits below the charts).
- Replace the `Theme.bad`-opacity bars with a three-step color ramp: `paper3` (light hour), `sand` (moderate), `clay` (heavy). The threshold lives in `PostureScoring`.
- Add a narrative line above the chart: `Text("Most slouching: \(peakRange).")` where `peakRange` is computed in the view's `body` — e.g. `"2 — 3 pm"`. Bold the time using `AttributedString`.
- Add two source chips below the chart: `airpods` (`sage` tonal) and `watch` (`paper2` neutral). Use `QualityChip` with custom labels.

---

## 6 · `Posture/Views/PaywallView.swift` (lines 45–142)

**Delete the entire `placeholderPaywall` body** (the crown icon, the 4 feature rows, the 2 purchase buttons, the "Free trial included" line).

**Replace with:**

```swift
private var placeholderPaywall: some View {
    VStack(alignment: .leading, spacing: 14) {
        // Top
        HStack {
            Text("POSTURE · PRO").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.ink3)
            Spacer()
            Button(action: { dismiss() }) { Image(systemName: "xmark") }.foregroundStyle(Theme.ink3)
        }
        // Headline
        Text("The long way is the only way.")
            .font(Theme.displaySerif(30))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        Text("Pro adds the parts of the practice you only see after a few weeks.")
            .font(.subheadline).foregroundStyle(Theme.ink2)
        // Postcard
        YourJulyPostcard()
        // Included list — three plain-text rows
        VStack(alignment: .leading, spacing: 0) {
            includedRow("24-hour rhythm — when you slip, hour by hour")
            includedRow("Quiet AirPods background monitoring")
            includedRow("Every month kept — free shows a week", isLast: true)
        }
        Spacer()
        // Price
        Button { /* purchase yearly */ } label: { Text("try 7 days · then $29.99 / year") }.daylightCTA(.primary)
        HStack {
            Text("or $4.99 / month").font(.caption).foregroundStyle(Theme.ink3)
            Spacer()
            Button("restore") { /* restorePurchases */ }.font(.caption).foregroundStyle(Theme.ink3)
            Text("·").foregroundStyle(Theme.ink3)
            Button("maybe later") { dismiss() }.font(.caption).foregroundStyle(Theme.ink3)
        }
        .padding(.bottom, 18)
    }
    .padding(.horizontal, 24)
    .background(Theme.paper.ignoresSafeArea())
}
```

**`YourJulyPostcard`:** a new view that renders 30 vertical bars in a grid using a synthetic data array. The 14-day "stretch" is outlined in `ink` with `outline-offset` equivalent (use `.overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.ink, lineWidth: 1.5).padding(-2))`). Real data is **not** used — the postcard is deliberately a "preview" graphic to avoid medical-claim territory. Mirror the visual in `mockups/12-paywall-redesign.png`.

**`includedRow(_:isLast:)`:** a small helper that lays out a top-border-only row with a leading `·` and `.subheadline.weight(.medium)` text.

**RevenueCat fallback:** unchanged. When `RevenueCatUI.PaywallView` is configured, it still wins; only the placeholder swaps.

**Pricing:** the literal `"$29.99 / year"` is a **placeholder** — RevenueCat substitutes the real price at render. Keep the visual fixed-width using `.monospacedDigit()`.

---

## 7 · `Posture/Views/SettingsView.swift`

**Changes:**

- Replace the top `Section("Pro") { NavigationLink { PaywallView() } label: { ... } }` chevron row with a **tonal sage postcard** rendered as a `Section` content with `.listRowInsets(.zero)` and `.listRowBackground(Color.clear)`. The card carries:
  - Eyebrow `posture · pro`.
  - Serif italic: `"Keep the whole year. See your slouch hours."`
  - `try 7 days · $29.99/yr →` (tap → present `PaywallView` as a sheet).
- Replace the recalibrate `confirmationDialog` with a `sheet(isPresented:)` presenting a small `RecalibrationOptionsView`:
  - Header: `"Recalibrate"` (`.title3.weight(.semibold)`).
  - Two `cta secondary` buttons: `quick — 5 seconds` / `full — restart`.
  - One `cta ghost`: `cancel`.
- Move the `AirpodsStatusView` out of the toggle row. Replace its position with a `QualityChip` reading `airpods · linked` (or `not linked`) that opens a detail sheet on tap.

---

## 8 · Reminder copy — `Shared/Services/NotificationService.swift` and `ReminderScheduler.swift`

Replace the rotating reminder titles with a starter rotation. Source of truth: a `static let reminderTitles: [String]` array in `NotificationService` (or wherever the schedulers pull from).

**Starter rotation (12 entries):**

```
"a small check-in."
"two minutes — how are you sitting?"
"crown of the head, reaching."
"shoulders, soft."
"a posture pause."
"feet flat?"
"how's the spine right now?"
"a breath. and a sit-up."
"jaw and tongue, soft."
"ears over shoulders."
"how upright?"
"a moment for the body."
```

**Tone rules:**

- Lowercase except proper nouns. No exclamation marks. No imperatives directed at the body ("Sit up straight!" is out). Observations and questions only.
- 24-character soft cap so the iOS notification banner doesn't truncate.
- One emoji only, optional, at the end — a single `·` glyph allowed for rhythm. **No SF Symbol icons in titles.**

---

## 9 · Audit cross-references (closed by this design pass)

| Audit ID | Closes? | How |
|---|---|---|
| P1-3 (reminders toggle silently flips back on denial) | **Yes** | `PostureBanner.warn` appears in SettingsView with `allow →` action wired to `UNUserNotificationCenter.requestAuthorization`. |
| P1-9 (today response rate uses broken formula) | **Yes** | The response-rate progress bar is deleted; the day strip is the new signal. |
| P1-12 (AcknowledgmentView is locked unless user picks something) | **Yes** | Close × is always visible on every phase of AcknowledgmentView. |
| P2 (recalibrate `confirmationDialog` is weak UX) | **Yes** | Replaced with `sheet { RecalibrationOptionsView }`. |
| P0-3 (silent-audio AirPods background workaround at App Store risk) | **No** | Out of scope for design. If kept, the Settings UX is named explicitly (`design-response.md` §7 Q9). |

---

## 10 · Out of scope (do not change)

- The `MainTabView` and its three tabs — structure stays. Only icons and label casing change (lowercase labels).
- `PostureHabitsView` — small pass deferred. Keep current grouping; revisit per-category color in a v1.1.
- `OnboardingView` — copy + the `figure.stand` icon stay this pass. Defer a 2-screen onboarding to a Q3 A/B test.
- Watch app (`PostureWatch/*`) — separate handoff per `brief.md`.
- App icon — separate icon pass before public launch.

---

## Suggested commit order

1. **Theme + asset catalog** — add the 12 color sets, replace `brandPrimary/Secondary/Gradient`. Compile.
2. **New components** — `DaylightCTA`, `HorizonMeter`, `DayStrip`, `WeekStrip`, `PostureBanner`, `TipLine`, `QualityChip` rename. Each in its own commit.
3. **AcknowledgmentView** — the moment-of-truth screen. Highest user-visible impact.
4. **TodayView** — biggest layout shift; ship behind a feature flag if possible for a day.
5. **HistoryView** — refactor + `HistoryNarrative`.
6. **PaywallView** — postcard + new layout.
7. **SettingsView** — Pro card, recalibrate sheet, AirPods chip.
8. **NotificationService** — copy rotation swap.
9. **CalibrationView** — full-bleed scan + disabled-button reason copy.
10. **Audit fixes** — P1-3 banner wire-up, P1-12 close button, P2 sheet (already covered above as side effects).

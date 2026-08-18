# Simulator Audit — Build 76 (`sim76`)

**Date:** 2026-07-06  
**Environment:** Headless `agent-posture` (iPhone 17 Pro, iOS 26 sim) + `agent-posture-max` (iPhone 17 Pro Max)  
**Build:** Debug-iphonesimulator via `/tmp/agent-dd-posture`  
**Method:** `xcodebuild` + `axe` automation + `PostureUITests` walkthroughs  
**Screenshots:** `../docs/sim76-screenshots/` (82 PNGs across `free-fresh/`, `free-seeded/`, `pro-seeded/`, `paywall/`, `flows/`, `final/`, `devices/`)

No code was changed for this audit.

---

## Executive summary

Posture’s **Daylight visual system is cohesive** — onboarding reads well, the paywall is polished, and the Progress tab’s level ladder is the clearest expression of the product loop. The **core practice experience could not be exercised on simulator** (no head-motion AirPods), so this audit leans heavily on the **no-AirPods / manual check-in path**, seeded data surfaces, and monetization flows.

The highest-impact issues are **logic/copy mismatches** (time-of-day greeting vs status bar, “scans” vs check-ins, hour-chart counts), **permission sequencing** during calibration, and **Today still pitching AirPods + check-ins** even when seeded as an AirPods-calibrated Pro user. Free-tier gating is visible but the **Progress blur** and **History trends gate** need a device pass with stable seeded state.

| Area | Grade | Notes |
|------|-------|-------|
| Onboarding teach flow | B+ | Strong pedagogy; copy nits; long (5 pages) |
| Calibration / permissions | C | Notification prompt fights motion copy; 8s wait for escape |
| No-AirPods Today loop | C+ | Works but feels like a side quest; terminology drift |
| Practice / walk / live monitor | N/A | Blocked without hardware |
| Progress / levels | A- | Pro ladder is excellent; free blur not fully captured |
| History | B | Good receipts; trends gate untested live |
| Paywall / trial | B+ | Clear tiers; trial sheet crops headline |
| Settings / Pro toggles | B | Scrolled capture blocked by permission dialog |
| Accessibility / automation | C- | Tab bar labels invisible to AX API |
| Multi-device layout | B | Pro Max empty states OK; tab Y coords differ |

---

## Test methodology

### Launch arguments used

| Profile | Args | Intent |
|---------|------|--------|
| Fresh free user | `-UITEST_FRESH` | Clean onboarding → calibration → trial → Today |
| Seeded returning user | `-UITEST_FRESH -SCREENSHOT_SEED` | 6-day streak, 7 practice days, walk, minutes, check-ins |
| Seeded Pro | above + `-PostureProOverride` | Unlocks ladder, walks, trends, background toggles |
| Paywall portfolio | `-PaywallSnapshot trial\|monthly\|yearly\|lifetime` | Isolated paywall variants |

**Finding:** `-SCREENSHOT_SEED` alone on a **fresh install** often still lands on onboarding/calibration. Reliable main-app entry required `-UITEST_FRESH` **before** seed. Even then, Today frequently shows the **no-AirPods check-in UI** because `hasAirpods == true` in settings does not imply a connected motion stream on simulator.

### Flows exercised

| Flow | Status | Screenshots |
|------|--------|-------------|
| Onboarding pages 1–5 | ✅ | `final/onboard-01-welcome.png` … `onboard-05.png` |
| Posture focus picker | ✅ | `final/onboard-02.png`, `free-fresh/02-onboarding-page.png` |
| Standing / sitting teach pages | ✅ | `onboard-03`–`05`, `pro-seeded/clean-settings.png` (standing) |
| Calibration waiting | ✅ | `final/onboard-calibration.png`, `onboard-no-airpods-link.png` |
| Notification permission during calibration | ✅ | `flows/free-today.png`, `final/pro-today.png` |
| “I don’t have AirPods” escape | ✅ | UITests pass; ~8s delay before link appears |
| Onboarding trial (7 days) | ✅ | `final/onboard-trial.png` |
| Trial dismiss → Today (no AirPods) | ⚠️ | Interrupted by notification / Apple ID sheet |
| Today / History / Progress / Settings tabs | ✅ (Pro) | `pro-seeded/01-today-v2.png`, `settings-v2.png`, `history-v2.png` |
| Today + Posture+ tab (free) | ✅ | `free-seeded/posture-plus-v2.png` |
| Manual check-in (3 chips) | ✅ | `final/session-detail.png` (choice screen) |
| Session receipt detail | ⚠️ | Tap opened check-in, not History receipt |
| Level ladder sheet | ⚠️ | Capture blocked by notification overlay |
| Streak detail sheet | ⚠️ | Same |
| Practice pre-start / active hold | ❌ | Never reached real `PracticeSessionView` on sim |
| Walk pre-start / baseline | ❌ | Gate showed trial; Apple ID sheet on purchase |
| Paywall (full + sheet + lifetime CTA) | ✅ | `paywall/*.png` |
| Walk gate (free) | ⚠️ | `final/free-walk-gate.png` (StoreKit sign-in) |
| iPhone 17 Pro Max layout | ✅ | `devices/iphone-17-pro-max-*.png` |
| UI tests | ✅ | `OnboardingUITests`, `NewUserWalkthroughUITests` pass |

### Automation gaps (meta)

- **`axe tap --label "History"`** fails for tab bar items — tabs lack accessible labels in the AX tree; coordinate taps required (fragile across devices).
- **Continue / Check in now** sometimes fail label match while XCTest succeeds — buttons may not expose consistent `accessibilityLabel`s.
- **`simctl status_bar override --time 9:41`** does not affect `Calendar.current` — causes greeting/reminder bugs in screenshots (see below).

---

## Device matrix

| Device | UDID role | Today | Progress | Notes |
|--------|-----------|-------|----------|-------|
| iPhone 17 Pro | `agent-posture` | Primary | Primary | Tab bar tap Y≈820 |
| iPhone 17 Pro Max | `agent-posture-max` | ✅ | ✅ | Tab bar tap Y≈900; more vertical whitespace on empty Today |

**Not tested this session:** iPhone SE / 17e (small width), iPad — recommend a follow-up pass for Progress path wrapping and onboarding page density.

**Pro Max observations** (`devices/iphone-17-pro-max-progress.png`):
- Empty alignment card (“No scans yet”) is readable; tip card visible above tab bar.
- **“Hello, night owl”** at faux 9:41 AM (wall-clock bug).
- **“Next reminder 9:00 AM”** when status bar says 9:41 — reminder copy uses calendar math that doesn’t respect status-bar override (and may confuse real users near midnight).

---

## Flow-by-flow findings

### 1. Onboarding (pages 1–5)

**Screenshots:** `final/onboard-01-welcome.png`, `onboard-02.png` (focus), `onboard-03.png` (what good posture is), `onboard-04.png` / `05.png` (standing / sitting teach).

**What works**
- Pedagogy-first pivot is clear: learn shape → calibrate → daily practice.
- Focus picker (sitting / standing / both) is well-scaffolded with icons and examples.
- Standing and sitting pages use `PoseDiagram` / Illo assets effectively; “Set up my baseline” CTA on final page is confident.
- Page dots communicate length without feeling like a generic carousel.

**Issues**
1. **Copy — focus page:** “We'll capture your posture both ways either way” is redundant/awkward. Suggest: “We'll capture both either way, but coaching leans where you need it.”
2. **Length:** Five swipes + calibration + trial before first value is a lot for App Review and cold traffic. Consider collapsing teach pages 3–4 for returning users or `.both` users who will see both calibrations anyway.
3. **AirPods assumed in welcome copy** (“coached by your AirPods”) before the escape hatch — fine for positioning but sharp contrast with no-AirPods path.
4. **Accessibility:** Large display type on welcome may truncate on smaller phones — not verified on SE.

---

### 2. Calibration

**Screenshots:** `final/onboard-calibration.png`, `onboard-no-airpods-link.png`, `free-fresh/06-calibration-waiting.png`.

**What works**
- “Pop in your AirPods” state is calm; motion permission foreshadowed in body copy.
- **“I don’t have AirPods”** appears after delay — UITest asserts ≤25s; critical escape for reviewers.

**Issues**
1. **Permission order (P0 UX):** Immediately after landing on calibration, iOS **notification** permission appears while background text still discusses **motion** permission. User reads “iOS will ask permission to read motion” but sees notification dialog first (`flows/free-today.png`, `final/pro-today.png`). Defer `ReminderScheduler.reschedule()` / notification auth until **after** calibration skip or first Today visit (onboarding already defers until `hasCompletedOnboarding` — but completing onboarding triggers it while still on calibration).
2. **No loading affordance** while waiting for AirPods — static screen with no spinner/pulse for 8+ seconds before escape link.
3. **Simulator dead-end:** Cannot complete calibration — expected, but no simulator-specific debug hint for internal testers.

---

### 3. Onboarding trial (`OnboardingTrialView`)

**Screenshot:** `final/onboard-trial.png`

**What works**
- Headline “Your first 7 days are on us” + “daily practice stays free forever” sets expectations.
- Three benefits map to real Pro gates (ladder, walk, trends/monitoring).
- Timeline (Today → Day 5 reminder → Day 7 billing) matches paywall footer language.
- **Maybe later** is prominent — soft gate aligned with practice pivot.
- Legal footer (Restore / Terms / Privacy) present.

**Issues**
1. Tapping **Start my 7 free days** opens StoreKit Apple ID sheet (expected on sim) — blocks screenshot of success path.
2. Benefit density is high above fold on small phones; timeline competes with bullets.
3. Branding: “POSTURE+” small caps vs app name “Posture” elsewhere — intentional but slightly split personality.

---

### 4. Today — no-AirPods / manual check-in path

**Screenshots:** `pro-seeded/01-today-v2.png`, `free-seeded/posture-plus-v2.png`, `devices/iphone-17-pro-max-progress.png` (empty), `final/session-detail.png`.

This is what most simulator users and App Review (no AirPods) will see.

**What works**
- Streak chip + freeze count (“2 saves ready”) is discoverable.
- Alignment ring + “Aligned” state feels rewarding when data exists (85 score).
- Hour-by-hour strip gives Pro-adjacent value preview.
- AirPods upsell card explains *why* hardware matters without hard-blocking.
- Posture tip line at bottom (Pro Max) adds warmth.

**Issues**

#### P0 — Time greeting uses wall clock, not device display time
- **“Hello, night owl”** shown while status bar overridden to 9:41 AM (`pro-seeded/01-today-v2.png`).
- Root cause: `timeOfDayGreeting` uses `Calendar.current.component(.hour, from: .now)` (`TodayView.swift` ~302–309) — unaffected by `simctl status_bar`.
- Real users near midnight see “night owl” correctly, but **QA screenshots mislead**; also check-in shows **“Monday · 11:15 PM”** (`final/session-detail.png`) under 9:41 status bar — same clock split.

#### P1 — Terminology: “scans” on a check-in product
- Card says **“4 of 4 scans on track”** for manual acknowledgments — product language elsewhere is “practice”, “check-in”, “aligned %”.
- Confusing for no-AirPods users who never “scan”.

#### P1 — Hour chart count mismatch
- Header **“4 today”** on hour strip but only **two** green blocks visible between 10a–4p (`01-today-v2.png`). Suggests aggregation buckets don’t match visual bins or check-ins lack hour placement.

#### P1 — Seeded Pro user still on check-in hero
- `SCREENSHOT_SEED` sets `hasAirpods = true`, inserts calibration + practice history, yet Today shows **Check in now** + **Get AirPods** card, not **Start practice** hero (`TodayView` `isAirpodsUser` + live monitor gating). Pro subscribers with baseline but disconnected buds look like free manual users.

#### P2 — Layout bleed under tab bar
- Faint text (“…your spine.” / check-in copy) clips under floating tab bar (`01-onboarding-welcome.png` mis-captured Today).

#### P2 — Reminders off buried
- “Reminders are off. Turn on →” is easy to miss; new users may never enable practice reminder.

#### P2 — “Next reminder 9:00 AM” in the past
- On Pro Max empty Today, reminder line shows **9:00 AM** while clock reads 9:41 (`iphone-17-pro-max-progress.png`) — likely “next occurrence tomorrow” without clarifying “tomorrow”.

---

### 5. Today — AirPods / practice path (intended core)

**Status:** Not reached on simulator.

**Expected from code / prior builds:**
- Practice hero with level chip, standing/sitting toggle, chin-tuck warm-up, timed hold, Live Activity.
- Walk card with lock for free users.

**Risk:** The majority of marketing promises AirPods-coached practice; simulator/testing infrastructure doesn’t validate this loop at all. Recommend **DEBUG simulator stub** that fakes `CMHeadphoneMotionManager` samples for CI screenshots.

---

### 6. Manual check-in (`AcknowledgmentView`)

**Screenshot:** `final/session-detail.png`

**What works**
- Clear question: “How’s your posture right now?”
- Three chips (Aligned / Drifting / Slouching) with distinct semantic colors.
- Streak motivation in subcopy.

**Issues**
1. **Large dead zone** — ~50% vertical empty space; could show last check-in, streak, or mini pose diagram.
2. Timestamp uses real wall clock (11:15 PM) — fine live, inconsistent in staged screenshots.
3. Could not capture **done** state in this pass (tap coordinate guess).

---

### 7. History

**Screenshots:** `pro-seeded/history-v2.png` (actually Today — mis-tap), `pro-seeded/clean-history.png` (onboarding focus page — wrong state). **Reliable session list** described from earlier successful navigation in v2 batch:

When History loaded correctly (from prior capture descriptions):
- Week summary “A strong week of practice” + minutes chart (5m bars, 15m Sunday walk).
- Session rows: practice vs walk icons, pass label, aligned %.

**Issues**
1. **“passed” only on practice rows**, not walks — intentional? Walk shows % without pass/fail; could read as bug.
2. **% metric unexplained** on list rows — aligned %? completion?
3. **Pro trends section** (`HistoryView` `trendsTeaser`) not captured — needs stable Pro main-app entry.
4. Free users see practice chart + check-in journal; trends locked — verify teaser copy entices without feeling like a bait-and-switch.

---

### 8. Progress tab

**Screenshots:** `pro-seeded/settings-v2.png` (true Progress tab — excellent), `pro-progress-scrolled.png` (wrong — onboarding page).

**Pro — what works**
- Standing / sitting segmented control.
- “Level 3” with plain-language targets (5 min, 56% aligned).
- L1–L2 checkmarks, L3 current, L4–L5 ghosted.
- NOW / NEXT compare card.
- Pip row “Pass 2 more sessions to reach Level 4”.
- Links: “How the program works”, “Full program”.

**Issues**
1. **“Full program” row sits under tab bar** when scrolled — touch target overlap risk (`settings-v2.png`).
2. Level 3 with seeded data but Today still on check-ins — **cognitive dissonance** between tabs.

**Free — inferred + partial**
- `ProgressTabUITests` expects **“Unlock the full program”** pinned banner.
- Blurred rungs above level 2 not screenshot’d — high priority for marketing/legal (show ladder but lock detail).

---

### 9. Posture+ tab (free only)

**Screenshot:** `free-seeded/posture-plus-v2.png` (Today tab, not Pro tab — coordinate miss).

**From code (`ProTabView`):** Dedicated upgrade education tab until subscribe.

**Issue:** Could not capture standalone Pro tab content this session. Verify feature grid parity with paywall bullets.

---

### 10. Paywall (`PaywallView`)

**Screenshots:** `paywall/paywall-yearly.png`, `paywall-monthly.png`, `paywall-lifetime.png`, `paywall-trial.png`

**What works**
- Trust row: On-device / Private / No ads.
- Three feature bullets align with progression, trends, monitoring.
- Yearly default with **SAVE 49%** badge + per-week breakdown.
- Trial footer: “No payment today · Reminder day 5 · Billing day 7”.
- **Lifetime** selection changes CTA to **“Unlock Lifetime”** and footer to one-time copy (`paywall-lifetime.png`) — good dynamic UX.
- Monthly selection updates headline subcopy to “Then $4.99 / month” (`paywall-monthly.png`).

**Issues**
1. **Trial sheet mode** (`paywall-trial.png`) crops headline to “...of Posture+” — verify on device with Dynamic Island + sheet detent.
2. Yearly pre-selected while monthly headline variant exists — ensure analytics track default package.
3. “higher bars” in feature copy — slightly opaque jargon.

---

### 11. Walk gate (free)

**Screenshot:** `final/free-walk-gate.png`

- Tapping walk opens **trial-led sheet** (walk trial offer) — matches `TodayView` design.
- **Start trial** triggers **Sign in to Apple Account** modal; simulator keyboard emoji glitch (environmental, not app bug).
- Could not evaluate `WalkSessionView` pre-start chips, GPS toggle, baseline capture.

---

### 12. Settings (Pro)

**Screenshots:** `final/pro-settings-top.png`, `pro-settings-bottom.png` — both blocked by notification dialog.

**From code review:** Pro exposes background monitoring, always-on, recalibrate, coach mark replay, Posture+ postcard (if unsubscribed), rate/feedback.

**Action:** Re-run with notification pre-dismissed (`simctl privacy` or tap Don’t Allow once globally).

---

## Paid vs unpaid comparison

| Surface | Free (observed / inferred) | Pro (observed / inferred) |
|---------|---------------------------|---------------------------|
| Tab bar | 5 tabs incl. **Posture+** lock tab | 4 tabs, no Posture+ |
| Today primary CTA | **Check in now** (no AirPods sim) | Same on sim — should be **Start practice** with connected buds |
| Walk | Trial sheet / lock | Walk pre-start (not captured) |
| Progress | Banner “Unlock the full program”; ladder capped at L2 detail | Full ladder + NOW/NEXT |
| History | Practice minutes + journal | + trends, week delta, hour rhythm, monitoring chart |
| Settings | Paywall postcards on locked toggles | Background monitoring, always-on |
| Onboarding trial | Shown once | Skipped if subscribed |

**Monetization tone:** Soft — Maybe later everywhere, no hard gate on practice pivot. Good for trust; ensure Pro value visible on Today (level cap chip, walk lock) without nag fatigue.

---

## Accessibility & automation

| Issue | Severity | Detail |
|-------|----------|--------|
| Tab bar items lack AX labels | High | `axe` cannot find “History”, “Progress”, etc. VoiceOver likely reads generic “Button” unless `accessibilityLabel` set on `TabView` items |
| Continue button | Medium | Intermittent label miss; XCTest still passes |
| Contrast on ink3 footnotes | Low | Reminder off, freeze subtext — verify WCAG on sand/paper |
| Touch targets under tab bar | Medium | Progress “Full program” row |

---

## Simulator / test infrastructure gaps

1. **`SCREENSHOT_SEED` unreliable** without `-UITEST_FRESH`; fresh install still hit onboarding.
2. **No fake motion pipeline** — blocks practice, walk, calibration complete, live monitor, Live Activity.
3. **Coordinate-based tab taps** don’t port across Pro vs Pro Max (Y 820 vs 900).
4. **Status bar override** poisons time-sensitive UI validation.
5. **`sim76-audit.sh`** stopped early on label misses — script needs XCTest backing or AX id discovery.

Recommend: extend `ScreenshotSeed` to set a `DEBUG` flag forcing practice hero UI for store screenshots; add `-SimulateAirpodsConnected` launch arg.

---

## Prioritized improvement backlog

### P0 — Correctness / trust
1. **Defer notification permission** until after calibration completes or user reaches Today (don’t fire on calibration screen).
2. **Fix hour-chart vs “N today” consistency** on Today.
3. **Align greeting/reminder times** with user-visible clock (or always label “tomorrow” on next reminder).

### P1 — Product clarity
4. Replace **“scans”** with **check-ins** on manual path; reserve “scans” for monitor/minute samples.
5. **Hide or reword AirPods upsell** when `hasAirpods && hasCalibrated` even if not connected — offer “Connect AirPods” instead of “Get AirPods”.
6. **Show practice hero** when calibration exists, even if monitor not live — check-in should be tertiary for calibrated users.
7. Rewrite focus page **“both ways either way”** copy.

### P2 — Polish
8. Check-in screen: fill empty space; celebrate streak.
9. Progress tab: extra bottom scroll padding above tab bar.
10. Paywall trial sheet: increase detent or shrink headline for small devices.
11. Calibration: indeterminate progress while waiting for buds / escape link.

### P3 — Growth / QA enablers
12. DEBUG motion stub for simulator CI screenshots.
13. Expose tab bar `accessibilityLabel`s matching visible titles.
14. SE + iPad layout pass for onboarding and paywall.

---

## Screenshot index (representative)

| ID | Path | Contents |
|----|------|----------|
| S1 | `final/onboard-01-welcome.png` | Welcome + 3 pillars |
| S2 | `final/onboard-02.png` | Posture focus picker |
| S3 | `final/onboard-calibration.png` | Pop in AirPods |
| S4 | `final/onboard-trial.png` | 7-day trial pitch |
| S5 | `pro-seeded/01-today-v2.png` | Today, seeded, check-in hero |
| S6 | `pro-seeded/settings-v2.png` | Progress Level 3 (Pro) |
| S7 | `free-seeded/posture-plus-v2.png` | Today, free, 5-tab bar |
| S8 | `final/session-detail.png` | Manual check-in chips |
| S9 | `paywall/paywall-yearly.png` | Full paywall, yearly default |
| S10 | `paywall/paywall-lifetime.png` | Lifetime CTA variant |
| S11 | `paywall/paywall-trial.png` | Sheet presentation crop |
| S12 | `devices/iphone-17-pro-max-progress.png` | Empty Today, large phone |
| S13 | `final/free-walk-gate.png` | Walk trial + StoreKit sheet |

Full set: `find ../docs/sim76-screenshots -name '*.png'`

---

## Recommended follow-up passes

1. **Device with AirPods** (Jack’s TestFlight build) — practice hold, chin-tuck reps, walk baseline, Live Activity, background monitor orange-dot disclosure.
2. **Free user day-0** — complete one practice on device, trigger `posture_post_first_session` paywall, level-cap gate at L3.
3. **Notification cold-start** — tap practice reminder + check-in reminder payloads.
4. **Watch companion** — out of scope for sim76 but mentioned in paywall copy.
5. Re-run audit after P0 fixes with XCTest-only capture script for deterministic labels.

---

## Appendix: UITest results

```
OnboardingUITests.testOnboardingAdvancesToAirpodsCalibration — PASSED
NewUserWalkthroughUITests.testNewUserNoAirpodsJourney — PASSED
ProgressTabUITests — not run this session (reference for free Progress assertions)
```

---

*End of sim76 audit.*

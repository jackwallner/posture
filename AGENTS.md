# Posture Project Guide
iOS app that uses AirPods and Apple Watch to coach better posture.
Duolingo-style streaks. Pro adds opt-in all-day monitoring.

XcodeGen project/scheme: `Posture`, sim lease owner `posture`.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- SwiftData (App Group container `group.com.jackwallner.posture`, shared with widgets)
- AVFoundation for the audio session only (`AudioKeepAlive`, `AirpodsBackgroundMonitor`), which keeps AirPods background motion sampling alive
- XcodeGen (`project.yml`). Target: iOS 17+

## Architecture

The core loop (2026-07 practice pivot) is a **bounded daily practice session**:
a few minutes of AirPods-coached posture holding, auto-ramping from 3 to 15
minutes via a level system. Completing the session credits the streak; meeting
the session's aligned-% target marks it `passed` and advances the level
(`PracticeProgression`). All-day monitoring is a demoted opt-in Pro extra (off
by default) that no longer credits the streak. No-AirPods users keep the
self-report check-in loop (`AcknowledgmentRecord`). There is NO camera/Vision
pipeline in the app.

Top-level layout:
- `Shared/Models/`: `PostureSession`, `AcknowledgmentRecord`, `PosturePassiveSample`, `PostureMinuteSample`, `Calibration`, `StreakState`, `BeforeAfterPhoto`
- `Shared/Services/`: data/session/scoring/monitoring/notifications (App Group SwiftData; widgets mirror `DataService` schema)
- `Posture/`: iOS UI (onboarding → calibration → MainTabView; dismissible paywall, no hard gate)
- `PostureWidget/`, `PostureWatchWidget/`: lockscreen and watch widgets, plus `PracticeLiveActivity`
- `PostureWatch/`: companion watch app

**Full service/view/model catalog with responsibilities and invariants: `posture-architecture` skill.** Load it before working on Posture internals.

Area rules: `.claude/rules/iphone-duo.md` (unfolded iPhone Duo split, Today beside History, and its capture tour), `.claude/rules/localization.md` (string catalog, `Tools/Localization/check.py`, adding copy), `.claude/rules/ipad-layout.md` (iPad: Today beside History, readable columns, `DeviceKind` gates, capture test).

### Daylight design system

Palette + type tokens in `Shared/Utilities/Theme.swift` (literal colors:
paper / ink / sage / sand / clay / lavender). Type is bundled **Nunito**
(`Posture/Fonts/*.ttf`, OFL). Use `Theme.font(size:weight:)`,
`Theme.font(_:weight:)` or `Theme.display(_:)`. Never use
`.system(design: .rounded)` in new UI code; watchOS falls back to system
rounded (no bundled fonts there). No serif italics, no em dashes in copy.
Posture qualities map: good→sage, borderline→sand, bad→clay. The
look-and-feel brief is in `docs/archive/design/2026-05/design-response/`.

## App-specific gotchas
- `StreakService.applySession(to:at:)` and `dailyGoalSeconds(forStreak:)` are `nonisolated static` so unit tests can call them sync.
- HealthKit lives on the watch target only. The iOS target intentionally has no HealthKit entitlement (audit P1-11). Don't re-add it without a reason.
- The iOS app declares only `UIBackgroundModes = ["audio"]`. Audio supports AirPods background motion sampling (Pro + bounded sessions). App Review rejected the `location` background mode (2.5.4, build 77), so don't re-add it. Walk GPS is foreground-only (when-in-use); pocketed/locked walks fall back to pedometer distance. Usage strings: `NSMotionUsageDescription` (head motion + walk steps/distance) and `NSLocationWhenInUseUsageDescription` (walk GPS). Settings shows a disclosure when the AirPods-background toggle is on (audit P0-3).
- Notification triggers are `UNCalendarNotificationTrigger(... repeats: true)` so reminders survive app kill (audit P1-2). Check-in slot cap is 57, plus 7 weekday practice triggers, inside iOS's 64 pending (P1-4).

## App-specific review

No in-app rating question (App Review 5.6.1). The system `requestReview()` is
the only automatic ask, about 3s after a good result, and only if Today is then
clear of every sheet, cover, paywall and trial pitch (`MainTabView`). Moments:
a **passed practice session** (the daily core action, the one a typical user
reaches in their 2nd or 3rd session), a **good check-in**, and a **streak
milestone** (7/14/30/60/100 days, rare). Predicates live in `ReviewMoment`; a
session that ended on the trial pitch never asks. Gates (`ReviewPromptTracker`):
not before the 2nd cold launch, 30-day cooldown stamped at the call, opening
the write-review page ends the asks, sending feedback never does, never before
onboarding and calibration finish. The remote switch `rating_prompt: off` pauses
it. Settings has separate "Rate Posture" (`AppStoreReviewLinks.writeReviewURL`)
and "Send Feedback" rows. App Store ID `6768514450`. (Shared rules in the
`ios-dev` skill.)

## Remote config

`RemoteConfig` reads the current RevenueCat offering's metadata (a running
Experiment's variant included). Trial button wording tests go through offering
metadata `trial_cta` (`seven_day` control, `my`, `your`); a missing or unknown
value is the control, which is exactly the shipped copy. Switch keys such as
`rating_prompt` must be set the same on every offering. DEBUG launch override:
`-posture.rc.<key> <value>`. Ask to Buy reads "Waiting for approval" on every
purchase surface (`PurchaseFailure`), never an error.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
the global agent rules + the `ios-dev` skill.

# Posture — Project Guide

iOS app that uses iPhone camera + (later) AirPods + Apple Watch to coach better posture.
Duolingo-style streaks. Premium = always-on background monitoring (Phase 4).

XcodeGen project/scheme: `Posture`, simulator device `agent-posture`.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- SwiftData (App Group container `group.com.jackwallner.posture` — shared with widgets)
- Vision (`VNDetectFaceRectanglesRequest`) for head-pose during sessions
- AVFoundation for the front-camera capture pipeline
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
- `Shared/Models/` — `PostureSession`, `AcknowledgmentRecord`, `PosturePassiveSample`, `PostureMinuteSample`, `Calibration`, `StreakState`, `BeforeAfterPhoto`
- `Shared/Services/` — data/session/scoring/monitoring/notifications (App Group SwiftData; widgets mirror `DataService` schema)
- `Posture/` — iOS UI (onboarding → calibration → MainTabView; dismissible paywall, no hard gate)
- `PostureWidget/`, `PostureWatchWidget/` — lockscreen + watch widgets (+ `PracticeLiveActivity`)
- `PostureWatch/` — companion watch app

**Full service/view/model catalog with responsibilities and invariants: `posture-architecture` skill.** Load it before working on Posture internals.

### Daylight design system

Palette + type tokens in `Shared/Utilities/Theme.swift` (literal colors:
paper / ink / sage / sand / clay / lavender). Type is bundled **Nunito**
(`Posture/Fonts/*.ttf`, OFL) via `Theme.font(_:weight:)` /
`Theme.font(size:weight:)` / `Theme.display(_:)` — never use
`.system(design: .rounded)` in new UI code; watchOS falls back to system
rounded (no bundled fonts there). No serif italics, no em dashes in copy.
Posture qualities map: good→sage, borderline→sand, bad→clay. The
look-and-feel brief is in `docs/archive/design/2026-05/design-response/`.

## Plan reference

Full multi-phase plan: `~/.claude/plans/plan-first-floating-pretzel.md`
Phase 1 (current): iPhone-only camera mode, calibration, sessions, streak.
Phase 2: AirPods (`CMHeadphoneMotionManager`). Phase 3: Watch app + complications.
Phase 4: Premium — always-on watch background monitoring (`HKWorkoutSession`).
Phase 5: Before/after photos. Phase 6: Widgets, App Store polish.

## App-specific gotchas

- Free dev account can't build to device (App Group entitlement). Use the simulator.
- `AVCaptureSession` is non-Sendable — `FaceTrackingService` uses `@preconcurrency import AVFoundation`.
- `StreakService.applySession(to:at:)` and `dailyGoalSeconds(forStreak:)` are `nonisolated static` so unit tests can call them sync.
- HealthKit lives on the watch target only — the iOS target intentionally has no HealthKit entitlement (audit P1-11). Don't re-add it without a reason.
- The iOS app declares `UIBackgroundModes = ["audio"]` only — `audio` for AirPods background motion sampling (Pro + bounded sessions). App Review rejected the `location` background mode (2.5.4, build 77): don't re-add it. Walk GPS is foreground-only (when-in-use); pocketed/locked walks fall back to pedometer distance. Usage strings: `NSMotionUsageDescription` (head motion + walk steps/distance) and `NSLocationWhenInUseUsageDescription` (walk GPS). Settings shows a disclosure when the AirPods-background toggle is on (audit P0-3).
- Notification triggers are `UNCalendarNotificationTrigger(... repeats: true)` so reminders survive app kill (audit P1-2). Slot cap is 60 (P1-4).

## App-specific review

Enjoyment funnel after a **good scan** or **streak milestone** (7/14/30/60/100 days); `AppStoreReviewLinks.writeReviewURL`, App Store ID `6768514450`. (Shared funnel mechanics + playbook in the `ios-dev` skill.)

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.

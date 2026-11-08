---
name: posture-architecture
description: Detailed Posture app architecture — every Shared model/service, iOS view, widget, and watch component with its responsibilities and invariants. Load before working on Posture internals (services, scoring, sessions, views, data flow).
---

# Posture — detailed architecture

The core loop (2026-07 practice pivot) is a **bounded daily practice session**:
a few minutes of AirPods-coached posture holding, auto-ramping from 3 to 15
minutes via a level system. Completing the session credits the streak; meeting
the session's aligned-% target marks it `passed` and advances the level
(`PracticeProgression`, pure function of passed-session count). All-day
monitoring still exists but is a demoted opt-in Pro extra (Settings toggle,
off by default) and no longer credits the streak. No-AirPods users keep the
self-report check-in loop (`AcknowledgmentRecord`). There is NO camera/Vision
pipeline in the app.

- `Shared/Models/` — `PostureSession` (practice/walk/legacy via `kindRaw`;
  practice rows carry target/aligned %, `completed`, `passed`; walk rows also
  carry `distanceMeters`, `steps`, `goalIsDistance`, `targetDistanceMeters` —
  all defaulted, additive migration),
  `AcknowledgmentRecord` (check-ins), `PosturePassiveSample` (slouch events),
  `PostureMinuteSample` (per-minute good/borderline/bad aggregates from monitor
  AND sessions — powers % of day aligned, wear time, hour rhythm),
  `Calibration`, `StreakState`, `BeforeAfterPhoto`
- `Shared/Services/`
  - `DataService` — App Group SwiftData container. Widget targets MUST mirror
    its schema exactly (they open the same store).
  - `PracticeProgression` — pure level ramp: passed sessions → level →
    session length + target %. Free tier caps at level 2 (the ladder is the
    upgrade); `LevelLadderView` explains the system + pitches Posture+.
  - `PracticeSessionController` — drives one bounded session: chin-tuck
    warm-up reps (`ChinTuckRepDetector`, practice only) → timed hold; owns
    the motion stream (suspends the monitor), scores at ~25 Hz, accrues
    elapsed from observed sample dt (never a Timer), writes `PostureSession`
    + minute samples, credits the streak on completion, and runs the
    ActivityKit Live Activity (countdown + live alignment in the Dynamic
    Island). Custom-length sessions set `countsForLevel: false` (streak
    only). Walks pass `repsTarget: 0`. Every practice session (including the
    first) opens with the chin-tuck warm-up; the reps screen surfaces a "Skip
    the warm-up" button after ~10s so undetected reps never strand a new user.
    Onboarding calibration honors `GoalSettings.postureFocus` (a standing-only
    user skips the sitting reads and vice versa); Settings → Recalibrate offers
    a per-posture chooser (standing / sitting / walking / everything).
    `CalibrationView.save()` is merge-safe: a partial recalibrate carries the
    other posture's baseline/slouch range AND the walking baseline forward from
    the previous `Calibration` row (a fresh row would otherwise drop them).
  - `AchievementCatalog` — display-only badges derived at read time from
    streak + session rows (no persistence). Surfaces: `AchievementsView`
    grid, Today teaser row, summary unlock lines.
  - `MinuteBucket` — pure per-minute aggregation shared by monitor + sessions
    (dt clamp 2s, ≥1s flush floor).
  - `AudioKeepAlive` — refcounted silent-audio engine (`acquire`/`release`)
    keeping CoreMotion alive in background; held by the monitor (indefinite,
    Pro toggle) and by sessions (bounded).
  - `WalkMetricsService` — iOS-only live walk metrics: `CMPedometer`
    (steps, distance estimate, cadence) + optional `CoreLocation` GPS for
    accurate distance. `isWalking` (step-delta gate): while false the walk
    clock KEEPS RUNNING but the time scores as rest (`.bad`), so sitting
    still can't fake a good walk and the in-app countdown never drifts from
    the Live Activity/watch countdown; slouch nudges are suppressed while
    stationary. Degrades to always-walking when the pedometer is absent
    (Simulator). Owned by `PracticeSessionController` for walk sessions.
  - `PostureScoring` — pure scoring (testable). `postureReference` picks the
    *nearer* of the standing/sitting baselines AND that posture's own
    calibrated slouch delta (`Calibration.standingSlouchDelta` /
    `sittingSlouchDelta`, nil on legacy rows → `slouchPitchDelta` fallback);
    the slouch reference is capped at π/16 at scoring time so
    small-amplitude standing slouches register. Also home of `ChinTuck` +
    `ChinTuckRepDetector` (warm-up rep counting).
  - `PostureDayStats` — pure aggregation over minute samples (testable)
  - `StreakService` — streak math + freeze logic. `currentState()` is the *only*
    get-or-create path for `StreakState`; views must never insert in `body`.
  - `CalibrationService` — baseline storage (AirPods standing/sitting/slouch)
  - `NotificationService` — one repeating daily practice reminder
    (`posture.practice.daily`, hour/minute from GoalSettings) + optional
    every-N-minutes check-in slots (repeating `UNCalendarNotificationTrigger`)
  - `ReminderScheduler` — orchestrates the reschedule on settings/foreground
  - `AirpodsBackgroundMonitor` — one shared monitor, two modes decided by
    `reconcileMonitoring` in App.swift: Pro all-day background (Settings
    toggle, silent-audio keep-alive) or the free in-app live readout
    (`GoalSettings.inAppLiveEnabled`, default on, foreground only). Only the
    Pro background mode persists minute samples (`persistsMinutes`, set from
    `start(background:)`); the foreground glance is display-only and must NOT
    count toward % of day aligned / wear / trends. `userPaused` is the manual
    Stop from Today's card — auto-start paths must respect it.
    `suspendForForegroundRead()`/`resumeAfterForegroundRead()` is the handoff
    every foreground reader (calibration, scan, session) must use
  - `HeadphoneMotionService` — foreground `CMHeadphoneMotionManager` wrapper
  - `GoalSettings` — `@Observable` UserDefaults wrapper (App Group)
  - `SubscriptionService` — RevenueCat (guarded by `#if canImport(RevenueCat)`)
  - `AnalyticsService`, `PostureTipService`
- `Posture/` — iOS UI
  - `App.swift` → onboarding (incl. posture-focus choice) → calibration →
    MainTabView (Today / History / Progress / Posture+ [non-subscribers only] /
    Settings). No hard paywall gate: free core loop, dismissible paywall
    after the first completed session (`posture_post_first_session`) and at
    Pro gates (`posture_level_gate`, `posture_walk_gate`,
    `posture_trends_gate`, `posture_pro_tab`, Settings postcard). Holds the
    AirPods monitor (`reconcileMonitoring`) and both notification-tap
    fullScreenCovers (check-in ack + practice session).
  - `Views/PracticeSessionView.swift` — the session screen (pre-start with
    custom-length menu → chin-tuck warm-up reps → live ring → paused →
    summary); first hold shows in-session coach marks, replayable from
    Settings via `.postureReplaySessionCoachMarks`
  - `Views/WalkSessionView.swift` — walk mode (Pro): a **Time or Distance**
    goal (minute chips / distance chips + custom wheels), an optional GPS
    toggle, and a live steps + distance readout. Rolling-median walk scoring
    (`PostureScoring.Walk`) against the one-time walking baseline
    (`WalkBaselineCaptureView`: intro → get-moving countdown → 30s walking
    capture → explicit "Start my walk", never auto-started; redoable from the
    walk pre-start link or Settings → "Reset walking posture"), anchored at
    scoring time to within `Walk.maxLeanFromStanding` of the standing
    calibration (`Walk.anchoredBaseline`) so a slouched capture can't poison
    the scale. The legacy per-walk 30s auto-baseline remains only for users
    with no saved capture. Stationary time counts as rest, not held time.
    Credits the streak, never the level.
  - `Views/OnboardingTrialView.swift` — the "7 days on us" trial pitch shown
    once after calibration to non-subscribers (`hasSeenOnboardingTrial` gate in
    `RootView`); dismissible ("Maybe later"), opens `PaywallView` as a sheet
    for the actual purchase (`posture_onboarding_trial`).
  - `Views/SessionSummaryView.swift` — kind-aware receipt (pass/fail + level
    for practice, % tall for walks), segment timeline, new-badge lines
  - `Views/HistoryView.swift` — practice-first: minutes/day chart, tappable
    session receipts (`SessionDetailView`), Pro-gated trends (week delta,
    monitoring chart, hour rhythm), free check-in journal
  - `Views/AcknowledgmentView.swift` — the fullscreen check-in on reminder tap
  - `Views/ProgressTabView.swift` — the Progress tab: the full level ladder,
    crisp for Pro, per-rung detail blurred for free (level rungs still shown)
  - `Views/LevelLadderView.swift`, `Views/StreakDetailView.swift`,
    `Views/AchievementsView.swift`, `Views/ProTabView.swift` — explainer /
    detail sheets opened from Today (level chip, streak chip, badges row)
    and the tab bar
  - `Views/Components/` — Daylight design system pieces (HorizonMeter, DayStrip,
    PostureBanner, QualityChip, TipLine, DaylightCTA, AirpodsScanView,
    PostureRing, StreakFlame, PoseDiagram).
    `PoseDiagram` renders drawn pose visuals and auto-swaps to bundled `Illo*`
    asset-catalog images when present.
- `PostureWidget/`, `PostureWatchWidget/` — lockscreen + watch widgets, read
  from the shared App Group container (schemas must mirror `DataService`).
  `PostureWidget` also hosts `PracticeLiveActivity` (ActivityKit Dynamic
  Island/lock-screen countdown; attributes in
  `Shared/Utilities/PracticeActivityAttributes.swift`).
- `PostureWatch/` — companion watch app

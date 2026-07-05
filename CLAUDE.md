# Posture — Project Guide

iOS app that uses iPhone camera + (later) AirPods + Apple Watch to coach better posture.
Duolingo-style streaks. Premium = always-on background monitoring (Phase 4).

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- SwiftData (App Group container — shared with widgets in later phases)
- Vision (`VNDetectFaceRectanglesRequest`) for head-pose during sessions
- AVFoundation for the front-camera capture pipeline
- XcodeGen (`project.yml` → `.xcodeproj`)
- Target: iOS 17+

## Build & Run

```bash
xcodegen generate

# Simulator (works without paid dev account) — use the dedicated device, see
# "Simulator — dedicated, headless" section below
UDID=$(agent-sim boot posture)
xcodebuild -project Posture.xcodeproj -scheme Posture -destination "id=$UDID" build
xcodebuild test -project Posture.xcodeproj -scheme Posture -destination "id=$UDID"
```

Device builds need a registered App Group (`group.com.jackwallner.posture`) — fails on free dev account.

After adding/removing any `.swift` file, rerun `xcodegen generate`.

## Architecture

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
  practice rows carry target/aligned %, `completed`, `passed`),
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
    only). Walks pass `repsTarget: 0`.
  - `AchievementCatalog` — display-only badges derived at read time from
    streak + session rows (no persistence). Surfaces: `AchievementsView`
    grid, Today teaser row, summary unlock lines.
  - `MinuteBucket` — pure per-minute aggregation shared by monitor + sessions
    (dt clamp 2s, ≥1s flush floor).
  - `AudioKeepAlive` — refcounted silent-audio engine (`acquire`/`release`)
    keeping CoreMotion alive in background; held by the monitor (indefinite,
    Pro toggle) and by sessions (bounded).
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
    (`GoalSettings.inAppLiveEnabled`, default on, foreground only). Both
    record minute samples. `userPaused` is the manual Stop from Today's
    card — auto-start paths must respect it.
    `suspendForForegroundRead()`/`resumeAfterForegroundRead()` is the handoff
    every foreground reader (calibration, scan, session) must use
  - `HeadphoneMotionService` — foreground `CMHeadphoneMotionManager` wrapper
  - `GoalSettings` — `@Observable` UserDefaults wrapper (App Group)
  - `SubscriptionService` — RevenueCat (guarded by `#if canImport(RevenueCat)`)
  - `AnalyticsService`, `PostureTipService`
- `Posture/` — iOS UI
  - `App.swift` → onboarding (incl. posture-focus choice) → calibration →
    MainTabView (Today / History / Posture+ [non-subscribers only] /
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
  - `Views/WalkSessionView.swift` — walk mode (Pro): 10/20/30-min chips +
    custom wheel (5–120), rolling-median walk scoring (`PostureScoring.Walk`),
    30s warmup excluded from the score; credits the streak, never the level
  - `Views/SessionSummaryView.swift` — kind-aware receipt (pass/fail + level
    for practice, % tall for walks), segment timeline, new-badge lines
  - `Views/HistoryView.swift` — practice-first: minutes/day chart, tappable
    session receipts (`SessionDetailView`), Pro-gated trends (week delta,
    monitoring chart, hour rhythm), free check-in journal
  - `Views/AcknowledgmentView.swift` — the fullscreen check-in on reminder tap
  - `Views/LevelLadderView.swift`, `Views/StreakDetailView.swift`,
    `Views/AchievementsView.swift`, `Views/ProTabView.swift` — explainer /
    detail sheets opened from Today (level chip, streak chip, badges row)
    and the tab bar
  - `Views/Components/` — Daylight design system pieces (HorizonMeter, DayStrip,
    PostureBanner, QualityChip, TipLine, DaylightCTA, AirpodsScanView,
    PostureRing, StreakFlame, PoseDiagram).
    `PoseDiagram` renders drawn pose visuals and auto-swaps to
    `Illo*` asset-catalog images when present — generate them with
    `scripts/generate-illustrations.py` (needs a billed Gemini key).
- `PostureWidget/`, `PostureWatchWidget/` — lockscreen + watch widgets, read
  from the shared App Group container (schemas must mirror `DataService`).
  `PostureWidget` also hosts `PracticeLiveActivity` (ActivityKit Dynamic
  Island/lock-screen countdown; attributes in
  `Shared/Utilities/PracticeActivityAttributes.swift`).
- `PostureWatch/` — companion watch app

### Daylight design system

Palette + type tokens in `Shared/Utilities/Theme.swift` (literal colors:
paper / ink / sage / sand / clay / lavender). Type is bundled **Nunito**
(`Posture/Fonts/*.ttf`, OFL) via `Theme.font(_:weight:)` /
`Theme.font(size:weight:)` / `Theme.display(_:)` — never use
`.system(design: .rounded)` in new UI code; watchOS falls back to system
rounded (no bundled fonts there). No serif italics, no em dashes in copy.
Posture qualities map: good→sage, borderline→sand, bad→clay. The
look-and-feel brief is in `docs/design-response/`.

## Plan reference

Full multi-phase plan: `~/.claude/plans/plan-first-floating-pretzel.md`

Phase 1 (current): iPhone-only camera mode, calibration, sessions, streak.
Phase 2: AirPods (`CMHeadphoneMotionManager`).
Phase 3: Watch app + complications.
Phase 4: Premium — always-on watch background monitoring (`HKWorkoutSession`).
Phase 5: Before/after photos.
Phase 6: Widgets, App Store polish.

## Scripts

- `scripts/testflight.sh` — push to TestFlight / ship a build
- `scripts/pull-appstore-metadata.sh` — snapshots `fastlane/metadata/` to `metadata.bak.<timestamp>/`, then runs `fastlane deliver download_metadata`. ALWAYS run before editing `fastlane/metadata/*.txt`; diff against the snapshot to confirm what changed remotely.
- `scripts/upload-appstore-metadata.sh` — `fastlane upload_metadata` (screenshots + listing copy, no binary, no submit-for-review).

ASC API key (shared across apps): `~/.baseball_credentials` (`ASC_API_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`).

## App Store reviews

Enjoyment funnel after a **good scan** or **streak milestone** (7/14/30/60/100 days); explicit Rate → `AppStoreReviewLinks.writeReviewURL` (`6768514450`); `requestReview()` only after Yes + "Maybe later" dismiss. Settings → **Rate or Send Feedback**. Playbook: `~/Desktop/app-store-5-star-review-strategy.md`.

## Gotchas

- Free dev account can't build to device (App Group entitlement). Use simulator.
- `AVCaptureSession` is non-Sendable — `FaceTrackingService` uses `@preconcurrency import AVFoundation`.
- `StreakService.applySession(to:at:)` and `dailyGoalSeconds(forStreak:)` are `nonisolated static` so unit tests can call them sync.
- HealthKit lives on the watch target only — the iOS target intentionally has no
  HealthKit entitlement (audit P1-11). Don't re-add it without a reason.
- The iOS app declares `UIBackgroundModes = ["audio"]` for AirPods background
  motion sampling (Pro feature). Settings shows a disclosure when the toggle is
  on (audit P0-3).
- Notification triggers are `UNCalendarNotificationTrigger(... repeats: true)`
  so reminders survive app kill (audit P1-2). Slot cap is 60 (P1-4).

## Simulator — dedicated, headless (required)

This project owns the simulator device `agent-posture`. Multiple agents work in
parallel on this machine: NEVER build/test against a shared named destination
(e.g. `name=iPhone 17 Pro`) and NEVER open Simulator.app — it steals Jack's
mouse/keyboard. Everything runs headless. Full guide: `~/docs/ios-agent-simulators.md`

```bash
UDID=$(agent-sim boot posture)        # create if needed + boot headless; prints UDID
xcodebuild -project Posture.xcodeproj -scheme Posture -destination "id=$UDID" build
xcodebuild test -project Posture.xcodeproj -scheme Posture -destination "id=$UDID"
APP=$(find ~/Library/Developer/Xcode/DerivedData/Posture-*/Build/Products -maxdepth 2 -name "*.app" -path "*iphonesimulator*" | head -1)
xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" "$(defaults read "$APP/Info" CFBundleIdentifier)"
axe describe-ui --udid "$UDID"        # inspect UI via accessibility tree
axe tap --label "Continue" --udid "$UDID"   # interact without mouse/keyboard
agent-sim screenshot posture          # PNG at /tmp/agent-posture.png
agent-sim shutdown posture            # free resources when done
```

## TestFlight on every update

After finishing a change and pushing to git, ALWAYS upload a new TestFlight build by
running `./scripts/testflight.sh` — do this unprompted on every push that changes app
code. Jack tests every update on his device and shouldn't have to ask.

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

# Simulator (works without paid dev account)
xcodebuild -project Posture.xcodeproj -scheme Posture \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build

xcodebuild test -project Posture.xcodeproj -scheme Posture \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

Device builds need a registered App Group (`group.com.jackwallner.posture`) — fails on free dev account.

After adding/removing any `.swift` file, rerun `xcodegen generate`.

## Architecture

The product pivoted from timed camera *sessions* to a reminder/acknowledgment loop:
the app schedules N reminders per day in the user's active window, each tap opens a
~3 second QuickScan, and the result is written as an `AcknowledgmentRecord`. Old
`PostureSession` model is retained for back-compat reads but no longer written.

- `Shared/Models/` — `AcknowledgmentRecord` (current), `PostureSession` (legacy),
  `PosturePassiveSample`, `Calibration`, `StreakState`, `BeforeAfterPhoto`
- `Shared/Services/`
  - `DataService` — App Group SwiftData container
  - `PostureScoring` — pure scoring (testable)
  - `StreakService` — streak math + freeze logic. `currentState()` is the *only*
    get-or-create path for `StreakState`; views must never insert in `body`.
  - `CalibrationService` — baseline storage
  - `FaceTrackingService` — AVCapture + Vision face landmarks → head pitch
  - `NotificationService` — schedules per-day rotation of reminders (repeating
    `UNCalendarNotificationTrigger`)
  - `ReminderScheduler` — orchestrates the reschedule on settings/foreground
  - `AirpodsBackgroundMonitor` — Pro-only background AirPods motion sampling
  - `HeadphoneMotionService` — foreground `CMHeadphoneMotionManager` wrapper
  - `GoalSettings` — `@Observable` UserDefaults wrapper (App Group)
  - `SubscriptionService` — RevenueCat (guarded by `#if canImport(RevenueCat)`)
  - `AnalyticsService`, `PostureTipService`
- `Posture/` — iOS UI
  - `App.swift` → onboarding → calibration → MainTabView (Today / History / Settings).
    Holds the AirPods monitor and the notification-tap fullScreenCover.
  - `Views/AcknowledgmentView.swift` — the fullscreen sheet shown on reminder tap
  - `Views/Components/` — Daylight design system pieces (HorizonMeter, DayStrip,
    WeekStrip, PostureBanner, QualityChip, TipLine, DaylightCTA, QuickScanView,
    CameraPreview, PostureRing, StreakFlame)
- `PostureWidget/`, `PostureWatchWidget/` — lockscreen + watch widgets, read
  `AcknowledgmentRecord` from the shared App Group container
- `PostureWatch/` — companion watch app

### Daylight design system

Palette + type tokens in `Shared/Utilities/Theme.swift`, backed by asset-catalog
`Daylight*` colorsets (paper / ink / sage / sand / clay, with dark variants).
Body type is rounded SF Pro; ritual moments use SF Serif italic
(`Theme.displaySerif(_:)`). Posture qualities map: good→sage, borderline→sand,
bad→clay. The look-and-feel brief is in `docs/design-response/`.

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

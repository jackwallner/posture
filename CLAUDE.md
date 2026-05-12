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

## Architecture (Phase 1)

- `Shared/Models/` — five SwiftData `@Model` types (PostureSession, PosturePassiveSample, Calibration, StreakState, BeforeAfterPhoto)
- `Shared/Services/`
  - `DataService` — App Group SwiftData container
  - `PostureScoring` — pure scoring (testable)
  - `StreakService` — streak math + freeze logic (testable)
  - `CalibrationService` — baseline storage
  - `SessionEngine` — `@Observable` session runner; ingests pose samples → emits live quality + writes session on finish
  - `FaceTrackingService` — AVCapture + Vision face landmarks → head pitch
  - `GoalSettings` — `@Observable` UserDefaults wrapper (App Group)
  - `NotificationService` — daily reminder
- `Posture/` — iOS UI
  - `App.swift` → onboarding → calibration → MainTabView (Today / History / Settings)
  - `Views/Components/` — PostureRing, StreakFlame, PostureLiveIndicator, CameraPreview

## Plan reference

Full multi-phase plan: `~/.claude/plans/plan-first-floating-pretzel.md`

Phase 1 (current): iPhone-only camera mode, calibration, sessions, streak.
Phase 2: AirPods (`CMHeadphoneMotionManager`).
Phase 3: Watch app + complications.
Phase 4: Premium — always-on watch background monitoring (`HKWorkoutSession`).
Phase 5: Before/after photos.
Phase 6: Widgets, App Store polish.

## Gotchas

- Free dev account can't build to device (App Group entitlement). Use simulator.
- `AVCaptureSession` is non-Sendable — `FaceTrackingService` uses `@preconcurrency import AVFoundation`.
- `StreakService.applySession(to:at:)` and `dailyGoalSeconds(forStreak:)` are `nonisolated static` so unit tests can call them sync.
- `SessionEngine` finalizes the session via a 1Hz ticker, accumulating time-in-quality buckets.

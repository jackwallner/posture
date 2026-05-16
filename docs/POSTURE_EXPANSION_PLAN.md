# Posture — Full Expansion & Cleanup Plan

A systematic audit of every component in the Posture project, what needs fixing,
and how to make this app excellent.

---

## A. Code Duplication & Structural Asymmetry

### A1. `WatchSessionView` duplicates `SessionEngine` logic

**Problem**: The watch has its own inline ticker (`startTicker()`), quality
classification (`PostureScoring.quality()` call), time-in-quality accumulation,
session writing, and finish logic — all in a view. This is a ~50-line
reimplementation of what `SessionEngine` already does.

**Fix**: Make `SessionEngine` watchOS-compatible. The only iOS-specific thing is
`FaceTrackingService`/`HeadphoneMotionService` reference, which it doesn't use
directly — it just takes `ingestPitchDeviation(_:)` from anywhere. Add
`#if os(watchOS)` guards or extract a `SessionEngineProtocol`. Have
`WatchSessionView` create a `SessionEngine` and wire it to `WatchMotionService`.
This eliminates the duplication entirely and ensures scoring/bucket logic stays
in one place.

### A2. `PostureRingCompact` vs `PostureRing`

**Problem**: `WatchTodayView` defines a private `PostureRingCompact` struct
(80x80, 8px line, score label) that's a hard fork of
`Posture/Components/PostureRing.swift`. The shared one already has `size` and
`lineWidth` parameters — it would work on watchOS with different defaults.

**Fix**: Delete `PostureRingCompact`. Use `PostureRing(score:size:lineWidth:)`
with small defaults on watchOS. Put it in the Shared target if not already.

### A3. Watch session `finish()` duplicates `SessionEngine.finish()`

**Problem**: Both `SessionEngine.finish()` and `WatchSessionView.finish()`
create `PostureSession`, insert into context, save, and set finished state.
The watch version also calls `StreakService.recordSessionCompleted()` in its
`begin()` callback while iOS does it in `SessionView.onChange(of: engine?.state)`.

**Fix**: If A1 is done, this goes away naturally. At minimum, extract session
wrapping into `SessionEngine` and call it uniformly from both platforms.

---

## B. Dead Code, Stubs & Incomplete Features

### B1. `BeforeAfterPhoto` model — defined but completely unused

**Problem**: Model exists with `headForwardAngle` and `note` fields, zero
references in any view, service, or test. It's Phase 5 placeholder.

**Fix options**:
- **Implement Phase 5**: Add a `BeforeAfterView` (camera capture -> save photo to
  documents -> display before/after side-by-side -> optional angle annotation).
  Gate behind Pro paywall. This is a significant new feature.
- **Delete it**: If Phase 5 isn't shipping soon, remove the dead model to keep
  the schema clean and avoid confusion.

### B2. `watchGravityX/Y/Z` never captured during calibration

**Problem**: `Calibration.swift` has nullable fields `watchGravityX/Y/Z`, but
`CalibrationView.swift` never writes them. The watch falls back to a hardcoded
`slouchPitchDelta = .pi / 6` (30 deg) when no calibration exists, or uses whatever
default the Gravity baseline gets set to at runtime.

**Fix**: After the main calibration countdown finishes, sample `WatchMotionService`
gravity on the companion phone (using `CMDeviceMotion` if available on iPhone) or
design a dedicated watch-side calibration step. At minimum, let the user initiate
a calibration from the watch.

### B3. No freeze refill mechanism

**Problem**: `StreakState.freezesAvailable` starts at 2, is decremented on use,
and is **never replenished**. After two missed days the freeze mechanic is
permanently exhausted.

**Fix**: Add a freeze refill strategy:
- **Weekly refill**: Reset to 2 every Monday at midnight.
- **Earn through sessions**: +1 freeze per N consecutive streak days.
- **Purchase**: Bonus freezes as an IAP add-on.
- Best approach: Weekly refill + earn bonus freezes at streak milestones (7, 14, 30 days).

### B4. `PostureSource` enum - `watch` route unused on iOS

**Problem**: `PostureSource.watch` exists as a case, but `SessionView.prepare()`
only chooses between `.camera` and `.airpods`. There's no pathway on iOS to use
the watch as a sensor source for a session.

**Fix**: During session preparation, probe Watch Connectivity or check if a
watch session is already active, and offer `.watch` as a source if the user has
a watch and it's calibrated.

---

## C. Missing Features

### C1. iOS Lock Screen Widget

**Problem**: Phase 6 is "Partial" -- only a watch widget exists. No iOS widget
for the lock screen or home screen.

**Fix**: Create an iOS widget target that shows today's posture ring score,
streak count, and "do a session" deep link. Use `WidgetKit` with
`StaticConfiguration` + `AppIntentConfiguration` for iOS 17+ interactivity.

Note: This adds a new target to `project.yml`.

### C2. No real-time Watch <-> Phone communication

**Problem**: All data sync is via shared App Group SQLite file on disk. There's
no `WCSession` anywhere. The phone can't know the watch fired a slouch event
until the next app launch reads the file.

**Fix**: Add `WatchConnectivity/WCSession` for real-time communication:
- Watch -> Phone: slouch events, session completions, calibration requests
- Phone -> Watch: configuration pushes (sensitivity change, always-on toggle in real time)
- Keep SwiftData as the persistent canonical store; use WCSession for live updates.

### C3. No haptic or audio feedback during iOS camera sessions

**Problem**: Watch session has haptic nudges (`WKInterfaceDevice.play(.notification)`)
after 8s of bad posture. The iOS camera session has zero haptic feedback -- the
user has to watch the `PostureLiveIndicator`.

**Fix**: Use `UIImpactFeedbackGenerator` or `UINotificationFeedbackGenerator` on
iOS to buzz when posture quality drops to `.bad` for sustained periods. This
makes camera sessions feel active without requiring visual attention.

### C4. No session pause/resume

**Problem**: Once a session starts, there's no way to pause it -- the user must
cancel entirely or ride it out. This is particularly bad if someone needs to
adjust their setup mid-session.

**Fix**: Add a pause button to `SessionView` / `WatchSessionView`. The
`SessionEngine` state machine gets a `.paused` state. The ticker stops
accumulating seconds. Resume unpauses the ticker.

### C5. No guided recalibration workflow

**Problem**: Settings has a recalibrate button, but it just calls
`CalibrationService.clear()` and flips `GoalSettings.hasCalibrated = false` --
which dumps the user into the full onboarding calibration flow again. There's no
"quick recalibrate" option.

**Fix**: Add a "Quick Recalibrate" flow that skips the AirPods question and goes
straight to a 3-second capture. Preserve existing AirPods baseline unless the
user asks to redo it.

### C6. Watch complication shows streak, not today's score

**Problem**: All 4 widget families show streak count prominently. Today's score
is shown only on `inline` and `rectangular` as secondary text. For many users,
"how was my posture today?" is a more interesting question.

**Fix**: Offer a configuration variant (via `AppIntent`) that switches between
"Streak focus" and "Score focus" for the complication. On `circular`, show score
instead of streak when configured.

### C7. No weekly/monthly trend view

**Problem**: HistoryView just lists sessions chronologically. There's no trend
chart, weekly average, or progress-over-time visualization -- the core "am I
getting better?" question is unanswered.

**Fix**: Add a trend section to `HistoryView` (or a new tab) showing:
- 7-day rolling average score
- Session duration trend
- Total good/borderline/bad time per week
- Simple Swift Charts bar or line chart
- This is a Pro feature candidate.

### C8. No session coaching tips

**Problem**: The app tells you "Sit up" but doesn't educate. Users don't learn
_what_ to improve.

**Fix**: Add post-session coaching cards: "Your posture dips between seconds
20-30 -- try keeping your shoulders back." Or show positional advice based on
which axis (pitch vs yaw vs roll) drifted most.

---

## D. Architecture & Code Quality

### D1. No formal protocols for sensor services

**Problem**: `FaceTrackingService`, `HeadphoneMotionService`, and
`WatchMotionService` all have different interfaces. They can't be swapped
polymorphically. `SessionEngine.ingestPitchDeviation()` takes a raw `Double`,
but each sensor produces that Double differently.

**Fix**: Define a `PostureSensor` protocol:

```swift
protocol PostureSensor: AnyObject {
    var isAvailable: Bool { get }
    var isRunning: Bool { get }
    var onPitchDeviation: ((Double) -> Void)? { get set }
    func start() async
    func stop()
}
```

Make all three services conform. This enables `SessionEngine` to accept any
sensor, and `SessionView` to pick the best available one generically.

### D2. `SessionEngine` uses `weak self` in ticker -- fragile

**Problem**: The ticker `Task` captures `[weak self]` and checks `guard let self`
on every iteration. If `SessionEngine` is deallocated mid-session (unlikely but
possible with SwiftUI lifecycle quirks), the ticker silently stops.

**Fix**: Make the ticker own a strong reference to the engine via a task-local
reference, or use `AsyncStream` for the timer instead of a manual `Task.sleep`
loop. At minimum, add a `deinit { ticker?.cancel() }`.

### D3. `FaceTrackingService` uses `@preconcurrency import AVFoundation`

**Problem**: AVCaptureSession is non-Sendable. The service wraps it in
`@MainActor` but bridges callbacks via `unchecked` continuation. This is
fragile and could crash if the delegate callback fires on a different thread.

**Fix**: Audit the delegate callback path -- ensure all delegate methods dispatch
back to `@MainActor` before accessing the session. Use `OSAllocatedUnfairLock`
or `Actor` isolation for the buffer if performance requires off-main processing.

### D4. `BackgroundPostureWorkout` re-creates `ModelContext` per slouch event

**Problem**: Each slouch event does `let context = ModelContext(DataService.sharedModelContainer)`
-- creating a new context, inserting, saving, then discarding. This is wasteful
and can cause SQLite write contention.

**Fix**: Hold a persistent `ModelContext` for the duration of the workout. Batch
writes or use a dedicated serial actor for SwiftData operations.

### D5. `DataService` resilience is good but manual

**Problem**: The corruption wipe-and-retry logic is solid, but the in-memory
fallback means the app silently loses all data on launch without user awareness.

**Fix**: After fallback to in-memory, post a warning (maybe via `Logger`) and
show a one-time alert: "Your posture data couldn't be loaded. Previous sessions
will appear once the issue is resolved." Provide a "try again" action that
reattempts the disk store.

### D6. Subscription status not refreshed on watch

**Problem**: `BackgroundPostureWorkout` checks `GoalSettings.shared.alwaysOnEnabled`
and `SubscriptionService.shared.isProSubscriber`, but the watch import of
`SubscriptionService` can't use RevenueCat (no `canImport(RevenueCat)`) --
it reads a stale `false` or whatever was set via `setLocalOverride`. There's no
RevenueCat SDK in the watch target's dependencies in `project.yml`.

**Fix**: Either add RevenueCat to the watch target, or use a different mechanism:
watch reads subscription status from shared UserDefaults (set by the iOS app
after purchase refresh), and the iOS app pushes status via WCSession or writes
it to the shared App Group defaults.

### D7. `GoalSettings.shared` is a global singleton

**Problem**: Accessed directly from `PostureApp`, `CalibrationView`,
`SessionView`, `WatchSessionView`, `TodayView`, `WatchSettingsView`,
`BackgroundPostureWorkout`. Hard to test, hard to swap for previews.

**Fix**: Inject via SwiftUI `.environment()` everywhere. The `PostureApp` already
does `.environment(settings)` -- but many views still use `GoalSettings.shared`
directly instead of `@Environment`. Clean up all consumers.

---

## E. Testing Gaps

### E1. Only 2 test files with 18 tests

**Problem**: Coverage chart:

| Component | Tests | Status |
|---|---|---|
| `PostureScoring` | 9 tests | Good -- quality thresholds, session scoring, smoothing |
| `StreakService` | 9 tests | Good -- all streak scenarios covered |
| `SessionEngine` | **0** | No tests for state machine, ticker, finish logic |
| `FaceTrackingService` | **0** | Hard to test (AVFoundation), but integration test possible |
| `HeadphoneMotionService` | **0** | Same, hardware-dependent |
| `WatchMotionService` | **0** | Same, hardware-dependent |
| `BackgroundPostureWorkout` | **0** | Complex logic -- sustained detection, cooldown, state mgmt |
| `CalibrationService` | **0** | SwiftData CRUD -- trivially testable |
| `StreakService` (model) | **0** | `dailyGoalSeconds` formula -- trivial |
| `DateHelpers` | **0** | Pure date math -- trivially testable |
| `DataService` | **0** | Container creation, corruption recovery |
| `GoalSettings` | **0** | UserDefaults wrapper -- testable with `UserDefaults(suiteName:)` |
| `Theme` | **0** | Regression tests for color values |

**Fix**: Minimum viable test additions:
- `SessionEngineTests`: State transitions, ingest to quality mapping,
  finish to session creation, cancel mid-session, ticker accumulation (use
  `Task.sleep` with timeouts).
- `CalibrationServiceTests`: Save, fetch latest, clear -- all with in-memory
  container.
- `DateHelpersTests`: `startOfDay`, `daysBetween`, `isSameDay` at midnight
  boundaries.
- `SubscriptionServiceTests`: Stub RevenueCat, test refresh path.

---

## F. UX & UI Polish

### F1. Onboarding video (from VIDEO_REVIEW_NOTES)

**Problem**: The review notes say "remove streak UI from intro" -- the
`OnboardingView` currently shows a streak preview that teases future mechanics
but confuses new users.

**Fix follow-through**: Confirm streak UI is removed from onboarding. Replace
with a simple 3-step carousel: (1) "We track your head position", (2) "Daily
sessions build the habit", (3) "Get started."

### F2. Calibration UX (from VIDEO_REVIEW_NOTES)

**Problem**: Add "Do you have AirPods?" question (already done). Improve
calibration countdown and feedback. The calibration currently grabs 10 samples
over 1 second after the countdown -- users may move during this.

**Fix**: Show a live waveform or pitch indicator during capture so users can see
when they're holding still. Extend the sample window or add a stability check
(variance threshold) before accepting the baseline.

### F3. Empty states across the app

**Problem**:
- `HistoryView` has an empty state ("No sessions yet") -- good, but it doesn't
  invite action.
- `PassiveTimelineView` shows an empty bar chart when there are no samples.
- `TodayView` when no session yet is fine but could be more engaging.

**Fix**: Make empty states actionable:
- History empty: "Start your first session ->" button.
- PassiveTimeline empty: "Enable always-on monitoring to see your slouch pattern."
- TodayView pre-session: Show the user's current streak goal, sensitivity
  setting, and a motivational message.

### F4. Session transition animations

**Problem**: The `TodayView` to `SessionView` transition via `.fullScreenCover`
is abrupt. The session end to score card is also instantaneous.

**Fix**: Add a smooth morph / scale transition between TodayView's ring and
SessionView's ring. Animate the score card appearing with a spring. On the watch,
add a haptic + animation when the session completes.

### F5. `PostureLiveIndicator` text tweaks

**Problem**: Current labels are "Good", "Watch your posture", "Sit up!" --
functional but generic.

**Fix**: Use more contextual labels:
- Good: "Great form" / "Looking good" (rotating pool)
- Borderline: "Shift back" / "Ease up" / "Check your angle"
- Bad: "Slumping!" / "Straighten up" / "Sit tall"

### F6. Accessibility audit

**Problem**: Likely none done yet. No `accessibilityLabel`, `accessibilityValue`,
or `accessibilityHint` on custom components. The `PostureRing` shows a score
visually but VoiceOver reads nothing.

**Fix**: Add accessibility modifiers to:
- `PostureRing`: "Posture score: X out of 100, [quality label]"
- `StreakFlame`: "X day streak"
- `PostureLiveIndicator`: "Current posture: [quality]"
- `PassiveTimelineView`: chart summary as an accessibility representation

### F7. Haptic feedback parity

**Problem**: Watch has haptics (`WKInterfaceDevice.play(.notification)`). iOS
session has UIKit heavyweight haptics (`UIImpactFeedbackGenerator`) available but
unused. Also, iOS doesn't vibrate on session completion.

**Fix**: Add `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` on
quality drops to `.bad` (with cooldown). Add `UINotificationFeedbackGenerator`
success notification on session completion.

---

## G. App Store Readiness

### G1. RevenueCat paywall polish

**Problem**: When RevenueCatUI isn't available (build configuration mismatch or
API key issue), the `placeholderPaywall` in `PaywallView` shows a static list of
features but has no actual purchase buttons -- just "Restore Purchases" and
"Close". This means the app has no working purchase path without RevenueCat
configured.

**Fix**: Make the placeholder paywall a working SKStorefront-style sheet with
real product display (prices from StoreKit config or hardcoded), purchase
buttons, and restore. At minimum, link to the StoreKit configuration file.

### G2. `project.yml` needs maintenance

**Problem**: The XcodeGen spec works but doesn't define the widget extension
target explicitly (it might derive it). RevenueCat SPM dependency is listed for
Posture target but not for watch target. The test target includes Shared/ but
may not include all needed source files for new tests.

**Fix**: Audit `project.yml` after all changes to ensure all targets,
dependencies, and source file memberships are correct. Add explicit target
definitions for the iOS widget.

### G3. No analytics or telemetry

**Problem**: There's zero insight into how users interact with the app. You
can't answer basic questions like "what % of users finish a session?" or "how
many calibrate their watch?".

**Fix**: Add an opt-in telemetry layer (can be Firebase Analytics, TelemetryDeck,
or a custom endpoint) that fires events for:
- Session started / completed / cancelled (with duration, source, score)
- Calibration completed (with source: camera / airpods / watch)
- Pro purchase / restore
- Settings changes
- Always-on enabled/disabled
- Keep it privacy-first: no PII, just aggregated metrics.

### G4. App icon and branding

**Problem**: The app icon is a single 1024x1024 PNG -- no alternate icons, no
watch icon variant, no widget icon.

**Fix**: Provide full icon suite: iOS icon, watch icon, widget icon. Design a
cohesive app icon that reflects the posture theme (spine/alignment motif).

---

## H. Performance & Reliability

### H1. SwiftData query performance

**Problem**: `HistoryView` and `PassiveTimelineView` use `@Query` with no
predicate filtering -- they load all records into memory. For users with hundreds
of sessions or thousands of passive samples, this will be slow.

**Fix**: Add predicates and sorting limits:
- `HistoryView`: `#Predicate { $0.startedAt >= startOfMonth }` + display
  pagination via `FetchDescriptor(limit: 50)` or lazy loading.
- `PassiveTimelineView`: `#Predicate { Calendar.current.isDateInToday($0.timestamp) }`
  (already done via in-memory filter -- but the fetch still loads all samples).
- Fix: Add a `todayPredicate` to the @Query itself.

### H2. Camera start latency

**Problem**: `FaceTrackingService.start()` configures the `AVCaptureSession` on a
background queue via `unchecked` continuation. This can take 500ms-2s depending
on device. The `SessionView.prepare()` delays session start by 400ms for AirPod
probing, then starts the camera, then the engine -- total lag is significant.

**Fix**: Pre-warm the camera earlier -- start `FaceTrackingService` before the
user taps "Start session" (e.g., when `TodayView` appears). Keep the session
warm but not streaming. On tap, immediately wire it to the engine.

### H3. Battery impact of always-on monitoring

**Problem**: `BackgroundPostureWorkout` keeps an `HKWorkoutSession` alive all day
and polls `CMMotionManager` at 2Hz. This will drain watch battery significantly.

**Fix**: Dynamic refresh rate: drop to 0.5Hz when posture has been good for >5
minutes. Ramp back to 2Hz on any borderline event. Also consider adaptive
sampling based on time of day (less frequent at night if user is sitting still).

---

## I. Implementation Priority Matrix

| Priority | Area | Effort | Impact |
|---|---|---|---|
| **P0 - Bugs / Reliability** | | | |
| H1 | SwiftData query perf (passive samples) | Small | Medium |
| D2 | SessionEngine weak-self fragility | Small | Medium |
| **P1 - Core Experience** | | | |
| A1 | WatchSessionEngine deduplication | Medium | High |
| C3 | iOS haptic feedback | Small | High |
| F1+F2 | Onboarding + calibration UX | Small | High |
| B3 | Freeze refill mechanism | Small | Medium |
| C5 | Quick recalibrate | Small | Medium |
| **P2 - Monetization** | | | |
| C1 | iOS widget | Medium | High |
| D6 | Watch subscription sync | Medium | Medium |
| G1 | Paywall polish | Medium | Medium |
| **P3 - Feature Growth** | | | |
| C7 | Weekly trend chart | Medium | High |
| C4 | Session pause/resume | Small | Medium |
| F7 | Haptic feedback parity | Small | Medium |
| C2 | WCSession real-time comms | Large | High |
| B1 | Before/After Photos (Phase 5) | Large | Medium |
| **P4 - Quality** | | | |
| D1 | Sensor protocol abstraction | Medium | Medium |
| E1 | Test expansion | Large | Medium |
| F6 | Accessibility audit | Medium | Medium |
| G3 | Analytics | Medium | Medium |
| D7 | Singleton cleanup | Medium | Low |
| H3 | Battery optimization | Medium | Medium |

---

## Summary

**The biggest wins per unit of effort**:

1. **Haptic feedback on iOS** (+ `WatchSessionEngine` dedup) -- Makes camera
   sessions feel alive, eliminates a maintenance burden. ~half day.
2. **Freeze refill** + **Quick recalibrate** -- Fixes two obvious user pain
   points. ~half day.
3. **iOS widget** -- Highest-visibility missing feature, drives engagement. ~1 day.
4. **Weekly trend chart** -- Answers "am I improving?" the #1 question users
   ask about habit apps. ~1 day.
5. **Sensor protocol** + **Test expansion** -- Architectural hygiene that
   unblocks all future development. ~2 days.

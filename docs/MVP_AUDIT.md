# Posture MVP Release Audit

Scope: triage pass across onboarding → calibration → check-in → streak/history →
settings → paywall → background. **Diagnosis only — no fixes applied.**

---

## Scoping answer: the deleted `SessionEngine` / `SessionView` is intentional

The whole "start a timed posture session" model has been replaced by a
**reminder + acknowledgment** model:

- `TodayView` now shows reminder status + a "Check in now" button.
- The check-in opens `AcknowledgmentView`, which offers either a 3-second
  `QuickScanView` (camera) or a manual "I sat up straight" tap.
- Camera-during-a-session is gone. The only camera surfaces now are
  calibration and the 3-second quick scan.

What this means for the audit:
- **`PostureSession`** is now dead data. No code path writes to it. `TodayView`
  still `@Query`s it (line 7) and `HistoryView` still renders rows for it as
  "Legacy session" (line 224). The Watch widget and lockscreen widget both
  look up "today's score" via `PostureSession` — so **both widgets will
  always show "no session today"** until they're rewired to
  `AcknowledgmentRecord`.
- **`CLAUDE.md`** is stale (mentions `SessionEngine`, `SessionView`,
  `FaceTrackingService` driving sessions). Should be updated before/with
  the audit fixes so the next session doesn't re-introduce the old model.

I'm treating "still queries `PostureSession`" / "widget reads non-existent
data" as **bugs**, not refactor-in-progress.

---

## P0 — blocks release

### P0-1. Camera-denied path silently records "good posture"
**Where:** `Posture/Views/Components/QuickScanView.swift:60-113`
**What:** If the user denies camera access (or scan never gets a face),
`face.lastPitch` stays `nil`, `samples` stays empty, `finalDeviation`
falls back to `0`, and `PostureScoring.quality(deviation: 0, …)` returns
`.good`. The acknowledgment is recorded as a "camera scan, good" with
no data behind it. Streak still increments.
**Fix plan:** Detect no-face-detected / no-samples and either (a) bail
with an error state ("Couldn't see your face — try again") or (b) record
the ack with `quality: nil` and method `.manual`.

### P0-2. `AirpodsBackgroundMonitor` env injection can crash `SettingsView`
**Where:** `Posture/App.swift:38-42` (created in `.onAppear`) +
`Posture/Views/SettingsView.swift:8` (`@Environment(AirpodsBackgroundMonitor.self)` — non-optional).
**What:** `monitor` is `nil` for the first render pass; it's only assigned
inside `onAppear`. `@Environment(AirpodsBackgroundMonitor.self)` (without
`.self?`-style optional) precondition-fails when the object isn't in the
environment. A user landing on Settings before `onAppear` resolves
(deep-link, fast tab switch on cold launch) is a crash.
**Fix plan:** Instantiate `monitor` at view init (not `onAppear`), or
change `SettingsView` to read it as optional via a wrapper, or pass it
through `@State` on the root view non-optionally with a no-op default.

### P0-3. Background `audio` mode used to keep CoreMotion alive
**Where:** `Shared/Services/AirpodsBackgroundMonitor.swift:166-186` +
`Posture/Info.plist:35-38` (`UIBackgroundModes: audio`).
**What:** Playing a silent looped buffer at `volume = 0.01` purely to
keep `CMHeadphoneMotionManager` updates flowing in the background is a
well-known App Store rejection vector (App Review 2.5.4 / "background
audio used for non-audio purpose"). The Settings copy at
`SettingsView.swift:166` literally tells the user "Orange audio indicator
appears while monitoring — this is expected" — which reads to a reviewer
like a confession.
**Fix plan:** Either (a) cut AirPods background monitoring from MVP and
ship Pro with just Watch always-on (which has a legitimate
`HKWorkoutSession` justification), (b) replace the silent-audio trick
with a CallKit-style approach, or (c) gate the feature behind a
disclosure that's explicit about the audio indicator. Talk to the
reviewer story before submitting.

---

## P1 — embarrassing but shippable

### P1-1. Lockscreen + Watch widget always show "no session today"
**Where:** `PostureWidget/PostureLockScreenWidget.swift:38-43` and
`PostureWatchWidget/PostureWatchWidget.swift:36-41`.
**What:** Both read latest `PostureSession` to derive `todayScore`.
Nothing creates `PostureSession` anymore (the post-refactor app records
`AcknowledgmentRecord`). Widgets will permanently render the empty state.
**Fix plan:** Query `AcknowledgmentRecord` for today's most recent
`.camera` entry; map `quality → score` the same way `WatchTodayView`
already does. Use that as `todayScore`.

### P1-2. Reminders quietly die after ~2 days without an app open
**Where:** `Shared/Services/NotificationService.swift:55-103`.
**What:** Reminders are scheduled as `UNCalendarNotificationTrigger`
with `dateMatching: [.hour, .minute]`, `repeats: false`. They fire once
each at the next matching wall-clock time, then never again. Rescheduling
only happens on app launch / foreground. A user who installs, lets it
run, and doesn't open the app for 48h gets zero reminders on day 3+.
**Fix plan:** Either set `repeats: true` (with daily date components) or
register a `BGAppRefreshTask` that re-runs the scheduler nightly. The
prefix-based cancellation in `pendingReminderIdentifiers()` already
supports either model.

### P1-3. Notification-denied silently flips the reminder toggle off
**Where:** `Shared/Services/ReminderScheduler.swift:19-25`.
**What:** If the system returns `not authorized`, the scheduler sets
`settings.reminderEnabled = false` without telling the user. The toggle
in Settings just snaps back to off after the user taps it. No "open
system settings" deeplink, no explanation.
**Fix plan:** On denial, leave the toggle visually on, show an inline
warning row ("Notifications are off in Settings — tap to fix") with a
deep link to `UIApplication.openSettingsURLString`.

### P1-4. Reminder cap of 20 truncates short-interval users
**Where:** `Shared/Services/NotificationService.swift:80-82`.
**What:** 15-minute interval × 9am–8pm = 44 slots, hard-capped to 20 → no
reminders past ~2pm. The user sees an empty "Next: —" with no clue why.
**Fix plan:** Pair with P1-2: switch to repeating daily triggers so the
20-slot iOS limit covers permanent slots instead of a single day's
queue. Or raise the day's cap to iOS's 64.

### P1-5. Calibration can capture a baseline with no face on camera
**Where:** `Posture/Views/CalibrationView.swift:237-298`.
**What:** Button is guarded by `face.faceDetected`, but once countdown
starts, the 1-second sample loop reads `face.lastPitch` regardless of
whether the face is still in frame. If `lastPitch` is stale or `nil`,
samples either contain stale values or `faceAvg = 0` is saved as a
real baseline. From then on, scoring is permanently miscalibrated.
**Fix plan:** During the sampling loop, abort + restart the countdown if
`face.faceDetected` flips false, and require ≥ N valid samples before
`save()`.

### P1-6. Notification-tap callback writes SwiftUI state off-main
**Where:** `Posture/App.swift:96-114` (`NotificationDelegate`).
**What:** `didReceive` is called by `UNUserNotificationCenter` on its
own queue. The callback writes the captured `[self]` closure which
mutates `@State` (`ackScheduledAt`, `ackNotificationIndex`) directly.
SwiftUI state mutations from a non-main thread are UB.
**Fix plan:** Wrap the closure body in `Task { @MainActor in … }` or
mark `onReceive` as `@MainActor` and use `MainActor.run { … }` inside
`didReceive`.

### P1-7. AirPods background monitoring doesn't auto-start on cold launch
**Where:** `Posture/App.swift:65-77`.
**What:** Monitor (re)start only happens in `onChange(of: airpodsBackgroundEnabled)`,
`onChange(of: isProSubscriber)`, and `UIApplication.willEnterForegroundNotification`.
A cold launch fires none of those — so a Pro user with the toggle on has
no monitoring until they background + foreground the app once.
**Fix plan:** After `onAppear` initializes `monitor`, call
`updateMonitoring(enabled: settings.airpodsBackgroundEnabled && subscriptions.isProSubscriber)`.

### P1-8. "Always-on Watch monitoring" toggle on iOS does nothing
**Where:** `Posture/Views/SettingsView.swift:24`.
**What:** Toggling `settings.alwaysOnEnabled` on the iPhone only writes
to UserDefaults. The actual workout start/stop lives in
`PostureWatch/Views/WatchSettingsView.swift:16-28` — which only runs if
the user opens the watch app. So iOS users flip the switch, see no
effect, and assume the feature is broken.
**Fix plan:** Either (a) drop the iOS toggle and reword as "Open Posture
on Apple Watch to enable always-on", or (b) push the setting to the
watch via `WCSession` so the watch app reacts when it next launches.

### P1-9. `TodayView`'s "response rate" is always ~100%
**Where:** `Posture/Views/TodayView.swift:175-196` and same logic in
`HistoryView.swift:53-74`.
**What:** `total = max(ackCount, remainingReminders + ackCount)` and the
History version uses `reminderCount = max(todayAcks, 1)`. Both make the
denominator equal-or-less-than the numerator, so the rate trends to 100%
the moment the user acks once. The chart and progress bar are
decorative — they don't reflect actual response rate.
**Fix plan:** Track scheduled reminder count + fired count (or
"reminder delivered" tap-through) and compute against actual delivered,
not against remaining-still-pending. Persist daily reminder counts in
SwiftData or UserDefaults keyed by day.

### P1-10. Duplicate `StreakState` rows possible
**Where:** `Posture/Views/TodayView.swift:17-23` and `WatchTodayView.swift:10-16`.
**What:** Computed property `streak` does an insert + save **inside the
getter** if `streaks.first == nil`. The getter is read every body
re-eval; with a fast first render across iOS + Watch in the same App
Group, the race can create two `StreakState` rows. They'll diverge —
which one wins is whichever `streaks.first` returns. Same pattern in
`StreakService.currentState()`.
**Fix plan:** Centralize the "get-or-create" inside `StreakService` and
make it idempotent (fetch with limit 1, only insert if still empty after
fetch, use a singleton ID or a dedicated upsert). Don't insert inside
SwiftUI body evaluation.

### P1-11. HealthKit entitlement on iOS app, but iOS never uses HealthKit
**Where:** `Posture/Posture.entitlements:5-6` and
`Posture/Info.plist:31-34`.
**What:** iOS app declares `com.apple.developer.healthkit` and ships
`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`, but
only the watch app calls into HealthKit. Apple reviewers will flag the
mismatch — "your app declares HealthKit but doesn't request it."
**Fix plan:** Move HealthKit entitlement + usage strings to the watch
target's plist; remove from iOS unless iOS does start using HK before
ship.

### P1-12. `fullScreenCover` AcknowledgmentView has no escape route
**Where:** `Posture/Views/AcknowledgmentView.swift:117-125`.
**What:** Dismiss button only appears when `notificationIndex != nil && idx > 0`.
A manual "Check in now" tap (idx=nil) or a tap on notification index 0
locks the user in until they pick Quick Scan or Manual. `fullScreenCover`
has no swipe-to-dismiss. Common iOS escape-hatch instinct fails.
**Fix plan:** Show the dismiss button (or a small close X) unconditionally
on the choice screen.

### P1-13. `airpods.start()` runs in calibration even when user said "no"
**Where:** `Posture/Views/CalibrationView.swift:50-57`.
**What:** `airpods.start()` is unconditional in `.task`. Battery + a
"motion sensor active" indicator on AirPods for nothing.
**Fix plan:** Only start `airpods` when `hasAirpods == true`.

### P1-14. Permission-denied UX missing across the app
**What:** No view handles `AVCaptureDevice.authorizationStatus == .denied`
or notification denial with a "go to Settings" affordance. Calibration
and QuickScan just appear to "do nothing" for denied users.
**Fix plan:** Add a thin reusable "permission required" sheet/banner
with `UIApplication.openSettingsURLString` deep link; surface from
`CalibrationView.captureStep`, `QuickScanView.body.task`, and the
Settings reminder section.

---

## P2 — post-launch

- **`PostureSession` is dead code.** No path writes it; `HistoryView` still
  renders rows labeled "Legacy session" (`HistoryView.swift:224`). Remove
  the type + the query + the merged-timeline `.session` case once widgets
  are migrated.
- **`WatchTodayView` `@State showingSession`** is unused.
  `PostureWatch/Views/WatchTodayView.swift:8`.
- **`BackgroundPostureWorkout.totalSlouchEvents`** labeled "today" but
  resets on every app launch.
  `PostureWatch/Views/WatchSettingsView.swift:34`.
- **Calibration's `done` step has no "redo"** — only a single "Done" CTA.
  Minor.
- **`CalibrationView` button shows "Capture" but no hint why it's
  disabled** when no face detected. Add a small "Move into frame" caption.
- **`PaywallView.placeholderPaywall` is reachable before RevenueCat
  configures** (slow network). Show a brief "Loading plans…" state.
- **Notification permission prompt fires on first foreground** (via
  `ReminderScheduler.reschedule`) with no contextual explanation in the
  app. Consider a pre-prompt screen explaining "we'll nudge you N times
  a day."
- **`CalibrationView.onDisappear`** cancels the countdown task but leaves
  `capturing = true` / `countdown` non-zero if user backgrounds mid-flow.
  Cosmetic on re-entry.
- **CLAUDE.md is stale** — mentions `SessionEngine`, `SessionView` and
  session-based architecture. Update so next session doesn't re-add them.
- **`SettingsView` recalibrate confirmation dialog** — wording could be
  trimmed; "Quick" and "Full" are not obvious.
- **`VIDEO_REVIEW_NOTES.md`** still mentions a "Now slouch" calibration
  step that's already gone — purge or rewrite to current state.

---

## What I did NOT audit

- **Accessibility:** dynamic type, VoiceOver labels (`PostureRing` and
  `StreakFlame` have some; broader pass needed). Not flagged P0/P1
  because none of it crashes — but worth a pass before submit.
- **Localization:** strings are hardcoded English. Fine for MVP, listing
  needs to match.
- **In-app purchase flows on real RevenueCat:** placeholder paywall logic
  reviewed; the `RevenueCatUI.PaywallView` branch is opaque without a
  configured offering in the dashboard.
- **iPad layout** — `TARGETED_DEVICE_FAMILY: "1"` (iPhone-only). OK.
- **`pull-appstore-metadata.sh` round-trip safety** — out of scope.

---

## Recommended P0/P1 order if you want a single batch

1. P0-2 (env-injection crash) — cheap, one-line risk.
2. P0-1 (camera-denied false-good) — one branch in `QuickScanView`.
3. P1-1 (widgets read dead model) — small, high visibility.
4. P1-5 + P1-10 (calibration stale samples, duplicate streak rows) — data integrity.
5. P1-2/P1-4 (reminder lifetime + cap) — together; one refactor.
6. P1-6 (notification-tap threading) — concurrency correctness.
7. P1-8 (iOS toggle that does nothing) or remove from UI.
8. P1-3 / P1-9 (permission-denied + bogus response rate) — UX honesty.
9. P0-3 (background audio) — needs a product decision before code.
10. P1-7, P1-11, P1-12, P1-13, P1-14 — pickups.

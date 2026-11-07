# State machine audit, 2026-11-06

Scope: iOS app, `Shared/`, widgets, watch targets. No backend function is in the repo (entitlements come from RevenueCat only). Audited committed code at `0534d77`. Nothing was fixed.

**Summary: 10 bugs. 3 proved by test (B4, B6, B8), 7 code path only (B1, B2, B3, B5, B7, B9, B10).** Plus 8 product calls (not counted). A 4th failing test (B2, widget) proves only the writer side, so B2 is counted as code path.

Test run: `gh-sim test --scheme Posture --only PostureTests/StateMachineAuditRepro`, Xcode 27.1, iPhone 17, iOS 27.2: 4 passed (controls), 10 failed. Of the 10 failures, 4 are failures on the claim (B2 writer side, B4, B6, B8). The other 6 failed their own PRECONDITION: the simulator test host is not authorised for notifications, so `UNUserNotificationCenter` accepts no request (`testControlDefaultWindowSchedulesEverySlot` saw 0 pending, expected 44). `NotificationService` calls `UNUserNotificationCenter.current()` directly with no seam, and app code may not change in this audit, so every notification claim (B1, B5, B7) stays code path. Repro suite: `state-machines-2026-11-06-repro.swift` (header lists exactly which tests passed and failed).

## Existing test seams checked

| Seam | Usable here |
|---|---|
| `StreakService.applySession/refillFreezesIfNeeded/displayStreak/awardMilestoneFreezes` (static, pure) and `StreakService(context:)` on an in-memory `ModelContainer` | yes, used (B6, B8) |
| `PracticeSessionController.ingest(pitch:at:)` with a `Calibration` row, in-memory context | yes, used (B2, B4) |
| `AchievementCatalog.all/earnedIDs` (pure) | yes, used (B4) |
| `GoalSettings(defaults:)` suite injection | available, no claim needed it |
| `DataService.openContainer(at:recovery:makeContainer:)` | available (P4) |
| `ReviewPromptTracker` (app group defaults, `now:` params) | available, no bug found |
| `CustomerInfo` fixtures / RevenueCat | `applyProStatus(from:)` is private and takes a RevenueCat `CustomerInfo` (not constructible without the SDK); no entitlement bug found, so not needed |
| `NotificationService` / `ReminderScheduler` | no seam (static enum on `UNUserNotificationCenter.current()`); real center rejects adds in the test host |
| Widget `load()` and Watch targets | not importable from `PostureTests`; no seam |
| `NSTimeZone.default` | not needed; streak math uses `Calendar.current`, and the tz cases I traced (east/west travel, negative gap) are covered by the `case ...0` branch |

Every scheduler call site (needed for B1, B5, B7). `schedulePracticeReminder` / `cancelPracticeReminder` are called only from `ReminderScheduler.reschedule` (`ReminderScheduler.swift:43,59`). `scheduleReminders` / `cancelAllReminders` only from `reschedule` (`:46,65`) and `ReminderScheduler.cancelAll` (`:104`, no callers). `reschedule()` callers: `App.swift:133,136,139,142,145,148,151` (one per setting `onChange`), `App.swift:170` (willEnterForeground), `App.swift:357` (RootView `.task`), `App.swift:461` (MainTabView `.task`), `TodayView.swift:1141`, `SettingsView.swift:100,124,148,154,160,535`. Immediate (trigger nil) notifications: `SlouchNudge.swift:49`, `PracticeSessionController.swift:855`. `removeDeliveredNotifications`: `AcknowledgmentView.swift:45`, `SlouchNudge.swift:58`, `NotificationService.swift:128`. Nothing reschedules or cancels any reminder when a practice is completed (`PracticeSessionController.finish`, `:629-760`, has no notification-center call besides `postCompletionNotification`, `:846`).

## Bugs, ranked by impact (users reached times cost)

| Id | Bug | What the user sees | Promise | User route | Impact | Evidence | File:line |
|---|---|---|---|---|---|---|---|
| B1 | The daily practice reminder keeps firing on days the practice is already done | At the reminder time, "today's practice is waiting." after they finished today's session | Notification copy `today's practice is waiting.` (`NotificationService.swift:38`); body `AirPods in, spine long.` (`:44`); Settings: "One reminder a day for your posture practice" (`SettingsView.swift:111`). The reminder is a `repeats: true` calendar trigger (`:101`) that nothing cancels or moves after completion | Fresh install, onboarding, calibrate with AirPods (`hasAirpods == true`, so Settings shows "Daily practice", `SettingsView.swift:95`), allow notifications. Practice reminder defaults on, 10:00 (`GoalSettings.swift:157-165`). Today, "Begin today's practice", Begin, hold to the end, Done. At 10:00 the banner arrives. Needs a completed practice earlier than the reminder time | Every AirPods user with the default reminder who practises before 10:00 (or before their chosen time) gets a false "waiting" nudge daily. The core loop's own reminder, so high reach; cost is annoyance and lost trust, repeated daily, plus a likely cause of users turning notifications off | Code path. Two attempted tests (`testPracticeReminder...`) are blocked at their preconditions in the simulator host. Would settle it: a fake behind `UNUserNotificationCenter` asserting the practice request's next trigger after `finish(completed: true)`, or one run on a device | `NotificationService.swift:87-109`, `ReminderScheduler.swift:41-62`, `PracticeSessionController.swift:629-760` |
| B2 | Home/lock-screen and watch widgets never show a practice result and are not refreshed after one | After finishing practice the widget says "No check-in yet today" and the old streak, for up to the rest of the day | Widget description "Today's posture score, with your current streak." (`PostureLockScreenWidget.swift:202`); watch: "Your current streak and today's posture score." (`PostureWatchWidget.swift:135`). Today shows the practice score | AirPods user with the Posture widget on the lock screen or home screen. Today, "Begin today's practice", finish. Lock the phone and read the widget. Needs a widget installed and no later check-in | Every AirPods user who installed the widget (the app's core users; install rate unknown). Every day they practise, it shows no score and, until iOS next honours the 15-minute timeline, yesterday's streak. The code comment `PostureSession is no longer written` (`:43`) is stale: practice rows are written (`PracticeSessionController.swift:696`). `grep -rn WidgetCenter` finds nothing in the repo, so no reload happens on completion | Code path, reader side. Writer side tested: after a completed practice there are 0 scored `AcknowledgmentRecord` rows for today (expected at least 1, recorded `("0") is less than ("1")`), using the widget's own predicate; the control with a check-in returns 1. The widget query itself was not run (extension target). Would settle it: a widget snapshot test with a practice row, or the real widget on a device | `PostureLockScreenWidget.swift:43-52,24`; `PostureWatchWidget.swift:23,40-46` |
| B3 | The Apple Watch app and watch widget read a store the phone never writes to | Watch shows "0 days" and "Check in on your iPhone", the watch complication shows a 0 streak and "Time to sit up" | Widget copy above; `WatchTodayView` comment `watch reads from shared App Group SwiftData` (`:23`). `WatchSyncService.swift:6-9` states App Group data is per-device and does not cross to the watch; the store is `cloudKitDatabase: .none` (`DataService.swift:160`) and only `alwaysOnEnabled`/`isPro` are pushed (`WatchSyncService.swift:36-43`) | Paired Apple Watch with the Posture watch app. Build a 5-day streak on the phone, open Posture on the watch | Every watch owner who opens the watch app or adds the complication: the streak and score are always empty. Medium cost (a core number is always wrong), smaller population than B1/B2 | Code path. Would settle it: run the watch target against a store seeded on the phone, on device | `WatchTodayView.swift:12,23-37`, `PostureWatchWidget.swift:30-46`, `WatchSyncService.swift:36-43` |
| B4 | First practice announces "Safety net: Earned a streak save." | The first session's summary lists the new badges: First practice, First pass, **Safety net** | Badge subtitle "Earned a streak save." (`AchievementCatalog.swift:126`); doc "Display-only badges... derives at read time" (`:3-5`). A fresh `StreakState` simply holds the starting allotment of 2 (`StreakState.swift:18`); `isEarned` is `freezesAvailable > 0` (`:128`). It also un-earns when saves run out below a 7-day best | New user, finish the first practice, read the summary (`SessionSummaryView.swift:221`) and Today's badge row | Every new user, once. Low cost (a reward they did not earn, trust cost small); highest reach | **Proved by test**: `testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave` failed with `summary newly-earned lines: ["First practice", "First pass", "Safety net"]`, after asserting `longestStreak == 1`, `freezesAvailable == 2` and that "First practice" is listed. Controls pass: `testControlNoStreakRowEarnsNoSafetyNet` | `AchievementCatalog.swift:124-129`, `PracticeSessionController.swift:670-690` |
| B5 | Overlapping reminder reschedules interleave and leave stale check-in slots | Check-in reminders at times outside the window the user set, or at the old interval | Stepper labels "Start at 9:00" / "End at 20:00" and "Every 30 minutes" (`SettingsView.swift:142-160`); doc `scheduleReminders` rewrites the queue. `reschedule()` is `@MainActor`, but each pass suspends on `await requestAuthorization()` and on every `await center.add` (`NotificationService.swift:128-175`), and nothing serialises passes: pass B removes all ids (`:127`) while pass A is still adding its tail, then A's higher indexes land after B's | Settings, "Remind me throughout the day" on, Every 15 minutes, Start 6, End 23 (60 slots), then tap the End stepper down several times, or hold it. Each tap starts a pass while the previous one still has adds to do. Needs reminders on, notifications allowed | Users who change the window or interval while reminders are on: small, they adjust it a few times at most. Cost: reminders at hours they excluded. Not deterministic: it needs the taps to land inside the previous pass | Code path. `testOverlappingRemindersChangesLeaveOnlyTheLatestSettingsPending` is blocked at its precondition (0 pending). Would settle it: a fake center that suspends on `add`, or a device with a debug log of pending ids | `NotificationService.swift:121-176`, `ReminderScheduler.swift:50-72`, `SettingsView.swift:147-161` |
| B6 | The streak chip reads zero for a run that the next practice will keep | Today hides the streak chip (`TodayView.swift:287`) and Streak detail says "0 days"; after practising it shows 21 | Streak copy: "Miss a single day and a save spends itself automatically, your streak carries on as if you'd practiced. You hold up to two, they refill weekly" (`StreakDetailView.swift:154`). `displayStreak` checks the stored `freezesAvailable > 0` (`StreakService.swift:139`) but `record()` first refills (`:41`) | A 20-day streak with 0 saves left and the last weekly refill 7+ days old, one missed day (0 saves needs 3 saves spent, two within a week). Open Today on the second day: no streak chip. Practise: streak 21 | Rare (needs three misses in about ten days), but a long-streak user sees "0 days" for a streak that is safe. High cost to the few it reaches | **Proved by test**: `testStreakChipDoesNotReadZeroForARunThatTheNextPracticeWillSave` failed `("0") is not equal to ("20") - Today and Streak detail showed 0 before the practice, 21 after`. Preconditions asserted: gap 2, refill due, record path yields 21. Control passes: with 1 save the display is 20 | `StreakService.swift:41,133-145` |
| B7 | Slot cap silently drops the end of a wide check-in window | Reminders stop at 20:45 although End is set to 23:00 | Stepper "End at 23:00" with "Hour (0-23) when daily reminders stop firing" (`GoalSettings.swift:195`) and Today's "N more today". Cap `maxSlots = 60` (`NotificationService.swift:58,136`); the Settings steppers allow Start 6 to End 23 at 15 minutes, 68 slots | Settings, Check-in reminders on, Every 15 minutes, Start at 6 (stepper down), End at 23 (stepper up) | Users who choose 15 minutes with a window over 15 hours: very few. The code comment documents the cap for iOS's 64 limit but the UI offers more than it can honour and says nothing | Code path (blocked test `testWideWindowAtFifteenMinutes...`). Count from the code: 17h / 15min = 68 > 60, last scheduled slot 20:45. Would settle it: a fake center or a device | `NotificationService.swift:132-139`, `SettingsView.swift:151-160` |
| B8 | A spent streak save comes back the next day, not weekly | After using a save, "2 saves ready" returns on the next practice | Doc `Weekly freeze refill - resets to 2 available freezes every 7 days` (`StreakService.swift:73`); StreakDetail "they refill weekly" (`StreakDetailView.swift:154`). `lastFreezeRefill` is nil until the first refill, and a nil date refills at once (`:76-79`) | Practise day 1, skip day 2, practise day 3 (save spent, "1 saves ready"), practise day 4: "2 saves ready" | Every user who ever spends their first save (a large share of long streaks). Favours the user, so cost is low; it makes the weekly cap meaningless once | **Proved by test**: `testSpentSaveRefillsWeeklyNotTheNextDay` failed `("2") is not equal to ("1") - saves refill weekly; one day later it is 2`, after asserting a save was spent and `lastFreezeRefill == nil`. Control passes. An existing test (`testRefillWhenEmptyAndNoRefillDateSetsTo2`) pins the nil-date refill for 0 saves, so the intent for that case is arguable | `StreakService.swift:74-87` |
| B9 | Today says a next reminder exists when permission was denied | "Next reminder later today · 0 more today" | The line asserts a schedule (`TodayView.swift:1131`). With permission denied `reschedule` returns before scheduling (`ReminderScheduler.swift:51-56`), so `nextReminderDate()` is nil and the text falls back to "later today" (`TodayView.swift:1182`) | Onboarding, "Continue without AirPods" (manual Today, `TodayView.swift:331-333`), Today, "Reminders are off. Turn on →", iOS prompt, Don't Allow | No-AirPods users who decline the prompt: small. Low cost | Code path. Would settle it: UI test with denied permission | `TodayView.swift:1129-1143,1179-1186` |
| B10 | Settings keeps saying notifications are off after the user allows them | The red banner "Notifications are off... won't fire until you allow notifications" stays | Banner copy (`SettingsView.swift:133-134`). `allowNotifications` opens iOS Settings then re-reads status immediately (`:532-540`); the only other refresh is the tab's `.task` (`:272`). The foreground `reschedule` does schedule the reminders, so they do fire | Settings, reminders on with iOS permission denied, tap "allow", enable in iOS Settings, return to the app without leaving the Settings tab | Users who recover from denial: small. Low cost, wrong message | Code path. Would settle it: UI test toggling permission | `SettingsView.swift:127-137,527-540` |

Ranking note: B1 and B2 reach the core users every day. B3 reaches all watch users. B4 reaches everyone once but costs little. B5 to B10 are narrower.

## Product calls (no promise cited, or documented; not counted)

1. **Practice again farms levels.** Today's "Practice again" (`TodayView.swift:497`) lets a user pass the same-length session repeatedly, each pass adding a level pip. The code only blocks custom lengths (`PracticeSessionView.swift:142`). Not contradicted by copy.
2. **Reminder-tap session is always the default mode.** A `.both` user whose standing practice is done taps the reminder and gets Standing again (`App.swift:122`, `GoalSettings.swift:23` documents it).
3. **Re-subscribing silently resumes all-day monitoring.** `airpodsBackgroundEnabled` and `alwaysOnEnabled` stay set when Pro lapses (`SettingsView.swift:410-420` only hides them), so a later purchase from any paywall starts the silent-audio monitor without the "Turn on all-day monitoring?" confirmation (`App.swift:209`).
4. **Store recovery leaves setup flags set.** A non-transient open failure moves the store to a backup and opens an empty one (`DataService.swift:93-103`). `hasCompletedOnboarding`, `hasCalibrated` and `hasAirpods` live in `UserDefaults`, so the user lands in the tabs with no calibration; "Begin" then shows "Calibrate with AirPods before a session." (`PracticeSessionController.swift:299`), and streak, history and levels are gone. Nothing in the app can restore the backup. The failure screen says "Your files have been kept" (`StorageContainerView.swift:18`) but that screen is skipped on this path. Needs a corrupt store to reach.
5. **A notification tap while a session is live.** Check-in or practice taps set root-level `fullScreenCover` state (`App.swift:115-123`) while Today already presents the session cover (`TodayView.swift:185`). I could not confirm on iOS whether a root cover presents over a child cover. If it queues, a second session or a scan (which takes the head-motion stream, `AirpodsScanView`) appears when the first ends. Needs a device.
6. **Posture+ tab removed while selected.** After a purchase on the Posture+ tab (tag 3, `App.swift:531-536`), `selectedTab` is never reset (`App.swift:475`). SwiftUI's behaviour for a missing selection was not verified.
7. **Check-in credits the streak for AirPods users.** A 3-second scan counts as a streak day (`AcknowledgmentView.swift:336`), against AGENTS.md "Completing the session credits the streak". The check-in copy says it keeps the streak alive, so it is documented in UI.
8. **A pending purchase gives no message in two places.** `OnboardingTrialView.swift:198` and `SettingsView.swift:481` treat `.pending` as success, unlike `PaywallView.swift:511`, which explains it. Reached only if the entitlement lags a purchase.

## Related fixes, grouped in order

1. **Notification scheduler (B1, B5, B7, B9, B10).** Put `reschedule()` behind one serial actor that coalesces requests and rereads settings; only then add a completed-today check (schedule the practice reminder as a one-shot for the next day when today's practice is done, restore on the day change); raise the cap with fewer, wider slots or tell the user when the window is cut; make Today's line and the Settings banner read the real pending and authorisation state on foreground.
2. **Widgets and watch (B2, B3).** Make both widgets read today's practice and walk rows and call `WidgetCenter.reloadAllTimelines()` at the end of `finish()` and the end of a check-in; push streak and today's score to the watch in the existing `pushState` application context and read them there.
3. **Streak (B6, B8, B4).** Share one "effective saves" function between `displayStreak` and `record`; give `lastFreezeRefill` a value when the first save is spent; derive "Safety net" from a persisted save earned by a milestone, not the starting count.

## State machines

Notation: **Inv** = invariant. Bad transitions name the bug (B#) or product call (P#) they come from.

### 1. Entitlement (`SubscriptionService.isProSubscriber`)

States: Unconfigured/simulator (cached flag only) , Configured-Unknown (cache loaded, `refresh()` pending), Pro (active entitlement), Free (no active entitlement), Purchasing, Pending (purchase finished, no entitlement yet).
Storage: `isProSubscriber` in memory and the `isProSubscriber` default in the app group; pushed to the watch as `isPro`.
- **Inv 1:** Pro iff `info.entitlements.active` is non-empty (`applyProStatus`, `SubscriptionService.swift:363-371`; any entitlement counts).
- **Inv 2:** a network error never changes the flag (`refresh`, `SubscriptionService.swift:247`).
- **Inv 3:** every flip pushes to the watch and re-reconciles the monitor (`App.swift:161-165`).
- **Inv 4:** Pro-only settings stay stored while hidden when Pro lapses.

| From | Event | To | Breaks |
|---|---|---|---|
| Unconfigured | `configure()` | Configured-Unknown (cached flag) | none |
| Configured-Unknown | customerInfo ok | Pro or Free | none |
| Configured-Unknown | customerInfo fails | stays cached | stale Pro or Free until the delegate fires; none found |
| Free | purchase ok, active | Pro | none |
| Free | purchase ok, no active entitlement | Pending | P8 (no message in two sheets) |
| Pro | lapse (delegate) | Free | Inv 4 / P3 on re-subscribe |
| Pro | purchase from the Posture+ tab | Pro, tab 3 removed | P6 |

### 2. Setup (`hasCompletedOnboarding`, `hasCalibrated`, `hasAirpods` tri-state, `calibrationDeferred`, `Calibration` rows)

States: Fresh; Onboarded (`hasAirpods = true` set by "Set up my baseline", `OnboardingView.swift:38`); Calibrated (AirPods); Deferred (no AirPods: `hasAirpods = false`, `calibrationDeferred = true`, a neutral `Calibration` row); Legacy (`hasAirpods == nil`).
- **Inv 1:** `hasCalibrated` implies a `Calibration` row exists (violated after store recovery, P4).
- **Inv 2:** the notification prompt never shows before `hasCompletedOnboarding && hasCalibrated` (`ReminderScheduler.swift:25`, holds).
- **Inv 3:** `hasAirpods == true` implies the practice reminder is scheduled (only on the next foreground, no `onChange` for `hasAirpods`; small lag, no bug counted).

| From | Event | To | Breaks |
|---|---|---|---|
| Fresh | finish onboarding | Onboarded | none |
| Onboarded | quit before calibration | Onboarded (shows calibration) | none |
| Onboarded | skip without AirPods | Deferred | none |
| Deferred | Recalibrate with AirPods | Calibrated (`calibrationDeferred = false`, `hasAirpods = true`) | reminders wait for next foreground |
| any | store recovery | flags unchanged, rows gone | Inv 1, P4 |

### 3. Practice session (`PracticeSessionController.Phase`)

States: idle, reps, waiting, running, paused(user), paused(airpodsOut), finished. Persisted: one `PostureSession` row, `PostureMinuteSample` rows, `StreakState`.
- **Inv 1:** elapsed time accrues only from scored samples, dt clamped to 2 s (`MinuteBucket`).
- **Inv 2:** a row is written only for `finish`; under 30 s from the close buttons writes none (`:325-330`, `:375`).
- **Inv 3:** the streak is credited iff `completed`; `passed` implies `completed && countsForLevel && aligned >= target` (`PracticeSessionController.swift:648-649`).
- **Inv 4:** the head-motion stream has one owner (monitor suspended during a session).
- **Inv 5:** teardown releases the keep-alive token, ends the Live Activity and clears the slouch notification (`PracticeSessionController.swift:754-761`).

| From | Event | To | Notes / Breaks |
|---|---|---|---|
| idle | `start` with a baseline | reps (or waiting if reps 0) | without AirPods baseline stays idle with an error |
| reps | enough reps / Skip | waiting | none |
| waiting / paused(out) | first scored sample | running | none |
| running | AirPods out | paused(out) | none |
| running/waiting | Pause | paused(user) | button disabled in waiting |
| running | elapsed >= target | finished (completed) | streak credit; B1 because no reminder change |
| running | End session (30 s or more) | finished (not completed) | partial row, no streak |
| any live | close under 30 s / view disappears | idle | no row |
| finished | view disappears | finished (no-op) | none |
| running | backgrounded, reconcile stops monitor | running | `suspendedForForegroundRead` stays set; monitor restarts after the session (traced, holds) |

### 4. Streak (`StreakState`)

Fields: `currentStreak`, `longestStreak`, `freezesAvailable`, `lastActiveDay`, `lastFreezeRefill`.
- **Inv 1:** one record per calendar day advances the streak; same day or a backward clock never resets it (`StreakService.swift:110-114`).
- **Inv 2:** saves refill weekly, hold up to 2 plus milestone bonuses (B8 breaks it).
- **Inv 3:** the displayed streak equals what the next record will produce (B6 breaks it).
- **Inv 4:** a milestone bonus is awarded once per advance (`:44`, holds).

| From | Event | To | Breaks |
|---|---|---|---|
| none | first record | 1, saves 2 | B4 (counts as an earned save) |
| N | record, gap 1 | N+1 | none |
| N | record, gap 2, saves > 0 | N+1, saves - 1 | B8 (first spend refills next day) |
| N | record, gap 2, saves 0, refill due | refill then N+1 | B6 (display shows 0 before) |
| N | record, gap 3 or more | 1 | none |
| N | record, gap <= 0 | N | none |
| N | record crosses midnight (23:55 to 00:05) | credits the end day, row dated the start | none counted (the row start day and the credited day differ) |

### 5. Level progression (derived)

Level is a pure function of passed practice rows per posture ladder (`PracticeProgression`); free users capped at level 2.
- **Inv 1:** only `passed` practice rows count; pre-split rows (`postureModeRaw == ""`) count in both ladders (documented).
- **Inv 2:** the summary reports the capped level (`PracticeSessionController.swift:663-667`, holds).
- P1: repeat passes of the same length keep adding passes.

### 6. Reminders and notifications

States of the center: Not determined, Denied, Authorised; pending set `{posture.practice.daily, posture.reminder.0...59}`.
- **Inv 1:** `practiceReminderEnabled && hasAirpods` iff the practice request is pending (reconciled at launch, foreground, setting change).
- **Inv 2:** `reminderEnabled` iff check-in slots are pending, matching interval and window.
- **Inv 3:** a fired reminder describes the current task state (B1 breaks it).
- **Inv 4:** overlapping passes converge to the last settings (B5 breaks it).

| From | Event | To | Breaks |
|---|---|---|---|
| Authorised, enabled | foreground | rewrite all slots | none |
| Authorised | setting changed twice quickly | two interleaved passes | B5 |
| Authorised, practice reminder pending | practice completed | unchanged, repeats daily | B1 |
| Denied, enabled | any pass | nothing pending, toggle stays on | B9, B10 |
| Denied | granted in iOS Settings | scheduled at next foreground | B10 (banner stale) |
| enabled | window over 15h at 15 min | first 60 slots only | B7 |

### 7. AirPods monitor (`AirpodsBackgroundMonitor`)

States: stopped, armed(foreground), armed(background, Pro), suspended-for-read, `userPaused`.
- **Inv 1:** Pro and the all-day toggle select background mode, else the in-app live mode only while the scene is not backgrounded (`App.swift:204-227`).
- **Inv 2:** `userPaused` beats both auto-start paths.
- **Inv 3:** foreground-only mode never persists minute rows (`persistsMinutes`).
- **Inv 4:** one reader owns the motion stream (suspend/resume pair, idempotent). Traced: holds when the monitor is running at session start; if it is stopped at session start and is started by an intent mid-session, two managers run (rare, no route counted).

### 8. Paywall and trial one-shots

Flags: `hasSeenIntroPaywall`, `hasSeenOnboardingTrial`, `pendingFeatureEnable`, `pendingPaywallAfterTrialDismiss`, sheet states.
- **Inv 1:** the post-first-practice trial pitch shows only to non-Pro with `hasSeenOnboardingTrial == false`, and the flag is set only by the pitch's own exits (`OnboardingTrialView.swift:126-130`). It is a full-screen cover with no swipe dismiss, so it repeats until the user taps "Keep the free practice" or buys.
- **Inv 2:** `pendingFeatureEnable` is cleared when the sheets close without Pro (`SettingsView.swift:297,327`), so a late approval does not enable a toggle (P8).
- No bug found: intro eligibility defaults to not eligible until loaded, so no trial claim is shown without confirmation (`SubscriptionService.swift:283-286`).

### 9. Review prompt

`ReviewPromptTracker`: pending moment, launch count >= 2, 30-day cooldown, `.openedWriteReview` ends asks. Traced with its tests' seams; transitions hold (a blocked ask keeps the moment pending; feedback never overrides an opened review).

### 10. Watch sync and always-on

Phone pushes `{alwaysOnEnabled, isPro, sentAt}` by application context (last value wins); the watch applies Pro by `setLocalOverride`, then starts or stops the workout.
- **Inv 1:** the workout runs iff `alwaysOnEnabled && isPro` on the watch (`WatchTodayView.swift:66-78`, holds).
- **Inv 2:** the watch shows phone data (B3 breaks it for streak and score).

### 11. Storage container

States: open, open-after-retry, recovered (backup plus fresh store), failed (blocking screen with "Try again").
- **Inv 1:** transient errors never move files (tested in `DataServiceTests`).
- **Inv 2:** one recovery per launch.
- Breaks: P4 (flags and rows disagree after recovery).

### 12. Notification taps and covers

`NotificationDelegate` buffers a cold-launch tap until `onReceive`/`onPracticeTap` is set. Check-in taps pin the slot to today. Cover collisions: P5.

VERDICT: PASS

# Verification of the state machine fixes, 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md`, reading the whole change `git diff f49779c..a729b34` (base `f49779c3`, head `a729b34f`). This replaces the earlier verify doc. No app code or tests were changed. Every fixed claim was traced along the review's user route; six fixes (the top three plus B4, B6 and B7) were reverted on a throwaway branch and their tests run against the reverted code.

**Summary: 9 fixes checked, 9 work, 0 regressions, 0 newly failing tests, 0 scope failures. Holds on B5, B8 and P6 ruled correct.** The fixes doc has no "Disputed" section; its held items are ruled on below.

The fixes doc names base `435e866`; this branch's base `f49779c` adds only the Settings Language row and a build bump (`git diff 435e866 f49779c`), and the fix commits sit on it as `45cfbde9`..`92c6a8b1` (the doc cites the hashes from the original branch).

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| B3 watch app and complication show 0 | yes | none found | Route: build a streak on the phone, open the watch app or read the complication. Phone: `pushState` adds the encoded `TodaySnapshot` (`Shared/Services/WatchSyncService.swift:64-79`, key at `:77`), sent after every completed practice or walk (`Shared/Services/PracticeSessionController.swift:751-753`, after the row and the streak are saved at `:696-702`), every check-in (`Posture/Views/AcknowledgmentView.swift:338`), and at activation when the snapshot changed (`WatchSyncService.swift:172-181`). Watch: `deliver` stores it and reloads timelines (`:189-194`); `WatchTodayView` reads it for streak and score (`PostureWatch/Views/WatchTodayView.swift:12,16-18,57,87`), the complication too (`PostureWatchWidget/PostureWatchWidget.swift:29-31`); background delivery via `.backgroundTask(.watchConnectivity)` (`PostureWatch/App.swift:14`). Watch app and widget share the App Group (`PostureWatch/PostureWatch.entitlements:7-9`, `PostureWatchWidget/PostureWatchWidget.entitlements:5-7`). Aging uses the phone's own rule (`Shared/Services/TodaySnapshot.swift:18-32`). Every phone streak writer (grep `recordAcknowledgment\|recordSessionCompleted`) is followed by a push except the one-shot pivot grace (`Posture/App.swift:371`), which the activation check covers. Neighbours: the `isPaired`/`isWatchAppInstalled` guard (`:54,174`) only skips pushes `updateApplicationContext` would reject; `isPro` is sent with the same phone value as before, so no new membership judgement. The watch applies the phone's always-on value only when the phone changed it (`:200-206`); upgrade has no stored key, so the first delivery applies as before. Revert test failed on the claim |
| B2 iPhone widget shows no practice score and lags | yes | none found | Route: finish today's practice, read the "Posture today" widget. `PostureWidget/PostureLockScreenWidget.swift:44` now calls `TodaySnapshot.todayScore`, which takes completed practices and walks (aligned %) and scored check-ins (`TodaySnapshot.swift:49-62`); `PostureSession` is already in the widget schema (`PostureLockScreenWidget.swift:31`). `todayDidChange` reloads timelines (`WatchSyncService.swift:89-92`) after the save. Revert test failed on the claim |
| B1 practice reminder fires after today's practice | yes | none found | Route: AirPods user, reminder 10:00, practise at 8:00. Seven weekday triggers, today's a one-shot a week out when today's practice is done (`Shared/Services/NotificationService.swift:105-129`), fed by `practiceDoneToday` (`Shared/Services/ReminderScheduler.swift:62,75-78`); a completed practice reschedules (`PracticeSessionController.swift:754-757`). That reschedule cannot raise the permission prompt early: practice is only reachable from `MainTabView`, behind onboarding and calibration (`Posture/App.swift:331-343`), whose first appearance already ran `reschedule` (`App.swift:357,461`). Legacy `posture.practice.daily` still removed (`NotificationService.swift:157-159`). Tap routing reads `userInfo["type"]`, unchanged; `nextReminderDate`/`remainingCount` filter on `posture.reminder.` (`ReminderScheduler.swift:87,102`), which the new ids do not match. Pending total 57 + 7 = 64; the only other requests are immediate (`SlouchNudge.swift:49`, `PracticeSessionController.swift:862`). Revert test failed on the claim |
| B4 "Safety net" on day one | yes | none found | `isEarned: bestStreak >= 7` (`Shared/Services/AchievementCatalog.swift:127-131`); the milestone bonus is unconditional (`StreakService.swift:103-106`), so the subtitle "Earned a streak save." is true when it lands. Badges are derived at read time and never stored (`AchievementCatalog.swift:3-5`), so upgrades change no data; `bestStreak` (`:45`) cannot move because `longestStreak >= currentStreak`. Revert test failed with `["First practice", "First pass", "Safety net"]` |
| B6 streak reads 0 for a run the next practice keeps | yes | none found | `displayStreak` and `record` share `freezesAfterRefill` (`Shared/Services/StreakService.swift:74-100,173-176`); `refillFreezesIfNeeded` keeps base behaviour for every input. Today (`Posture/Views/TodayView.swift:89,92`) and Streak detail (`Posture/Views/StreakDetailView.swift:15-16`) read display streak and saves at the same clock, so they agree. Other readers: widget (`PostureLockScreenWidget.swift:39`), achievements (`AchievementCatalog.swift:45`, unchanged by `max`), pivot grace (`App.swift:370`, see notes). No stored format change. Revert test failed with `0 != 6` on the review's route |
| B9 Today promises a next reminder with permission denied | yes | none found | Route: no-AirPods user, tap "Turn on →", Don't Allow. `reschedule` posts on the denied return (`ReminderScheduler.swift:37`), Today re-reads status (`TodayView.swift:251-253,1186`) and `metaRow` shows "Reminders are off. Turn on →" unless reminders can fire (`:1132`); with permission denied the button opens iOS Settings (`:1142-1145`), and the foreground pass (`App.swift:169-170`) refreshes on return. Existing copy only |
| B10 Settings keeps "Notifications are off." | yes | none found | `didBecomeActiveNotification` re-reads the status (`Posture/Views/SettingsView.swift:309-311`, `refreshNotificationStatus` at `:563-566`). No test (CONFIRMED-MINOR, the simulator host cannot change permission) |
| B7 wide 15-minute windows cut at 20:45 | yes | none found | `checkInSlots` widens the step to fit the cap (`NotificationService.swift:228-236`): 6 to 23 at 15 minutes gives 57 slots every 18 minutes, last 22:48; slot count is always at most 57. A tapped slot records its own `scheduledAt` (`:199-207`). Ids 0 to 59 still cleared (`:63`, `:245-252`). Revert test failed with last reminder 20:00 |
| P4 store recovery leaves setup flags set | yes | none found | `recoverContainer` calls `onRecovered` only after the backup and a successful fresh open (`Shared/Services/DataService.swift:111-118`); `launchRecovery` sets `hasCalibrated = false` (`:27-29`), so `RootView` shows `CalibrationView` (`App.swift:334-336`), whose onboarding mode sets it back (`CalibrationView.swift:517,637`). Not an inferred state: the store in use was just created empty. `hasSeenOnboardingTrial`/`hasSeenIntroPaywall` are untouched, so no trial or paywall re-shows; the trial is still presented only from a practice summary (`PracticeSessionView.swift:514`). On the watch the hook flips a flag nothing there reads |

### Revert proof

Branch `scratch-revert` off head, keeping every test and the symbols they call (a literal `git revert` deletes those symbols, so the test target would not compile and would prove nothing). Behaviour put back to base: `applicationContext` sends no snapshot (B3); `todayScore` counts check-ins only, as the base widget did (B2); `practiceTriggers` returns the base single daily repeating trigger (B1); the base "Safety net" rule (B4); `displayStreak` checks stored saves only (B6); the base slot loop that stops at the cap (B7). One run, GitHub 42366009903, id `posture@20261107-020609-44a6-claude-imac8d7c-1107-025555-20686`: 0 passed, 6 failed, each on its claim:

- `TodaySnapshotTests/testWatchGetsThePhoneStreakAndTodayScore`: `XCTUnwrap failed: expected non-nil value of type "TodaySnapshot"`
- `TodaySnapshotTests/testCompletedPracticeGivesTheWidgetATodayScore`: `("nil") is not equal to ("Optional(100)")`
- `ReminderSchedulingTests/testPracticeReminderDoesNotFireTodayAfterTodaysPractice`: `practice done at 8:00, yet the 10:00 reminder still fires today`
- `StreakSaveTests/testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave`: `summary newly-earned lines: ["First practice", "First pass", "Safety net"]`
- `StreakSaveTests/testStreakDoesNotReadZeroForARunThatTheNextPracticeWillSave`: `("0") is not equal to ("6") - Today showed 0 on day 11, then 7 after practising`
- `ReminderSchedulingTests/testWideFifteenMinuteWindowRemindsUntilTheEndHour`: `("1200") is less than ("1350") - last reminder at 20:0, End is 23:00`

The branch was deleted; this branch ends with only this doc commit on top of `a729b34`.

### What the tests leave open (device checks)

The B1, B2, B3, B7 and B9 tests assert pure helpers, not the views, widgets, notification center or WatchConnectivity, which have no seam here. B4 and B6 run the real record path. The wiring was read instead; on a device:

- B3: a paired watch shows the phone's streak and today's score in the app and complication after a phone practice, including with the watch app closed.
- B2: the lock screen widget shows the practice score right after a practice.
- B1: after an 8:00 practice no practice banner arrives at 10:00, and it does the next day without opening the app.
- B9: deny permission from "Turn on →"; the line reads "Reminders are off." and the next tap opens iOS Settings. `testTodayDoesNotPromiseRemindersWhenNotificationsAreDenied` only checks `remindersCanFire`.
- B10: allow in iOS Settings, return to the Settings tab, banner gone.
- P4: `testRecoveryTellsSetupTheFreshStoreHasNoCalibration` only proves the hook fires on recovery and not on a healthy store, not that `hasCalibrated` is cleared or that calibration shows (`launchRecovery` is private). A corrupt store on a device should land on calibration.

## Holds and disputed items

No "Disputed" section in the fixes doc. Rulings on its held items:

- **B5 (and the cancel-while-adding case): hold correct.** UNVERIFIED in the review; the simulator host accepts no notification requests, so no test can fail on base, and fixing it would be a fix for an UNVERIFIED claim without one. The reverted queue is gone: no `SerialTaskQueue` anywhere in the diff.
- **P6: hold correct.** Unsettled in the review and reaching it needs a purchase. The reset was reverted (`b3bee801`); `Posture/App.swift` is not in the diff.
- **B8: hold correct.** The review calls it a product call ("Decide the rule rather than treat it as a defect"); the fix would take a save from users. Held for Jack, not skipped, and the existing test still pins the shipped rule.
- **P4 messaging: correctly left to Jack.** New copy and product scope.
- P5 is listed as out of scope with what would settle it (one device run); the review files it under product calls, not claims, so this is not a missing claim.

## Scope

- Only the listed bugs are touched. `SubscriptionService`, `PaywallView`, `OnboardingTrialView`, `OnboardingView` and `project.yml` are not in the diff; no change to trials, onboarding order, paywalls, prices, offers or membership judgement. The watch receives the same `isPro` value as before, only more often.
- No backend, App Store Connect or RevenueCat change.
- No stored format change: SwiftData schema unchanged; `todaySnapshot` and `lastPhoneAlwaysOnEnabled` are new watch-side defaults keys.
- P4 clears `hasCalibrated` only on a confirmed fresh store, never on a cached entitlement, missing request or failed call.
- No fix for an UNVERIFIED claim; held items unchanged. Every in-scope review claim (B1 to B10, P4, P6) is in the fixes table.
- The watch always-on change (`WatchSyncService.swift:200-206`) is beyond the letter of B3 but needed by it: without it the new per-practice pushes would undo a toggle set on the watch.

## Test results

| Run | Command | Result |
|---|---|---|
| Full suite and screens on head | `gh-sim all --scheme Posture --args "-SCREENSHOT_SEED -PostureProOverride -DuoTour -DuoTourFirst 3 -DuoTourStep 3 -DuoRoutes today" --screen "-DuoRoutes settings"` | Build ok (watch app and watch widget compiled), 195 passed, 0 failed, 0 skipped (Xcode 27.1, iPhone 17, iOS 27.2). GitHub run 42362686062, id `posture@20261107-020609-44a6-claude-imac8d7c-1107-020835-24307`. Matches the fixes doc's final run (195 passed). All 20 added or edited tests passed by name |
| Revert proof | `gh-sim test --scheme Posture --only` the six tests above, on `scratch-revert` | 0 passed, 6 failed on the claims. GitHub run 42366009903 |
| Localization | `python3 Tools/Localization/check.py` | 777 keys, 6 languages, 0 problems. No copy added |

## Screens

- Today (seeded AirPods user, `shots/launch.png`): the streak chip reads "6-day streak" with "2 saves ready" under it, now from `displayFreezes`; layout unchanged.
- Settings (`shots/screen1-DuoRoutes-settings.png`) renders normally; the B10 change is an observer with no visual change.
- Not reached: Today's no-AirPods meta row (B9; the seed is an AirPods user and `-DuoTour` skips the permission flow), Streak detail (a sheet with no tour route), the watch app and both widgets (gh-sim launches the iPhone app only). B9 and B6's Streak detail change reuse existing views and copy. iPhone Duo layouts: no layout code changed.

## Must change

Nothing.

## Notes

- B6 neighbour: the one-shot pivot grace (`App.swift:370`) checks `displayStreak > 0`. A pre-pivot user upgrading now with 0 saves, a due refill and one missed day gets the grace credit where base gave none; the next record would have kept the run anyway, so the outcome matches.
- B1: a practice started before midnight and finished after credits the new day but keys "done today" on `startedAt` (`PracticeSessionController.swift:695`, `TodaySnapshot.swift:65-71`), so that day's reminder still fires. Rare.
- B1: a skipped weekday's one-shot becomes repeating only at the next reschedule; a user who never opens the app again loses that weekday after it fires once. Every other day keeps firing.
- B1: a completed practice now runs a full reminder pass (check-in slots too), the same timing class as the held B5.
- B7: a wide 15-minute window now fires every 18 minutes while Settings still says "Every 15 minutes". Windows of 14.25 to 15 hours at 15 minutes that fit the old cap of 60 are now stretched too (cap 57). Worth a decision on whether Settings should say so.
- B2: the widget score mixes aligned % with the fixed check-in scores (85/55/25) and shows the best.
- B9: with reminders off and permission denied, "Turn on →" opens iOS Settings without turning reminders on, so after allowing the user taps once more.
- P4: the hook runs inside the lazy `containerResult` initializer and mutates an `@Observable` setting; if that first access happens during a view update SwiftUI may log a state-mutation warning. Behaviour is unaffected.

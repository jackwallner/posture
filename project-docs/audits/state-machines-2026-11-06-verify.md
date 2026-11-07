VERDICT: PASS

# Verification of the state machine fixes, 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md`, reading the whole change `git diff 435e866..f2ef580` (base `435e866a`, head `f2ef580b`). No app code or tests were changed. Every claim was traced in the code; the top three fixes were reverted on a throwaway branch and their tests run against the reverted code.

**Summary: 9 fixes checked, 9 work, 0 regressions, 0 newly failing tests, 0 scope failures. 3 holds (B5, B8, P6) ruled correct.** A few notes below, none of which fail the check.

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| B3 watch app and complication show 0 | yes | none found | Phone: `pushState` adds the encoded `TodaySnapshot` to the application context (`Shared/Services/WatchSyncService.swift:48-78`), called after every completed practice or walk (`Shared/Services/PracticeSessionController.swift:751-753`) and every check-in (`Posture/Views/AcknowledgmentView.swift:338`, after the record is saved at `:332`), and at activation when stale (`WatchSyncService.swift:172-180`). Watch: `deliver` stores it and reloads timelines (`:191-195`); `WatchTodayView` reads it for the streak and score (`PostureWatch/Views/WatchTodayView.swift:12-18,54-57,86-87`), the complication too (`PostureWatchWidget/PostureWatchWidget.swift:27-31`); `.backgroundTask(.watchConnectivity)` (`PostureWatch/App.swift:12-16`). Both watch targets compiled in run 42343441611 (`Debug-watchsimulator` in build.log). Aging uses the phone's own rules (`TodaySnapshot.swift:17-32` via `StreakService.displayStreak(currentStreak:...)`). Every streak writer (`StreakService.record` callers: `PracticeSessionController.swift:701`, `AcknowledgmentView.swift:336`, pivot grace `Posture/App.swift:371`) is followed by a push except the one-shot pivot grace, which the activation-time stale check covers. Neighbour: the watch now applies the phone's always-on value only when the phone changed it (`WatchSyncService.swift:200-207`); the first delivery after upgrade has no stored key, so it applies as before. Revert test failed on the claim (below) |
| B2 iPhone widget shows no practice score and lags | yes | none found | `PostureLockScreenWidget.swift:44` now calls `TodaySnapshot.todayScore`, which counts completed practices and walks plus scored check-ins (`Shared/Services/TodaySnapshot.swift:47-62`). The widget's schema already includes `PostureSession` (`PostureLockScreenWidget.swift:31`). `todayDidChange` calls `WidgetCenter.shared.reloadAllTimelines()` (`WatchSyncService.swift:89-92`) after the session row and streak are saved (`PracticeSessionController.swift:696-703`). Revert test failed on the claim |
| B1 practice reminder fires after today's practice | yes | none found | Seven weekday triggers; today's becomes a one-shot a week out when today's practice is done (`Shared/Services/NotificationService.swift:95-129`), checked by `ReminderScheduler.practiceDoneToday` (`ReminderScheduler.swift:62,74-78`), and a completed practice reschedules (`PracticeSessionController.swift:755-758`). Legacy `posture.practice.daily` is removed on upgrade (`NotificationService.swift:155-159`). Tap routing uses `userInfo["type"]`, not the id (`Posture/App.swift:278`), so the new ids still open the practice. `nextReminderDate`/`remainingCount` filter on `posture.reminder.` (`ReminderScheduler.swift:87,102`), unaffected. Pending total 57 + 7 = 64; the only other requests are immediate (`SlouchNudge.swift:49`, `PracticeSessionController.swift:862`). The prompt cannot newly appear after a practice: `reschedule` already ran at the first Today (`App.swift:356-357,461`) behind the onboarding and calibration guard (`ReminderScheduler.swift:36`). Revert test failed on the claim |
| B4 "Safety net" on day one | yes | none found | `isEarned: bestStreak >= 7` (`Shared/Services/AchievementCatalog.swift:127-131`). The badge is derived at read time and never stored, so an existing user whose badge came from the starting allotment just sees it as not yet earned; no data changes. On base the audit repro failed with `["First practice", "First pass", "Safety net"]`; the same test now lives in `StreakSaveTests` and passes |
| B6 streak reads 0 for a run the next practice keeps | yes | none found | `displayStreak` and `record` now share `freezesAfterRefill` (`Shared/Services/StreakService.swift:74-100,148-180`). `refillFreezesIfNeeded` is behaviour-equivalent to base for every input (same three branches). Readers of saves: Today (`Posture/Views/TodayView.swift:92`) and Streak detail (`Posture/Views/StreakDetailView.swift:16`) use `displayFreezes`, the watch gets the raw fields plus refill date. No stored format change. The review's own check showed display 0 on base on this exact route |
| B9 Today promises a next reminder with permission denied | yes | none found | `metaRow` shows the line only when `remindersCanFire` (`TodayView.swift:1131-1134`), the status is re-read on every `postureRemindersRescheduled` (`:251-253,1186`), which `reschedule` posts on every pass including the denied return (`ReminderScheduler.swift:37`). Route: Turn on, Don't Allow, pass posts, line reads "Reminders are off. Turn on →"; next tap opens iOS Settings (`TodayView.swift:1142-1145`); on return the foreground pass (`App.swift:169-170`) refreshes it. Existing copy only |
| B10 Settings keeps "Notifications are off." | yes | none found | `didBecomeActiveNotification` re-reads the status (`Posture/Views/SettingsView.swift:276-279`). No test (allowed for a CONFIRMED-MINOR claim; the simulator host cannot change permission) |
| B7 wide 15-minute windows cut at 20:45 | yes | none found | `checkInSlots` stretches the step to fit the cap (`NotificationService.swift:225-236`): 6 to 23 at 15 minutes gives 57 slots every 18 minutes, last 22:48. The tapped slot's time comes from its own `userInfo["scheduledAt"]` (`:197-205`, `App.swift:287-296`), so odd minutes are recorded correctly. All ids 0 to 59 still cleared (`:246-252`) |
| P4 store recovery leaves setup flags set | yes | none found | `recoverContainer` runs `onRecovered` only after the backup and a successful fresh open (`Shared/Services/DataService.swift:104-119`); `launchRecovery` sets `hasCalibrated = false` (`:27-29`), so `RootView` routes to `CalibrationView` (`App.swift:334`). A no-AirPods user can still leave through `skipWithoutAirpods`, which writes a neutral row (`Posture/Views/CalibrationView.swift:622-638`). `hasSeenOnboardingTrial`/`hasSeenIntroPaywall` are untouched, so no paywall or trial re-shows. On the watch the same hook only flips an unused flag |

### Revert proof (top three)

Branch `scratch-revert` off head: the B3, B2 and B1 behaviour reverted to base while keeping the symbols the tests call (a literal `git revert` deletes those symbols, so the test target would not compile and would prove nothing about behaviour). Watch app, watch widget and iPhone widget files restored to `435e866`; the phone sends no snapshot and the watch stores none; `todayScore` counts check-ins only, as the base widget did, and no widget reload; `practiceTriggers` returns the base single daily repeating trigger and no reschedule after a practice. Run 42348085414 (`posture@20261106-212703-b487-claude-mbpro74a6-1106-224056-10741`): 0 passed, 3 failed, each on its claim:

- `TodaySnapshotTests/testWatchGetsThePhoneStreakAndTodayScore`: `XCTUnwrap failed: expected non-nil value of type "TodaySnapshot"`
- `TodaySnapshotTests/testCompletedPracticeGivesTheWidgetATodayScore`: `("nil") is not equal to ("Optional(100)")`
- `ReminderSchedulingTests/testPracticeReminderDoesNotFireTodayAfterTodaysPractice`: `practice done at 8:00, yet the 10:00 reminder still fires today`

The branch was deleted; this branch ends with only this doc commit on top of `f2ef580`.

## Holds and disputed items

The fixes doc has no "Disputed" section. Rulings on its held items:

- **B5 (and the cancel-while-adding case): hold is correct.** UNVERIFIED in the review, and no test can fail on `435e866` (the simulator host accepts no requests). Fixing it would be a fix for an UNVERIFIED claim with no failing test. The reverted queue (`f1526ae`, reverted in `f7a643b`) is fully gone: no `SerialTaskQueue` in the diff.
- **P6: hold is correct.** The review leaves it unsettled and reaching it needs a purchase. The reset (`e9f867c`, reverted in `255966f`) is fully gone: `Posture/App.swift` is not in the diff.
- **B8: hold is acceptable.** The review calls it a product call ("Decide the rule rather than treat it as a defect"), it favours the user, and the fix would take a save away from every user who spends their first one, which is the "fix makes the experience worse" ground. An existing test still pins the shipped rule.
- **P4 messaging: correctly left to Jack.** Telling the user about the backup is new copy and product scope.

## Scope

- Only the listed bugs are touched. No change to trials, onboarding screens, paywalls, prices, offers or membership judgement: `SubscriptionService`, `PaywallView`, `OnboardingTrialView` and `OnboardingView` are not in the diff. The watch still receives the phone's existing `isPro` value (`WatchSyncService.swift:55-58`), only more often.
- No backend, App Store Connect or RevenueCat change.
- No stored format change: SwiftData schema unchanged; `TodaySnapshot` and `lastPhoneAlwaysOnEnabled` are new watch-side defaults keys.
- P4 clears `hasCalibrated` on a confirmed state, not an inferred one: the store in use was just created empty, so no `Calibration` row exists. The user's data had already been moved to the backup by the pre-existing recovery; the fix destroys nothing.
- No fix for an UNVERIFIED claim; held items unchanged.
- Every in-scope review claim (B1 to B10, P4, P6) is in the fixes table.

## Test results

| Run | Command | Result |
|---|---|---|
| Full suite on head | `gh-sim test --scheme Posture` | 195 passed, 0 failed, 0 skipped (Xcode 27.1, iPhone 17, iOS 27.2). GitHub run 42343441611, id `posture@20261106-212703-b487-claude-mbpro74a6-1106-213616-18337`. Matches the fixes doc's final run (195 passed, run 42339256923) |
| Revert proof | `gh-sim test --scheme Posture --only` the three tests above, on `scratch-revert` | 0 passed, 3 failed on the claims. GitHub run 42348085414. Two earlier tries never dispatched (GitHub API rate limit, infrastructure) |
| Screens on head | `gh-sim launch --args "-SCREENSHOT_SEED -PostureProOverride -DuoTour ... -DuoRoutes today" --screen "-DuoRoutes settings"` | Today and Settings captured. GitHub run 42350680188, id `posture@20261106-212703-b487-claude-mbpro74a6-1106-231744-20562` |
| Localization | `python3 Tools/Localization/check.py` | 775 keys, 6 languages, 0 problems. No copy added |

## Screens

- Today (seeded AirPods user): the streak chip reads "6-day streak" with "2 saves ready" under it, now from `displayFreezes`; layout unchanged.
- Settings renders normally; the B10 change is an observer with no visual change.
- Not reached: Today's no-AirPods meta row (B9; the seed is an AirPods user and the tour skips the permission prompt), Streak detail (a sheet with no tour route), the watch app and both widgets (gh-sim launches the iPhone app only). B9 and B6's Streak detail change reuse existing views and copy.

## Must change

Nothing.

## Notes

- Tests for B3, B2, B1, B7 and B9 assert pure helpers (`TodaySnapshot`, `applicationContext`, `practiceTriggers`, `checkInSlots`, `remindersCanFire`), not the views, widgets or notification center, which have no test seam here. The wiring was read instead. P4's test proves the hook fires on recovery and not on a healthy store, not that `hasCalibrated` is cleared (`launchRecovery` is private).
- B9: if reminders are off and permission is denied, "Turn on →" now opens iOS Settings without turning reminders on (`TodayView.swift:1142-1145`), so after allowing, the user taps once more. Better than base, where the tap did nothing visible.
- B7: a wide 15-minute window now fires every 18 minutes while Settings still says "Every 15 minutes". This is the audit's own suggested fix ("fewer, wider slots"), but it is still silent. Worth a decision on whether Settings should show it.
- B1: a practice started before midnight and finished after credits the new day's streak but does not mark today's practice done (`TodaySnapshot.practiceCompleted` keys on `startedAt`), so that day's reminder still fires. Rare.
- B1: a completed practice now runs a full reminder pass, which also rewrites check-in slots and logs `remindersScheduled` once more. Same timing class as the held B5.
- B2: the widget score mixes aligned % with the fixed check-in scores (85/55/25) and shows the best. Reasonable, but a 40% practice beside a "good" check-in reads 85.
- B3: the watch no longer re-applies the phone's always-on value on every watch launch, only when the phone changed it, matching the existing intent in `pushStateIfStale`'s comment. A toggle set on the watch now survives watch relaunches.
- The fixes doc cites the reverts as `9ffd45a` and `1d94c24`; on this branch they are `f7a643b` and `255966f`.

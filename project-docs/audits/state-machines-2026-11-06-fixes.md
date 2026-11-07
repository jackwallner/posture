# Fixes for the state machine audit, 2026-11-06

Fixes for the claims that `state-machines-2026-11-06-review.md` confirmed, in the review's ranked order, using its corrected routes. Branch `fleet/20261106-165320-59a3-claude`.

**Summary: 12 in scope. 11 fixed, 1 held for Jack (B8), 0 skipped.** In scope: the 9 CONFIRMED and CONFIRMED-MINOR claims, B5 (UNVERIFIED, settled as reachable) together with the review's missed cancel-while-adding case, and the product calls P4 (the review calls it a real state inconsistency) and P6 (unsettled, but the fix only keeps the tab selection valid).

## Claims

| Id | Outcome | Commit | Regression test | What changed |
|---|---|---|---|---|
| B3 watch app and complication show 0 | fixed | `3439a988`, `3c491f24` | `TodaySnapshotTests.testWatchGetsThePhoneStreakAndTodayScore`, `testWatchStreakAndScoreAgeLikeThePhone`, `testWatchStoresWhatThePhoneSent` | The phone adds a `TodaySnapshot` (streak fields, today's score and its day) to the application context it already pushes, after every completed practice or walk and every check-in, and on activation when it has changed. The watch saves it in its App Group defaults; `WatchTodayView` and the complication read it, and age it with the phone's own lapse rules. A `.watchConnectivity` background task lets the complication update while the app is closed. The watch now applies the phone's always-on value only when it changed on the phone, so the extra pushes never undo a toggle set on the watch. The push is skipped when no paired watch has the app |
| B2 iPhone widget shows no practice score and lags | fixed | `a20fbdff` | `TodaySnapshotTests.testCompletedPracticeGivesTheWidgetATodayScore` (the repro test, pointed at the widget's new scorer), `testWidgetScoreIsTheBestOfTodayAndIgnoresPartialsAndYesterday` | The widget scores today's completed practices and walks (aligned %) with the scored check-ins (`TodaySnapshot.todayScore`), and every practice or check-in calls `WidgetCenter.reloadAllTimelines()` |
| B1 practice reminder fires after today's practice | fixed | `2537b71d` | `ReminderSchedulingTests.testPracticeReminderDoesNotFireTodayAfterTodaysPractice`, `testPracticeReminderFiresTodayWhenPracticeIsNotDone`, `testPracticeReminderKeepsFiringDailyWithoutReopeningTheApp`, `testPracticeDoneTodayCountsOnlyCompletedPracticesFromToday` | The reminder is one repeating trigger per weekday instead of one daily trigger. When a practice is done today, today's weekday becomes a one-shot a week out, so every other day keeps firing with the app closed (audit P1-2 still holds) and the next reschedule restores it. A completed practice reschedules. The legacy `posture.practice.daily` request is still removed on upgrade, and the check-in cap drops from 60 to 57 (ids 0 to 59 are still cleared) so the total stays within iOS's 64 pending requests |
| B4 "Safety net" announced on day one | fixed | `72073f76` | `StreakSaveTests.testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave` (the repro test), `testSafetyNetArrivesWithTheSevenDayMilestoneSave`, `AchievementCatalogTests.testFreezeSavedNeedsTheSevenDayMilestoneSave` | The badge tracks the first earned save, the 7-day milestone bonus (`bestStreak >= 7`), instead of the starting allotment. It no longer un-earns and re-announces as saves run out and refill. The old `testFreezeSavedFromAvailableFreeze` pinned the bug and was replaced |
| B6 streak reads 0 for a run the next practice keeps | fixed | `93cb2de0` | `StreakSaveTests.testStreakDoesNotReadZeroForARunThatTheNextPracticeWillSave` (the review's route through real records), `testSavesShownMatchWhatTheNextPracticeHas`, `testStreakStillReadsZeroWhenNoSaveCanCoverTheGap` | `displayStreak` and `record` share `freezesAfterRefill`, so a weekly refill that is due counts in the display. Today's and Streak detail's save counts use the same number (`displayFreezes`). `StreakServiceTests.testDisplayStreakZeroesALapsedRun` used an unreachable state (0 saves, no refill yet); it now has a refill date and still covers a dead run. No stored data changes |
| B9 Today promises a next reminder with permission denied | fixed | `6c7722cb` | `ReminderSchedulingTests.testTodayDoesNotPromiseRemindersWhenNotificationsAreDenied` | Today reads the authorisation status with the pending queue; unless notifications can fire it shows the existing "Reminders are off." with "Turn on →", which opens iOS Settings when permission is denied. No new copy |
| B10 Settings keeps "Notifications are off." after allowing | fixed | `fab30161` | none: a SwiftUI foreground observer, and the simulator test host cannot change notification permission | Settings re-reads the authorisation status on `didBecomeActiveNotification` |
| B7 wide 15-minute windows cut at 20:45 | fixed | `9a5cbbaa` | `ReminderSchedulingTests.testWideFifteenMinuteWindowRemindsUntilTheEndHour`, `testWindowsThatFitKeepTheChosenInterval` | When the chosen interval needs more slots than the cap, slots are spaced evenly over the whole window (6:00 to 23:00 at 15 minutes becomes every 18 minutes, last at 22:48) instead of stopping early. Windows that fit keep the chosen interval (the default 9:00 to 20:00 is unchanged at 44 slots) |
| B5 overlapping reschedules leave stale slots, plus the review's cancel-while-adding case | fixed | `95e75571` | `ReminderSchedulingTests.testOverlappingReschedulePassesRunOneAfterAnother` | Settled as reachable: every settings change starts two passes, each pass suspends on every `add`, and dropping the slot count (for example End 21 to 20 at 15 minutes from Start 6) lets the older pass's tail land after the newer pass's remove; turning check-ins off mid-pass does the same. All passes now run through a `SerialTaskQueue` and read settings when they start, so the last settings win |
| B8 first spent save refills the next day | held | none | none | See "Held for Jack" |
| P4 store recovery leaves setup flags set | fixed | `a29208df` | `DataServiceTests.testRecoveryTellsSetupTheFreshStoreHasNoCalibration` | The launch recovery clears `hasCalibrated` after it opens a fresh store, so the user is routed to calibration instead of landing on Today with no `Calibration` row. The backup on disk is untouched. Telling the user is held, see below |
| P6 purchase from the Posture+ tab leaves the selection on a removed tab | fixed | `767c9d83` | none: tab selection lives in `MainTabView` state with no unit seam | When Pro turns on with the Posture+ tab selected, the selection returns to Today. Not verified on a device which way SwiftUI shows a missing tag; the change only keeps the selection valid |

## Held for Jack

- **B8 first spent save comes back the next day.** The review calls it a product call ("Decide the rule rather than treat it as a defect"), and the fix takes a save away from users. Decision: should the weekly refill clock start when the streak starts (stamp `lastFreezeRefill` when `StreakState` is created, so the first spent save waits up to a week), or stay as shipped (the first spend refills on the next record, and the existing `testRefillWhenEmptyAndNoRefillDateSetsTo2` keeps pinning it)?
- **P4 messaging.** Recovery now routes to calibration, but the user is still not told that their history was moved to a backup, and nothing can restore it. Decision: show a one-time notice after a recovery, and should there be a way to restore the backup?
- **P5 notification tap while a session is live.** Unsettled: whether a root-level cover presents over Today's session cover needs one device run. Decision: while a practice or walk is on screen, should a reminder tap be ignored, or queue a check-in for after the session?
- **P8 pending purchase shows no message.** `OnboardingTrialView` and Settings' sheet treat `.pending` as success. This is the trial flow and paywall. Decision: should both show the "purchase pending" explanation `PaywallView` already shows?

## Skipped

None. P1, P2, P3 and P7 are product decisions the review agreed with and are left alone.

## Test runs

| Run | Command | Result |
|---|---|---|
| Baseline, before any change (clean worktree of `50aaca49`) | `gh-sim test --scheme Posture` | 177 passed, 0 failed (Xcode 27.1, iPhone 17, iOS 27.2). GitHub run 42321080723, gh-sim id `posture-baseline-59a3-imac9204-1106-165450-13168` |
| Final, all fixes | `gh-sim test --scheme Posture` | FINAL_RESULT |

The repro suite was never added to the test target; its sound tests (B2, B4, and B6 through real records) live on in the regression tests above. Its notification tests were not kept: the review showed they fail on their own preconditions in the simulator host.

`python3 Tools/Localization/check.py`: 775 keys, 6 languages, 0 problems. No user-facing copy was added.

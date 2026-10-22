---
paths:
  - "Posture/App.swift"
  - "Posture/Utilities/UnfoldedSplit.swift"
  - "Posture/Utilities/DuoScreenshotTour.swift"
  - "Posture/Views/HistoryView.swift"
  - "PostureTests/UnfoldedSplitTests.swift"
---

# Posture: iPhone Duo (2026-10-21)

- Unfolded (regular width, room for two panes of at least 360 pt),
  `MainTabView` puts the tab view (Today, Progress, Posture+, Settings and its
  bar) on the leading side of the fold and History in its own pane on the
  trailing side; the History tab leaves the bar while split. Pane edges come
  from `GeometryProxy.verticalFold()` (iOS 27.1 `reservedRegions(.division)`),
  else an even split (`UnfoldedSplit`, tested in `UnfoldedSplitTests`). The
  folded Duo, every phone and the unfolded Duo held in portrait keep one column.
- Folding only moves frames: the `TabView` is never rebuilt, so Today keeps its
  scroll position and covers. History is a separate instance in tab and pane
  (its only state is the open session and sheets). Never wrap the tabs in an `if`.
- `.phonePane` gives each tab's content and the History pane
  `horizontalSizeClass = .compact` and, while split, `toolbarVerticalBehavior(.disabled)`
  so a pane's back button stays leading instead of moving beside the fold.
  Never set the size class on the `TabView` itself: its bar placement is the
  system's. Split, the tabs use a hard bottom scroll edge (`unfoldedBarEdge`).
- In the History pane a session opens as a push inside the pane
  (`HistoryView(opensSessionsInPane: true)`, nav bar hidden, its own close
  button pops); folded it stays a sheet.
- Onboarding and calibration (first run) use `.unfoldedLeadingPane` with
  `SetupFoldPanel` in the trailing pane. Today's sheets (streak, levels,
  achievements, paywall, trial offer) and practice/walk covers still present
  across the whole inner display.
- Captures: `gh-sim launch --device 'iPhone Duo' --scheme Posture --wait 6
  --record-seconds 60 --args "-SCREENSHOT_SEED -PostureProOverride -DuoTour
  -DuoTourFirst 3 -DuoTourStep 14"` plus `--url noop://1..9`, and tests as a
  separate `gh-sim test` (in `gh-sim all` the two recorders collide). Noop URLs only pace shots
  (`simctl openurl` to a real scheme raises an alert on iOS 27). gh-sim
  relaunches the app after unfolding, so the tour restarts per display.
  `-DuoTour` also skips the notification permission alert. `DUOTOUR` lines in
  app.log map shots to routes and log the measured width and fold. The tour
  switches tabs unanimated, as a tap does (an animated switch grows the new tab
  from a zero frame on video). The seed leaves today's practice to do and
  stamps nothing after the 9:41 screenshot clock, so Today and History agree.

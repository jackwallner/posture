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
  system's. Split, each tab and the History pane get `unfoldedBarClearance`:
  content stops `TabBarClearance.gap` above the floating bar (or the home
  indicator), and a row that line would slice is hidden whole (`PaneCut`: the
  mask moves up to that row's top, and a Form section gets rounded bottom
  corners there). Rows report their frames with `paneRow()` (History rows),
  `PaneRowStack` (each child of Today's and Progress's column) and
  `paneListRows()` (each Settings section). Never nest a reported row inside
  another reported row: the outer one counts as sliced too. Both a hard scroll
  edge and an eased fade sliced glyphs in static captures (shots reviews
  2026-10-22). Folded the mask is fully open and nothing reports, so folding
  never rebuilds a tab.
- In the History pane a session opens as a push inside the pane
  (`HistoryView(opensSessionsInPane: true)`, nav bar hidden, its own close
  button pops); folded it stays a sheet.
- Onboarding and calibration (first run) use `.unfoldedLeadingPane` with
  `SetupFoldPanel` in the trailing pane. Today's sheets (streak, levels,
  achievements, paywall, trial offer) and practice/walk covers still present
  across the whole inner display.
- Captures: one `gh-sim all --device 'iPhone Duo'` run with a `--screen` per
  surface (gh-sim relaunches per screen, folded then unfolded). No `--url`:
  `simctl openurl` to a real scheme raises an alert on iOS 27, and fake
  schemes like `noop://` are banned. The DEBUG tour walks `-DuoRoutes`
  (folded) and `-DuoRoutesRegular` (split) once and holds the last route; the
  last copy of an argument wins, so `--args` sets the defaults and each
  `--screen` overrides them, e.g. `--args "-SCREENSHOT_SEED -PostureProOverride
  -DuoTour -DuoTourFirst 3 -DuoTourStep 3 -DuoRoutes today -DuoRoutesRegular
  today" --screen "-DuoRoutes progress -DuoRoutesRegular progress,session"`
  (Progress beside a session). `-DuoTour` also skips the notification
  permission alert. `DUOTOUR` lines in app.log map shots to routes and log the
  measured width and fold. The tour switches tabs unanimated, as a tap does
  (an animated switch grows the new tab from a zero frame on video). The seed
  leaves today's practice to do and stamps nothing after the 9:41 screenshot
  clock, so Today and History agree.

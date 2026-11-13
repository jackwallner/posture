---
paths:
  - "Posture/App.swift"
  - "Posture/Utilities/ReadableColumn.swift"
  - "Posture/Utilities/DeviceKind.swift"
  - "Posture/Utilities/UnfoldedSplit.swift"
  - "PostureUITests/IPadCaptureUITests.swift"
  - "project.yml"
  - "Posture/Info.plist"
---

# Posture: iPad layout (added 2026-11-12)

Universal app: `TARGETED_DEVICE_FAMILY "1,2"` on the app and the iOS widget, all
four iPad orientations in `UISupportedInterfaceOrientations~ipad`. Once a version
ships with iPad support it can never be removed.

- Main screen: the iPhone Duo split (`UnfoldedSplit`) is also the iPad layout,
  with iPad thresholds in `MainTabView.split`. The tabs (Today, Progress,
  Posture+, Settings) take at least 660 pt (`primaryMinimum`, the width the
  floating tab pill needs to avoid collapsing into a chevron) and History takes
  the rest, at least 480 pt. That needs 1140 pt: 11-inch landscape (660 and
  520) and 13-inch landscape split; every portrait width and Split View keep
  one column, History as a tab. An iPad has no fold.
- Single column on an iPad: each tab and History are `iPadSingleColumn`, a 680 pt
  column on the page wash. It is a frame cap, never an `if`, so the tabs are not
  rebuilt when the window rotates.
- `MainTabView` measures a `Color.clear` and draws the panes in its overlay.
  Measuring the panes themselves keeps the old width after a landscape to
  portrait rotation (the panes' own width is the measured width), so both panes
  overflow. Keep the measured box independent of the panes.
- Setup (onboarding, calibration): on an iPad `unfoldedLeadingPane` is one
  centred 620 pt column (`readableColumn`), not the Duo's fold panel.
- Full-screen covers (check-in, practice, walk, summary, trial) cap their content
  with `readableColumn` / `dawnColumn()` so the wash and tints still fill the
  screen. Put the cap inside a tinted background, never outside it.
- `DeviceKind` gates what an iPad cannot do: no walk mode (no pedometer worth
  walking with), no Always-on Watch toggle (an iPad pairs with no Watch), and
  the buzz sentences become notification sentences (no haptic motor). Sentences
  that name the device take `DeviceKind.name` (`%@` in the catalog). Walk
  and Watch features stay in the paywall copy: Posture+ is one subscription
  across the user's devices.
- Head motion: `CMHeadphoneMotionManager` works on iPadOS 14+ with the same
  AirPods. Nothing in the head-motion path is iPhone-only.
- Capture: `PostureUITests/IPadCaptureUITests` rotates the device and attaches
  a frame per surface in portrait and landscape
  (`gh-sim test --scheme PostureUITests --only PostureUITests/IPadCaptureUITests
  --device "iPad Pro 13-inch (M5)"`; frames land in `attachments/`). Review every
  frame by eye. App Store iPad frames are 2064x2752, one English set shared by
  every locale like the iPhone set.

# Screenshot capture instructions

The engineer fills this folder before sending the handoff over. ~15
minutes of work.

## What we need

Each screen listed in `../screen-inventory.md` with a "Screenshot
needed:" line. Use the exact filename from that doc.

## Capture setup

```bash
# Build & run on simulator (CLAUDE.md says iPhone 17 Pro)
xcodegen generate
xcodebuild -project Posture.xcodeproj -scheme Posture \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build
open -a Simulator
```

Then in the simulator:
- `File → Open Simulator → iPhone 17 Pro`.
- Light mode (Features → Toggle Appearance to confirm Light).
- Run the app from Xcode.
- For each screen, `⌘S` to save a screenshot to Desktop, then move it
  here with the right name.

## Light + dark

For the top-priority screens (TodayView, AcknowledgmentView, Paywall),
capture both:
- `05-today-with-data.png` (light)
- `05-today-with-data-dark.png` (dark)

Dark mode: `Settings → Developer → Dark Appearance` in the simulator.

## Generating fake data

Several screens need data on them to be useful. Options:

1. **Onboard fresh + click through manually.** Tap "Get started", pick
   "No, use my camera" in calibration, complete capture. You now have a
   calibrated, just-installed state — good for empty-state captures.
2. **For History with data:** trigger several check-ins via the "Check
   in now" button on Today, picking different qualities by tilting the
   simulator's "camera" (use Features → Camera → External Webcam or
   point the Mac camera at varying angles, or use the "Manual check"
   path repeatedly).
3. **For Pro paywall + Pro features:** call
   `SubscriptionService.shared.setLocalOverride(isPro: true)` from a
   debugger breakpoint or temporarily add it to `App.init` for the
   capture session. **Remove before shipping.**

## What if Pro features are gated behind purchase?

`SubscriptionService.setLocalOverride(isPro:)` exists for exactly this.
Or skip Pro screenshots — Design can work from `screen-inventory.md`
descriptions alone for those.

## What to do with the screenshots

Put them in this folder (`docs/claude-design-handoff/assets/`). Reference
them by relative path from the design write-up. The whole handoff folder
gets sent to Claude Design.

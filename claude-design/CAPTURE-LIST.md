# Capture list — raws for the store screenshots

Six captures, saved into `claude-design/raw/` with these exact names.
The marketing canvas is fixed at 1320×2868 (6.9" ASC slot), and your raw
gets scaled into the drawn phone frame — so captures from **any** modern
iPhone (or the iPhone 17 Pro Max simulator) work. Plain screenshots,
no markup, PNG straight from the device/simulator.

Before capturing, stage the data so it sells (5 minutes):
- Do 3–4 check-ins spread through the day (mostly "aligned") so Today
  shows a high score ring and "3 of 4 scans on track".
- Have a multi-day streak going if possible (even 2–3 days reads fine;
  the flame + count shows top-right on Today).
- Settings → reminders ON, a sane window (9:00–18:00).
- Phone language English, battery decently charged, Wi-Fi on (status bar
  is visible in the raws and stays real — that's fine, it's the house
  style on the published apps).

Fastest path: launch the DEBUG build with `SCREENSHOT_SEED -PostureProOverride`
(see `Posture/Utilities/ScreenshotSeed.swift`) to land in a fully-staged app
(6-day streak, a week of passed practice sessions, a walk, per-minute history,
Pro-crisp surfaces) with no onboarding/calibration, then navigate headless with
`axe` and capture with `xcrun simctl io <UDID> screenshot`.

| File | Screen | How to get there |
|------|--------|------------------|
| `raw-1-today.png` | Today tab, scored day | Open seeded app. Streak chip, "Practice complete · 84% aligned, target met", Level 3, rhythm chart. |
| `raw-2-practice.png` | "Today's practice." pre-start | Today → "Practice again →". The chin-tuck + hold explainer, duration/target chips, Begin. |
| `raw-3-summary.png` | Session receipt | History → tap the top session row. Aligned/drifting/slouching split + "Target met, counted toward your level." |
| `raw-4-history.png` | History tab | "A strong week of practice." minutes-per-day bars + session list. |
| `raw-5-progress.png` | Progress tab | The level ladder (L1–L5), NOW/NEXT cards, "target-met sessions to next level". |
| `raw-6-checkin.png` | Hand check-in confirmation | Today → "Log a manual check-in" → "Check in by hand" → "Noted." (logged for your streak). |

Watch (optional this round): plain captures from the watch app/widget at
native resolution go directly into `claude-design/output/watch/` — Apple
wants watch shots near-raw, not marketing-framed. The required ASC watch
slot is 410×502 (Ultra); 416×496 (Series 10) is also accepted.

## Then

1. In Claude Design: "+" → **Link local code…** → this repo folder.
2. Paste the contents of `claude-design/SCREENSHOT-PROMPT.md`.
3. Download the 6 PNGs into `claude-design/output/store/`.
4. Verify sizes — every file must be exactly 1320×2868:
   `sips -g pixelWidth -g pixelHeight claude-design/output/store/*.png`
   (fix any stragglers with `sips -z 2868 1320 <file>` — height first).
5. Drop the finals into `fastlane/screenshots/en-US/` and upload via
   `scripts/upload-appstore-metadata.sh`, or drag into ASC directly.

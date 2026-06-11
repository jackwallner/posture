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

| File | Screen | How to get there |
|------|--------|------------------|
| `raw-1-today.png` | Today tab, scored day | Open app after the staged check-ins. Ring + "aligned" + streak visible. |
| `raw-2-scan.png` | AirPods scan countdown | "check in now" → "scan with AirPods" with AirPods in → capture mid-countdown (big 3/2/1 numeral). |
| `raw-3-aligned.png` | "aligned." result | Finish a scan that lands aligned (sit straight) → serif "aligned." screen before tapping done. |
| `raw-4-history.png` | History tab | After several check-ins across ≥2 days so the week bars + "% aligned" + entries list look alive. |
| `raw-5-checkin.png` | Check-in choice sheet | "check in now" → the "how's your posture right now?" sheet with the aligned/drifting/resting chips. |
| `raw-6-streak.png` | Today, streak emphasis | Same Today screen on a streak day ≥3 — capture with the flame/count fresh (can be same capture session as raw-1 if streak shows; otherwise skip and Claude Design will produce 5). |

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

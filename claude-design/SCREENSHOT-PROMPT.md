# App Store screenshots for Posture — composite, do NOT recreate

Produce exactly 6 finished PNGs and nothing else. No preamble, no
explanations, no alternates, no manifest, no follow-up questions.

## The one rule that overrides everything else

**Use the raw screenshots in `claude-design/raw/` as-is, pixel-for-pixel.**
Each raw PNG is the literal screen content. Your job is ONLY to place that
raw image inside a drawn iPhone device frame on a branded canvas and set
marketing text above it. **Do not redraw, recreate, retouch, re-typeset, or
"idealize" any part of the app UI. Do not change the data, times, numbers,
or text visible in the raws.** If a raw looks imperfect, ship it anyway —
real pixels beat redrawn ones. The only thing you generate is the canvas,
the device frame, and the headline/subline text.

## Canvas — exact size, non-negotiable

- Every output: **1320 × 2868 px, portrait, PNG, sRGB, no transparency.**
  This is the App Store Connect 6.9-inch iPhone slot. Do not output any
  other size. Do not crop. If your renderer can't hit exact pixels, render
  larger at exactly 1320:2868 aspect and downscale to 1320 × 2868.
- Raws may be a slightly different resolution than the frame's screen
  cutout — scale them uniformly (never stretch, never crop content) to fit
  the device frame's screen area.

## Frame anatomy — match the house style

Same layout system on all 6 frames (this matches my other published apps —
e.g. "Total Calories" on the App Store — go look if unsure):

- **Headline, top of canvas, centered, two lines:**
  - Line 1: heavy rounded sans-serif (SF Pro Rounded Bold/Heavy feel),
    deep slate `#2F3E3A`.
  - Line 2: *italic serif* (New York / SF Serif italic feel) in the frame's
    accent color, ending with a period.
  - Font size ≈ 150–170 px per line; the two lines together ≈ 12% of
    canvas height, starting ≈ 120 px from the top.
- **Subline:** one short sentence, ≤ 60 characters, medium-weight rounded
  sans, secondary slate `#6B7B76`, centered under the headline.
- **Device frame:** a simple modern iPhone outline (thin dark bezel,
  rounded corners ≈ 120 px radius, Dynamic Island visible from the raw
  itself — do not draw a fake one over it). Frame width ≈ 78% of canvas
  width, centered horizontally, top edge starting ≈ 26% from canvas top,
  and the bottom of the phone **bleeds off the bottom edge of the canvas**
  (cut off, not floating). Soft drop shadow, ~8% opacity.
- **Canvas background:** soft vertical wash of the frame's tint color into
  near-white `#FAFCFB`. Flat and calm — no patterns, no extra graphics, no
  icons, no badges, no fake UI elements outside the phone.

Brand palette (the app's real "Daylight" design system):
mint canvas `#E8F4EF` · ink `#2F3E3A` · secondary `#6B7B76` ·
sage `#8FC5A8` · sand `#E8C896` · clay `#E8A09A` · lavender `#BFA8E4`.

Apple 2.3.7 compliance: no competitor names, no trademarks, no Apple
hardware claims beyond "AirPods", no ratings/awards badges.

## The 6 frames, in display order

| # | Raw file | Output file | Accent / tint | Headline line 1 | Headline line 2 (italic serif) | Subline |
|---|----------|-------------|---------------|-----------------|-------------------------------|---------|
| 1 | `raw-1-today.png` | `store-1-today.png` | sage `#8FC5A8` | Sit taller, | every day. | 3-second posture checks with your AirPods |
| 2 | `raw-2-scan.png` | `store-2-scan.png` | lavender `#BFA8E4` | Your AirPods | read your posture. | Head-motion scan — no camera, no wearable |
| 3 | `raw-3-aligned.png` | `store-3-aligned.png` | sage `#8FC5A8` | Gentle words, | not nagging. | Aligned, drifting, or resting — never scolded |
| 4 | `raw-4-history.png` | `store-4-history.png` | sand `#E8C896` | See your | slouch hours. | Your week, hour by hour, on-device |
| 5 | `raw-5-checkin.png` | `store-5-checkin.png` | clay `#E8A09A` | No AirPods in? | Just tell us. | Check in by hand and keep your streak |
| 6 | `raw-6-streak.png` | `store-6-streak.png` | sand `#E8C896` | Streaks make | it stick. | Daily flames, with freeze protection |

If a listed raw is missing from `claude-design/raw/`, skip that frame and
renumber nothing — produce the remaining outputs under their listed names.

Write outputs to `claude-design/output/store/`.

# Posture · Design Pass · Deliverables

**Direction:** Daylight (paper + sage)
**Date:** 2026-05-15
**For:** v0.1.0 → App Store submission

## What's in this folder

| File | For |
|---|---|
| `design-response.md` | The full design write-up. Read first if you're the design reviewer. |
| `change-list.md` | Code-level diff plan against current files. Hand this to Claude Code. |
| `mockups/` | PNG screenshots of every redesigned surface + the design system. |
| `Daylight - Design Pass.html` | Live, interactive review surface (open in any browser). Pixel reference for everything in the mockup PNGs. |

## Recommended reading order

1. Open `Daylight - Design Pass.html` in a browser. Scroll top → bottom. This is the visual.
2. Skim `design-response.md` to understand the why.
3. Hand `change-list.md` to engineering. Each file maps to a Swift source file with line numbers.

## Companion mockup PNGs

| File | Maps to |
|---|---|
| `mockups/00-cover.png` | Identity statement |
| `mockups/01-color-palette.png` | §2 Color system (light + dark + quality scale) |
| `mockups/02-type-scale.png` | §3 Typography |
| `mockups/03-components.png` | §4 Component patterns |
| `mockups/05-today-redesign.png` | §5.1 TodayView |
| `mockups/06-acknowledgment-redesign.png` | §5.2 AcknowledgmentView (choice / scanning / done × 3) |
| `mockups/09-history-redesign.png` | §5.3 HistoryView + Pro variant |
| `mockups/12-paywall-redesign.png` | §5.4 PaywallView + Settings Pro card |
| `mockups/03-calibration-redesign.png` | §5.7–5.8 CalibrationView |
| `mockups/14-banner-pattern.png` | §6 Empty / error / permission |

## Out of scope (per `brief.md`)

App icon · watchOS · iPad · localization · marketing screenshots.

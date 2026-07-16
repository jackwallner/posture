# Current Design System

Pulled verbatim from `Shared/Utilities/Theme.swift`. Use as a starting
point — feel free to propose replacements, but provide hex + a
side-by-side rationale so the engineer can swap them in one diff.

## Colors

### Brand
| Name | Value | Use |
|---|---|---|
| `brandPrimary` | `Color(red: 0.36, green: 0.55, blue: 0.95)` ≈ `#5C8DF2` | Primary CTA, accents |
| `brandSecondary` | `Color(red: 0.55, green: 0.42, blue: 0.95)` ≈ `#8C6BF2` | Gradient end-point |
| `brandGradient` | `LinearGradient(brandPrimary → brandSecondary, topLeading → bottomTrailing)` | All primary buttons, hero icons |

### Posture quality palette
| Name | Value | Maps to |
|---|---|---|
| `good` | `#33B873` (≈) | "Looking good!" / score ≥ 80 |
| `borderline` | `#FFB333` | "Shift back a bit" / score 50–79 |
| `bad` | `#F25C5C` | "Straighten up" / score < 50 |
| `streakFlame` | `#FF8C1A` | flame icon when streak > 0 |

### Neutrals (light/dark adaptive — system semantic)
| Name | iOS | watchOS override |
|---|---|---|
| `background` | `Color(.systemBackground)` | `.black` |
| `cardSurface` | `Color(.secondarySystemBackground)` | `Color(white: 0.12)` |
| `cardSurfaceLight` | `Color(.tertiarySystemBackground)` | `Color(white: 0.18)` |
| `ringTrack` | `Color(.systemFill)` | `Color(white: 0.20)` |
| `textPrimary` | `Color(.label)` | `.white` |
| `textSecondary` | `Color(.secondaryLabel)` | `Color(white: 0.70)` |
| `textTertiary` | `Color(.tertiaryLabel)` | `Color(white: 0.50)` |

## Typography

System fonts only. Specific calls:
- `Theme.bigNumber(size)` → `.system(size: size, weight: .bold, design: .rounded)`
  - 34 — onboarding headline, paywall title
  - 28 — calibration step headlines, "You're calibrated"
  - 64 — countdown digit
- `.title.bold()` — ack screen headers
- `.headline` — card titles, buttons
- `.subheadline` — body explanations
- `.body` — long paragraphs
- `.caption` / `.caption2` — meta info, dates

No custom font is shipped. Design can propose one (rounded sans like
SF Rounded or a licensed alternative — keep iOS-feel) but flag any
font that needs licensing/shipping.

## Geometry

| Name | Value |
|---|---|
| `cardRadius` | `20` |
| `cardPadding` | `20` |
| CTA padding | `vertical: 14` |
| CTA corner radius | `14` |
| Screen horizontal padding | `32` (most flows), `16` (TodayView scroll) |
| Section spacing | `24` (vertical between major blocks) |

## Iconography

Currently 100% SF Symbols (single-color or hierarchical, no custom
SVGs):

| Symbol | Where |
|---|---|
| `figure.stand` | brand icon, Today + Ack |
| `airpodspro` / `airpodspro.badge.exclamationmark` | airpods status |
| `camera.viewfinder` / `camera.fill` | scan / camera |
| `bell.badge.fill` / `bell.slash.fill` | reminders |
| `flame.fill` | streak |
| `crown.fill` | paywall |
| `checkmark.circle.fill` / `checkmark.seal.fill` | good / done |
| `exclamationmark.triangle.fill` | borderline |
| `xmark.octagon.fill` | bad |
| `chart.bar.xaxis` | history |
| `gearshape` | settings |
| `lightbulb.fill` | tip |
| `hand.tap` | manual check-in |
| `book.fill` | "all tips" |
| `desktopcomputer` / `arrow.triangle.2.circlepath` / `figure.cooldown` / `brain` | tip categories |
| `applewatch.radiowaves.left.and.right` | always-on |
| `infinity` | unlimited history (paywall) |

If Design proposes custom illustrations, please specify which symbols
they replace and provide them as PDF vector or SVG sized for `.frame`
usage. Keep system SF Symbols as the fallback elsewhere — full
custom icon set is out of scope this pass.

## Dark mode

The app inherits semantic system colors for neutrals. Brand colors are
fixed RGB and not dark-mode-tuned — if Design changes them, please
provide both light and dark hex variants explicitly.

## Accessibility minima

- Dynamic Type: must support up to AX5. Current code uses semantic
  fonts which scale automatically.
- VoiceOver: `PostureRing` and `StreakFlame` have explicit
  `accessibilityLabel` / `accessibilityValue` — preserve in new designs.
- Contrast: brand gradient over white passes WCAG AA for large text only.
  Verify replacements pass AA for body text or constrain their use.

# Deliverables

What we need back from Claude Design, in the form the engineer can
hand straight to Claude Code.

## 1. A single design write-up — `design-response.md`

Markdown. One file. Sections, in order:

1. **Identity proposal** — 3–5 sentences on the direction (mood, tone,
   reference apps). One named direction the engineer can adopt or
   reject without ambiguity.
2. **Color system** — new palette with hex codes for brand + quality
   colors, both light + dark mode. Include rationale for changes.
3. **Typography scale** — concrete size/weight pairs for each role
   (display, title, body, caption). System or proposed custom font.
4. **Component patterns** — ring, pill, card, CTA, segmented control,
   form row, banner. One section per pattern with intent + a code-style
   spec the engineer can implement (corner radius, padding, color refs).
5. **Per-screen redesigns** — one subsection per `screen-inventory.md`
   entry marked priority ≥ medium. Each subsection:
   - One short paragraph of intent.
   - An ASCII layout sketch (works) OR a low-fi mockup as a PNG in
     `mockups/` (preferred).
   - A bullet list of concrete changes against the current
     implementation file (e.g., "remove the StreakFlame from line 40,
     move to a small badge in the toolbar").
6. **Empty / error / permission-denied patterns** — a single reusable
   component spec + 2–3 example usages.
7. **Open follow-ups** — what Design decided to defer + why.

## 2. Low-fi mockups (optional but preferred) — `mockups/`

PNG, SVG, or Figma export, one image per redesigned screen named
`<screen-key>-redesign.png` (matching keys in `screen-inventory.md`).
B/W or grayscale is fine — the engineer just needs the *composition*.
Don't burn time on pixel-perfect mocks; the brief is to inform code.

## 3. Engineering-actionable checklist — `change-list.md`

Markdown. Bulleted list of code-level changes against current files,
e.g.:

```
- Theme.swift: replace brandPrimary with #4A6CF7
- Theme.swift: add new constants `surfaceElevated`, `dividerSubtle`
- TodayView.swift:36-99 — restructure: hero ring at top, single CTA
  card, demote streak to navigation toolbar
- PaywallView.swift:45-142 — replace placeholderPaywall with new layout
  per mockups/12-paywall-redesign.png
- AcknowledgmentView.swift:55-130 — choice screen: single primary
  action, manual as text link, add close button
- New component: PostureBanner (for empty/error/permission-denied)
```

This is the file the engineer hands Claude Code first. The rest is
context.

## What we DON'T need

- App icon designs.
- A full design system in Figma (a markdown spec is enough).
- Marketing screenshots (we have a separate fastlane pipeline for those).
- Animation specs as JSON / Lottie (describe motion in prose).
- A new logo or wordmark.

## Format reminder

Plain markdown + PNGs. The engineer's Claude Code session will read the
files directly from this folder. Don't embed designs as a PDF or a
shared link — local files only.

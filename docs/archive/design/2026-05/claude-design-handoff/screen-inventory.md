# Screen Inventory

Each entry: what's on screen today, what to redesign, redesign priority.

Screenshots go in `assets/`. Capture from an iPhone 17 Pro simulator
(or whatever the latest is) — see `assets/CAPTURE_INSTRUCTIONS.md`.

---

## 1. OnboardingView (priority: low)

**Today:** single screen — large `figure.stand` SF Symbol in brand
gradient, two-line headline "Stand tall, every day.", three feature rows
(camera.viewfinder / timer / bell.badge.waveform), full-width "Get
started" button.

**Redesign goal:** keep to one screen. The 3 feature rows feel like a
checklist of features rather than a value prop. Consider replacing with
a single hero illustration or animated demo loop. Don't add steps unless
they materially improve activation.

**Screenshot needed:** `assets/01-onboarding.png`

---

## 2. CalibrationView — AirPods Question (priority: medium)

**Today:** AirPods Pro icon, "Do you have AirPods?" headline, explainer
paragraph, two stacked buttons ("Yes" / "No, use my camera").

**Redesign goal:** the explainer paragraph is too long. The two buttons
look like primary CTAs of equal weight — they probably shouldn't. Picking
"No" is the safe path for most users; picking "Yes" should feel like a
confident-upgrade choice.

**Screenshot needed:** `assets/02-calibration-airpods.png`

---

## 3. CalibrationView — Capture step (priority: high)

**Today:** "Sit upright" headline, explainer, **live camera preview in a
3:4 box** with a brand-gradient border, an AirPods status pill
(green/grey) if applicable, big "5,4,3,2,1" countdown over the preview
when capturing, full-width "Capture" CTA (greyed when no face).

**Redesign goal:** the camera box is the only visually interesting
element. Make the framing feel intentional — a head-silhouette guide,
better empty/no-face state, smoother countdown. The current "Capture"
button when greyed gives no hint *why* it's greyed.

**Screenshot needed:** `assets/03-calibration-capture.png` (with face
in frame) + `assets/03-calibration-capture-noface.png`

---

## 4. CalibrationView — Done (priority: low)

**Today:** big green checkmark.seal, "You're calibrated", two paragraphs
(varies by airpods/no-airpods), full-width "Start using Posture" CTA.

**Redesign goal:** small. Maybe a "what happens next" preview (the
reminders cadence they're about to start receiving).

**Screenshot needed:** `assets/04-calibration-done.png`

---

## 5. TodayView (priority: highest)

**Today:** stack of cards (top to bottom):
1. `StreakFlame` pill (current streak)
2. "Reminders active — Every 30 min — Next 3:00 PM" status card OR
   "Reminders off" card.
3. "Today's response rate" progress bar (broken metric — see audit P1-9).
4. "Today's check-ins summary" — 3 stat tiles (scans / manual / streak days).
5. **"Check in now"** big gradient CTA (the primary action of the app).
6. "Tip" card with the tip-of-the-day.
7. "All posture tips" link → `PostureHabitsView` sheet.
8. Stats row (Longest / Freezes / Total check-ins).

That's 8 visual blocks. Scroll-heavy on small phones.

**Redesign goal:** establish a clear hero. The user opens Today to know
*"how am I doing today, and what do I do next?"* — answer that above
the fold. Demote the stats. Possibly merge response rate + today
summary into one block. Streak gets a smaller representation. Make
"Check in now" the single primary CTA. The tip can stay but as a
secondary block — or shown only after the user has acked at least once.

**Screenshot needed:** `assets/05-today-with-data.png` (a day with a few
check-ins) + `assets/05-today-empty.png` (new user, reminders on but no
acks yet).

---

## 6. AcknowledgmentView — Choice (priority: highest)

**Today:** large `figure.stand` icon, "Time to check in", "How's your
posture right now?", two stacked option buttons (Quick Scan / Manual),
optional Dismiss link (only when triggered by a notification index > 0).

**Redesign goal:** this fires up to 24× a day if a user picks 30-min
intervals on a full day. It needs to be **fast**, **rewarding to land
on**, and **never feel like a chore**. Consider:
- One big primary "Scan" action, manual as secondary.
- A peek of the time-of-day or "what they're about to do."
- A way out (currently locked unless they pick something — see audit P1-12).

**Screenshot needed:** `assets/06-ack-choice.png`

---

## 7. AcknowledgmentView — Scanning (priority: high)

**Today:** "Checking your posture", `QuickScanView` (camera preview with
quality pill bottom-aligned, "3..2..1" countdown below, ProgressView
spinner), "Hold still and look straight ahead" caption.

**Redesign goal:** the camera box should feel like the focus. Possibly a
full-bleed treatment instead of a small inset. The live quality pill
should feel less iOS-default-capsule, more brand. Countdown style needs
attention.

**Screenshot needed:** `assets/07-ack-scanning.png`

---

## 8. AcknowledgmentView — Done (priority: high)

**Today:** big system icon (checkmark.circle / exclamationmark.triangle /
xmark.octagon), title ("Looking good!" / "Shift back a bit" / "Straighten
up"), subtitle, tip card, "Done" CTA.

**Redesign goal:** this is the **reward moment**. Currently feels like
an alert dialog. Three result states should feel meaningfully different
without being scolding for "bad."

**Screenshot needed:** all three: `assets/08a-ack-done-good.png`,
`assets/08b-ack-done-borderline.png`, `assets/08c-ack-done-bad.png`,
and `assets/08d-ack-done-manual.png` (no camera, no quality).

---

## 9. HistoryView (priority: high)

**Today:** weekly quality bar chart, weekly response rate bar chart,
(Pro only) `PassiveTimelineView` 24h heatmap, then a card with an
interleaved timeline of recent acks + (dead) sessions.

**Redesign goal:** the two charts look the same. Compress to one
narrative chart (week-on-week or 7-day trend). The timeline needs to
look less like a settings table — more like a journal feed. Empty state
exists but is bare.

**Screenshot needed:** `assets/09-history-with-data.png` +
`assets/09-history-empty.png`.

---

## 10. PostureHabitsView (priority: low)

**Today:** static educational tips grouped into 4 categories
(Ergonomics / Habits / Stretches / Awareness) — each a `PostureTipCard`.

**Redesign goal:** small. Currently a long scroll of identical cards.
Could benefit from per-category color + iconography.

**Screenshot needed:** `assets/10-habits.png`

---

## 11. SettingsView (priority: medium)

**Today:** native iOS `Form` with sections: Pro, Posture reminders,
Sensitivity (segmented), Calibration, About.

**Redesign goal:** keep the `Form` semantics for accessibility, but the
Pro upsell row at the top is a generic chevron row — could be a more
visually distinctive upsell card. The recalibrate confirmationDialog is
weak UX (see audit P2). AirPods status sub-view inside the toggle is
crowded.

**Screenshot needed:** `assets/11-settings-free.png` (non-Pro) +
`assets/11-settings-pro.png` (Pro user).

---

## 12. PaywallView — placeholder (priority: highest)

**Today:** crown icon in gradient, "Posture Pro", subtitle, 4 benefit
rows (always-on watch / timeline+heatmap / before-after / unlimited
history), 2 purchase buttons (monthly / yearly), "Free trial included",
"Restore Purchases", error inline, "Maybe Later" footer.

Note: when RevenueCat is configured, this is replaced by
`RevenueCatUI.PaywallView` — Claude Design should redesign **the
placeholder** since that's the fallback / the one we control. We may
also build a custom paywall instead of the RC UI — Design should
propose both.

**Redesign goal:** stop looking like a SaaS upsell. We're a wellness
habit app; this paywall should evoke "long-term me" not "unlock
features." Consider showing a real before/after concept (without
implying medical claims), a vivid week-of-streak visualization, etc.

**Screenshot needed:** `assets/12-paywall.png`

---

## 13. PassiveTimelineView — Pro 24h heatmap (priority: medium)

**Today:** "Today's slouches" header with count, small source-breakdown
chips, 24-bar heatmap.

**Redesign goal:** the bars use `Theme.bad` opacity — a bit punitive.
Could feel more like a "Calm" / "Headspace"-style timeline.

**Screenshot needed:** `assets/13-passive-timeline.png` (only available
to Pro users with AirPods/watch data).

---

## Components (used across screens)

- `PostureRing` — animated circular progress with score in the middle.
- `StreakFlame` — pill with flame icon + N days.
- `PostureLiveIndicator` — colored capsule with icon + label (Good /
  Watch your posture / Sit up!).
- `PostureTipCard` — left icon + body text card.
- `CameraPreview` — `UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer`.

Design should propose consistent treatments — ring style, pill style,
card style — that get reused, not a unique style per surface.

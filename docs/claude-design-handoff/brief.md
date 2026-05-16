# Brief

## Product in one sentence

A consumer iOS app that periodically nudges you to check your posture,
optionally uses your front camera (or AirPods head motion) to verify it,
and tracks a daily streak so the habit sticks.

## Target user

A 25–45 year-old desk worker on a Mac/PC most of the day. Owns an iPhone,
probably owns AirPods, possibly an Apple Watch. Has tried 1–2 wellness
apps. Doesn't want a clinical / medical tone. Wants something that
feels gentle, not nagging.

## What works today (don't break)

- The reminder → tap → 3-second camera scan → done loop is fast and
  doesn't ask for too much attention.
- The check-in screen tells you "Looking good!" / "Shift back a bit" /
  "Straighten up" — color-coded green / amber / red. Clear at a glance.
- A "Tip of the day" card on Today gives the app something to read
  beyond stats.
- Calibration flow is gated up front and short (1 question + 5s capture).

## What feels weak (do work on this)

- **Generic visual language.** SF Symbol + gradient card pattern repeats
  on every screen. Onboarding, Today, History, Settings, Paywall all
  feel like the same template with different headers.
- **Today screen is a stack of cards** — reminder status, response rate,
  today summary, check-in CTA, tip, "all tips" link, stats. No clear
  hero. The user can't tell what to look at first.
- **History is two charts + a list.** Doesn't tell a story. A user with a
  3-day streak sees something that looks identical to a user with 30
  days minus the number.
- **Streak is buried at the top.** A "Duolingo-style streak" was an
  original goal, then the user explicitly de-prioritized it in
  `VIDEO_REVIEW_NOTES.md`. We still keep it functionally but the visual
  weight should drop.
- **Paywall** mixes a system-rendered RevenueCat paywall with a custom
  placeholder. The custom one is generic SaaS — "crown icon, 4 benefit
  rows, big purple CTA." It doesn't earn the price.
- **AcknowledgmentView** (the post-tap full-screen check-in) is the
  most-used surface in the app — 1× per reminder × N reminders/day. It's
  currently a 3-block vertical layout that doesn't feel rewarding.
- **Empty states** — History has one. Today, Paywall, Settings have
  none. New users and users-with-no-data hit awkward blank states.

## What we want from this design pass

In priority order:

1. **A visual identity** — a real color palette and typographic scale
   that isn't just `Color.brandPrimary` (`#5C8DF2`-ish blue) + system
   labels. Should still play well with light + dark mode + Dynamic Type.
2. **A redesigned `TodayView`** — single hero ("here's where you are
   right now"), then secondary content. Should be obvious at a glance
   whether the user is on track for the day.
3. **A redesigned `AcknowledgmentView`** — the moment-of-truth screen.
   Should feel slightly rewarding to land on. Three states: scanning,
   result (good/borderline/bad), manual-only.
4. **A non-generic paywall** — feels Posture-y, not crown-and-checklist.
5. **A History screen that tells a story** — a "you got better this
   week" / "you slipped on Tuesday" feel. Charts are fine if the
   composition isn't generic.
6. **Empty/error/permission-denied patterns** — a consistent system
   the engineer can reuse (banner / inline card / full-screen).

Stretch:
- Pass over `CalibrationView` (currently 3 sequential screens — works,
  but feels DIY).
- Onboarding (single screen now, could earn one more screen of
  explanation if it materially helps activation — but don't add steps
  unless you can justify it).

## Out of scope for this pass

- New features.
- App icon redesign.
- Apple Watch UI (we'll do a separate watch handoff).
- Localization / non-English.
- iPad layouts (iPhone-only build).

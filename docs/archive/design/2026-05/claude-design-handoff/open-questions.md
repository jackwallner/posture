# Open Questions for Design

Decisions Design should weigh in on — don't proceed assuming an answer
without flagging.

1. **How prominent should the streak be?**
   Original spec was Duolingo-style, then de-prioritized in
   `VIDEO_REVIEW_NOTES.md`. Current TodayView still puts it at the top.
   Recommend a treatment that doesn't gamify the home screen but
   doesn't kill the social-proof either (e.g., move to nav toolbar?
   small badge?).

2. **Result framing — celebration vs. neutral.**
   On a "good" check-in we say "Looking good!" with a green checkmark.
   On a "bad" check-in we say "Straighten up" with a red xmark.octagon.
   For a wellness app, the "bad" framing risks feeling scolding.
   Recommend a tonal scale: how do we tell the user their posture
   needs work without making them dread opening the app?

3. **Pro vs. free affordances.**
   Pro features are: always-on Watch monitoring, AirPods background
   monitoring, 24h slouch heatmap (`PassiveTimelineView`), before/after
   photos (planned, not yet built), unlimited history (free is 7 days,
   per paywall copy — but the current `HistoryView` queries 30 days
   for everyone).
   Question: should free users see Pro features locked-with-a-preview
   in History/Today, or hidden entirely? Currently mixed.

4. **Calibration intensity.**
   Current calibration is a single 5-second baseline capture. Question:
   does it earn its own brand moment (animated guide, custom
   illustration) or stay utility-style?

5. **Camera framing.**
   Quick scan + calibration both show a small 3:4 camera preview with a
   gradient border. iPhone is held in portrait. The user's face appears
   small. Should the camera be full-bleed during scan to feel less
   utilitarian, or stay inset?

6. **Brand voice in copy.**
   Reminders rotate: "Time to check your posture. Quick scan or tap to
   acknowledge." / "Sit up straight — how's your alignment?" / "Heads
   up — check your posture." Tone varies from clinical to chummy.
   Recommend a single voice direction Engineering can apply across all
   copy in this pass.

7. **App icon implications.**
   We're not redesigning the icon in this pass, but if your direction
   diverges sharply from the current `figure.stand`-on-gradient
   identity, flag it so we can plan a separate icon pass before ship.

8. **Empty-state philosophy.**
   When a user has zero check-ins, History is mostly blank. TodayView
   shows the response-rate card with 0/0. Two philosophies — illustrate
   the future ("you'll see your progress here") or hide the surface
   until there's data. Pick one and apply consistently.

9. **AirPods background monitoring's audio-indicator UX.**
   When AirPods background is on, iOS shows an orange audio indicator
   in the Dynamic Island because we play silent audio to keep CoreMotion
   alive. Currently we just tell the user "this is expected." Is there
   a Design treatment that makes this feel intentional rather than a
   hack? (Engineering will likely cut this feature — see audit P0-3 —
   but if it stays, this is a major UX surface.)

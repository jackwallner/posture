# Posture — App Store Screenshots Handoff

## Goal

6 App Store screenshots (en-US) that convert searchers into installs by showing the core loop in 2 seconds. These reinforce the keyword strategy: **posture reminder**, **daily health**, **habit coach**, **body scan**, **back care**.

## Keyword-to-screenshot copy mapping

| Screenshot # | Hook | Keywords to weave into overlay text |
|---|---|---|
| 1 (Hero) | "Your daily posture reminder" | posture reminder, habit |
| 2 | "3-second AirPods scan" | scan, airpods, body |
| 3 | "Gentle slouch alerts at your desk" | back, desk, care |
| 4 | "Apple Watch companion" | watch, tracker |
| 5 | "Streaks & widgets" | widget, health |
| 6 | "Track your progress" | health, wellness, body |

## Screenshot 1 — Hero (TodayView)
**Source screen:** TodayView with streak data, active reminders, "Check in now" CTA visible.
**Composition:** iPhone frame showing TodayView with a healthy streak flame, reminder status card, and the big "Check in now" gradient button as the hero element. Overlay on top or bottom: *"Your daily posture reminder. 3 seconds. Every day."*
**Visual notes:**
- This is the search-result first impression — make it immediately clear this is a **posture app that builds a habit**, not a medical tool
- The streak flame should be visible but not overwhelming
- Keep overlay text ≤ 8 words, sans-serif, bold + thin weight

## Screenshot 2 — AirPods Scan (AcknowledgmentView scanning)
**Source screen:** AcknowledgmentView in scanning state with AirPods quality pill indicator visible.
**Composition:** iPhone showing the check-in screen during an active scan. The quality indicator pill (Good / Watch your posture / Sit up) should be visible. AirPods iconography present. Overlay: *"3-second check with your AirPods."*
**Visual notes:**
- This is the key differentiator vs camera-only posture apps
- Show the result feedback (green/yellow/red quality indicator)
- Should convey speed (3 seconds) and ease

## Screenshot 3 — Slouch Alert (TodayView or notification context)
**Source screen:** TodayView with "Check in now" CTA, or a notification banner mockup.
**Composition:** iPhone showing a notification or TodayView context that communicates passive monitoring. Could show phone on a desk + alert graphic. Overlay: *"Gentle reminders while you work. Back to good."*
**Visual notes:**
- Communicate the passive/background coaching feature
- Should feel gentle, not nagging
- Desk/office context to reinforce the "desk" indexed term

## Screenshot 4 — Apple Watch (if Watch app ships in v1)
**Source screen:** Apple Watch companion app screen + iPhone pairing.
**Composition:** Split frame — Apple Watch on left/right showing coaching screen, iPhone on the other side showing TodayView. Overlay: *"Posture tracking on Apple Watch."* If no Watch app in v1, skip this and replace with History screenshot showing trend data.
**Visual notes:**
- Only include if Watch app ships
- Shows the Apple ecosystem integration

## Screenshot 5 — Streaks & Widgets (Home Screen)
**Source screen:** iPhone home screen with Posture widget visible, plus TodayView with streak.
**Composition:** Split screen — left side showing the widget on a styled home screen, right side showing TodayView streak. Overlay: *"Today's streak. Tomorrow's habit."*
**Visual notes:**
- Reinforce the habit/streak positioning from keyword strategy
- Widget shows glanceable posture data
- Should feel aspirational ("look at my streak")

## Screenshot 6 — History (Progress tracking)
**Source screen:** HistoryView with weekly trend chart or heatmap.
**Composition:** iPhone showing the History tab with quality-over-time chart or weekly heatmap. Overlay: *"Your posture. Your progress. Your health."*
**Visual notes:**
- Shows the long-term value proposition
- Weekly trend line or heatmap visualization
- Communicates "this app has ongoing value"

## Visual direction (do this)

- **Device frame:** iPhone 17 Pro form factor, rounded corners, silver/black bezel
- **Background:** Clean light background or brand gradient — one treatment, consistent across all 6
- **Overlay text:** Sans-serif SF Pro or similar — bold weight on first line, lighter/thinner on second line. No more than 2 lines.
- **Color palette:** Use the app's actual brand color for accents (blue gradient)
- **Screenshots should use REAL app content** — install on simulator, populate with fake data, capture ⌘S

## Visual direction (avoid this)

- ❌ Bullet list of features as overlay text (says nothing unique)
- ❌ Generic health imagery (hearts, medical crosses, anatomical diagrams)
- ❌ Before/after body comparisons (medical claim risk = App Store rejection)
- ❌ Multiple phone frames per screenshot (confusing at small sizes)
- ❌ Screenshots without device frames (looks unprofessional)

## What to deliver

For each screenshot above, Claude Design should produce:
1. **A composition spec** — what's on screen, where overlay text goes, any secondary elements
2. **A low-fi mockup** PNG (grayscale is fine — just the layout/composition)
3. **Overlay text copy** — exact text for each screenshot

**Don't waste time on:**
- Pixel-perfect renders (Claude Code will commit the actual screenshots)
- Multiple color variations (pick one direction)
- Redesigning the app UI itself (separate handoff)
- Illustrations from scratch (use existing app screens + clean overlays)

## Dependencies

Engineer needs to provide actual app screenshots first. Capture from iPhone 17 Pro simulator with fake data populated. See `docs/archive/design/2026-05/claude-design-handoff/assets/CAPTURE_INSTRUCTIONS.md` for process. Relevant screens to capture:
1. `assets/screenshot-1-hero.png` — TodayView with streak data
2. `assets/screenshot-2-scan.png` — AcknowledgmentView scanning state  
3. `assets/screenshot-3-alert.png` — TodayView with reminder active
4. `assets/screenshot-4-watch.png` — Apple Watch screen (if available) OR HistoryView
5. `assets/screenshot-5-widget.png` — Home screen with widget
6. `assets/screenshot-6-history.png` — HistoryView with chart data

# Posture App - Video Review Notes

This document contains detailed notes from the screen recording and narration provided by the user. The purpose is to guide future AI agents in fixing and refining the application based on the user's direct feedback.

## Screen-by-Screen Breakdown & Required Fixes

### 1. Initial Screen ("Stand tall every day")
- **Audio Context:** "Stand tall every day. I don't think we need Duolingo style streaks included on the customer end here."
- **Screen Action:** The user is looking at the initial start, onboarding, or paywall screen that features a "Stand tall every day" prompt and displays streak functionality.
- **Action Item:** Remove the "Duolingo-style streaks" UI/elements from this customer-facing screen.

### 2. AirPods Calibration Step
- **Audio Context:** "Calibrate with Airpods. We probably need a question of if you have Airpods."
- **Screen Action:** The app prompts the user to calibrate their posture using AirPods.
- **Action Item:** Before initiating the AirPods calibration flow, add a preliminary question asking the user if they actually have AirPods. The app should not assume the user has them.

### 3. Camera / Tracking Status
- **Audio Context:** "Here's me. Tells me I'm not tracking. We probably need to have it learn if I'm upright and not have it tell me."
- **Screen Action:** The user's face is visible in the camera preview, and the app displays a "not tracking" status or warning message.
- **Action Item:** Improve the tracking UX. Instead of bluntly telling the user they are "not tracking," the app should be smarter and attempt to learn/calibrate when the user is upright automatically, making the process seamless rather than error-driven.

### 4. Calibration Instructions ("Hold still" and "Now slouch")
- **Audio Context:** "Hold still for what? ... Now slouch. I don't know if this is helpful. It doesn't seem to make any sense of doing anything."
- **Screen Action:** The app instructs the user to "Hold still", and subsequently instructs them to "Now slouch" as part of the calibration process.
- **Action Items:** 
  - **Contextualize Instructions:** Clarify the "Hold still" instruction by explaining *why* they need to hold still (e.g., "Hold still to set your baseline posture").
  - **Rethink 'Slouch' Step:** Re-evaluate or remove the "Now slouch" calibration step. The user finds it confusing, unhelpful, and it does not seem to add obvious value to the calibration experience.

---

## Overall Vibe & Strategic Direction for Fixes

- **Reduce Assumptions:** The app currently assumes the user has specific hardware (AirPods) and understands the app's internal mechanics. We need to introduce gentle, explicit onboarding questions (like checking for AirPods) before forcing users into hardware-dependent flows.
- **Smarter, Less Punitive Tracking:** The app's feedback (e.g., flashing "not tracking") feels frustrating. The app should work seamlessly in the background to learn the user's good posture rather than constantly throwing errors or scolding the user when tracking is lost.
- **Clarity and Purpose in Calibration:** The calibration flow lacks context. Users need to understand the *purpose* behind the actions they are asked to perform. If a step (like slouching intentionally) feels pointless or confusing, it creates friction and should be removed or completely redesigned.
- **Streamline the UI:** Remove unnecessary gamification elements (like the streak counters on the intro screens) that distract from the core value proposition. Keep the initial user experience focused entirely on simple, intuitive posture correction.

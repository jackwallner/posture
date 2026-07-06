# Phase C — guided chin-tuck reps, achievements, History trends (Pro)

**For:** a new agent picking up implementation in `/Users/jackwallner/posture`  
**Source thread:** Claude Code practice-pivot session (2026-07-05). Canonical parent plan: `~/.claude/plans/breezy-mixing-mccarthy.md`  
**Product memory:** `~/.claude/projects/-Users-jackwallner-posture/memory/continuous-monitoring-primary.md`

---

## Where we are

| Phase | Status | Commit / build |
|-------|--------|----------------|
| **A** — daily practice core loop | **Shipped** | `fb757d8` |
| **B** — walk mode (Pro) | **Shipped** | `29073cb`, TestFlight build **57** |
| **C** — this doc | **Not started** | — |

Phase C is the last planned slice of the **daily practice pivot**. It does **not** revisit the old monitoring-first / hard-paywall direction. Do not re-hero always-on monitoring or add a hard entry gate.

---

## Product context (read before coding)

The app’s core loop is a **bounded daily AirPods practice session**:

- Duration and aligned-% target auto-ramp via `PracticeProgression` (3 min → 15 min cap; 50% → 80% target).
- **Streak** = completed the session duration (`PostureSession.completed`).
- **Level** = met the aligned-% target (`PostureSession.passed`); only `.practice` rows count.
- **Walk mode** (Pro): 10/20/30 min, walk-tuned scoring, streak yes / level no.
- **Free tier** caps at level 5; Pro unlocks full ladder, walk mode, all-day monitoring, Watch.
- Paywall is **soft**: once after first completed session (`posture_post_first_session`), plus feature gates (`posture_walk_gate`, `posture_level_gate`).

Evidence rationale for Phase C: RCTs and reviews support **active deep-cervical-flexor training** (chin tucks) plus biofeedback — not passive all-day awareness. Chin-tuck reps at session start make the practice clinically grounded without rebuilding a camera pipeline.

---

## Phase C scope (three deliverables)

From the parent plan § “Phase C — guided reps + polish”:

1. **Chin-tuck guided reps** at the start of each **practice** session (not walks).
2. **Achievements** — display-only badges derived from existing data (streak milestones, levels, session counts). No new persistence model.
3. **History trends Pro-gating** — ship the “trends” benefit promised on the paywall (`posture_trends_gate`), plus remove legacy `TrainingTour` in favor of replaying in-session coach marks.

**One shippable TestFlight build** when all three are done, tested, committed, and uploaded via `./scripts/testflight.sh`.

---

## C1. Chin-tuck guided reps

### User experience

Before the timed practice hold begins, the user completes **N guided chin-tuck reps** (~5–8 reps, ~30–45 seconds total):

1. Pre-start screen adds a step: **“Warm up your neck”** → **Rep phase** → existing timed hold.
2. On-screen cue: *“Gently draw your chin back — like a small double chin — then return to level.”* Reuse `PoseDiagram` / copy tone from `CalibrationView` and `PostureTipService` (chin-tuck tip already exists).
3. Live feedback: ring or simple progress (`3 of 5`) counts **completed cycles**, not elapsed time.
4. Optional light haptic on each counted rep.
5. After `repsTarget` reps → transition to the existing live hold (`phase` goes from rep warmup → running). Walk sessions **skip** reps entirely.

First-time users who already see in-session coach marks (`hasSeenSessionCoachMarks`) still do reps every session — reps are training, not onboarding.

### Scoring / detection (pure, testable)

Add to `Shared/Services/PostureScoring.swift`:

```swift
enum ChinTuck {
    static let minExcursionRadians: Double = 0.08   // ~4.5° — tune on device
    static let returnToleranceRadians: Double = 0.04  // near baseline counts as “returned”
    static let minRepDurationSeconds: Double = 0.8
    static let maxRepDurationSeconds: Double = 6.0
    static let defaultRepsTarget: Int = 5
}

/// Stateful cycle detector — feed (t, pitch, baseline) each sample.
/// Returns newly completed rep count delta (0 or 1 per call).
struct ChinTuckRepDetector: Sendable { ... }
```

**Algorithm (pitch excursion cycle):**

- Baseline = standing AirPods pitch from calibration (`calibration.airpodsStandingPitch ?? combined`).
- **Retraction** = pitch moves **away** from slouch direction (opposite of forward head in calibration slouch capture — verify sign against real AirPods data in simulator/device).
- State machine: `neutral → retracting → returned` = **1 rep**.
- Ignore cycles shorter than `minRepDurationSeconds` or longer than `maxRepDurationSeconds` (fidgeting vs stuck).
- Use smoothed pitch (same α as practice, 0.15) before measuring excursion.

**Tests:** `PostureTests/ChinTuckRepDetectorTests.swift` — synthetic pitch streams: clean rep, partial rep, slouch-without-return, noise.

### Controller integration

Extend `PracticeSessionController`:

| Change | Detail |
|--------|--------|
| `Config` | Add `repsTarget: Int` (0 = skip; practice default 5; walk always 0). |
| `Phase` | Add `reps` between `waiting` and `running` for `.practice` when `repsTarget > 0`. |
| Observable | `repsCompleted: Int`, `repsTarget: Int` for UI. |
| `start(config:)` | If `repsTarget > 0` && kind == `.practice` → `phase = .reps`; else existing `waiting`. |
| Sample ingest | In `.reps`, run `ChinTuckRepDetector`; on `repsCompleted >= repsTarget` → `phase = .running` (or `waiting` until first scored sample — match existing handoff). |
| Elapsed / scoring | **Do not** accrue practice seconds or timeline segments during `.reps`. Minute buckets flush only after reps complete. |

Keep the seam clean so walk and future session kinds stay unaffected.

### UI

`Posture/Views/PracticeSessionView.swift`:

- New `repsView(controller)` branch in `content(_:)` when `phase == .reps`.
- Reuse ring styling (`PostureRing` / `HorizonMeter`) tinted for “warm-up” (lavender/sand).
- Show `repsCompleted/repsTarget` and the cue copy.
- Pre-start CTA: “Start practice” begins reps first, not the timer.

Optional v1 simplification if detection is flaky on device: **manual tap-to-advance** fallback button (“Done with this rep”) hidden behind `#if DEBUG` only — do **not** ship manual counting to production unless Jack explicitly asks.

---

## C2. Achievements (display-only)

### Principles

- **No new SwiftData models.** Derive everything at read time from `StreakState`, `PostureSession`, and `AcknowledgmentRecord`.
- **No gameplay mechanics** — badges celebrate existing behavior; they don’t unlock features.
- Daylight design: rounded SF, sage/sand/clay chips, no serif italics (`Theme.display(_:)` only).

### New pure module

`Shared/Services/AchievementCatalog.swift`:

```swift
struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isEarned: Bool
    let earnedAt: Date?  // nil if not earned
}

enum AchievementCatalog {
  nonisolated static func all(
    streak: StreakState?,
    sessions: [PostureSession],
    at date: Date = .now
  ) -> [Achievement]
}
```

### Suggested badge set (implement all)

| ID | Earned when | Icon |
|----|-------------|------|
| `first_practice` | ≥1 `.practice` row with `completed` | `figure.stand` |
| `first_pass` | ≥1 `.practice` row with `passed` | `checkmark.seal` |
| `level_5` | `PracticeProgression.level(passed) >= 5` | `chevron.up.2` |
| `level_10` | level ≥ 10 | `chevron.up.2` |
| `streak_7` | `StreakService.displayStreak >= 7` (or hit 7 historically via `longestStreak`) | `flame` |
| `streak_30` | longest or current ≥ 30 | `flame.fill` |
| `streak_100` | longest ≥ 100 | `flame.circle` |
| `first_walk` | ≥1 `.walk` row with `completed` | `figure.walk` |
| `walk_10` | ≥10 completed walk rows | `figure.walk.motion` |
| `freeze_saved` | user has ever had `freezesAvailable > 0` after a miss — **or** simply earned a milestone freeze (check `currentStreak` in `streakMilestoneDays`) | `snowflake` |

Use `StreakService.streakMilestoneDays` (`7, 14, 30, 60, 100`) — surface 14 and 60 as badges too for parity with freeze awards.

`earnedAt`: use earliest qualifying session `startedAt`, or `streakState.lastActiveDay` for streak badges (best-effort; exact timestamp not critical).

### UI surfaces

1. **`Posture/Views/AchievementsView.swift`** — grid of badges (earned full color, locked grayed `Theme.paper3`).
2. **Today** — compact row under the streak header: “Next up: 7-day streak” or latest earned badge. Tap → `AchievementsView` sheet.
3. **SessionSummaryView** — if session completion newly earns a badge, show a small celebration line (“New: 7-day streak”).

### Tests

`PostureTests/AchievementCatalogTests.swift` — fixture sessions/streak → expected earned IDs.

---

## C3. History trends Pro-gating + TrainingTour cleanup

### Trends (Pro)

Paywall already promises: *“Trends and your day scored, hour by hour”* (`PaywallView.compactFeatureList`). `HistoryView` today shows a **free** 7-day wear/alignment chart from `PostureMinuteSample` — Phase C **gates the rich trends**, not the empty state.

**Free users see:**

- Last 7 days headline + **blurred or stubbed** chart (show silhouettes, no percentages).
- One visible day (today or best day) as a teaser.
- CTA card: “See your full trends with Posture+” → `PaywallView(paywallImpressionId: "posture_trends_gate")`.

**Pro users see:**

- Full 7-day chart (existing `weekChart`).
- **14-day** aligned % trend line or second row of columns.
- Week-over-week delta (existing `deltaVsLastWeek` — currently shown to everyone; move behind Pro).
- **Hour-of-day rhythm** — reuse `PostureDayStats` / minute samples aggregated by hour (pattern exists on Today’s day report). Show top 3 “strong hours” / “slouch hours”.

Implementation sketch:

- Extract chart + rhythm into `HistoryTrendsSection(isPro:bindings...)`.
- `@State private var showingTrendsPaywall = false` + sheet with `posture_trends_gate`.
- Do not break check-in-only users: journal feed stays free.

### TrainingTour removal

`TrainingTour` is **legacy** (monitoring-first). Auto-start is already gone; Settings still replays it.

| File | Action |
|------|--------|
| `Posture/Views/TodayView.swift` | Remove `trainingTourOverlay`, `tourSteps`, `tourIndex`, `tourActive`, `hasSeenTrainingTour` onFinish, `.onReceive(.postureReplayTrainingTour)` |
| `Posture/Views/SettingsView.swift` | Change “Replay the Walkthrough” → **“Replay practice coach marks”** — sets `hasSeenSessionCoachMarks = false` and opens `PracticeSessionView` (or posts a new notification `.postureReplaySessionCoachMarks` that PracticeSessionView listens for) |
| `Posture/Views/Components/TrainingTour.swift` | **Delete** if no references remain |
| `Shared/Services/GoalSettings.swift` | Keep `hasSeenTrainingTour` key for migration but stop writing it; optional deprecation comment |
| `Shared/Services/ReminderScheduler.swift` | Remove `.postureReplayTrainingTour` if unused |
| `Posture/App.swift` | Remove any `.postureReplayTrainingTour` handler |
| `CLAUDE.md` | Remove `TrainingTour` from architecture list |

Coach marks live in `PracticeSessionView` (`CoachStep`: ring → slouch → hold). Replaying = reset `hasSeenSessionCoachMarks` and launch a session.

---

## Files to create / modify (checklist)

### New files

- `Shared/Services/PostureScoring.swift` — `ChinTuck` + `ChinTuckRepDetector`
- `PostureTests/ChinTuckRepDetectorTests.swift`
- `Shared/Services/AchievementCatalog.swift`
- `PostureTests/AchievementCatalogTests.swift`
- `Posture/Views/AchievementsView.swift`
- `Posture/Views/Components/HistoryTrendsSection.swift` (optional extract)

### Modify

- `Shared/Services/PracticeSessionController.swift` — reps phase + `Config.repsTarget`
- `Posture/Views/PracticeSessionView.swift` — reps UI
- `Posture/Views/SessionSummaryView.swift` — achievement unlock line
- `Posture/Views/TodayView.swift` — achievements entry, remove TrainingTour
- `Posture/Views/HistoryView.swift` — Pro gate + hour rhythm
- `Posture/Views/SettingsView.swift` — replay coach marks
- `CLAUDE.md` — document reps + achievements; remove TrainingTour

After adding/removing Swift files: `xcodegen generate`

---

## Architecture constraints

- **Swift 6 / strict concurrency:** new UI types `@MainActor`; pure logic `nonisolated static` / `Sendable` structs (mirror `PracticeProgression`, `PostureScoring`).
- **No camera / Vision work.**
- **RevenueCat:** keep entitlement id `pro`; don’t rename UserDefaults keys.
- **Widgets:** if you touch `PostureSession` fields, update widget schemas in the same commit (`PostureWidget`, `PostureWatchWidget` mirror `DataService`).
- **Analytics:** add events only if useful — e.g. `chin_tuck_reps_completed`, `achievement_unlocked(id)`, `paywall_impression` already handles gates.

---

## Verify + ship

```bash
xcodegen generate
UDID=$(agent-sim boot posture)
xcodebuild -project Posture.xcodeproj -scheme Posture -destination "id=$UDID" build
xcodebuild test -project Posture.xcodeproj -scheme Posture -destination "id=$UDID"
```

### Unit tests (required)

- `ChinTuckRepDetectorTests` — rep counting edge cases
- `AchievementCatalogTests` — earned vs locked
- Existing `PracticeSessionControllerTests`, `PostureScoringWalkTests`, `PracticeProgressionTests` must stay green

### Manual / headless UI

1. Onboard → calibrate → start practice → complete 5 chin-tuck reps → timed hold → summary.
2. Settings → replay coach marks → confirm three coach steps appear (not TrainingTour spotlight).
3. Free user (`-PostureProOverride` off): History shows trends teaser → `posture_trends_gate` paywall.
4. Pro override: full 14-day + hour rhythm visible.
5. Complete first walk → `first_walk` badge appears.

### Ship

```bash
git commit -m "feat(posture): Phase C — chin-tuck reps, achievements, trends gate"
./scripts/testflight.sh
```

Update `~/.claude/projects/-Users-jackwallner-posture/memory/continuous-monitoring-primary.md`: mark Phase C shipped, remove “Remaining: Phase C…”.

---

## Explicit non-goals (do not expand scope)

- Stationary/gait detection for walks (deferred from Phase B).
- Camera-based rep detection.
- New subscription SKUs or hard paywall.
- Persisting achievements in SwiftData (display-only derivation).
- Astro / App Store metadata (separate workflow — see `docs/astro-aso-setup.md`).
- ASO “go refine” (that’s a different “phase” in the Astro docs — not this product phase).

---

## Reference map

| Topic | Location |
|-------|----------|
| Parent plan | `~/.claude/plans/breezy-mixing-mccarthy.md` |
| Phase A commit | `fb757d8` |
| Phase B commit | `29073cb` |
| Level math | `Shared/Services/PracticeProgression.swift` |
| Session engine | `Shared/Services/PracticeSessionController.swift` |
| Walk scoring pattern | `PostureScoring.Walk` + `PostureScoringWalkTests.swift` |
| Coach marks | `Posture/Views/PracticeSessionView.swift` (`CoachStep`) |
| Streak milestones | `StreakService.streakMilestoneDays` |
| Paywall gates | `posture_walk_gate`, `posture_level_gate`, add `posture_trends_gate` |
| Simulator | `agent-sim boot posture` (headless — never open Simulator.app) |

---

## Agent handoff prompt

Copy into a fresh session:

> Implement **Phase C** per `/Users/jackwallner/posture/phasec.md`. Phase A and B are shipped on `main`. Build chin-tuck guided reps at practice session start, display-only achievements, History trends Pro-gating with `posture_trends_gate`, and remove TrainingTour in favor of replaying in-session coach marks. Tests green, then commit and `./scripts/testflight.sh`.

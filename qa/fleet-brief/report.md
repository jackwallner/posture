# Release gate: posture-ship 48567b7b0958

Verdict: **BLOCK** (2026-11-01T09:39:18+00:00)

Every finding blocks except legacy backlog. `qa-gate fix <repo>` fixes them. Motion candidates need a judgement in the ledger: `qa-gate ledger <repo> accept` for an intended change, or `add` a P1 when it is a real glitch.

## Blocking (5)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P0 | journey-broken | newcomer | testCoreLoopCheckInCountsAndSurvivesRelaunch /  | XCTAssertTrue failed - second result did not name the quality that was logged | `journey-broken|testCoreLoopCheckInCountsAndSurvivesRelaunch` |
| P0 | journey-broken | accessibility | testCoreLoopCheckInCountsAndSurvivesRelaunch /  | XCTAssertTrue failed - second result did not name the quality that was logged | `journey-broken|testCoreLoopCheckInCountsAndSurvivesRelaunch` |
| P0 | journey-broken | reduce-motion | testCoreLoopCheckInCountsAndSurvivesRelaunch /  | XCTAssertTrue failed - second result did not name the quality that was logged | `journey-broken|testCoreLoopCheckInCountsAndSurvivesRelaunch` |
| P0 | journey-broken | duo | testCoreLoopCheckInCountsAndSurvivesRelaunch /  | XCTAssertTrue failed - second result did not name the quality that was logged | `journey-broken|testCoreLoopCheckInCountsAndSurvivesRelaunch` |
| P3 | a11y-element-description | accessibility,duo,newcomer,reduce-motion | testCoreLoopCheckInCountsAndSurvivesRelaunch / check-in-result-aligned | Label not human-readable: "Aligned." | `a11y-element-description|testCoreLoopCheckInCountsAndSurvivesRelaunch|check-in-result-aligned|aligned.` |

## Needs a judgement (1)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P1 | motion-jump | newcomer | test03PosturePlusPaywallTab / today-after-paywall | jump candidate at 144.66s of journeys.mp4 (score 0.158) | `motion-jump|test03PosturePlusPaywallTab|today-after-paywall|` |

## Legacy backlog, warns until fixed (29)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P2 | a11y-contrast |  | test01OnboardingToTrialAndToday / welcome | Contrast failed (measured 1.8:1): "1" | `a11y-contrast|test01OnboardingToTrialAndToday|welcome|#` |
| P2 | a11y-contrast |  | test03PosturePlusPaywallTab / posture-plus-paywall | Contrast failed (measured 1.2:1): " " | `a11y-contrast|test03PosturePlusPaywallTab|posture-plus-paywall|` |
| P2 | a11y-contrast |  | test03PosturePlusPaywallTab / posture-plus-paywall | Contrast failed (measured 1.7:1): "SAVE 33%" | `a11y-contrast|test03PosturePlusPaywallTab|posture-plus-paywall|save #%` |
| P2 | a11y-hit-region |  | test02EveryTabOnSeededData / progress | Hit area is too small: "1 of 4 passed sessions toward the next level" | `a11y-hit-region|test02EveryTabOnSeededData|progress|# of # passed sessions toward the next level` |
| P2 | a11y-hit-region |  | test02EveryTabOnSeededData / progress | Hit area is too small: "Choose posture program" | `a11y-hit-region|test02EveryTabOnSeededData|progress|choose posture program` |
| P2 | a11y-hit-region |  | test03PosturePlusPaywallTab / posture-plus-paywall | Hit area is too small: "Privacy Policy" | `a11y-hit-region|test03PosturePlusPaywallTab|posture-plus-paywall|privacy policy` |
| P2 | a11y-hit-region |  | test03PosturePlusPaywallTab / posture-plus-paywall | Hit area is too small: "Restore Purchases" | `a11y-hit-region|test03PosturePlusPaywallTab|posture-plus-paywall|restore purchases` |
| P2 | a11y-hit-region |  | test03PosturePlusPaywallTab / posture-plus-paywall | Hit area is too small: "Terms of Use" | `a11y-hit-region|test03PosturePlusPaywallTab|posture-plus-paywall|terms of use` |
| P2 | a11y-hit-region |  | test03PosturePlusPaywallTab / today-after-paywall | Hit area is too small: "Choose posture to train" | `a11y-hit-region|test03PosturePlusPaywallTab|today-after-paywall|choose posture to train` |
| P2 | a11y-hit-region |  | test03PosturePlusPaywallTab / today-after-paywall | Hit area is too small: "Level 2 · full program with Posture+" | `a11y-hit-region|test03PosturePlusPaywallTab|today-after-paywall|level # · full program with posture+` |
| P2 | a11y-hit-region |  | test04ReturnVisitWithInterruption / progress-after-interruption | Hit area is too small: "1 of 4 passed sessions toward the next level" | `a11y-hit-region|test04ReturnVisitWithInterruption|progress-after-interruption|# of # passed sessions toward the next level` |
| P2 | a11y-hit-region |  | test04ReturnVisitWithInterruption / progress-after-interruption | Hit area is too small: "Choose posture program" | `a11y-hit-region|test04ReturnVisitWithInterruption|progress-after-interruption|choose posture program` |
| P2 | a11y-hit-region |  | test04ReturnVisitWithInterruption / progress-before-interruption | Hit area is too small: "1 of 4 passed sessions toward the next level" | `a11y-hit-region|test04ReturnVisitWithInterruption|progress-before-interruption|# of # passed sessions toward the next level` |
| P2 | a11y-hit-region |  | test04ReturnVisitWithInterruption / progress-before-interruption | Hit area is too small: "Choose posture program" | `a11y-hit-region|test04ReturnVisitWithInterruption|progress-before-interruption|choose posture program` |
| P2 | a11y-hit-region |  | test04ReturnVisitWithInterruption / today-after-relaunch | Hit area is too small: "Choose posture to train" | `a11y-hit-region|test04ReturnVisitWithInterruption|today-after-relaunch|choose posture to train` |
| P2 | clipped |  | test03PosturePlusPaywallTab / posture-plus-paywall | text "On-device" is broken across 3 lines: On / de / V... (AX3 text only) | `clipped|test03PosturePlusPaywallTab|posture-plus-paywall|on-device` |
| P2 | overlap |  | test03PosturePlusPaywallTab / posture-plus-paywall | button "Start Posture+" overlaps "chart.bar.fill" by 67% (AX3 text only) | `overlap|test03PosturePlusPaywallTab|posture-plus-paywall|start posture+ / chart.bar.fill` |
| P2 | overlap |  | test03PosturePlusPaywallTab / posture-plus-paywall | button "Start Posture+" overlaps "chart.line.uptrend.xyaxis" by 67% (AX3 text only) | `overlap|test03PosturePlusPaywallTab|posture-plus-paywall|start posture+ / chart.line.uptrend.xyaxis` |
| P2 | overlap |  | test03PosturePlusPaywallTab / posture-plus-paywall | button "Start Posture+" overlaps "gearshape.fill" by 67% (AX3 text only) | `overlap|test03PosturePlusPaywallTab|posture-plus-paywall|start posture+ / gearshape.fill` |
| P2 | overlap |  | test03PosturePlusPaywallTab / posture-plus-paywall | button "Start Posture+" overlaps "leaf.fill" by 67% (AX3 text only) | `overlap|test03PosturePlusPaywallTab|posture-plus-paywall|start posture+ / leaf.fill` |
| P2 | reduce-motion-ignored |  | all / all | with Reduce Motion on the journeys still moved for 47.3s against 52.4s without it (90%); check which animations ignore it | `reduce-motion-ignored|all|all|` |
| P2 | truncated |  | test01OnboardingToTrialAndToday / airpods-calibration | text drawn as "Pop in yo..." but reads "Pop in your AirPods." (AX3 text only) | `truncated|test01OnboardingToTrialAndToday|airpods-calibration|pop in your airpods.` |
| P2 | truncated |  | test01OnboardingToTrialAndToday / airpods-calibration | text drawn as "your AirPods to rea..." but reads "We use the head-motion sensor in your AirPods to read posture. Make sure they're connected to this iPhone. iOS will ask permission to read motion." (A | `truncated|test01OnboardingToTrialAndToday|airpods-calibration|we use the head-motion sensor in your airpods to read postur` |
| P2 | truncated |  | test03PosturePlusPaywallTab / posture-plus-paywall | button drawn as "Pay once..." but reads "Lifetime, Pay once · never renews, $99.99" (AX3 text only) | `truncated|test03PosturePlusPaywallTab|posture-plus-paywall|lifetime, pay once · never renews, $#` |
| P2 | truncated |  | test03PosturePlusPaywallTab / posture-plus-paywall | text drawn as "•° Optional AirPods and..." but reads "Optional AirPods and Watch nudges beyond practice" (AX3 text only) | `truncated|test03PosturePlusPaywallTab|posture-plus-paywall|optional airpods and watch nudges beyond practice` |
| P2 | truncated |  | test03PosturePlusPaywallTab / posture-plus-paywall | text drawn as "def..." but reads "Private by default" (AX3 text only) | `truncated|test03PosturePlusPaywallTab|posture-plus-paywall|private by default` |
| P2 | truncated |  | test03PosturePlusPaywallTab / posture-plus-paywall | text drawn as "* Weekly trends, walk m..." but reads "Weekly trends, walk mode, and hour-by-hour patterns" (AX3 text only) | `truncated|test03PosturePlusPaywallTab|posture-plus-paywall|weekly trends, walk mode, and hour-by-hour patterns` |
| P2 | truncated |  | test03PosturePlusPaywallTab / posture-plus-paywall | button drawn as "Ye..." but reads "Yearly, SAVE 33%, $79.99 / year, $1.54 / week" (AX3 text only) | `truncated|test03PosturePlusPaywallTab|posture-plus-paywall|yearly, save #%, $# / year, $# / week` |
| P3 | a11y-audit |  | test02EveryTabOnSeededData / today | audit could not run: Invalid target app 71221 | `a11y-audit|test02EveryTabOnSeededData|today|` |

## Journeys

| Persona | Journey | Result | Seconds |
|---|---|---|---|
| newcomer | test01OnboardingToTrialAndToday | Passed | 70.51656401157379 |
| newcomer | test02EveryTabOnSeededData | Passed | 40.26245701313019 |
| newcomer | test03PosturePlusPaywallTab | Passed | 22.228358030319214 |
| newcomer | test04ReturnVisitWithInterruption | Passed | 35.73413300514221 |
| newcomer | testCoreLoopCheckInCountsAndSurvivesRelaunch | Failed | 78.62347197532654 |
| accessibility | test01OnboardingToTrialAndToday | Passed | 62.177722096443176 |
| accessibility | test02EveryTabOnSeededData | Passed | 33.49262809753418 |
| accessibility | test03PosturePlusPaywallTab | Passed | 21.618310928344727 |
| accessibility | test04ReturnVisitWithInterruption | Passed | 35.007405042648315 |
| accessibility | testCoreLoopCheckInCountsAndSurvivesRelaunch | Failed | 81.82051301002502 |
| reduce-motion | test01OnboardingToTrialAndToday | Passed | 63.214223980903625 |
| reduce-motion | test02EveryTabOnSeededData | Passed | 39.27242600917816 |
| reduce-motion | test03PosturePlusPaywallTab | Passed | 20.54907202720642 |
| reduce-motion | test04ReturnVisitWithInterruption | Passed | 36.90741801261902 |
| reduce-motion | testCoreLoopCheckInCountsAndSurvivesRelaunch | Failed | 81.66428208351135 |
| duo | test01OnboardingToTrialAndToday | Passed | 64.22109699249268 |
| duo | test02EveryTabOnSeededData | Passed | 29.977076053619385 |
| duo | test03PosturePlusPaywallTab | Passed | 23.64662003517151 |
| duo | test04ReturnVisitWithInterruption | Passed | 41.82716202735901 |
| duo | testCoreLoopCheckInCountsAndSurvivesRelaunch | Failed | 78.95110201835632 |

## Motion

| Persona | Motion s | Windows | Candidates | Gaps > 25 ms | 60 fps |
|---|---|---|---|---|---|
| newcomer | 52.359 | 51 | 13 | 407 | True |
| accessibility | 57.855 | 53 | 13 | 446 | True |
| reduce-motion | 47.311 | 51 | 7 | 389 | True |

## Launch entrances to look at

Each launch's frames after the springboard zoom, left to right then down, 4 frames per
row at the recorded rate. A blank stretch, text that reflows, or content that arrives and
pushes the layout is a finding: `qa-gate ledger <repo> add`.

- [entrance-01-test01onboardingtotrialandtoday.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/newcomer/entrance-01-test01onboardingtotrialandtoday.png)
- [entrance-09-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/newcomer/entrance-09-launch-environment.png)
- [entrance-14-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/newcomer/entrance-14-launch-environment.png)
- [entrance-01-test01onboardingtotrialandtoday.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/accessibility/entrance-01-test01onboardingtotrialandtoday.png)
- [entrance-17-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/accessibility/entrance-17-launch-environment.png)
- [entrance-18-test04returnvisitwithinterruption.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/accessibility/entrance-18-test04returnvisitwithinterruption.png)
- [entrance-21-test04returnvisitwithinterruption.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/accessibility/entrance-21-test04returnvisitwithinterruption.png)
- [entrance-01-test01onboardingtotrialandtoday.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-01-test01onboardingtotrialandtoday.png)
- [entrance-09-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-09-launch-environment.png)
- [entrance-14-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-14-launch-environment.png)
- [entrance-17-launch-environment.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-17-launch-environment.png)
- [entrance-21-test04returnvisitwithinterruption.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-21-test04returnvisitwithinterruption.png)
- [entrance-23-testcoreloopcheckincountsandsurvivesrelaunch.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-23-testcoreloopcheckincountsandsurvivesrelaunch.png)
- [entrance-28-testcoreloopcheckincountsandsurvivesrelaunch.png](/Users/jackwallner/posture-ship/build/qa/48567b7b0958/reduce-motion/entrance-28-testcoreloopcheckincountsandsurvivesrelaunch.png)

Skipped personas: german (app not localized).

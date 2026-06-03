# Astro ASO setup — Posture Check (US)

Last optimized: **2026-05-25** · Astro temp app **Posture** (`104`) · ~85 targeted keywords

## Strategy (popularity × difficulty × fit)

| Tier | What to track | Why |
|------|----------------|-----|
| **ASC field** | Single tokens with highest search volume | Fills the 100-char keyword slot; compounds with name/subtitle |
| **Priority phrases** | `posture reminder` (pop 16, diff 23) | Best prelaunch opportunity — matches core loop |
| **Accessory head terms** | `apple watch`, `watch`, `airpods`, `reminder`, `habit`, `coach` | High pop (55–73); harder rank but essential for Watch/AirPods positioning |
| **Low-diff phrases** | `slouch`, `tech neck`, `back straight`, `align posture`, `posture scan` | pop 5–6, diff 7–19 — realistic wins for a new app |
| **Streak differentiation** | `habit tracker`, `streak tracker`, `duolingo streak`, `streak freeze` | Habit tracker pop 67; streak tracker 30 — unique vs generic posture apps |
| **Skip** | Description fragments, `chin tuck`, generic `health tracker` alone | Removed 80+ junk terms via MCP |

**Opportunity score** = `popularity ÷ difficulty` (higher is better).

## App

| Field | Value |
|-------|-------|
| ASC name | Posture Check - Active Daily |
| ASC app ID | `6768514450` |
| Astro (prelaunch) | **Posture** · `104` |
| Bundle ID | `com.jackwallner.posture` |

## ASC keyword field (updated locally)

```
slouch,habit,airpods,watch,widget,neck,back,desk,coach,ergonomics,wellness,scan,tap,align,health,wfh
```

**100 characters exactly.** Comma-separated, no spaces (Apple format).

**Do not repeat name/subtitle words** — `posture`, `reminder`, `streak`, `check`, `active`, `daily` are already indexed from:

- **Name (28/30):** `Posture Check - Active Daily`
- **Subtitle (29/30):** `Posture reminders and streaks`

Putting those again in the keyword field wastes slots.

Upload when ready:

```bash
./scripts/upload-appstore-metadata.sh
```

File: `fastlane/metadata/en-US/keywords.txt`

## Top keywords to optimize first

| Pop | Diff | Keyword | Notes |
|-----|------|---------|--------|
| 16 | 23 | **posture reminder** | #1 priority — subtitle + screenshots |
| 67 | 68 | habit tracker | Streak/habit angle |
| 66 | 64 | watch | Pair with Apple Watch creative |
| 58 | 73 | airpods | Pro differentiator |
| 57 | 77 | reminder | Core mechanic |
| 30 | 60 | streak tracker | Duolingo-style positioning |
| 6 | 13 | posture scan | QuickScan feature |
| 5 | 7 | tech neck | Low difficulty phrase |
| 5 | 9 | slouch / slouch alert | Brand-adjacent |
| 5 | 17 | back straight | Added after probe — strong opp |

## Tracked list

Canonical: `scripts/astro-keywords-us.json` (~72 terms)  
Report: `scripts/astro-keyword-report.json`

## Iterate

```bash
# Re-score tracked keywords, remove junk, add seeds
PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --analyze
PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --apply --remove-junk

# Re-sync curated file only
./scripts/sync-astro-keywords.sh
```

## After App Store launch

1. Add **Posture Check - Active Daily** in Astro by ID `6768514450`
2. Re-run optimizer + `./scripts/astro-setup.sh --skip-pull`
3. Retire temp **Posture** entry
4. Watch rankings for **posture reminder** and **habit tracker** first

## Name & subtitle (should optimize — not auto-changed)

Apple limits: **name 30**, **subtitle 30**, **keywords 100** (comma-separated).

| Field | Current | Chars |
|-------|---------|-------|
| Name | Posture Check - Active Daily | 28/30 |
| Subtitle | Posture reminders and streaks | 29/30 |

**Recommended subtitle tests** (pick one, A/B after launch):

| Subtitle | Chars | Rationale |
|----------|-------|-----------|
| `AirPods & Watch Reminders` | 25 | High-pop accessories (58–73); clear differentiator |
| `Slouch Alerts & Streaks` | 23 | `slouch` + streak mechanic; no wasted "posture" repeat |
| `3-Sec Posture Checks` | 20 | Supports `posture scan` / QuickScan |

**Name:** current is fine (brand + "Active Daily"). Optional at 30/30: `Posture Reminder: Daily Streak` — puts **reminder** + **streak** in the indexed title.

**We optimized keywords locally; name/subtitle are still your prior ASC copy** until you edit and upload.

## MCP prompts

- "Posture US: keywords with popularity ≥ 10 and difficulty ≤ 40"
- "Compare rank changes for posture reminder vs slouch alert"
- "Search App Store for posture reminder — top 5 competitors"

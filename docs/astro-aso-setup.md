# Astro ASO setup — Posture

Last optimized: **2026-07-04** · Astro temp app **Posture** (`104`) · ASC `6768514450`

## Astro scope (normal setup — not 91 stores)

**Do not run `astro-sync-all-stores.sh` / `astro-finish-sync.py` for Posture.** Those scripts are for the one-off `~/ios/archive/aso/2026-05/astro-global-aso-go-2026.md` pipeline (Headaches ran it once). Day-to-day Astro for Jack's live apps uses:

| Pattern | Stores | How |
|---------|--------|-----|
| **Standard (Headache, Vitals, Fitness Habits, …)** | **36** tier-1 Search Ads countries | Curated keyword list + `sync-astro-keywords.sh` per store |
| **Posture (pre-launch temp app)** | **18** stores already in Astro | Same curated-list workflow; expand to 36 when swapping to live App Store ID |

Re-sync US keywords after ASC field changes:

```bash
./scripts/sync-astro-keywords.sh
```

Full re-setup (pull ASC + rebuild keyword file + push):

```bash
./scripts/astro-setup.sh
```

## Strategy (monitoring-first, v4)

Product positioning: always-on AirPods background monitoring, hard paywall after calibration.

**Name** (26/30): `Posture Check: Neck & Back`  
**Subtitle** (28/30): `Fix slouch & sit up straight`  
**ASC keyword field** (94/100):

```
corrector,reminder,spine,align,stretch,ergonomic,monitor,hunch,desk,stand,health,habit,airpods,watch
```

**Auto-indexed from name/subtitle:** `posture`, `airpods`, `coach`, `always`, `on`, `slouch`, `alerts`

**Why `monitor` replaced `text`:** ASC field pivoted from text-neck / reminder-check-in copy to always-on monitoring. Astro still tracks compound phrases (`text neck`, `posture reminder`) for rank research, but the ASC field no longer wastes chars on `text`.

## Iterate

```bash
# Re-push curated list to Astro (US)
./scripts/sync-astro-keywords.sh

# Re-score tracked keywords (if script present)
PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --analyze
```

## After App Store launch

1. Add **Posture: AirPods Posture Coach** in Astro by ID `6768514450`
2. Copy keyword sets to the standard **36-store** list (same as Headache / Total Calories)
3. Retire temp **Posture** (`104`)
4. Watch **airpods posture**, **posture monitor**, **slouch** first

## Optional: full global ASO pass

Only when explicitly asked to run `~/ios/archive/aso/2026-05/astro-global-aso-go-2026.md` **go** — optimizes all 50 ASC locales + 91 Astro Search Ads countries. Not the default workflow.

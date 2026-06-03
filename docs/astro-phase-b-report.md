# Astro Phase B report — Posture

**Date:** 2026-05-26  
**ASC draft:** `1.0` (`PREPARE_FOR_SUBMISSION`)  
**Astro app:** Posture · `appId` **104**  
**ASC app:** `6768514450` · `com.jackwallner.posture`

## Summary

| Item | Status |
|------|--------|
| ASC locales optimized | **50** (`fastlane/Deliverfile` languages) |
| Native descriptions | **50** — `scripts/aso-apply-native-locales.py` |
| Keywords/subtitles | Native per locale, deduped vs name/subtitle |
| ASC upload (API + deliver) | **Success** — see `scripts/asc-finish-missed-native.log` |
| Astro stores (91) | In progress — `scripts/astro-finish-sync.py` |
| Competitor scan | `scripts/astro-competitor-research.json` |

## Backups

| Snapshot | Path |
|----------|------|
| First pull | `fastlane/metadata.bak.20260525-190647/` |
| Pre-upload (ASO pass) | `fastlane/metadata.bak.pre-upload-20260525-190917/` |
| Pre native re-upload | `fastlane/metadata.bak.pre-upload-native-*` |

## en-US before → after

| Field | Before | After | Len |
|-------|--------|-------|-----|
| Subtitle | Posture reminders and streaks | Neck, desk & slouch coach | 29 |
| Keywords | posture,slouch,neck,back,reminder,... | back,spine,alignment,habit,airpods,watch,widget,ergonomics,sit,shoulders,office,wfh,camera,calibration,wellness,health | 90 |

Full table: `scripts/aso-native-locales-report.json`

## Native language coverage

- **Tier-1:** Full native descriptions (de, fr, es, it, pt, nl, pl, ja, ko, zh-Hans/Hant, ar, he, ru, uk, tr, sv, fi, …)
- **Nordic:** sv, da, no, fi — dedicated copy
- **Indic:** hi, ta, te, bn + shared Hindi template for gu, kn, ml, mr, or, pa, ur where noted in script
- **en-***: Shared English description

Re-apply native copy:

```bash
python3 scripts/aso-apply-native-locales.py
./scripts/asc-finish-missed.sh
```

## Astro 91 stores

- Sync script: `scripts/astro-finish-sync.py`
- Per-store JSON: `scripts/astro-keywords-by-store/<store>.json`
- Summary: `scripts/astro-keywords-by-store/_summary.json`
- Audit: `scripts/astro-store-audit.json`

After sync completes:

```bash
./scripts/astro-prune-all-stores.sh
python3 scripts/astro-tier1-second-pass.py
```

## go refine

Re-run **14 days** after metadata is live: pull → rank-based tune → prune → `./scripts/asc-finish-missed.sh`

# Localization ASO — Posture

## Backups (this run)

| Snapshot | Path |
|----------|------|
| Pre-edit pull | `fastlane/metadata.bak.20260525-190647/` |
| Post-locale-add pull | `fastlane/metadata.bak.20260525-190801/` |
| Pre-upload | `fastlane/metadata.bak.pre-upload-20260525-190917/` |

## Restore

```bash
rm -rf fastlane/metadata
cp -R fastlane/metadata.bak.pre-upload-20260525-190917 fastlane/metadata
eval "$(python3 scripts/asc-ensure-draft-version.py | grep '^export ')"
SKIP_SCREENSHOTS=true ./scripts/upload-appstore-metadata.sh
```

## ASC draft

- **Version:** `1.0` (`PREPARE_FOR_SUBMISSION`)
- **State file:** `scripts/.asc-state.json`
- **Locales on disk / ASC:** 50 (`fastlane/Deliverfile` languages)

## Astro

- **App:** Posture · MCP `appId` **104**
- **Stores:** 91 (Search Ads countries) — `scripts/astro-stores-2026.json`
- **Per-store keyword JSON:** `scripts/astro-keywords-by-store/<store>.json`
- **Summary:** `scripts/astro-keywords-by-store/_summary.json`

## Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/pull-appstore-metadata.sh` | Download + backup |
| `python3 scripts/aso-apply-locale-optimizations.py` | Native keywords/subtitles |
| `./scripts/astro-sync-all-stores.sh` | Push keywords to all Astro stores |
| `./scripts/astro-resume-sync.sh` | Resume partial sync |
| `./scripts/astro-prune-all-stores.sh` | Remove junk/wrong-language terms |
| `./scripts/asc-finish-missed.sh` | Draft version + API PATCH + deliver |

## Refine (later)

After **7–14 days** live: re-pull → `astro-optimize --all-stores` → tune fastlane from ranks → prune → `./scripts/asc-finish-missed.sh`

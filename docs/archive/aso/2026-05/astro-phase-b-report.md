# Astro Phase B report — Posture

**Date:** 2026-07-04 (closed)  
**ASC app:** `6768514450` · `com.jackwallner.posture`  
**Astro:** temp **Posture** (`104`) — swap to live ID after launch  
**TestFlight:** build **54** on `main`

## Summary

| Item | Status |
|------|--------|
| Monitoring-first app + hard paywall | **Shipped** on `main` |
| ASC metadata (48 locales) | **Uploaded** — monitoring-first copy |
| GitHub Pages | **Live** from `main` `/docs` |
| Astro US keyword tracking | **Active** — `scripts/astro-keywords-us.json` + `sync-astro-keywords.sh` |
| Astro 91-store sync | **Not required** — see `docs/astro-aso-setup.md` |

## Astro: standard setup (not 91 stores)

Jack's other apps (Headache, Total Calories, Fitness Habits, …) track **36 tier-1** Search Ads countries with a curated keyword file. Posture's temp Astro app has **18 stores** and ~500+ tracked keywords — sufficient for pre-launch rank research.

The **91-store** scripts (`astro-sync-all-stores.sh`, `astro-finish-sync.py`) belong to the optional `astro-global-aso-go-2026.md` one-shot pipeline. Do not run them unless explicitly requested.

## en-US ASC (current)

| Field | Value |
|-------|--------|
| Name | Posture Check: Neck & Back |
| Subtitle | Fix slouch & sit up straight |
| Keywords | `corrector,reminder,spine,align,stretch,ergonomic,monitor,hunch,desk,stand,health,habit,airpods,watch` |

## go refine

14+ days after monitoring-first metadata is live: re-pull ASC → tune keywords from Astro ranks → `./scripts/upload-appstore-metadata.sh`

# aso-plan.md — Posture Check ASO Plan

> Written 2026-06-25. App: **Posture Check - Active Daily** (ASC ID `6768514450`, repo `~/posture`). Methodology: `~/Desktop/aso.md`.

---

## 0. TL;DR

- **Positioning:** AirPods/head-motion posture reminders + streaks for desk workers — NOT hardware posture device (UPRIGHT GO), NOT generic habit tracker.
- **Astro blocker:** placeholder app ID `104` ranks 1000 on everything. **At launch:** `add_app(6768514450)` and migrate keywords off placeholder `104`.
- **US edit:** drop false-friend field words `text`, `scan`; add `slouch`, `hunch` (~15%).
- **Subtitle is strong** (`Neck, desk & slouch coach`) — keep this cycle.

---

## STEP 0 — Re-pull + Astro migration

1. Confirm app is live on App Store (`add_app` fails until published).
2. `mcp_astro_add_app(appStoreId="6768514450")` — delete/migrate placeholder `104`.
3. Re-add US keyword set from this plan; rankings will populate after 24–48h.

---

## 1. Competitor tiers (SERP: `posture reminder`, `airpods posture`)

| Tier | Apps |
|---|---|
| **WALL** | UPRIGHT (3.9k★ hardware), generic `habit tracker` / `fitness` heads |
| **WINNABLE PEERS** | Posture Pal (291★), Align (545★), Posture Reminder: Stand Up (242★), Align - Posture Coach + AirPods (2★), PodPosture (17★) |
| **ADJACENT** | NeckTimer, HeadUp — neck-focused |

**SERP FAIL in field:** `text` (pop 74 → messaging apps), `scan` (pop 63 → QR/body-scan apps).

---

## 2. US metadata change (staged)

**Current:**
- name: `Posture Check - Active Daily`
- subtitle: `Neck, desk & slouch coach`
- keywords: `reminder,habit,scan,health,body,back,care,spine,align,tracker,streak,airpods,watch,widget,text`

**Change to:**
- subtitle: *(unchanged)*
- keywords → `reminder,habit,health,body,back,care,spine,align,tracker,streak,airpods,watch,widget,slouch,hunch`

| OUT | IN | Why |
|---|---|---|
| scan, text | slouch, hunch | False friends; subtitle already has slouch/neck/desk |
| health | — | kept (in pool via care/body) — actually we keep health |

97/100 chars · 2 words swapped.

**Do not chase:** `habit tracker` pop 67, `widget` pop 70, `watch` pop 66 as standalone — walls at rank 1000 on placeholder; re-evaluate after real ID migration.

---

## 3. Astro state (placeholder `104`, done 2026-06-25)

**US:** 34 keywords · **global:** ~161 (non-US junk pruned). Migrate to ASC ID `6768514450` at launch.

| Tag | Keywords |
|---|---|
| `deployed` | reminder, habit, health, body, back, care, spine, align, tracker, streak, airpods, watch, widget, slouch, hunch, posture |
| `target` | posture reminder, posture check, posture tracker, airpods posture, desk posture, slouch, neck posture, text neck, improve posture |
| `wall` | habit tracker, fitness, upright, apple health |

---

## 4. Product-gated

`posture scan` / body-scan features — only index if camera scan ships prominently. AirPods motion is the moat — ensure screenshots/reviews mention AirPods.

---

## 5. Rollout

Metadata can stage now; rankings tracking starts at launch. Manual release on first App Store version.

# Astro ASO setup — Posture Check (US)

Last optimized: **2026-06-09** (v3 final) · Astro temp app **Posture** (`104`)

## Strategy (v3 — indie-winnable)

We compound name/subtitle terms with high-pop ASC field tokens. Apple indexes all three fields together, so every field token + name/subtitle word forms a searchable phrase for free.

**Name** (28/30): `Posture Check - Active Daily`
**Subtitle** (29/30): `Neck, desk & slouch coach`

**Auto-indexed (free):** `posture`, `check`, `active`, `daily`, `neck`, `desk`, `slouch`, `coach`

**ASC keyword field** (94/100):
```
reminder,habit,scan,health,body,back,care,spine,align,tracker,streak,airpods,watch,widget,text
```

(`wellness` — pop 9 / diff 72, low-volume and unwinnable — and `fit` — untracked,
no data — were dropped in favor of `align` and `text`. `streak` kept: it unlocks
streak tracker (30/60) and streak app (9/54) via the `tracker` token. Applied to
en-US, en-AU, en-CA, en-GB.)

**Why each token earns its slot:**

| Token | Pop | Diff | Standalone | Unlocked compounds |
|-------|-----|------|-----------|-------------------|
| `reminder` | 55 | 77 | ✅ High | posture reminder(16), daily reminder(9) |
| `habit` | 60 | 70 | ✅ High | habit tracker(67), habit builder(17) |
| `airpods` | 57 | 73 | ✅ High | airpods posture, airpods app(26) |
| `watch` | 66 | 64 | ✅ High | apple watch(73), watch app(44) |
| `back` | 20 | 61 | ✅ Medium | back posture, back care |
| `scan` | 63 | 88 | ✅ High | posture scan(6), body scan(8) |
| `tracker` | 52 | 81 | ✅ High | habit tracker(67), calorie tracker(74) |
| `text` | 74 | 80 | ✅ High | text neck |
| `widget` | 70 | 83 | ✅ High | posture widget |
| `health` | 68 | 74 | ✅ High | daily health(21), health check(21), health coach(6) |
| `body` | 53 | 70 | ✅ High | body scan(8), body tracker(17), body alignment(16) |
| `care` | 54 | 70 | ✅ High | back care, neck care, self care(36) |
| `wellness` | 9 | 72 | ✅ Low | wellness coach(12), wellness app(19) |
| `spine` | 17 | 19 | ✅ Low | spine health, spine alignment |
| `align` | 9 | 39 | ✅ Low | body alignment(16), align posture |

**Pop=5 keywords removed from Astro tracking:** 218 keywords pruned (slouch, tech neck, text neck, back straight, etc.). Only pop≥6 keywords tracked.

**Keywords NOT chased (and why):**
- `habit tracker` alone (pop 67, diff 68) — dominated by InnerGrow (141K reviews), but we index it via `habit` + `tracker` field tokens
- `streak` (pop 7) — dropped from field, unlocks only streak tracker(30) via `tracker` compound
- `posture` alone (pop 18, diff 42) — already in name, 232 competing apps

## Iterate

```bash
# Re-score tracked keywords
PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --analyze

# Re-sync curated keyword file
./scripts/sync-astro-keywords.sh
```

## After App Store launch

1. Add **Posture Check - Active Daily** in Astro by ID `6768514450`
2. Re-run optimizer
3. Retire temp **Posture** entry
4. Watch **posture reminder** (pop 16, diff 23) and **daily health** (pop 21, diff 57) first

#!/usr/bin/env python3
"""
Optimize Astro keyword mix for Posture (popularity / difficulty / relevance).

Usage:
  PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --analyze
  PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --apply
  PYTHONPATH=scripts python3 scripts/astro-optimize-keywords.py --apply --remove-junk
"""
from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

from astro_mcp import add_keywords, call


def mcp_call(mcp_url: str, tool: str, arguments: dict, retries: int = 3) -> Any:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            return call(mcp_url, tool, arguments, req_id=10 + attempt, timeout=240)
        except Exception as e:
            last = e
            time.sleep(2 * (attempt + 1))
    raise last  # type: ignore[misc]

DEFAULT_MCP = "http://127.0.0.1:8089/mcp"
CONFIG_PATH = Path("scripts/.astro-app.json")
OUT_PATH = Path("scripts/astro-keywords-us.json")

# Real App Store searches for this app (agent + competitor research)
# Always track — product fit or proven pop/diff from Astro data
MUST_KEEP = frozenset({
    "apple watch",
    "airpods",
    "watch",
    "reminder",
    "habit",
    "coach",
    "wellness",
    "apple health",
    "health app",
    "posture reminder",
    "posture scan",
    "posture check",
    "posture coach",
    "slouch",
    "slouch alert",
    "slouching",
    "desk posture",
    "text neck",
    "tech neck",
    "neck pain",
    "ergonomics app",
    "spine health",
    "habit tracker",
    "streak tracker",
    "tech neck",
    "duolingo streak",
    "streak freeze",
    "quick posture check",
    "apple watch posture",
    "apple watch widget",
    "lock screen widget",
    "home screen widget",
    "airpods posture",
    "posture widget",
    "posture tracker",
    "posture streak",
    "wfh posture",
    "office posture",
    "sit up straight",
    "forward head",
    "forward head posture",
    "background monitoring",
    "headphone motion",
})

SEED_PHRASES = [
    "posture reminder",
    "posture tracker",
    "posture coach",
    "posture check",
    "posture correction",
    "posture monitor",
    "posture scan",
    "posture app",
    "posture fix",
    "posture habit",
    "posture streak",
    "slouch alert",
    "slouch detector",
    "slouching app",
    "text neck",
    "tech neck",
    "forward head posture",
    "back straight",
    "align posture",
    "sitting posture",
    "posture training",
    "spinal alignment",
    "stand up",
    "neck posture",
    "neck pain relief",
    "back posture",
    "desk posture",
    "office posture",
    "wfh posture",
    "sit up straight",
    "stand up reminder",
    "stand reminder",
    "break reminder",
    "desk ergonomics",
    "ergonomics app",
    "spine health",
    "straight back",
    "daily posture",
    "posture widget",
    "lock screen widget",
    "apple watch widget",
    "apple watch complication",
    "airpods posture",
    "posture airpods",
    "headphone posture",
    "habit tracker",
    "habit streak",
    "streak tracker",
    "daily reminder",
    "wellness app",
    "health tracker",
    "on device",
    "privacy app",
]

RELEVANCE_TERMS = re.compile(
    r"posture|slouch|neck|back|spine|ergonomic|desk|sit|stand|straight|"
    r"reminder|streak|habit|airpod|watch|widget|coach|tracker|scan|"
    r"align|upright|forward|head|text|tech|wfh|office|wellness|health|"
    r"break|sedentary|spinal|motion|calibrat|monitor",
    re.I,
)

JUNK_STARTERS = frozenset(
    "and for the you each few all check good grow build choose covers "
    "actually stick with instead nagging nudges land tap scan tells "
    "upright borderline slouching works calibrate rhythm pick want "
    "hours per day off days flame freeze protection covers device "
    "iphone airpods apple watch your habit personal baseline learns "
    "many reminders second posture".split()
)


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text())


def opportunity(pop: int, diff: int) -> float:
    return pop / max(diff, 1)


def is_junk(keyword: str, curated: set[str]) -> bool:
    k = keyword.strip().lower()
    if k in curated or k in MUST_KEEP:
        return False
    if not RELEVANCE_TERMS.search(k):
        return True
    words = k.split()
    if len(words) == 1:
        return False
    if len(words) >= 4:
        return True
    if words[0] in JUNK_STARTERS or (len(words) > 1 and words[1] in JUNK_STARTERS):
        return True
    # Bigram fragments from description n-grams
    bad_pairs = {
        ("and", "apple"), ("and", "watch"), ("and", "actually"), ("and", "streaks"),
        ("and", "posture"), ("airpods", "and"), ("coach", "for"), ("for", "iphone"),
        ("you", "all"), ("the", "way"), ("check", "active"), ("check", "hold"),
        ("reminders", "and"), ("straight", "and"), ("actually", "stick"),
        ("stick", "with"), ("few", "times"), ("all", "day"), ("grow", "how"),
        ("flame", "grows"), ("freeze", "protection"), ("covers", "the"),
        ("per", "day"), ("once", "sit"), ("sit", "the"), ("pick", "your"),
        ("rhythm", "choose"), ("many", "reminders"), ("land", "tap"),
        ("scan", "tells"), ("tells", "you"), ("device", "posture"),
    }
    if tuple(words[:2]) in bad_pairs:
        return True
    return False


def tier(pop: int, diff: int, opp: float) -> str:
    if pop >= 15 and diff <= 35:
        return "priority"
    if pop >= 8 and diff <= 50:
        return "strong"
    if opp >= 0.35 and pop >= 5:
        return "target"
    if pop >= 5 and diff <= 25:
        return "target"
    return "longtail"


def analyze(kws: list[dict], curated: set[str]) -> dict:
    rows = []
    for k in kws:
        kw = k["keyword"]
        pop = int(k.get("popularity") or 0)
        diff = int(k.get("difficulty") or 50)
        opp = opportunity(pop, diff)
        junk = is_junk(kw, curated)
        rows.append(
            {
                "keyword": kw,
                "popularity": pop,
                "difficulty": diff,
                "opportunity": round(opp, 3),
                "tier": tier(pop, diff, opp),
                "junk": junk,
            }
        )
    rows.sort(key=lambda x: (-x["opportunity"], -x["popularity"]))
    keep = [r for r in rows if not r["junk"]]
    junk = [r for r in rows if r["junk"]]
    return {"keep": keep, "junk": junk, "all": rows}


def build_target_list(
    analyzed_keep: list[dict],
    asc_tokens: list[str],
    seeds: list[str],
    max_keywords: int = 72,
) -> list[str]:
    chosen: list[str] = []
    seen: set[str] = set()

    def add(k: str) -> None:
        k = k.strip().lower()
        if k and k not in seen:
            seen.add(k)
            chosen.append(k)

    # ASC field tokens always tracked
    for t in asc_tokens:
        add(t)

    for k in MUST_KEEP:
        add(k)

    # Priority from tracked data
    for r in analyzed_keep:
        if r["tier"] in ("priority", "strong"):
            add(r["keyword"])

    # High-opportunity tracked
    for r in analyzed_keep:
        if r["tier"] == "target" and len(chosen) < max_keywords:
            add(r["keyword"])

    # Seeds not yet tracked
    for s in seeds:
        if len(chosen) >= max_keywords:
            break
        add(s)

    return chosen[:max_keywords]


def remove_keywords_batched(
    mcp_url: str,
    app_name: str,
    app_id: str,
    store: str,
    keywords: list[str],
) -> int:
    removed = 0
    for i in range(0, len(keywords), 20):
        batch = keywords[i : i + 20]
        for args in (
            {"appName": app_name, "store": store, "keywords": batch},
            {"appId": app_id, "store": store, "keywords": batch},
        ):
            try:
                r = mcp_call(mcp_url, "remove_keywords", args)
                if isinstance(r, dict):
                    removed += r.get("removed", r.get("deleted", len(batch)))
                break
            except Exception:
                continue
        time.sleep(1.2)
    return removed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--analyze", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--remove-junk", action="store_true")
    parser.add_argument("--max", type=int, default=72)
    args = parser.parse_args()

    cfg = load_config()
    mcp = DEFAULT_MCP
    app_id = str(cfg["appId"])
    app_name = cfg.get("astroAppName", "Posture")
    store = cfg.get("store", "us")

    meta_keywords = ""
    if Path("fastlane/metadata/en-US/keywords.txt").exists():
        meta_keywords = Path("fastlane/metadata/en-US/keywords.txt").read_text().strip()
    asc_tokens = [t.strip().lower() for t in meta_keywords.split(",") if t.strip()]

    curated = set(json.loads(OUT_PATH.read_text())["keywords"]) if OUT_PATH.exists() else set()

    kws = mcp_call(mcp, "get_app_keywords", {"appId": app_id, "store": store})
    report = analyze(kws, curated)

    print(f"Tracked: {len(kws)} | Keep: {len(report['keep'])} | Junk: {len(report['junk'])}")
    print("\n--- Priority / strong (top 20) ---")
    for r in report["keep"][:20]:
        print(
            f"  [{r['tier']:8}] opp={r['opportunity']:.2f} "
            f"pop={r['popularity']:3} diff={r['difficulty']:3}  {r['keyword']}"
        )

    target = build_target_list(report["keep"], asc_tokens, SEED_PHRASES, args.max)
    print(f"\n--- Optimized list ({len(target)} keywords) ---")

    asc_field_recommended = optimize_asc_field(asc_tokens, report["keep"], target)
    asc_str = ",".join(asc_field_recommended)
    print(f"\n--- Recommended ASC keyword field ({len(asc_str)} chars) ---")
    print(asc_str)

    report_path = Path("scripts/astro-keyword-report.json")
    payload = {
        "analyzedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tracked": len(kws),
        "junkCount": len(report["junk"]),
        "optimizedKeywords": target,
        "ascFieldRecommended": asc_field_recommended,
        "priority": [r for r in report["keep"] if r["tier"] == "priority"],
        "junk": [r["keyword"] for r in report["junk"]],
    }
    report_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"\nWrote {report_path}")

    if args.analyze and not args.apply:
        return

    if args.apply:
        if args.remove_junk and report["junk"]:
            junk_kw = [r["keyword"] for r in report["junk"]]
            print(f"\nRemoving {len(junk_kw)} junk keywords...")
            n = remove_keywords_batched(mcp, app_name, app_id, store, junk_kw)
            print(f"Remove reported: ~{n}")

        missing = [k for k in target if k not in {x["keyword"] for x in kws}]
        if missing:
            print(f"\nAdding {len(missing)} keywords...")
            add_keywords(mcp, app_id, store, missing, app_name=app_name)

        OUT_PATH.write_text(
            json.dumps(
                {
                    "store": store,
                    "appName": cfg.get("appName"),
                    "ascKeywords": meta_keywords,
                    "keywords": target,
                },
                indent=2,
            )
            + "\n"
        )
        print(f"Updated {OUT_PATH}")


def name_subtitle_tokens() -> set[str]:
    tokens: set[str] = set()
    for path in (
        Path("fastlane/metadata/en-US/name.txt"),
        Path("fastlane/metadata/en-US/subtitle.txt"),
    ):
        if path.exists():
            text = path.read_text().lower()
            tokens |= set(re.findall(r"[a-z0-9]+", text))
            # stems Apple likely treats as duplicates
            for t in list(tokens):
                if t.endswith("s") and len(t) > 3:
                    tokens.add(t[:-1])
    return tokens


def optimize_asc_field(
    current: list[str],
    keep_rows: list[dict],
    phrases: list[str],
) -> list[str]:
    """Pick ASC 100-char field: single tokens, high pop, no name/subtitle dupes."""
    skip = name_subtitle_tokens()
    singles_scores: list[tuple[float, str]] = []
    for r in keep_rows:
        kw = r["keyword"]
        if " " in kw:
            continue
        if len(kw) > 12:
            continue
        singles_scores.append((r["opportunity"] * r["popularity"], kw))

    preferred = [
        "posture",
        "slouch",
        "reminder",
        "streak",
        "habit",
        "airpods",
        "watch",
        "widget",
        "neck",
        "back",
        "desk",
        "coach",
        "ergonomics",
        "wellness",
        "scan",
    ]
    # Drop low-signal ASC tokens when optimizing the 100-char field
    drop = {"sit", "active"}
    chosen: list[str] = []
    seen: set[str] = set()

    def try_add(word: str) -> bool:
        if word in seen or word in skip:
            return False
        trial = ",".join(chosen + [word]) if chosen else word
        if len(trial) <= 100:
            chosen.append(word)
            seen.add(word)
            return True
        return False

    for w in preferred:
        try_add(w)

    for score, w in sorted(singles_scores, reverse=True):
        if w in drop:
            continue
        if len(chosen) >= 14:
            break
        try_add(w)

    return chosen


if __name__ == "__main__":
    main()

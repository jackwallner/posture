#!/usr/bin/env python3
"""Sync Astro keywords until all 91 stores have >= MIN_KW."""
from __future__ import annotations

import importlib.util
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from astro_mcp import add_keywords, call, ping

_spec = importlib.util.spec_from_file_location(
    "astro_sync", Path(__file__).parent / "astro-sync-all-stores.py"
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore

MCP_URL = "http://127.0.0.1:8089/mcp"
OUT_DIR = _mod.OUT_DIR
AUDIT = Path(__file__).parent / "astro-store-audit.json"
MIN_KW = 25
BATCH_SIZE = 2
BATCH_SLEEP = 1.0
MAX_ROUNDS = 15
MAX_BATCH_RETRIES = 8
GET_TIMEOUT = 40


def kw_count(app_id: str, store: str, retries: int = 3) -> int:
    for attempt in range(retries):
        try:
            kws = call(
                MCP_URL,
                "get_app_keywords",
                {"appId": app_id, "store": store},
                timeout=GET_TIMEOUT,
            )
            return len(kws) if isinstance(kws, list) else 0
        except Exception:
            time.sleep(2 + attempt)
    return -1


def sync_store(app_id: str, store: str, keywords: list[str]) -> int:
    if not keywords:
        return 0
    existing: set[str] = set()
    n = kw_count(app_id, store)
    if n > 0:
        try:
            kws = call(
                MCP_URL,
                "get_app_keywords",
                {"appId": app_id, "store": store},
                timeout=GET_TIMEOUT,
            )
            existing = {k["keyword"].lower() for k in kws if isinstance(k, dict)}
        except Exception:
            pass

    missing = [k for k in keywords if k.lower() not in existing]
    if not missing:
        return 0

    added = 0
    for i in range(0, len(missing), BATCH_SIZE):
        batch = missing[i : i + BATCH_SIZE]
        for attempt in range(MAX_BATCH_RETRIES):
            try:
                r = add_keywords(MCP_URL, app_id, store, batch)
                added += sum(
                    b.get("added", 0) for b in r.get("batches", []) if isinstance(b, dict)
                )
                break
            except Exception as e:
                if attempt == MAX_BATCH_RETRIES - 1:
                    print(f"    batch fail ({batch}): {e}", flush=True)
                time.sleep(2 + attempt)
        time.sleep(BATCH_SLEEP)
    return added


def write_store_json(store: str, info: dict, count: int) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "store": store,
        "country": info["country"],
        "locales": info["locales"],
        "keywordCount": count if count >= 0 else len(info["keywords"]),
        "keywords": info["keywords"],
    }
    (OUT_DIR / f"{store}.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    )


def stores_to_fix(app_id: str, all_stores: list[str]) -> list[str]:
    """Stores below MIN_KW; seed from audit file to avoid scanning all 91 up front."""
    if AUDIT.exists():
        low = json.loads(AUDIT.read_text()).get("lowStores", [])
        if low:
            return [s for s in low if s in all_stores]
    low = []
    for store in all_stores:
        n = kw_count(app_id, store, retries=2)
        print(f"  audit {store}: {n}", flush=True)
        if n < MIN_KW:
            low.append(store)
        time.sleep(0.2)
    return low


def main() -> None:
    if not ping(MCP_URL):
        raise SystemExit("error: Astro MCP not reachable — open Astro and enable MCP")

    app_id = _mod.load_app_id()
    plan = _mod.build_store_plan(app_id)
    all_stores = sorted(plan.keys())
    print(f"appId={app_id} stores={len(all_stores)} minKw={MIN_KW}", flush=True)

    work = stores_to_fix(app_id, all_stores)
    print(f"Work list: {len(work)} store(s)", flush=True)

    for round_num in range(1, MAX_ROUNDS + 1):
        if not work:
            work = stores_to_fix(app_id, all_stores)
        print(f"\n=== Round {round_num}: syncing {len(work)} store(s) ===", flush=True)
        if not work:
            break

        still_low: list[str] = []
        for i, store in enumerate(work, 1):
            info = plan[store]
            kws = info["keywords"]
            n_before = kw_count(app_id, store, retries=2)
            print(
                f"[{i}/{len(work)}] {store} ({info['country']}) astro={n_before} plan={len(kws)}",
                flush=True,
            )
            if n_before >= MIN_KW:
                write_store_json(store, info, n_before)
                continue
            if not kws:
                still_low.append(store)
                continue
            added = sync_store(app_id, store, kws)
            n_after = kw_count(app_id, store, retries=3)
            write_store_json(store, info, n_after)
            print(f"    added~{added} astro now={n_after}", flush=True)
            if n_after < MIN_KW:
                still_low.append(store)
            time.sleep(0.5)

        work = still_low
        if not work:
            break

    print("\n=== Final audit (all stores) ===", flush=True)
    low_final: list[str] = []
    audit: dict[str, dict] = {}
    for i, store in enumerate(all_stores, 1):
        n = kw_count(app_id, store, retries=3)
        audit[store] = {"count": max(n, 0)}
        if n < MIN_KW:
            low_final.append(store)
        if i % 15 == 0:
            print(f"  ... {i}/{len(all_stores)}", flush=True)

    summary = {
        "syncedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "appId": app_id,
        "storeCount": len(all_stores),
        "okCount": len(all_stores) - len(low_final),
        "lowStores": low_final,
        "stores": audit,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    AUDIT.write_text(
        json.dumps(
            {"appId": app_id, "minKw": MIN_KW, "lowStores": low_final, "stores": audit},
            indent=2,
        )
        + "\n"
    )
    cfg_path = Path(__file__).parent / ".astro-app.json"
    cfg = json.loads(cfg_path.read_text()) if cfg_path.exists() else {}
    cfg.update({"appId": app_id, "syncedAt": summary["syncedAt"], "allAstroStores": all_stores})
    cfg_path.write_text(json.dumps(cfg, indent=2) + "\n")

    print(f"\nDone: {summary['okCount']}/{len(all_stores)} stores >= {MIN_KW}", flush=True)
    if low_final:
        print(f"STILL LOW ({len(low_final)}): {', '.join(low_final)}", flush=True)
        raise SystemExit(1)
    print(f"Wrote {OUT_DIR}/_summary.json", flush=True)


if __name__ == "__main__":
    main()

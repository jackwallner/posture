#!/usr/bin/env python3
"""Sync remaining Astro stores in-process (resilient to per-store failures)."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scripts/astro-keywords-by-store"
STORES = ROOT / "scripts/astro-stores-2026.json"
MIN_KW = 25


def remaining() -> list[str]:
    codes = [s["code"] for s in json.loads(STORES.read_text())["stores"]]
    todo: list[str] = []
    for code in codes:
        f = OUT / f"{code}.json"
        if f.exists() and json.loads(f.read_text()).get("keywordCount", 0) >= MIN_KW:
            continue
        todo.append(code)
    return todo


def keyword_count_in_astro(code: str, app_id: str) -> int:
    sys.path.insert(0, str(ROOT / "scripts"))
    from astro_mcp import call

    try:
        kws = call("http://127.0.0.1:8089/mcp", "get_app_keywords", {"appId": app_id, "store": code})
        return len(kws) if isinstance(kws, list) else 0
    except Exception:
        return 0


def run_store(code: str) -> bool:
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts/astro-sync-all-stores.py"), "--store", code],
        cwd=ROOT,
        env={**dict(__import__("os").environ), "PYTHONUNBUFFERED": "1"},
        timeout=180,
    )
    return r.returncode == 0


def main() -> None:
    cfg = json.loads((ROOT / "scripts/.astro-app.json").read_text())
    app_id = str(cfg["appId"])
    todo = remaining()
    print(f"{len(todo)} store(s) to sync")
    failed: list[str] = []
    for i, code in enumerate(todo, 1):
        print(f"\n[{i}/{len(todo)}] {code}")
        n0 = keyword_count_in_astro(code, app_id)
        if n0 >= MIN_KW:
            print(f"  skip sync — astro already has {n0} keywords")
            continue
        ok = False
        for attempt in range(3):
            try:
                if run_store(code):
                    ok = True
                    break
            except subprocess.TimeoutExpired:
                print(f"  timeout attempt {attempt + 1}/3")
            else:
                print(f"  retry {attempt + 1}/3 in 10s")
            time.sleep(10)
        n = keyword_count_in_astro(code, app_id)
        if n >= MIN_KW:
            print(f"  astro has {n} keywords — OK")
            ok = True
        if not ok:
            failed.append(code)
            print(f"  WARN: {code} still below {MIN_KW} keywords")
        time.sleep(2)
    if failed:
        print(f"\nFailed/low stores ({len(failed)}): {', '.join(failed)}")
    print("\n==> full summary")
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/astro-sync-all-stores.py")],
        cwd=ROOT,
        check=False,
    )


if __name__ == "__main__":
    main()

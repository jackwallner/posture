#!/usr/bin/env python3
"""Audit Astro keyword counts per store; write scripts/astro-store-audit.json."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from astro_mcp import call, ping

ROOT = Path(__file__).resolve().parent.parent
STORES = ROOT / "scripts/astro-stores-2026.json"
OUT = ROOT / "scripts/astro-store-audit.json"
MCP = "http://127.0.0.1:8089/mcp"
MIN_KW = 25


def main() -> None:
    if not ping(MCP):
        raise SystemExit("MCP not reachable")
    app_id = str(json.loads((ROOT / "scripts/.astro-app.json").read_text())["appId"])
    codes = [s["code"] for s in json.loads(STORES.read_text())["stores"]]
    audit: dict[str, dict] = {}
    low: list[str] = []
    for i, code in enumerate(codes, 1):
        try:
            kws = call(MCP, "get_app_keywords", {"appId": app_id, "store": code}, timeout=25)
            n = len(kws) if isinstance(kws, list) else 0
        except Exception as e:
            n = 0
            audit[code] = {"count": 0, "error": str(e)}
            low.append(code)
            print(f"[{i}/{len(codes)}] {code}: ERROR")
            time.sleep(1.5)
            continue
        audit[code] = {"count": n}
        if n < MIN_KW:
            low.append(code)
        print(f"[{i}/{len(codes)}] {code}: {n}")
        time.sleep(0.8)
    payload = {"appId": app_id, "minKw": MIN_KW, "lowStores": low, "stores": audit}
    OUT.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"\nOK (>={MIN_KW}): {len(codes)-len(low)}/{len(codes)}")
    print(f"LOW: {len(low)} → {', '.join(low)}")


if __name__ == "__main__":
    main()

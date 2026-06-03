#!/bin/bash
# Resume per-store Astro sync; skip stores with keywordCount >= 25 on disk.
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="$(dirname "$0"):${PYTHONPATH:-}"
OUT="scripts/astro-keywords-by-store"
MIN_KW=25

python3 <<'PY' | while IFS= read -r code; do
import json
from pathlib import Path
stores = [s["code"] for s in json.load(open("scripts/astro-stores-2026.json"))["stores"]]
out = Path("scripts/astro-keywords-by-store")
for code in stores:
    f = out / f"{code}.json"
    if f.exists():
        n = json.loads(f.read_text()).get("keywordCount", 0)
        if n >= 25:
            continue
    print(code)
PY
  echo "========== $code =========="
  for attempt in 1 2 3; do
    if PYTHONUNBUFFERED=1 python3 scripts/astro-sync-all-stores.py --store "$code"; then
      break
    fi
    echo "WARN: $code attempt $attempt failed; retry in 15s"
    sleep 15
  done
  sleep 3
done

echo "========== FINAL FULL SYNC =========="
PYTHONUNBUFFERED=1 python3 scripts/astro-sync-all-stores.py

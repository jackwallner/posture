#!/usr/bin/env python3
"""Install the generated illustration PNGs (scripts/illos/*.png) into the app's
asset catalog as the imagesets PoseDiagram looks up. Run after generate-illustrations.py.

illo_welcome / illo_nudge are left in scripts/illos/ for future onboarding use."""

import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts", "illos")
CATALOG = os.path.join(ROOT, "Posture", "Assets.xcassets")

# generated slug -> asset-catalog imageset name (PoseDiagram.assetName)
MAP = {
    "illo_standing": "IlloStanding",
    "illo_sitting": "IlloSitting",
    "illo_standing_slouch": "IlloStandingSlouch",
    "illo_slouch": "IlloSlouch",
    "illo_stack": "IlloStack",
}


def install(slug: str, asset: str) -> bool:
    png = os.path.join(SRC, f"{slug}.png")
    if not os.path.exists(png):
        print(f"  skip {asset}: {slug}.png not found (generate it first)")
        return False
    imageset = os.path.join(CATALOG, f"{asset}.imageset")
    os.makedirs(imageset, exist_ok=True)
    shutil.copyfile(png, os.path.join(imageset, f"{asset}.png"))
    contents = {
        "images": [{"filename": f"{asset}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(imageset, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  ok  {asset}")
    return True


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"no {SRC} - run generate-illustrations.py first")
    installed = sum(install(s, a) for s, a in MAP.items())
    print(f"installed {installed}/{len(MAP)} imagesets into Posture/Assets.xcassets")
    if installed:
        print("rebuild the app; PoseDiagram will pick them up automatically.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Check an archive against the caller's repo before any TestFlight upload."""
from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


def validate(spec: Path, archive: Path) -> None:
    text = spec.read_text()
    expected = {}
    for key in ("PRODUCT_BUNDLE_IDENTIFIER", "MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        match = re.search(rf"^\s*{key}:\s*[\"']?([\w.\-]+)[\"']?\s*(?:#.*)?$", text, re.M)
        if not match:
            raise SystemExit(f"cannot establish {key} from {spec}; refusing upload")
        expected[key] = match.group(1)
    with (archive / "Info.plist").open("rb") as stream:
        properties = plistlib.load(stream)["ApplicationProperties"]
    app_path = (archive / "Products" / properties["ApplicationPath"]).resolve()
    if not app_path.is_relative_to(archive.resolve()):
        raise SystemExit("archive app path escapes the archive; refusing upload")
    with (app_path / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    for key, field in (("PRODUCT_BUNDLE_IDENTIFIER", "CFBundleIdentifier"),
                       ("MARKETING_VERSION", "CFBundleShortVersionString"),
                       ("CURRENT_PROJECT_VERSION", "CFBundleVersion")):
        actual = str(info.get(field, ""))
        if actual != expected[key]:
            raise SystemExit(f"archive {field}={actual!r}, repo expects {expected[key]!r}; refusing upload")
    print(f"==> Archive identity verified: {info['CFBundleIdentifier']} {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: testflight_archive.py PROJECT_YML ARCHIVE")
    validate(Path(sys.argv[1]), Path(sys.argv[2]))

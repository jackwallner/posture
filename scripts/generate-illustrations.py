#!/usr/bin/env python3
"""Generate Posture onboarding/calibration illustrations via Pollinations.

Uses the public image.pollinations.ai on-demand endpoint. Sideline's briefing
pipeline uses gen.pollinations.ai (+ optional Cloudflare) — different host, no
shared API key, no overlap with sports card-art seeds or storage.

Writes PNGs to scripts/illos/. Run install-illustrations.py to copy the four
pose images into Assets.xcassets for PoseDiagram."""

import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "illos")

# Public Pollinations renderer. Sideline server generation uses gen.pollinations.ai.
HOST = "image.pollinations.ai"

STYLE = (
    "Simple flat cartoon illustration in the style of a friendly newspaper comic. "
    "Bold clean dark-slate outlines, limited flat color palette of exactly three colors: "
    "soft sage green (#8FC5A8), warm sand (#E8C896), and deep slate (#2F3E3A), "
    "on a very pale mint paper background (#F4F9F7). Minimal shapes, lots of negative "
    "space, one single clear subject centered, easy to read at a single glance, light "
    "gentle humor, calm and kind mood. The person is a simple gender-neutral cartoon "
    "figure with no facial detail beyond a simple friendly expression. "
    "No text, no words, no letters, no numbers, no logos, no brand marks, "
    "no real or recognizable people. Vector-like, clean, square composition."
)

SUBJECTS = [
    ("illo_welcome",
     "A relaxed person working at a laptop desk wearing tiny wireless earbuds, "
     "sitting perfectly upright, with two or three soft short signal arcs rising "
     "gently from one earbud to suggest quiet listening"),
    ("illo_stack",
     "A side profile of a person standing perfectly tall, with a subtle dashed "
     "vertical line passing through ear, shoulder, and hip to show the stacked "
     "alignment of good posture"),
    ("illo_standing",
     "Front view of a person standing tall and relaxed, feet hip-width apart, arms "
     "loose at their sides, with a thin string rising from the very top of the head "
     "to a small balloon above — the string must attach to the crown of the head, "
     "not the face"),
    ("illo_sitting",
     "Side view of a person with perfect upright sitting posture on a simple chair, "
     "spine straight as a vertical line, ears stacked over shoulders, chin level, "
     "chest open, feet flat on the floor, back against the chair back, hands resting "
     "on thighs, clearly tall and aligned not slouched"),
    ("illo_slouch",
     "A person slumped deeply in a chair in a classic lazy slouch, chin dropped "
     "toward chest, shoulders rolled forward, spine curved like the letter C, "
     "clearly comfortable but clearly slouching"),
    ("illo_nudge",
     "A single wireless earbud, large and centered, with two or three gentle "
     "curved vibration lines on each side suggesting a soft friendly buzz"),
]


def seed_for(slug: str) -> int:
    """FNV-1a in a Posture-only namespace — unrelated to Sideline card-art seeds."""
    text = f"posture.illo.v4.{slug}"
    hash_ = 0x811C9DC5
    for byte in text.encode("utf-8"):
        hash_ ^= byte
        hash_ = (hash_ * 0x01000193) & 0xFFFFFFFF
    return hash_ & 0x7FFFFFFF


def pollinations_url(prompt: str, seed: int) -> str:
    # Commas stay literal, matching Pollinations' path encoding expectations.
    encoded = urllib.parse.quote(prompt, safe=",")
    query = urllib.parse.urlencode({
        "width": 1024,
        "height": 1024,
        "nologo": "true",
        "safe": "true",
        "seed": seed,
        "model": "flux",
    })
    return f"https://{HOST}/prompt/{encoded}?{query}"


def fetch_image(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "posture-illos/1"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = resp.read()
    if len(data) < 512:
        raise RuntimeError(f"response too small ({len(data)} bytes)")
    if data[0:8] != b"\x89PNG\r\n\x1a\n" and data[0:2] != b"\xff\xd8":
        raise RuntimeError("response is not PNG or JPEG")
    return data


def generate(slug: str, subject: str) -> str:
    prompt = f"{subject}. {STYLE}"
    seed = seed_for(slug)
    url = pollinations_url(prompt, seed)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{slug}.png")
    data = fetch_image(url)
    with open(path, "wb") as f:
        f.write(data)
    return path


def main():
    only = {s.strip() for s in sys.argv[1:] if s.strip()}
    subjects = [(s, sub) for s, sub in SUBJECTS if not only or s in only]
    if only and not subjects:
        sys.exit(f"unknown slug(s): {', '.join(sorted(only))}")

    print(f"host: {HOST}")
    for i, (slug, subject) in enumerate(subjects):
        for attempt in range(4):
            try:
                path = generate(slug, subject)
                print(f"  ok  -> {path}", flush=True)
                break
            except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError) as e:
                wait = 15 * (attempt + 1)
                print(f"  retry {slug} ({attempt + 1}): {e} — sleeping {wait}s", flush=True)
                time.sleep(wait)
        else:
            print(f"  FAIL {slug}: gave up after retries", flush=True)
            sys.exit(1)
        if i < len(subjects) - 1:
            time.sleep(8)


if __name__ == "__main__":
    main()

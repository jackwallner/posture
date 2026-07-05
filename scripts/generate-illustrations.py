#!/usr/bin/env python3
"""Generate the Posture onboarding/calibration illustration set with Gemini,
in the same friendly-newspaper-comic house style as the sports app, tuned to
Posture's Daylight palette (sage green, warm sand, slate ink on soft paper)."""

import base64
import json
import os
import sys
import time
import urllib.request

ENV_FILES = [
    os.path.expanduser("~/sports/.env"),
    os.path.expanduser("~/sports/SupabaseFunctions/.env"),
]


def load_key() -> str:
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"]
    for path in ENV_FILES:
        if not os.path.exists(path):
            continue
        for line in open(path):
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("no GEMINI_API_KEY found")


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
     "gently from one earbud to suggest quiet listening."),
    ("illo_stack",
     "A side profile of a person standing perfectly tall, with a subtle dashed "
     "vertical line passing through ear, shoulder, and hip to show the stacked "
     "alignment of good posture."),
    ("illo_standing",
     "A person standing tall and relaxed, feet hip-width apart, arms loose at "
     "their sides, with a single thread rising from the crown of their head to a "
     "small balloon above, suggesting being gently lifted taller."),
    ("illo_sitting",
     "A person sitting tall on a simple chair at a small desk, both feet flat on "
     "the floor, hips back in the seat, long straight spine, looking straight ahead."),
    ("illo_slouch",
     "A person slumped deeply in a chair in a classic lazy slouch, chin dropped "
     "toward chest, shoulders rolled forward, spine curved like the letter C, "
     "clearly comfortable but clearly slouching."),
    ("illo_nudge",
     "A single wireless earbud, large and centered, with two or three gentle "
     "curved vibration lines on each side suggesting a soft friendly buzz."),
]

MODEL = os.environ.get("IMAGE_MODEL", "gemini-2.5-flash-image")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "illos")


def generate(key: str, slug: str, subject: str) -> str:
    prompt = f"{subject}\n\n{STYLE}"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{MODEL}:generateContent?key={key}"
    )
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        body = json.loads(resp.read())

    parts = body.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    for part in parts:
        inline = part.get("inlineData") or part.get("inline_data")
        if inline and inline.get("data"):
            os.makedirs(OUT, exist_ok=True)
            path = f"{OUT}/{slug}.png"
            with open(path, "wb") as f:
                f.write(base64.b64decode(inline["data"]))
            return path
    raise RuntimeError("no image in response: " + json.dumps(body)[:500])


def main():
    key = load_key()
    print(f"model: {MODEL}")
    for i, (slug, subject) in enumerate(SUBJECTS):
        for attempt in range(3):
            try:
                path = generate(key, slug, subject)
                print(f"  ok  -> {path}", flush=True)
                break
            except Exception as e:  # noqa: BLE001
                print(f"  retry {slug} ({attempt + 1}): {e}", flush=True)
                time.sleep(35)
        if i < len(SUBJECTS) - 1:
            time.sleep(31)  # free tier ~2 img/min


if __name__ == "__main__":
    main()

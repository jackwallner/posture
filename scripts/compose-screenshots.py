#!/usr/bin/env python3
"""Compose App Store screenshots from raw captures in the Posture house style.

Reads raws from claude-design/raw/, writes framed 1320x2868 PNGs to
claude-design/output/store/. Matches SCREENSHOT-PROMPT.md: branded gradient
canvas, drawn iPhone frame with the raw inside, a two-line headline (rounded
bold + italic serif accent) and a one-line subline.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "claude-design", "raw")
OUT = os.path.join(ROOT, "claude-design", "output", "store")
os.makedirs(OUT, exist_ok=True)

W, H = 1320, 2868
INK = (47, 62, 58)          # #2F3E3A
SUB = (107, 123, 118)       # #6B7B76
NEAR_WHITE = (250, 252, 251)  # #FAFCFB
BEZEL = (26, 27, 28)

TINTS = {
    "sage": (143, 197, 168),
    "sand": (232, 200, 150),
    "clay": (232, 160, 154),
    "lavender": (191, 168, 228),
}

NUNITO_BOLD = os.path.join(ROOT, "Posture", "Fonts", "Nunito-Bold.ttf")
NUNITO_MED = os.path.join(ROOT, "Posture", "Fonts", "Nunito-Medium.ttf")
SERIF_ITALIC = "/System/Library/Fonts/Supplemental/Georgia Bold Italic.ttf"

# (raw, output, tint, headline line 1, headline line 2 [italic serif], subline)
FRAMES = [
    ("raw-1-today.png",    "store-1-today.png",    "sage",
     "Sit taller,", "every day.", "A gentle daily score, no scolding."),
    ("raw-2-practice.png", "store-2-practice.png", "lavender",
     "Your AirPods,", "your coach.", "A few guided minutes. No camera, no wearable."),
    ("raw-3-summary.png",  "store-3-summary.png",  "sage",
     "Gentle words,", "not nagging.", "Aligned, drifting, or slouched. Never scolded."),
    ("raw-4-history.png",  "store-4-history.png",  "sand",
     "Watch it", "add up.", "Practice minutes and passes, private on-device."),
    ("raw-5-progress.png", "store-5-progress.png", "clay",
     "Level up,", "gently.", "Sessions grow from 3 to 15 minutes as you improve."),
    ("raw-6-checkin.png",  "store-6-checkin.png",  "sand",
     "No AirPods in?", "Just tell us.", "Check in by hand and keep your streak."),
]


def blend(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def darken(c, t=0.35):
    return tuple(round(c[i] * (1 - t)) for i in range(3))


def gradient(tint):
    top = blend((255, 255, 255), tint, 0.28)
    img = Image.new("RGB", (W, H), NEAR_WHITE)
    px = img.load()
    for y in range(H):
        t = min(1.0, y / (H * 0.62))
        row = blend(top, NEAR_WHITE, t)
        for x in range(W):
            px[x, y] = row
    return img


def fit_font(path, text, max_w, start, floor=70):
    size = start
    while size > floor:
        f = ImageFont.truetype(path, size)
        if f.getbbox(text)[2] - f.getbbox(text)[0] <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, floor)


def centered(draw, text, font, y, fill):
    bb = draw.textbbox((0, 0), text, font=font)
    w = bb[2] - bb[0]
    draw.text(((W - w) / 2 - bb[0], y), text, font=font, fill=fill)
    return bb[3] - bb[1]


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return m


def compose(raw_name, out_name, tint_name, h1, h2, subline):
    tint = TINTS[tint_name]
    canvas = gradient(tint)
    draw = ImageDraw.Draw(canvas)

    max_text_w = W - 2 * 96
    f1 = fit_font(NUNITO_BOLD, h1, max_text_w, 150)
    f2 = fit_font(SERIF_ITALIC, h2, max_text_w, 150)
    head_size = min(f1.size, f2.size)
    f1 = ImageFont.truetype(NUNITO_BOLD, head_size)
    f2 = ImageFont.truetype(SERIF_ITALIC, head_size)

    y = 150
    centered(draw, h1, f1, y, INK)
    y += int(head_size * 1.02)
    centered(draw, h2, f2, y, darken(tint, 0.28))
    y += int(head_size * 1.30)

    fsub = fit_font(NUNITO_MED, subline, W - 2 * 80, 50, floor=38)
    centered(draw, subline, fsub, y, SUB)

    # Device frame
    raw = Image.open(os.path.join(RAW, raw_name)).convert("RGB")
    dev_w = int(W * 0.80)
    bezel = 18
    screen_w = dev_w - 2 * bezel
    scale = screen_w / raw.width
    screen_h = int(raw.height * scale)
    dev_h = screen_h + 2 * bezel
    dev_x = (W - dev_w) // 2
    dev_y = 780

    # Soft shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([dev_x + 10, dev_y + 26, dev_x + dev_w + 10, dev_y + dev_h + 26],
                         radius=110, fill=(30, 40, 36, 40))
    from PIL import ImageFilter
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shadow.split()[3])

    # Bezel
    bez = Image.new("RGB", (dev_w, dev_h), BEZEL)
    canvas.paste(bez, (dev_x, dev_y), rounded_mask((dev_w, dev_h), 108))

    # Screen (raw)
    screen = raw.resize((screen_w, screen_h), Image.LANCZOS)
    canvas.paste(screen, (dev_x + bezel, dev_y + bezel), rounded_mask((screen_w, screen_h), 92))

    canvas.save(os.path.join(OUT, out_name))
    print(f"wrote {out_name}  ({tint_name})")


if __name__ == "__main__":
    for frame in FRAMES:
        if os.path.exists(os.path.join(RAW, frame[0])):
            compose(*frame)
        else:
            print(f"skip {frame[0]} (missing)")

#!/usr/bin/env python3
"""Generate the alpha-cutout card textures used for billboard-style crops
(currently just wheat) in textures/manifest.json, from procedural drawing —
no external art assets. Deterministic (seeded), so re-running produces byte-
identical PNGs.

Usage:
  python3 scripts/generate-textures.py
"""

from __future__ import annotations

import json
import math
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "textures"
MANIFEST = OUT_DIR / "manifest.json"

SUPERSAMPLE = 4


def lerp_color(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def draw_wheat_card(size: tuple[int, int], seed: int) -> Image.Image:
    rng = random.Random(seed)
    w, h = size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base_green = (90, 118, 58)
    gold = (222, 188, 92)
    gold_light = (238, 210, 130)

    stalk_count = 6
    for i in range(stalk_count):
        stalk_x = w * (0.14 + 0.72 * i / (stalk_count - 1)) + rng.uniform(-w * 0.03, w * 0.03)
        base_y = h * rng.uniform(0.92, 1.0)
        top_y = h * rng.uniform(0.12, 0.24)
        sway = rng.uniform(-w * 0.09, w * 0.09)
        stroke = rng.uniform(0.016, 0.024) * w

        segments = 14
        points = []
        for s in range(segments + 1):
            t = s / segments
            # ease-out curve so the stalk leans more near the top, like it's
            # bending under the head's weight
            bend = t * t
            x = stalk_x + sway * bend
            y = base_y + (top_y - base_y) * t
            points.append((x, y))

        for s in range(segments):
            t = (s + 0.5) / segments
            color = lerp_color(base_green, gold, min(1.0, t * 1.3))
            width = max(2, round(stroke * (1.0 - 0.35 * t)))
            draw.line([points[s], points[s + 1]], fill=(*color, 255), width=width)

        # Ear at the tip: an elongated blob plus a few short awns for texture
        tip = points[-1]
        prev = points[-2]
        dirx, diry = tip[0] - prev[0], tip[1] - prev[1]
        length = math.hypot(dirx, diry) or 1
        dirx, diry = dirx / length, diry / length
        ear_len = h * rng.uniform(0.16, 0.21)
        ear_w = w * rng.uniform(0.032, 0.042)
        ear_end = (tip[0] + dirx * ear_len, tip[1] + diry * ear_len)
        draw.line([tip, ear_end], fill=(*gold, 255), width=round(ear_w))
        draw.ellipse(
            [tip[0] - ear_w * 0.6, tip[1] - ear_w * 0.6, tip[0] + ear_w * 0.6, tip[1] + ear_w * 0.6],
            fill=(*gold, 255),
        )
        draw.ellipse(
            [ear_end[0] - ear_w * 0.45, ear_end[1] - ear_w * 0.45, ear_end[0] + ear_w * 0.45, ear_end[1] + ear_w * 0.45],
            fill=(*gold_light, 255),
        )
        awn_count = 5
        for a in range(awn_count):
            t = (a + 0.5) / awn_count
            ax, ay = tip[0] + dirx * ear_len * t, tip[1] + diry * ear_len * t
            side = 1 if a % 2 == 0 else -1
            perp_x, perp_y = -diry * side, dirx * side
            awn_len = h * rng.uniform(0.05, 0.075)
            end = (ax + perp_x * awn_len + dirx * awn_len * 0.4, ay + perp_y * awn_len + diry * awn_len * 0.4)
            draw.line([(ax, ay), end], fill=(*gold, 235), width=max(1, round(ear_w * 0.18)))

    return img.resize(size, Image.LANCZOS)


def main() -> int:
    OUT_DIR.mkdir(exist_ok=True)
    entries = [
        {"key": "wheat_card", "file": "textures/wheat_card.png", "displayName": "Wheat card"},
    ]
    for e in entries:
        img = draw_wheat_card((320, 480), seed=zlib.crc32(e["key"].encode()))
        img.save(ROOT / e["file"])
        print(f"wrote {e['file']}")

    MANIFEST.write_text(json.dumps(entries, indent=2) + "\n")
    print(f"wrote {MANIFEST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

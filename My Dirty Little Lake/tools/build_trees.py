#!/usr/bin/env python
"""The wood's new trees and its forest-floor wood (2026-10-05, /grill-me with Richard,
picked off tools/flora_look/mock2_*.png, option D).

Toffeecraft's animated trees (art_source/Fauna/AnimatedTreesUpdates, bought with the
bunnies): the dark green (CoolColor) and light green (WarmColor) round trees, every one of
their 16 sway frames, cut to one shared box so a tree never shifts between frames, its baked
black shadow and half pixels dropped (the lake throws its own), laid side by side with a
`GUTTER` of clear pixels so a nearest sample at a frame's edge never lands on the next one.
The ground steps through the frames in the shader (shaders/flora_sway.gdshader), so the
frame stride is the same for both trees and written down in the json.

And the logs and sticks the wood floor gets from the start (Decorations/Woods.png, and the
stump off Plants.png), one picture each, onto a small sheet.

No pines (Richard: "pines do not stay") and no other season. Writes:
  assets/trees/round_dark.png, round_light.png   16 frames each
  assets/trees/floor.png                          logs, sticks, stump, driftwood
  assets/trees/trees.json                         frame size, stride, count; floor rects

Base python with the psd-extract venv's site-packages on PYTHONPATH, from the project root,
then reimport.
"""
from __future__ import annotations

import json
import os

import numpy as np
from PIL import Image

PACK = os.path.join("art_source", "Fauna", "AnimatedTreesUpdates", "AnimatedTreesUpdates")
OUT = os.path.join("assets", "trees")
CELL = 64
FRAMES = 16
GUTTER = 2
TREES = {
    "round_dark": os.path.join(PACK, "AnimatedClassicalTrees", "AnimatedTreeCoolColor.png"),
    "round_light": os.path.join(PACK, "AnimatedClassicalTrees", "AnimatedTreeWarmColor.png"),
}
# Sheet, then the box of the piece on it (art px). Picked off the indexed cut in
# tools/flora_look/idx_{Woods,Plants}.png.
FLOOR = {
    "log0": ("Woods", (65, 7, 31, 15)),
    "log1": ("Woods", (96, 7, 31, 15)),
    "log_moss0": ("Woods", (65, 27, 31, 16)),
    "log_moss1": ("Woods", (96, 27, 31, 16)),
    "stick0": ("Woods", (0, 8, 15, 5)),
    "stick1": ("Woods", (15, 4, 16, 5)),
    "stick2": ("Woods", (2, 35, 11, 11)),
    "stick3": ("Woods", (18, 35, 11, 11)),
    "stump": ("Plants", (49, 34, 14, 13)),
    "driftwood": ("Plants", (230, 100, 86, 24)),
}


def clean(path: str) -> np.ndarray:
    """The pack's baked black shadows and its half pixels dropped."""
    a = np.array(Image.open(path).convert("RGBA"))
    shadow = (a[..., 3] < 200) & (a[..., :3].max(-1) < 30)
    a[shadow] = 0
    a[a[..., 3] < 128] = 0
    a[a[..., 3] >= 128, 3] = 255
    return a


def trim(a: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(a[..., 3])
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    sheets = {n: clean(p) for n, p in TREES.items()}
    frames = {n: [s[0:CELL, i * CELL:(i + 1) * CELL] for i in range(FRAMES)] for n, s in sheets.items()}
    union = np.zeros((CELL, CELL), bool)
    for fs in frames.values():
        for f in fs:
            union |= f[..., 3] > 0
    ys, xs = np.nonzero(union)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    w, h = int(x1 - x0), int(y1 - y0)
    stride = w + GUTTER
    for n, fs in frames.items():
        strip = np.zeros((h, stride * FRAMES, 4), np.uint8)
        for i, f in enumerate(fs):
            strip[:, i * stride:i * stride + w] = f[y0:y1, x0:x1]
        Image.fromarray(strip).save(os.path.join(OUT, n + ".png"))
    pieces = {}
    for name, (sheet, (x, y, bw, bh)) in FLOOR.items():
        src = clean(os.path.join(PACK, "Decorations", sheet + ".png"))
        pieces[name] = trim(src[y:y + bh, x:x + bw])
    wide = sum(p.shape[1] + GUTTER for p in pieces.values()) + GUTTER
    tall = max(p.shape[0] for p in pieces.values()) + GUTTER * 2
    floor = np.zeros((tall, wide, 4), np.uint8)
    rects = {}
    cx = GUTTER
    for name, p in pieces.items():
        ph, pw = p.shape[:2]
        floor[GUTTER:GUTTER + ph, cx:cx + pw] = p
        rects[name] = [cx, GUTTER, pw, ph]
        cx += pw + GUTTER
    Image.fromarray(floor).save(os.path.join(OUT, "floor.png"))
    with open(os.path.join(OUT, "trees.json"), "w", encoding="utf-8") as f:
        json.dump({
            "frame": [w, h], "stride": stride, "frames": FRAMES,
            "trees": list(TREES), "floor": rects,
        }, f, indent=1)
    print(f"trees {w}x{h} stride {stride}, floor {wide}x{tall}: {list(rects)}")


if __name__ == "__main__":
    main()

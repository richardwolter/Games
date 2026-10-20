#!/usr/bin/env python
"""The honey coin (2026-10-18, the hive's visual overhaul; Richard's pick 4A off
tools/hive_look/last_honey.png): the honey's share of a catch, paid on the spot, flying from the
net to the purse as a coin of its own.

Drawn by rule, not recoloured: the gold coin recoloured a step down read as the same coin in
another hue. This one is struck differently, on the gold coin's own nine widths (face on, edge
on at frame 4, the back at 8):
  - a thick HONEY_DEEP rim, two px, lit HONEY_MID on its top-left half;
  - an amber HONEY face with a HONEY_LIGHT crescent and a shine pixel top left;
  - a comb cell for its stamp (a pointy-topped hex in HONEY_DEEP, honey inside, a lit lip
    under it) where the money's coin has the recycle arrows;
  - a drop of honey clinging to its trailing (lower-right) rim on the face frames, gone edge on;
  - the one-pixel near-black outline every sprite wears.
And three 2x2 trail drops, inked, at three hard alpha steps (255, 170, 95): what it leaves on
its arc.

The port of `honey_coin2` and `trail_drop` in tools/hive_look/honey_parts.py, so the coin in
the game is the coin that was picked.

Writes assets/honey_coin.png and assets/honey_coin.json (read by CoinFly). Run from the
project root, base python with the psd-extract venv's site-packages on PYTHONPATH, then
reimport:
    python tools/build_honey_coin.py
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PNG = os.path.join(ROOT, "assets", "honey_coin.png")
OUT_JSON = os.path.join(ROOT, "assets", "honey_coin.json")

OUT = (24, 18, 17, 255)                # the hut's and the box's near-black outline
HONEY_DEEP = (150, 72, 12, 255)        # build_hive's honey, HiveArt.HONEY_*
HONEY_MID = (206, 120, 22, 255)
HONEY = (238, 164, 38, 255)
HONEY_LIGHT = (252, 204, 84, 255)
HONEY_SHINE = (255, 242, 190, 255)

COIN_WIDTHS = [20, 16, 11, 7, 6, 7, 11, 16, 20]
TURNS = [1.0, 0.75, 0.5, 0.25, 0.0, -0.25, -0.5, -0.75, -1.0]   # coin.json's own
CELL = 24                               # one frame's canvas
MIDDLE = (12, 10)                       # the disc's middle in it
HEX = {   # pointy-topped comb cells, at the face's three widths
    8: ["...x...", ".xx.xx.", "x.....x", "x.....x", "x.....x", ".xx.xx.", "...x..."],
    6: ["..x..", ".x.x.", "x...x", "x...x", "x...x", ".x.x.", "..x.."],
    4: [".x.", "x.x", "x.x", "x.x", ".x."],
}
TRAIL_ALPHA = (255, 170, 95)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def grid(rows, key):
    im = Image.new("RGBA", (max(len(r) for r in rows), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in key:
                im.putpixel((x, y), key[ch])
    return im


def inked(im, col=OUT):
    """The game's one-pixel outline round everything opaque: one pixel bigger all round."""
    w, h = im.size
    body = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    body.paste(im, (1, 1))
    a = body.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = a
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown = ImageChops.lighter(grown, ImageChops.offset(a, dx, dy))
    ring = ImageChops.subtract(grown, a)
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (w + 2, h + 2), col), (0, 0), ring)
    out.alpha_composite(body)
    return out


def _disc(w, h=20):
    cx, cy = w / 2.0, h / 2.0
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            if ((x + 0.5 - cx) / (w / 2.0)) ** 2 + ((y + 0.5 - cy) / (h / 2.0)) ** 2 < 1.0:
                m[y, x] = True
    return m


def _edge(m):
    e = np.zeros_like(m)
    h, w = m.shape
    for y in range(h):
        for x in range(w):
            if m[y, x]:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or not m[ny, nx]:
                        e[y, x] = True
                        break
    return e


def coin(frame):
    """Frame 0..8 on a CELL x CELL canvas, the disc's middle at MIDDLE."""
    w = COIN_WIDTHS[frame]
    back = frame >= 5
    m = _disc(w)
    o = _edge(m)
    inner = m & ~o
    r1 = inner & _edge(inner)
    inner2 = inner & ~r1
    r2 = inner2 & _edge(inner2) if w >= 11 else inner2
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    ox = MIDDLE[0] - w // 2
    cx, cy = w / 2.0, 10.0
    face_col = mix(HONEY, HONEY_MID, 0.35) if back else HONEY
    for y in range(20):
        for x in range(w):
            if not m[y, x]:
                continue
            lit = (x + 0.5 - cx) + (y + 0.5 - cy) < -1.0
            if o[y, x]:
                c = OUT
            elif r1[y, x] or r2[y, x]:
                c = HONEY_MID if lit else HONEY_DEEP
                if w < 11 and not back and x == int(cx) - 1:
                    c = HONEY        # edge on: a lit band down the thickness
            else:
                c = face_col
                d = math.hypot((x + 0.5 - cx) / (w / 2.0), (y + 0.5 - cy) / 10.0)
                if lit and d > 0.45 and not back:
                    c = HONEY_LIGHT
            im.putpixel((ox + x, y), c)
    if w >= 11:
        rows = HEX[8 if w >= 20 else (6 if w >= 16 else 4)]
        hexw = len(rows[0])
        hx = ox + (w - hexw) // 2
        hy = 10 - len(rows) // 2
        stamp = HONEY_DEEP if not back else mix(HONEY_DEEP, OUT, 0.3)
        for j, row in enumerate(rows):
            inside = [i for i, ch in enumerate(row) if ch == "x"]
            for i, ch in enumerate(row):
                if ch == "x":
                    im.putpixel((hx + i, hy + j), stamp)
                    # the lit lip under the stamp's lower edges
                    if (j >= len(rows) - 2 and not back
                            and im.getpixel((hx + i, hy + j + 1))[:3] == face_col[:3]):
                        im.putpixel((hx + i, hy + j + 1), HONEY_LIGHT)
            if 0 < j < len(rows) - 1 and len(inside) == 2:
                for i in range(inside[0] + 1, inside[1]):
                    im.putpixel((hx + i, hy + j), HONEY_LIGHT if not back else HONEY)
        if not back and hexw >= 5:
            im.putpixel((hx + 2, hy + 2), HONEY_SHINE)
    if not back and w >= 16:
        im.putpixel((ox + int(w * 0.28), 4), HONEY_SHINE)
    if w >= 16 and not back:
        # the drop clinging to the lower-right rim: a 2x2 bead, inked, tucked onto the outline
        bx = ox + int(round(cx + w * 0.22))
        d = inked(grid(["lm", "md"], {"l": HONEY_LIGHT, "m": HONEY_MID, "d": HONEY_DEEP}))
        im.alpha_composite(d, (bx - 1, 17))
    return im


def trail_drop(step):
    d = inked(grid(["lm", "md"], {"l": HONEY_LIGHT, "m": HONEY_MID, "d": HONEY_DEEP}))
    a = np.array(d)
    a[..., 3] = (a[..., 3] > 0) * TRAIL_ALPHA[step]
    return Image.fromarray(a)


def main():
    frames = [coin(f) for f in range(len(COIN_WIDTHS))]
    drops = [trail_drop(k) for k in range(len(TRAIL_ALPHA))]
    sheet = Image.new("RGBA", (CELL * len(frames), CELL + 6), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * CELL, 0))
    drop_rects = []
    for k, d in enumerate(drops):
        at = (k * 6, CELL + 1)
        sheet.alpha_composite(d, at)
        drop_rects.append([at[0], at[1], d.width, d.height])
    sheet.save(OUT_PNG)
    with open(OUT_JSON, "w", newline="\n") as f:
        json.dump({
            "design": "honey comb cell",
            "frame": [CELL, CELL],
            "middle": list(MIDDLE),
            "turns": TURNS,
            "drops": drop_rects,
            "drop_alpha": list(TRAIL_ALPHA),
        }, f, indent=1)
    print("wrote", OUT_PNG, sheet.size)


if __name__ == "__main__":
    main()

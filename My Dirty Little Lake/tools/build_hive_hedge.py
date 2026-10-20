#!/usr/bin/env python
"""The hive room's hedge: the low bed of the island's flowers along the window's foot.

Run from the project root with base python and the psd-extract venv's site-packages on
PYTHONPATH, and **reimport after**:

  PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
      python tools/build_hive_hedge.py

Writes:
  assets/hive_hedge.png    the bed at one painted pixel a pixel, PERIOD wide, its bottom row
                           the window's foot. It wraps left to right.
  assets/hive_hedge.json   its size, and every flower pixel a bee may work (`heads`, flat
                           x, y pairs on the strip).
  tools/last_hive_hedge.png  a contact sheet over the lawn, 3x.

Option A, "LOW HEDGE", of `tools/hive_look/last_backdrop.png` (Richard's pick, 2026-10-18),
built by the mockup's own rules (`tools/hive_look/backdrop_mockup.py`, `bed_A` and
`bed_layer`): real pieces of `assets/flora.png`, planted in drifts of one colour family in
brick-laid rows, graded by depth (the 3x5 heads at the back, the pack's clumps and the 5x7
tulips in the middle, four rows of the 7x8 discs and 6x6 crosses at the foot), on a two-step
leaf body (`grass_dark`, and that taken towards the outline ink) filling the gaps, the whole
mass ringed once in the game's outline, open at the foot.

**Periodic, so a wide window tiles it**: the mockup laid one 640-wide bed; here the pieces
whose feet fall in one period are laid three times side by side, the mass is closed and
ringed on all three, and the middle period is kept, so its two ends meet.
"""
import json
import os
import random
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PERIOD = 640
GRID_H = 360
# Bees work only heads at least this far above the window's foot (the mockup's own margin).
HEADS_ABOVE_FOOT = 4
OUT = (24, 18, 17, 255)

CLUMP = {"white": "pk_bed_0", "pink": "pk_bed_1", "blue": "pk_bed_7", "yellow": "pk_bed_3",
         "lilac": "pk_bed_1"}
BIG = {"white": ["pk_flower_0", "pk_flower_3", "pk_flower_2"],
       "pink": ["pk_flower_4"],
       "blue": ["pk_flower_1", "pk_flower_6"],
       "yellow": ["pk_flower_8", "pk_flower_3"],
       "lilac": ["pk_flower_5", "pk_flower_7"]}
MID = {"white": ["pk_flower_13"], "pink": ["pk_flower_9"], "blue": ["pk_flower_12"],
       "yellow": ["pk_flower_8"], "lilac": ["pk_flower_7"]}
SMALL = {"white": ["pk_flower_15", "clover_white"], "pink": ["clover_pink", "thrift"],
         "blue": ["pk_flower_14"], "yellow": ["pk_flower_10"], "lilac": ["pk_flower_11"]}
GREEN_BODY = ["pk_leafy_a", "pk_fern", "pk_leafy_b"]
FRONT_CLUMPS = 0.28
DRIFT_ORDER = ["blue", "white", "pink", "yellow", "lilac", "white", "pink", "blue", "yellow"]


def palette(name):
    text = open(os.path.join(ROOT, "resources/palette.tres"), encoding="utf-8").read()
    m = re.search(r"^%s = Color\(([^)]*)\)" % re.escape(name), text, re.M)
    r, g, b = (float(v) for v in m.group(1).split(",")[:3])
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


LEAF_LIT = palette("grass_dark")
LEAF_DEEP = mix(LEAF_LIT, OUT, 0.45)

_FLORA = json.load(open(os.path.join(ROOT, "assets/flora.json")))
_SHEET = Image.open(os.path.join(ROOT, "assets/flora.png")).convert("RGBA")


def flora(name):
    x, y, w, h = _FLORA[name]["full"]
    return _SHEET.crop((x, y, x + w, y + h))


def _hash(x, y, s=0):
    v = ((int(x) * 73856093) ^ (int(y) * 19349663) ^ (int(s) * 83492791)) & 0xffffffff
    v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
    return ((v ^ (v >> 16)) & 0xffff) / 65535.0


# --- the layout: backdrop_mockup.bed_A, word for word --------------------------------------

def drift_map(rng, x0=-40, x1=700, span=(30, 52), order=DRIFT_ORDER, start=0):
    out = []
    x = x0
    k = start
    while x < x1:
        w = rng.uniform(*span)
        out.append((x, x + w, order[k % len(order)]))
        x += w
        k += 1
    return out


def family_at(drifts, x):
    for a, b, fam in drifts:
        if a <= x < b:
            return fam
    return drifts[-1][2]


def pool_of(kind, fam, rng, filler):
    if kind == "green":
        return GREEN_BODY
    if kind == "clump":
        return [CLUMP[fam]]
    if kind == "big":
        if rng.random() < FRONT_CLUMPS:
            return [CLUMP[fam]]
        return BIG["white"] if rng.random() < filler else BIG[fam]
    if kind == "mid":
        return MID["white"] if rng.random() < filler else MID[fam]
    return SMALL[fam]


def drift_rows(rng, rows, drifts, filler=0.08, lean=5):
    out = []
    for i, (fy, x0, x1, step, kind, jit) in enumerate(rows):
        x = x0 + ((i % 2) * 0.5 + rng.uniform(0, 0.15)) * step
        last = None
        while x <= x1:
            fam = family_at(drifts, x + i * lean)
            pool = pool_of(kind, fam, rng, filler)
            choices = [p for p in pool if p != last] or pool
            name = rng.choice(choices)
            last = name
            fx = int(round(x + rng.uniform(-jit, jit)))
            fyy = int(round(fy + rng.uniform(-jit * 0.4, jit * 0.4)))
            out.append((name, fx, fyy))
            x += step * rng.uniform(0.92, 1.08)
    return out


def bed_A():
    rng = random.Random(21)
    drifts = drift_map(rng, span=(44, 70))
    return drift_rows(rng, [
        (338, -6, 650, 6, "small", 1),
        (343, -14, 656, 17, "clump", 2),
        (345, -6, 650, 8, "mid", 1),
        (350, -2, 646, 9, "big", 1),
        (355, -6, 652, 9, "big", 1),
        (360, -2, 646, 9, "big", 1),
        (365, -6, 652, 9, "big", 1),
    ], drifts, lean=4)


# --- masks on plain lists ---------------------------------------------------------------------

def dilate(m, w, h, rx, ry):
    out = [row[:] for row in m]
    for y in range(h):
        for x in range(w):
            if out[y][x]:
                continue
            hit = False
            for dy in range(-ry, ry + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                row = m[yy]
                for dx in range(-rx, rx + 1):
                    xx = x + dx
                    if 0 <= xx < w and row[xx]:
                        hit = True
                        break
                if hit:
                    break
            out[y][x] = hit
    return out


def erode(m, w, h, rx, ry):
    inv = [[not v for v in row] for row in m]
    d = dilate(inv, w, h, rx, ry)
    return [[not v for v in row] for row in d]


def fill_holes(m, w, h):
    """`m` with every clear pixel not reachable from the top, left or right edge filled."""
    reach = [[False] * w for _ in range(h)]
    stack = []
    for x in range(w):
        if not m[0][x]:
            stack.append((0, x))
    for y in range(h):
        for x in (0, w - 1):
            if not m[y][x]:
                stack.append((y, x))
    while stack:
        y, x = stack.pop()
        if reach[y][x] or m[y][x]:
            continue
        reach[y][x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and not reach[yy][xx] and not m[yy][xx]:
                stack.append((yy, xx))
    return [[m[y][x] or not reach[y][x] for x in range(w)] for y in range(h)]


def is_flower(c):
    r, g, b, a = c
    if a < 200:
        return False
    if g > r + 6 and g > b + 6:
        return False
    return r + g + b >= 150


def build():
    layout = [(n, x, y) for n, x, y in bed_A() if 0 <= x < PERIOD]
    wide = PERIOD * 3
    tall = GRID_H + 24
    pieces = Image.new("RGBA", (wide, tall), (0, 0, 0, 0))
    for name, fx, fy in sorted(layout, key=lambda t: (t[2], t[1])):
        im = flora(name)
        for shift in (0, PERIOD, 2 * PERIOD):
            pieces.alpha_composite(im, (fx + shift - im.width // 2, fy - im.height))
    # Only the rows the bed can reach are worked on.
    top = min(fy - flora(n).height for n, _, fy in layout) - 6
    band = pieces.crop((0, top, wide, tall))
    w, h = band.size
    px = band.load()
    M = [[px[x, y][3] > 40 for x in range(w)] for y in range(h)]
    S = erode(dilate(M, w, h, 2, 1), w, h, 2, 1)
    S = [[S[y][x] or M[y][x] for x in range(w)] for y in range(h)]
    S = fill_holes(S, w, h)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            if M[y][x]:
                c = px[x, y]
                op[x, y] = c[:3] + (255,)
            elif S[y][x]:
                above_out = y == 0 or not S[y - 1][x]
                above_piece = y > 0 and M[y - 1][x]
                if above_out:
                    c = LEAF_LIT
                elif above_piece:
                    c = LEAF_DEEP
                else:
                    c = LEAF_LIT if _hash((x + 2 * ((y // 2) % 2)) // 3, y // 2, 7) < 0.34 else LEAF_DEEP
                op[x, y] = c
    # The ring, open at a flat foot.
    solid = [[op[x, y][3] > 40 for x in range(w)] for y in range(h)]
    ring = []
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            up = y > 0 and solid[y - 1][x]
            down = y < h - 1 and solid[y + 1][x]
            left = x > 0 and solid[y][x - 1]
            right = x < w - 1 and solid[y][x + 1]
            if not (up or down or left or right):
                continue
            if up and not down and not left and not right:
                continue
            ring.append((x, y))
    for x, y in ring:
        op[x, y] = OUT
    # The middle period, down to the window's foot.
    foot = GRID_H - top
    strip = out.crop((PERIOD, 0, 2 * PERIOD, foot))
    bbox = strip.getbbox()
    cut = bbox[1] if bbox else 0
    strip = strip.crop((0, cut, PERIOD, foot))
    sp = strip.load()
    heads = []
    for y in range(strip.height - HEADS_ABOVE_FOOT):
        for x in range(PERIOD):
            if is_flower(sp[x, y]):
                heads += [x, y]
    return strip, heads


def main():
    strip, heads = build()
    strip.save(os.path.join(ROOT, "assets/hive_hedge.png"))
    with open(os.path.join(ROOT, "assets/hive_hedge.json"), "w", encoding="utf-8") as f:
        json.dump({"period": PERIOD, "tall": strip.height, "heads": heads}, f)
    lawn = Image.open(os.path.join(ROOT, "assets/wash_lawn.png")).convert("RGBA")
    sheet = Image.new("RGBA", (PERIOD + PERIOD // 2, strip.height + 20), (0, 0, 0, 255))
    for x in range(0, sheet.width, lawn.width):
        sheet.alpha_composite(lawn.crop((0, lawn.height - sheet.height, lawn.width, lawn.height)), (x, 0))
    sheet.alpha_composite(strip, (0, 20))
    sheet.alpha_composite(strip, (PERIOD, 20))
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(os.path.join(ROOT, "tools/last_hive_hedge.png"))
    print("hedge %dx%d, %d heads" % (strip.width, strip.height, len(heads) // 2))


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""Draw the water pump that stands beside the hut.

Issue #37 (`/grill-me` with Richard, 2026-09-18): a find is washed before it goes in the
shed, and this is the thing on the island the player walks up to for it. An old cast-iron
hand pump on a deck of the hut's own oak, a bucket under its spout, and the wash nozzle's
canvas hose coiled on a peg at its side: the hose is what says this pump and that nozzle are
one machine.

**Redrawn at the hut's grain** (2026-10-01, `/grill-me` with Richard): one world px an art
px, so `Pump.ART_SCALE` is 1.0; then taken down to three quarters of that and dulled
(Richard, same day: too big, too bright and too glossy beside the hut). The
wood is the hut's own ramp (`build_shed_v2.WALL`), the hose the wash room's canvas
(`assets/nozzle.json`'s inks) and the nozzle its brass on an oak grip, the outline the hut's
near-black. One picture all run, no meter stages, by decision.

Built from rules, not painted: shapes on whole pixels, lit from the right like every painted
asset in the game. Richard may polish the PNG after ("rules first, polish after"); the json
holds while the size does.

Output:
  assets/pump.png             the pump, front-on, one world px to a painted one (38x44)
  assets/pump.json            its size, and the share of its height under its foot
  tools/last_pump_sheet.png   at 8x over lawn green, for looking at

Run from the project root, with the psd-extract venv's site-packages on PYTHONPATH:
  python tools/build_pump.py
Reimport afterwards:
  <godot> --path . --headless --import
"""

from __future__ import annotations

import json
import os

from PIL import Image

from build_hive import Art, inked, OUT
from build_nozzle import BRASS, palette_colour
from build_shed_v2 import WALL, mix

ASSET = os.path.join("assets", "pump.png")
CONTRACT = os.path.join("assets", "pump.json")
SHEET = os.path.join("tools", "last_pump_sheet.png")

## Cast iron is not in the pack's palette; authored. Deep, shade, body, lit, shine. Kept dark
## and close together (2026-10-01, Richard: the first cut read brighter and glossier than the
## hut): matte iron, the lightest step used only on a few edge pixels.
IRON = [(26, 28, 32), (40, 45, 50), (54, 61, 67), (70, 78, 84), (88, 96, 100)]
## The wash room's canvas hose, taken down towards the hut's wood so it sits with it.
HOSE = [(96, 84, 64), (128, 112, 84), (156, 138, 104)]

## The raw canvas, before the outline adds a pixel all round: three quarters of the first
## cut, which stood as tall as a walker and read as a machine rather than a garden pump.
W, H = 36, 42
## The deck's top diamond: its middle, half width and half height (2:1, as the hut's are),
## and how thick it is.
DECK = (18, 33)
DECK_HALF = (12, 6)
DECK_THICK = 2

SHEET_ZOOM = 8
LAWN = (86, 125, 70)


def a4(c):
    return tuple(c[:3]) + (255,)


def wood(t):
    """The hut's wall ramp at a whole step, clamped."""
    return a4(WALL[max(0, min(6, t))])


def deck(a):
    cx, cy = DECK
    hw, hh = DECK_HALF
    L, T, R, B = (cx - hw, cy), (cx, cy - hh), (cx + hw, cy), (cx, cy + hh)

    def top(x, y):
        # boards running along the T-R edge, a seam every third row
        t = y + 0.5 * (x - cx)
        row = int((t - (cy - hh)) // 3)
        pr = (t - (cy - hh)) % 3
        tone = 3 - (pr < 1) - (row % 3 == 1) * 0
        if int(x + row * 5) % 11 == 0 and pr >= 1:
            tone -= 1
        return wood(tone)

    a.fill_by([L, T, R, B], top)
    a.poly([L, B, (B[0], B[1] + DECK_THICK), (L[0], L[1] + DECK_THICK)], wood(1))
    a.poly([B, R, (R[0], R[1] + DECK_THICK), (B[0], B[1] + DECK_THICK)], wood(2))
    for x in range(L[0], R[0] + 1):
        a.px(x, B[1] - abs(x - cx) // 2, wood(4))


def bucket(a):
    """An oak bucket by the deck under the spout: staves, two iron hoops, water in it."""
    x0, x1 = 3, 10
    top, bot = 26, 34
    for x in range(x0, x1 + 1):
        u = (x - x0) / (x1 - x0)
        sag = int(round(1.0 * (1 - (2 * u - 1) ** 2)))
        for y in range(top + 1, bot + sag):
            t = 1 + (u > 0.5) + (u > 0.85) - ((x - x0) % 3 == 0)
            a.px(x, y, wood(t))
        for hy in (top + 2, bot - 2):
            a.px(x, hy + int(round(0.8 * (1 - (2 * u - 1) ** 2))), a4(IRON[1 + (u > 0.6)]))
    water = palette_colour("water_clean")
    for x in range(x0, x1 + 1):
        a.px(x, top, wood(3))
    for x in range(x0 + 1, x1):
        a.px(x, top + 1, a4(mix(water, WALL[1], 0.25)))
    a.px(x0 + 5, top + 1, a4(mix(water, (220, 235, 240), 0.35)))


def pump(a):
    cx = 19
    # the flange it is bolted down with
    for x in range(cx - 4, cx + 5):
        t = 1 + (x > cx - 1) + (x > cx + 2)
        for y in range(29, 32):
            a.px(x, y, a4(IRON[t]))
    # the column, lit down its right side
    shade = {-2: 1, -1: 2, 0: 2, 1: 3, 2: 1}
    for y in range(12, 29):
        for dx, t in shade.items():
            a.px(cx + dx, y, a4(IRON[t]))
    for x in range(cx - 3, cx + 4):
        a.px(x, 20, a4(IRON[2 + (x > cx)]))
        a.px(x, 21, a4(IRON[1]))
    # the cap: a dome and a knob
    for y, half in ((11, 3), (10, 3), (9, 2), (8, 1)):
        for x in range(cx - half, cx + half + 1):
            a.px(x, y, a4(IRON[1 + (x >= cx) + (x == cx + 1)]))
    a.px(cx, 7, a4(IRON[3]))
    # the spout, out to the left and down over the bucket
    for x in range(8, cx - 2):
        a.px(x, 15, a4(IRON[3]))
        a.px(x, 16, a4(IRON[1]))
    for y in range(15, 21):
        a.px(6, y, a4(IRON[1]))
        a.px(7, y, a4(IRON[2]))
    for x in range(5, 9):
        a.px(x, 21, a4(IRON[2 if x > 6 else 1]))
    water = palette_colour("water_clean")
    a.px(6, 23, a4(mix(water, (220, 235, 240), 0.3)))
    # the handle: a pivot on the cap, the lever up and out, an oak grip
    a.px(cx + 3, 9, a4(IRON[3]))
    a.px(cx + 3, 10, a4(IRON[1]))
    for i in range(10):
        x = cx + 3 + i
        y = 9 - int(i * 0.6)
        a.px(x, y, a4(IRON[2]))
        a.px(x, y + 1, a4(IRON[0]))
    for i in range(4):
        x = cx + 13 + i
        y = 3 - int(i * 0.5)
        a.px(x, y, wood(4))
        a.px(x, y + 1, wood(2))


def hose(a):
    """The canvas hose coiled on a peg on the column, the loops hanging from the peg, its end
    hanging down with the brass nozzle on its oak grip, as the wash room draws them."""
    import math
    py = 16
    sizes = ((3.0, 3.0), (3.8, 4.0), (4.5, 5.0))
    loops = [(27 + i * 0.5, py + 1 + ry, rx, ry) for i, (rx, ry) in enumerate(sizes)]
    for half in ("back", "front"):
        for i, (cx, cy, rx, ry) in enumerate(loops):
            for k in range(120):
                th = k / 120 * math.tau
                front = math.sin(th) > 0
                if (half == "front") != front:
                    continue
                x = cx + math.cos(th) * rx
                y = cy + math.sin(th) * ry
                lit = math.cos(th) * 0.8 - math.sin(th) * 0.6
                t = 2 if lit > 0.4 else 0 if lit < -0.4 else 1
                if not front:
                    t = max(0, t - 1)
                a.px(x, y, a4(HOSE[t]))
    for x in range(22, 28):
        a.px(x, py, a4(IRON[2]))    # the peg
    # the end, off the biggest loop's right side and hanging straight down
    for y in range(22, 28):
        a.px(31, y, a4(HOSE[1]))
        a.px(32, y, a4(HOSE[2]))
    a.px(31, 28, wood(2))
    a.px(32, 28, wood(3))
    brass = [a4(c) for c in BRASS]
    for y, row in ((29, (0, 1, 2)), (30, (0, 1)), (31, (0,))):
        for i, t in enumerate(row):
            a.px(31 + i, y, brass[t])


def draw():
    a = Art(W, H)
    deck(a)
    bucket(a)
    pump(a)
    hose(a)
    return inked(a.im, OUT)


def ground(picture):
    """The share of the picture's height under the deck's middle, plus a pixel: the foot."""
    return round((picture.height - (DECK[1] + 1)) / picture.height, 4)


def main():
    picture = draw()
    picture.save(ASSET)
    with open(CONTRACT, "w", encoding="utf-8", newline="\n") as out:
        json.dump({"size": [picture.width, picture.height], "ground": ground(picture)}, out, indent=1)
        out.write("\n")
    look = Image.new("RGBA", (picture.width * SHEET_ZOOM, picture.height * SHEET_ZOOM), LAWN + (255,))
    look.alpha_composite(picture.resize(look.size, Image.NEAREST))
    look.save(SHEET)
    print("pump: %dx%d" % picture.size)


if __name__ == "__main__":
    main()

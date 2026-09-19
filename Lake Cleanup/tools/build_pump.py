#!/usr/bin/env python
"""Draw the water pump that stands beside the hut, and the wash room's stand.

Issue #37 (`/grill-me` with Richard, 2026-09-18): a find is washed before it goes in the
shed, and this is the thing on the island the player walks up to for it. An old cast-iron
hand pump on a plank of the recycle box's own wood, a bucket under its spout, and the wash
nozzle's canvas hose coiled on a peg at its side — the hose is what says this pump and that
nozzle are one machine.

Built from rules rather than painted, like the piers, the cursor and the nozzle: authored
as rows of letters, one per painted pixel, and inked here. The letters name a material and
how lit it is; the light is on the right, as it is on everything painted in this game. A
one-pixel outline in the box's own edge colour goes round the lot afterwards. Richard
polishes the PNG after ("rules first, polish after"); the json holds while the size does.

Output:
  assets/pump.png             the pump, front-on, drawn at 2 world px to a painted one
  assets/pump.json            its size, and how far up the picture its foot stands
  tools/last_pump_sheet.png   at 8x over lawn green, for looking at

Run from the project root:
  <psd-extract venv python> tools/build_pump.py

Reimport afterwards, as every builder here needs:
  <godot> --path . --headless --import
"""

from __future__ import annotations

import json
import os
from PIL import Image

from build_nozzle import BRASS, EDGE, box_browns, palette_colour, scaled

ASSET = os.path.join("assets", "pump.png")
CONTRACT = os.path.join("assets", "pump.json")
SHEET = os.path.join("tools", "last_pump_sheet.png")

## Cast iron is not in the pack's palette; authored. Shade, body, lit, shine.
IRON = [(38, 46, 54), (62, 74, 84), (96, 112, 122), (150, 168, 176)]

## One letter a painted pixel. `.` clear. Iron: `i` shade, `I` body, `J` lit, `K` shine.
## Wood: `w` dark, `W` body, `X` lit. Brass band: `b` / `B`. Canvas hose: `h` dark, `H` body,
## `G` lit. Water in the bucket: `~`. The handle's wooden grip is wood.
ART = [
    "...............XX.....",
    "..............WXX.....",
    ".............iIJ......",
    "............iIJ.......",
    ".......iIJ.iIJ........",
    "......iIIJKIJ.........",
    "......iIIIJJ..........",
    ".......iIJJ...........",
    ".......iIJK...........",
    "..iiIIIiIJK...........",
    ".iIIIJJiIJKhHG........",
    ".iIJ...iIJhHhHG.......",
    ".iJ....iIJhH.hHG......",
    ".......iIJhH.hHG......",
    ".......iIJhHGhHG......",
    ".......iIJKhHHG.......",
    ".......iIJK.hG........",
    "WbBBbX.iIJK...........",
    "W~~~~X.iIJK...........",
    "wWWWWX.iIJK...........",
    "wbBBBX.iIJK...........",
    "wWWWWXiIIJJK..........",
    ".wWWXiIIIIJJK.........",
    "..wWWWWWWWWWXXX.......",
    "..wwWWWWWWWWWXX.......",
]

## How many of the picture's bottom rows are the plank it stands on: the foot, for the grass
## and the shadow, is the top of that.
FOOT_ROWS = 2

SHEET_ZOOM = 8
LAWN = (86, 125, 70)


def main():
    browns = box_browns()
    sand = palette_colour("sand")
    water = palette_colour("water_clean")
    inks = {
        "i": IRON[0], "I": IRON[1], "J": IRON[2], "K": IRON[3],
        "w": browns[0], "W": browns[2], "X": browns[3],
        "b": BRASS[0], "B": BRASS[2],
        "h": scaled(sand, 0.5), "H": scaled(sand, 0.68), "G": scaled(sand, 0.84),
        "~": water,
    }
    tall = len(ART)
    wide = max(len(row) for row in ART)
    # A pixel of margin all round, which is where the outline goes.
    picture = Image.new("RGBA", (wide + 2, tall + 2), (0, 0, 0, 0))
    px = picture.load()
    for y, row in enumerate(ART):
        for x, letter in enumerate(row):
            if letter != ".":
                px[x + 1, y + 1] = inks[letter] + (255,)
    ring = []
    for y in range(picture.height):
        for x in range(picture.width):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < picture.width and 0 <= yy < picture.height and px[xx, yy][3] != 0:
                    ring.append((x, y))
                    break
    for x, y in ring:
        px[x, y] = EDGE + (255,)
    picture.save(ASSET)
    with open(CONTRACT, "w", encoding="utf-8", newline="\n") as out:
        json.dump({
            "size": [picture.width, picture.height],
            "ground": round((FOOT_ROWS + 1) / picture.height, 4),
        }, out, indent=1)
        out.write("\n")
    look = Image.new("RGBA", (picture.width * SHEET_ZOOM, picture.height * SHEET_ZOOM), LAWN + (255,))
    look.alpha_composite(picture.resize(look.size, Image.NEAREST))
    look.save(SHEET)
    print("pump: %dx%d" % picture.size)


if __name__ == "__main__":
    main()

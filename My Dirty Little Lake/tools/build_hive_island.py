#!/usr/bin/env python
"""The island beehive's picture (2026-10-18, the hive's visual overhaul, Richard's pick "Hive C"
off tools/hive_look/last_island.png): the hive 1.4x, its stand a sky-blue painted cupboard with
two shelves on each seen face, and the jars the player holds standing on them, three a shelf, up
to twelve. No separate shelf on the lawn. Beside it the young flowering tree the swarm hangs
from.

Writes assets/hive.png and assets/hive.json (the contract scripts/hive.gd reads), and
tools/last_hive_island.png (every frame at 4x on grass, for checking).

**Drawn by the mockup's own functions** (tools/hive_look/island_mockup.py, which imports
build_hive for the paint, roof, oak and honey ramps): what Richard picked is what ships. Nothing
here is drawn twice. This builder never calls build_hive's main(), which would overwrite this
sheet with the old island picture.

**The jars are not baked.** The game draws `HoneyPot`'s `shelf` jar (`shelf_shade` on the shaded
face) at every slot up to `Hive.jars`, so the count reads one jar at a time. The json's
`jar_slots` are the feet pixels, in fill order: the lit face's top shelf, the shaded face's top
shelf, then the two bottom shelves.

**The window is baked in five levels** (`hive_colony0..4`), the mockup's stepped honey under its
pale meniscus; `hive_full` is level four with the drip off the board (honey ready).

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/build_hive_island.py
then reimport (Godot --path . --headless --import).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "hive_look"))
import island_mockup as im_  # noqa: E402

bh = im_.bh
SHEET = os.path.join(ROOT, "assets", "hive.png")
CONTRACT = os.path.join(ROOT, "assets", "hive.json")
CHECK = os.path.join(HERE, "last_hive_island.png")

# Where the tree stands off the hive's foot, world px (one world px an art px): option C's
# layout on the sheet, plate px over two.
TREE_AT = ((im_.LAYOUT["C"]["shrub"][0] - im_.LAYOUT["C"]["hive"][0]) // im_.G,
           (im_.LAYOUT["C"]["shrub"][1] - im_.LAYOUT["C"]["hive"][1]) // im_.G)
LEVELS = im_.WIN_LEVELS          # 4: the window's honey in four steps; 0 is the empty pane
TILE_W, TILE_H = 64.0, 32.0      # Iso.TILE_W / TILE_H
WHITE = (255, 255, 255, 255)


def hive_at_level(level, state="colony", drip=False):
    """The 1.4x hive on its cupboard, empty shelves, the window at `level`. The mockup picks the
    level off its share through `win_level`; here every level is wanted, so it is pinned."""
    saved = im_.win_level
    im_.win_level = lambda s, share: level if s != "weathered" else 0
    try:
        return im_.draw_hive(state, 0.5, stand="shelves", jars=0, drip=drip, drip_long=1)
    finally:
        im_.win_level = saved


def silhouette(im, minus=None):
    a = np.array(im.getchannel("A")) > 40
    if minus is not None:
        a &= ~(np.array(minus.getchannel("A")) > 40)
    out = np.zeros(a.shape + (4,), np.uint8)
    out[a] = WHITE
    return Image.fromarray(out, "RGBA")


def pack(frames):
    """Shelf-pack named images onto one sheet with a 1 px gutter. Returns (sheet, rects)."""
    wide = 360
    x = y = 1
    row = 0
    places = {}
    for name, im in frames:
        if x + im.width + 1 > wide:
            x, y = 1, y + row + 1
            row = 0
        places[name] = (x, y, im.width, im.height)
        x += im.width + 1
        row = max(row, im.height)
    sheet = Image.new("RGBA", (wide, y + row + 1), (0, 0, 0, 0))
    for name, im in frames:
        px, py, _, _ = places[name]
        sheet.alpha_composite(im, (px, py))
    return sheet, places


def tile_of(dx, dy):
    """World px off the node -> tiles off its tile (Iso's 2:1 plane)."""
    a = dx / (TILE_W * 0.5)
    b = dy / (TILE_H * 0.5)
    return ((a + b) * 0.5, (b - a) * 0.5)


def main():
    weathered, g = im_.draw_hive("weathered", 0.5, stand="shelves", jars=0)
    colony = [hive_at_level(k)[0] for k in range(LEVELS + 1)]
    full, _ = hive_at_level(LEVELS, "full", drip=True)
    size = weathered.size
    for im in colony + [full]:
        assert im.size == size, "every hive frame on one canvas"
    # The inked picture is one pixel bigger all round than the drawing.
    foot = (g.origin[0] + 1, g.origin[1] + 1)

    bare, tfoot, hang, _, _ = im_.shrub(blossom=False, swarm=False)
    bloom, _, _, _, _ = im_.shrub(blossom=True, swarm=False)
    swarm, _, _, _, _ = im_.shrub(blossom=True, swarm=True)
    assert bare.size == bloom.size == swarm.size
    mass, (mx, my) = im_.swarm_mass()
    mbox = mass.getbbox()
    swarm_px = (hang[0] - mx + mbox[0], hang[1] - my + mbox[1], mbox[2] - mbox[0],
                mbox[3] - mbox[1])

    ready, ready_mid = im_.ready_mark()

    frames = [("hive_weathered", weathered)]
    frames += [("hive_colony%d" % k, im) for k, im in enumerate(colony)]
    frames += [("hive_full", full), ("tree_bare", bare), ("tree_bloom", bloom),
               ("tree_swarm", swarm), ("tree_sil", silhouette(bloom)),
               ("swarm_sil", silhouette(swarm, bloom)), ("ready", ready)]
    sheet, rects = pack(frames)
    sheet.save(SHEET)

    # The jars' feet pixels on the inked hive picture, fill order (c_slots), and which face.
    slots = []
    for x0, y, shaded in im_.c_slots(g):
        slots.append([x0 + 4, y + 1, 1 if shaded else 0])

    # The landing board's middle, and how high it stands over the lawn below it: the ground
    # under the lit face at that column is the cupboard's foot there, plus its legs.
    ex, ey = g.entrance()
    ground_y = g.c + 14 - (ex - 1 - g.cx) // 2 + g.box + g.legs + 1
    deepest = size[1] - 1
    contract = {
        "size": list(size),
        "foot": list(foot),
        # How much of the picture's height is below the walls' ground line (Shade.sweep's
        # `ground`): from the side legs' foot (the origin's row) to the picture's bottom.
        "ground_hive": round((size[1] - foot[1]) / size[1], 4),
        "frames": {k: list(v) for k, v in rects.items()},
        "levels": LEVELS,
        "jar_slots": slots,
        "entrance": [ex, ey],
        "entrance_high": ground_y - ey,
        "ready_at": list(g.ready_at()),
        "ready_mid": list(ready_mid),
        "tree_at": list(TREE_AT),
        "tree_foot": list(tfoot),
        "tree_size": list(bare.size),
        "swarm_px": list(swarm_px),
        "swarm_high": tfoot[1] - (swarm_px[1] + swarm_px[3]),
    }
    # The footprint: the cupboard's diamond, half extents 28 x 14 world px round the node, which
    # on Iso's plane is a tile-axis square (its right corner is half a side along each axis).
    corner = tile_of(28.0, 0.0)
    contract["foot_tiles"] = {"centre": [0.0, 0.0],
                              "half": [round(abs(corner[0]), 4), round(abs(corner[1]), 4)]}
    with open(CONTRACT, "w", newline="\n") as f:
        json.dump(contract, f, indent=1)
        f.write("\n")

    # The check sheet: every frame 4x on the lawn's green, the jars laid in at 12.
    jar = Image.open(os.path.join(ROOT, "assets", "honey_pot.png")).convert("RGBA")
    pot = json.load(open(os.path.join(ROOT, "assets", "honey_pot.json")))["frames"]
    shown = []
    for name, im in frames:
        c = im.copy()
        if name.startswith("hive_") and name != "hive_weathered":
            for k, (fx, fy, shade) in enumerate(slots):
                r = pot["shelf_shade" if shade else "shelf"]["rect"]
                a = pot["shelf"]["anchor"]
                c.alpha_composite(jar.crop((r[0], r[1], r[0] + r[2], r[1] + r[3])),
                                  (fx - a[0], fy - a[1]))
        bg = Image.new("RGBA", c.size, (74, 106, 45, 255))
        bg.alpha_composite(c)
        shown.append(bg.resize((c.width * 4, c.height * 4), Image.NEAREST))
    w = sum(s.width for s in shown) + 8 * (len(shown) + 1)
    h = max(s.height for s in shown) + 16
    out = Image.new("RGBA", (w, h), (40, 36, 34, 255))
    x = 8
    for s in shown:
        out.alpha_composite(s, (x, 8))
        x += s.width + 8
    out.save(CHECK)
    print("wrote", SHEET, sheet.size, "and", CONTRACT)
    print("hive", size, "foot", foot, "tree at", TREE_AT, "deepest", deepest)


if __name__ == "__main__":
    main()

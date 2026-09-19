#!/usr/bin/env python
"""The wash room's backdrop: the two painted strips `scripts/wash_backdrop.gd` lays either
side of the water it draws for itself.

Run from the project root with the psd-extract venv python, and **reimport after**:

  <psd-extract venv python> tools/build_wash_backdrop.py

The view is the one from the pump: the island's lawn under the stand, a strip of its beach,
the lake, the far bank's sand and the wood behind it, sky over that. Two strips, because the
water between them is the player's own lake and follows its meter, and the sky follows the
day — both are drawn in code off `palette.tres`:

  assets/wash_bank.png   the far bank: sand, rough grass, the pack's trees in three ranks.
                         Its bottom row is the far waterline. Transparent where sky shows.
  assets/wash_lawn.png   the near bank: the island's sand, then its lawn, running to the
                         bottom of the window. Its top row is the near waterline.
  assets/wash_backdrop.json   the sizes, and the rows the code needs.

Both wrap left to right, so a wide window tiles them.

**All pack art, no new drawing** (Richard, 2026-09-19: "pack trees, small, in a row"): the
trees are `Tree_1-3` as the lake stands them, the ground is a patchwork of the rectangle
inscribed in each tile's top diamond. A first-person floor is a plane running away from the
eye and the pack's tiles are 2:1 diamonds, so the diamonds themselves are not used: the
patchwork is laid in flat rows whose blocks get shorter and narrower towards the horizon —
a stepped fake perspective, resampled nearest, whole painted pixels.

Rules first, polish after: Richard may hand-paint either PNG; the json holds while the sizes
do. The ranks behind are the same trees multiplied down (`RANKS`' third number), the one place a
colour here is not the pack's own.
"""
import json
import random

from PIL import Image

PACK = "assets/Forest Isometric Pack Free/"
TREES = ["Trees/Tree_1.png", "Trees/Tree_2.png", "Trees/Tree_3.png"]
DEAD = ["Trees/death_Tree_2.png"]
DEAD_ODDS = 0.08
LAWN_TILES = [1, 2, 19]
ROUGH_TILES = [18, 20, 21]
SAND_TILE = 67
# The row of each tile picture its top diamond's upper corner is on (`Ground`'s numbers).
GRASS_FACE_ROW = 3
SAND_FACE_ROW = 13

SEED = 1909
WIDE = 960

# The far bank, top to bottom: room for the tallest tree, the rough grass the trees stand
# in, the sand.
BANK_TALL = 118
BANK_GRASS = 18
BANK_SAND = 7
# Back to front: how far up the bank a rank's feet are, its spacing, and its tone.
RANKS = [(14, 19, 0.62), (8, 23, 0.8), (2, 27, 1.0)]
RANK_JITTER = 7

# The near bank: block heights from the waterline down. Sand first, then lawn; the last
# height repeats to the bottom.
LAWN_TALL = 200
SAND_ROWS = [2, 2, 3, 3, 4]
GRASS_ROWS = [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8]
BLOCK = (16, 8)
EDGE_WANDER = 2
BLADE_ODDS = 0.22


def face(tile, face_row):
    """The rectangle inscribed in a tile's top diamond."""
    im = Image.open(PACK + "Tileset/Slice %d.png" % tile).convert("RGBA")
    return im.crop((8, face_row + 4, 24, face_row + 12))


def patch_row(roll, faces, tall, wide):
    """One row of the patchwork: blocks `tall` high and in proportion wide, rolled."""
    block_wide = max(6, BLOCK[0] * tall // BLOCK[1])
    row = Image.new("RGBA", (wide, tall))
    x = -roll.randrange(block_wide)
    while x < wide:
        block = roll.choice(faces)
        if roll.random() < 0.5:
            block = block.transpose(Image.FLIP_LEFT_RIGHT)
        row.paste(block.resize((block_wide, tall), Image.NEAREST), (x, 0))
        x += block_wide
    return row


def ground(roll, faces, heights, tall, wide):
    out = Image.new("RGBA", (wide, tall))
    y = 0
    k = 0
    while y < tall:
        h = heights[min(k, len(heights) - 1)]
        out.paste(patch_row(roll, faces, h, wide), (0, y))
        y += h
        k += 1
    return out


def toned(im, tone):
    if tone >= 1.0:
        return im
    r, g, b, a = im.split()
    dim = lambda band: band.point(lambda v: int(v * tone))
    return Image.merge("RGBA", (dim(r), dim(g), dim(b), a))


def stamp(canvas, art, x, y):
    """Composite `art`, and again a strip either side, so what runs over one edge comes
    back in on the other and the strip wraps."""
    for shift in (0, -WIDE, WIDE):
        left = x + shift
        if left >= canvas.width or left + art.width <= 0:
            continue
        cut_l = max(0, -left)
        cut_r = min(art.width, canvas.width - left)
        canvas.alpha_composite(art.crop((cut_l, 0, cut_r, art.height)), (left + cut_l, y))


def build_bank(roll):
    bank = Image.new("RGBA", (WIDE, BANK_TALL))
    rough = [face(t, GRASS_FACE_ROW) for t in ROUGH_TILES]
    sand = [face(SAND_TILE, SAND_FACE_ROW)]
    grass_top = BANK_TALL - BANK_SAND - BANK_GRASS
    bank.paste(ground(roll, rough, [2, 2, 2, 3, 3], BANK_GRASS, WIDE), (0, grass_top))
    bank.paste(ground(roll, sand, [2, 2, 3], BANK_SAND, WIDE), (0, BANK_TALL - BANK_SAND))
    trees = [Image.open(PACK + p).convert("RGBA") for p in TREES]
    dead = [Image.open(PACK + p).convert("RGBA") for p in DEAD]
    feet_base = BANK_TALL - BANK_SAND
    for up, gap, tone in RANKS:
        x = roll.randrange(gap)
        while x < WIDE:
            art = roll.choice(dead if roll.random() < DEAD_ODDS else trees)
            if roll.random() < 0.5:
                art = art.transpose(Image.FLIP_LEFT_RIGHT)
            art = toned(art.crop(art.getbbox()), tone)
            feet = feet_base - up - roll.randrange(3)
            at = (x - art.width // 2, feet - art.height)
            stamp(bank, art, at[0], at[1])
            x += gap + roll.randrange(-RANK_JITTER, RANK_JITTER + 1)
    return bank


def build_lawn(roll):
    lawn_faces = [face(t, GRASS_FACE_ROW) for t in LAWN_TILES]
    sand_faces = [face(SAND_TILE, SAND_FACE_ROW)]
    sand_tall = sum(SAND_ROWS)
    out = ground(roll, sand_faces, SAND_ROWS, LAWN_TALL, WIDE)
    grass = ground(roll, lawn_faces, GRASS_ROWS, LAWN_TALL, WIDE)
    # The lawn's far edge wanders and throws blades over the sand: a ruled line between two
    # patchworks is a seam, not a beach.
    edge = 0
    for x in range(WIDE):
        if roll.random() < 0.3:
            edge = max(-EDGE_WANDER, min(EDGE_WANDER, edge + roll.choice((-1, 1))))
        # Come back to nought by the right edge so the strip wraps.
        if x > WIDE - 12:
            edge = int(edge * (WIDE - x) / 12)
        top = sand_tall + edge
        if roll.random() < BLADE_ODDS:
            top -= roll.randrange(1, 4)
        for y in range(top, LAWN_TALL):
            out.putpixel((x, y), grass.getpixel((x, max(y - sand_tall, 0))))
    return out, sand_tall


def main():
    roll = random.Random(SEED)
    bank = build_bank(roll)
    lawn, sand_tall = build_lawn(roll)
    bank.save("assets/wash_bank.png")
    lawn.save("assets/wash_lawn.png")
    with open("assets/wash_backdrop.json", "w", encoding="utf-8") as out:
        json.dump({
            "wide": WIDE,
            "bank_tall": BANK_TALL,
            "bank_sand": BANK_SAND,
            "lawn_tall": LAWN_TALL,
            "lawn_sand": sand_tall,
        }, out, indent=1)
    sheet = Image.new("RGBA", (WIDE, BANK_TALL + 60 + LAWN_TALL), (60, 110, 150, 255))
    sheet.alpha_composite(bank, (0, 0))
    sheet.alpha_composite(lawn, (0, BANK_TALL + 60))
    sheet.save("tools/last_wash_backdrop.png")
    print("bank %dx%d, lawn %dx%d (sand %d)" % (*bank.size, *lawn.size, sand_tall))


if __name__ == "__main__":
    main()

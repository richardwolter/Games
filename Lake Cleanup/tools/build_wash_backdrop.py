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
  assets/wash_clouds.png the clouds, side by side: the code drifts them across the sky.
  assets/wash_backdrop.json   the sizes, the rows the code needs, the clouds' rectangles.

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
import math
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


# The clouds (2026-09-28, `/grill-me` with Richard, off a reference and option 3 of
# tools/last_sky_mockup.png, written by tools/sky_reflect_mockup.py). One noisy mass on a
# flat base, rounding off as it rises — not a heap of round puffs, which read as snowballs.
# One sun, top left: the mass is lit on its upper left, each billow on its own upper left,
# and the lower part falls into shade. **White is the majority**; the shade is a blue-grey
# between the cloud grey and the sky, and the base melts into shade rather than wearing a
# dark band. The thin edge is half see-through, so the cloud sits in whatever sky the hour
# paints behind it. (wide, tall, seed) in painted pixels; `CLOUDS` ride the near layer,
# `FAR_CLOUDS` the far one, `WISPS` are the small scraps high up.
CLOUDS = [(124, 48, 4), (138, 43, 8), (100, 52, 12), (116, 40, 17)]
FAR_CLOUDS = [(70, 24, 21), (84, 26, 25), (58, 22, 29)]
WISPS = [(12, 3, 31), (18, 3, 32), (9, 2, 33), (15, 4, 34), (22, 3, 35)]
C_LIT = (255, 255, 255, 255)
C_BODY = (238, 246, 251, 255)
C_GREY = (204, 222, 240, 255)
C_UNDER = (158, 184, 219, 255)
C_SKY = (125, 184, 230, 255)
EDGE_ALPHA = 140


def _mix(a, b, t):
    return tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(4))


C_SHADE = _mix(C_GREY, C_UNDER, 0.45)
C_DEEP = _mix(C_UNDER, C_SKY, 0.25)


def _hash(x, y, s):
    n = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return (n & 0xffff) / 65535.0


def _vnoise(x, y, s):
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = _hash(xi, yi, s), _hash(xi + 1, yi, s)
    d, e = _hash(xi, yi + 1, s), _hash(xi + 1, yi + 1, s)
    return a + (b - a) * fx + (d - a) * fy + (a - b - d + e) * fx * fy


def _fbm(x, y, s):
    return sum(_vnoise(x * 2 ** o, y * 2 ** o, s + o) / 2 ** o for o in range(3)) / 1.75


def cloud(wide, tall, seed):
    """One cloud, `wide` x `tall` painted pixels, base on the bottom row."""
    k = wide / 86.0            # the mockup's cloud was 86 across; its noise scales with it
    cx, base = wide / 2.0, tall - 1

    def dens(x, y):
        up = (base - y) / (tall * 0.8)
        if up < 0 or up > 1.02:
            return 0.0
        half = wide * 0.5 * 0.8 * math.sqrt(max(0.0, 1 - (up / 1.1) ** 2))             * (0.8 + 0.4 * _fbm(y / (14 * k), seed, seed + 5))
        side = 1 - abs(x - cx) / max(half, 1)
        n = _fbm(x / (18 * k), y / (15 * k), seed)
        return side * 1.4 + (n - 0.5) * 1.6 - max(0, up - 0.85) * 3

    im = Image.new("RGBA", (wide, tall))
    off = max(3, int(round(6 * k)))
    for y in range(tall):
        for x in range(wide):
            d = dens(x, y)
            if d < 0.35:
                continue
            nb = dens(x + off, y + off) if y + off <= base and dens(x, y + off) > 0 else d
            mass = (d - nb) * 1.6
            bill = (_fbm(x / (12 * k), y / (10 * k), seed + 31)
                    - _fbm((x + 3 * k) / (12 * k), (y + 3 * k) / (10 * k), seed + 31)) * 4
            height = (base - y) / max(tall * 0.8, 1)
            lit = mass * 1.4 + bill + (height - 0.5) * 1.8 + (cx - x) / (60 * k)
            lit -= max(0.0, 1 - (base - y) / (12 * k)) * 0.8
            if d < 0.48:
                col = C_SHADE if lit < 0.2 else C_BODY
                col = col[:3] + (EDGE_ALPHA,)
            elif lit > -0.3:
                col = C_LIT
            elif lit > -0.55:
                col = C_BODY
            elif lit > -0.95:
                col = C_SHADE
            else:
                col = C_DEEP
            im.putpixel((x, y), col)
    return im


def wisp(wide, tall, seed):
    im = Image.new("RGBA", (wide, tall))
    for x in range(wide):
        mid = 1 - abs(x / max(wide - 1, 1) * 2 - 1)
        rows = max(1, int(round(tall * (0.4 + 0.6 * mid) * (0.6 + 0.5 * _hash(x // 3, 0, seed)))))
        for y in range(tall - rows, tall):
            im.putpixel((x, y), C_BODY if y < tall - 1 or mid > 0.6 else C_GREY)
    return im


def build_clouds(roll):
    arts = [("near", cloud(*c)) for c in CLOUDS] + [("far", cloud(*c)) for c in FAR_CLOUDS]         + [("wisp", wisp(*c)) for c in WISPS]
    pad = 2
    sheet = Image.new("RGBA", (sum(a.width + pad for _, a in arts), max(a.height for _, a in arts)))
    boxes = {"near": [], "far": [], "wisp": []}
    x = 0
    for kind, art in arts:
        box = art.getbbox() or (0, 0, art.width, art.height)
        art = art.crop(box)
        sheet.alpha_composite(art, (x, 0))
        boxes[kind].append([x, 0, art.width, art.height])
        x += art.width + pad
    return sheet, boxes


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
    clouds, cloud_boxes = build_clouds(roll)
    clouds.save("assets/wash_clouds.png")
    bank.save("assets/wash_bank.png")
    lawn.save("assets/wash_lawn.png")
    with open("assets/wash_backdrop.json", "w", encoding="utf-8") as out:
        json.dump({
            "wide": WIDE,
            "bank_tall": BANK_TALL,
            "bank_sand": BANK_SAND,
            "lawn_tall": LAWN_TALL,
            "lawn_sand": sand_tall,
            "clouds": cloud_boxes["near"],
            "far_clouds": cloud_boxes["far"],
            "wisps": cloud_boxes["wisp"],
        }, out, indent=1)
    sheet = Image.new("RGBA", (WIDE, BANK_TALL + 60 + LAWN_TALL), (60, 110, 150, 255))
    sheet.alpha_composite(bank, (0, 0))
    sheet.alpha_composite(lawn, (0, BANK_TALL + 60))
    sheet.alpha_composite(clouds, (8, BANK_TALL + 8))
    sheet.save("tools/last_wash_backdrop.png")
    print("bank %dx%d, lawn %dx%d (sand %d)" % (*bank.size, *lawn.size, sand_tall))


if __name__ == "__main__":
    main()

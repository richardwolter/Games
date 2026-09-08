"""Generate the grass fringe strips that hang over the sand in Lake Cleanup.

Why this exists
---------------
`Ground` draws every grass tile as a rectangle cut off a hair below its top face
(`_add_tile_quad`'s `skirt`). That cut is a horizontal line, and it lands at exactly
`mid.y + TILE_H/2` for every grass tile whatever its own `_face_top` is -- the lift and the
face height cancel. So a run of lawn against a beach ends on one unbroken horizontal edge per
tile, repeated all the way along the shore, and at a low camera angle that reads as a cut
picture rather than as turf.

These strips are what hangs over that cut: a few pixels of blades and tufts, drawn past the
edge and over the sand tile in front, with a different silhouette per variant so the line is
never the same twice.

The colours are not invented. They are sampled off the pack's own border tiles (the tufted
mounds `Ground.GRASS_BORDER` already picks from), so a strip cannot drift out of the pack's
palette no matter what the shapes do.

Deterministic: same SEED, same strips. Re-running overwrites in place and the diff is empty
unless a parameter changed.

Needs Pillow:  python -m pip install Pillow  (a venv is fine; nothing else imports this)
Run from anywhere:  python _pipeline/tools/generate_fringe.py
"""

import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PACK = os.path.join(ROOT, "Lake Cleanup", "assets", "Forest Isometric Pack Free", "Tileset")
OUT = os.path.join(ROOT, "Lake Cleanup", "assets", "fringe")

# The pack tiles the palette is read from: the same tufted mounds `Ground.GRASS_BORDER` uses.
SOURCE_TILES = (37, 38, 43, 45)

# How many strips to make. Picked per tile by a stable hash, so this is how long the shore can
# run before a silhouette comes back around.
VARIANTS = 8

# A strip is one tile wide and this tall, in source pixels at the pack's own resolution, with
# the grass tile's cut edge sitting `OVERLAP` rows down from the top of it.
#
# The rows above the cut are not decoration: a strip that starts exactly at the edge shows a
# seam of its own wherever a blade's colour differs from the tile's last row. Starting a
# couple of rows up puts the join inside the lawn where nothing is looking.
WIDTH = 32
OVERLAP = 2
HANG = 7
HEIGHT = OVERLAP + HANG

# How wide the grass tile still is at the row its quad is cut, and how fast the silhouette
# below it narrows, in source pixels. Measured off the pack (slice 37 row 26 spans x 4..27);
# a blade hanging outside this is hanging off the side of a tile that isn't there.
EDGE_LEFT = 4
EDGE_RIGHT = 27
NARROW = 2.0

# How much of a strip is blades at all. Below this the fringe is gap, and the cut edge shows
# through as it does today -- which is wanted in moderation: an unbroken curtain of fringe is
# its own straight line, just a furrier one.
COVER = 0.88

# How many clumps of blades a strip is built from, and how wide one clump is. Blades rolled
# per column come out as static; rolled per clump they come out as tufts.
CLUMPS = (6, 9)
CLUMP_WIDE = (5, 11)

SEED = 20260908


def _palette():
    """The greens of the pack's border tiles, darkest first.

    Read off the top faces only -- the rows below a tile's face are its earth side, and a
    blade the colour of dirt is a dead blade.
    """
    counts = {}
    for slice_no in SOURCE_TILES:
        img = Image.open(os.path.join(PACK, "Slice %d.png" % slice_no)).convert("RGBA")
        px = img.load()
        top = next(
            y for y in range(img.height)
            if any(px[x, y][3] > 127 for x in range(img.width))
        )
        for y in range(top, min(top + 16, img.height)):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a > 127 and g > r and g > b:
                    counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    common = sorted(counts.items(), key=lambda kv: -kv[1])[:5]
    return sorted((c for c, _ in common), key=lambda c: c[0] + c[1] + c[2])


def _reach(x):
    """How far below the cut a blade at this column may hang, in rows.

    The tile it hangs off narrows as it goes down, so a blade near the tile's corner has less
    tile above it to belong to than one in the middle.
    """
    if x < EDGE_LEFT or x > EDGE_RIGHT:
        return 0
    room = min(x - EDGE_LEFT, EDGE_RIGHT - x) / NARROW
    return int(min(HANG, room))


def _strip(rng, palette):
    dark, mid, light = palette[0], palette[len(palette) // 2], palette[-1]
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    px = img.load()

    # Where the blades are: a handful of clumps, not a per-column roll. See CLUMPS.
    depth = [0] * WIDTH
    for _ in range(rng.randint(*CLUMPS)):
        wide = rng.randint(*CLUMP_WIDE)
        centre = rng.randint(0, WIDTH - 1)
        tall = rng.uniform(0.6, 1.0)
        for x in range(centre - wide // 2, centre + wide // 2 + 1):
            if not 0 <= x < WIDTH:
                continue
            # Tapered to the clump's edges, so a tuft is a mound rather than a block.
            near = 1.0 - 0.55 * abs(x - centre) / float(wide * 0.5 + 0.5)
            d = int(round(_reach(x) * tall * max(near, 0.0) + rng.uniform(-0.3, 0.9)))
            depth[x] = max(depth[x], min(max(d, 1), _reach(x)))

    # Thin it back out to COVER, dropping whole columns rather than shortening them: a fringe
    # of even length with gaps in it still reads as blades; one of uneven length with none
    # reads as a hem.
    for x in range(WIDTH):
        if depth[x] and rng.random() > COVER:
            depth[x] = 0

    for x in range(WIDTH):
        if depth[x] <= 0:
            continue
        # The rows above the cut, so the strip joins the lawn inside the lawn.
        for y in range(OVERLAP):
            px[x, y] = mid + (255,)
        for row in range(depth[x]):
            y = OVERLAP + row
            if row == depth[x] - 1:
                colour = dark
            elif row == 0 and rng.random() < 0.35:
                colour = light
            else:
                colour = mid
            px[x, y] = colour + (255,)
    return img


def main():
    palette = _palette()
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(SEED)
    for i in range(VARIANTS):
        path = os.path.join(OUT, "fringe_%d.png" % i)
        _strip(rng, palette).save(path)
        print("wrote", path)
    print("palette", palette)


if __name__ == "__main__":
    main()

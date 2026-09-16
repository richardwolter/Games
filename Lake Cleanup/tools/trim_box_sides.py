#!/usr/bin/env python
"""Dress the recycle box's side borders: their colour, and how many pixels come off them.

The box is painted with a one-pixel line of its darkest brown round its whole silhouette.
Up the two vertical sides — the left and right corners of the crate, rows 8 to 25 of the
32x33 picture — that line is cleared (2026-09-12, Richard: "clean 1px from the shed and the
box borders on the sides only"), so the planks meet the grass there and only the diamond
edges top and bottom keep the dark line. The shed gets the same treatment in
tools/recolor_shed.py, so the two read as one wood with one edge.

The sides are also **recoloured to match the top edges** (2026-09-12, Richard): the box is
painted with its upper rim in one dark red-brown (76,29,29) and its vertical sides and
lower edges in a darker, cooler brown (48,37,33), and the sides are repainted in the rim's
colour so the outline round the crate reads as one line. The colour is read off the
painted box's top edges, not written down here. The lower, sloping edges keep theirs.

Only pixels on a **vertical run** of the silhouette are touched: a pixel is a side pixel
when it is the outermost opaque pixel of its row and the rows above and below it start at
the same column. The sloping diamond edges never satisfy that.

Input:   art_source/recycle_box_painted.png   the box as painted
Output:  assets/Recycle_Box.png               the box the yard, the HUD and Style read

Run from the project root with the psd-extract venv python.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "recycle_box_painted.png"
OUT = ROOT / "assets" / "Recycle_Box.png"

## How many pixels to clear off each vertical side. Zero, by decision (2026-09-12): the
## box's side line is only one pixel, so taking one off left it with no border at all,
## which was too much. Kept at zero rather than deleting the script, so the box still goes
## through the same step as the shed and the number is here to try again.
SIDE_TRIM = 0


def side_runs(image):
    """The (x, y) of every pixel on a vertical run of the left or right silhouette edge."""
    w, h = image.size
    px = image.load()
    left = [None] * h
    right = [None] * h
    for y in range(h):
        xs = [x for x in range(w) if px[x, y][3] > 0]
        if xs:
            left[y], right[y] = xs[0], xs[-1]
    found = []
    for y in range(1, h - 1):
        if left[y] is not None and left[y - 1] == left[y] == left[y + 1]:
            found.append((left[y], y))
        if right[y] is not None and right[y - 1] == right[y] == right[y + 1]:
            found.append((right[y], y))
    return found


## Rows above which the outermost pixels are the box's upper rim, whose colour the sides take.
RIM_ROWS = 8


def rim_ink(image):
    """The colour the box's top edges are drawn in: the commonest outermost pixel colour
    over the rim rows."""
    w, h = image.size
    px = image.load()
    counts = {}
    for y in range(min(RIM_ROWS, h)):
        xs = [x for x in range(w) if px[x, y][3] > 0]
        for x in (xs[:1] + xs[-1:]):
            key = px[x, y][:3]
            counts[key] = counts.get(key, 0) + 1
    return max(counts, key=counts.get)


def main():
    image = Image.open(SOURCE).convert("RGBA")
    px = image.load()
    ink = rim_ink(image)
    painted = 0
    for x, y in side_runs(image):
        if y >= RIM_ROWS:
            px[x, y] = (ink[0], ink[1], ink[2], px[x, y][3])
            painted += 1
    cleared = 0
    for _ in range(SIDE_TRIM):
        for x, y in side_runs(image):
            px[x, y] = (0, 0, 0, 0)
            cleared += 1
    image.save(OUT)
    print("wrote %s: %d side pixels painted %s, %d cleared"
          % (OUT.relative_to(ROOT), painted, ink, cleared))


if __name__ == "__main__":
    main()

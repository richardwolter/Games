#!/usr/bin/env python
"""Repaint the hut's walls in the recycle box's wood.

The shed was painted in a warm tan and the recycle box beside it in a cooler, darker brown;
the ferry's hull already took the box's brown (tools/build_boat_sheet.py), so the hut is the
last piece of wood on the island in its own colour. This maps the walls onto the box's plank
ramp and leaves everything else as painted.

How, and why this way (2026-09-12):
  * It is a **gradient remap by brightness**, not a tint. Every wall pixel keeps its rank in
    the wall's own light-to-dark order and is given the colour at the same rank in the box's
    planks — histogram matching, interpolated through the box's browns so the shed's ~280
    shades stay distinct. Plank faces land on the box's plank faces, seams stay seams, the
    outline becomes the box's darkest brown. One wood, by decision (Richard, Q1): the seams
    shift with the planks rather than staying the shed's own dark tan.
  * Roof untouched, by decision: the green thatch, and the wooden fascia along its outer
    edges. The fascia is wall-coloured, so it is told apart by *where* it is — a brown pixel
    with thatch below it in its own column is roof trim (the trim runs along the roof's outer
    edge, above and outside the green); a wall pixel never has thatch below it, only above,
    at the eaves and over the gable alike.
  * Kept exactly as painted, by decision: the lit yellow window (a bright, saturated yellow)
    and the grey door hardware (low saturation). Classified by colour, not by hand mask.
  * The walls get the box's **border** as well (2026-09-12, Richard): the box is drawn with a
    one-pixel line of its darkest brown round its whole silhouette, and the shed's edge was
    only whatever its darkest shading happened to be there. Every wall pixel on the outer
    edge of the picture — next to a clear pixel, or the half-alpha shadow line under the
    walls — is painted in the box's own edge colour, read off the box's silhouette. The
    roof's edge is the roof's and is left alone.
  * The box's planks are read off Recycle_Box.png itself — the browns, not the red hollow
    inside it and not the blue mark — so this is the same brown the ferry's hull was given,
    rather than Style.CRATE, which is the drawn fallback crate and a different colour.

Input:
  art_source/shed_101.png      the hut at its grain (tools/downres_shed.py), in its tan
  art_source/recycle_box_painted.png   the box whose wood it takes, as painted

Output:
  assets/shed.png              the hut the lake, the shadow and the HUD button draw

Run from the project root:
  <psd-extract venv python> tools/recolor_shed.py [--mask out.png]

Re-run after any re-cut of the hut: copy the fresh cut to art_source/shed_tan.png first.
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
## The hut at its grain, from tools/downres_shed.py — and, once Richard has polished
## it by hand, the painted source itself.
SOURCE = ROOT / "art_source" / "shed_101.png"
## The box **as painted**, not assets/Recycle_Box.png: tools/trim_box_sides.py clears the
## dark line off that one's sides, and the edge colour read off it then comes out as the
## red rim of the hollow.
BOX = ROOT / "art_source" / "recycle_box_painted.png"
OUT = ROOT / "assets" / "shed.png"

## Hue, in degrees, below which a saturated pixel is wood rather than thatch. The walls' tan
## runs about 20-37 degrees; the thatch's lit strokes start at about 45 and the green proper
## at 60.
WOOD_HUE = 40.0
## Saturation under which a pixel is grey (the door hardware) rather than any wood.
GREY_SAT = 0.2
## The lit window: bright, saturated yellow, hue between the wood and the thatch.
WINDOW_HUE = (40.0, 58.0)
WINDOW_VALUE = 0.7
## How finely the box's ramp is sampled: bins of equal pixel count from darkest to lightest,
## each the mean colour of its pixels. Interpolated between, so a shade between two bins is
## a shade between two browns rather than a jump.
RAMP_BINS = 48


def hsv(p):
    r, g, b = p[0] / 255.0, p[1] / 255.0, p[2] / 255.0
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return h * 360.0, s, v


def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def classify(image):
    """One letter per pixel: ' ' clear, 'w' wall, 'r' roof (thatch or fascia), 'y' window,
    'g' grey hardware."""
    w, h = image.size
    px = image.load()
    kind = [[" "] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hue, sat, val = hsv((r, g, b))
            if sat < GREY_SAT:
                kind[y][x] = "g"
            elif hue < WOOD_HUE:
                kind[y][x] = "w"
            elif WINDOW_HUE[0] <= hue < WINDOW_HUE[1] and val > WINDOW_VALUE:
                kind[y][x] = "y"
            else:
                kind[y][x] = "r"
    # The fascia: wood with thatch somewhere **below** it in its own column. The trim runs
    # along the roof's outer edges, above and outside the green, so looking straight down
    # from a trim pixel finds thatch; looking down from any wall pixel never does — the
    # thatch is above the walls, at the eaves and over the gable alike. A pixel is also given
    # its neighbours' columns, so the outline at the trim's very ends is not missed. (A
    # first cut asked for thatch diagonally below, and that also caught the gable under the
    # roof's near edge, which slopes the same way.)
    top = [h] * w
    for x in range(w):
        for y in range(h):
            if kind[y][x] == "r":
                top[x] = y
                break
    for y in range(h):
        for x in range(w):
            if kind[y][x] != "w":
                continue
            if any(y < top[xx] < h for xx in (x - 1, x, x + 1) if 0 <= xx < w):
                kind[y][x] = "f"
    return kind


def box_ramp():
    """The box's planks, darkest to lightest, as RAMP_BINS mean colours."""
    image = Image.open(BOX).convert("RGBA")
    px = image.load()
    planks = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hue, sat, val = hsv((r, g, b))
            # Brown: not the red hollow (hue near 0, strongly saturated, dark) and not the
            # blue mark. The planks sit between about 15 and 40 degrees.
            if 12.0 <= hue <= 45.0 and sat >= 0.2:
                planks.append((r, g, b))
    planks.sort(key=luma)
    bins = []
    n = len(planks)
    for i in range(RAMP_BINS):
        lo = i * n // RAMP_BINS
        hi = max((i + 1) * n // RAMP_BINS, lo + 1)
        chunk = planks[lo:hi]
        bins.append(tuple(sum(c[j] for c in chunk) / len(chunk) for j in range(3)))
    return bins


def box_edge():
    """The colour the box's silhouette is drawn in: the commonest colour of its pixels
    that touch a clear one."""
    image = Image.open(BOX).convert("RGBA")
    px = image.load()
    w, h = image.size
    counts = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                key = px[x, y][:3]
                counts[key] = counts.get(key, 0) + 1
    return max(counts, key=counts.get)


## Alpha under which a pixel counts as outside the hut for the border: the baked shadow line
## under the walls is half-alpha and is not wall.
OUTSIDE_ALPHA = 128
## How many pixels deep the border is drawn in from the edge, and whether the half-alpha
## shadow line under the walls is stripped (2026-09-12, "darker and flatter like the box"):
## a one-pixel line with a soft grey row under it read thin and faded next to the box's
## solid edge. Two deep, fully opaque, and nothing soft below it — a hull on water throws no
## baked shadow (build_boat_sheet.py) and neither does a hut on grass; the sun's shadow is
## drawn by the lake.
## One painted pixel, 1.4 on screen — the coarser picture draws its own edge.
BORDER_DEEP = 1
STRIP_SOFT = True
## How many pixels are cleared off the walls' two vertical sides after the border is drawn
## (2026-09-12, "clean 1px from the shed and the box borders on the sides only"). The box
## gets the same in tools/trim_box_sides.py. Only a vertical run of the silhouette is a
## side: the outermost wall pixel of a row whose neighbours above and below start at the
## same column. The sloping bottom edges keep the whole border.
SIDE_TRIM = 1


def ramp_at(bins, t):
    """The ramp colour at rank t in 0..1, interpolated."""
    f = t * (len(bins) - 1)
    i = int(f)
    if i >= len(bins) - 1:
        return bins[-1]
    a, b = bins[i], bins[i + 1]
    u = f - i
    return tuple(a[j] + (b[j] - a[j]) * u for j in range(3))


def main():
    mask_out = None
    if "--mask" in sys.argv:
        mask_out = Path(sys.argv[sys.argv.index("--mask") + 1])
    # Trials: --source path --out path recolour another picture somewhere else.
    source = SOURCE
    out_path = OUT
    if "--source" in sys.argv:
        source = Path(sys.argv[sys.argv.index("--source") + 1])
    if "--out" in sys.argv:
        out_path = Path(sys.argv[sys.argv.index("--out") + 1])
    image = Image.open(source).convert("RGBA")
    w, h = image.size
    px = image.load()
    kind = classify(image)

    # Every wall pixel's rank in the wall's own brightness order.
    walls = [(luma(px[x, y]), x, y) for y in range(h) for x in range(w) if kind[y][x] == "w"]
    walls.sort()
    bins = box_ramp()
    out = image.copy()
    op = out.load()
    n = len(walls)
    for rank, (_, x, y) in enumerate(walls):
        t = rank / max(n - 1, 1)
        r, g, b = ramp_at(bins, t)
        op[x, y] = (int(round(r)), int(round(g)), int(round(b)), px[x, y][3])
    # The border: wall pixels within BORDER_DEEP of the picture's outer edge, in the box's
    # edge colour, solid.
    edge = box_edge()
    bordered = 0

    def outside(xx, yy):
        return not (0 <= xx < w and 0 <= yy < h) or px[xx, yy][3] < OUTSIDE_ALPHA

    for y in range(h):
        for x in range(w):
            if kind[y][x] != "w":
                continue
            near = any(
                outside(x + dx, y + dy)
                for k in range(1, BORDER_DEEP + 1)
                for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k))
            )
            if near:
                op[x, y] = (edge[0], edge[1], edge[2], 255)
                bordered += 1
    if STRIP_SOFT:
        for y in range(h):
            for x in range(w):
                if 0 < px[x, y][3] < OUTSIDE_ALPHA:
                    op[x, y] = (0, 0, 0, 0)
    # The sides: the outermost pixel of every vertical run of the walls' edge, cleared.
    trimmed = 0
    for _ in range(SIDE_TRIM):
        left = [None] * h
        right = [None] * h
        for y in range(h):
            xs = [x for x in range(w) if kind[y][x] == "w" and op[x, y][3] > 0]
            if xs:
                left[y], right[y] = xs[0], xs[-1]
        for y in range(1, h - 1):
            for run in (left, right):
                if run[y] is not None and run[y - 1] == run[y] == run[y + 1]:
                    op[run[y], y] = (0, 0, 0, 0)
                    trimmed += 1
    print("sides: %d pixels cleared" % trimmed)
    out.save(out_path)
    print("border: %d pixels in %s" % (bordered, edge))
    counts = {}
    for row in kind:
        for k in row:
            counts[k] = counts.get(k, 0) + 1
    print("wrote %s: %d wall, %d fascia, %d roof, %d window, %d grey"
          % (out_path, counts.get("w", 0), counts.get("f", 0),
             counts.get("r", 0), counts.get("y", 0), counts.get("g", 0)))

    if mask_out is not None:
        tint = {" ": (255, 0, 255), "w": (255, 128, 0), "f": (255, 0, 0),
                "r": (0, 160, 0), "y": (255, 255, 0), "g": (200, 200, 200)}
        mask = Image.new("RGB", (w, h))
        mp = mask.load()
        for y in range(h):
            for x in range(w):
                mp[x, y] = tint[kind[y][x]]
        mask.resize((w * 4, h * 4), Image.NEAREST).save(mask_out)
        print("mask at", mask_out)


if __name__ == "__main__":
    main()

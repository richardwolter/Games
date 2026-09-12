#!/usr/bin/env python
"""Turn the PixZels blue boat into the ferry's sheet of headings, jib and shadow removed.

The source is a 16-direction pixel-art sail boat, one row of 128x128 frames, drawn with
three sails: a jib forward of the mast on a forestay, a square sail on a yard at the mast
(its forward billow is the white-and-slate lens in the side views), and a gaff sail aft.
The ferry sails without the jib and without the forestay it hung on, and without the
floor shadow the frames were rendered with, since a hull on water throws none. Its hull
planks are repainted in the yard's recycle box's brown (Style.BOX), so the boat and the
box it serves read as one wood, and the square sail's lit face carries the box's blue
recycle mark (Style.BOX_BLUE), painted per heading so it turns with the sail.

This is a hand edit written down, not a detector. Which light-blue pixels are the jib and
which are the square sail's head strip, and what the bow deck looks like under the jib's
clew, are decisions made frame by frame from the drawing; the OPS table below is those
decisions, so they can be re-run and revised without touching the picture by hand. Frames
9 to 15 mirror 7 to 1 (checked: they differ by a few pixels of the hull's blue stripe), so
the ops are authored for 0 to 8 and applied mirrored to the rest.

Input:
  art_source/Blue_Boat/blue_boat_16dir.png   the sheet as shipped

Output:
  assets/boat_sail_frames.png                 the sheet the ferry draws from
  assets/boat_sail_frames.json                what the sheet is and which way frame 0 faces

Run from the project root:
  <psd-extract venv python> tools/build_boat_sheet.py [--contact out.png] [--ascii FRAME..]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "Blue_Boat" / "blue_boat_16dir.png"
OUT_PNG = ROOT / "assets" / "boat_sail_frames.png"
OUT_JSON = ROOT / "assets" / "boat_sail_frames.json"

FRAME = 128
FRAMES = 16

## The sheet's fifteen colours, by the letter the ops and the ascii dump use. Space is
## transparent. The shadow (13,13,22 at half alpha) is stripped before any op runs.
INK = {
    "o": (53, 31, 28, 255),  # outline brown: spars, rails, every edge
    ".": (184, 196, 229, 255),  # sail cloth
    "W": (255, 255, 255, 255),  # sail cloth, lit
    "D": (84, 95, 132, 255),  # sail cloth, back face
    "K": (13, 13, 22, 255),  # rope
    "w": (187, 117, 71, 255),  # wood
    "l": (222, 181, 129, 255),  # wood, light
    "m": (203, 140, 85, 255),  # wood, warm
    "d": (113, 65, 59, 255),  # wood, dark (deck in shadow)
    "x": (122, 66, 34, 255),  # hull planks, as shipped
    "X": (120, 89, 64, 255),  # hull planks, the recycle box's brown (Style.BOX)
    "R": (77, 133, 166, 255),  # the recycle mark, the box's blue (Style.BOX_BLUE)
    "b": (53, 151, 231, 255),  # blue stripe
    "B": (59, 86, 149, 255),  # blue stripe, dark
    " ": (0, 0, 0, 0),
}
LETTER = {v: k for k, v in INK.items()}
LETTER[(255, 255, 255, 0)] = " "

## Per-frame edits, frame 0 to 8, in source pixel coordinates. Each op is a tuple:
##   ("clear", (x0, y0, x1, y1), "letters")   clear pixels of those colours in the box
##   ("clear_pts", [(x, y), ...])             clear these pixels
##   ("set", letter, [(x, y), ...])           paint these pixels
##   ("box", letter, (x0, y0, x1, y1))        paint the box (inclusive)
##   ("hline", letter, y, x0, x1)             paint a run along a row (inclusive)
##   ("vline", letter, x, y0, y1)             paint a run down a column (inclusive)
## Boxes are inclusive on both ends. Frames 9-15 get frame (16 - n)'s ops mirrored.
OPS = {
    0: [
        # Bow on: the jib is edge-on behind its own stay, so the stay is all there is to
        # take out, one column down the mast, the yard, the sail, the rail and the stem.
        ("vline", "w", 64, 35, 39),
        ("set", "o", [(64, 40), (64, 41), (64, 42), (64, 44)]),
        ("set", "w", [(64, 43)]),
        ("vline", ".", 64, 45, 48),
        ("vline", "W", 64, 49, 73),
        ("set", "o", [(64, 74), (64, 75), (64, 77), (64, 78), (64, 79), (64, 81), (64, 82), (64, 83),
                      (64, 84), (64, 85), (64, 86)]),
        ("set", "w", [(64, 76)]),
        ("set", "l", [(64, 80), (64, 87), (64, 88)]),
    ],
    1: [
        # The stay: the truck's outline and the mast's own face where it covered them, the
        # yard and head strip, then lit sail.
        ("set", "o", [(65, 33), (66, 33), (67, 33), (64, 34), (64, 37), (64, 38), (64, 39), (64, 40),
                      (64, 41), (64, 42), (63, 43)]),
        ("set", "w", [(65, 36), (65, 37), (65, 38)]),
        ("set", ".", [(63, 44), (63, 45)]),
        ("set", "W", [(62, 46), (62, 47), (62, 48), (62, 49), (62, 50), (61, 51), (61, 52), (61, 53),
                      (61, 54), (61, 55), (61, 56), (60, 57), (60, 58), (60, 59), (60, 60)]),
        # The sliver of jib beside the stay, over the sail and then over the bow: the square
        # sail's foot spar, the deck inside the rail, the rail cap, the bow's panels, the stem.
        ("hline", "W", 61, 59, 60), ("hline", "W", 62, 59, 60), ("hline", "W", 63, 59, 60),
        ("hline", "W", 64, 59, 60), ("hline", "W", 65, 59, 60), ("hline", "W", 66, 58, 60),
        ("hline", "W", 67, 58, 61), ("hline", "W", 68, 58, 61), ("hline", "W", 69, 58, 61),
        ("hline", "W", 70, 57, 61), ("hline", "W", 71, 57, 61), ("hline", "W", 72, 57, 61),
        ("hline", "W", 73, 57, 61),
        ("hline", "o", 74, 57, 61),
        ("set", "o", [(56, 75)]), ("hline", "w", 75, 57, 61),
        ("hline", "o", 76, 56, 61),
        ("set", "o", [(56, 77)]), ("hline", "d", 77, 57, 61),
        ("set", "o", [(56, 78)]), ("hline", "d", 78, 57, 61),
        ("set", "o", [(55, 79)]), ("hline", "d", 79, 56, 61),
        ("set", "o", [(55, 80)]), ("hline", "l", 80, 56, 60),
        ("set", "o", [(55, 81)]), ("hline", "m", 81, 56, 59),
        ("set", "o", [(55, 82)]), ("hline", "m", 82, 56, 58),
        ("set", "o", [(54, 83)]), ("hline", "m", 83, 55, 57),
        ("hline", "o", 84, 54, 56),
        ("hline", "o", 85, 54, 55),
        ("set", "o", [(54, 86), (53, 87), (54, 87)]),
    ],
    2: [
        # The forestay: mast outline at the truck, spar junction where it crosses the yard,
        # head strip, then lit sail down to the square sail's lower corner.
        ("set", "o", [(66, 36), (65, 37), (65, 38), (63, 40), (64, 40), (63, 41), (64, 41), (63, 42),
                      (63, 43)]),
        ("clear_pts", [(64, 39)]),
        ("set", ".", [(62, 44), (62, 45), (62, 46)]),
        ("set", "W", [(61, 47), (61, 48), (60, 49), (59, 50), (59, 51), (59, 52), (59, 53), (58, 54),
                      (58, 55), (57, 56), (57, 57), (57, 58)]),
        ("clear", (32, 72, 50, 83), "K"),
        ("set", "o", [(45, 84)]),
        # The jib's shaded lower half. Behind it: the square sail's lit face down to its foot
        # spar, the spar's far end (the wooden stub at x 49-50 was always its end cap), the
        # far rail running down to the stem cap, water through the gap between them, and
        # deck in shadow inside the rail.
        ("clear", (47, 59, 59, 79), "."),
        ("clear", (47, 80, 53, 82), "."),
        ("hline", "W", 59, 56, 57), ("hline", "W", 60, 55, 57), ("hline", "W", 61, 55, 57),
        ("hline", "W", 62, 55, 57), ("hline", "W", 63, 54, 57), ("hline", "W", 64, 54, 57),
        ("hline", "W", 65, 53, 57), ("hline", "W", 66, 53, 57), ("hline", "W", 67, 52, 58),
        ("set", "o", [(51, 68)]), ("hline", "W", 68, 52, 58),
        ("hline", "w", 69, 50, 51), ("hline", "o", 69, 52, 53), ("hline", "W", 69, 54, 58),
        ("set", "o", [(51, 70)]), ("hline", "w", 70, 52, 53), ("hline", "o", 70, 54, 55),
        ("hline", "W", 70, 56, 58),
        ("set", "o", [(50, 71)]), ("hline", "o", 71, 52, 53), ("hline", "w", 71, 54, 55),
        ("hline", "o", 71, 56, 57), ("set", "W", [(58, 71)]),
        ("hline", "o", 72, 54, 55), ("hline", "w", 72, 56, 57), ("hline", "o", 72, 58, 59),
        ("hline", "o", 73, 56, 57), ("hline", "w", 73, 58, 59),
        ("hline", "o", 74, 58, 59),
        ("hline", "o", 75, 58, 59),
        ("hline", "o", 76, 56, 57), ("hline", "w", 76, 58, 59),
        ("hline", "o", 77, 54, 55), ("hline", "w", 77, 56, 57), ("hline", "o", 77, 58, 59),
        ("hline", "o", 78, 52, 53), ("hline", "w", 78, 54, 55), ("hline", "o", 78, 56, 57),
        ("hline", "d", 78, 58, 59),
        ("hline", "o", 79, 50, 51), ("hline", "w", 79, 52, 53), ("hline", "o", 79, 54, 55),
        ("hline", "d", 79, 56, 59),
        ("hline", "o", 80, 48, 49), ("hline", "w", 80, 50, 51), ("hline", "o", 80, 52, 53),
        ("hline", "o", 81, 46, 47), ("hline", "w", 81, 48, 49), ("set", "o", [(50, 81)]),
        ("hline", "w", 82, 46, 47), ("set", "o", [(48, 82)]),
        ("hline", "o", 83, 46, 47),
    ],
    3: [
        # The forestay, truck to bowsprit cap. Over the square sail it becomes sail; past the
        # sail's edge it goes.
        ("clear_pts", [(65, 37), (65, 38), (64, 39), (65, 39), (63, 40), (64, 40), (63, 41)]),
        ("set", "o", [(66, 36), (66, 37)]),
        ("set", ".", [(61, 42), (62, 42), (63, 42), (62, 43)]),
        ("set", "W", [(61, 44), (62, 44), (61, 45), (60, 46), (60, 47), (59, 48), (58, 49), (58, 50),
                      (57, 51), (56, 52), (56, 53), (55, 54), (54, 55), (54, 56), (53, 57), (52, 58),
                      (52, 59), (51, 60), (51, 61)]),
        ("clear", (32, 62, 50, 80), "K"),
        ("set", "o", [(39, 79)]),
        ("set", "l", [(38, 80)]),
        # The jib's shaded lower half, drawn over the square sail's lit face. The sail's left
        # edge curves in from x 50 at row 59 to its outlined corner at (57, 70).
        ("hline", "W", 55, 55, 55), ("hline", "W", 56, 55, 55), ("hline", "W", 57, 54, 55),
        ("hline", "W", 58, 53, 55), ("hline", "W", 59, 53, 55),
        ("clear", (41, 60, 58, 78), "."),
        ("hline", "W", 60, 51, 55), ("hline", "W", 61, 51, 55), ("hline", "W", 62, 52, 55),
        ("hline", "W", 63, 53, 55), ("hline", "W", 64, 53, 55), ("hline", "W", 65, 54, 55),
        ("hline", "W", 66, 54, 56), ("hline", "W", 67, 55, 56), ("hline", "W", 68, 56, 56),
        ("hline", "W", 69, 56, 56),
        # The bow under the clew: the far rail runs down from behind the sail to the stem cap,
        # a row per four pixels like its visible stretch aft, with deck in shadow inside it.
        ("hline", "o", 73, 55, 59),
        ("hline", "o", 74, 51, 54), ("hline", "w", 74, 55, 58),
        ("hline", "o", 75, 47, 50), ("hline", "w", 75, 51, 54), ("hline", "o", 75, 55, 58),
        ("hline", "o", 76, 43, 46), ("hline", "w", 76, 47, 50), ("hline", "o", 76, 51, 54),
        ("hline", "d", 76, 55, 57),
        ("hline", "o", 77, 39, 42), ("hline", "w", 77, 43, 46), ("hline", "o", 77, 47, 50),
        ("hline", "d", 77, 51, 58),
        ("hline", "w", 78, 39, 42), ("hline", "o", 78, 43, 46),
        ("hline", "o", 79, 39, 42),
    ],
    4: [
        # The forestay: up the fore side of the mast to the truck, then down to the bowsprit.
        # The short rope beside the mast at rows 39-50 (x 64-65) is not it and stays.
        ("clear_pts", [(62, 36), (62, 37), (62, 38), (63, 39), (63, 40), (63, 41), (62, 42), (61, 43),
                       (61, 44)]),
        ("clear", (32, 45, 60, 75), "K"),
        # The jib: the cloth aft of the stay, up to the gap before the square sail's lens.
        ("clear", (32, 54, 57, 76), "."),
        # Where the stay crossed the square sail's head strip and the lens, it becomes them.
        ("set", ".", [(63, 39), (63, 40), (63, 41), (62, 42), (61, 43), (61, 44), (60, 45), (59, 46)]),
        ("set", "W", [(58, 47), (57, 48), (57, 49), (56, 50)]),
        ("set", "l", [(36, 75)]),
        # The bow deck under the clew: the far rail's edge, and a wedge of deck in shadow.
        ("hline", "o", 74, 48, 56),
        ("hline", "d", 75, 52, 56),
        ("hline", "d", 76, 56, 57),
    ],
    5: [
        # The forestay, from the truck (where it stood in for the mast's outline) down to the
        # stem cap. The gaff halyard runs the other way and is untouched.
        ("clear", (32, 38, 65, 70), "K"),
        ("set", "o", [(66, 37), (39, 69), (38, 70)]),
        # The jib: the cloth between the stay and the lens.
        ("clear", (32, 52, 54, 73), "."),
        # The bow under the clew: the far rail, down from the stem cap to where the lens hides
        # it, in the same steps as its visible stretch aft of the mast.
        ("hline", "o", 67, 39, 43),
        ("hline", "w", 68, 39, 43), ("hline", "o", 68, 44, 48),
        ("hline", "o", 69, 39, 43), ("hline", "w", 69, 44, 48), ("hline", "o", 69, 49, 53),
        ("hline", "o", 70, 42, 48), ("hline", "w", 70, 49, 53),
        ("hline", "o", 71, 49, 53),
        ("hline", "d", 72, 50, 53),
        ("hline", "d", 73, 53, 54),
    ],
    6: [
        # The forestay: up the truck's left side, then the stretch below the lens down to the
        # stem cap. Between, the yard and the lens already hide it.
        ("clear_pts", [(65, 37), (64, 39), (63, 40), (62, 41), (61, 42), (60, 43), (48, 59), (47, 60),
                       (47, 61), (46, 62), (45, 63), (45, 64)]),
        ("set", "o", [(64, 38)]),
        ("set", "l", [(43, 65), (44, 65), (45, 65)]),
        # The sliver of jib between the stay and the lens, and the far rail's near end under
        # it, three pixels of it before the lens takes over.
        ("clear", (46, 60, 48, 66), "."),
        ("hline", "o", 63, 44, 48),
        ("set", "o", [(45, 64)]), ("hline", "w", 64, 46, 48),
        ("hline", "o", 65, 46, 48),
        ("set", "o", [(48, 66)]),
    ],
    7: [
        # Stern quarter: the square sail's back hides the jib and all of its stay but the one
        # pixel leaving the truck. Nothing else to do.
        ("clear_pts", [(62, 41)]),
    ],
    # Stern on: jib and stay both hidden. The rope down the mast's back is the halyard.
    8: [],
}


## The recycle mark, as painted on the square sail's lit face: two curved arrows chasing
## clockwise round one ring, one over the top and one under, each ending in a chevron head
## with a gap before the next tail — the mark on the yard's recycle box (assets/
## Recycle_Box.png), which the ferry serves. Drawn as geometry on a unit canvas and decided
## pixel by pixel: each frame pixel's centre is mapped back onto the canvas and tested,
## distance to the ring for the arcs and point-in-triangle for the heads, so an edge is a
## pixel that is on or off rather than a blurred step (2026-09-12: the earlier three bent
## arrows round a triangle, drawn at zoom and boxed down, came out ragged, and Richard
## wanted them round like the box's). Fractions are of the canvas's width: the ring's
## radius and the bar's thickness, the head's half-width across the ring and its length
## along it, and the angles: each arc runs MARK_SWEEP from its tail with the head at its
## end, so the gap between the head and the next tail is what is left of the half turn.
MARK_RADIUS = 0.39
MARK_THICK = 0.13
MARK_HEAD_W = 0.21
MARK_HEAD_L = 0.24
MARK_SWEEP = 2.0
MARK_START = -0.35
## A one-pixel edge round each arrow, on the face's white, in the sheet's dark wood rather
## than its outline ink — a slight line, so the blue stands off the cloth without the mark
## reading as inked on. All the way round each arrow, as the box's own arrows are lined:
## every white pixel beside a painted one, edge-on (not diagonally), so the line stays one
## pixel thin on the curves.
MARK_EDGE = "d"
## The canvas the mark is painted on in each frame that carries it: a parallelogram on the
## sail's lit face — top-left, top-right and bottom-left corners in frame pixels, the fourth
## implied — measured off the face's white rows with a pixel or two of cloth kept round it.
## The mark is mapped onto that parallelogram, so in a quartering heading it leans and
## foreshortens with the cloth instead of lying flat over it, and it is then clipped to the
## face's own white pixels, so nothing of it lands on the shaded head strip, the billow or
## the sky. Frames 0-3 and their mirrors show the face; the side view (4) shows only the
## sail's billow edge, a lens a few pixels wide, and gets the mark squeezed into that so a
## hint of the blue shows at every heading the painted side faces. The stern quarters show
## the sail's back, the slate face, and are left plain, by decision.
## The canvas is a square on the cloth, foreshortened as the sail is: about seven tenths of
## the face's width bow on (a wider one crowded the reef points), the same share of each
## narrower face, and a shallower slope for its top and bottom edges than the face's own
## (2026-09-12): sheared to the cloth's full slope, the ring in the quartering headings
## tilted into a flat ellipse, and the pixel art's sail is hardly foreshortened there — its
## face is 26 px wide against 34 bow on — so a lean of a couple of rows is all it can carry.
MARK_QUAD = {
    0: ((52, 51), (75, 51), (52, 71)),
    1: ((51, 50), (74, 50), (51, 70)),
    2: ((52, 48), (69, 50), (52, 65)),
    3: ((53, 46), (64, 51), (53, 60)),
    4: ((56, 46), (61, 49), (56, 60)),
}
## Where the frames turn about: the mast's column, and the water at the axis's depth,
## which is the side view's waterline (frame 4, whose whole near side is at that depth).
ANCHOR_X = 64
SIDE_FRAME = 4

## The waterline of each frame is one level row, SINK_ROWS up from the bottom of the hull's
## body at the near end — the hull sits in the water by just that much, the stem foot and
## the rudder post under it. The body's bottom is the lowest row with HULL_WIDE opaque
## pixels, which the post and the foot fall short of. Level by decision (2026-09-11): a
## line following the boot-top along the near side ran diagonally into the bow and the
## transom in the quartering headings and made a V across the bow face end on; a level
## line at the near end leaves the far end of a quartering hull riding a little high, the
## lesser wrong. Derived from the pixels; a frame that comes out wrong can be pinned here.
SINK_ROWS = 2
HULL_WIDE = 8
CUT_ROW = {}

## How many rows above the line the hull's width is read over, for the collar's ends. The
## far end of a quartering hull bottoms out above the line, and a collar read off the one
## row under it stopped short of that end.
CUT_BAND = 4


def repaint_hull(frame):
    px = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if px[x, y] == INK["x"]:
                px[x, y] = INK["X"]


def mark_on(u, v):
    """Whether the canvas point (u, v), in a unit square, is under the mark's paint."""
    import math
    x, y = u - 0.5, v - 0.5
    r = math.hypot(x, y)
    ang = math.atan2(y, x)
    for k in range(2):
        tail = MARK_START + math.pi * k
        along = (ang - tail) % (2 * math.pi)
        if abs(r - MARK_RADIUS) <= MARK_THICK * 0.5 and along <= MARK_SWEEP:
            return True
        # The head: a triangle across the ring at the arc's end, pointing on round it.
        tip = tail + MARK_SWEEP
        cx, cy = math.cos(tip) * MARK_RADIUS, math.sin(tip) * MARK_RADIUS
        fx, fy = -math.sin(tip), math.cos(tip)
        px, py = x - cx, y - cy
        f = px * fx + py * fy
        n = px * math.cos(tip) + py * math.sin(tip)
        if -MARK_THICK * 0.3 <= f <= MARK_HEAD_L                 and abs(n) <= MARK_HEAD_W * (1.0 - (f + MARK_THICK * 0.3) / (MARK_HEAD_L + MARK_THICK * 0.3)):
            return True
    return False


def mark_bitmap(quad, mirror=False):
    """The mark laid on the parallelogram `quad` (top-left, top-right, bottom-left, in frame
    pixels), as a FRAME x FRAME grid of booleans: every frame pixel's centre mapped back to
    the canvas and tested."""
    (tlx, tly), (trx, try_), (blx, bly) = quad
    if mirror:
        tlx, trx, blx = FRAME - 1 - tlx, FRAME - 1 - trx, FRAME - 1 - blx
    ax, ay = trx - tlx, try_ - tly
    bx, by = blx - tlx, bly - tly
    det = float(ax * by - ay * bx)
    # Corners are pixel centres; the canvas runs half a pixel past them.
    bits = [[False] * FRAME for _ in range(FRAME)]
    for y in range(FRAME):
        for x in range(FRAME):
            dx, dy = x - tlx, y - tly
            u = (dx * by - dy * bx) / det
            v = (ax * dy - ay * dx) / det
            if -0.02 <= u <= 1.02 and -0.02 <= v <= 1.02 and mark_on(u, v):
                bits[y][x] = True
    return bits


def stamp_mark(frame, quad, mirror=False):
    """Paint the mark onto the face's own white pixels, and nothing else, with its edge."""
    bits = mark_bitmap(quad, mirror)
    px = frame.load()
    lit = INK["W"]
    for y in range(FRAME):
        for x in range(FRAME):
            if bits[y][x] and px[x, y] != lit:
                bits[y][x] = False
    for y in range(FRAME):
        for x in range(FRAME):
            if bits[y][x] or px[x, y] != lit:
                continue
            if any(0 <= x + dx < FRAME and 0 <= y + dy < FRAME and bits[y + dy][x + dx]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = INK[MARK_EDGE]
    for y in range(FRAME):
        for x in range(FRAME):
            if bits[y][x]:
                px[x, y] = INK["R"]


def cut_row(frame, n):
    """The row a frame is cut at: everything from it down is under the water."""
    if n in CUT_ROW:
        return CUT_ROW[n]
    px = frame.load()
    body = [y for y in range(FRAME)
            if sum(1 for x in range(FRAME) if px[x, y][3] == 255) >= HULL_WIDE]
    return (max(body) + 1 - SINK_ROWS) if body else FRAME // 2


def cut_of(frame, n):
    """The waterline across one edited frame: left end, right end, in frame pixels."""
    row = cut_row(frame, n)
    band = frame.crop((0, max(row - CUT_BAND, 0), FRAME, row)).getbbox()
    if band is None:
        return [(ANCHOR_X - 23, row), (ANCHOR_X + 23, row)]
    return [(band[0], row), (band[2], row)]


def cuts(frames):
    return [cut_of(frames[n], n) for n in range(FRAMES)]


def anchor(frames):
    return (ANCHOR_X, cut_row(frames[SIDE_FRAME], SIDE_FRAME))


def strip_shadow(frame):
    px = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if px[x, y][3] < 255:
                px[x, y] = INK[" "]


def apply(frame, ops, mirror=False):
    px = frame.load()

    def mx(x):
        return FRAME - 1 - x if mirror else x

    def put(x, y, letter):
        px[mx(x), y] = INK[letter]

    for op in ops:
        kind = op[0]
        if kind == "clear":
            (x0, y0, x1, y1), letters = op[1], op[2]
            wanted = {INK[c] for c in letters}
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if px[mx(x), y] in wanted:
                        put(x, y, " ")
        elif kind == "clear_pts":
            for x, y in op[1]:
                put(x, y, " ")
        elif kind == "set":
            for x, y in op[2]:
                put(x, y, op[1])
        elif kind == "box":
            x0, y0, x1, y1 = op[2]
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    put(x, y, op[1])
        elif kind == "hline":
            _, letter, y, x0, x1 = op
            for x in range(x0, x1 + 1):
                put(x, y, letter)
        elif kind == "vline":
            _, letter, x, y0, y1 = op
            for y in range(y0, y1 + 1):
                put(x, y, letter)
        else:
            raise ValueError(op)


def build():
    source = Image.open(SOURCE).convert("RGBA")
    frames = []
    for n in range(FRAMES):
        frame = source.crop((n * FRAME, 0, (n + 1) * FRAME, FRAME))
        strip_shadow(frame)
        if n <= 8:
            apply(frame, OPS[n])
        else:
            apply(frame, OPS[16 - n], mirror=True)
        repaint_hull(frame)
        if n in MARK_QUAD:
            stamp_mark(frame, MARK_QUAD[n])
        elif 16 - n in MARK_QUAD:
            stamp_mark(frame, MARK_QUAD[16 - n], mirror=True)
        frames.append(frame)
    return frames


def write(frames):
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for n, frame in enumerate(frames):
        sheet.paste(frame, (n * FRAME, 0))
    sheet.save(OUT_PNG)
    OUT_JSON.write_text(json.dumps({
        "source": "art_source/Blue_Boat/blue_boat_16dir.png",
        "frames": FRAMES,
        "frame": FRAME,
        "frame_zero": "bow towards the camera; frames turn clockwise seen from above",
        "anchor": list(anchor(frames)),
        "cut": [[list(at) for at in line] for line in cuts(frames)],
        "edits": "jib, forestay and floor shadow removed, hull repainted in the recycle "
                 "box's brown, recycle mark on the square sail, by tools/build_boat_sheet.py",
    }, indent="\t") + "\n")


def ascii_dump(frame, x0=32, x1=98, y0=30, y1=100):
    px = frame.load()
    lines = ["    " + "".join(str((x // 10) % 10) if x % 10 == 0 else " " for x in range(x0, x1)),
             "    " + "".join(str(x % 10) for x in range(x0, x1))]
    for y in range(y0, y1):
        lines.append("%3d " % y + "".join(LETTER.get(px[x, y], "?") for x in range(x0, x1)))
    return "\n".join(lines)


def zoom_frame(frame, path, x0=30, y0=28, x1=100, y1=108, z=12):
    """One frame's box at `z`, gridded and numbered every four pixels, for authoring ops."""
    crop = frame.crop((x0, y0, x1, y1))
    w, h = crop.size
    out = Image.new("RGBA", (w * z + 40, h * z + 40), (255, 0, 255, 255))
    big = crop.resize((w * z, h * z), Image.NEAREST)
    out.paste(big, (40, 40), big)
    draw = ImageDraw.Draw(out)
    for i in range(w + 1):
        strong = (x0 + i) % 4 == 0
        draw.line([(40 + i * z, 40), (40 + i * z, 40 + h * z)], fill=(0, 0, 0, 200 if strong else 90))
        if strong:
            draw.text((40 + i * z - 6, 4 if (x0 + i) % 8 == 0 else 20), str(x0 + i), fill=(0, 0, 0, 255))
    for i in range(h + 1):
        strong = (y0 + i) % 4 == 0
        draw.line([(40, 40 + i * z), (40 + w * z, 40 + i * z)], fill=(0, 0, 0, 200 if strong else 90))
        if strong:
            draw.text((2, 40 + i * z - 5), str(y0 + i), fill=(0, 0, 0, 255))
    out.save(path)


def contact(frames, path, zoom=4):
    """Every frame at `zoom`, source over result, on magenta, for checking the edit."""
    source = Image.open(SOURCE).convert("RGBA")
    cols = 8
    rows = (FRAMES + cols - 1) // cols
    cell = FRAME * zoom
    out = Image.new("RGBA", (cols * cell, rows * cell * 2), (255, 0, 255, 255))
    draw = ImageDraw.Draw(out)
    for n, frame in enumerate(frames):
        cx, cy = (n % cols) * cell, (n // cols) * cell * 2
        before = source.crop((n * FRAME, 0, (n + 1) * FRAME, FRAME)).resize((cell, cell), Image.NEAREST)
        after = frame.resize((cell, cell), Image.NEAREST)
        out.paste(before, (cx, cy), before)
        out.paste(after, (cx, cy + cell), after)
        draw.text((cx + 4, cy + 4), str(n), fill=(0, 0, 0, 255))
    out.save(path)


def main(argv):
    frames = build()
    if "--zoom" in argv:
        where = Path(argv[argv.index("--zoom") + 1])
        for n in argv[argv.index("--zoom") + 2:]:
            if n.startswith("--"):
                break
            zoom_frame(frames[int(n)], where / ("z%s.png" % n))
        return
    if "--ascii" in argv:
        for n in argv[argv.index("--ascii") + 1:]:
            if n.startswith("--"):
                break
            print("frame", n)
            print(ascii_dump(frames[int(n)]))
        return
    write(frames)
    if "--contact" in argv:
        contact(frames, argv[argv.index("--contact") + 1])
    print("wrote %s (%d frames)" % (OUT_PNG.relative_to(ROOT), len(frames)))


if __name__ == "__main__":
    main(sys.argv[1:])

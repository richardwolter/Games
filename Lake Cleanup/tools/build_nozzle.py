#!/usr/bin/env python
"""Draw the wash stand's nozzle at every heading it aims through, as pixel art.

A brass fireman's nozzle on an oak grip with a canvas hose running off the bottom of the
screen (issue #37, `/grill-me` with Richard 2026-09-19: the drawn placeholder was a thick
line turned towards the pointer, "ugly and blocky, not pixel art"). Pixel art cannot be
turned freely, so it is not turned at all: this draws it once per heading, each on the art
grid with its own outline and its own shading, and the game picks the nearest — the ferry's
sixteen headings, for the same reason.

**Every heading is drawn on its own, none is a mirror of another.** The light is on the
right in every painted thing in this game, and a mirrored frame has it on the left.

Built from rules rather than painted, the way the piers, the cursor and the shed were, so a
re-run reproduces it and the numbers can be nudged. Richard polishes the PNG afterwards;
the json holds for as long as the frames keep their rectangles.

The nozzle is a run of round sections along one axis (`PARTS`): hose, grip, collar, cone,
lip. A pixel belongs to the part whose stretch of the axis it is beside, if it is within
that part's half-width there. Its tone is how far round the section it is towards the
light, cut into three hard steps — a cylinder lit from one side, which is what every part
of this is — with a one-pixel shine down the brass on the lit side.

Output:
  assets/nozzle.png             the headings in one row
  assets/nozzle.json            per frame: rect, pivot, tip, bead, glint run
  tools/last_nozzle_sheet.png   the row at 6x over the wash room's wall, for looking at

Run from the project root:
  <psd-extract venv python> tools/build_nozzle.py

Reimport afterwards, as every builder here needs:
  <godot> --path . --headless --import
"""

from __future__ import annotations

import colorsys
import json
import math
import os
import re
from PIL import Image

ASSET = os.path.join("assets", "nozzle.png")
CONTRACT = os.path.join("assets", "nozzle.json")
SHEET = os.path.join("tools", "last_nozzle_sheet.png")
BOX = os.path.join("art_source", "recycle_box_painted.png")
PALETTE = os.path.join("resources", "palette.tres")

## The headings, in degrees off straight up, left to right. One frame each.
##
## **One, the straight one** (Richard, 2026-09-19, second look): a picture that changed with
## every move read as a different nozzle each time. The nozzle slides and never turns. Set
## `SWING` back to 50 and every heading is drawn again; nothing else here has to change.
##
## **And it turns after all, as one drawing** (third look the same day: "the tip should also
## move with the hose curving and point sideways, but keep the consistency"). So the
## straight frame is drawn once, by rule, and **every other heading is that same picture
## turned** (`turned`) — not drawn again. What read as a different nozzle each move was each
## heading being lit and cut afresh; turned, the shine stays down the same side of the brass
## and the wraps stay where they are. Fine steps, so it swings rather than clicks.
SWING = 48
STEP = 4
## Samples a side per pixel when a frame is turned: the colour most of them land on wins,
## which is what keeps a turned edge from fraying into single pixels.
TURN_SAMPLES = 4
HEADINGS = list(range(-SWING, SWING + 1, STEP))

## One frame, and where in it the nozzle hangs from. The hose runs from the pivot back out
## of the frame; everything else runs from it forwards.
FRAME = 96
PIVOT = (48, 72)

## The sections along the axis, in art pixels from the pivot: (name, from, to, half-width at
## `from`, half-width at `to`). The brass is wider than the wood so the collar reads as a
## ring round the grip's end, and the lip is a bead round the cone's.
PARTS = [
    ("grip", 0.0, 9.0, 4.6, 4.6),
    ("collar", 9.0, 12.0, 6.2, 6.2),
    ("cone", 12.0, 23.5, 5.2, 2.8),
    ("lip", 23.5, 26.0, 3.8, 3.8),
]
TIP = 26.0

## The hose. **It hangs, it does not stick out behind**: drawn straight in line with the
## nozzle it read as a broom handle. It leaves the grip along the nozzle's own axis and turns
## to hang straight down over `HOSE_TURN` pixels of its length, so a nozzle held over to one
## side trails a curve. Walked as a centre line in `HOSE_STEP`s; a pixel is hose when it is
## within `HOSE_HALF` of that line.
##
## **Not baked since the nozzle became one straight picture** (`HOSE_BAKED`): a hose hanging
## straight down under a nozzle that never turns has no curve in it, and the curve was the
## part with the life. `WashStand._draw_hose` lays it out every frame instead, in the tones
## and the edge colour this writes into the json, so the two stay one drawing.
HOSE_BAKED = False
HOSE_LONG = 44.0
HOSE_TURN = 26.0
HOSE_HALF = 3.6
HOSE_STEP = 0.25

## Where the light comes from on the screen: right and a little up.
LIGHT = (0.8, -0.6)
LIT_OVER = 0.3
DARK_UNDER = -0.35
## The shine down the brass: a one-pixel line this far round towards the light.
SHINE_AT = 0.5
SHINE_WIDE = 0.2

## Brass is not in the pack's palette; these are authored. Dark, body, lit, shine.
BRASS = [(112, 78, 34), (176, 130, 54), (226, 184, 92), (255, 236, 176)]
## Bands across the grip, in pixels along the axis: the wrap that holds the collar on.
WRAPS = [(1.0, 2.5), (6.5, 8.0)]
## How often the canvas hose's weave shows, along the axis.
WEAVE = 3.0
GRAIN_ODDS = 0.16
EDGE = (48, 37, 33)
BORE = (30, 24, 22)

SHEET_ZOOM = 6
WALL = (18, 33, 36)


def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def box_browns():
    """The recycle box's plank browns, darkest to lightest, in four: tools/recolor_shed.py's
    own rule, so the grip is the wood the hut and the ferry already are."""
    image = Image.open(BOX).convert("RGBA")
    px = image.load()
    planks = []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, _v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 12.0 <= h * 360.0 <= 45.0 and s >= 0.2:
                planks.append((r, g, b))
    planks.sort(key=luma)
    n = len(planks)
    bins = []
    for i in range(4):
        chunk = planks[i * n // 4:max((i + 1) * n // 4, i * n // 4 + 1)]
        bins.append(tuple(int(round(sum(c[j] for c in chunk) / len(chunk))) for j in range(3)))
    return bins


def palette_colour(name):
    text = open(PALETTE, encoding="utf-8").read()
    found = re.search(r"^%s = Color\(([^)]*)\)" % name, text, re.M)
    parts = [float(v) for v in found.group(1).split(",")]
    return tuple(int(round(v * 255)) for v in parts[:3])


def scaled(colour, by):
    return tuple(max(0, min(255, int(round(c * by)))) for c in colour)


def hashed(a, b, c=0):
    h = (a * 374761393 + b * 668265263 + c * 1274126177) & 0x7FFFFFFF
    h = ((h ^ (h >> 13)) * 1103515245) & 0x7FFFFFFF
    return (h ^ (h >> 16)) / 2147483648.0


def part_at(u):
    for name, start, end, wide_from, wide_to in PARTS:
        if start <= u < end:
            t = (u - start) / (end - start)
            return name, wide_from + (wide_to - wide_from) * t
    return None, 0.0


def tone_of(name, u, v, half, lit, inks):
    """The colour of one pixel of one part. `lit` is -1 to 1, how far round towards the
    light; `v` is across the axis in pixels."""
    step = 2 if lit > LIT_OVER else (0 if lit < DARK_UNDER else 1)
    if name in ("collar", "cone", "lip"):
        if abs(lit - SHINE_AT) < SHINE_WIDE and name != "lip":
            return BRASS[3]
        # The collar and the lip stand proud of what is either side: a step lighter.
        if name != "cone":
            step = min(step + 1, 2)
        return BRASS[step]
    if name == "grip":
        for start, end in WRAPS:
            if start <= u < end:
                return inks["wrap"][min(step, 1)]
        if hashed(int(u // 4), int(round(v)), 5) < GRAIN_ODDS:
            return inks["wood"][max(step - 1, 0)]
        return inks["wood"][step + 1]
    # The hose: canvas, with its weave showing as a darker band every few pixels.
    if int(u // WEAVE) % 2 == 0:
        step = max(step - 1, 0)
    return inks["hose"][step]


def hose_line(turn):
    """The hose's centre line from the pivot back: (x, y, length along it, across-x,
    across-y) per step, the heading easing from the nozzle's own to straight down."""
    line = []
    x, y = float(PIVOT[0]), float(PIVOT[1])
    walked = 0.0
    while walked < HOSE_LONG:
        ease = min(walked / HOSE_TURN, 1.0)
        ease = ease * ease * (3.0 - 2.0 * ease)
        angle = turn * (1.0 - ease)
        back = (-math.sin(angle), math.cos(angle))
        line.append((x, y, walked, math.cos(angle), math.sin(angle)))
        x += back[0] * HOSE_STEP
        y += back[1] * HOSE_STEP
        walked += HOSE_STEP
    return line


def draw_hose(px, kinds, turn, inks):
    line = hose_line(turn)
    for y in range(FRAME):
        for x in range(FRAME):
            if kinds[y][x] is not None:
                continue
            cx, cy = x + 0.5, y + 0.5
            if math.hypot(cx - PIVOT[0], cy - PIVOT[1]) > HOSE_LONG + HOSE_HALF:
                continue
            best = None
            best_far = HOSE_HALF * HOSE_HALF
            for sx, sy, walked, ax, ay in line:
                far = (cx - sx) ** 2 + (cy - sy) ** 2
                if far <= best_far:
                    best_far = far
                    best = (sx, sy, walked, ax, ay)
            if best is None or best[2] <= 0.0:
                continue
            sx, sy, walked, ax, ay = best
            v = (cx - sx) * ax + (cy - sy) * ay
            lit = (v / HOSE_HALF) * (ax * LIGHT[0] + ay * LIGHT[1])
            kinds[y][x] = "hose"
            px[x, y] = tone_of("hose", walked, v, HOSE_HALF, lit, inks) + (255,)


def draw_heading(degrees, inks):
    turn = math.radians(degrees)
    along = (math.sin(turn), -math.cos(turn))
    across = (math.cos(turn), math.sin(turn))
    kinds = [[None] * FRAME for _ in range(FRAME)]
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    px = frame.load()
    for y in range(FRAME):
        for x in range(FRAME):
            dx = x + 0.5 - PIVOT[0]
            dy = y + 0.5 - PIVOT[1]
            u = dx * along[0] + dy * along[1]
            v = dx * across[0] + dy * across[1]
            name, half = part_at(u)
            if name is None or abs(v) > half:
                continue
            # A cylinder seen from the side: across it, the surface turns from facing one
            # way to facing the other, and how lit it is is how much of that faces the lamp.
            round_it = v / half
            lit = round_it * (across[0] * LIGHT[0] + across[1] * LIGHT[1])
            kinds[y][x] = name
            px[x, y] = tone_of(name, u, v, half, lit, inks) + (255,)
    if HOSE_BAKED:
        draw_hose(px, kinds, turn, inks)
    # The bore: the last pixel of the lip, across its middle, is the hole the water leaves by.
    for y in range(FRAME):
        for x in range(FRAME):
            if kinds[y][x] != "lip":
                continue
            dx = x + 0.5 - PIVOT[0]
            dy = y + 0.5 - PIVOT[1]
            u = dx * along[0] + dy * along[1]
            v = dx * across[0] + dy * across[1]
            if u > TIP - 1.1 and abs(v) < 2.0:
                px[x, y] = BORE + (255,)
    return frame


def turned(straight, degrees):
    """The straight frame turned about the pivot onto the art grid. Each pixel asks a grid
    of points inside itself where they came from and takes the commonest answer."""
    turn = math.radians(degrees)
    cos_t, sin_t = math.cos(turn), math.sin(turn)
    src = straight.load()
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    px = frame.load()
    for y in range(FRAME):
        for x in range(FRAME):
            votes = {}
            for j in range(TURN_SAMPLES):
                for i in range(TURN_SAMPLES):
                    dx = x + (i + 0.5) / TURN_SAMPLES - PIVOT[0]
                    dy = y + (j + 0.5) / TURN_SAMPLES - PIVOT[1]
                    sx = int(math.floor(PIVOT[0] + cos_t * dx + sin_t * dy))
                    sy = int(math.floor(PIVOT[1] - sin_t * dx + cos_t * dy))
                    ink = src[sx, sy] if 0 <= sx < FRAME and 0 <= sy < FRAME else (0, 0, 0, 0)
                    if ink[3] == 0:
                        ink = (0, 0, 0, 0)
                    votes[ink] = votes.get(ink, 0) + 1
            # A one-pixel line never wins a vote — the shine down the brass and the bore at
            # the lip are both thinner than the pixel asking — so where the pixel's own
            # middle lands on one, it is kept. Those two are the nozzle's face.
            dx, dy = x + 0.5 - PIVOT[0], y + 0.5 - PIVOT[1]
            sx = int(math.floor(PIVOT[0] + cos_t * dx + sin_t * dy))
            sy = int(math.floor(PIVOT[1] - sin_t * dx + cos_t * dy))
            middle = src[sx, sy] if 0 <= sx < FRAME and 0 <= sy < FRAME else (0, 0, 0, 0)
            if middle[3] != 0 and middle[:3] in (BRASS[3], BORE):
                px[x, y] = middle
            else:
                px[x, y] = max(votes, key=votes.get)
    return frame


def tidy(frame):
    """Take off any pixel hanging on by a corner: a rotated edge leaves a few, and a lone
    pixel on a silhouette is the first thing a pixel artist would rub out."""
    px = frame.load()
    for _ in range(2):
        loose = []
        for y in range(FRAME):
            for x in range(FRAME):
                if px[x, y][3] == 0:
                    continue
                near = 0
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + ddx, y + ddy
                    if 0 <= xx < FRAME and 0 <= yy < FRAME and px[xx, yy][3] != 0:
                        near += 1
                if near < 2:
                    loose.append((x, y))
        for x, y in loose:
            px[x, y] = (0, 0, 0, 0)


def outline(frame):
    """One pixel of the box's own edge colour round the outside, edge-on only."""
    px = frame.load()
    ring = []
    for y in range(FRAME):
        for x in range(FRAME):
            if px[x, y][3] != 0:
                continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < FRAME and 0 <= yy < FRAME and px[xx, yy][3] != 0:
                    ring.append((x, y))
                    break
    for x, y in ring:
        px[x, y] = EDGE + (255,)


def point(along, across, u, v=0.0):
    return [
        round(PIVOT[0] + along[0] * u + across[0] * v, 2),
        round(PIVOT[1] + along[1] * u + across[1] * v, 2),
    ]


def main():
    browns = box_browns()
    sand = palette_colour("sand")
    inks = {
        "wood": browns,
        "wrap": [scaled(browns[0], 0.7), scaled(browns[0], 0.95)],
        "hose": [scaled(sand, 0.5), scaled(sand, 0.68), scaled(sand, 0.84)],
    }
    sheet = Image.new("RGBA", (FRAME * len(HEADINGS), FRAME), (0, 0, 0, 0))
    frames = []
    straight = draw_heading(0, inks)
    for i, degrees in enumerate(HEADINGS):
        turn = math.radians(degrees)
        along = (math.sin(turn), -math.cos(turn))
        across = (math.cos(turn), math.sin(turn))
        # Turned bare and outlined after, so the outline is one clean pixel at every
        # heading rather than a turned line with gaps in it.
        frame = turned(straight, degrees) if degrees != 0 else straight.copy()
        tidy(frame)
        outline(frame)
        sheet.paste(frame, (i * FRAME, 0))
        # Which side the light is on, across the axis: the shine runs down that side, and
        # the bead hangs off whichever end of the lip is lower on the screen.
        lit_side = 1.0 if (across[0] * LIGHT[0] + across[1] * LIGHT[1]) >= 0.0 else -1.0
        low_side = 1.0 if across[1] >= 0.0 else -1.0
        frames.append({
            "heading": degrees,
            "rect": [i * FRAME, 0, FRAME, FRAME],
            "pivot": list(PIVOT),
            "tip": point(along, across, TIP),
            "bead": point(along, across, TIP - 1.0, low_side * 3.0),
            "glint_from": point(along, across, PARTS[1][1] + 1.0, lit_side * 3.0),
            "glint_to": point(along, across, TIP - 2.0, lit_side * 1.5),
        })
    sheet.save(ASSET)
    with open(CONTRACT, "w", encoding="utf-8", newline="\n") as out:
        hose = {"half": HOSE_HALF, "weave": WEAVE, "edge": list(EDGE),
                "inks": [list(c) for c in inks["hose"]]}
        json.dump({"step": STEP, "swing": SWING, "frame": FRAME, "hose": hose,
                   "frames": frames}, out, indent=1)
        out.write("\n")

    look = Image.new("RGBA", (sheet.width * SHEET_ZOOM, sheet.height * SHEET_ZOOM), WALL + (255,))
    big = sheet.resize(look.size, Image.NEAREST)
    look.alpha_composite(big)
    look.save(SHEET)
    print("nozzle: %d headings, %dx%d, browns %s" % (len(HEADINGS), sheet.width, sheet.height, browns))


if __name__ == "__main__":
    main()

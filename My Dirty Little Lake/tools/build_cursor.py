#!/usr/bin/env python
"""Draw the wooden cursor variants and the aim ring's candidate colours, and lay them
out on one contact sheet for Richard to pick from.

Nothing here is read by the game. This writes options; once a winner is named, the picked
cursor is baked to assets/cursor.png and the picked ring pair becomes three constants in
scripts/net.gd.

The cursor is a standard arrow silhouette -- the shape every pointer has, so nobody has to
work out what it is -- with a one-pixel black outline round it and wood inside. Two woods
are drawn: the menus' oak with its grain, its lit top-left edge and V bites out of its
sides, and the recycle box's plank brown with seams across the shaft. Both are built from
rules rather than painted, the way the piers and the shed are, so a re-run reproduces them
and the numbers can be nudged.

The ring rows draw the real marker -- a 2:1 ellipse, a 1.5 px line, the game's own alphas,
dashed for a refused throw -- over clean, murky and dirty water, in three candidate
palette-toned green/red pairs, each over the dark backing line.

Output:
  assets/cursor.png                   the picked cursor, which the game loads
  tools/cursor/<wood>_<scale>x.png    each cursor at each size, transparent
  tools/last_cursor_mockup.png        the contact sheet

Run from the project root:
  <psd-extract venv python> tools/build_cursor.py

Reimport afterwards, as every builder here needs:
  <godot> --path . --headless --import
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.join("tools", "cursor")
SHEET = os.path.join("tools", "last_cursor_mockup.png")
ASSET = os.path.join("assets", "cursor.png")

## What Richard picked off the contact sheet (2026-09-16): the menus' oak, bitten, at the
## 2 screen pixels an art pixel the rest of the game's art is drawn at. Change this and
## re-run to bake a different one; the sheet still draws every option either way.
PICKED = ("oak", 2)

# How many screen pixels an art pixel is drawn at on the sheet. The game draws its art at
# 2 (Lake.ART_PIXEL), so 2 is the size that matches everything else on screen; 1 and 3 are
# there to judge it small and large.
SCALES = (1, 2, 3)


def rgb(r: float, g: float, b: float) -> tuple[int, int, int]:
    """A Godot Color literal as 8-bit RGB, so the constants below can be copied straight
    out of style.gd and palette.tres without being converted by hand."""
    return (round(r * 255), round(g * 255), round(b * 255))


# --- the game's own colours -------------------------------------------------------------
# style.gd
FRAME = rgb(0.62, 0.46, 0.36)
FRAME_LIT = rgb(0.71, 0.55, 0.45)
FRAME_LOW = rgb(0.55, 0.33, 0.25)
FRAME_DEEP = rgb(0.26, 0.17, 0.11)
FRAME_GRAIN = rgb(0.48, 0.30, 0.22)
BOX = rgb(0.47, 0.35, 0.25)
BOX_LIT = rgb(0.63, 0.44, 0.31)
BOX_DEEP = rgb(0.35, 0.22, 0.16)
BOARD = rgb(0.17, 0.24, 0.25)
HOLE_RIM = (0, 0, 0)

# palette.tres
SAND = rgb(0.91, 0.804, 0.592)
WATER_CLEAN = rgb(0.255, 0.42, 0.573)
WATER_CLEAN_SHALLOW = rgb(0.498, 0.655, 0.776)
WATER_MURKY = rgb(0.16, 0.32, 0.31)
WATER_MURKY_SHALLOW = rgb(0.34, 0.5, 0.45)
WATER_DIRTY = rgb(0.094, 0.227, 0.067)
WATER_DIRTY_SHALLOW = rgb(0.227, 0.353, 0.141)
GRASS_LIGHT = rgb(0.427, 0.529, 0.251)
WOOD = rgb(0.541, 0.235, 0.141)
FOAM = rgb(0.933, 0.965, 0.984)


# --- the arrow --------------------------------------------------------------------------
# The classic pointer, as a polygon rather than a table of rows: tip, straight down the
# left edge, in to the notch, out along the tail, across it, back to the notch, and out to
# the head's far point. Rasterised at ART_TALL art pixels, so the whole silhouette is one
# number to resize and the diagonals stay clean at any of them. The shape of every arrow
# cursor there has ever been, which is the whole point of keeping it.
ARROW = [
    (0.00, 0.00),   # the tip, and the hotspot
    (0.00, 0.84),   # down the straight left edge
    (0.19, 0.66),   # in to the notch
    (0.33, 0.97),   # down the tail's near side
    (0.46, 0.92),   # across the tail's foot
    (0.32, 0.61),   # back up the tail's far side
    (0.56, 0.60),   # out to the head's far point
]

## How tall the arrow's wood is, in art pixels, before the one-pixel outline round it.
ART_TALL = 19

# One art pixel of margin all round, for the black outline to live in.
PAD = 1

# Rasterised at this multiple and then thresholded, so the diagonals land on the same
# pixels a hand-drawn arrow would rather than on whatever a single point sample hits.
RASTER = 8


def silhouette() -> set[tuple[int, int]]:
    tall = ART_TALL
    wide = round(max(x for x, _ in ARROW) * tall) + 1
    big = Image.new("L", (wide * RASTER, tall * RASTER), 0)
    ImageDraw.Draw(big).polygon(
        [(x * tall * RASTER, y * tall * RASTER) for x, y in ARROW], fill=255
    )
    small = big.resize((wide, tall), Image.BOX)
    pix = small.load()
    cells: set[tuple[int, int]] = set()
    for y in range(tall):
        for x in range(wide):
            # Half covered is in: an arrow whose edge pixels are all dropped comes out
            # a size smaller than it was authored at.
            if pix[x, y] >= 128:
                cells.add((x + PAD, y + PAD))
    return cells


# The bites: V notches out of the wood's outer edge, narrowing to a point, the way every
# plank and frame in the menus is chipped (Style.frame_bites).
#
# **The straight left edge is left whole, and the tip with it, by decision**: the left edge
# is the arrow's identity and the tip is the hotspot, so a notch in either reads as a broken
# pointer rather than as chipped wood. Bites are given as fractions down the long diagonal
# edge, so they stay in the same place at any ART_TALL.
OAK_BITES = [(0.40, 3), (0.72, 2)]


def carve(cells: set[tuple[int, int]], bites) -> None:
    """Take a V out of the long diagonal edge at each fraction down it. The widest row is
    the one on the edge; each row in is a pixel narrower, so the notch comes to a point."""
    if not bites:
        return
    rows = sorted({y for _, y in cells})
    for where, deep in bites:
        y0 = rows[round(where * (len(rows) - 1))]
        for step in range(deep):
            y = y0 + step
            row = [x for x, yy in cells if yy == y]
            if not row:
                continue
            edge = max(row)
            for x in range(edge - (deep - step - 1), edge + 1):
                cells.discard((x, y))


def outline_of(cells: set[tuple[int, int]]) -> set[tuple[int, int]]:
    """Every empty cell touching the wood, corners included. A corner touching a hole at a
    point draws as a loose pixel in the gap otherwise -- the lesson _border_bites learnt."""
    ring: set[tuple[int, int]] = set()
    for x, y in cells:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                spot = (x + dx, y + dy)
                if spot not in cells:
                    ring.add(spot)
    return ring


def shade(cells: set[tuple[int, int]], spot: tuple[int, int]) -> str:
    """Which face of the wood a cell is on. The light is up and to the left, the way every
    painted asset in the game is lit (see The Sun Is in the Southeast)."""
    x, y = spot
    lit = (x - 1, y) not in cells or (x, y - 1) not in cells
    deep = (x + 1, y) not in cells or (x, y + 1) not in cells
    if lit and not deep:
        return "lit"
    if deep and not lit:
        return "deep"
    return "body"


def draw_oak(cells: set[tuple[int, int]]) -> dict[tuple[int, int], tuple[int, int, int]]:
    """The menus' oak: Style.FRAME body, a lit top-left edge, a shaded lower-right one, and
    grain running lengthwise down the wood in FRAME_GRAIN.

    The grain is vertical dashes, two and three cells long, one column in three, staggered
    so no two neighbouring columns start on the same row. Scattered per cell instead it
    reads as noise in the wood rather than as the wood's grain -- which is what a first
    pass did.
    """
    ink: dict[tuple[int, int], tuple[int, int, int]] = {}
    for spot in cells:
        face = shade(cells, spot)
        # FRAME_LOW rather than FRAME_DEEP on the shaded face: at a pixel wide, the deep
        # tone is close enough to the black outline that the two read as one fat rim.
        ink[spot] = {"lit": FRAME_LIT, "deep": FRAME_LOW, "body": FRAME}[face]
    for spot in sorted(cells):
        if ink[spot] is not FRAME:
            continue
        x, y = spot
        if x % 2 == 0:
            continue
        if (y + (x // 2) * 3) % 4 < 2:
            ink[spot] = FRAME_GRAIN
    return ink


def draw_box(cells: set[tuple[int, int]]) -> dict[tuple[int, int], tuple[int, int, int]]:
    """The recycle box's wood: Style.BOX planks with a dark seam across the arrow every few
    rows and a lit row under each, the pitch the piers and the crate are planked at."""
    ink: dict[tuple[int, int], tuple[int, int, int]] = {}
    for spot in cells:
        face = shade(cells, spot)
        ink[spot] = {"lit": BOX_LIT, "deep": BOX_DEEP, "body": BOX}[face]
    for spot in sorted(cells):
        row = (spot[1] - PAD) % 5
        if row == 0 and ink[spot] is BOX:
            ink[spot] = BOX_DEEP
        elif row == 1 and ink[spot] is BOX:
            ink[spot] = BOX_LIT
    return ink


VARIANTS = {
    "oak": (draw_oak, OAK_BITES),
    "box": (draw_box, []),
}


def build_art(name: str) -> tuple[Image.Image, tuple[int, int]]:
    """The cursor at one art pixel per pixel, and where its tip is in it.

    The hotspot is handed back rather than worked out again by the caller, because a hotspot
    that disagrees with the picture is every click landing off the point of the arrow.

    **There is no pressed picture**, by decision (2026-09-16): a bead of lake water baked
    into a second one and swapped in while the button was down read as decoration hanging
    off the pointer. The click is answered by a ripple drawn on its own layer instead
    (`ClickRipple`), which a hardware cursor cannot do.
    """
    make, bites = VARIANTS[name]
    cells = silhouette()
    carve(cells, bites)
    ink = make(cells)
    ring = outline_of(cells)

    wide = max(x for x, _ in ring) + 2
    tall = max(y for _, y in ring) + 2
    art = Image.new("RGBA", (wide, tall), (0, 0, 0, 0))
    pix = art.load()
    for x, y in ring:
        if 0 <= x < wide and 0 <= y < tall:
            pix[x, y] = HOLE_RIM + (255,)
    for spot, colour in ink.items():
        pix[spot[0], spot[1]] = colour + (255,)
    return art, (PAD, PAD)


def build_cursor(name: str, scale: int) -> Image.Image:
    art, _ = build_art(name)
    if scale == 1:
        return art
    return art.resize((art.width * scale, art.height * scale), Image.NEAREST)


def tip_of(name: str, scale: int) -> tuple[int, int]:
    _, tip = build_art(name)
    return (tip[0] * scale, tip[1] * scale)


# --- the aim ring -----------------------------------------------------------------------
# The three readings, in three candidate palette-toned pairs. Green is will-catch, red is
# nothing-to-lift, pale is out-of-range; the meanings do not move, only the swatches.
#
# C is the pick (2026-09-16): the pack's own grass and wood, each multiplied by LIFT so they
# carry over dirty water, rather than two colours invented beside the palette. The pale is
# the lake's foam at every strength -- C's was a hair warmer on the sheet and the two are
# within four parts in 255, which at 0.55 alpha over water is under a pixel step.
LIFT = 1.52


def lift(colour: tuple[int, int, int]) -> tuple[int, int, int]:
    return tuple(min(255, round(c * LIFT)) for c in colour)


RING_PAIRS = [
    ("A  pack as measured", GRASS_LIGHT, WOOD, FOAM),
    ("B  pack lifted", (140, 180, 80), (190, 72, 45), FOAM),
    ("C  pack bright  <- picked", lift(GRASS_LIGHT), lift(WOOD), FOAM),
]

AIM_ALPHA = 0.8
AIM_FAR_ALPHA = 0.55
RING_WIDE = 1.5
# The dark backing, drawn under the coloured line so the marker keeps its contrast on any
# water -- the same black every hole in the menus' wood is ringed with.
BACK_ALPHA = 0.55
BACK_WIDE = 3.5

SS = 4  # supersample, so the ellipse is as smooth as Godot's own draw_polyline


def ring_points(at: tuple[float, float], span: float, steps: int = 48):
    import math
    return [
        (
            at[0] + math.cos(math.tau * i / steps) * span,
            at[1] + math.sin(math.tau * i / steps) * span * 0.5,
        )
        for i in range(steps + 1)
    ]


def draw_ring(over: Image.Image, at: tuple[float, float], span: float,
              colour: tuple[int, int, int], alpha: float, dashed: bool) -> None:
    big = Image.new("RGBA", (over.width * SS, over.height * SS), (0, 0, 0, 0))
    pen = ImageDraw.Draw(big)
    pts = [(x * SS, y * SS) for x, y in ring_points((at[0], at[1]), span)]

    def stroke(ink: tuple[int, int, int, int], wide: float) -> None:
        w = max(1, round(wide * SS))
        if dashed:
            for i in range(len(pts) // 2):
                pen.line([pts[i * 2], pts[i * 2 + 1]], fill=ink, width=w)
        else:
            pen.line(pts, fill=ink, width=w, joint="curve")

    stroke(HOLE_RIM + (round(BACK_ALPHA * alpha / AIM_ALPHA * 255),), BACK_WIDE)
    stroke(colour + (round(alpha * 255),), RING_WIDE)
    over.alpha_composite(big.resize(over.size, Image.LANCZOS))


def water_tile(wide: int, tall: int, deep: tuple[int, int, int],
               light: tuple[int, int, int]) -> Image.Image:
    """A stand-in for the lake: the ramp's two steps in hard bands, the way water.gdshader
    rounds a depth to a step rather than blending it."""
    tile = Image.new("RGBA", (wide, tall), deep + (255,))
    pen = ImageDraw.Draw(tile)
    for y in range(0, tall, 8):
        if (y // 8) % 3 == 0:
            pen.rectangle([0, y, wide, y + 3], fill=light + (255,))
    return tile


# --- the sheet --------------------------------------------------------------------------
INK = (236, 240, 236)
DIM = (150, 158, 150)
BACK = (26, 28, 30)


def font(size: int) -> ImageFont.ImageFont:
    for name in ("consola.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


BIG = font(17)
MID = font(13)
SMALL = font(11)


def build_sheet() -> Image.Image:
    backdrops = [
        ("clean water", water_tile(120, 70, WATER_CLEAN, WATER_CLEAN_SHALLOW)),
        ("dirty water", water_tile(120, 70, WATER_DIRTY, WATER_DIRTY_SHALLOW)),
        ("sand", Image.new("RGBA", (120, 70), SAND + (255,))),
        ("board", Image.new("RGBA", (120, 70), BOARD + (255,))),
        ("white", Image.new("RGBA", (120, 70), (255, 255, 255, 255))),
    ]
    names = {"oak": "menu oak, bitten", "box": "recycle-box plank"}

    tile_w, tile_h = 120, 70
    gap = 10
    left = 24
    row_w = len(backdrops) * (tile_w + gap) - gap
    wide = left * 2 + row_w
    tall = 60 + len(VARIANTS) * (tile_h + 46) + 60 + len(RING_PAIRS) * (150 + 30) + 40
    sheet = Image.new("RGBA", (wide, tall), BACK + (255,))
    pen = ImageDraw.Draw(sheet)

    y = 18
    pen.text((left, y), "CURSOR  -  pick a wood and a size", font=BIG, fill=INK)
    y += 30

    for name in VARIANTS:
        pen.text((left, y), names[name], font=MID, fill=INK)
        y += 18
        x = left
        for label, tile in backdrops:
            sheet.alpha_composite(tile, (x, y))
            at = x + 12
            for scale in SCALES:
                art = build_cursor(name, scale)
                sheet.alpha_composite(art, (at, y + (tile_h - art.height) // 2))
                at += art.width + 12
            pen.text((x, y + tile_h + 3), label, font=SMALL, fill=DIM)
            x += tile_w + gap
        y += tile_h + 28

    pen.text((left, y), f"sizes left to right: {'x, '.join(str(s) for s in SCALES)}x "
                        "screen pixels per art pixel  (the game draws its art at 2x)",
             font=SMALL, fill=DIM)
    y += 34

    pen.text((left, y), "AIM RING  -  pick a green/red pair", font=BIG, fill=INK)
    y += 30

    waters = [
        ("clean", WATER_CLEAN, WATER_CLEAN_SHALLOW),
        ("murky", WATER_MURKY, WATER_MURKY_SHALLOW),
        ("dirty", WATER_DIRTY, WATER_DIRTY_SHALLOW),
    ]
    ring_w = (row_w - 2 * gap) // 3
    ring_h = 150
    for label, green, red, pale in RING_PAIRS:
        pen.text((left, y), label, font=MID, fill=INK)
        y += 18
        x = left
        for water, deep, light in waters:
            tile = water_tile(ring_w, ring_h, deep, light)
            span = ring_w / 7.0
            draw_ring(tile, (ring_w * 0.22, ring_h * 0.34), span, green, AIM_ALPHA, False)
            draw_ring(tile, (ring_w * 0.62, ring_h * 0.34), span, red, AIM_ALPHA, False)
            draw_ring(tile, (ring_w * 0.42, ring_h * 0.74), span, pale, AIM_FAR_ALPHA, True)
            sheet.alpha_composite(tile, (x, y))
            pen.text((x, y + ring_h + 3), water, font=SMALL, fill=DIM)
            x += ring_w + gap
        y += ring_h + 30

    return sheet


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in VARIANTS:
        for scale in SCALES:
            art = build_cursor(name, scale)
            art.save(os.path.join(OUT_DIR, f"{name}_{scale}x.png"))
    picked = build_cursor(*PICKED)
    picked.save(ASSET)
    sheet = build_sheet()
    sheet.convert("RGB").save(SHEET)
    # The hotspot is the arrow's tip. Pad.CURSOR_TIP must agree with it, or a click lands
    # off the point of the arrow.
    tip = tip_of(*PICKED)
    print(f"wrote {ASSET} ({picked.width}x{picked.height}, {PICKED[0]} at {PICKED[1]}x, "
          f"tip {tip[0]},{tip[1]}), {SHEET} ({sheet.width}x{sheet.height}) and "
          f"{len(VARIANTS) * len(SCALES)} cursors in {OUT_DIR}")


if __name__ == "__main__":
    main()

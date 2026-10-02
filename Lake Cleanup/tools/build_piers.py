#!/usr/bin/env python
"""Build the four merchant piers as isometric pixel art, from rules rather than a painting.

Each yard is a jetty of planks on posts running out from the bank to where the ferry ties
up, with a two-tile platform on the sand behind it holding the recycle box — the island's
own crate (assets/Recycle_Box.png), empty, waiting for what the ferry lands. The wood is
the box's: the plank rhythm is the box's own five rows (a lit line, two of body, a lighter
one, a dark seam) read off its lit face for the deck and its shaded face for the beams and
posts, and the silhouette is ringed in the box's edge colour, so a pier and the crate on it
read as one carpentry.

The box is pasted at one painted pixel to one, so it draws at 2.0 in the game like every
sprite — four fifths of the island's crate, which Yard draws at 2.5. A whole art pixel,
not one and a quarter: the sheet is nearest-filtered and a fractional scale sets the
planking crawling (see the hull's HULL_DROP).

A signboard with a material icon and a heap of the yard's rubbish were drawn first
(2026-09-12) and taken off at Richard's call — "just the pier and the empty box" — but are
kept behind WITH_SIGN / WITH_HEAP in case a yard needs telling apart by more than its
place on the bank. What tells them apart now (2026-09-13, Richard's call) is two things on
the box itself: an **emblem carved into its lit face** — the actual sprite of one of the
pieces the yard buys (the globe for plastic, the wood piece for wood, the hanger for
metal, the duck for rubber), laid on the face's own slope, its colours sunk into the plank,
a groove round it and a lit edge where the cut catches the sun, so it reads as a mark of
what the box takes and not as a duck somebody left on the crate — and a **sign over the
box**: a post standing behind it carrying a plank above its top. The plank is bare on the
sheet; the yard's name is written on it by the runtime (`Dropoff`), so it can be translated
without repainting anything. A stencil of the silhouette on the jetty's planks was tried the
same day and rejected: a one-tile deck gives a mark twenty-odd screen pixels across, which is
a smudge whatever is painted in it.

Geometry is laid out on the tile plane and projected the way Iso.tile_to_world does, at
one painted pixel to two world pixels (Lake.ART_PIXEL), so the deck is a 2:1 diamond that
lies in the grid rather than a front-on picture standing on it. The four banks face four
ways, so the four yards are four drawings, not one turned.

Each yard is written as four pictures of one size sharing one anchor (2026-09-12, after
the first pass in the lake): `region` is the deck top and everything standing on it, `under`
is the posts and the edge beams below it, and `shade_wet` / `shade_dry` are the deck top's
silhouette over the water and over the sand, in white, for the runtime to draw in the day's
ink. The split lets the lake draw the posts *under* the floating rubbish (z 4) and the deck
over it (z 6), so a piece floating in front of a post is drawn over the post rather than
clipped by it, and the deck still hides what floats under it; and the silhouettes let the
deck's shadow be the deck's own shape — posts, bollards and all — rather than a slab.

Everything the runtime needs to stand a pier on the lake is written to the json beside the
sheet: where the waterline point lands in the picture (the anchor), the footprint polygons
of the two decks (for the sun's shadow: a flat slab's shadow is its footprint slid along
the lean by the deck's height), the foot of every post that stands in the water (for the
foam collars), the platform's landward edges (for the sand spill), where the box stands and where a delivered
piece should come down — the middle of the box's mouth, not its foot: the runtime climbs
from there as the box fills (Dropoff.drop_point), the way the island's crate does.

Outputs:
  assets/piers.png / .json          the sheet and its book (Dropoff reads both)
  tools/last_piers_mockup.png       the four yards over stand-in sand and water, with a
                                    stand-in noon shadow, foam and beach tufts, at 3x —
                                    the picture the design was judged on (2026-09-12)
  tools/last_sign_mockup.png        the box, its emblem and its sign per yard as baked, at
                                    3x, 1x and half, with a stand-in of the name on the
                                    plank (2026-09-13; the pick was made on it with the
                                    wrapped and relief emblems as extra rows)

Run from the project root, then reimport (`<godot> --path . --headless --import`), or a
`--path` run without the editor draws the stale `.godot/imported` texture:
  <psd-extract venv python> tools/build_piers.py [--out assets/piers] [--scale 3]
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_recycle_box  # noqa: E402  the box itself and the wood ramps

PIECES = ROOT / "assets" / "pieces.json"
BOX = ROOT / "assets" / "Recycle_Box.png"
BOAT_SHEET = ROOT / "assets" / "boat_sail_frames.png"
BOAT_JSON = ROOT / "assets" / "boat_sail_frames.json"

# --- the plane -----------------------------------------------------------------------------
## Half a tile on screen in painted pixels: Iso.TILE_W / 2 / ART_PIXEL, Iso.TILE_H / 2 / ART_PIXEL.
## At the angler's grain since 2026-10-02 (one painted px a world px, was two): twice the
## pixels at the same world size, so every count below that was painted px doubled.
HALF_W = 32.0
HALF_H = 16.0
## World px per painted px. Only used to write world-space numbers.
ART_PIXEL = 1.0
## Which wood ramp (build_recycle_box.RAMPS) the pier and its box wear.
PALETTE_NAME = "brown"

## The four yards: name, basin angle (Lake._shape_dropoffs) and tint. The jetty runs from
## the waterline towards the lake's middle, which at the four cardinal banks is along a tile
## axis, so the axis is written down rather than derived.
YARDS = [
    ("plastic", (0.0, -1.0), (107, 168, 199)),
    ("wood", (-1.0, 0.0), (168, 128, 71)),
    ("metal", (0.0, 1.0), (158, 163, 179)),
    ("rubber", (1.0, 0.0), (82, 77, 87)),
]

# --- the build ------------------------------------------------------------------------------
## Deck top height above the water, in painted px, and how thick the edge beam under it is.
## Six, so that four rows of post show under the far edges: a deck a pier is a floor you
## can see under, and at four the posts vanished into the beam.
DECK_UP = 12
BEAM = 4
## Jetty: tiles out from the waterline, and tiles across.
JETTY_OUT = 3.0
JETTY_WIDE = 1.0
## Platform on the sand: tiles landward from the waterline, and tiles across.
PLATFORM_BACK = 2.0
PLATFORM_WIDE = 2.0
## Plank width, in tiles along the deck: ten painted px along the diagonal (the old five at
## twice the grain), each board a lit row, body with grain, a darker row and the gap.
PLANK_PX = 10
PLANK = PLANK_PX / math.hypot(HALF_W, HALF_H)
## Post spacing along an edge, in tiles, and the post's width on screen.
POST_EVERY = 1.0
POST_WIDE = 6
## Bollards at the jetty's end: how far they rise above the deck.
BOLLARD_UP = 10
## The box: where it stands on the platform (local s, t).
BOX_AT = (-1.0, 0.0)
## Two rows of Recycle_Box.png (Yard.ART_TOP, Yard.ART_GROUND): the middle of the mouth's
## diamond, where a thrown piece is aimed, and the middle of the diamond the box stands on,
## the point the runtime heaps from. Measured from the picture's top, not from the bottom
## corner: the first bake took the mouth as 16 rows above the bottom corner (the wall's
## height above the *ground diamond's middle*, which the corner is 8 rows below), and
## every delivery aimed 8 rows too low, behind the near wall (2026-09-13).
BOX_TOP = build_recycle_box.ART_TOP
BOX_STAND = build_recycle_box.ART_GROUND
## How much of the deck's light is left in the first and second rows under the box's foot.
BOX_CONTACT = (0.55, 0.65, 0.8, 0.9)
## How far in front of a post's foot the deck's footprint must still reach for the post to
## count as under the pier rather than on its edge, painted px.
UNDER_PIER = 6
WITH_HEAP = False

## The emblem (2026-09-13): the yard's material carved into the box's lit (right) face.
## The actual sprite of one of the pieces the yard buys, laid on the face's parallelogram —
## its rows follow the face's slope, so it sits on the wood rather than in front of it —
## sized to fill the face inside a margin off the rim, the corner seam and the outline.
EMBLEM_PIECE = {
    "plastic": "plastic_bottle1",
    "wood": "wood_stump1",
    "metal": "metal_kettle",
    "rubber": "rubber_ball",
}
## "carved": the sprite's own colours, sunk EMBLEM_SOAK of the way towards the plank under
## them, ringed by a groove in the wood's darkest tone with a lit edge along its left and
## bottom, where a recess lit from the upper right catches the light. "relief": the same cut,
## but in the plank's own tones by the sprite's brightness — a carving, unpainted.
EMBLEM_STYLE = "carved"
EMBLEM_SOAK = 0.2
## Whether the emblem wraps round the near corner onto both front faces — twice the width,
## for pieces that are wider than they are tall. A tall piece is held by the face's height
## either way.
EMBLEM_WRAP = False
## The face, in the box's own painted px: the right face runs from column FACE_CORNER to
## the last, its top edge dropping half a row per column from FACE_TOP at the corner, and it
## stands FACE_TALL rows. Margins keep the emblem off the rim above, the outline at the far
## edge and below, and the seam down the corner.
FACE_CORNER = build_recycle_box.MID
FACE_TOP = 2 * build_recycle_box.ART_TOP - 0.5
FACE_TALL = float(build_recycle_box.WALL_TALL)
FACE_MARGIN = (5.0, 3.0, 5.0, 4.0)  # in from the corner, down from the rim, in from the far edge, up from the foot

## The sign (2026-09-13): a post carrying a bare plank. The runtime writes the yard's name
## on the plank (Dropoff.sign_text), which is what makes the name translatable; the plank's
## rectangle and the post's foot go in the json. Where it stands is decided by what is
## behind the plank on the screen:
##   * **over the box** where that is sand (the north and west banks, whose platforms lie up
##     the screen from their jetties): the post stands SIGN_BACK tiles straight behind the
##     box — up the plane along both tile axes at once, which projects to the box's own
##     column — most of it hidden by the box, and the plank hangs SIGN_GAP rows above the
##     box's top corner, centred over it;
##   * **at the platform's side corner** where that would be water (the south and east
##     banks, whose platforms lie down the screen from their jetties, so anything tall over
##     the box stands against the lake): the post stands SIGN_INSET in from the landward
##     corner on the box's level, SIGN_POST rows tall, and the plank hangs off it SIGN_HANG
##     px outward — away from the box, out over the beach. Richard's call (2026-09-13): a
##     plank across the waterline was the objection, and the sign may stand apart from the
##     box as long as it stands on the pier.
SIGN_BACK = 0.45
SIGN_BOARD = (88, 26)
SIGN_GAP = 8
SIGN_INSET = 0.12
SIGN_POST = 24
SIGN_HANG = 28
## The plank's carpentry (2026-09-13, Richard: "the sign frames should have the crevices
## like the menus"): V notches bitten out of its edges the way every drawn plank in the
## HUD has them (Style._border_bites / v_rows — widest at the edge, narrowing to a blunt
## tip), ringed by the outline pass like every other hole in the pier's silhouette; a few
## grain dashes in the plank's lighter and darker tones; and the corner pixels off. Per
## long edge and per end: how many, how deep they go, how wide they open, all painted px,
## kept SIGN_BITE_CLEAR in from the corners. A foot-edge bite is steered off the post's
## column, or the hole opens onto the post standing behind the plank.
SIGN_BITES = (3, 1)
SIGN_BITE_DEEP = (3, 2)
SIGN_BITE_WIDE = (6, 4)
SIGN_BITE_TIP = 0.2
SIGN_BITE_CLEAR = 8
SIGN_GRAIN = 14
assert SIGN_HANG < SIGN_BOARD[0] // 2 - 2, "the post has to meet the plank"
## The heap: centre (s, t) and radii (s, t) of the ellipse the pieces are scattered in.
HEAP_AT = (-1.0, -0.35)
HEAP_RADII = (0.75, 0.6)

## Which of the lake's sprites each yard heaps up. Rubber's tyres are stacked, not scattered.
HEAPS = {
    "plastic": ["plastic_cup", "plastic_cups", "plastic_bucket1", "plastic_bottle1",
                "plastic_mug1", "plastic_bag1", "plastic_bottle2", "plastic_cup",
                "plastic_sauce", "plastic_bucket2"],
    "wood": ["wood_block", "wood_scrap", "wood_tile", "wood_stick", "wood_scrap",
               "wood_splinter", "wood_peg"],
    "metal": ["metal_can1", "metal_can2", "metal_can3", "metal_soda1", "metal_soda2",
              "metal_tin1", "metal_tin2", "metal_jar", "metal_can1"],
    "rubber": ["rubber_ball", "rubber_sock", "rubber_eraser", "rubber_plug", "rubber_puck"],
}
TYRE_STACKS = [((-1.15, -0.45), 3), ((-0.75, 0.15), 2)]

# --- the mockup -----------------------------------------------------------------------------
PALETTE = {
    "sand": (232, 205, 151),
    "grass": (109, 135, 64),
    "grass_dark": (50, 87, 29),
    "water_mid": (65, 107, 146),
    "water_shallow": (127, 167, 198),
    "water_deep": (44, 77, 110),
    "foam": (238, 246, 251),
    "foam_light": (255, 255, 255),
}
SHADOW_INK = (10, 15, 23)
## Noon: day_config lean_noon -1.0, stretch_noon 0.42, ink_noon 0.34.
NOON = (-1.0, 0.42, 0.34)
## Tiles of beach between the waterline and the lawn (Ground beach_width).
BEACH = 3.5


def proj(tx, ty):
    return ((tx - ty) * HALF_W, (tx + ty) * HALF_H)


def unproj(x, y):
    a = x / HALF_W
    b = y / HALF_H
    return ((a + b) * 0.5, (b - a) * 0.5)


def luma_key(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


class Wood:
    """Tones off one of the box's wood ramps (build_recycle_box.RAMPS), darkest to lightest,
    named the way the 2x build named them, so the drawing code reads the same."""

    def __init__(self, palette=None):
        name = palette or PALETTE_NAME
        self.name = name
        r = build_recycle_box.RAMPS[name]
        self.ramp = r
        self.moss = name == "oak"
        self.edge = build_recycle_box.INK
        self.dark = r[1]
        self.mid_dark = r[2]
        self.mid = r[3]
        self.mid_light = r[4]
        self.light = r[5]
        self.pale = r[6]
        self.planks = [self.mid, self.mid_light, self.light]
        # A plank's rows, lit (a deck top, the sign) and shaded (posts and beams): a lit
        # line, two of body, a lighter row, the seam — the 2x build's five, by index.
        self.plank_lit = [r[5], r[4], r[4], mix(r[4], r[5], 0.35), r[2]]
        self.plank_shade = [r[4], r[2], r[2], r[3], r[1]]
        self.rim = r[0]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


MOSS = build_recycle_box.MOSS


class Yard:
    def __init__(self, name, axis, tint):
        self.name = name
        self.ax = axis
        self.ac = (-axis[1], axis[0])
        self.tint = tint

    def local_to_tile(self, s, t):
        return (self.ax[0] * s + self.ac[0] * t, self.ax[1] * s + self.ac[1] * t)

    def at(self, s, t, up=0.0):
        """Screen point of local (s, t) lifted `up` painted px, before the canvas offset."""
        x, y = proj(*self.local_to_tile(s, t))
        return (x, y - up)

    def local_of(self, x, y):
        tx, ty = unproj(x, y)
        # Inverse of the rotation: ax, ac are orthonormal.
        return (tx * self.ax[0] + ty * self.ax[1], tx * self.ac[0] + ty * self.ac[1])


def rect_corners(s0, s1, t0, t1):
    return [(s0, t0), (s1, t0), (s1, t1), (s0, t1)]


def visible_edges(yard, corners):
    """Edges of a local rect whose outward normal faces the camera (screen-down)."""
    out = []
    n = len(corners)
    cs = sum(c[0] for c in corners) / n
    ct = sum(c[1] for c in corners) / n
    for i in range(n):
        a, b = corners[i], corners[(i + 1) % n]
        ms, mt = (a[0] + b[0]) * 0.5 - cs, (a[1] + b[1]) * 0.5 - ct
        nx, ny = yard.local_to_tile(ms, mt)
        if nx + ny > 1e-6:
            out.append((a, b))
    return out


def load_pieces():
    book = json.loads(PIECES.read_text(encoding="utf-8"))
    sheets = {}
    for key, entry in book["sheets"].items():
        path = ROOT / entry["file"].replace("res://", "")
        if path.exists():
            sheets[key] = Image.open(path).convert("RGBA")
    sprites = {}
    for piece in book["pieces"]:
        if piece["sheet"] in sheets:
            x, y, w, h = piece["region"]
            sprites[piece["name"]] = sheets[piece["sheet"]].crop((x, y, x + w, y + h))
    return sprites


def hash01(*args):
    h = 2166136261
    for a in args:
        for ch in repr(a).encode():
            h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return (h % 10007) / 10007.0


def outline(image, colour):
    """Ring every opaque pixel that touches a clear one in `colour`."""
    px = image.load()
    w, h = image.size
    marks = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < w and 0 <= yy < h) or px[xx, yy][3] == 0:
                    marks.append((x, y))
                    break
    for x, y in marks:
        px[x, y] = colour + (255,)


def face_of(x, wrap):
    """The face a box column lies on and its top row, in the box's own painted px: (u, top)
    where u runs across the unfolded front from the corner (0 at the corner, positive on the
    lit right face, negative on the left), or None off the front faces."""
    if x >= FACE_CORNER:
        return (x - FACE_CORNER + 0.5, FACE_TOP - (x - FACE_CORNER) * 0.5)
    if wrap:
        return (x - FACE_CORNER + 0.5, FACE_TOP - (FACE_CORNER - x) * 0.5)
    return None


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def carve_emblem(image, x0, y0, crate, sprite, wood, style, wrap):
    """Carve `sprite` into the box pasted at (x0, y0): laid on the lit face's parallelogram
    (both front faces when `wrap`), sized to fill it inside FACE_MARGIN, then a groove of the
    wood's darkest tone round it and a lit edge along its left and bottom."""
    ink = sprite.getbbox()
    if ink is None:
        return
    sp = sprite.load()
    sw, sh = ink[2] - ink[0], ink[3] - ink[1]
    left, top, right, bottom = FACE_MARGIN
    u_lo = -(FACE_CORNER - right) if wrap else left
    u_hi = FACE_CORNER - right
    v_lo, v_hi = top, FACE_TALL - bottom
    k = min((u_hi - u_lo) / sw, (v_hi - v_lo) / sh)
    # Whole steps where it fits: the rubbish is drawn at this grain too, so at one step the
    # emblem is the piece's own pixels.
    if k >= 1.0:
        k = float(math.floor(k))
    eu = (u_lo + u_hi) * 0.5 - sw * k * 0.5
    ev = (v_lo + v_hi) * 0.5 - sh * k * 0.5
    cp = crate.load()
    px = image.load()
    # Which box pixels are the emblem, and what the sprite says there.
    marks = {}
    for cy in range(crate.height):
        for cx in range(crate.width):
            if cp[cx, cy][3] == 0:
                continue
            face = face_of(cx, wrap)
            if face is None:
                continue
            u, top_row = face
            v = cy + 0.5 - top_row
            if not (u_lo <= u < u_hi and v_lo <= v < v_hi):
                continue
            c = math.floor((u - eu) / k)
            r = math.floor((v - ev) / k)
            if 0 <= c < sw and 0 <= r < sh and sp[ink[0] + c, ink[1] + r][3] > 0:
                marks[(cx, cy)] = sp[ink[0] + c, ink[1] + r][:3]
    if not marks:
        return
    groove = wood.dark
    lit = wood.plank_lit[0]
    for (cx, cy), colour in marks.items():
        under = px[x0 + cx, y0 + cy][:3]
        if style == "relief":
            # The plank's own tones by the sprite's brightness: dark, body, lit line.
            bright = luma(colour) / 255.0
            tone = wood.plank_lit[4] if bright < 0.35 else (wood.plank_lit[1] if bright < 0.7 else wood.plank_lit[0])
        else:
            tone = tuple(int(round(colour[i] * (1.0 - EMBLEM_SOAK) + under[i] * EMBLEM_SOAK)) for i in range(3))
        # The groove: the emblem's own outer ring, so it costs no room on the face.
        edge = any((cx + dx, cy + dy) not in marks for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        px[x0 + cx, y0 + cy] = (groove if edge else tone) + (255,)
    # The lit edge: the plank just left of and just under the cut, where the recess's walls
    # face the sun. On the face only — never over the corner seam or the outline.
    for (cx, cy) in list(marks):
        for dx, dy in ((-1, 0), (0, 1)):
            nx, ny = cx + dx, cy + dy
            if (nx, ny) in marks or not (0 <= nx < crate.width and 0 <= ny < crate.height):
                continue
            face = face_of(nx, wrap)
            if face is None:
                continue
            u, top_row = face
            v = ny + 0.5 - top_row
            if (u_lo - 1.0 <= u < u_hi) and (v_lo <= v < v_hi + 1.0) and cp[nx, ny][3] > 0:
                px[x0 + nx, y0 + ny] = lit + (255,)


## Each yard's plank is painted in its material's colour (2026-09-26, Richard): metal grey,
## wood brown, plastic blue, rubber near-black. Weathered, not flat: the wood's own light and
## grain are kept by painting each pixel at the paint's colour times how light the wood was
## there, with `SIGN_WEATHER` of the wood left showing through. Dark enough that the runtime's
## pale lettering (`Dropoff.SIGN_INK`) clears 4.5:1 on every one; `test_lake` measures it.
SIGN_PAINT = {
    "metal": (86, 92, 100),
    "wood": (112, 66, 36),
    "plastic": (38, 82, 142),
    "rubber": (34, 32, 34),
}
SIGN_WEATHER = 0.15


def luma(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def draw_sign(sign, wood, foot, centre_x, board_bottom, seed=""):
    """The post and the bare plank, into `sign` (the yard's canvas): the plank with the
    menus' carpentry — grain, chamfered corners and V bites out of its edges, which the
    outline pass rings afterwards. `seed` (the yard's name) varies the grain and the bites,
    so the four signs are four planks. Returns the plank's rectangle [x, y, w, h]."""
    draw = ImageDraw.Draw(sign)
    fx, fy = int(round(foot[0])), int(round(foot[1]))
    bw, bh = SIGN_BOARD
    bx0 = int(round(centre_x)) - bw // 2
    by0 = board_bottom - bh
    # The post, four wide, from its foot up into the plank's middle.
    r = wood.ramp
    for i, tone in enumerate((r[1], r[2], r[3], r[4])):
        x = fx - 2 + i
        draw.line([(x, by0 + bh // 2), (x, fy)], fill=tone + (255,))
    # The plank: a lit top row, body, a dark seam row along the foot, the box's outline round.
    draw.rectangle([bx0, by0, bx0 + bw - 1, by0 + bh - 1], fill=wood.plank_lit[1] + (255,))
    # Two boards, one over the other: each a lit row under its top, body, a darker row and
    # the seam between them.
    mid = by0 + bh // 2
    for top, foot in ((by0, mid), (mid, by0 + bh)):
        draw.line([(bx0 + 1, top + 1), (bx0 + bw - 2, top + 1)], fill=wood.plank_lit[0] + (255,))
        draw.line([(bx0 + 1, foot - 2), (bx0 + bw - 2, foot - 2)], fill=wood.plank_lit[3] + (255,))
        draw.line([(bx0 + 1, foot - 1), (bx0 + bw - 2, foot - 1)], fill=wood.plank_lit[4] + (255,))
    # Nails at each end of both boards.
    for nx in (bx0 + 4, bx0 + bw - 5):
        for ny in (by0 + bh // 4, mid + bh // 4):
            draw.point((nx, ny), fill=wood.ramp[0] + (255,))
    draw.rectangle([bx0, by0, bx0 + bw - 1, by0 + bh - 1], outline=wood.edge + (255,))
    px = sign.load()
    # Grain: short dashes in the plank's lighter and darker rows, inside the lit and seam
    # rows, never reaching the ends.
    for g in range(SIGN_GRAIN):
        gx = bx0 + 3 + int(hash01(seed, "grain", g) * (bw - 12))
        gy = by0 + 3 + int(hash01(seed, "grain row", g) * (bh - 6))
        gl = 4 + int(hash01(seed, "grain length", g) * 9)
        tone = wood.plank_lit[3] if g % 2 else wood.plank_lit[4]
        for x in range(gx, min(gx + gl, bx0 + bw - 3)):
            px[x, gy] = tone + (255,)
    paint = SIGN_PAINT.get(seed)
    if paint is not None:
        base = max(luma(wood.plank_lit[1]), 1.0)
        for y in range(by0 + 1, by0 + bh - 1):
            for x in range(bx0 + 1, bx0 + bw - 1):
                r, g, b, a = px[x, y]
                light = luma((r, g, b)) / base
                out = []
                for ch, w in zip(paint, (r, g, b)):
                    v = ch * light * (1.0 - SIGN_WEATHER) + w * SIGN_WEATHER
                    out.append(max(0, min(255, int(round(v)))))
                px[x, y] = tuple(out) + (a,)

    def clear(x, y):
        if bx0 <= x < bx0 + bw and by0 <= y < by0 + bh:
            px[x, y] = (0, 0, 0, 0)

    # The chamfer: one pixel off each corner, the drawn boards' own corner.
    for cx, cy in ((bx0, by0), (bx0 + bw - 1, by0), (bx0, by0 + bh - 1), (bx0 + bw - 1, by0 + bh - 1)):
        clear(cx, cy)
    # The bites: a V of rows out of each long edge, narrowing from `wide` at the mouth to
    # SIGN_BITE_TIP of it; a shorter V of columns out of each end.
    room = bw - 2 * SIGN_BITE_CLEAR
    for edge, y_edge, inward in (("top", by0, 1), ("foot", by0 + bh - 1, -1)):
        for i in range(SIGN_BITES[0]):
            step = room / float(SIGN_BITES[0])
            at = bx0 + SIGN_BITE_CLEAR + int(step * (i + 0.2 + 0.6 * hash01(seed, edge, i)))
            wide = SIGN_BITE_WIDE[0] - int(hash01(seed, edge, i, "wide") * 2)
            if edge == "foot" and abs(at - fx) <= wide:
                at = fx + wide + 2 if at >= fx else fx - wide - 2
            for d in range(SIGN_BITE_DEEP[0]):
                share = 1.0 - (1.0 - SIGN_BITE_TIP) * d / float(max(SIGN_BITE_DEEP[0] - 1, 1))
                span = max(int(round(wide * share)), 1)
                start = int(round(at - span * 0.5))
                for x in range(start, start + span):
                    clear(x, y_edge + inward * d)
    for edge, x_edge, inward in (("left", bx0, 1), ("right", bx0 + bw - 1, -1)):
        for i in range(SIGN_BITES[1]):
            at = by0 + SIGN_BITE_CLEAR + int((bh - 2 * SIGN_BITE_CLEAR) * (0.2 + 0.6 * hash01(seed, edge, i)))
            for d in range(SIGN_BITE_DEEP[1]):
                share = 1.0 - (1.0 - SIGN_BITE_TIP) * d / float(max(SIGN_BITE_DEEP[1] - 1, 1))
                span = max(int(round(SIGN_BITE_WIDE[1] * share)), 1)
                start = int(round(at - span * 0.5))
                for y in range(start, start + span):
                    clear(x_edge + inward * d, y)
    return [bx0, by0, bw, bh]


## Where the nails go across a board: over the stringers under each long edge, in tiles in
## from the edge, and how many of them are missing.
NAIL_IN = 0.1
NAIL_GONE = 0.25


def deck_tone(wood, name, on_jetty, index, row_in, across, seam_along):
    """One pixel of deck top. A board is PLANK_PX rows along the deck: a lit row where it
    catches the sun, body with grain dashes, a darker row, and the gap between boards. The
    odd board a step darker or lighter, worn ends, nails over the stringers, a knot."""
    r = wood.ramp
    shade = hash01(name, on_jetty, index)
    body = r[4] if shade > 0.3 else r[3]
    if shade > 0.85:
        body = mix(r[4], r[5], 0.4)
    if row_in == PLANK_PX - 1:
        return r[1]
    if row_in == PLANK_PX - 2:
        return mix(body, r[2], 0.6)
    if row_in == 0:
        return mix(body, r[6], 0.45)
    half = (JETTY_WIDE if on_jetty else PLATFORM_BACK) * 0.5
    off = across if on_jetty else across + PLATFORM_BACK * 0.5
    # The board's end grain where it meets the deck's edge: a step darker, worn.
    if abs(off) > half - seam_along * 2.5:
        return mix(body, r[2], 0.45)
    # Nails over the stringers, two to a board, on the body's middle rows.
    if row_in in (3, 4) and abs(abs(off) - (half - NAIL_IN)) < seam_along * 0.8:
        if hash01(name, on_jetty, index, "nail", off > 0) > NAIL_GONE:
            return r[0] if row_in == 3 else r[2]
    # Grain: dashes along the board, a step darker, each on its own row.
    lane = int((off + half) / (seam_along * 6))
    g = hash01(name, on_jetty, index, "grain", lane)
    if g < 0.45 and row_in == 2 + int(g * 20) % 5:
        return mix(body, r[2], 0.55)
    # A knot now and then.
    if hash01(name, on_jetty, index, "knot") < 0.18:
        kn = (hash01(name, on_jetty, index, "kx") - 0.5) * half * 1.2
        if abs(off - kn) < seam_along * 1.2 and row_in in (4, 5):
            return r[2] if row_in == 4 else r[1]
    return body


def build_yard(yard, wood, sprites, emblem=EMBLEM_STYLE, wrap=EMBLEM_WRAP):
    """Draw one yard. Returns (image, book) with every point in painted px from the anchor."""
    jetty = rect_corners(0.0, JETTY_OUT, -JETTY_WIDE * 0.5, JETTY_WIDE * 0.5)
    platform = rect_corners(-PLATFORM_BACK, 0.0, -PLATFORM_WIDE * 0.5, PLATFORM_WIDE * 0.5)

    # Bounds: every corner at ground and at deck height, plus the box's and the sign's reach.
    pts = []
    for c in jetty + platform:
        pts.append(yard.at(*c))
        pts.append(yard.at(*c, up=DECK_UP + BOLLARD_UP))
    hx, hy = yard.at(*HEAP_AT, up=DECK_UP + 40)
    pts += [(hx - 40, hy), (hx + 40, hy)]
    box_tall = build_recycle_box.H
    bx, by = yard.at(*BOX_AT, up=DECK_UP + box_tall + SIGN_GAP + SIGN_BOARD[1] + 2)
    pts += [(bx - SIGN_BOARD[0] // 2 - 2, by), (bx + SIGN_BOARD[0] // 2 + 2, by)]
    for t in (-(PLATFORM_WIDE * 0.5 - SIGN_INSET), PLATFORM_WIDE * 0.5 - SIGN_INSET):
        cx, cy = yard.at(-PLATFORM_BACK + SIGN_INSET, t, up=DECK_UP + SIGN_POST + SIGN_BOARD[1] + 2)
        reach = SIGN_BOARD[0] // 2 + SIGN_HANG + 2
        pts += [(cx - reach, cy), (cx + reach, cy)]
    minx = math.floor(min(p[0] for p in pts)) - 2
    miny = math.floor(min(p[1] for p in pts)) - 2
    maxx = math.ceil(max(p[0] for p in pts)) + 2
    maxy = math.ceil(max(p[1] for p in pts)) + 2
    W, H = maxx - minx, maxy - miny
    image = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    ox, oy = -minx, -miny

    def P(s, t, up=0.0):
        x, y = yard.at(s, t, up)
        return (x + ox, y + oy)

    # Which layer each pixel belongs to (1 under: posts and beams; 2 over: the deck top and
    # what stands on it) and which deck it is (1 jetty, 2 platform; 0 for neither).
    layer = [[0] * H for _ in range(W)]
    deck = [[0] * H for _ in range(W)]

    book = {
        "anchor": [ox, oy],
        "deck_up": DECK_UP,
        "jetty": [list(P(*c)) for c in jetty],
        "platform": [list(P(*c)) for c in platform],
        "posts_wet": [],
        "posts_dry": [],
        "landward": [],
        "drop": None,
        "berth_end": list(P(JETTY_OUT, 0.0)),
    }

    # --- posts, far to near ------------------------------------------------------------
    posts = []
    for rect, wet in ((jetty, True), (platform, False)):
        s0 = min(c[0] for c in rect)
        s1 = max(c[0] for c in rect)
        t0 = min(c[1] for c in rect)
        t1 = max(c[1] for c in rect)
        inset = 0.08
        along = s1 - s0
        count = max(1, int(round(along / POST_EVERY)))
        for i in range(count + 1):
            s = s0 + inset + (along - 2 * inset) * i / count
            for t in (t0 + inset, t1 - inset):
                posts.append((s, t, wet and s > 0.05))
        # The platform's landward edge gets a middle post too, so the back is held up.
        if not wet:
            posts.append((s0 + inset, 0.0, False))
    posts.sort(key=lambda p: P(p[0], p[1])[1])
    px0 = image.load()
    for s, t, wet in posts:
        gx, gy = P(s, t)
        gx, gy = int(round(gx)), int(round(gy))
        top = gy - (DECK_UP - BEAM)
        half = POST_WIDE // 2
        r = wood.ramp
        # A round pile: dark down its left, body, lit down its right; a ring of grain every
        # few rows; weed on its foot where it stands in the water.
        cols = [r[0], r[1], r[2], r[2], r[3], r[4]]
        for i, x in enumerate(range(gx - half, gx - half + POST_WIDE)):
            for y in range(top, gy + 1):
                tone = cols[min(i, len(cols) - 1)]
                if (gy - y) % 5 == 0 and 0 < i < POST_WIDE - 1:
                    tone = mix(tone, r[0], 0.4)
                if wet and wood.moss and gy - y < 3 + int(hash01(yard.name, s, t, i) * 3):
                    tone = MOSS[min(i // 2, 2)]
                if 0 <= x < W and 0 <= y < H:
                    px0[x, y] = tone + (255,)
                    layer[x][y] = 1
        (book["posts_wet"] if wet else book["posts_dry"]).append([gx, gy])

    # --- deck tops, per pixel ----------------------------------------------------------
    px = image.load()
    seam_along = 1.0 / math.hypot(HALF_W, HALF_H)  # one painted px along a diagonal, in tiles
    for y in range(H):
        for x in range(W):
            s, t = yard.local_of(x + 0.5 - ox, y + 0.5 - oy + DECK_UP)
            on_jetty = 0.0 <= s < JETTY_OUT and abs(t) < JETTY_WIDE * 0.5
            on_platform = -PLATFORM_BACK <= s < 0.0 and abs(t) < PLATFORM_WIDE * 0.5
            if not (on_jetty or on_platform):
                continue
            # The deck top owns its pixels (2026-09-26): a far-row post drawn before it rises
            # into the deck, and left marked as under, those pixels went to the under layer —
            # holes in the deck with the pole showing through.
            layer[x][y] = 2
            # Which deck: the beam, the two shadow masks and the box's contact rows all read
            # this, and nothing wrote it (found 2026-09-26), so all four came out empty.
            deck[x][y] = 1 if on_jetty else 2
            # Jetty planks run across the walkway; platform planks run along the shore.
            along = s if on_jetty else t
            across = t if on_jetty else s
            index = math.floor(along / PLANK)
            frac = along - index * PLANK
            row_in = min(PLANK_PX - 1, int(frac / seam_along))
            px[x, y] = deck_tone(wood, yard.name, on_jetty, index, row_in, across, seam_along) + (255,)
    # --- the edge beam, per pixel: the rows under the deck top's lower boundary --------
    # The camera-facing edges of a slab on the plane are exactly where the deck-top region
    # ends going down the screen, so the beam is BEAM rows painted under each such pixel.
    # Painted this way rather than as polygons because an aliased polygon edge and the
    # per-pixel top left a one-pixel gap of daylight along every near edge.
    # Keyed to the deck mask, **not to the pixel's colour** (2026-09-12): the post's body is
    # painted in the same tone as the beam, so a colour test called every post a deck top and
    # hung two more rows of "beam" under each one. Every pole was two rows longer than the
    # foot the json recorded, and the sand banked on that foot sat in the middle of the pole
    # with its bottom showing below.
    is_top = [[deck[x][y] != 0 for y in range(H)] for x in range(W)]
    for x in range(W):
        for y in range(H - 1):
            if is_top[x][y] and not is_top[x][y + 1]:
                for k in range(1, BEAM + 1):
                    if y + k < H and not is_top[x][y + k]:
                        tone = (wood.ramp[1] if k == BEAM else
                                (wood.ramp[3] if k == 1 else wood.ramp[2]))
                        px[x, y + k] = tone + (255,)
                        layer[x][y + k] = 1

    # --- bollards at the jetty's end ---------------------------------------------------
    for t in (-JETTY_WIDE * 0.5 + 0.12, JETTY_WIDE * 0.5 - 0.12):
        bx, by = P(JETTY_OUT - 0.12, t, up=DECK_UP)
        bx, by = int(round(bx)), int(round(by))
        tones = [wood.ramp[1], wood.ramp[2], wood.ramp[3], wood.ramp[5]]
        for i, x in enumerate(range(bx - 2, bx + 2)):
            draw.line([(x, by - BOLLARD_UP), (x, by)], fill=tones[i] + (255,))
        # Its cut top, lit, and a band of rope round it.
        draw.line([(bx - 2, by - BOLLARD_UP - 1), (bx + 1, by - BOLLARD_UP - 1)],
                  fill=wood.pale + (255,))
        rope = [(108, 96, 70), (150, 136, 98), (190, 176, 130), (150, 136, 98)]
        for k, x in enumerate(range(bx - 2, bx + 2)):
            for y in (by - 5, by - 4):
                image.putpixel((x, y), rope[(k + y) % 4] + (255,))
        for x in range(bx - 2, bx + 2):
            for y in range(by - BOLLARD_UP - 1, by + 1):
                if 0 <= x < W and 0 <= y < H:
                    layer[x][y] = 2
                    deck[x][y] = 1

    # --- the sign's post, then the box over it, then its plank ---------------------------
    # The post stands straight behind the box on the screen: back along both tile axes at
    # once, which projects to the same column. Drawn into its own canvas and composited
    # under the box, so the box hides all of it but what rises past the top corner.
    sign = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bt = yard.local_to_tile(*BOX_AT)
    hx, hy = P(*BOX_AT, up=DECK_UP)
    crate = build_recycle_box.build_box(wood.name)
    crate_tall = crate.getbbox()[3] if crate is not None else 36
    # The box's own stand (the middle of the diamond its walls stand on, row BOX_STAND of the
    # art) on the platform's middle (2026-09-26). It used to stand the art's *bottom row* —
    # the near corner of that diamond — on the middle, which put the box half a tile up the
    # screen, in the platform's back corner.
    box_top = int(round(hy - BOX_STAND))
    # Where the box stands and where its mouth is, both rows of the picture as pasted.
    # The hole, not the foot (2026-09-13): a piece is thrown into the mouth of the box. It
    # used to be the ground point, and every delivery came down on the box's bottom edge.
    book["box_ground"] = [int(round(hx)), box_top + BOX_STAND]
    book["drop"] = [int(round(hx)), box_top + BOX_TOP]
    # Where the plank over the box would hang: the ground straight up the screen from the
    # box by the plank's height is the ground `d` tiles back along both axes. Sand, and the
    # sign stands behind the box; water, and it stands at the platform's side corner.
    over_h = crate_tall + SIGN_GAP + SIGN_BOARD[1] * 0.5
    d = over_h / (HALF_H * 2.0)
    behind_s = yard.local_of(*proj(bt[0] - d, bt[1] - d))[0]
    if behind_s < -0.05:
        st = yard.local_of(*proj(bt[0] - SIGN_BACK, bt[1] - SIGN_BACK))
        foot = P(st[0], st[1], up=DECK_UP)
        book["sign_foot"] = [int(round(foot[0])), int(round(foot[1]))]
        book["sign"] = draw_sign(sign, wood, foot, hx, box_top - SIGN_GAP, yard.name)
        book["sign_stands"] = "over the box"
    else:
        # The side corner: of the two landward corners, the one on the box's own row of
        # the screen; the other is in front of the box and a sign there would stand in
        # front of it.
        corners = [
            P(-PLATFORM_BACK + SIGN_INSET, t, up=DECK_UP)
            for t in (-(PLATFORM_WIDE * 0.5 - SIGN_INSET), PLATFORM_WIDE * 0.5 - SIGN_INSET)
        ]
        foot = min(corners, key=lambda c: abs(c[1] - hy))
        outward = 1.0 if foot[0] > hx else -1.0
        book["sign_foot"] = [int(round(foot[0])), int(round(foot[1]))]
        book["sign"] = draw_sign(
            sign, wood, foot, foot[0] + outward * SIGN_HANG, int(round(foot[1] - SIGN_POST)),
            yard.name
        )
        book["sign_stands"] = "at the side corner"
    image.alpha_composite(sign)
    sp = sign.load()
    for y in range(H):
        for x in range(W):
            if sp[x, y][3]:
                layer[x][y] = 2
                deck[x][y] = 0
    if crate is not None:
        ink = crate.getbbox()
        fx, fy = hx, hy
        x0 = int(round(fx - (ink[0] + ink[2]) * 0.5))
        y0 = box_top
        image.alpha_composite(crate, (x0, y0))
        # Where the box meets the deck: the two rows of planks under its lowest pixel in
        # each column, taken down, so it sits on the wood rather than being laid over it.
        ip = image.load()
        cp0 = crate.load()
        for cx in range(crate.width):
            low = -1
            for cy in range(crate.height - 1, -1, -1):
                if cp0[cx, cy][3] > 0:
                    low = cy
                    break
            if low < 0:
                continue
            for d, keep in enumerate(BOX_CONTACT, 1):
                x, y = x0 + cx, y0 + low + d
                if 0 <= x < W and 0 <= y < H and ip[x, y][3] and deck[x][y] == 2:
                    r, g, b, a = ip[x, y]
                    ip[x, y] = (int(r * keep), int(g * keep), int(b * keep), a)
        book["box"] = [x0, y0, crate.width, crate.height]
        cp = crate.load()
        for cy in range(crate.height):
            for cx in range(crate.width):
                if cp[cx, cy][3] > 0 and 0 <= x0 + cx < W and 0 <= y0 + cy < H:
                    layer[x0 + cx][y0 + cy] = 2
                    deck[x0 + cx][y0 + cy] = 0
                    # The runtime's copy of the sign is what the box leaves showing.
                    sp[x0 + cx, y0 + cy] = (0, 0, 0, 0)
        piece = sprites.get(EMBLEM_PIECE.get(yard.name, ""))
        if piece is not None and emblem is not None:
            carve_emblem(image, x0, y0, crate, piece, wood, emblem, wrap)
    book["sign_layer"] = sign
    if yard.name in SIGN_PAINT:
        book["sign_paint"] = list(SIGN_PAINT[yard.name])

    if WITH_HEAP:
        # --- the heap (off by default) ----------------------------------------------------------------------
        rng = random.Random(yard.name)
        stands = []
        names = HEAPS[yard.name]
        for i, name in enumerate(names):
            sprite = sprites.get(name)
            if sprite is None:
                continue
            # Scatter inside the ellipse, densest at the middle; sorted by screen depth below.
            for _ in range(40):
                a = rng.uniform(0, math.tau)
                r = math.sqrt(rng.uniform(0.0, 1.0))
                s = HEAP_AT[0] + math.cos(a) * r * HEAP_RADII[0]
                t = HEAP_AT[1] + math.sin(a) * r * HEAP_RADII[1]
                if -PLATFORM_BACK + 0.12 < s < -0.12 and abs(t) < PLATFORM_WIDE * 0.5 - 0.12:
                    break
            stands.append((s, t, sprite))
        if yard.name == "rubber":
            tyre = sprites.get("rubber_tire")
            if tyre is not None:
                for (s, t), count in TYRE_STACKS:
                    for k in range(count):
                        stands.append((s, t - 0.0001 * k, tyre, k * 4))
        stands.sort(key=lambda st: P(st[0], st[1])[1])
        for stand in stands:
            s, t, sprite = stand[0], stand[1], stand[2]
            lift = stand[3] if len(stand) > 3 else 0
            fx, fy = P(s, t, up=DECK_UP + lift)
            x0 = int(round(fx - sprite.width * 0.5))
            y0 = int(round(fy - sprite.height))
            image.alpha_composite(sprite, (x0, y0))

    # The platform's landward edges: the three sides not on the water.
    s0 = -PLATFORM_BACK
    hw = PLATFORM_WIDE * 0.5
    book["landward"] = [list(P(0.0, -hw)), list(P(s0, -hw)), list(P(s0, hw)), list(P(0.0, hw))]

    outline(image, wood.edge)
    # Anything painted that no layer claimed (the sign, the heap, when they are on) is over.
    src = image.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3] and layer[x][y] == 0:
                layer[x][y] = 2
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    under = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dry = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    po, pu, pw, pd = over.load(), under.load(), wet.load(), dry.load()
    for y in range(H):
        for x in range(W):
            if not src[x, y][3]:
                continue
            (po if layer[x][y] == 2 else pu)[x, y] = src[x, y]
            if deck[x][y] == 1:
                pw[x, y] = (255, 255, 255, 255)
            elif deck[x][y] == 2:
                pd[x, y] = (255, 255, 255, 255)
    # Each post as [middle column, bottom row, width], all in painted px.
    #
    # **Only the posts whose wood the deck leaves showing.** A deck one tile wide carries a
    # row of posts down each side, and the far row is drawn under a deck that covers it
    # completely — so dressing every post the geometry placed hung sand and foam on nothing,
    # a tile up the beach from the pole they were supposed to belong to. That is the strays
    # going up the bank. A post is kept when its foot pixel survives into the under layer.
    #
    # The bottom is the row the line was drawn to and is **not** re-measured: walking down
    # from it to find "the real bottom" walks into the edge beam, which is painted under the
    # deck in the same layer and reaches lower at the near edges. `draw.line` includes its
    # endpoint, so the drawn row is the bottom.
    for key in ("posts_wet", "posts_dry"):
        kept = []
        for gx, gy in book[key]:
            if not (0 <= gx < W and 0 <= gy < H) or pu[gx, gy][3] == 0:
                continue
            # And not under the deck top or the box (2026-09-26): the under layer is its own
            # picture, so a foot the deck covers still survives into it, and its sand and
            # foam showed on the planks.
            if po[gx, gy][3] != 0:
                continue
            # Nor under the pier (2026-09-26, Richard: sand and foam "seen through under the
            # pier"): a far-row post's foot shows in the gap under the deck, and dressing it
            # hung sand and foam in the pier's shadow. The deck's footprint is its top lowered
            # by DECK_UP; a foot with footprint still in front of it (`UNDER_PIER` rows down)
            # stands under the pier, and only the near edge's posts are dressed.
            fs, ft = yard.local_of(gx + 0.5 - ox, gy + UNDER_PIER - oy)
            if (0.0 <= fs < JETTY_OUT and abs(ft) < JETTY_WIDE * 0.5) or (
                -PLATFORM_BACK <= fs < 0.0 and abs(ft) < PLATFORM_WIDE * 0.5
            ):
                continue
            left = right = gx
            while left - 1 >= 0 and pu[left - 1, gy][3]:
                left -= 1
            while right + 1 < W and pu[right + 1, gy][3]:
                right += 1
            # Clamped to the post's own width: at a deck's corner the run along the bottom
            # row runs into the neighbouring post's wood and into the beam's.
            left = max(left, gx - POST_WIDE // 2)
            right = min(right, gx - POST_WIDE // 2 + POST_WIDE - 1)
            kept.append([(left + right) // 2, gy, right - left + 1])
        book[key] = kept

    book["layers"] = {"under": under, "shade_wet": wet, "shade_dry": dry, "sign": book.pop("sign_layer")}
    return over, book


def stand_in_shadow(yard, image, book, lean, stretch, ink):
    """A noon shadow for the mockup: the decks' footprints slid along the lean by their
    height, and the upright things laid down from their feet the way Shade.lying does."""
    W, H = image.size
    shade = Image.new("L", (W * 3, H * 3), 0)
    draw = ImageDraw.Draw(shade)
    off = (W, H)
    dx, dy = -lean * DECK_UP, stretch * 0.5 * DECK_UP
    for key in ("jetty", "platform"):
        poly = [(p[0] + off[0] + dx, p[1] + off[1] + dy) for p in book[key]]
        draw.polygon(poly, fill=255)
    # Uprights: every opaque pixel above the deck plane, laid down from its own foot. Cheap
    # stand-in: the picture's alpha above the deck top, sheared from the anchor row.
    px = image.load()

    def on_deck(x, y):
        s, t = yard.local_of(x + 0.5 - book["anchor"][0], y + 0.5 - book["anchor"][1] + DECK_UP)
        return (0.0 <= s < JETTY_OUT and abs(t) < JETTY_WIDE * 0.5) or (
            -PLATFORM_BACK <= s < 0.0 and abs(t) < PLATFORM_WIDE * 0.5)

    sign = book["layers"]["sign"].load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0 or on_deck(x, y) or sign[x, y][3]:
                continue
            # Only things standing on the deck: their foot is the first deck row below them.
            yy = y
            while yy < H and px[x, yy][3] != 0 and not on_deck(x, yy):
                yy += 1
            if yy >= H or px[x, yy][3] == 0:
                continue
            h = yy - y
            sx = x + off[0] - lean * (h + DECK_UP)
            sy = yy + off[1] - DECK_UP + stretch * 0.5 * (h + DECK_UP)
            if 0 <= sx < shade.width and 0 <= sy < shade.height:
                shade.putpixel((int(sx), int(sy)), 255)
    # The sign is a billboard on a post: it lies down from the post's foot, sheared, the way
    # Shade.lying lays the angler down — every pixel over by its height, not swept.
    fx, fy = book["sign_foot"]
    for y in range(H):
        for x in range(W):
            if sign[x, y][3] == 0:
                continue
            h = fy - y
            sx = x + off[0] - lean * h
            sy = fy + off[1] + stretch * 0.5 * h
            if 0 <= sx < shade.width and 0 <= sy < shade.height:
                shade.putpixel((int(sx), int(sy)), 255)
    return shade, off, int(ink * 255)


def load_boat():
    """The ferry's side view for the mockups, and where its anchor is. (None, None) without
    the sheet."""
    if not (BOAT_SHEET.exists() and BOAT_JSON.exists()):
        return None, None
    sheet = Image.open(BOAT_SHEET).convert("RGBA")
    book = json.loads(BOAT_JSON.read_text(encoding="utf-8"))
    frame = book["frame"]
    idx = 4
    boat = sheet.crop((idx * frame, 0, (idx + 1) * frame, frame))
    cut = book.get("cut")
    if cut and len(cut) > idx:
        cy = cut[idx][0][1]
        bp = boat.load()
        for y in range(cy + 1, frame):
            for x in range(frame):
                bp[x, y] = (0, 0, 0, 0)
    # The ferry draws at two world px a painted px; the pier at one.
    grow = int(round(2.0 / ART_PIXEL))
    anchor = book.get("anchor", [frame // 2, frame // 2])
    boat = boat.resize((frame * grow, frame * grow), Image.NEAREST)
    return boat, [anchor[0] * grow, anchor[1] * grow]


def render_panel(yard, image, book, boat, boat_anchor, tile_s=8.5, tile_t=6.0):
    """One yard over stand-in sand and water with a noon shadow, foam and tufts. Returns
    the panel and the painted-px point its top-left corner stands at, so a yard point can
    be found on it."""
    pts = [yard.at(s, t) for s in (-tile_s * 0.55, tile_s * 0.45) for t in (-tile_t * 0.5, tile_t * 0.5)]
    minx = math.floor(min(p[0] for p in pts))
    miny = math.floor(min(p[1] for p in pts)) - 80
    maxx = math.ceil(max(p[0] for p in pts))
    maxy = math.ceil(max(p[1] for p in pts))
    W, H = maxx - minx, maxy - miny
    panel = Image.new("RGBA", (W, H), PALETTE["water_deep"] + (255,))
    px = panel.load()
    rng = random.Random(yard.name + "ground")
    for y in range(H):
        for x in range(W):
            s, t = yard.local_of(x + 0.5 + minx, y + 0.5 + miny)
            wob = 0.12 * math.sin(t * 2.1 + 0.7) + 0.06 * math.sin(t * 5.3)
            edge = wob
            if s < edge - BEACH:
                tone = PALETTE["grass"]
                if hash01("g", x, y) < 0.08:
                    tone = PALETTE["grass_dark"]
            elif s < edge:
                tone = PALETTE["sand"]
            elif s < edge + 0.08:
                tone = PALETTE["foam"]
            elif s < edge + 0.16 and hash01("f", x // 2, y) < 0.5:
                tone = PALETTE["foam"]
            else:
                band = math.sin((x - 2 * y) * 0.09 + s * 1.7)
                tone = PALETTE["water_shallow"] if (s < edge + 0.9 and band > 0.6) else (
                    PALETTE["water_mid"] if band > -0.3 or s < edge + 1.5 else PALETTE["water_deep"])
            px[x, y] = tone + (255,)
    # Beach tufts along the platform's landward edges.
    for i in range(14):
        a = rng.uniform(0, 1)
        s = -PLATFORM_BACK - rng.uniform(0.05, 0.35)
        t = (a - 0.5) * (PLATFORM_WIDE + 0.6)
        gx, gy = yard.at(s, t)
        gx, gy = int(round(gx - minx)), int(round(gy - miny))
        for k in range(rng.randint(2, 3)):
            tone = PALETTE["grass"] if k else PALETTE["grass_dark"]
            if 0 <= gx + k - 1 < W and 0 <= gy - k < H:
                px[gx + k - 1, gy - rng.randint(1, 3)] = tone + (255,)
    # Shadow.
    shade, off, alpha = stand_in_shadow(yard, image, book, *NOON)
    ax, ay = book["anchor"]
    place = (-minx - ax, -miny - ay)
    ink = Image.new("RGBA", shade.size, SHADOW_INK + (alpha,))
    ink.putalpha(shade.point(lambda v: alpha if v else 0))
    panel.alpha_composite(ink, (place[0] - off[0], place[1] - off[1]))
    # Foam collars at the wet posts.
    for gx, gy, _pw in book["posts_wet"]:
        cx, cy = gx + place[0], gy + place[1]
        for dx in range(-6, 7):
            yy = cy + (1 if abs(dx) < 4 else 0)
            tone = PALETTE["foam_light"] if abs(dx) < 4 else PALETTE["foam"]
            if 0 <= cx + dx < W and 0 <= yy < H:
                px[cx + dx, yy] = tone + (255,)
    # The ferry alongside the jetty's end, for scale only (one side view, not the
    # heading it would really lie at).
    boat_first = True
    if boat is not None:
        bx, by = yard.at(JETTY_OUT - 0.4, JETTY_WIDE * 0.5 + 0.95)
        boat_at = (int(round(bx - minx - boat_anchor[0])), int(round(by - miny - boat_anchor[1])))
        # Painter's order: whichever stands lower on screen is nearer and goes on top.
        boat_first = by - miny < place[1] + book["berth_end"][1]
        if boat_first:
            panel.alpha_composite(boat, boat_at)
    panel.alpha_composite(book["layers"]["under"], place)
    panel.alpha_composite(image, place)
    if boat is not None and not boat_first:
        panel.alpha_composite(boat, boat_at)
    return panel, (minx, miny)


def mockup(yards, wood, sprites, scale, out):
    panels = []
    boat, boat_anchor = load_boat()
    for yard, (image, book) in yards:
        panel, _origin = render_panel(yard, image, book, boat, boat_anchor)
        panels.append((yard.name, panel))

    pw = max(p.width for _, p in panels)
    ph = max(p.height for _, p in panels)
    gap = 4
    sheet = Image.new("RGBA", ((pw + gap) * 2 * scale, (ph + gap + 6) * 2 * scale), (24, 24, 28, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, panel) in enumerate(panels):
        big = panel.resize((panel.width * scale, panel.height * scale), Image.NEAREST)
        cx = (i % 2) * (pw + gap) * scale
        cy = (i // 2) * (ph + gap + 6) * scale
        sheet.alpha_composite(big, (cx, cy))
        draw.text((cx + 4, cy + panel.height * scale + 2), name + "  (1x grain, noon, ferry side view at 2x for scale)", fill=(230, 230, 230, 255))
    sheet.save(out)


def sign_mockup(wood, sprites, scale, out):
    """The box and its sign per yard as baked, at `scale` for looking at, at 1x (a little
    under play zoom, 1.24 painted px to the screen px) and at half, nearest, about the
    whole-lake zoom. The name on the plank is a stand-in in the game's own face; the runtime
    writes the real one. The pick was made on this picture with three emblem rows (carved
    on the lit face, wrapped round the corner, unpainted relief), 2026-09-13; `variants`
    takes any list of (EMBLEM_STYLE, EMBLEM_WRAP) to see the others again."""
    variants = [(EMBLEM_STYLE, EMBLEM_WRAP)]
    half = (152, 120, 152, 44)  # left, up, right, down from the box's ground point, painted px
    cw, ch = half[0] + half[2], half[1] + half[3]
    font_path = ROOT / "assets" / "Bungee-Regular.ttf"
    try:
        from PIL import ImageFont
        big_font = ImageFont.truetype(str(font_path), int(SIGN_BOARD[1] * 0.72 * scale))
        one_font = ImageFont.truetype(str(font_path), int(SIGN_BOARD[1] * 0.72))
    except Exception:
        big_font = one_font = None
    rows = []
    for style, wrap in variants:
        row = []
        for name, axis, tint in YARDS:
            yard = Yard(name, axis, tint)
            image, book = build_yard(yard, wood, sprites, emblem=style, wrap=wrap)
            panel, origin = render_panel(yard, image, book, None, None)
            gx, gy = book["box_ground"]
            ax, ay = book["anchor"]
            cx, cy = int(round(yard.at(0.0, 0.0)[0] - origin[0] + gx - ax)), int(round(yard.at(0.0, 0.0)[1] - origin[1] + gy - ay))
            crop = panel.crop((cx - half[0], cy - half[1], cx + half[2], cy + half[3]))
            sx, sy, sw, sh = book["sign"]
            board = (sx - ax + gx - gx - (cx - half[0]) + (yard.at(0.0, 0.0)[0] - origin[0]), 0)
            # The plank in crop px: the sign rect is in the yard's own canvas, the crop's
            # origin is the box's ground point less `half`.
            bx = sx - ax + int(round(yard.at(0.0, 0.0)[0] - origin[0])) - (cx - half[0])
            by = sy - ay + int(round(yard.at(0.0, 0.0)[1] - origin[1])) - (cy - half[1])
            row.append((crop, (bx, by, sw, sh), name))
        rows.append(("%s%s" % (style, ", wrapped" if wrap else ""), row))
    gap = 6
    label = 12
    cell_w = cw * scale + gap
    cell_h = ch * scale + gap + ch + gap + label
    sheet = Image.new(
        "RGBA", (cell_w * len(YARDS) + gap, (cell_h + gap) * len(variants) + gap), (24, 24, 28, 255)
    )
    draw = ImageDraw.Draw(sheet)

    def lettered(crop, board, name, s, font):
        big = crop.resize((crop.width * s, crop.height * s), Image.NEAREST)
        if font is None:
            return big
        d = ImageDraw.Draw(big)
        bx, by, bw, bh = board
        text = name.upper()
        box = d.textbbox((0, 0), text, font=font)
        tw, th = box[2] - box[0], box[3] - box[1]
        tx = (bx + bw * 0.5) * s - tw * 0.5 - box[0]
        ty = (by + bh * 0.5) * s - th * 0.5 - box[1]
        d.text((tx + s * 0.4, ty + s * 0.4), text, font=font, fill=(0, 0, 0, 140))
        d.text((tx, ty), text, font=font, fill=(247, 240, 219, 255))
        return big

    for i, (title, row) in enumerate(rows):
        for j, (crop, board, name) in enumerate(row):
            x = gap + j * cell_w
            y = gap + i * (cell_h + gap)
            sheet.alpha_composite(lettered(crop, board, name, scale, big_font), (x, y))
            y2 = y + ch * scale + gap
            one = lettered(crop, board, name, 1, one_font)
            sheet.alpha_composite(one, (x, y2))
            sheet.alpha_composite(one.resize((cw // 2, ch // 2), Image.NEAREST), (x + cw + gap, y2))
            draw.text((x + 2, y2 + ch + 1), "%s / %s  (%dx, 1x, half)" % (name, title, scale),
                      fill=(230, 230, 230, 255))
    sheet.save(out)


def palette_mockup(sprites, scale, out, yard_name="wood"):
    """The pick sheet (2026-10-02): one yard built in each wood ramp, with the hut and the
    angler beside it at the same grain, at `scale` and at 1x."""
    hut = Image.open(ROOT / "assets" / "shed_tidied.png").convert("RGBA")
    char = None
    cj = ROOT / "assets" / "character.json"
    if cj.exists():
        book = json.loads(cj.read_text(encoding="utf-8"))
        sheet = Image.open(ROOT / "assets" / "character.png").convert("RGBA")
        pose = (book.get("poses") or {}).get("idle_south")
        if pose:
            r = pose[0]["region"]
            char = sheet.crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))
    boat, boat_anchor = load_boat()
    panels = []
    for palette in build_recycle_box.RAMPS:
        wood = Wood(palette)
        axis, tint = next((a, t) for n, a, t in YARDS if n == yard_name)
        yard = Yard(yard_name, axis, tint)
        image, book = build_yard(yard, wood, sprites)
        panel, _ = render_panel(yard, image, book, boat, boat_anchor, tile_s=7.0, tile_t=4.6)
        panels.append((palette, panel))
    pw = max(p.width for _, p in panels)
    ph = max(p.height for _, p in panels)
    side = hut.width + 40
    W = (pw + side) * scale
    sheet = Image.new("RGBA", (W, (ph + 16) * scale * len(panels)), (24, 24, 28, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (palette, panel) in enumerate(panels):
        y = i * (ph + 16) * scale
        canvas = Image.new("RGBA", (pw + side, ph), PALETTE["grass"] + (255,))
        canvas.alpha_composite(panel, (0, 0))
        canvas.alpha_composite(hut, (pw + 10, ph - hut.height - 10))
        if char is not None:
            canvas.alpha_composite(char, (pw + 10 + hut.width - char.width, ph - char.height - 4))
        sheet.alpha_composite(canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST), (0, y))
        draw.text((6, y + ph * scale + 2), "%s  (%dx; hut and angler at the same grain)" % (palette, scale), fill=(230, 230, 230, 255))
    sheet.save(out)


def main():
    args = sys.argv[1:]
    out_base = ROOT / "assets" / "piers"
    scale = 3
    if "--out" in args:
        out_base = ROOT / args[args.index("--out") + 1]
    if "--scale" in args:
        scale = int(args[args.index("--scale") + 1])
    if "--palettes" in args:
        palette_mockup(load_pieces(), scale, ROOT / "tools" / "last_pier_palettes.png")
        print("wrote tools/last_pier_palettes.png")
        return
    if "--palette" in args:
        global PALETTE_NAME
        PALETTE_NAME = args[args.index("--palette") + 1]
    wood = Wood()
    sprites = load_pieces()
    built = []
    for name, axis, tint in YARDS:
        yard = Yard(name, axis, tint)
        built.append((yard, build_yard(yard, wood, sprites)))

    mockup(built, wood, sprites, scale, ROOT / "tools" / "last_piers_mockup.png")
    sign_mockup(wood, sprites, scale, ROOT / "tools" / "last_sign_mockup.png")

    # Pack the four side by side, each yard's four pictures in a run.
    gap = 2
    width = sum(img.width * 5 for _, (img, _) in built) + gap * (len(built) * 5 - 1)
    height = max(img.height for _, (img, _) in built)
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    book = {"sheet": "res://" + str(Path(out_base).with_suffix(".png").relative_to(ROOT)).replace("\\", "/"),
            "art_pixel": ART_PIXEL,
            "note": "painted px; multiply by art_pixel for world px. region = the deck top and what "
                    "stands on it; under = posts and beams (drawn below the floating rubbish); "
                    "shade_wet/shade_dry = the deck top's silhouette over water / over sand, white. "
                    "All four share the anchor. anchor = the drawn waterline "
                    "point on the jetty's centreline; jetty/platform = deck-top outlines at deck_up "
                    "above the plane; posts_wet = feet of posts standing in the water; landward = the "
                    "platform's three edges on the sand; box = the box's rectangle in the region, "
                    "box_ground = the middle of the diamond it stands on, drop = the middle of its mouth, where a "
                    "delivered piece is aimed (the runtime climbs from there as the box fills); "
                    "sign = the bare plank's rectangle, for the name the runtime writes on it; "
                    "sign_foot = the sign post's foot; sign (layer) = the post and plank alone, "
                    "what the box leaves showing, for the sign's shadow; berth_end = the middle "
                    "of the jetty's end.",
            "pieces": {}}
    x = 0
    for yard, (img, entry) in built:
        layers = entry.pop("layers")
        sheet.alpha_composite(img, (x, 0))
        entry["region"] = [x, 0, img.width, img.height]
        x += img.width + gap
        for key in ("under", "shade_wet", "shade_dry", "sign"):
            sheet.alpha_composite(layers[key], (x, 0))
            entry["sign_cut" if key == "sign" else key] = [x, 0, img.width, img.height]
            x += img.width + gap
        book["pieces"][yard.name] = entry
    Path(out_base).with_suffix(".png").parent.mkdir(parents=True, exist_ok=True)
    sheet.save(Path(out_base).with_suffix(".png"))
    Path(out_base).with_suffix(".json").write_text(json.dumps(book, indent="\t"), encoding="utf-8")

    print("wrote", Path(out_base).with_suffix(".png"), sheet.size)


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""The hive look's shared module: palette, the cute bee, plates, and the sheet helpers.

OFFLINE MOCKUPS ONLY (2026-10-16, the hive's visual overhaul, Richard's brief). Nothing here is
read by the game. Every sheet under tools/hive_look/ imports this, so the bee, its colours and
the grains are one thing across them.

Run anything that imports it from the project root with the base python and the psd-extract
venv's packages (Windows App Control blocks the venv's own python.exe):

    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/<sheet>_mockup.py

and import it with  sys.path.insert(0, "tools/hive_look"); import look

**Everything is one pixel per art pixel.** Every sprite function returns a PIL RGBA image at 1x.
Put it on a plate with `place(plate, im, at, grain)`, which blows it up by the plate's measured
grain (nearest) and snaps it to the plate's own lattice. The grains, measured off today's
captures (run lengths of flat colour, and where colour edges fall):

    ROOM_GRAIN   = 3  the 1920x1080 room plates (HiveArt.PIXEL 2 canvas px x window stretch 1.5).
                      Lattice at multiples of 3 from (0, 0); the room is a 640 x 360 art grid.
    ISLAND_GRAIN = 2  the 720x480 island crops (one window px per world px, blown up 2x by
                      tools/shot_hive.gd). Lattice at even px from (0, 0). One art px of the hive,
                      the angler and the pack flowers is one world px.
    LAKE_GRAIN   = 2  the 1920x1080 lake views mid-moment (last_hive_moment/honey, the camera at
                      the 1.33 stop): two screen px a world px. The HUD-on store stills
                      (store_v2) are at the play stop, 1.5 px a world px, uneven: no lattice.

**Colours are the game's own.** `PAL` is resources/palette.tres (through build_hive's reader).
`SW` names every other swatch used here with where it already lives in the game: the coin's ramp
(assets/coin.png), the finds' gold (NetShape.GOLD_*), the hive's honey (build_hive HONEY_*),
today's bee stripe and the bark (build_hive), the island hive's roof paint, the palette's foam
and clean water. Nothing in the bees is invented here; `SW` is the list to pick from.

**The bee is authored, not ruled**: at 9x7 a rule cannot place an eye and its glint, so each
variant is a handful of hand-set grids (body, wings in four states, legs, feelers) composited
per frame. Everything faces right; `facing_left` mirrors.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)

# build_hive reads resources/palette.tres relative to the project root at import.
_cwd = os.getcwd()
os.chdir(ROOT)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
import build_hive as bh  # noqa: E402
os.chdir(_cwd)

# =============================================================================================
# Grains and plates
# =============================================================================================
ROOM_GRAIN = 3
ROOM_ORIGIN = (0, 0)
ISLAND_GRAIN = 2
ISLAND_ORIGIN = (0, 0)
LAKE_GRAIN = 2
LAKE_ORIGIN = (0, 0)
ROOM_GRID = (640, 360)

GRAINS = {
    "room": (ROOM_GRAIN, ROOM_ORIGIN),
    "island": (ISLAND_GRAIN, ISLAND_ORIGIN),
    "lake": (LAKE_GRAIN, LAKE_ORIGIN),
}

PLATES = {
    # the room, 1920x1080, ROOM_GRAIN
    "catch": "tools/last_hive_room_catch.png",
    "smoke": "tools/last_hive_room_smoke.png",
    "queen": "tools/last_hive_room_queen.png",
    "settled": "tools/last_hive_room_settled.png",
    "uncap": "tools/last_hive_room_uncap.png",
    "pour": "tools/last_hive_room_pour.png",
    "done": "tools/last_hive_room_done.png",
    # the island, 720x480, ISLAND_GRAIN
    "empty": "tools/last_hive_empty.png",
    "swarm": "tools/last_hive_swarm.png",
    "ready": "tools/last_hive_ready.png",
    "busy": "tools/last_hive_busy.png",
    # the lake, 1920x1080, LAKE_GRAIN
    "moment": "tools/last_hive_moment.png",
    "honey": "tools/last_hive_honey.png",
    # HUD-on store stills (play stop, uneven grain)
    "big_cast": "../Marketing/My Dirty Little Lake/1 Final/Steam Store/Screenshots and Clips/02_big_cast.png",
    "gold_double": "../Marketing/My Dirty Little Lake/1 Final/Steam Store/Screenshots and Clips/05_gold_double.png",
    "tornado": "../Marketing/My Dirty Little Lake/1 Final/Steam Store/Screenshots and Clips/10_tornado.png",
}
PLATE_GRAIN = {k: ROOM_GRAIN for k in ("catch", "smoke", "queen", "settled", "uncap", "pour", "done")}
PLATE_GRAIN.update({k: ISLAND_GRAIN for k in ("empty", "swarm", "ready", "busy")})
PLATE_GRAIN.update({k: LAKE_GRAIN for k in ("moment", "honey")})

_plate_cache = {}


def plate(name):
    """A fresh RGBA copy of a capture, by short name (PLATES) or path from the project root."""
    path = PLATES.get(name, name)
    full = os.path.join(ROOT, path)
    if full not in _plate_cache:
        _plate_cache[full] = Image.open(full).convert("RGBA")
    return _plate_cache[full].copy()


def snap(v, grain, origin=0):
    return origin + int(round((v - origin) / grain)) * grain


def art_px(xy, grain=ROOM_GRAIN, origin=(0, 0)):
    """An art-grid coordinate on a plate -> the plate pixel of that art pixel's top-left."""
    return (origin[0] + xy[0] * grain, origin[1] + xy[1] * grain)


def place(dst, im, at, grain=ROOM_GRAIN, origin=(0, 0), anchor=(0, 0)):
    """Blow `im` (1x) up by `grain`, nearest, and composite it onto `dst` IN PLACE so that its
    art pixel `anchor` lands on plate pixel `at`, snapped to the plate's lattice. Returns dst."""
    big = zoom(im, grain)
    x = snap(at[0], grain, origin[0]) - anchor[0] * grain
    y = snap(at[1], grain, origin[1]) - anchor[1] * grain
    layer = Image.new("RGBA", dst.size, (0, 0, 0, 0))
    layer.paste(big, (int(x), int(y)))
    dst.alpha_composite(layer)
    return dst


def place_art(dst, im, art_xy, grain=ROOM_GRAIN, origin=(0, 0), anchor=(0, 0)):
    """`place` with the spot given in art pixels of the plate's grid."""
    return place(dst, im, art_px(art_xy, grain, origin), grain, origin, anchor)


def zoom(im, s):
    s = int(s)
    return im.resize((im.width * s, im.height * s), Image.NEAREST)


def downsample(plate_im, grain=ROOM_GRAIN, origin=(0, 0)):
    """A plate back to one pixel per art pixel (each cell's middle), for drawing at 1x over it."""
    import numpy as np
    a = np.array(plate_im)
    return Image.fromarray(a[origin[1] + grain // 2::grain, origin[0] + grain // 2::grain].copy())


# --- taking today's bees off a plate --------------------------------------------------------
OLD_BEE = {bh.OUT[:3], bh.BEE_GOLD[:3], bh.BEE_STRIPE[:3], bh.BEE_THORAX[:3], bh.BEE_HEAD[:3],
           bh.QUEEN_GOLD[:3], bh.QUEEN_LIT[:3]}


def clean_bees(dst, box, grain=ROOM_GRAIN, origin=(0, 0), reach=12):
    """Take today's bees off a stretch of SKY (or any ground of horizontal bands) in place: an
    art cell whose colour is a bee's is refilled with the nearest clean cell in its own art row,
    and the pale wing cells over a bee go with it. `box` is plate px. Not for comb (see
    `restore_comb`)."""
    import numpy as np
    a = np.array(dst)
    x0, y0, x1, y1 = box
    c0, r0 = (x0 - origin[0]) // grain, (y0 - origin[1]) // grain
    c1, r1 = (x1 - origin[0]) // grain, (y1 - origin[1]) // grain
    mid = grain // 2
    cells = a[origin[1] + mid::grain, origin[0] + mid::grain, :3].astype(int)
    rows, cols = cells.shape[:2]
    r1, c1 = min(r1, rows), min(c1, cols)
    bad = np.zeros((rows, cols), bool)
    for r in range(r0, r1):
        for c in range(c0, c1):
            if tuple(cells[r, c]) in OLD_BEE:
                bad[r, c] = True
    # wings: pale blue-white cells up to three cells over a bee cell
    grown = bad.copy()
    for r in range(r0, r1):
        for c in range(c0, c1):
            if bad[r, c]:
                continue
            p = cells[r, c]
            if p[0] > 180 and p[1] > 195 and p[2] > 195:
                near = bad[max(0, r - 1):r + 4, max(0, c - 2):c + 3].any()
                win = cells[max(0, r - 2):r + 3, max(0, c - 2):c + 3]
                pale = ((win[..., 0] > 180) & (win[..., 1] > 195) & (win[..., 2] > 195)).sum()
                if near and pale <= 6:
                    grown[r, c] = True
    for r in range(r0, r1):
        for c in range(c0, c1):
            if not grown[r, c]:
                continue
            fill = None
            for k in range(1, reach):
                for cc in (c - k, c + k):
                    if 0 <= cc < cols and not grown[r, cc]:
                        fill = cells[r, cc]
                        break
                if fill is not None:
                    break
            if fill is None:
                continue
            py, px = origin[1] + r * grain, origin[0] + c * grain
            a[py:py + grain, px:px + grain, :3] = fill
            a[py:py + grain, px:px + grain, 3] = 255
    out = Image.fromarray(a)
    dst.paste(out)
    return dst


def room_piece(name):
    """A piece of assets/hive_room.png (the game's room art, no bees on it) and its anchors."""
    import json
    j = json.load(open(os.path.join(ROOT, "assets/hive_room.json")))["pieces"][name]
    x, y, w, h = j["rect"]
    sheet = Image.open(os.path.join(ROOT, "assets/hive_room.png")).convert("RGBA")
    return sheet.crop((x, y, x + w, y + h)), j.get("anchors", {})


# The brood frame's spot on the queen plate, matched pixel for pixel (art grid), and the art row
# where the front bars start covering it.
QUEEN_FRAME_AT = (157, 44)
QUEEN_BARS_FROM = 221


def restore_comb(dst):
    """The queen plate's brood frame painted back without its bees (the game's own piece at the
    matched spot), down to where the front bars begin. In place; returns dst."""
    piece, _ = room_piece("frame_brood")
    keep = QUEEN_BARS_FROM - QUEEN_FRAME_AT[1]
    piece = piece.crop((0, 0, piece.width, keep))
    return place_art(dst, piece, QUEEN_FRAME_AT, ROOM_GRAIN)


# =============================================================================================
# Palette
# =============================================================================================
PAL = bh.PAL                      # palette.tres: name -> (r, g, b, 255)
OUT = bh.OUT                      # (24, 18, 17): every sprite's outline


def _c(r, g, b, a=255):
    return (r, g, b, a)


SW = {
    # the outline
    "out": OUT,
    # the coin (assets/coin.png), darkest to palest
    "coin_deep": _c(132, 88, 22), "coin_low": _c(184, 133, 36), "coin_shade": _c(214, 160, 52),
    "coin": _c(255, 204, 77), "coin_lit": _c(255, 236, 150), "coin_pale": _c(255, 252, 222),
    # the finds' gold (NetShape.GOLD_*), the lucky net's ramp
    "gold_shade": _c(70, 40, 8), "gold_deep": _c(122, 76, 18), "gold_low": _c(196, 136, 34),
    "gold": _c(240, 190, 64), "gold_lit": _c(255, 226, 128), "gold_pale": _c(255, 244, 196),
    # the hive's honey (build_hive)
    "honey_deep": bh.HONEY_DEEP, "honey_mid": bh.HONEY_MID, "honey": bh.HONEY,
    "honey_light": bh.HONEY_LIGHT, "honey_shine": bh.HONEY_SHINE,
    # today's bee stripe and the bark (build_hive): the dark browns already on the hive's art
    "stripe": bh.BEE_STRIPE, "bark_deep": bh.BARK[2], "bark": bh.BARK[1], "bark_lit": bh.BARK[0],
    # the island hive's roof paint (build_hive ROOF), the game's one coral
    "roof_lit": bh.ROOF["lit"], "roof": bh.ROOF["base"], "roof_shade": bh.ROOF["shade"],
    # the palette's foam, clean water and sky, for wings
    "foam_light": PAL["foam_light"], "foam": PAL["foam"],
    "water_light": PAL["water_clean_light"], "water_shallow": PAL["water_clean_shallow"],
    "water_mid": PAL["water_clean_mid"], "sky_low": PAL["sky_noon_low"],
}


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def darker(c, t=0.25):
    return mix(c, OUT, t)


# =============================================================================================
# Pixel tools
# =============================================================================================
def grid(rows, key, ox=0, oy=0, into=None, size=None):
    """Paint authored rows (one char a pixel, '.' clear) through `key` (char -> colour) into
    `into` at (ox, oy), or a new image of `size` (default: the rows' own size). Returns it."""
    if into is None:
        w = size[0] if size else max(len(r) for r in rows)
        h = size[1] if size else len(rows)
        into = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in ". ":
                continue
            c = key.get(ch)
            if c is None:
                continue
            px, py = ox + x, oy + y
            if 0 <= px < into.width and 0 <= py < into.height:
                into.putpixel((px, py), c)
    return into


def inked(im, col=OUT):
    """build_hive's one-pixel outline round everything opaque (the image grows a px a side)."""
    return bh.inked(im, col)


def ring(im, col=OUT):
    """The outline drawn inside the image's own bounds: every clear pixel touching an opaque
    one (4-neighbour) goes `col`."""
    a = im.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = a
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown = ImageChops.lighter(grown, ImageChops.offset(a, dx, dy))
    edge = ImageChops.subtract(grown, a)
    out = im.copy()
    out.paste(Image.new("RGBA", im.size, col), (0, 0), edge)
    return out


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def turned(im, k):
    """`k` quarter turns anticlockwise (build_hive's bee() rule)."""
    for _ in range(k % 4):
        im = im.transpose(Image.ROTATE_90)
    return im


def tinted(im, toward, t):
    """Every opaque pixel mixed `t` of the way to `toward` (depth in a clump)."""
    if t <= 0:
        return im
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3]:
                q = mix(p, toward, t)
                px[x, y] = q[:3] + (p[3],)
    return out


def bbox_size(im):
    b = im.getbbox()
    return (0, 0) if not b else (b[2] - b[0], b[3] - b[1])


# =============================================================================================
# The bee. Three variants inside Richard's brief (2026-10-16): a round striped body about 9x7,
# one big dark eye with a white glint, flickering pale wings, a little bob as it flies.
#
#   A  "coin"   the coin's own gold, two brown bands (the finds' gold shade), a 2x2 eye mid-face
#              with a top-left glint, a coral cheek, one curled feeler, small paddle wings.
#   B  "honey"  the hive's honey, chubby (11x8), near-black bands, a cream fluff collar, a tall
#              2x3 eye high on the face, big round wings, no feeler.
#   C  "lemon"  the finds' pale gold, a dark tail and one thin band, a big round 3x3 eye low on
#              the face, two feelers, long swept wings.
#
# Grid key: O outline, L lit, G gold, S shade, D deep, K band, k band lit, E eye, w glint,
# c cheek, F fluff, A feeler, T sting. Wings: O outline, W wing, V wing shade (the far wing).
# Every grid faces right; the body grid's (0, 0) is its top-left corner.
# =============================================================================================
VARIANTS = ("A", "B", "C")
VARIANT_NAMES = {"A": "coin", "B": "honey", "C": "lemon"}


def key(v):
    """The variant's colours, grid char -> RGBA (every one an `SW` swatch)."""
    base = {"O": OUT, "E": OUT, "A": OUT, "T": OUT, "w": SW["foam_light"], "c": SW["roof_lit"],
            "R": SW["roof"]}
    if v == "A":
        base.update({"L": SW["coin_lit"], "G": SW["coin"], "S": SW["coin_shade"],
                     "D": SW["coin_low"], "K": SW["gold_shade"], "k": SW["gold_deep"],
                     "F": SW["coin_pale"], "W": SW["foam"], "V": SW["water_light"],
                     "Y": SW["coin_lit"], "y": SW["coin_shade"]})
    elif v == "B":
        base.update({"L": SW["honey_light"], "G": SW["honey"], "S": SW["honey_mid"],
                     "D": SW["honey_deep"], "K": SW["stripe"], "k": SW["bark_deep"],
                     "F": SW["gold_pale"], "W": SW["foam_light"], "V": SW["foam"],
                     "Y": SW["gold_lit"], "y": SW["gold_low"]})
    elif v == "R":
        # "R", the round coin bee (2026-10-17, the queen sheet's art review): A's colours, a
        # dark tail tip (T), one wrapping band lit on its top (k over K), a bottom shade (B),
        # the wings pale sky blue with a foam highlight (W, h) and the far wing a step down (V);
        # the queen's amber (Q, q, s, b) and her coin-gold crown (Z, Y, y) with a coral jewel.
        base.update({"L": SW["coin_lit"], "G": SW["coin"], "S": SW["coin_shade"],
                     "B": SW["coin_low"], "D": SW["coin_low"], "K": SW["gold_shade"],
                     "k": SW["gold_deep"], "T": SW["gold_shade"], "F": SW["coin_pale"],
                     "W": SW["sky_low"], "h": SW["foam"],
                     "V": mix(SW["sky_low"], SW["water_shallow"], 0.45),
                     "Q": bh.QUEEN_GOLD, "q": bh.QUEEN_LIT, "s": mix(bh.QUEEN_GOLD, OUT, 0.2),
                     "b": mix(bh.QUEEN_GOLD, OUT, 0.38),
                     "Z": SW["coin_lit"], "Y": SW["coin"], "y": SW["coin_shade"]})
    else:
        base.update({"L": SW["gold_pale"], "G": SW["gold_lit"], "S": SW["gold"],
                     "D": SW["gold_low"], "K": SW["stripe"], "k": SW["gold_shade"],
                     "F": SW["gold_pale"], "W": SW["foam"], "V": SW["water_light"],
                     "Y": SW["coin"], "y": SW["coin_low"]})
    return base


# --- A: coin --------------------------------------------------------------------------------
_A = {
    "body": [
        "..OOOOOO..",
        ".OkLkLLLO.",
        "OGKGKGwEGO",
        "OGKGKGEEGO",
        "OSKSKSScSO",
        ".OKDKDDDO.",
        "..OOOOOO..",
    ],
    "blink": {(6, 2): "G", (7, 2): "G", (6, 3): "E", (7, 3): "E"},
    "extra": [(-1, 4, "T"), (7, -1, "A"), (8, -2, "A"), (9, -2, "A")],
    # wings: [(rows, x, y), ...] relative to the body's top-left; the far wing first, the near
    # wing last (drawn over the body).
    "wings": {
        "up": [([".OO.", "OVVO", "OVVO"], 1, -3),
               ([".OO.", "OWWO", "OWWO", "OWWO"], 3, -4)],
        "mid": [(["OOO..", "OVVOO", ".OVVO"], 0, -2),
                (["OO....", "OWOO..", "OWWWOO", ".OWWWO"], 1, -3)],
        "down": [(["OOOOO.", "OVVVVO", ".OOOO."], 0, -1),
                 (["OOOOOO.", "OWWWWWO", ".OOOOO."], 1, -1)],
        "fold": [(["OOOO..", "OWWWOO"], 0, -1)],
    },
    "legs": [[(2, 7), (5, 7), (7, 7)], [(3, 7), (4, 7), (6, 7)]],
    "rest_legs": [(3, 7), (6, 7)],
}

# --- B: honey (chubby, fluff collar, tall eye) ----------------------------------------------
_B = {
    "body": [
        "...OOOOO...",
        ".OOLkLFLOO.",
        "OGKGKGFwEGO",
        "OGKGKGFEEGO",
        "OGKGKGFEEGO",
        "OSKSKSFScSO",
        ".OODKDDDOO.",
        "...OOOOO...",
    ],
    "blink": {(7, 2): "G", (8, 2): "G", (7, 3): "G", (8, 3): "G", (7, 4): "E", (8, 4): "E"},
    "extra": [(-1, 4, "T")],
    "wings": {
        "up": [([".OOO.", "OVVVO", "OVVVO", ".OOO."], 1, -3),
               ([".OOO.", "OWWWO", "OWWWO", "OWWWO", ".OWO."], 3, -4)],
        "mid": [(["OOOO..", "OVVVOO", ".OOVVO"], 0, -2),
                (["OOO....", "OWWOO..", "OWWWWOO", ".OOWWWO"], 1, -3)],
        "down": [([".OOOOO.", "OVVVVVO", ".OOOOO."], 0, -1),
                 ([".OOOOO.", "OWWWWWWO", ".OOOOOO."], 2, -1)],
        "fold": [(["OOOOO..", "OWWWWOO"], 1, -1)],
    },
    "legs": [[(3, 8), (5, 8), (7, 8)], [(4, 8), (6, 8), (7, 8)]],
    "rest_legs": [(4, 8), (7, 8)],
}

# --- C: lemon (big round eye low on the face, long swept wings, two feelers) -----------------
_C = {
    "body": [
        "..OOOOOO..",
        ".OLKLLLLO.",
        "OKGKGwEEGO",
        "OKGKGEEEGO",
        "OKSKSEEESO",
        ".ODKDDcDO.",
        "..OOOOOO..",
    ],
    "blink": {(5, 2): "G", (6, 2): "G", (7, 2): "G", (5, 3): "G", (6, 3): "G", (7, 3): "G",
              (5, 4): "E", (6, 4): "E", (7, 4): "E"},
    "extra": [(-1, 4, "T"), (6, -1, "A"), (7, -2, "A"), (8, -1, "A"), (9, -2, "A")],
    "wings": {
        "up": [(["..OO", ".OVO", "OVVO", "OVO."], 0, -4),
               (["..OO.", ".OWWO", "OWWO.", "OWWO.", "OWO.."], 1, -5)],
        "mid": [(["OOOOO.", ".OVVVO", "..OOO."], -2, -2),
                (["OOOOOO..", "OWWWWWOO", ".OOWWWWO", "...OOOO."], -2, -3)],
        "down": [(["OOOOOO.", "OVVVVVO", ".OOOOO."], -2, -1),
                 (["OOOOOOO.", "OWWWWWWO", ".OOOOOOO"], -1, 0)],
        "fold": [(["OOOOOOO", "OWWWWWO", ".OOOOO."], -1, -1)],
    },
    "legs": [[(2, 7), (5, 7), (7, 7)], [(3, 7), (4, 7), (6, 7)]],
    "rest_legs": [(3, 7), (6, 7)],
}

_SPEC = {"A": _A, "B": _B, "C": _C}

# --- R: round coin (2026-10-17, after the queen sheet's art review) --------------------------
# Not one of VARIANTS (the bee sheet's three); asked for by name, bee("R"). A's coin colours on
# the same 10 x 7 octagon, reworked so it reads as a bee and not a letter at game size: one
# band that wraps (lit on its top row) between a dark tail tip and the head, the eye a 2 x 2 in
# the head third with its glint on the top left (the room's sun) and a pixel of face in front
# of it, and the wings pale sky-blue leaves with their own outline, rooted on the back and
# leaning towards the tail, lifted off it in flight, lying on it folded.
_R = {
    "body": [
        "..OOOOOO..",
        ".OLkLLLLO.",
        "OTGKGGwEGO",
        "OTGKGGEEGO",
        "OTSKSSScSO",
        ".OBKBBBBO.",
        "..OOOOOO..",
    ],
    "blink": {(6, 2): "G", (7, 2): "G", (6, 3): "E", (7, 3): "E"},
    "extra": [(8, -1, "A"), (9, -2, "A")],
    "wings": {
        "up": [([".OO..", "OVVO.", "OVVVO", ".OVVO", "..OO."], 0, -4),
               ([".OO...", "OhWO..", "OWWWO.", ".OWWWO", "..OOO."], 2, -4)],
        "mid": [(["OOO...", "OVVOO.", ".OVVVO", "..OOO."], -1, -3),
                (["OOO....", "OhWOO..", ".OWWWWO", "..OOOO."], 1, -3)],
        "down": [(["OOOO...", "OVVVOO.", ".OOOOO."], -1, -2),
                 (["OOOOO..", "OhWWWOO", ".OOWWWO", "...OOO."], 1, -2)],
        "fold": [([".OOOO..", "OVVVVO.", ".OOOO.."], 0, -2),
                 ([".OOOO..", "OhWWWO.", "OWWWWO.", ".OOOO.."], 2, -2)],
    },
    "legs": [[(2, 7), (5, 7), (7, 7)], [(3, 7), (4, 7), (6, 7)]],
    "rest_legs": [(3, 7), (6, 7)],
}
_SPEC["R"] = _R

# The worker's canvas: every frame of every pose of every variant is this size, the body's
# top-left at BODY_AT (plus the bob), so frames line up and `bee_anchor` holds for all of them.
BEE_CANVAS = (16, 16)
BODY_AT = (3, 6)

WING_STATES = ("up", "mid", "down")   # fly frames 0, 1, 2 (then again for 3, 4, 5)
BOB = (0, 0, 0, -1, -1, -1)            # fly frame f bobs BOB[f % 6] art px


def _body(spec, blink=False):
    rows = [list(r) for r in spec["body"]]
    if blink:
        for (x, y), ch in spec["blink"].items():
            rows[y][x] = ch
    return ["".join(r) for r in rows]


def _compose(spec, k, canvas, at, wings_state, legs, blink, extras=True):
    im = Image.new("RGBA", canvas, (0, 0, 0, 0))
    bx, by = at
    wings = spec["wings"][wings_state]
    for rows, wx, wy in wings[:-1]:
        grid(rows, k, bx + wx, by + wy, into=im)
    for lx, ly in legs:
        grid(["O"], k, bx + lx, by + ly, into=im)
    grid(_body(spec, blink), k, bx, by, into=im)
    if extras:
        for x, y, ch in spec["extra"]:
            grid([ch], k, bx + x, by + y, into=im)
    rows, wx, wy = wings[-1]
    grid(rows, k, bx + wx, by + wy, into=im)
    return im


def bee(variant="A", frame=0, facing_left=False, pose="fly", turn=0):
    """The cute worker bee at one pixel per art pixel, on a fixed BEE_CANVAS (16x16) RGBA image.

    pose 'fly'  : wings flicker up / mid / down on frame % 3 and the body bobs one art px on a
                  six-frame cycle (frames 0-2 level, 3-5 one up). Loop frames 0..5.
    pose 'hover': 'fly' with no bob (a bee held in a clump or over a flower). Loop 0..2.
    pose 'walk' : crawling, wings folded flat on the back, three legs shuffling on frame % 2.
    pose 'rest' : landed and still, wings folded, two legs; frame % 4 == 3 blinks. Loop 0..3.

    facing_left mirrors it (the grids face right). turn = quarter turns anticlockwise, for a bee
    crawling up (turn=1 from facing right) or down a comb. `bee_anchor` gives the body's middle."""
    s = _SPEC[variant]
    k = key(variant)
    bx, by = BODY_AT
    if pose == "fly":
        by += BOB[frame % 6]
    if pose in ("fly", "hover"):
        state, legs = WING_STATES[frame % 3], []
    elif pose == "walk":
        state, legs = "fold", s["legs"][frame % 2]
    else:
        state, legs = "fold", s["rest_legs"]
    im = _compose(s, k, BEE_CANVAS, (bx, by), state, legs, pose == "rest" and frame % 4 == 3)
    if facing_left:
        im = flip(im)
    return turned(im, turn)


def bee_keyed(variant="A", frame=0, facing_left=False, pose="fly", turn=0, over=None, face=True):
    """`bee` with some of its grid colours swapped (`over`: grid char -> RGBA, e.g. a ramp a step
    darker for a bee in shade, or a step paler), the outline 'O' untouched unless named. face=False
    paints the eye and its glint over in the body gold: the bee seen from behind, crawling away.
    Added 2026-10-17 for the smoke sheet's beard; `bee` itself is unchanged."""
    s = _SPEC[variant]
    k = dict(key(variant))
    if over:
        k.update(over)
    if not face:
        k["E"] = k["G"]
        k["w"] = k["G"]
        k["c"] = k["S"]
    bx, by = BODY_AT
    if pose == "fly":
        by += BOB[frame % 6]
    if pose in ("fly", "hover"):
        state, legs = WING_STATES[frame % 3], []
    elif pose == "walk":
        state, legs = "fold", s["legs"][frame % 2]
    else:
        state, legs = "fold", s["rest_legs"]
    blink = pose == "rest" and frame % 4 == 3 and face
    im = _compose(s, k, BEE_CANVAS, (bx, by), state, legs, blink)
    if facing_left:
        im = flip(im)
    return turned(im, turn)


def bee_anchor(variant="A", pose="fly", facing_left=False, frame=0):
    """The middle of the bee's body in its BEE_CANVAS image (before any turn)."""
    body = _SPEC[variant]["body"]
    x = BODY_AT[0] + len(body[0]) // 2
    y = BODY_AT[1] + len(body) // 2 + (BOB[frame % 6] if pose == "fly" else 0)
    if facing_left:
        x = BEE_CANVAS[0] - 1 - x
    return (x, y)


def bee_frames(pose="fly"):
    """How many distinct frames a pose loops over: fly 6, hover 3, walk 2, rest 4."""
    return {"fly": 6, "hover": 3, "walk": 2, "rest": 4}[pose]


def bee_size(variant="A"):
    """The body's own size with its outline (no wings, feelers or sting): about 9x7."""
    body = _SPEC[variant]["body"]
    return (len(body[0]), len(body))


# =============================================================================================
# The mini bee: the lake's bee at the flowers, in the swarm on the island and commuting to the
# hive, at one world px an art px (the hive's, the angler's and the pack flowers' grain). The
# same bee: the same colours, band, eye with its glint, pale wings, outline; 7x5 with outline.
# =============================================================================================
_MINI = {
    "A": {"body": [".OOOOO.", "OGKGwGO", "OGKGEGO", "OSKSScO", ".OOOOO."],
          "extra": [(-1, 3, "T"), (5, -1, "A"), (6, -2, "A")]},
    "B": {"body": [".OOOOO.", "OKGFwGO", "OKGFEGO", "OKSFScO", ".OOOOO."],
          "extra": [(-1, 2, "T")]},
    "C": {"body": [".OOOOO.", "OKGKwEO", "OKGKEEO", "OKSKScO", ".OOOOO."],
          "extra": [(-1, 2, "T"), (4, -1, "A"), (6, -1, "A")]},
}
# R's mini: the dark tail tip, the band, the eye in front (see _R).
_MINI["R"] = {"body": [".OOOOO.", "OTLkLLO", "OTGKGEO", "OTSKScO", ".OOOOO."],
              "extra": [(5, -1, "A")]}
_MINI_WINGS = {
    "up": [([".O.", "OVO"], 1, -2), ([".OO.", "OWWO", "OWWO"], 2, -3)],
    "mid": [(["OO.", "OVO"], 0, -2), (["OOO.", "OWWO"], 1, -2)],
    "down": [(["OOO", "OVO"], 0, -1), (["OOO", "OWO"], 1, -1)],
    "fold": [(["OOOO", "OWWO"], 1, -1)],
}
MINI_CANVAS = (10, 9)
MINI_AT = (2, 3)


def mini_bee(variant="A", frame=0, facing_left=False, pose="fly"):
    """The lake's small bee, one pixel per art (world) pixel, on a fixed MINI_CANVAS (10x9).

    pose 'fly' : wings up / mid / down on frame % 3, a one-px bob on frames 3-5. Loop 0..5.
    pose 'rest': on a flower, wings folded, still.
    Same colours and parts as `bee(variant)`; `mini_anchor` gives the body's middle."""
    m = _MINI[variant]
    k = key(variant)
    bx, by = MINI_AT
    spec = {"body": m["body"], "extra": m["extra"], "wings": _MINI_WINGS, "blink": {}}
    if pose == "fly":
        by += BOB[frame % 6]
        im = _compose(spec, k, MINI_CANVAS, (bx, by), WING_STATES[frame % 3], [], False)
    else:
        im = _compose(spec, k, MINI_CANVAS, (bx, by), "fold", [(2, 5), (4, 5)], False)
    return flip(im) if facing_left else im


def mini_anchor(variant="A", pose="fly", facing_left=False, frame=0):
    x = MINI_AT[0] + 3
    y = MINI_AT[1] + 2 + (BOB[frame % 6] if pose == "fly" else 0)
    if facing_left:
        x = MINI_CANVAS[0] - 1 - x
    return (x, y)


# =============================================================================================
# The round mini bee (added 2026-10-17 for the honey sheet's second review: `mini_bee` above is
# a squared 7x5 block whose outlined wing sits on it like a lid). A 6x5 oval body with every
# corner pixel cut, ringed in the outline (8x7 with it); two dark bands; a 2x2 eye on the front
# with a one-px glint on its leading pixel, a coral cheek under it; the wings are two pale dabs
# with no outline, set back from the head and standing off the body's top edge, flicking up /
# mid / down; a sting at the tail and one feeler. `mini_bee` is unchanged; other sheets still
# draw it until they are moved over.
# =============================================================================================
_ROUND_BODY = [".kLkL.",
               "GKGKEw",
               "GKGKEE",
               "SKSKSc",
               ".KDKD."]
# wing dabs: (key char, [(x, y)...]) relative to the body's top-left, far wing (V) first
_ROUND_WINGS = {
    "up": [("V", [(0, -3), (1, -3), (1, -2)]),
           ("W", [(2, -4), (3, -4), (2, -3), (3, -3), (2, -2)])],
    "mid": [("V", [(0, -2), (1, -2)]),
            ("W", [(1, -3), (2, -3), (3, -3), (2, -2), (3, -2)])],
    "down": [("V", [(-1, -2), (0, -2)]),
             ("W", [(0, -3), (1, -2), (2, -2), (3, -2)])],
    "fold": [("W", [(0, -1), (1, -1), (2, -1)])],
}
ROUND_CANVAS = (12, 11)
ROUND_AT = (3, 5)


def mini_round(variant="A", frame=0, facing_left=False, pose="fly"):
    """The round mini bee, one pixel per art (world) pixel, on a fixed ROUND_CANVAS (12x11).
    pose 'fly': wings up / mid / down on frame % 3, the body bobs one px on frames 3-5 (loop
    0..5). pose 'rest': wings folded flat along the back. The body is 8x7 with its outline."""
    k = key(variant)
    bx, by = ROUND_AT
    if pose == "fly":
        by += BOB[frame % 6]
    im = Image.new("RGBA", ROUND_CANVAS, (0, 0, 0, 0))
    grid(_ROUND_BODY, k, bx, by, into=im)
    im = ring(im)
    im.putpixel((bx - 2, by + 2), k["T"])      # sting
    im.putpixel((bx + 6, by - 1), k["A"])      # feeler
    state = WING_STATES[frame % 3] if pose == "fly" else "fold"
    for ch, pts in _ROUND_WINGS[state]:
        for x, y in pts:
            im.putpixel((bx + x, by + y), k[ch])
    return flip(im) if facing_left else im


def mini_round_anchor(variant="A", pose="fly", facing_left=False, frame=0):
    """The round mini bee's body middle in its ROUND_CANVAS image."""
    x = ROUND_AT[0] + 3
    y = ROUND_AT[1] + 2 + (BOB[frame % 6] if pose == "fly" else 0)
    if facing_left:
        x = ROUND_CANVAS[0] - 1 - x
    return (x, y)


# =============================================================================================
# The queen: the worker's face on a long tapering abdomen of bands, a gold crown with a coral
# jewel on her head. Seen on the comb (wings folded), walking; `laying` dips the tail.
# =============================================================================================
_QUEEN = {
    "A": {
        "body": [
            "....OOOOOOOO..",
            "..OOkLkLFLLLO.",
            ".OKGKGKGFGwEGO",
            "OGKGKGKGFGEEGO",
            ".OKSKSKSSSScSO",
            "..OOKDKDDDDDO.",
            "....OOOOOOOO..",
        ],
        "crown_at": (8, -3),
        "extra": [(-1, 3, "T")],
        "fold": [(["OOOOOOO..", "OWWWWWWOO"], 2, -1)],
        "legs": [[(6, 7), (9, 7), (11, 7)], [(7, 7), (8, 7), (10, 7)]],
    },
    "B": {
        "body": [
            ".....OOOOOOO...",
            "...OOLkLkLFLOO.",
            ".OKGKGKGKGFwEGO",
            "OGKGKGKGKGFEEGO",
            "OGKGKGKGKGFEEGO",
            ".OKSKSKSKSFScSO",
            "...OODKDKDDDOO.",
            ".....OOOOOOO...",
        ],
        "crown_at": (9, -3),
        "extra": [(-1, 4, "T")],
        "fold": [(["OOOOOOO..", "OWWWWWWOO"], 3, -1)],
        "legs": [[(6, 8), (9, 8), (11, 8)], [(7, 8), (8, 8), (10, 8)]],
    },
    "C": {
        "body": [
            "....OOOOOOOO..",
            "..OOLKLKLLLLO.",
            ".OGKGKGKGwEEGO",
            "OKGKGKGKGEEEGO",
            ".OSKSKSKSEEESO",
            "..OODKDKDDcDO.",
            "....OOOOOOOO..",
        ],
        "crown_at": (8, -3),
        "extra": [(-1, 3, "T")],
        "fold": [(["OOOOOOOO.", "OWWWWWWWO", ".OOOOOOO."], 1, -1)],
        "legs": [[(5, 7), (8, 7), (11, 7)], [(6, 7), (7, 7), (10, 7)]],
    },
}
# R's queen (2026-10-17, the queen sheet's art review): told from her workers three ways at
# once. Her silhouette: 18 x 7 with outline, nearly twice a worker's length, the abdomen
# tapering to a point, three bands, the wings short over her thorax so the bare bands show.
# Her colour: the hive's QUEEN_GOLD amber (build_hive), not the worker's coin yellow. Her crown:
# CROWN_R in the coin's gold (lit points, a coral jewel) with its own outline.
_QUEEN["R"] = {
    "body": [
        "......OOOOOOOOOO..",
        "...OOOkqqkqqqqqqO.",
        ".OOKQQKQQKQQQQwEQO",
        "OTQKQQKQQKQQQQEEQO",
        ".OOKssKssKssssscsO",
        "...OOOKbbKbbbbbbO.",
        "......OOOOOOOOOO..",
    ],
    "crown_at": (12, -3),
    "extra": [],
    "fold": [([".OOO.", "OVVVO", ".OOO."], 4, -2),
             ([".OOOO.", "OhWWWO", ".OOOO."], 6, -2)],
    "legs": [[(7, 7), (10, 7), (13, 7)], [(8, 7), (11, 7), (12, 7)]],
}
CROWN = ["Y.Y.Y", "YYRYY", "yyyyy"]
CROWN_R = ["Z.Z.Z", "YYRYY", "yyyyy"]
QUEEN_CANVAS = (21, 16)
QUEEN_AT = (3, 6)
QUEEN_TAIL = 5       # columns of the abdomen that dip when she lays


def crown(variant="A"):
    """The queen's little gold crown with its coral jewel, inked (7x5)."""
    k = key(variant)
    im = grid(CROWN_R if variant == "R" else CROWN, k)
    # the tips get their own outline caps
    out = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 1))
    return ring(out)


def queen(variant="A", frame=0, laying=False, facing_left=False, turn=0):
    """The queen at one pixel per art pixel, on a fixed QUEEN_CANVAS (21x16) RGBA image: the
    worker's face and eye on a long banded abdomen, a crown on her head, wings folded, three
    legs shuffling on frame % 2 (walking on the comb). laying=True dips her last QUEEN_TAIL
    columns one px. `queen_anchor` gives her body's middle."""
    q = _QUEEN[variant]
    k = key(variant)
    bx, by = QUEEN_AT
    im = Image.new("RGBA", QUEEN_CANVAS, (0, 0, 0, 0))
    for lx, ly in q["legs"][frame % 2]:
        grid(["O"], k, bx + lx, by + ly, into=im)
    body = Image.new("RGBA", QUEEN_CANVAS, (0, 0, 0, 0))
    grid(q["body"], k, bx, by, into=body)
    for x, y, ch in q["extra"]:
        grid([ch], k, bx + x, by + y, into=body)
    if laying:
        cut = bx + QUEEN_TAIL
        tail = body.crop((0, 0, cut, QUEEN_CANVAS[1]))
        clear = Image.new("RGBA", (cut, QUEEN_CANVAS[1]), (0, 0, 0, 0))
        body.paste(clear, (0, 0))
        body.alpha_composite(tail, (0, 1))
    im.alpha_composite(body)
    for rows, wx, wy in q["fold"]:
        grid(rows, k, bx + wx, by + wy, into=im)
    cx, cy = q["crown_at"]
    im.alpha_composite(crown(variant), (bx + cx - 1, by + cy - 1))
    if facing_left:
        im = flip(im)
    return turned(im, turn)


def queen_anchor(variant="A", facing_left=False):
    body = _QUEEN[variant]["body"]
    x = QUEEN_AT[0] + len(body[0]) // 2
    y = QUEEN_AT[1] + len(body) // 2
    if facing_left:
        x = QUEEN_CANVAS[0] - 1 - x
    return (x, y)


# =============================================================================================
# The swarm: n bees composed into a living clump.
# =============================================================================================
def _inside(shape, u, v):
    """Is (u, v) in [-1, 1]^2 inside the clump's shape?"""
    if shape == "beard":            # wide flat top, tapering to a round point below
        if v < -1 or v > 1:
            return False
        half = 1.0 - 0.75 * ((v + 1) / 2) ** 1.4
        return abs(u) <= half and (v > -0.85 or abs(u) < 0.85)
    if shape == "mound":            # flat foot, round top (a heap on a box or a bar)
        if v > 0.85:
            return False
        return u * u + (min(v, 0.0) ** 2) <= 1.0 and abs(u) <= 1.0
    return u * u + v * v <= 1.0     # 'clump'


def swarm(variant="A", n=40, seed=1, box=(80, 64), frame=0, shape="clump", loose=0.12,
          spacing=(6.0, 4.6), depth=0.22):
    """n bees composed into a living clump, at one pixel per art pixel, an RGBA image of `box`.

    The core fills `shape` ('clump' an ellipse, 'beard' hanging from a flat top, 'mound' a heap
    on a flat foot), the bees about `spacing` (across, down) apart so each overlaps its
    neighbours by about half and keeps its outline, eye and stripes. The core's size follows n;
    the box only bounds it. Inside the clump they crawl over each other with wings folded (walk
    and rest, some turned up or down); round its edge most hover, wings flickering. Every bee has
    its own facing and its own phase of `frame`; they are drawn back to front by height, the back
    ones `depth` darker. `loose` of them fly round the clump, bobbing. Animate by stepping
    `frame`; the same seed keeps the same bees."""
    w, h = box
    rng = random.Random(seed)
    n_loose = int(round(n * loose))
    n_core = n - n_loose
    sx, sy = spacing
    aspect = 1.3
    area = n_core * sx * sy * 1.45
    ry = math.sqrt(area / (math.pi * aspect))
    rx = ry * aspect
    rx = min(rx, (w - 26) / 2.0)
    ry = min(ry, (h - 20) / 2.0)
    cx, cy = w / 2.0, h / 2.0
    pts = []
    tries = 0
    shrink = 1.0
    while len(pts) < n_core and tries < 30000:
        tries += 1
        if tries % 6000 == 0 and shrink > 0.8:
            shrink -= 0.05
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if not _inside(shape, u, v):
            continue
        x, y = cx + u * rx, cy + v * ry
        if all(((x - a) / (sx * shrink)) ** 2 + ((y - b) / (sy * shrink)) ** 2 >= 1.0
               for a, b, _ in pts):
            pts.append((x, y, math.sqrt(u * u + v * v)))
    bees = []
    for x, y, r in pts:
        roll = rng.random()
        if r < 0.7:
            pose = "walk" if roll < 0.62 else ("rest" if roll < 0.82 else "hover")
        else:
            pose = "hover" if roll < 0.6 else "walk"
        left = rng.random() < 0.5
        turn = 0
        if pose == "walk" and rng.random() < 0.2:
            turn = rng.choice([1, 3])
        phase = rng.randrange(6)
        bees.append((y, x, pose, left, turn, phase))
    bees.sort()
    im = Image.new("RGBA", box, (0, 0, 0, 0))
    lowest = min((b[0] for b in bees), default=0)
    highest = max((b[0] for b in bees), default=1)
    for y, x, pose, left, turn, phase in bees:
        f = frame + phase
        spr = bee(variant, f, facing_left=left, pose=pose, turn=turn)
        ax, ay = bee_anchor(variant, pose, left, f)
        if turn:
            ax, ay = spr.width // 2, spr.height // 2
        t = depth * (1.0 - (y - lowest) / max(1.0, highest - lowest))
        im.alpha_composite(tinted(spr, OUT, t), (int(round(x - ax)), int(round(y - ay))))
    # the loose ones: round the clump on an ellipse past it, bobbing and drifting round
    for i in range(n_loose):
        a = rng.uniform(0, 2 * math.pi) + frame * 0.09 * (1 if i % 2 else -1)
        rr = rng.uniform(1.25, 1.5)
        x = min(max(cx + math.cos(a) * (rx + 5) * rr, 9), w - 9)
        y = min(max(cy + math.sin(a) * (ry + 4) * rr, 10), h - 6)
        left = rng.random() < 0.5
        f = frame + rng.randrange(6)
        spr = bee(variant, f, facing_left=left, pose="fly")
        ax, ay = bee_anchor(variant, "fly", left, f)
        im.alpha_composite(spr, (int(round(x - ax)), int(round(y - ay))))
    return im


def mini_swarm(variant="A", n=18, seed=1, box=(34, 32), frame=0, shape="beard", loose=0.22,
               spacing=(4.0, 3.0), depth=0.25):
    """The lake's swarm: n MINI bees in a clump, at one pixel per art (world) pixel, an RGBA image
    of `box`. `swarm`'s composition with `mini_bee` (added 2026-10-16 for the island sheet): the
    core fills `shape` ('beard' hangs from a flat top, 'clump', 'mound'), bees about `spacing`
    apart so each keeps its eye and band; inner bees rest (wings folded), edge bees fly in place;
    back ones `depth` darker; `loose` of them circle it inside the box. Same seed, same bees."""
    w, h = box
    rng = random.Random(seed)
    n_loose = int(round(n * loose))
    n_core = n - n_loose
    sx, sy = spacing
    aspect = 1.15 if shape == "beard" else 1.3
    area = n_core * sx * sy * 1.45
    ry = math.sqrt(area / (math.pi * aspect))
    rx = ry * aspect
    rx = min(rx, (w - 12) / 2.0)
    ry = min(ry, (h - 10) / 2.0)
    cx, cy = w / 2.0, h / 2.0
    pts = []
    tries = 0
    shrink = 1.0
    while len(pts) < n_core and tries < 20000:
        tries += 1
        if tries % 4000 == 0 and shrink > 0.75:
            shrink -= 0.05
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if not _inside(shape, u, v):
            continue
        x, y = cx + u * rx, cy + v * ry
        if all(((x - a) / (sx * shrink)) ** 2 + ((y - b) / (sy * shrink)) ** 2 >= 1.0
               for a, b, _ in pts):
            pts.append((x, y, math.sqrt(u * u + v * v)))
    bees = []
    for x, y, r in pts:
        pose = "rest" if (r < 0.65 and rng.random() < 0.75) else "fly"
        bees.append((y, x, pose, rng.random() < 0.5, rng.randrange(6)))
    bees.sort()
    im = Image.new("RGBA", box, (0, 0, 0, 0))
    lowest = min((b[0] for b in bees), default=0)
    highest = max((b[0] for b in bees), default=1)
    for y, x, pose, left, phase in bees:
        f = frame + phase
        spr = mini_bee(variant, f, facing_left=left, pose=pose)
        ax, ay = mini_anchor(variant, pose, left, f)
        t = depth * (1.0 - (y - lowest) / max(1.0, highest - lowest))
        im.alpha_composite(tinted(spr, OUT, t), (int(round(x - ax)), int(round(y - ay))))
    for i in range(n_loose):
        a = rng.uniform(0, 2 * math.pi) + frame * 0.11 * (1 if i % 2 else -1)
        rr = rng.uniform(1.2, 1.45)
        x = min(max(cx + math.cos(a) * (rx + 3) * rr, 5), w - 6)
        y = min(max(cy + math.sin(a) * (ry + 2) * rr, 5), h - 4)
        left = rng.random() < 0.5
        f = frame + rng.randrange(6)
        spr = mini_bee(variant, f, facing_left=left, pose="fly")
        ax, ay = mini_anchor(variant, "fly", left, f)
        im.alpha_composite(spr, (int(round(x - ax)), int(round(y - ay))))
    return im


# =============================================================================================
# Sheets
# =============================================================================================
FONT_LABEL = os.path.join(ROOT, "assets/Bungee-Regular.ttf")
FONT_TEXT = "C:/Windows/Fonts/arial.ttf"
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"
SHEET_BG = (36, 32, 30, 255)
PANEL_BG = (52, 46, 42, 255)
INK = (236, 228, 214, 255)
INK_SOFT = (176, 166, 150, 255)
PICK = (112, 199, 107, 255)          # Style.SAFE: the recommended option's tag
MARK = (255, 64, 200, 255)           # where a zoom crop came from (never on the art itself)

_fonts = {}


def font(size, kind="text"):
    path = {"label": FONT_LABEL, "text": FONT_TEXT, "bold": FONT_BOLD}[kind]
    if (path, size) not in _fonts:
        _fonts[(path, size)] = ImageFont.truetype(path, size)
    return _fonts[(path, size)]


def text_size(s, f):
    b = f.getbbox(s)
    return (b[2] - b[0], b[3] - b[1])


def wrap(s, f, width):
    words, lines, cur = s.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if text_size(t, f)[0] <= width or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def text_block(s, width, size=18, kind="text", ink=INK, bg=None, line_gap=4):
    f = font(size, kind)
    lines = wrap(s, f, width)
    lh = size + line_gap
    im = Image.new("RGBA", (width, max(1, lh * len(lines))), bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, ln in enumerate(lines):
        d.text((0, i * lh), ln, font=f, fill=ink)
    return im


def frame(im, pad=6, bg=PANEL_BG, border=(90, 80, 72, 255)):
    out = Image.new("RGBA", (im.width + pad * 2 + 2, im.height + pad * 2 + 2), border)
    inner = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), bg)
    inner.alpha_composite(im, (pad, pad))
    out.paste(inner, (1, 1))
    return out


def panel(im, title=None, caption=None, width=None, pad=6, size=16):
    """An image in a frame with a small title over it and a caption under it."""
    body = frame(im, pad)
    w = max(body.width, width or 0)
    parts = []
    if title:
        parts.append(text_block(title, w, size, "bold", INK))
    parts.append(body)
    if caption:
        parts.append(text_block(caption, w, size - 2, "text", INK_SOFT))
    return stack(parts, "v", 4)


def stack(ims, direction="h", gap=12, bg=(0, 0, 0, 0), align="start"):
    ims = [i for i in ims if i is not None]
    if not ims:
        return Image.new("RGBA", (1, 1), bg)
    if direction == "h":
        w = sum(i.width for i in ims) + gap * (len(ims) - 1)
        h = max(i.height for i in ims)
    else:
        w = max(i.width for i in ims)
        h = sum(i.height for i in ims) + gap * (len(ims) - 1)
    out = Image.new("RGBA", (w, h), bg)
    at = 0
    for i in ims:
        if direction == "h":
            y = 0 if align == "start" else (h - i.height) // 2
            out.alpha_composite(i, (at, y))
            at += i.width + gap
        else:
            x = 0 if align == "start" else (w - i.width) // 2
            out.alpha_composite(i, (x, at))
            at += i.height + gap
    return out


def flow(ims, max_width, gap=14):
    """Panels laid left to right, wrapping into rows no wider than max_width."""
    rows, cur, cw = [], [], 0
    for i in ims:
        if cur and cw + gap + i.width > max_width:
            rows.append(stack(cur, "h", gap))
            cur, cw = [], 0
        cur.append(i)
        cw += i.width + (gap if len(cur) > 1 else 0)
    if cur:
        rows.append(stack(cur, "h", gap))
    return stack(rows, "v", gap)


def crop_zoom(src, box, s=4, mark_on=None):
    """A nearest zoom of `box` of `src`; with mark_on, outlines that box on mark_on (a copy you
    are about to show) so the eye can find where the detail came from."""
    if mark_on is not None:
        ImageDraw.Draw(mark_on).rectangle([box[0] - 2, box[1] - 2, box[2] + 1, box[3] + 1],
                                          outline=MARK, width=2)
    return zoom(src.crop(box), s)


def option_block(label, name, caption, body, recommended=False, width=None):
    """One option of a sheet: a big letter, its name, RECOMMENDED if picked, the panels, and a
    one-line caption."""
    w = max(body.width, width or 0)
    head = Image.new("RGBA", (w, 54), (0, 0, 0, 0))
    d = ImageDraw.Draw(head)
    d.text((0, 0), label, font=font(44, "label"), fill=INK)
    lw = text_size(label, font(44, "label"))[0]
    d.text((lw + 18, 14), name, font=font(26, "label"), fill=INK_SOFT)
    if recommended:
        nw = text_size(name, font(26, "label"))[0]
        tag = "RECOMMENDED"
        tw, th = text_size(tag, font(20, "label"))
        x = lw + 18 + nw + 24
        d.rectangle([x, 12, x + tw + 20, 12 + th + 16], fill=PICK)
        d.text((x + 10, 16), tag, font=font(20, "label"), fill=(24, 18, 17, 255))
    cap = text_block(caption, w, 20, "text", INK)
    return stack([head, cap, body], "v", 8)


def sheet(title, options, out_path, subtitle=None, notes=None, pad=36):
    """Lay out a sheet: a title, an optional subtitle, the options (from option_block) stacked
    down, optional notes at the foot; saved to out_path (PNG). Returns the image."""
    body = stack(options, "v", 48)
    w = body.width + pad * 2
    parts = [text_block(title, body.width, 40, "label", INK)]
    if subtitle:
        parts.append(text_block(subtitle, body.width, 20, "text", INK_SOFT))
    parts.append(body)
    if notes:
        parts.append(text_block(notes, body.width, 18, "text", INK_SOFT))
    inner = stack(parts, "v", 20)
    out = Image.new("RGBA", (w, inner.height + pad * 2), SHEET_BG)
    out.alpha_composite(inner, (pad, pad))
    out.convert("RGB").save(out_path)
    return out


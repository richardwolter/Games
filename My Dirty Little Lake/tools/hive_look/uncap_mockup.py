#!/usr/bin/env python
"""The uncap sheet (2026-10-16/17, the hive overhaul): the bucket, the trough and the hot knife.

Writes tools/hive_look/last_uncap.png. Three options, A / B / C, each a bucket and an open
trough drawn ON the uncap capture at the room's own grain (3 screen px an art px), shown first
at real scale side by side (the read that matters), then with 2x-4x zoom crops.

The backdrop is the backdrop sheet's recommended look (backdrop_mockup, borrowed when it is
there): no rubbish, no piers' signs, no ferries, no dogs, its flower bed and bees; the step's
own work (the rest, the frame, the curtains, the UI) is put back from the capture, and today's
mint tub, steel pipe, knife handle and donut curl are taken off first (uncap_clean.py).

The buckets are named for the pour sheet, which carries the same bucket to the bottling table
(pour_art.bucket imports them; the small gate keeps its 11 x 12 / 10 x 13 canvas so the pour can
swap it for its working gate):
    A  GALVANISED PAIL   build_hive STEEL tin, a few big zinc spangles on the lit side, a rolled
                         rim, two pressed ribs, the wire bail dropped back flat behind the far rim
                         with a short oak grip, a brass gate (boss, 3-px nozzle, 1-px lever)
    B  OAK HONEY BUCKET  coopered staves in the hut's oak ramp, two iron hoops, two tall ears
                         with a rope handle, a brass tap shut low on the front
    C  HONEY CROCK       paper-cream stoneware dipped in cobalt on a near-straight line with
                         three short runs, a cobalt bee painted on, cobalt lugs, an oak tap

The troughs, each its own silhouette and material, all seen a little from above (a lit far lip,
a dark inside wall, a broad honey surface, the near rim, a short face):
    A  a deep tin U with a flat riveted face, on iron strap cradles bolted to the frame
    B  two oak boards nailed in a V, slung on pine rope knotted round the frame's foot
    C  a copper half-round eaves gutter, a tall back flange and a fat bead, on one steel wire each
Every hanger is a U-cradle: down behind the trough, round under it, up the face to a bolt.

Every colour is an in-game ramp, a look.SW swatch, or a mix of two (RAMPS says which). Every
sprite is ringed in OUT, every edge hard, no gradient but stepped bands and a 2x2 checker on a
shadow's fringe. The light is the brief's: the room's sun top left, so shadows fall down and to
the right; the sheet names the contradiction with the game's Shade.drop (LIGHT_NOTE).

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages"         python tools/hive_look/uncap_mockup.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
import uncap_clean  # noqa: E402
from look import ROOM_GRAIN as G, panel, stack, flow  # noqa: E402
from PIL import Image  # noqa: E402

OUT_PATH = os.path.join(look.HERE, "last_uncap.png")
SCRATCH = os.path.join(look.HERE, "scratch_uncap")
RECOMMEND = "A"
BEE = "A"                      # the bee sheet's pick (coin)

W, H = look.ROOM_GRID
P = look.PAL
SW = look.SW
OUT = look.OUT
CLEAR = (0, 0, 0, 0)
mix = look.mix
bh = look.bh
Art = bh.Art


def _c(t):
    return tuple(t[:3]) + (255,)


def hsh(*v):
    """A stable hash of integers to [0, 1)."""
    h = 2166136261
    for n in v:
        h = ((h ^ (int(n) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


# =============================================================================================
# Colours: in-game ramps, SW swatches, or a mix of two of them
# =============================================================================================
S = {k: _c(bh.STEEL[k]) for k in ("hi", "lit", "base", "shade", "deep")}     # tin / galvanised
S_ORDER = [S["hi"], S["lit"], S["base"], S["shade"], S["deep"]]
IRON = {"hi": S["base"], "lit": S["shade"], "base": mix(S["deep"], OUT, 0.38)}
BRASS = {"pale": SW["coin_pale"], "lit": _c(bh.BRASS["lit"]), "base": _c(bh.BRASS["base"]),
         "shade": _c(bh.BRASS["shade"]), "deep": _c(bh.BRASS["deep"])}
LEATHER = {k: _c(bh.LEATHER[k]) for k in ("lit", "base", "shade")}
# the hut's oak (build_shed_v2.WALL, the recycle box's oak), darkest first
OAK = [_c(c) for c in ((38, 24, 22), (58, 36, 29), (78, 48, 36), (100, 64, 45), (122, 80, 54),
                       (168, 118, 76), (214, 166, 110))]
PINE = [_c(bh.PINE_DEEP), _c(bh.PINE_SHADE), _c(bh.PINE), _c(bh.PINE_LIT)]
# the pots' clay (build_shed_v2.CLAY): the crock's glaze, darkest first
CLAY = [_c(c) for c in ((84, 38, 30), (140, 68, 46), (192, 106, 70), (224, 150, 104))]
# the boards' paper (Style.PAPER*) and the cream: the crock's stoneware, darkest first
STONE = [mix(_c(bh.PAPER_EDGE), OUT, 0.32), _c(bh.PAPER_EDGE), _c(bh.PAPER), _c(bh.CREAM),
         SW["coin_pale"]]
# the recycle mark's blue (Style.BOX_BLUE*), darkest first
BLUE = [_c((46, 86, 112)), _c((77, 133, 166)), _c((110, 168, 204))]
HONEY = {"deep": SW["honey_deep"], "mid": SW["honey_mid"], "base": SW["honey"],
         "light": SW["honey_light"], "shine": SW["honey_shine"], "white": SW["foam_light"]}
WAX = {"gloss": SW["coin_pale"], "lit": _c(bh.WAX_LIT), "base": _c(bh.WAX),
       "shade": _c(bh.WAX_SHADE), "wall": _c(bh.WAX_WALL), "hole": _c(bh.CELL_EMPTY)}
HEAT = {"warm": mix(S["lit"], SW["coin_lit"], 0.5), "gold": SW["coin_lit"], "glow": SW["roof_lit"],
        "white": SW["gold_pale"], "spark": SW["foam_light"]}
# copper for C's eaves gutter: the pots' clay ramp (it is the clay's own red-brown), its lit
# step taken half way to coin_pale for the shine
COPPER = {"deep": CLAY[0], "mid": CLAY[1], "base": CLAY[2], "lit": CLAY[3],
          "hi": mix(CLAY[3], SW["coin_pale"], 0.5)}
# cobalt for the crock's dipped shoulder: the recycle mark's blue, a step under it toward OUT
# and a gloss half way to the cream
COBALT = [mix(BLUE[0], OUT, 0.35), BLUE[0], BLUE[1], BLUE[2], mix(BLUE[2], SW["coin_pale"], 0.5)]
SHADOW = (24, 18, 17, 112)     # the land's shadow ink, as the room's own shadows lay it
SHADOW_DARK = (24, 18, 17, 150)

RAMPS = [("steel", S, "build_hive STEEL (the knife, today's gutter): the tin of pail and trough"),
         ("iron", IRON, "STEEL's shade and deep, the deep taken toward OUT"),
         ("brass", BRASS, "build_hive BRASS, coin_pale for the glint"),
         ("leather", LEATHER, "build_hive LEATHER"),
         ("oak", dict(enumerate(OAK)), "the hut's oak (build_shed_v2.WALL, the recycle box)"),
         ("pine", dict(enumerate(PINE)), "build_hive PINE: the rope"),
         ("clay", dict(enumerate(CLAY)), "the pots' clay (build_shed_v2.CLAY): the glaze"),
         ("stone", dict(enumerate(STONE)), "Style.PAPER*, the cream, coin_pale: stoneware"),
         ("cobalt", dict(enumerate(COBALT)), "the recycle mark's blue (Style.BOX_BLUE*), a step "
                                               "toward OUT, a gloss toward coin_pale"),
         ("copper", COPPER, "the pots' clay ramp, its lit step toward coin_pale: C's gutter"),
         ("heat", HEAT, "STEEL lit to coin_lit, coin_lit, the roof's coral, gold_pale, foam")]


# =============================================================================================
# The trough: where it hangs (today's gutter line, three px lower, run on past the rest's leg)
# =============================================================================================
X0 = 143                      # the high end, art px
DROP = 3                      # three px under today's line: a gap under the frame's foot
CURTAINS = [uncap_clean.FRAME_AT[0] + c for c in uncap_clean.CURTAIN_X]
CURTAIN_W = [8, 12, 14, 10, 7, 6]
STRAPS = [182, 326, 462]      # between the curtains
SPILL_X = 447
FRAME_FOOT = uncap_clean.FRAME_AT[1] + uncap_clean.FRAME_SIZE[1] - 2       # 218
GROUND = 289                  # the lawn under the rest's front feet (art row of the legs' foot)


def ty(x):
    """The trough's rim row at column x (the front rim's top). Every band of the trough is a
    whole number of rows off this one line, so the slope steps once, cleanly, every ~11 px."""
    return int(math.floor(uncap_clean.gut(x) + DROP + 0.5))


# Each trough is a profile down a column, rows relative to ty(x):
#   back   the far lip (and C's flange), drawn first
#   wall   the inside seen from above, top to bottom, when no honey covers it
#   hbot   the lowest honey row (the honey lies on the near side, against the front rim)
#   front  the near rim and the face, drawn over the honey and the curtains
# Read at 1x the opening is the widest band in every trough: a thin lit far lip, a dark inside
# wall, then a broad lit honey surface, then the near rim. A pipe shows none of that.
FLOOR = IRON["base"]          # the inside under the far lip: STEEL deep toward OUT
TROUGHS = {
    # A: a deep square U in tin: a 1-px lit far lip, three rows of dark inside wall, up to seven
    # rows of honey, a bright rolled bead, and a short FLAT face in shade (one tone and one dark
    # bottom edge) with lap seams and rivets
    "A": {"back": [(-12, OUT), (-11, S["hi"])],
          "wall": [(-10, FLOOR), (-9, S["deep"]), (-8, S["deep"]), (-7, S["deep"]),
                   (-6, S["shade"]), (-5, S["shade"]), (-4, S["shade"]), (-3, S["shade"]),
                   (-2, S["shade"]), (-1, S["shade"])],
          "hbot": -1, "most": 7,
          "front": [(0, S["hi"]), (1, S["lit"]), (2, OUT), (3, S["shade"]), (4, S["shade"]),
                    (5, S["deep"]), (6, OUT)]},
    # B: a V of two oak boards nailed together, seen from above: the back board's lit arris, its
    # inner face in shade sloping down to the dark crease (the honey lies in it), the front
    # board's lit top edge two px thick, its outer face lighter than the inside
    "B": {"back": [(-12, OUT), (-11, OAK[6])],
          "wall": [(-10, OAK[1]), (-9, OAK[2]), (-8, OAK[2]), (-7, OAK[2]), (-6, OAK[1]),
                   (-5, OAK[1]), (-4, OAK[0]), (-3, OAK[1]), (-2, OAK[2]), (-1, OAK[2])],
          "hbot": -1, "most": 7,
          "front": [(0, OAK[6]), (1, OAK[5]), (2, OUT), (3, OAK[4]), (4, OAK[3]), (5, OUT)]},
    # C: a half-round copper eaves gutter: a tall back flange (a lit top edge, its inner face in
    # shade) standing four rows over the honey, the honey, a fat round bead, a short rounded
    # belly with one dark core line
    "C": {"back": [(-13, OUT), (-12, COPPER["hi"]), (-11, COPPER["mid"])],
          "wall": [(-10, COPPER["deep"]), (-9, COPPER["deep"]), (-8, COPPER["mid"]),
                   (-7, COPPER["mid"]), (-6, COPPER["mid"]), (-5, COPPER["mid"]),
                   (-4, COPPER["mid"]), (-3, COPPER["base"])],
          "hbot": -3, "most": 6,
          "front": [(-2, OUT), (-1, COPPER["lit"]), (0, COPPER["hi"]), (1, COPPER["base"]),
                    (2, OUT), (3, COPPER["mid"]), (4, COPPER["deep"]), (5, OUT)]},
}


def tr_top(style):
    return TROUGHS[style]["back"][0][0]


def tr_bottom(style):
    return TROUGHS[style]["front"][-1][0]


def rim_row(style):
    """The front rim's first lit row (where a curtain's honey bulges over it)."""
    for dy, c in TROUGHS[style]["front"]:
        if c != OUT:
            return dy
    return 0


_STYLE = ["A"]                # the trough being drawn (render sets it)


def honey_rise(x):
    """How many rows of honey stand in the trough at x: none upstream of the first curtain, then
    3 up to the trough's most, fed by every curtain it is downstream of, a slow swell along it."""
    fed = 0.0
    for cx, w in zip(CURTAINS, CURTAIN_W):
        if x >= cx - 3:
            fed += w
    if fed == 0:
        return 0
    most = TROUGHS[_STYLE[0]]["most"]
    k = fed / sum(CURTAIN_W)
    r = 4.0 + (most - 4.0) * k ** 0.6 + 0.5 * math.sin(x * 0.11) * min(1.0, k * 2)
    return max(4, min(most, int(round(r))))


def honey_top(x):
    r = honey_rise(x)
    if r == 0:
        return None
    return ty(x) + TROUGHS[_STYLE[0]]["hbot"] - r + 1


def draw_rows(a, style, part, x0, x1):
    for x in range(x0, x1 + 1):
        y = ty(x)
        for dy, c in TROUGHS[style][part]:
            a.px(x, y + dy, c)


def draw_trough_back(a, style, x1):
    """The far lip and the inside wall from the high end to x1, and the inside of the high end's
    plate (two lit columns over the dark inside, so the run reads as a box with its lid off)."""
    draw_rows(a, style, "back", X0, x1)
    draw_rows(a, style, "wall", X0, x1)
    y = ty(X0)
    top = TROUGHS[style]["wall"][0][0]
    bot = TROUGHS[style]["hbot"]
    end_lit, end_base = {"A": (S["lit"], S["base"]), "B": (OAK[5], OAK[4]),
                         "C": (COPPER["lit"], COPPER["base"])}[style]
    for dy in range(top, bot + 1):
        a.px(X0 + 1, y + dy, end_lit)
        a.px(X0 + 2, y + dy, end_base)
    if style == "B":
        # grain dashes along the back board's inner face, and the plank's end joints
        for x in range(X0 + 4, x1 - 1):
            for dy in (-9, -8):
                if hsh(x // 5, dy, 41) < 0.22:
                    a.px(x, ty(x) + dy, OAK[1])


def draw_trough_honey(a, x1):
    """The honey lying in the trough, seen from above: a deep wet line on the wall over it, its
    far edge lit, a broken lit streak, the body, a step darker against the near rim; glints and
    bubbles riding down it. Every row is continuous: only its top edge follows the honey's rise."""
    bot = TROUGHS[_STYLE[0]]["hbot"]
    for x in range(X0 + 3, x1 + 1):
        top = honey_top(x)
        if top is None:
            continue
        foot = ty(x) + bot
        rows = list(range(top, foot + 1))
        a.px(x, top - 1, HONEY["deep"])               # the wet line on the wall over it
        for i, yy in enumerate(rows):
            if i == 0:
                c = HONEY["light"]
            elif i == 1:
                c = HONEY["shine"] if hsh(x // 4, 31) < 0.3 else HONEY["light"]
            elif i == len(rows) - 1:
                c = HONEY["mid"]
            elif i == 3 and len(rows) >= 6 and hsh((x + 2 * yy) // 4, 37) < 0.34:
                c = HONEY["light"]                   # ripples running down the surface
            else:
                c = HONEY["base"]
            a.px(x, yy, c)
    for gx in (246, 296, 334, 372, 410, 452, 488, 508):
        top = honey_top(gx)
        if top is not None and gx <= x1 - 2:
            a.px(gx, top + 1, HONEY["white"])
            a.px(gx + 1, top + 1, HONEY["shine"])
            a.px(gx - 1, top + 1, HONEY["shine"])
    for bx in (318, 398, 470):
        top = honey_top(bx)
        if top is not None and bx <= x1 - 2:
            a.px(bx, top + 2, HONEY["shine"])
            a.px(bx + 1, top + 2, HONEY["light"])


def draw_curtains(a, kept):
    """The curtains run on from where the capture leaves them, sink into the trough's honey and
    flare into it with no seam (the game's own rope rows and soft rows); rings open round each.
    Returns where each lands: [(middle, width)]."""
    import numpy as np
    out = []
    for cx in CURTAINS:
        cols = [x for x in range(cx - 14, cx + 15) if kept[:, x].any()]
        if not cols:
            continue
        bottom = max(int(np.nonzero(kept[:, x])[0].max()) for x in cols)
        row = [x for x in cols if kept[bottom, x]]
        if not row:
            continue
        l, r = min(row), max(row)
        mid = (l + r) / 2.0
        w = r - l
        join = honey_top(int(mid))
        if join is None:
            join = ty(int(mid)) - 5
        end = join + 1
        for yy in range(bottom + 1, end + 1):
            left = end - yy
            if left <= 3:
                u = 1.0 - left / 3.0
                soft_row(a, mid, yy, w + u * u * 5)
            else:
                rope_row(a, mid, yy, w)
        for s in (1, -1):
            for d, c in ((w // 2 + 4, HONEY["shine"]), (w // 2 + 7, HONEY["light"])):
                x = int(round(mid + s * d))
                if honey_top(x) is not None:
                    a.px(x, honey_top(x), c)
        out.append((mid, w))
    return out


def rope_row(a, cx, y, w):
    l = int(round(cx - w * 0.5))
    r = int(round(cx + w * 0.5))
    span = r - l
    if span < 1:
        a.px(l, y, HONEY["mid"])
        return
    a.rect(l, y, span + 1, 1, HONEY["base"])
    a.rect(l, y, max(math.ceil(span * 0.22), 1), 1, HONEY["mid"])
    a.rect(l + math.ceil(span * 0.28), y, max(math.ceil(span * 0.17), 1), 1, HONEY["shine"])
    a.rect(l + math.ceil(span * 0.45), y, max(math.ceil(span * 0.15), 1), 1, HONEY["light"])
    a.px(l, y, HONEY["deep"])
    a.px(r, y, HONEY["deep"])


def soft_row(a, cx, y, w):
    l = int(round(cx - w * 0.5))
    r = int(round(cx + w * 0.5))
    a.rect(l, y, max(r - l + 1, 1), 1, HONEY["light"])
    span = r - l
    if span >= 3:
        a.rect(l + math.ceil(span * 0.3), y, max(math.ceil(span * 0.25), 1), 1, HONEY["shine"])


def draw_bulges(a, style, landed):
    """Where each curtain lands the honey stands a pixel proud of the near rim: it lies over the
    rim's lit row, a lit middle and darker ends, so the curtain reads as filling the trough."""
    rr = rim_row(style)
    for mid, w in landed:
        l = int(round(mid - w * 0.5)) - 1
        r = int(round(mid + w * 0.5)) + 1
        for x in range(l, r + 1):
            y = ty(x) + rr
            edge = x in (l, r)
            a.px(x, y, HONEY["mid"] if edge else HONEY["light"])
            if style == "C":
                a.px(x, y - 1, HONEY["base"] if edge else HONEY["light"])   # over the bead's line
        a.px(int(round(mid)) - 1, ty(int(round(mid))) + rr, HONEY["shine"])


def draw_trough_front(a, style, x1):
    """The near rim and the face, and the face's own make: A lap seams and rivets, B a butt
    joint and nails, C a soldered seam and the bead's glints."""
    draw_rows(a, style, "front", X0, x1)
    bottom = tr_bottom(style)
    if style == "A":
        for sx in (232, 352, 432):
            y = ty(sx)
            for dy in range(3, bottom):
                a.px(sx, y + dy, S["shade"])
                a.px(sx + 1, y + dy, S["hi"])
            for dx in (-2, 3):
                a.px(sx + dx, y + 4, S["deep"])
                a.px(sx + dx - 1, y + 4, S["lit"])
    elif style == "B":
        for x in range(X0 + 2, x1 - 1):
            for dy in (3, 4):
                if hsh(x // 6, dy, 43) < 0.18:
                    a.px(x, ty(x) + dy, OAK[3])                 # grain on the outer face
        for sx in (290, 412):
            y = ty(sx)
            for dy in range(0, bottom):
                a.px(sx, y + dy, OAK[1])                        # where two boards butt
            a.px(sx + 1, y, OAK[6])
        for nx in range(X0 + 12, x1 - 4, 30):
            y = ty(nx)
            a.px(nx, y + 4, OAK[0])                             # a nail head, its glint
            a.px(nx - 1, y + 3, OAK[6])
    else:
        for sx in (262, 402):
            y = ty(sx)
            for dy in range(3, bottom):
                a.px(sx, y + dy, COPPER["deep"])
                a.px(sx + 1, y + dy, COPPER["hi"] if dy == 3 else COPPER["lit"])
        for gx in range(X0 + 16, x1 - 4, 46):
            a.px(gx, ty(gx) - 1, SW["coin_pale"])               # a glint along the bead
    # the high end's cap, closing the profile
    y = ty(X0)
    for dy in range(tr_top(style), bottom + 1):
        a.px(X0 - 1, y + dy, OUT)


# --- the hangers: each a U-cradle -------------------------------------------------------------
# It comes down from the frame's foot BEHIND the trough (so the far lip is drawn over it), is
# hidden by the trough's body, and shows again on the face: from a bolt just under the rim down
# the face and round under the belly, two px past the bottom outline. It never runs on below.
def _strap_column(a, sx, y0, y1, cols):
    for yy in range(y0, y1 + 1):
        for dx, c in cols:
            a.px(sx + dx, yy, c)


def draw_hangers_back(a, style):
    """The upper half of each cradle: frame foot to just behind the far lip."""
    for sx in STRAPS:
        y = ty(sx)
        top = y + tr_top(style)
        if style == "A":
            _strap_column(a, sx, FRAME_FOOT + 1, top, [(-2, OUT), (-1, IRON["lit"]),
                                                      (0, IRON["base"]), (1, IRON["base"]),
                                                      (2, OUT)])
            # the bolt through the frame's foot
            a.rect(sx - 3, FRAME_FOOT - 1, 7, 4, OUT)
            a.rect(sx - 2, FRAME_FOOT, 5, 2, IRON["lit"])
            a.px(sx - 1, FRAME_FOOT, IRON["hi"])
            a.px(sx + 1, FRAME_FOOT + 1, IRON["base"])
        elif style == "B":
            rope(a, (sx - 1, FRAME_FOOT + 2), (sx - 3, top + 1))
        else:
            _strap_column(a, sx, FRAME_FOOT + 2, top, [(-1, OUT), (0, S["lit"]), (1, OUT)])
    return


def draw_hangers_front(a, style):
    """The lower half: the face from just under the rim, round under the belly."""
    bottom = tr_bottom(style)
    for sx in STRAPS:
        y = ty(sx)
        if style == "A":
            y0, y1 = y + 3, y + bottom + 1
            _strap_column(a, sx, y0, y1, [(-2, OUT), (-1, IRON["lit"]), (0, IRON["base"]),
                                          (1, IRON["base"]), (2, OUT)])
            # round under the belly: the strap's foot turns away from us, darker, rounded
            a.rect(sx - 1, y1, 3, 1, mix(IRON["base"], OUT, 0.5))
            a.rect(sx - 1, y1 + 1, 3, 1, OUT)
            a.px(sx - 2, y1, OUT)
            a.px(sx + 2, y1, OUT)
            # the bolt just under the rim bead
            a.px(sx, y0, S["hi"])
            a.px(sx, y0 + 1, IRON["base"])
            a.px(sx + 1, y0 + 1, OUT)
        elif style == "B":
            # the front strand crosses over the opening from the knot and runs down the face,
            # then round under the keel
            rope(a, (sx + 1, FRAME_FOOT + 2), (sx + 2, y + bottom + 1))
            yb = y + bottom + 1
            a.rect(sx - 1, yb + 1, 5, 1, OUT)
            a.px(sx, yb, PINE[1])
            a.px(sx + 1, yb, PINE[2])
            # the knot round the frame's foot
            knot = Art(9, 7)
            knot.rect(1, 1, 7, 5, PINE[2])
            knot.rect(1, 1, 7, 1, PINE[3])
            knot.px(3, 3, PINE[1])
            knot.px(5, 2, PINE[1])
            knot.px(6, 4, PINE[0])
            knot.px(2, 2, PINE[3])
            a.paste(bh.inked(knot.im), sx - 5, FRAME_FOOT - 3)
        else:
            y0, y1 = y + 3, y + bottom + 2
            _strap_column(a, sx, y0, y1 - 1, [(-1, OUT), (0, S["lit"]), (1, OUT)])
            # round under: the wire turns back under the belly
            a.px(sx, y1, OUT)
            a.px(sx - 1, y1, OUT)
            a.px(sx + 1, y1, OUT)
            # the clip that holds the wire to the bead
            a.rect(sx - 2, y - 3, 5, 5, OUT)
            a.rect(sx - 1, y - 2, 3, 3, S["lit"])
            a.px(sx - 1, y - 2, S["hi"])
            a.px(sx + 1, y, S["shade"])
            # the single hook over the frame's foot
            for (hx, hy) in ((0, FRAME_FOOT + 1), (0, FRAME_FOOT), (0, FRAME_FOOT - 1),
                             (-1, FRAME_FOOT - 2), (-2, FRAME_FOOT - 2), (-3, FRAME_FOOT - 1)):
                a.px(sx + hx, hy, S["lit"])
            _outline_box(a, sx - 5, FRAME_FOOT - 4, sx + 2, FRAME_FOOT + 1)


def rope(a, p0, p1):
    """A pine rope two px wide, its twist lit on each turn, ringed (drawn on its own and inked)."""
    (x0, y0), (x1, y1) = p0, p1
    n = max(abs(x1 - x0), abs(y1 - y0))
    w = int(max(x0, x1)) + 4
    h = int(max(y0, y1)) + 4
    r = Art(w, h)
    for i in range(int(n) + 1):
        t = i / float(max(1, n))
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        r.px(x, y, PINE[3] if (y % 3) == 0 else PINE[2])
        r.px(x + 1, y, PINE[1] if (y % 3) == 1 else PINE[2])
    a.paste(bh.inked(r.im), -1, -1)


def draw_spill(a, style, x0=SPILL_X):
    """Honey brimming over the near rim at one spot: it stands proud of the rim, smears down the
    face, gathers on the bottom edge, necks and hangs there as a drop (an overspill, not a leak)."""
    y = ty(x0)
    rr = rim_row(style)
    bottom = tr_bottom(style)
    for dx in range(-2, 4):
        a.px(x0 + dx, y + rr - 1, HONEY["light"] if dx < 2 else HONEY["base"])
        a.px(x0 + dx, y + rr, HONEY["base"] if dx not in (-2, 3) else HONEY["mid"])
    a.px(x0, y + rr - 1, HONEY["shine"])
    _outline_box(a, x0 - 3, y + rr - 2, x0 + 4, y + rr - 1)
    for dy in range(rr + 1, bottom + 1):
        a.px(x0 - 1, y + dy, HONEY["light"])
        a.px(x0, y + dy, HONEY["shine"] if dy < rr + 3 else HONEY["base"])
        a.px(x0 + 1, y + dy, HONEY["mid"])
    for dx in (-2, 2):
        for dy in range(rr + 1, bottom + 1):
            a.px(x0 + dx, y + dy, OUT)
    # the neck and the drop under the bottom edge
    a.px(x0, y + bottom + 1, HONEY["base"])
    a.px(x0 - 1, y + bottom + 1, OUT)
    a.px(x0 + 1, y + bottom + 1, OUT)
    drop = [".L.", "LSH", "HHM", ".M."]
    look.grid(drop, {"L": HONEY["light"], "S": HONEY["shine"], "H": HONEY["base"],
                     "M": HONEY["mid"]}, x0 - 1, y + bottom + 2, into=a.im)
    _outline_box(a, x0 - 3, y + bottom + 1, x0 + 3, y + bottom + 7)


def _outline_box(a, x0, y0, x1, y1):
    """Ring every opaque pixel in the box that touches a clear one with OUT (in place)."""
    im = a.im
    px = im.load()
    pts = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not (0 <= x < im.width and 0 <= y < im.height) or px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if (x0 <= q[0] <= x1 and y0 <= q[1] <= y1 and 0 <= q[0] < im.width
                        and 0 <= q[1] < im.height and px[q][3] >= 200
                        and px[q][:3] != OUT[:3]):
                    pts.append((x, y))
                    break
    for p in pts:
        px[p] = OUT


# --- the low ends ----------------------------------------------------------------------------
# where the stream leaves each low end, relative to (x1, ty(x1)), and how wide it starts
END_STREAM = {"A": (-3, 7, 4.6), "B": (5, 9, 4.6), "C": (-4, 9, 3.8)}
NOTCH = [1, 2, 2, 2, 2, 1]    # A: how far the pouring notch dips into the front rim


def draw_low_end(a, style, x1):
    """The trough's low end: A an end plate and a beak pinched in the front rim, the honey
    brimming through it and sheeting down the face; B the open end of the V, the honey rolling
    off between the boards' end grain in a fat ribbon; C an end cap and a short round outlet
    under the belly. Returns where the stream leaves and its width."""
    y = ty(x1)
    bottom = tr_bottom(style)
    if style == "A":
        for dy in range(tr_top("A"), bottom + 1):
            a.px(x1 + 1, y + dy, OUT)
            if tr_top("A") < dy < bottom and dy not in (2,):
                a.px(x1, y + dy, S["lit"] if dy < 0 else S["shade"])
        n0 = x1 - len(NOTCH)
        for i, d in enumerate(NOTCH):
            x = n0 + i
            yy = ty(x)
            for k in range(d + 1):
                a.px(x, yy + k, HONEY["light"] if k == 0 else HONEY["base"])
        for i in range(1, len(NOTCH) - 1):
            x = n0 + i
            yy = ty(x)
            for dy in range(2, bottom + 1):
                c = (HONEY["light"] if i == 1 else HONEY["mid"] if i == len(NOTCH) - 2
                     else HONEY["base"])
                if i == 2 and dy in (3, 5):
                    c = HONEY["shine"]
                a.px(x, yy + dy, c)
        for dy in range(2, bottom + 1):
            a.px(n0, ty(n0) + dy, OUT)
            a.px(x1 - 1, ty(x1 - 1) + dy, OUT)
    elif style == "B":
        # the open end: the two boards' end grain, a V, the honey rolling out between them
        for dy in range(tr_top("B"), bottom + 1):
            a.px(x1 + 1, y + dy, OUT)
        for dy in range(-11, -6):
            a.px(x1, y + dy, OAK[5])                 # the back board's end grain
        for dy in range(0, bottom):
            a.px(x1, y + dy, OAK[5] if dy < 2 else OAK[4])
        top = honey_top(x1)
        for dy in range(top - y, TROUGHS["B"]["hbot"] + 1):
            a.px(x1 + 1, y + dy, HONEY["light"] if dy == top - y else HONEY["base"])
        n = 9 - (top - y)
        for i, dy in enumerate(range(top - y, 9)):
            k = i / float(max(1, n))
            w = 6.5 - 2.0 * k
            cx = x1 + 2.0 + 3.0 * math.sin(min(1.0, k * 1.6) * math.pi * 0.5)
            rope_row(a, cx, y + dy, w)
        _outline_box(a, x1 + 1, top - 1, x1 + 10, y + 9)
    else:
        for dy in range(tr_top("C"), bottom + 1):
            a.px(x1 + 1, y + dy, OUT)
            if tr_top("C") < dy < bottom and dy not in (-2, 2):
                a.px(x1, y + dy, COPPER["lit"] if dy < 0 else COPPER["mid"])
        ox = x1 - 4
        for dy in range(bottom, bottom + 3):
            for dx in range(-3, 4):
                c = (COPPER["hi"] if dx == -2 else COPPER["lit"] if dx < 0 else
                     COPPER["base"] if dx < 2 else COPPER["mid"])
                a.px(ox + dx, y + dy, c)
            a.px(ox - 4, y + dy, OUT)
            a.px(ox + 4, y + dy, OUT)
        for dx in range(-4, 5):
            a.px(ox + dx, y + bottom + 3, COPPER["lit"] if -3 <= dx <= 0 else COPPER["mid"])
            a.px(ox + dx, y + bottom + 4, OUT)
        a.px(ox - 5, y + bottom + 3, OUT)
        a.px(ox + 5, y + bottom + 3, OUT)
    dx, dy, w = END_STREAM[style]
    return (x1 + dx, y + dy), w


def sip_spot(style, x1):
    """Where a bee stands to sip at the low end: (x, y of its feet, facing_left)."""
    y = ty(x1)
    if style == "A":
        return x1 - 10, y - 1, False          # on the rim beside the beak, facing the honey sheet
    if style == "B":
        return x1 - 6, y - 12, False          # on the back board's arris over the open end
    return x1 - 9, y - 13, False              # on the copper flange over the end cap


def draw_trough_shadow(a, style, x1, blocked):
    """The trough's shadow on the lawn under the rest: a thin hard strip, a solid core and a 2x2
    checkered fringe (the bucket's rule), dropped down and to the right with the room's sun the
    further the trough hangs above the grass; each hanger and the low end leave a darker smudge
    where they come down to it. `blocked` (an art-grid mask) keeps it off the rest's legs."""
    pts = {}
    for x in range(X0, x1 + 2):
        h = GROUND - ty(x)
        sx = int(round(x + 4 + h * 0.12))
        for dy in range(-1, 2):
            pts[(sx, GROUND + dy)] = "core"
        for dy in (-2, 2):
            if (sx + GROUND + dy) % 2 == 0:
                pts.setdefault((sx, GROUND + dy), "fringe")
    for x in STRAPS + [x1 - 2]:
        h = GROUND - ty(x)
        sx = int(round(x + 4 + h * 0.12))
        for dx in range(-2, 3):
            for dy in (-1, 0, 1, 2):
                pts[(sx + dx, GROUND + dy)] = "dark"
    for (x, y), kind in pts.items():
        if 0 <= x < W and 0 <= y < H and blocked[y, x]:
            continue
        a.px(x, y, SHADOW_DARK if kind == "dark" else SHADOW)


# =============================================================================================
# The buckets: each a dict of layers on its own canvas and where its mouth is
# =============================================================================================
def _band(u, steps):
    """Pick from `steps` [(upper bound of u, colour), ...] for u across a cylinder (-1 left)."""
    for lim, c in steps:
        if u < lim:
            return c
    return steps[-1][1]


def _in_ell(x, y, cx, cy, hx, hy):
    dx = (x + 0.5 - cx) / hx
    dy = (y + 0.5 - cy) / hy
    return dx * dx + dy * dy < 1.0


def _shape(cx, y_m, y_f, hw_of, hy_f, x, y):
    """Where a pixel is on a round vessel's body (below the mouth's middle row): (u across it,
    t down it) or None. The mouth and the rim are drawn over separately."""
    if y + 0.5 < y_m:
        return None
    t = max(0.0, min(1.0, (y + 0.5 - y_m) / (y_f - y_m)))
    u = (x + 0.5 - cx) / hw_of(t)
    if abs(u) >= 1.0:
        return None
    if y + 0.5 > y_f + hy_f * math.sqrt(1 - u * u):
        return None
    return u, t


def _front_layer(im, mouth, half):
    """The near wall alone, to draw over what falls into the bucket (build_hive bucket_front)."""
    out = im.copy()
    px = out.load()
    mx, my = mouth
    for y in range(out.height):
        for x in range(out.width):
            if y <= my or _in_ell(x, y, mx, my, half[0] + 1, half[1] + 1):
                px[x, y] = CLEAR
    return out


def _rim_and_mouth(body, cx, y_m, outer, inner, back, front_hi, front, front_lo, under,
                   wall_dark, wall, wall_lit):
    """A rolled rim between the outer and the inner ellipse, lit on its near left; the inside
    wall where it shows, shaded under the left rim and lit on the right."""
    hx, hy = outer
    ix, iy = inner
    for y in range(int(y_m - hy - 1), int(y_m + hy + 2)):
        for x in range(body.w):
            if not _in_ell(x, y, cx, y_m, hx, hy):
                continue
            u = (x + 0.5 - cx) / hx
            if not _in_ell(x, y, cx, y_m, ix, iy):
                if y + 0.5 < y_m:
                    c = back if u < 0.4 else front_lo
                else:
                    c = front_hi if -0.75 < u < -0.15 else front if u < 0.55 else front_lo
                body.px(x, y, c)
                continue
            ui = (x + 0.5 - cx) / ix
            c = wall_dark if ui < 0.15 else wall
            if ui > 0.55 and y + 0.5 < y_m:
                c = wall_lit
            if not _in_ell(x, y - 2, cx, y_m, ix, iy):
                c = wall_dark                  # the shade right under the back rim
            body.px(x, y, c)
    # under the near rim, a dark line where the rolled edge meets the body
    for x in range(body.w):
        u = (x + 0.5 - cx) / hx
        if abs(u) < 0.97:
            yr = y_m + hy * math.sqrt(1 - u * u)
            body.px(x, int(yr + 0.5), under[0] if u < 0.35 else under[1])


def _drip_down(art, x, y, length):
    """A run of honey down a face from a glob on the rim (pour_art's): three px wide narrowing,
    a round bead at its foot, lit on its left."""
    for dx in range(-1, 4):
        art.px(x + dx, y - 1, HONEY["light"] if dx < 1 else HONEY["base"])
    for k in range(0, length):
        art.px(x, y + k, HONEY["shine"] if k < 2 else HONEY["light"])
        art.px(x + 1, y + k, HONEY["base"])
        if k < length * 0.55:
            art.px(x + 2, y + k, HONEY["mid"])
    bead = [".LHM.", "LSHHM", "LHHMD", ".MMD."]
    key = {"L": HONEY["light"], "S": HONEY["shine"], "H": HONEY["base"], "M": HONEY["mid"],
           "D": HONEY["deep"]}
    look.grid(bead, key, x - 1, y + length, into=art.im)


# the pail's zinc spangle: a few big flat patches (x, y off the mouth's middle, w, h), lit side
SPANGLE = [(-23, 13, 4, 3), (-14, 21, 5, 3), (-25, 29, 3, 4), (-9, 33, 4, 3), (-19, 40, 5, 3)]


def pail():
    """A: GALVANISED PAIL. Tapered tin in STEEL, mottled zinc, a rolled rim, two pressed ribs, a
    dark foot ring; riveted ears, a wire bail laid back over the mouth with an oak grip; a small
    brass honey gate shut low on the front (the pour step opens it); honey run down the front."""
    WD, HT = 68, 84
    cx, y_m, y_f = 34.0, 24.0, 70.0
    hx_m, hy_m, hy_f = 30.0, 8.5, 7.0
    inner = (27.5, 7.0)

    def hw_of(t):
        return hx_m - 5.0 * t

    body = Art(WD, HT)
    BANDS = [(-0.86, S["base"]), (-0.62, S["lit"]), (-0.36, S["hi"]), (-0.12, S["lit"]),
             (0.3, S["base"]), (0.68, S["shade"]), (2.0, S["deep"])]

    def step(c, k):
        i = S_ORDER.index(c) if c in S_ORDER else 2
        return S_ORDER[max(0, min(len(S_ORDER) - 1, i + k))]

    ribs = (0.3, 0.66)
    for y in range(HT):
        for x in range(WD):
            s = _shape(cx, y_m, y_f, hw_of, hy_f, x, y)
            if s is None:
                continue
            u, t = s
            c0 = _band(u, BANDS)
            c = c0
            for (px0, py0, pw, ph) in SPANGLE:
                # a few big flat spangle patches, one step lighter, on the lit side only, their
                # corners nicked so each is irregular
                lx, ly = x - int(cx) - px0, y - int(y_m) - py0
                if 0 <= lx < pw and 0 <= ly < ph and not (
                        (lx in (0, pw - 1) and ly in (0, ph - 1)) and hsh(px0, py0, lx, ly) < 0.7):
                    c = step(c0, -1)
            hy = hy_m + (hy_f - hy_m) * t
            arc = math.sqrt(max(0.0, 1 - u * u))
            for h in ribs:
                yh = y_m + h * (y_f - y_m) + (hy_m + (hy_f - hy_m) * h) * arc
                if abs(y + 0.5 - yh) < 0.5:
                    c = step(c0, -1)
                elif abs(y + 0.5 - (yh + 1)) < 0.5:
                    c = step(c0, 2)
            yb = y_f + hy_f * arc
            if yb - (y + 0.5) < 2.0:
                c = step(c0, 1 if yb - (y + 0.5) > 1 else 2)                  # the foot ring
            body.px(x, y, c)
    _rim_and_mouth(body, cx, y_m, (hx_m, hy_m), inner, S["base"], S["hi"], S["lit"], S["base"],
                   (S["shade"], S["deep"]), S["deep"], S["shade"], S["base"])
    # the ears: a riveted lug each side under the rim
    for sgn in (-1, 1):
        ex = int(cx + sgn * (hx_m - 2.0)) - (1 if sgn < 0 else 0)
        body.rect(ex - 1, int(y_m + 2), 3, 5, S["base"] if sgn < 0 else S["shade"])
        body.px(ex, int(y_m + 4), IRON["base"])
        body.px(ex - sgn, int(y_m + 3), S["hi"] if sgn < 0 else S["lit"])
    # the brass honey gate, shut, low on the front right: a round boss on the tin, a short
    # horizontal nozzle three px long, a one-px lever standing up off it (down = shut). The
    # pour sheet swaps this for its working gate (the same 11 x 12 canvas, see pour_art.bucket)
    gx, gy = int(cx + 8), int(y_f - 10)
    gate = Art(11, 12)
    gate.rect(1, 5, 4, 5, BRASS["base"])         # the boss against the tin
    gate.rect(1, 5, 4, 1, BRASS["lit"])
    gate.rect(1, 9, 4, 1, BRASS["shade"])
    gate.px(1, 6, BRASS["pale"])
    gate.px(4, 8, BRASS["deep"])
    gate.rect(5, 7, 3, 2, BRASS["base"])         # the nozzle, three px long
    gate.rect(5, 7, 3, 1, BRASS["lit"])
    gate.px(8, 8, BRASS["deep"])                 # its mouth
    gate.px(8, 7, BRASS["shade"])
    for i in range(4):                           # the lever: one px, laid back over the boss
        gate.px(5 + i, 5 - i, BRASS["shade"] if i < 3 else BRASS["lit"])
    gate.px(9, 1, BRASS["lit"])
    body.paste(bh.inked(gate.im), gx - 1, gy - 1)
    # a run of honey down the front from the near rim
    _drip_down(body, int(cx + 5), int(y_m + hy_m), 10)
    body_im = bh.inked(body.im)

    # the bail, dropped back flat: the wire from ear to ear lies behind the far rim, its oak grip
    # resting on the far rim at the mouth's level (drawn behind, so only what clears the rim
    # shows), short and right of the middle, clear of the trough's beak over the left of the mouth
    bail = Art(WD + 2, HT + 2)
    ex0, ex1 = cx - hx_m + 2.5, cx + hx_m - 1.5
    top = y_m - hy_m - 2
    pts = []
    for i in range(61):
        t = i / 60.0
        x = ex0 + t * (ex1 - ex0) + 1
        y = (y_m + 4) - math.sin(t * math.pi) * ((y_m + 4) - top) + 1
        pts.append((x, y))
    wire = Art(WD + 2, HT + 2)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        wire.line([(x0, y0), (x1, y1)], S["lit"])
    bail.paste(bh.inked(wire.im), -1, -1)       # a one-px wire, ringed like any sprite
    gx0 = int(cx) + 1
    gyy = int(min(p[1] for p in pts))
    bail.rect(gx0 - 1, gyy - 2, 11, 5, OUT)
    bail.rect(gx0, gyy - 1, 9, 3, OAK[4])
    bail.rect(gx0, gyy - 1, 9, 1, OAK[6])
    bail.rect(gx0, gyy + 1, 9, 1, OAK[3])
    bail.px(gx0 + 3, gyy, OAK[3])
    bail.px(gx0 + 6, gyy, OAK[5])
    mouth = (cx + 1, y_m + 1)
    return {"name": "GALVANISED PAIL", "bail": bail.im, "body": body_im,
            "front": _front_layer(body_im, mouth, (inner[0] + 1, inner[1] + 1)),
            "mouth": mouth, "inner": inner, "foot": (cx + 1, y_f + hy_f + 1),
            "foot_half": (hx_m - 5.0, hy_f), "deep": 9.0, "left": 0}


def oak_bucket():
    """B: OAK HONEY BUCKET. Nine coopered staves in the hut's oak with their seams and grain and
    a hint of a barrel's belly, two iron hoops with rivets, the staves' end grain round the mouth,
    two taller ears with a pine rope handle laid back over the mouth, a brass tap shut low."""
    WD, HT = 68, 88
    cx, y_m, y_f = 34.0, 28.0, 74.0
    hx_m, hy_m, hy_f = 29.0, 8.5, 7.0
    inner = (26.0, 6.8)

    def hw_of(t):
        return hx_m + 2.2 * math.sin(t * math.pi) - 2.0 * t

    staves = 9
    tones = [4, 5, 6, 5, 4, 4, 3, 3, 2]
    body = Art(WD, HT)
    hoops = (0.18, 0.78)
    for y in range(HT):
        for x in range(WD):
            s = _shape(cx, y_m, y_f, hw_of, hy_f, x, y)
            if s is None:
                continue
            u, t = s
            ang = math.degrees(math.asin(max(-1.0, min(1.0, u))))
            k = max(0, min(staves - 1, int((ang + 90.0) / (180.0 / staves))))
            ti = tones[k]
            c = OAK[ti]
            xl = cx + hw_of(t) * math.sin(math.radians(-90.0 + k * 180.0 / staves))
            if k > 0 and abs(x + 0.5 - xl) < 0.6:
                c = OAK[1]                                      # the seam
            elif k > 0 and abs(x + 0.5 - (xl + 1)) < 0.6 and k < 5:
                c = OAK[min(6, ti + 1)]                         # the stave's lit edge
            elif hsh(x, y // 3, k, 5) < 0.11:
                c = OAK[max(1, ti - 1)]                         # grain
            arc = math.sqrt(max(0.0, 1 - u * u))
            for h in hoops:
                yh = y_m + h * (y_f - y_m) + (hy_m + (hy_f - hy_m) * h) * arc
                d = y + 0.5 - yh
                if -0.5 <= d < 0.5:
                    c = IRON["hi"] if u < -0.2 else IRON["lit"]
                elif 0.5 <= d < 2.5:
                    c = IRON["lit"] if u < -0.5 else IRON["base"]
                elif 2.5 <= d < 3.5:
                    c = OUT
            yb = y_f + hy_f * arc
            if 0 <= yb - (y + 0.5) < 1.0:
                c = OAK[max(1, ti - 2)]
            body.px(x, y, c)
    for h in hoops:
        yh = y_m + h * (y_f - y_m) + (hy_m + (hy_f - hy_m) * h)
        body.px(int(cx - 7), int(yh + 1), S["hi"])
        body.px(int(cx + 8), int(yh + 1), S["lit"])
    # the ears first, so the rim's end grain sits over their feet
    for sgn in (-1, 1):
        ex = int(cx + sgn * (hx_m - 5)) - (3 if sgn < 0 else 0)
        etop = int(y_m - 13)
        for y in range(etop, int(y_m + 3)):
            for dx in range(4):
                c = OAK[6] if dx == 0 else OAK[5] if dx < 3 else OAK[3]
                if sgn > 0:
                    c = OAK[5] if dx == 0 else OAK[4] if dx < 3 else OAK[2]
                body.px(ex + dx, y, c)
        body.rect(ex, etop, 4, 1, OAK[6] if sgn < 0 else OAK[5])
        body.rect(ex + 1, etop + 3, 2, 2, OAK[0])
    _rim_and_mouth(body, cx, y_m, (hx_m, hy_m), inner, OAK[4], OAK[6], OAK[5], OAK[4],
                   (OAK[2], OAK[1]), OAK[1], OAK[2], OAK[3])
    # the stave joints across the end grain at the near rim
    for k in range(1, staves):
        u = math.sin(math.radians(-90.0 + k * 180.0 / staves))
        x = int(cx + u * (hx_m - 1.3))
        yr = y_m + (hy_m - 0.8) * math.sqrt(max(0.0, 1 - u * u))
        body.px(x, int(yr), OAK[3])
    # the brass tap low on the front
    tx, ty_ = int(cx + 8), int(y_f - 10)
    tap = Art(10, 13)
    tap.rect(2, 1, 5, 8, BRASS["base"])
    tap.rect(1, 2, 7, 6, BRASS["base"])
    tap.rect(2, 1, 5, 1, BRASS["lit"])
    tap.rect(1, 2, 1, 3, BRASS["lit"])
    tap.rect(3, 3, 3, 3, BRASS["shade"])
    tap.px(4, 4, BRASS["deep"])
    tap.px(3, 3, BRASS["pale"])
    tap.rect(3, 9, 3, 3, BRASS["shade"])
    tap.px(4, 11, BRASS["deep"])
    tap.rect(8, 0, 1, 4, BRASS["shade"])          # the key, turned shut
    tap.px(8, 0, BRASS["lit"])
    body.paste(bh.inked(tap.im), tx, ty_)
    body_im = bh.inked(body.im)

    # the rope handle: through the ears, laid back over the mouth (drawn behind)
    rope = Art(WD + 2, HT + 2)
    lx = cx - (hx_m - 5) - 1.5 + 1
    rx = cx + (hx_m - 5) + 1.5 + 1
    etop = y_m - 13 + 1
    top = y_m - hy_m - 14
    pts = []
    for i in range(61):
        t = i / 60.0
        x = lx + t * (rx - lx)
        y = (etop + 3) - math.sin(t * math.pi) * ((etop + 3) - top)
        pts.append((x, y))
    strand = Art(WD + 2, HT + 2)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        strand.line([(x0, y0), (x1, y1)], PINE[2], 2)
    for i, (x, y) in enumerate(pts[2:-2]):
        if i % 4 == 0:
            strand.px(x, y - 1, PINE[3])                # the twist's lit turns
            strand.px(x + 1, y, PINE[1])
    rope.paste(bh.inked(strand.im), -1, -1)
    mouth = (cx + 1, y_m + 1)
    return {"name": "OAK HONEY BUCKET", "bail": rope.im, "body": body_im,
            "front": _front_layer(body_im, mouth, (inner[0] + 1, inner[1] + 1)),
            "mouth": mouth, "inner": inner, "foot": (cx + 1, y_f + hy_f + 1),
            "foot_half": (hx_m - 1.0, hy_f), "deep": 8.0, "left": 0}


COBALT_BEE = [  # a brush-painted bee: wings up, a round body, two cream stripes, an eye glint
    "....ww.ww....",
    "...w..w..w...",
    "...w..w..w...",
    "....wwwwww...",
    "..bbcbbcbbb..",
    ".bbbcbbcbbbb.",
    "bbbbcbbcbbebb",
    ".bbbcbbcbbbb.",
    "..bbcbbcbbb..",
    "...bbbbbbb...",
]


def crock():
    """C: HONEY CROCK. Paper-cream stoneware with a round belly, its shoulder dipped in cobalt
    (a near-straight dip line with three short runs: nothing on it reads as honey or mud), a
    cobalt band and a cobalt bee painted on the cream, two cobalt lug handles, a thick glazed
    lip, an oak tap low on the front."""
    WD, HT = 78, 74
    cx, y_m, y_f = 38.0, 16.0, 64.0
    hx_m, hy_m, hy_f = 25.0, 7.0, 6.0
    inner = (22.0, 5.3)

    def hw_of(t):
        return 24.5 + 9.0 * math.sin(math.pi * min(1.0, t * 1.05)) ** 0.9 - 1.5 * t

    def glaze_edge(x):
        e = 0.30 + 0.008 * math.sin(x * 0.4)
        for dx, ln in ((19, 0.06), (47, 0.08), (60, 0.05)):
            d = abs(x - dx)
            if d < 2:
                e += ln * (1 - (d / 2.0) ** 2)
        return e

    body = Art(WD, HT)
    CR = [(-0.86, STONE[2]), (-0.66, STONE[3]), (-0.48, STONE[4]), (-0.2, STONE[3]),
          (0.35, STONE[2]), (0.72, STONE[1]), (2.0, STONE[0])]
    GL = [(-0.86, COBALT[2]), (-0.66, COBALT[3]), (-0.46, COBALT[4]), (-0.22, COBALT[3]),
          (0.1, COBALT[2]), (0.5, COBALT[1]), (2.0, COBALT[0])]
    for y in range(HT):
        for x in range(WD):
            s = _shape(cx, y_m, y_f, hw_of, hy_f, x, y)
            if s is None:
                continue
            u, t = s
            hy = hy_m + (hy_f - hy_m) * t
            arc = math.sqrt(max(0.0, 1 - u * u))
            tt = t - hy * arc / (y_f - y_m)
            g = tt < glaze_edge(x)
            c = _band(u, GL if g else CR)
            if not g and tt < glaze_edge(x) + 0.025:
                c = COBALT[1] if u < 0.2 else COBALT[0]    # the glaze's thin dark edge
            yb = y_f + hy_f * arc
            if yb - (y + 0.5) < 2.0:
                c = STONE[1] if u < 0.3 else STONE[0]     # the unglazed foot
            body.px(x, y, c)
    # the glaze's gloss: a short bright streak on the shoulder's lit side
    for i, (dx, dy) in enumerate(((-15, 11), (-14, 10), (-13, 10), (-16, 12), (-12, 9))):
        body.px(int(cx + dx), int(y_m + dy), STONE[4] if i < 3 else COBALT[4])
    # a cobalt band round the belly, and the painted bee on the front left
    for x in range(WD):
        t = 0.72
        u = (x + 0.5 - cx) / hw_of(t)
        if abs(u) < 0.94:
            yb = y_m + t * (y_f - y_m) + (hy_m + (hy_f - hy_m) * t) * math.sqrt(1 - u * u)
            body.px(x, int(yb), BLUE[1] if u < 0.45 else BLUE[0])
            body.px(x, int(yb) + 2, BLUE[1] if u < 0.45 else BLUE[0])
    bx, by = int(cx - 12), int(y_m + 0.5 * (y_f - y_m))       # on the cream, between drips
    for j, row in enumerate(COBALT_BEE):
        for i, ch in enumerate(row):
            c = {"b": BLUE[0], "c": STONE[3], "w": BLUE[1], "e": STONE[4]}.get(ch)
            if c is not None:
                body.px(bx + i, by + j, c)
    for dx, dy in ((-3, 6), (-6, 5), (-9, 6), (-12, 7)):
        body.px(bx + dx, by + dy, BLUE[1])
    # the lug handles on the shoulders
    for sgn in (-1, 1):
        t = 0.2
        hxx = hw_of(t)
        lx = int(cx + sgn * hxx) + (0 if sgn > 0 else -4)
        ly = int(y_m + t * (y_f - y_m))
        for dy in range(0, 8):
            for dx in range(0, 4):
                if dy in (0, 7) or dx == (3 if sgn > 0 else 0):
                    body.px(lx + dx, ly + dy, COBALT[3] if dy < 3 and sgn < 0 else COBALT[2])
    _rim_and_mouth(body, cx, y_m, (hx_m, hy_m), inner, COBALT[2], COBALT[4], COBALT[3],
                   COBALT[2], (COBALT[0], COBALT[0]), COBALT[0], COBALT[1], COBALT[2])
    body_im = bh.inked(body.im)
    # the oak tap low on the front: a bung, a peg, a spout
    tx, ty_ = int(cx + 10), int(y_f - 12)
    tap = Art(11, 12)
    tap.rect(1, 3, 7, 5, OAK[4])
    tap.rect(1, 3, 7, 1, OAK[6])
    tap.rect(1, 7, 7, 1, OAK[3])
    tap.rect(7, 4, 2, 3, OAK[5])
    tap.px(8, 5, OAK[2])
    tap.rect(3, 0, 2, 3, OAK[5])
    tap.px(3, 0, OAK[6])
    tap.rect(5, 8, 3, 3, OAK[3])
    tap.px(6, 10, OAK[1])
    body_im.alpha_composite(bh.inked(tap.im), (tx, ty_))
    mouth = (cx + 1, y_m + 1)
    return {"name": "HONEY CROCK", "bail": None, "body": body_im,
            "front": _front_layer(body_im, mouth, (inner[0] + 1, inner[1] + 1)),
            "mouth": mouth, "inner": inner, "foot": (cx + 1, y_f + hy_f + 1),
            "foot_half": (hw_of(1.0), hy_f), "deep": 7.0, "left": 0}


BUCKETS = {"A": pail, "B": oak_bucket, "C": crock}


def draw_pool(a, mouth, inner, deep, level, land_x, stream_w):
    """The honey inside, clipped to the mouth: the surface WALL_SHOWN px under the rim, so a band
    of the inside wall shows between its far edge and the far rim (it reads part full, not
    brimming); its far edge lit, a step darker under the near rim's shadow, a shine streak; where
    the stream lands a lit mound two rows high and one stepped ring opening from it."""
    mx, my = mouth
    hx, hy = inner[0] - 0.5, inner[1] - 0.3
    sy = my + WALL_SHOWN

    def on(x, y):
        return _in_ell(x, y, mx, my, hx, hy) and _in_ell(x, y, mx, sy, hx, hy)

    for y in range(int(my - hy - 2), int(my + hy + 3)):
        for x in range(int(mx - hx - 2), int(mx + hx + 3)):
            if not on(x, y):
                continue
            c = HONEY["base"]
            if not on(x, y - 1):
                c = HONEY["light"]
            elif not on(x, y - 2):
                c = HONEY["light"] if (x + y) % 2 == 0 else HONEY["base"]
            if not _in_ell(x, y + 1, mx, my, hx, hy):
                c = HONEY["mid"]                   # the near rim's shadow on the honey
            if not (on(x - 1, y) and on(x + 1, y)):
                c = HONEY["deep"]                  # where it meets the wall
            a.px(x, y, c)
    # the sun's streak on the surface, left of middle
    s_y = int(sy - hy * 0.05)
    for x in range(int(mx - hx * 0.66), int(mx - hx * 0.3)):
        if on(x, s_y) and on(x, s_y + 1) and abs(x - land_x) > stream_w + 5:
            a.px(x, s_y, HONEY["shine"])
    # where the stream lands: one stepped ring (lit on its far half, a step darker on its near
    # half), then the mound over it, lit on top
    ly = int(sy + hy * 0.15)
    r = stream_w + 4.5
    for i in range(96):
        ang = 2 * math.pi * i / 96
        x = int(math.floor(land_x + math.cos(ang) * r))
        y = int(math.floor(ly + 0.5 + math.sin(ang) * r * 0.34))
        if on(x, y):
            a.px(x, y, HONEY["shine"] if math.sin(ang) < 0 else HONEY["mid"])
    w = int(stream_w)
    for dx in range(-w - 1, w + 2):
        x = int(land_x) + dx
        if on(x, ly):
            a.px(x, ly, HONEY["light"] if abs(dx) <= w - 1 else HONEY["base"])
        if on(x, ly - 1) and abs(dx) <= w - 1:
            a.px(x, ly - 1, HONEY["shine"] if abs(dx) <= 1 else HONEY["light"])
        if on(x, ly + 1) and abs(dx) <= w:
            a.px(x, ly + 1, HONEY["mid"])
    return ly


def draw_stream(a, top, bottom_y, wtop=5.0, ws=3.5):
    """The stream off the spout: fat where it leaves, necking to its own width, wobbling more
    the further it falls (the game's rope rows)."""
    x0, y0 = top
    fall = max(bottom_y - y0, 4)
    for i in range(int(fall) + 1):
        t = i / fall
        w = ws + (wtop - ws) * math.exp(-i / 4.0) + math.sin(i * 0.5) * 0.4
        cx = x0 + math.sin(i * 0.13 + 1.0) * 1.0 * t
        rope_row(a, cx, y0 + i, w)


def draw_shadow(a, foot, half):
    """The bucket's shadow on the lawn: a solid core and a 2x2 checkered fringe (the catch box's
    rule), dropped down and to the right: the room's sun is top left (see LIGHT_NOTE)."""
    fx, fy = foot
    cx, cy = fx + 6, fy + 1
    hx, hy = half[0] + 7, half[1] + 3
    for y in range(int(cy - hy - 1), int(cy + hy + 2)):
        for x in range(int(cx - hx - 1), int(cx + hx + 2)):
            if _in_ell(x, y, cx, cy, hx * 0.84, hy * 0.74):
                a.px(x, y, SHADOW)
            elif _in_ell(x, y, cx, cy, hx, hy) and (x + y) % 2 == 0:
                a.px(x, y, SHADOW)


# =============================================================================================
# The hot knife (the same in every option)
# =============================================================================================
BLADE_TIP = 171               # the blade's tip, art px (today's)
BLADE_TOP = 129               # its top outline row; the steel is 130..135, the outline 136
HEEL = 463                    # where the steel meets the bolster


def heat_at(x):
    """How far the heat has climbed off the cutting edge at x, in rows (0 cool .. 4 white-hot):
    a smooth ramp, so each hot row ends at its own column and the hot zone tapers rather than
    stepping in blocks. Hottest along the run the wax rides, cooler near the tip, cooling off
    toward the bolster."""
    if x < BLADE_TIP + 40:
        return 2.2 + 1.6 * (x - BLADE_TIP) / 40.0
    if x < HEEL - 70:
        return 3.8 + 0.4 * math.sin((x - BLADE_TIP) * 0.05)
    return max(0.0, 3.8 * (HEEL - 4 - x) / 66.0)


# the cool blade's rows under its top outline, spine to edge; the heat replaces them from the
# cutting edge up: the edge coin_lit (gold_pale where white-hot), then coin, then a warm steel
HOT_ROWS = [(6, 0.6, SW["coin_lit"]), (5, 1.6, SW["coin"]), (4, 2.6, HEAT["warm"])]
COOL = [S["hi"], S["lit"], S["base"], S["base"], S["shade"], S["deep"]]
GLINT_AT = 238                # where the hot-white glint runs along the edge


def draw_knife(a):
    """A heated uncapping knife: the steel's spine cool and lit, the heat climbing off the cutting
    edge, white-hot along the middle and cooling toward the bolster, a hot-white glint running on
    the edge; a brass bolster with two rivets; a turned oak handle, swelled, two turned rings and
    lengthwise grain; a brass cap and a leather loop."""
    y = BLADE_TOP
    for x in range(BLADE_TIP, HEEL):
        d = x - BLADE_TIP
        h = heat_at(x)
        rows = list(COOL)
        for row, need, c in HOT_ROWS:
            if h >= need:
                rows[row - 1] = c
        if h >= 3.5:
            rows[5] = HEAT["white"]           # white-hot along the middle of the edge
        a.px(x, y, OUT)
        for i, c in enumerate(rows):
            dy = i + 1
            if d < 6 and dy < 7 - d:          # the tip cut back to a point at the edge
                continue
            a.px(x, y + dy, c)
        a.px(x, y + 7, OUT)
        if d < 6:
            a.px(x, y + 7 - d - 1, OUT)
    # the glint: five px of hot white on the edge, gold either end, and a pale dot over it
    for k in range(-3, 4):
        a.px(GLINT_AT + k, y + 6, HEAT["spark"] if abs(k) < 3 else HEAT["white"])
        if abs(k) < 2:
            a.px(GLINT_AT + k, y + 5, HEAT["spark"])
        elif abs(k) < 3:
            a.px(GLINT_AT + k, y + 5, HEAT["white"])
    a.px(GLINT_AT, y + 4, HEAT["white"])
    # the bolster: brass, taller than the blade, two rivets
    bx0, bx1 = HEEL, HEEL + 7
    for x in range(bx0, bx1):
        for yy in range(y - 2, y + 10):
            c = (BRASS["lit"] if yy < y + 1 else BRASS["base"] if yy < y + 6 else BRASS["shade"]
                 if yy < y + 8 else BRASS["deep"])
            if x == bx1 - 1:
                c = BRASS["shade"] if yy < y + 6 else BRASS["deep"]
            if x == bx0 and yy < y + 6:
                c = BRASS["pale"] if yy < y + 1 else BRASS["lit"]
            a.px(x, yy, c)
    for yy in (y + 2, y + 6):
        a.px(bx0 + 3, yy, BRASS["deep"])
        a.px(bx0 + 2, yy - 1, BRASS["pale"])
    # the handle: turned oak, swelled in the middle, waisted at each end
    hx0, hx1 = bx1, bx1 + 38
    mid = y + 4.0
    rings = (hx0 + 9, hx1 - 8)
    for x in range(hx0, hx1):
        t = (x - hx0) / (hx1 - hx0 - 1)
        half = 4.6 + 2.0 * math.sin(t * math.pi) ** 0.8
        top = int(round(mid - half))
        bot = int(round(mid + half))
        for yy in range(top, bot + 1):
            v = (yy - top) / max(1, bot - top)
            c = (OAK[6] if v < 0.14 else OAK[5] if v < 0.36 else OAK[4] if v < 0.68 else OAK[3]
                 if v < 0.88 else OAK[2])
            if c in (OAK[5], OAK[4]) and hsh(x // 4, yy, 21) < 0.16:
                c = OAK[3]                                    # grain along the handle
            if x in rings:
                c = OAK[2] if v > 0.1 else OAK[3]             # a turned groove
            elif x - 1 in rings:
                c = OAK[6] if v < 0.5 else OAK[5]             # its lit lip
            a.px(x, yy, c)
    # the brass end cap and its hanging loop
    cx0 = hx1
    for x in range(cx0, cx0 + 3):
        for yy in range(int(mid) - 4, int(mid) + 5):
            a.px(x, yy, BRASS["lit"] if yy < mid - 1 else BRASS["base"] if yy < mid + 2
                 else BRASS["shade"])
    loop = [(cx0 + 3, int(mid)), (cx0 + 5, int(mid) + 2), (cx0 + 6, int(mid) + 6),
            (cx0 + 4, int(mid) + 9), (cx0 + 1, int(mid) + 8), (cx0 + 1, int(mid) + 5)]
    return loop


# three sparks rising off the hot edge where the wax sheet ends and the comb shows over the
# blade: (x, y of the spark, its trail's length), each a hot-white pixel over a gold trail
SPARKS = [(437, BLADE_TOP - 5, 2), (445, BLADE_TOP - 9, 3), (452, BLADE_TOP - 4, 1)]


def draw_sparks(a):
    """Each spark a hot-white pixel with pale gold round it (a four-point star with two-px arms
    for the biggest), its trail a gold pixel or two under it; no outline, so they read as light
    on the comb, not as pills."""
    for k, (x, y, n) in enumerate(SPARKS):
        a.px(x, y, HEAT["spark"])
        arms = 2 if k == 1 else 1
        for r in range(1, arms + 1):
            c = SW["coin_pale"] if r == 1 else SW["coin_lit"]
            for dx, dy in ((r, 0), (-r, 0), (0, -r)):
                a.px(x + dx, y + dy, c)
        for j in range(1, n + 1):
            a.px(x, y + j, SW["coin_pale"] if j == 1 else SW["coin_lit"])


def warm_halo(lay, base_art):
    """The wax riding the blade warms where it meets the hot steel: its bottom row over the
    blade's top outline, only where it is wax and only over the hot run, a step toward gold."""
    y = BLADE_TOP - 1
    n = 0
    for x in range(BLADE_TIP + 6, HEEL):
        if heat_at(x) < 3:
            continue
        c = tuple(int(v) for v in base_art[y, x, :3])
        if c[0] > 200 and c[1] > 170 and c[2] > 100 and c[0] - c[2] < 110:   # the wax's creams
            lay.px(x, y, mix(_c(c), SW["coin"], 0.7))
            n += 1
    return n


def draw_loop(a, loop):
    for (x0, y0), (x1, y1) in zip(loop, loop[1:]):
        a.line([(x0, y0), (x1, y1)], OUT, 3)
    for (x0, y0), (x1, y1) in zip(loop, loop[1:]):
        a.line([(x0, y0), (x1, y1)], LEATHER["base"])
    for x0, y0 in loop[1:3]:
        a.px(x0, y0, LEATHER["lit"])


def wax_curl():
    """The capping peeling up off the blade's tip: an open ribbon of wax three px thick that
    leaves the sheet on the blade at its right, rises, arches over to the left and comes down
    a little way, its free end OPEN, the comb showing through the arch (nothing dark inside).
    Its outer edge is lit on the top left, its middle the wax, its inner edge the capping's
    underside with the cells' dots on it; a drop of honey hangs off the free end on a thread."""
    im = Art(22, 24)
    cx, cy, R = 10.5, 10.0, 5.8
    A0, A1 = math.radians(-14), math.radians(212)
    for y in range(22):
        for x in range(22):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            th = math.atan2(-dy, dx)                       # y up
            if th < A0 - 0.01:
                th += 2 * math.pi
            if not (A0 <= th <= A1):
                continue
            d = r - R
            if not (-1.6 <= d < 1.5):
                continue
            nx, ny = dx / (r + 1e-6), dy / (r + 1e-6)
            lit = -0.7 * nx - 0.7 * ny                     # the outward normal against the sun
            if d >= 0.5:                                    # the outer face
                c = WAX["gloss"] if lit > 0.35 else WAX["lit"] if lit > -0.25 else WAX["base"]
            elif d >= -0.5:                                 # the strip's body
                c = WAX["lit"] if lit > 0.3 else WAX["base"]
            else:                                           # the underside: the cells' dots
                c = WAX["base"] if (x * 2 + y * 3) % 5 else WAX["shade"]
                if lit < -0.5:
                    c = WAX["shade"]
            im.px(x, y, c)
    # the strip runs on down and to the right into the sheet on the blade
    for x, y, c in ((16, 12, "lit"), (17, 12, "gloss"), (16, 13, "base"), (17, 13, "base"),
                    (18, 13, "lit"), (17, 14, "base"), (18, 14, "base"), (19, 14, "lit"),
                    (16, 14, "shade"), (18, 15, "shade"), (19, 15, "base"), (20, 15, "base")):
        im.px(x, y, WAX[c])
    # the honey thread and drop off the free end
    fx = int(math.floor(cx + R * math.cos(A1)))
    fy = int(math.floor(cy - R * math.sin(A1))) + 1
    im.px(fx, fy + 1, HONEY["base"])
    im.px(fx, fy + 2, HONEY["mid"])
    drop = [".L.", "LSH", "HHM", ".M."]
    look.grid(drop, {"L": HONEY["light"], "S": HONEY["shine"], "H": HONEY["base"],
                     "M": HONEY["mid"]}, fx - 1, fy + 3, into=im.im)
    return bh.inked(im.im)


# =============================================================================================
# One option on the plate
# =============================================================================================
BUCKET_BOTTOM = 348           # the bucket's lowest row on the lawn, art px
LEG_CLEAR = 516               # nothing of the bucket over row 290 left of this: the rest's leg
LEVEL = 0.8                   # how full the bucket is in the picture
WALL_SHOWN = 3.0              # px of the inside wall between the honey and the far rim


def _opaque_cols(im, y_to):
    a = im.getchannel("A").crop((0, 0, im.width, max(1, y_to))).getbbox()
    return a


def place_bucket(b):
    """Where the bucket stands: its foot on BUCKET_BOTTOM, pushed right until nothing of it above
    the leg's foot (row 290) is left of LEG_CLEAR, so the rest's leg stands clear beside it."""
    by = int(BUCKET_BOTTOM - b["body"].height + 1)
    rows = max(1, 290 - by)
    bb = _opaque_cols(b["body"], rows)
    left = bb[0] if bb else 0
    if b["bail"] is not None:
        bb2 = _opaque_cols(b["bail"], rows + 1)
        if bb2:
            left = min(left, bb2[0] - 1)
    bx = LEG_CLEAR - left
    return bx, by


def render(option, base, kept, ctx):
    """The option drawn on the clean view: (the full-size picture, the boxes of interest in
    plate px, the bucket's name)."""
    lay = Art(W, H)
    _STYLE[0] = option
    b = BUCKETS[option]()
    bx, by = place_bucket(b)
    mouth = (b["mouth"][0] + bx, b["mouth"][1] + by)
    foot = (b["foot"][0] + bx, b["foot"][1] + by)
    # the stream lands a little left of the mouth's middle; the trough runs on to meet it
    land_x = int(round(mouth[0] - b["inner"][0] * 0.42))
    x1 = land_x - END_STREAM[option][0]
    # shadows on the lawn first: the trough's strip under the rest, the bucket's
    draw_trough_shadow(lay, option, x1, ctx["blocked"])
    draw_shadow(lay, foot, b["foot_half"])
    # the trough: the hangers' upper halves behind it, its far lip and inside, the honey, the
    # curtains sinking into it, the near rim and face, the curtains' bulges over the rim, an
    # overspill, the hangers' lower halves round its face
    draw_hangers_back(lay, option)
    draw_trough_back(lay, option, x1)
    draw_trough_honey(lay, x1)
    landed = draw_curtains(lay, kept)
    draw_trough_front(lay, option, x1)
    draw_bulges(lay, option, landed)
    draw_spill(lay, option)
    draw_hangers_front(lay, option)
    # the bucket's bail or rope handle, laid back behind the mouth; the trough's low end and the
    # honey leaving it in front of it; then the bucket, its honey, the stream, its near wall
    if b["bail"] is not None:
        lay.paste(b["bail"], bx - 1, by - 1)
    (sx, sy0), sw = draw_low_end(lay, option, x1)
    lay.paste(b["body"], bx, by)
    ly = draw_pool(lay, mouth, b["inner"], b["deep"], LEVEL, sx, 2.5)
    draw_stream(lay, (sx, sy0), ly, wtop=sw, ws=3.4)
    lay.paste(b["front"], bx, by)
    # the knife, its sparks, the warm wax over it, and the wax curl
    loop = draw_knife(lay)
    draw_loop(lay, loop)
    _outline_box(lay, HEEL - 1, BLADE_TOP - 4, HEEL + 52, BLADE_TOP + 22)
    warm_halo(lay, ctx["base_art"])
    draw_sparks(lay)
    lay.paste(wax_curl(), BLADE_TIP - 6, BLADE_TOP - 16)
    pic = base.copy()
    look.place(pic, lay.im, (0, 0), G)
    if BED_LAYER:
        # the bed's flowers nearer than the bucket (their pixels below its foot) stand in front
        layer = BED_LAYER[0]
        near = Image.new("RGBA", layer.size, CLEAR)
        fy = int(foot[1]) - 2
        x0 = bx - 4
        x1b = bx + b["body"].width + 4
        box = (x0, fy, x1b, layer.height)
        near.paste(layer.crop(box), box[:2])
        look.place_art(pic, near, (0, 0), G)
    # bees drawn to the honey: one sipping on the bucket's rim, one at the trough's low end, one
    # hovering at a curtain; and a few flying over the scene
    rim_x = int(mouth[0] - b["inner"][0] + 3)
    rim_y = int(mouth[1] + b["inner"][1] * 0.55) - 3
    px_, py_, left = sip_spot(option, x1)
    for (x, y, lf, frame) in ((rim_x, rim_y, False, 1), (px_, py_ - 3, left, 0)):
        im = look.bee(BEE, frame, facing_left=lf, pose="rest")
        look.place(pic, im, look.art_px((x, y)), G, anchor=look.bee_anchor(BEE, "rest", lf, frame))
    hx, hy = HOVER_AT
    im = look.bee(BEE, 1, facing_left=True, pose="hover")
    look.place(pic, im, look.art_px((hx, hy)), G, anchor=look.bee_anchor(BEE, "hover", True, 1))
    for (x, y, f, lf) in FLYERS:
        im = look.bee(BEE, f, facing_left=lf, pose="fly")
        look.place(pic, im, look.art_px((x, y)), G, anchor=look.bee_anchor(BEE, "fly", lf, f))
    t1 = ty(x1)
    boxes = {
        "bucket": (int((bx - 14) * G), int((by - 6) * G), int((bx + b["body"].width + 10) * G),
                   int((by + b["body"].height + 6) * G)),
        "pour": (int((x1 - 48) * G), int((t1 - 22) * G), int((x1 + 22) * G), int((t1 + 32) * G)),
        "curtain": (int((CURTAINS[3] - 32) * G), int((FRAME_FOOT - 26) * G),
                    int((CURTAINS[3] + 30) * G), int((ty(CURTAINS[3]) + 14) * G)),
        "knife": (int((HEEL - 34) * G), int((BLADE_TOP - 14) * G), int((HEEL + 56) * G),
                  int((BLADE_TOP + 22) * G)),
        "tip": (int((BLADE_TIP - 14) * G), int((BLADE_TOP - 22) * G), int((BLADE_TIP + 40) * G),
                int((BLADE_TOP + 13) * G)),
        "section": (int(300 * G), int((FRAME_FOOT - 2) * G), int(372 * G),
                    int((ty(372) + 14) * G)),
        "low": (int((x1 - 60) * G), int((t1 - 30) * G), int((bx + b["body"].width + 10) * G),
                int((BUCKET_BOTTOM + 8) * G)),
        "strip": (int((X0 - 12) * G), int((FRAME_FOOT - 6) * G), int(600 * G),
                  int((BUCKET_BOTTOM + 8) * G)),
    }
    return pic, boxes, b["name"]


HOVER_AT = (354, 200)         # a bee hovering at the fourth curtain, facing it
FLYERS = [(92, 236, 3, False), (560, 92, 2, True), (612, 268, 0, True), (402, 300, 4, False),
          (120, 172, 1, False)]


# =============================================================================================
# The backdrop: the uncap plate with today's step off it (uncap_clean), then below the sky the
# backdrop sheet's recommended look (the far bank re-laid, the lake redrawn with nothing on it,
# the lawn redrawn, its veil, its flower bed and the bees at it), then the step's own work (the
# rest, the frame, the curtains, the UI) put back over it from the plate.
# =============================================================================================
BACKDROP_NOTE = []
BED_LAYER = []                # the bed's own art layer, to lay the near flowers back over a bucket


def compose_base():
    import numpy as np
    base, art, rem, kept = uncap_clean.clean()
    rest_a, _ = uncap_clean._piece_alpha("rest", uncap_clean.REST_AT)
    fo_a, _ = uncap_clean._piece_alpha("frame_open", uncap_clean.FRAME_AT)
    fc_a, _ = uncap_clean._piece_alpha("frame_capped", uncap_clean.FRAME_AT)
    rows = np.arange(H)[:, None]
    fore = rest_a | (fo_a & (rows < uncap_clean.CUT_ROW)) | (fc_a & (rows >= uncap_clean.CUT_ROW))
    work = fore | kept
    for x0, y0, x1, y1 in uncap_clean.UI:
        work[y0:y1, x0:x1] = True
    blocked = fore.copy()
    blocked[1:] |= fore[:-1]
    blocked[:-1] |= fore[1:]
    blocked[:, 1:] |= fore[:, :-1]
    blocked[:, :-1] |= fore[:, 1:]
    out = base
    try:
        import backdrop_mockup as bm
        opt = bm.RECOMMEND
        entry = bm.OPTIONS[opt]               # its layout has changed between passes: read it
        title, bed = entry[0], entry[1]       # by kind, not by place
        plan = next(v for v in entry[2:] if isinstance(v, list))
        veil = next((v for v in entry[2:] if isinstance(v, float)),
                    getattr(bm, "SCENE_VEIL", 0.6))
        plate = np.array(look.plate("uncap"))
        ink = bm.fit_ink(plate)
        sky = bm.clean_sky(base.copy(), "uncap")
        view = np.array(sky)
        bank, trees = bm.render_bank(plate, ink, view.copy())
        view[bm.BANK_TOP:bm.LAKE_FAR, :, :3] = bank
        state = getattr(bm, "CHECK", {}).get("uncap", {}).get(
            "state", bm.STATES_SHOWN.get("pour", 1))
        view[bm.LAKE_FAR:bm.LAKE_NEAR, :, :3] = bm.render_lake(
            state, ink, streak_share=0.7 * (1.0 - 0.5 * (veil > 0)))
        view[bm.LAKE_NEAR:, :, :3] = bm.render_lawn(ink)
        view[..., 3] = 255
        if veil > 0:
            bm.apply_veil(view, veil, trees)
        import inspect
        res = bm.lay_bed(view, bed())
        spots, sil = (res[0], res[1]) if isinstance(res, tuple) else (res, None)
        if isinstance(res, tuple) and len(res) > 2:
            BED_LAYER[:] = [res[2]]
        img = Image.fromarray(view)
        used = []
        takes_sil = "sil" in inspect.signature(bm.bees_at_bed).parameters
        for k, part in enumerate(bm._halves(spots)):
            if takes_sil:
                bm.bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
            else:
                bm.bees_at_bed(img, part, plan, seed=5 + 4 * k)
        va = np.array(img)
        ba = np.array(base)
        m = np.repeat(np.repeat(work, G, 0), G, 1)
        va[m] = ba[m]
        out = Image.fromarray(va)
        BACKDROP_NOTE[:] = ["the backdrop sheet's %s (%s, veil %.1f, lake %s): no rubbish, no "
                            "piers' signs, no ferries, no dogs" % (opt, title.lower(), veil,
                                                                   bm.STATES[state])]
    except Exception as e:                     # the backdrop sheet is its own work: carry on
        import traceback
        traceback.print_exc()
        print("backdrop sheet not borrowed:", repr(e))
        BACKDROP_NOTE[:] = ["today's view retouched (the backdrop sheet was not there to "
                            "borrow); the backdrop is the backdrop sheet's job"]
    base_art = np.array(look.downsample(out))
    return out, kept, {"blocked": blocked, "base_art": base_art}


CAPTIONS = {
    "A": "GALVANISED PAIL under a deep riveted tin U-trough on iron cradles: the one cool, bright "
         "object in a warm scene, so the honey glows in both and reads first.",
    "B": "OAK HONEY BUCKET under an oak V-flume slung on rope: all one carpentry, the warmest and "
         "cosiest, and the bright honey sits well on the dark oak.",
    "C": "HONEY CROCK under a copper half-round eaves gutter on wire hangers: the most "
         "characterful, cobalt and cream under copper, but the heaviest to carry to the table.",
}
DETAILS = {
    "A": "Pail: STEEL tin, a few big flat zinc spangles on its lit side, a rolled rim, two pressed "
         "ribs, a dark foot ring; riveted ears, the wire bail dropped back flat behind the far "
         "rim with its short oak grip resting on it; a brass gate (a boss, a 3-px nozzle, a "
         "1-px lever) shut low on the front. Trough: a deep U, seen from above: a 1-px lit far "
         "lip, four rows of dark inside wall, five of honey, a bright rolled bead, then a FLAT "
         "face (one tone and one dark bottom edge) with lap seams and rivets; iron strap cradles "
         "bolted to the frame's foot, behind the trough and round under it to a bolt under the "
         "bead; its low end an end plate and a beak pressed in the rim.",
    "B": "Bucket: nine coopered staves in the hut's oak with seams, lit edges and grain, a hint of "
         "a belly, two iron hoops with rivets, the staves' end grain round the mouth, two tall "
         "ears with a pine rope handle laid back, a brass tap shut low. Flume: two oak boards "
         "nailed in a V, seen from above: the back board's lit arris and end grain, its broad "
         "inner face (grain) down to a dark crease, the front board's lit top edge, its outer "
         "face with nails and a butt joint; slung on pine rope, a knot round the frame's foot, "
         "the back strand behind it and the front strand over the honey and round under the "
         "keel; its open end lets the honey roll off between the boards' end grain.",
    "C": "Crock: paper-cream stoneware, its shoulder dipped in cobalt on a near-straight line with "
         "three short runs, a gloss streak, a cobalt band and a cobalt bee with a dotted path, "
         "cobalt lugs and lip, an oak tap. Gutter: copper (the pots' clay ramp): a tall back "
         "flange standing four rows over the honey, a fat round bead, a short rounded belly with "
         "one dark core line, soldered seams; one solid steel wire a hanger, a single hook over "
         "the frame's foot, clipped to the bead and round under the belly; its low end capped, "
         "a short round outlet under the belly.",
}

KNIFE_NOTE = ("The hot knife, the same in all three: the spine stays cool lit steel and the heat "
              "climbs off the cutting edge, white-hot (gold_pale) through gold and coral, hottest "
              "along the run the wax rides and cooling toward the bolster; a 7-px hot-white glint "
              "on the edge; three sparks rising off it where the comb shows; the wax over it warm "
              "where it meets the steel; a brass bolster, a turned oak handle, a brass cap, a "
              "leather loop. The capping peels up off the tip as an open ribbon arching over, the "
              "comb showing through the arch (no dark centre), a drop of honey off its free end.")

LIGHT_NOTE = ("CONTRADICTION, for Richard: the brief puts the hive room's sun top left (its "
              "clouds are lit that way), and every piece here is lit from the left. But the game "
              "drops the hive room's contact shadows down and to the LEFT (One Sun: the hive "
              "steps take Shade.drop, and the catch box's shadow falls down-left), which wants a "
              "sun on the right. This sheet follows the brief, as the pour sheet does: shadows "
              "fall down and to the right. Which is authoritative? If Shade.drop stays, the "
              "buckets, trough and knife want lighting from the right instead.")


# =============================================================================================
# The sheet
# =============================================================================================
def option_body(option, base, kept, ctx):
    pic, boxes, name = render(option, base, kept, ctx)
    marked = pic.copy()
    zb = look.crop_zoom(pic, boxes["bucket"], 3, marked)
    zp = look.crop_zoom(pic, boxes["pour"], 3, marked)
    zc = look.crop_zoom(pic, boxes["curtain"], 3, marked)
    zk = look.crop_zoom(pic, boxes["knife"], 3, marked)
    zt = look.crop_zoom(pic, boxes["tip"], 4, marked)
    real = panel(marked, "real scale on the uncap capture (3 screen px an art px); pink boxes "
                         "are the zooms")
    top = stack([real, panel(zb, "3x: the " + name.lower())], "h", 14)
    zooms = [panel(zp, "3x: the trough's low end, the pour, a bee sipping"),
             panel(zc, "3x: a curtain into the trough, its bulge, a hanger, a bee at it"),
             panel(zk, "3x: the knife's heel, sparks (same in A/B/C)"),
             panel(zt, "4x: the blade's tip and the wax ribbon")]
    body = stack([top, flow(zooms, top.width, 14),
                  look.text_block(DETAILS[option], top.width, 17, "text", look.INK_SOFT)], "v", 14)
    return body, name, pic, boxes


def today_panel():
    pl = look.plate("uncap")
    marked = pl.copy()
    z1 = look.crop_zoom(pl, (1350, 840, 1710, 1080), 2, marked)
    z2 = look.crop_zoom(pl, (1200, 640, 1560, 840), 2, marked)
    z3 = look.crop_zoom(pl, (430, 330, 640, 450), 3, marked)
    small = marked.resize((960, 540), Image.BOX)
    return stack([panel(small, "today (half size): a mint tub off the palette and cut off by the "
                               "window, the gutter a steel pipe, a dog behind it"),
                  stack([panel(z1, "2x: the tub"), panel(z2, "2x: the pipe and its lip"),
                         panel(z3, "3x: the donut curl")], "h", 14)], "h", 14)


def compare_panel(rendered):
    """The three side by side: the trough and the bucket at REAL scale (no zoom: this is the read
    that matters), the bucket and the trough's low end at 2x, and the same stretch of trough (a
    hanger, the honey, a curtain landing) at 4x."""
    reals, lows, secs = [], [], []
    for o in ("A", "B", "C"):
        pic, boxes, name = rendered[o]
        reals.append(panel(pic.crop(boxes["strip"]), o + "  " + name + ", 1x"))
        lows.append(panel(look.zoom(pic.crop(boxes["low"]), 2), o + "  " + name + ", 2x"))
        secs.append(panel(look.zoom(pic.crop(boxes["section"]), 4), o + "  trough, 4x"))
    return panel(stack([stack(reals, "h", 18), stack(lows, "h", 18), stack(secs, "h", 18)],
                       "v", 16),
                 "the three side by side, same lawn, same light: first at real scale")


def swatches():
    rows = []
    for name, ramp, how in RAMPS:
        cells = [Image.new("RGBA", (30, 30), c) for c in ramp.values()]
        rows.append(stack([look.text_block(name, 80, 16, "bold"), stack(cells, "h", 2),
                           look.text_block(how, 520, 14, "text", look.INK_SOFT)], "h", 10,
                          align="center"))
    return panel(stack(rows, "v", 6), "every new colour: an in-game ramp, a swatch, or a mix")


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    base, kept, ctx = compose_base()
    base.save(os.path.join(SCRATCH, "uncap_base.png"))
    rendered, opts = {}, []
    for o in ("A", "B", "C"):
        body, name, pic, boxes = option_body(o, base, kept, ctx)
        rendered[o] = (pic, boxes, name)
        pic.save(os.path.join(SCRATCH, "uncap_%s.png" % o))
        opts.append(look.option_block(o, name, CAPTIONS[o], body, recommended=(o == RECOMMEND)))
    head = stack([today_panel(), swatches()], "h", 24)
    notes = (LIGHT_NOTE + " " + KNIFE_NOTE + " Every option drops the trough three px under "
             "today's line (a gap under the frame's foot) and runs its low end on past the rest's "
             "right leg; the trough throws a thin strip of shadow on the lawn under the rest, and "
             "the bucket stands whole on the lawn (its foot on art row 348 of 360) clear of the "
             "leg and the hint card. The buckets keep their names on the pour sheet. Backdrop: "
             + "; ".join(BACKDROP_NOTE) + ". Bees are the bee sheet's A (coin), every one.")
    look.sheet("UNCAP: THE BUCKET, THE TROUGH AND THE HOT KNIFE",
               [head, compare_panel(rendered)] + opts, OUT_PATH,
               subtitle="Richard's brief (2026-10-16): a bucket that belongs to the palette, whole "
                        "in frame on the grass with a shadow, its honey visible; the gutter an "
                        "open trough with a rolled rim and straps; a nicer hot knife; the "
                        "curtains kept. Drawn on the real capture at the room's grain. Second "
                        "pass after the art director's review: three different troughs, U-cradle "
                        "hangers, one light, a clean backdrop.",
               notes=notes)
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

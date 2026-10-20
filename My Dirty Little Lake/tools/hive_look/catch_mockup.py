#!/usr/bin/env python
"""The catch sheet (2026-10-16, the hive's visual overhaul): the catch step redrawn, A / B / C.

Writes tools/hive_look/last_catch.png. OFFLINE MOCKUP: nothing here is read by the game.

What is redesigned, per Richard's critique of today's step (tools/last_hive_room_catch.png):
the box was a flat blue cube with five progress pips that looked like UI buttons stuck on its
front; the swarm clumps in the sky read as scattered debris; the dragged clump was grey-brown
speckle. Each option is a real nucleus box in the hive's sky blue (build_hive PAINTS["sky"],
all four steps as stepped bands: a proud rim band with its shadow under it, two bevelled boards,
a proud plinth; box joints with the pine end grain at the corners, paint worn at the ends), lid
off and the five frame top bars showing, standing in the lawn with its shadow and a hem of
blades. Two carcasses: front-on (A, B; the paint dithers a step darker towards the shaded right)
and turned a few degrees (C; a shaded side face with a cut hand-hold). The swarm is clumps of
about fourteen of look's bee (variant A on every sheet), a bee's width apart, soft brown lines
where two touch and one ink outline round the clump. Each option counts once:

  A  bees on the frames  every clump poured in settles on the next frame: its own crowd on the
                    bar, one half down the gap, stripes glimpsed in the gaps below; at 3-5 they
                    spill onto the bar ends and the rim. A raised pine cleat is its handle. Lit:
                    the gaps glow honey-warm and two bees fan on the landing board.
  B  the window     an observation window with glass (a streak of light, bees behind it a step
                    duller), three bees more on the comb a clump; the bars stay bare. Lit: warm
                    light stands up out of the mouth and the comb glows.
  C  carved flight  five bees carved into the front (shaded as recesses under the top-left sun)
                    fill with honey a clump at a time; two bar bees the same at every count.
                    Lit: the rim goes gold, a star at each corner and one chasing, gaps dark.

All three share the sky (five clumps at the step's homes, the middle one 8 art px lower, ten
loose bees), the clump in hand strung out behind the pointer and balled up round it when held
still, the pour (a curtain of bees diving head first between the frames, two veering off), a
guard bee on the landing board, and the hardware cursor drawn over every bee.

Everything is drawn at the room's grain, 3 screen px an art px, on the plate's lattice, over the
backdrop sheet's recommended view of the catch plate (backdrop_mockup.py, imported, not
edited): no rubbish, ferry or dog, its bed of flowers and their bees, today's prompt card lifted
back.

Light, per the brief: the hive room's sun is top-left (its clouds are lit that way), so the
box's top and left arris are lit, its right side in shade, its shadow falls down-right.

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/catch_mockup.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
from look import ROOM_GRAIN as G, zoom, place, panel, stack, flow  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402
import numpy as np  # noqa: E402

bh = look.bh
OUT_PATH = os.path.join(look.HERE, "last_catch.png")
SCRATCH = os.path.join(look.HERE, "_scratch")
BEE = "A"                 # look's recommended bee, the same on every sheet
RECOMMEND = "A"
SHEET_WIDE = 2440

# =============================================================================================
# The plate: the backdrop sheet's recommended view
# =============================================================================================
# The catch is drawn on the room's new backdrop, not on a retouched capture: the backdrop sheet
# (backdrop_mockup.py, read, never edited) redraws the far bank, the lake and the lawn from
# WashBackdrop's own strips with nothing on them, scrubs today's bees off the plate's sky and
# lays its recommended bed of flowers along the foot with look's bees working it. What it
# leaves of today's step is lifted back: the prompt card. The step board and the close cross
# are the plate's own pixels in its view.
import backdrop_mockup as bd  # noqa: E402

# Where the backdrop's scrub of today's two sky clumps left a cloud stretched along its rows
# (art cells: rows, and the cut's left edge per row, to the right edge): put back to open sky.
# The big cloud by the right-hand clump gets a stepped bottom-right corner (its own was under
# the bees); the one over the treeline loses the square shelf the scrub added to it.
SKY_FIX = [
    ((92, 121), lambda r: max(528, 548 - max(0, int(round((r - 96) * 1.15)))), 581),
    ((110, 122), lambda r: 416 - (r - 110) // 2, 427),
]


def _is_sky(v):
    """The open sky's own blues (not a cloud's white or its blue-grey shade, not a crown)."""
    r, g, b = int(v[0]), int(v[1]), int(v[2])
    return b - g <= 28 and g - r >= 28 and r < 200


def _fix_sky(img):
    """Each cell in SKY_FIX is refilled from the nearest open sky of its own row two cells at a
    time, so the sky's checker dither keeps its phase. Crowns of the far bank are left alone."""
    a = np.array(img)
    cells = a[G // 2::G, G // 2::G, :3].astype(int)
    rows, cols = cells.shape[:2]
    for (r0, r1), left_of, c1 in SKY_FIX:
        for r in range(r0, r1):
            row = cells[r]
            c0 = left_of(r)

            def clean(cc):
                return all(0 <= k < cols and _is_sky(row[k]) for k in (cc - 1, cc, cc + 1))
            for c in range(c0, c1):
                if row[c][1] > row[c][2] or clean(c):
                    continue
                src = None
                for k in range(2, 300, 2):
                    for cc in (c - k, c + k):
                        if not (c0 <= cc < c1) and 0 <= cc < cols and clean(cc):
                            src = cc
                            break
                    if src is not None:
                        break
                if src is not None:
                    a[r * G:(r + 1) * G, c * G:(c + 1) * G, :3] = row[src]
    img.paste(Image.fromarray(a))
    return img


def backdrop():
    """The catch plate's view as the backdrop sheet recommends it: no rubbish, no ferry, no dog,
    the lake dirty as captured under the sheet's veil, its bed and its bees, the prompt card.
    (backdrop_mockup.compose, less its step bees: today's clumps and heap, which this sheet
    redraws, and less every bit of today's step's work but the card.)"""
    opt = bd.RECOMMEND
    _, bed, plan, _ = bd.OPTIONS[opt]
    view, work, _ = bd.clean_view("catch", bd.STATES_SHOWN["catch"], bd.SCENE_VEIL)
    if FIX_SKY:
        _fix_sky(view)
    va = np.array(view)
    spots, sil, _ = bd.lay_bed(va, bed())
    img = Image.fromarray(va)
    used = []
    for k, part in enumerate(bd._halves(spots)):
        bd.bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
    # the prompt card: the step's work the backdrop lifted, inside the card's own rectangle
    wa = np.array(work)
    x0, y0, x1, y1 = bd.CARD["catch"]
    keep = np.zeros(wa.shape[:2], bool)
    keep[y0:y1, x0:x1] = True
    wa[~keep] = 0
    img.alpha_composite(Image.fromarray(wa))
    return img


FIX_SKY = False


def _cells(im):
    return np.array(look.downsample(im, G))[..., :4].copy()


def _paint_back(im, cells):
    """Blow a 1x cell grid back up onto the plate (every cell a whole 3x3 block)."""
    big = Image.fromarray(cells, "RGBA").resize((cells.shape[1] * G, cells.shape[0] * G),
                                                Image.NEAREST)
    im.paste(big, (0, 0))
    return im


_BASE = None


def clean_plate():
    """The backdrop, made once."""
    global _BASE
    if _BASE is None:
        _BASE = backdrop()
    return _BASE.copy()


# =============================================================================================
# Colours: every one an in-game swatch or a mix of two
# =============================================================================================
mix = look.mix
P_LIT, P_BASE, P_SHADE, P_DEEP = bh.PAINTS["sky"]       # the hive's own sky-blue paint
P_SOFT = mix(P_BASE, P_LIT, 0.5)                       # between the lit step and the body
P_GRAIN = mix(P_BASE, P_SHADE, 0.5)                    # between the body and the shade step
P_DUSK = mix(P_SHADE, P_DEEP, 0.5)                     # between the shade and the deep step
P_NIGHT = mix(P_DEEP, look.OUT, 0.4)                   # the bottom of a deep cut
P_RIM_GRAIN = mix(P_LIT, P_BASE, 0.45)
# one step down the paint, for occlusion and for the shaded side face
DOWN = {P_LIT: P_SOFT, P_SOFT: P_BASE, P_BASE: P_GRAIN, P_GRAIN: P_SHADE, P_SHADE: P_DUSK,
        P_DUSK: P_DEEP, P_DEEP: P_NIGHT}
PINE_LIT, PINE, PINE_SHADE, PINE_DEEP = bh.PINE_LIT, bh.PINE, bh.PINE_SHADE, bh.PINE_DEEP
PINE_GRAIN = mix(PINE, PINE_SHADE, 0.6)
DARK, DARKER = bh.WELL_DARK, bh.WELL_DEEPER            # inside the box
HONEY_DEEP, HONEY_MID, HONEY, HONEY_LIGHT, HONEY_SHINE = (
    bh.HONEY_DEEP, bh.HONEY_MID, bh.HONEY, bh.HONEY_LIGHT, bh.HONEY_SHINE)
OUT = look.OUT
SOFT_LINE = look.SW["coin_deep"]                       # where two bees in a clump touch
# the lawn's own tones, measured off the plate (Ground.lawn_shades under the room's DARKEN)
LAWN_ROOT, LAWN_MID, LAWN, LAWN_LIT, LAWN_TIP = (
    (40, 70, 23, 255), (49, 78, 29, 255), (61, 87, 37, 255), (88, 109, 51, 255),
    (138, 153, 84, 255))
SHADOW_INK = (12, 20, 28, 255)
SHADOW_CORE = 0.42
SHADOW_FRINGE = 0.2

# =============================================================================================
# The nucleus box, at one pixel per art pixel
# =============================================================================================
# Two carcasses, compared on the sheet (the counters are interchangeable between them):
#   'front'  front-on in the room's first-person view: the box stands centred under the eye, so
#            neither side wall shows and its top is a trapezoid narrowing towards the horizon.
#   'turned' set down a few degrees off square, so its right-hand side face shows, in shade
#            (the room's sun is top-left), and its top is a parallelogram running back and right.
# Both: lid off, the five frame top bars running back with the dark gaps between them; a proud
# rim band round the top with its shadow under it, two boards, a proud plinth on the grass.
W, H, D, INSET = 114, 50, 17, 9          # front face, top's depth, the top's back inset a side
SIDE = 12                                # 'turned': how far the back is shifted right
MX, MTOP, MBOT = 36, 48, 8
CW, CH = W + 2 * MX, MTOP + D + H + MBOT
OX, OY = MX, MTOP                        # the top's back-left corner (front carcass)
FY0 = OY + D                             # the front face's top row
FY1 = FY0 + H - 1                        # its foot, on the grass
CX = OX + W // 2
BARS = 5
BAR_F = 0.155                            # a bar's share of the inside width, the gaps between
GAP_F = (1.0 - BARS * BAR_F) / (BARS + 1)
FEET_AT = (318, 302)                     # the room's art grid: today's BOX_FEET_AT, kept
FEET = (CX, FY1)                         # the box's own pixel standing on FEET_AT
# the front's bands, rows from FY0
RIM_ROWS = 5                             # the proud rim band
RIM_SHADOW = 2                           # its shadow on the upper board
BOARD_FROM = FY0 + RIM_ROWS + RIM_SHADOW
SEAM = FY0 + 25                          # between the two boards
PLINTH = FY1 - 5                         # the proud plinth, to the foot
BOARD_TO = PLINTH - 1
TAB = 4                                  # the corner finger joints' pitch
CARCASS = {"A": "front", "B": "front", "C": "turned"}
_kind = "front"


def use(opt):
    """Which carcass the geometry below answers for."""
    global _kind
    _kind = CARCASS[opt]


def _top_lr(y):
    t = (y - OY) / float(D - 1)
    if _kind == "turned":
        s = SIDE * (1 - t)
        return int(round(OX + s)), int(round(OX + W - 1 + s))
    return int(round(OX + INSET * (1 - t))), int(round(OX + W - 1 - INSET * (1 - t)))


def _inside(y):
    xl, xr = _top_lr(y)
    return xl + 2, xr - 2


def bar_span(k, y):
    il, ir = _inside(y)
    wide = ir - il + 1
    x0 = il + wide * (GAP_F + k * (BAR_F + GAP_F))
    return int(round(x0)), int(round(x0 + wide * BAR_F)) - 1


def bar_mid(k, y):
    x0, x1 = bar_span(k, y)
    return (x0 + x1) / 2.0


def _gap_span(g, y):
    """The g-th gap between frames on row y (0 and BARS are the ones by the walls)."""
    il, ir = _inside(y)
    x0 = il + 1 if g == 0 else bar_span(g - 1, y)[1] + 1
    x1 = ir - 1 if g == BARS else bar_span(g, y)[0] - 1
    return x0, x1


def _band(y):
    """The front's colour on row y before anything is drawn on it: the rim band (lit along its
    top arris), its shadow on the upper board, each board's bevels (lit on top, shaded at the
    foot), the seam, and the plinth (its top lit, its foot in the grass's shade)."""
    r = y - FY0
    if r < RIM_ROWS:
        return (P_LIT, P_SOFT, P_BASE, P_GRAIN, P_DEEP)[r]
    if y < BOARD_FROM:
        return (P_SHADE, P_GRAIN)[y - FY0 - RIM_ROWS]
    if y == SEAM:
        return P_DEEP
    if y > BOARD_TO:
        return (P_LIT, P_SOFT, P_BASE, P_GRAIN, P_SHADE, P_DEEP)[y - PLINTH]
    b0, b1 = (BOARD_FROM, SEAM - 1) if y < SEAM else (SEAM + 1, BOARD_TO)
    if y == b0 and b0 != BOARD_FROM:
        return P_LIT
    if y == b0 + 1 and b0 != BOARD_FROM:
        return P_SOFT
    if y == b1:
        return P_SHADE
    if y == b1 - 1:
        return P_GRAIN
    return P_BASE


def _grain(a, rng, y0, y1, n, shade=P_SHADE):
    """Long grain lines in the paint's shade step, readable at 1:1: one or two a board."""
    for _ in range(n):
        y = rng.randint(y0 + 2, y1 - 3)
        x = rng.randint(OX + 8, OX + W - 46)
        L = rng.randint(18, 34)
        step = rng.randint(6, L - 6)
        dy = rng.choice((-1, 1))
        for i in range(L):
            yy = y + (dy if i >= step else 0)
            if a.im.getpixel((x + i, yy))[:3] == P_BASE[:3]:
                a.px(x + i, yy, shade)


def _tabs(a, x0, x1, pine_tones, painted):
    """Box joints down one corner: tabs TAB rows tall, every other one the side board's finger
    with its pine end grain showing, the ones between the front board's own end grain painted a
    step off the face; a seam runs down their inner side and between every two tabs, so the
    corner reads as a joint, not as a row of rivets."""
    lit, body, ring = pine_tones
    inner = x1 + 1 if x0 < CX else x0 - 1
    seam = P_DEEP if x0 < CX else P_DUSK
    for y in range(BOARD_FROM, BOARD_TO + 1):
        if y == SEAM:
            continue
        k, r = divmod(y - BOARD_FROM, TAB)
        a.px(inner, y, seam)
        for x in range(x0, x1 + 1):
            if r == TAB - 1:
                c = seam                         # the line between two tabs
            elif k % 2:
                c = lit if r == 0 else body
                if r == 1 and x == (x0 + x1) // 2 + (k // 2) % 2:
                    c = ring                     # a growth ring in the end grain
            else:
                c = painted
            a.px(x, y, c)


def _front(a, opt, rng):
    for y in range(FY0, FY1 + 1):
        c = _band(y)
        for x in range(OX, OX + W):
            a.px(x, y, c)
    _grain(a, rng, BOARD_FROM, SEAM - 1, 2)
    _grain(a, rng, SEAM + 1, BOARD_TO, 2)
    # a knot in the lower board
    kx, ky = OX + int(W * 0.8), (SEAM + BOARD_TO) // 2 + 1
    for dx in (-1, 0, 1):
        a.px(kx + dx, ky - 1, P_SHADE)
        a.px(kx + dx, ky + 1, P_GRAIN)
    a.px(kx - 2, ky, P_SHADE)
    a.px(kx + 2, ky, P_GRAIN)
    a.px(kx, ky, P_DEEP)
    a.px(kx + 1, ky, P_DUSK)
    # the arrises: the left catches the sun (top-left)
    for y in range(FY0, FY1 + 1):
        a.px(OX, y, P_LIT if y < PLINTH else P_SOFT)
    if _kind == "front":
        # the right-hand arris is in shade, and the paint steps darker towards it through a
        # 2x2 dither (the light falls off across the face from the top-left)
        reach = 34
        for y in range(FY0, FY1 + 1):
            down = max(0.0, (y - (SEAM - 6)) / float(BOARD_TO - SEAM + 6))
            for x in range(OX + W - reach, OX + W - 1):
                c = a.im.getpixel((x, y))
                if c not in DOWN:
                    continue
                f = (x - (OX + W - reach)) / float(reach - 1) * (0.55 + 0.45 * min(1.0, down))
                level = 0 if f < 0.2 else 1 if f < 0.45 else 2 if f < 0.75 else 3
                if level >= look_dither(x, y):
                    a.px(x, y, DOWN[c])
            a.px(OX + W - 1, y, P_SHADE if y < PLINTH else P_DUSK)
    # the corner joints
    _tabs(a, OX + 1, OX + 4, (PINE_LIT, PINE, PINE_GRAIN), P_SOFT)
    if _kind == "front":
        _tabs(a, OX + W - 5, OX + W - 2, (PINE, PINE_SHADE, PINE_DEEP), P_SHADE)
    else:
        _tabs(a, OX + W - 5, OX + W - 2, (PINE_LIT, PINE, PINE_GRAIN), P_GRAIN)
        for y in range(FY0, FY1 + 1):          # the corner, catching a little light
            a.px(OX + W - 1, y, P_SOFT if y < PLINTH else P_BASE)


_DITHER = ((0, 2), (3, 1))


def look_dither(x, y):
    """A 2x2 ordered dither's threshold: a level of 1..4 covers 1..4 of every four cells."""
    return _DITHER[y % 2][x % 2] + 1


def _side(a, rng):
    """'turned': the right side face, in shade, a parallelogram whose top runs up to the back
    corner. Its bands follow the front's, a step down; a hand-hold is cut into it."""
    for j in range(1, SIDE + 1):
        x = OX + W - 1 + j
        dy = int(round(j * D / float(SIDE)))
        for y in range(FY0, FY1 + 1):
            c = DOWN[DOWN[_band(y)]] if _band(y) in DOWN and DOWN[_band(y)] in DOWN else P_DEEP
            if y - FY0 == 0:
                c = P_GRAIN                    # its top arris, under the top's rim
            a.px(x, y - dy, c)
    # grain on the side, in its deepest step
    for y0 in (BOARD_FROM + 6, SEAM + 7):
        for j in range(2, SIDE - 1):
            if (j + y0) % 5:
                dy = int(round(j * D / float(SIDE)))
                a.px(OX + W - 1 + j, y0 - dy, P_DEEP)
    # the hand-hold: a slot cut into the upper board, dark, its lower lip catching light
    for j in range(4, SIDE - 2):
        dy = int(round(j * D / float(SIDE)))
        y = BOARD_FROM + 9 - dy
        end = j in (4, SIDE - 3)
        a.px(OX + W - 1 + j, y - 1, P_NIGHT)
        a.px(OX + W - 1 + j, y, DARKER)
        a.px(OX + W - 1 + j, y + 1, DARKER if not end else DARK)
        a.px(OX + W - 1 + j, y + 2, DARK if not end else P_DEEP)
        a.px(OX + W - 1 + j, y + 3, P_GRAIN)


def _top(a, opt, rng, glow, occupied=()):
    for y in range(OY, FY0):
        xl, xr = _top_lr(y)
        for x in range(xl, xr + 1):
            a.px(x, y, P_LIT)
    # the rim's grain
    for y in (OY, FY0 - 2):
        x0 = _top_lr(y)[0] + rng.randint(8, 26)
        for i in range(rng.randint(10, 22)):
            a.px(x0 + i, y, P_RIM_GRAIN)
    # inside: the slivers of the inner walls, the gaps, the bars
    for y in range(OY + 1, FY0 - 2):
        il, ir = _inside(y)
        t = (y - OY - 1) / float(FY0 - 3 - OY - 1)
        if glow:
            gap = HONEY_LIGHT if t > 0.62 else HONEY if t > 0.3 else HONEY_MID
            wall_l, wall_r, back = HONEY_MID, HONEY, HONEY_MID
        else:
            gap = DARK
            wall_l, wall_r, back = PINE_DEEP, PINE, PINE_SHADE
        for x in range(il, ir + 1):
            a.px(x, y, back if y == OY + 1 else gap)
        if y == OY + 1:
            continue
        a.px(il, y, wall_l)
        a.px(ir, y, wall_r)
        # bees under the frames already taken: stripe flecks down in the dark gaps either side
        if not glow:
            for g in range(BARS + 1):
                if (g in occupied or g - 1 in occupied):
                    x0, x1 = _gap_span(g, y)
                    for x in range(x0, x1 + 1):
                        r = (y - OY + 2 * g + x) % 5
                        if r == 0:
                            a.px(x, y, look.SW["coin_low"])
                        elif r == 1 and (y + g) % 2:
                            a.px(x, y, look.SW["gold_deep"])
        for k in range(BARS):
            x0, x1 = bar_span(k, y)
            for x in range(x0, x1 + 1):
                a.px(x, y, PINE)
            g = x0 + int((x1 - x0) * (0.4 + 0.25 * (k % 2)))
            if (y + 2 * k) % 6:
                a.px(g, y, PINE_GRAIN)
            a.px(x0, y, mix(PINE_LIT, HONEY_SHINE, 0.55) if glow else PINE_LIT)
            a.px(x1, y, mix(PINE_SHADE, HONEY_LIGHT, 0.55) if glow else PINE_SHADE)
    # the frames' lugs resting in the rebates, flush with the rim: pine through the blue
    for k in range(BARS):
        x0, x1 = bar_span(k, FY0 - 3)
        for x in range(x0, x1 + 1):
            a.px(x, FY0 - 2, PINE_LIT if x == x0 else PINE)
            a.px(x, FY0 - 1, PINE_SHADE)
        b0, b1 = bar_span(k, OY + 2)
        for x in range(b0, b1 + 1):
            a.px(x, OY, PINE_SHADE)


# --- A: the handle ---------------------------------------------------------------------------
CLEAT_HALF, CLEAT_Y = 17, BOARD_FROM + 4


def _cleat(a):
    """A: the handle, a raised pine block screwed across the upper board. Seen from above the
    eye, its top face shows (lit), then its front (pine, its foot in shade), ringed in the
    outline ink, and it throws a two-pixel shadow down and right onto the paint."""
    x0, x1 = CX - CLEAT_HALF, CX + CLEAT_HALF - 1
    y0 = CLEAT_Y
    rows = (OUT, PINE_LIT, PINE_LIT, PINE, PINE, PINE_SHADE, OUT)
    y1 = y0 + len(rows) - 1
    for dx, dy in ((1, 1), (2, 2), (1, 2), (2, 1)):        # its shadow on the board
        for x in range(x0 + dx, x1 + dx + 1):
            a.px(x, y1 + dy, P_DEEP)
        for y in range(y0 + dy, y1 + dy + 1):
            a.px(x1 + dx, y, P_DEEP)
    for j, c in enumerate(rows):
        for x in range(x0, x1 + 1):
            a.px(x, y0 + j, OUT if x in (x0, x1) else c)
    a.px(x0 + 1, y0 + 1, PINE_LIT)
    for x in range(x0 + 6, x0 + 15):                         # grain along its front
        a.px(x, y0 + 4, PINE_GRAIN)
    for x in range(x1 - 13, x1 - 7):
        a.px(x, y0 + 3, PINE_GRAIN)
    a.px(x0 + 1, y0 + 4, PINE_SHADE)                         # its front's end, in shade
    for sx in (x0 + 4, x1 - 4):                              # the screws, in its top face
        a.px(sx, y0 + 2, bh.STEEL["base"])
        a.px(sx - 1, y0 + 2, bh.STEEL["lit"])
        a.px(sx, y0 + 1, bh.STEEL["hi"])


def _entrance(a):
    """The slot over the plinth, then the landing board standing out onto the grass."""
    for x in range(CX - 12, CX + 12):
        a.px(x, PLINTH - 5, P_DEEP)
    for j, c in enumerate((DARKER, DARK, DARK, DARKER)):
        for x in range(CX - 11, CX + 11):
            a.px(x, PLINTH - 4 + j, c)
    for j, (half, c) in enumerate(((14, PINE_LIT), (15, PINE_LIT), (16, PINE), (17, PINE),
                                    (17, PINE_SHADE), (18, PINE_DEEP))):
        y = PLINTH + j
        for x in range(CX - half, CX + half):
            a.px(x, y, c)
        if j < 4:
            a.px(CX - half, y, PINE_LIT)
    for x in range(CX - 9, CX + 4):
        a.px(x, PLINTH + 2, PINE_GRAIN)


# --- B: the observation window ---------------------------------------------------------------
WIN = (CX - 31, BOARD_FROM + 1, 62, 30)  # x, y, w, h of the window's outer frame
WIN_GLASS = (WIN[0] + 4, WIN[1] + 4, WIN[2] - 8, WIN[3] - 8)
WIN_BEES = [0, 3, 6, 9, 12, 15]          # bees seen on the comb, by clumps boxed


def _window_spots(seed=9):
    """The comb's bees, nearest the middle of the glass's foot first: bees cover a comb from
    where they gather outwards. Bee middles in the box's own pixels, about a bee apart."""
    gx, gy, gw, gh = WIN_GLASS
    rng = random.Random(seed)
    mid = (gx + gw / 2.0, gy + gh - 3)
    best = None
    for attempt in range(40):
        spots = []
        for _ in range(3000):
            x = rng.uniform(gx + 4, gx + gw - 4)
            y = rng.uniform(gy + 3, gy + gh - 3)
            if all(abs(x - a) > 9.5 or abs(y - b) > 6.5 for a, b, _ in spots):
                spots.append((x, y, math.hypot((x - mid[0]) / 1.4, y - mid[1])))
        if best is None or len(spots) > len(best):
            best = spots
        if len(best) >= WIN_BEES[-1]:
            break
    best.sort(key=lambda s: s[2])
    return [(x, y) for x, y, _ in best]


GLASS_LINE = look.SW["bark_deep"]       # a bee's outline seen through the glass


def _behind_glass(spr):
    """A bee seen through glass: a step duller, its outline lighter than the outline ink."""
    out = spr.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if not p[3]:
                continue
            q = GLASS_LINE if p[:3] == OUT[:3] else mix(p, P_LIT, 0.12)
            px[x, y] = q[:3] + (p[3],)
    return out


def _window(a, n_in, frame=0, glow=False):
    x, y, w, h = WIN
    gx, gy, gw, gh = WIN_GLASS
    # the comb behind the glass: a fresh nuc's comb, mostly empty cells (dark, so the bees on
    # it read), a little honey near its top
    comb = bh.Art(gw, gh)
    bh.comb(comb, 0, 0, gw, gh,
            lambda cx, cy, rng: "honey" if cy < 5 and rng.random() < 0.6 else
            "wax" if rng.random() < 0.12 else "empty", seed=4)
    if glow:                             # lit from inside as the mouth is
        cp = comb.im.load()
        for yy in range(gh):
            for xx in range(gw):
                c = cp[xx, yy]
                if c[3]:
                    cp[xx, yy] = mix(c, HONEY_LIGHT, 0.45)
    a.paste(comb.im, gx, gy)
    rng = random.Random(23)
    mask = Image.new("L", a.im.size, 0)
    ImageDraw.Draw(mask).rectangle([gx, gy, gx + gw - 1, gy + gh - 1], fill=255)
    for i, (bx, by) in enumerate(_window_spots()[:WIN_BEES[n_in]]):
        pose = "walk" if rng.random() < 0.7 else "rest"
        left = rng.random() < 0.5
        turn = rng.choice((0, 0, 0, 1, 3)) if pose == "walk" else 0
        # wingless: crawling on the comb their wings lie flat and the glass loses them, so what
        # reads through it is the round striped body and the eye
        spr = _behind_glass(look.turned(_bare(frame + i, left, pose), turn))
        if turn:
            ax, ay = spr.width // 2, spr.height // 2
        else:
            ax, ay = look.bee_anchor(BEE, pose, left, frame + i)
        clip = Image.new("RGBA", a.im.size, (0, 0, 0, 0))
        clip.alpha_composite(spr, (int(round(bx - ax)), int(round(by - ay))))
        clip.putalpha(Image.fromarray(np.minimum(np.array(clip.getchannel("A")), np.array(mask))))
        a.im.alpha_composite(clip)
    # the glass, in front of everything behind it: a faint sky tint, a long diagonal streak of
    # light down its left (the sun is top-left) and a short one beside it
    px = a.im.load()
    for yy in range(gy, gy + gh):
        for xx in range(gx, gx + gw):
            c = px[xx, yy]
            q = c if glow else mix(c, P_LIT, 0.12)
            d = (xx - gx) + (yy - gy)
            if d in (7, 8):
                q = mix(c, look.SW["foam_light"], 0.62)
            elif d == 12 and yy - gy < 12:
                q = mix(c, look.SW["foam_light"], 0.4)
            elif d in (44, 45) and yy - gy > 6:
                q = mix(c, look.SW["foam_light"], 0.28)
            px[xx, yy] = q
    # the frame, proud of the board, lit top-left; a dark line where the glass sits in it
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            ring = (xx in (gx - 1, gx + gw) and gy - 1 <= yy <= gy + gh) or \
                   (yy in (gy - 1, gy + gh) and gx - 1 <= xx <= gx + gw)
            if ring:
                px[xx, yy] = OUT
                continue
            if gx <= xx < gx + gw and gy <= yy < gy + gh:
                continue
            dl, dr, dt, db = xx - x, x + w - 1 - xx, yy - y, y + h - 1 - yy
            m = min(dl, dr, dt, db)
            if m in (dt, dl) and not (m == db or m == dr):
                c = PINE_LIT if m < 2 else PINE
            else:
                c = PINE_DEEP if m == 0 else PINE_SHADE if m < 2 else PINE
            px[xx, yy] = c
    for xx in range(x + 1, x + w + 1):          # the frame's shadow on the paint
        if 0 <= y + h < a.im.height:
            q = px[xx, y + h]
            if q[:3] in {c[:3] for c in DOWN}:
                px[xx, y + h] = DOWN[q[:3] + (255,)]
    # two brass turn-buttons holding the glass: 2x3, lit on top, ringed
    for bx in (x + 1, x + w - 3):
        by = y + h // 2 - 1
        for dy in range(-1, 4):
            for dx in range(-1, 3):
                px[bx + dx, by + dy] = OUT
        for dy, (c0, c1) in enumerate(((bh.BRASS["lit"], bh.BRASS["base"]),
                                       (bh.BRASS["base"], bh.BRASS["shade"]),
                                       (bh.BRASS["shade"], bh.BRASS["deep"]))):
            px[bx, by + dy] = c0
            px[bx + 1, by + dy] = c1


# --- C: the carved flight --------------------------------------------------------------------
# One carved bee, drawn for the board (bigger than the live bee so it reads as a carving, not a
# bee sitting there): '.' the board left alone, 'K' a band left standing between two cuts,
# 'B' the body's floor, 'W' a wing (a shallower cut), 'E' the eye drilled deep, 'g' the eye's
# glint left standing, 'T' the sting, 'A' the feeler. Faces right.
CARVED = [
    "....WWW..WWW...",
    "...WWWWWWWWWW..",
    "...WWWWWWWWWW..",
    "....WWWWWWWW.A.",
    "...BBBBBBBBB.A.",
    "..BBKBBKBBBBBB.",
    ".BBBKBBKBBBgEEB",
    "TBBBKBBKBBBEEEB",
    ".BBBKBBKBBBBBB.",
    "..BBKBBKBBBBB..",
    "...BBBBBBBBB...",
]
CARVE_W, CARVE_H = len(CARVED[0]), len(CARVED)
# where the five sit on the front (their middles, in the front's own pixels from its top-left)
# and which way each flies: a swoop over the board and down to the entrance
FLIGHT = [(17, 17, False), (37, 14, False), (58, 15, False), (81, 20, False), (77, 33, True)]
FLIGHT_DOTS = [(27, 15), (29, 14), (47, 13), (49, 13), (69, 16), (71, 17), (89, 27), (89, 30),
               (88, 34)]


def _carve_cells(left):
    cells = {}
    for y, row in enumerate(CARVED):
        for x, ch in enumerate(row):
            if ch != ".":
                cells[(CARVE_W - 1 - x if left else x, y)] = ch
    return cells


def _carving(a, cx, cy, left, filled):
    """A bee cut into the board, shaded as a recess under the top-left sun: the cut's inner top
    and left walls are in shadow (a step or two darker than the paint), its inner bottom and
    right walls face the sun and catch it. Filled, honey stands in every cut: its darkest step
    on top and left, its glint at the bottom right, the eye kept dark."""
    cells = _carve_cells(left)
    cut = {p for p, ch in cells.items() if ch in "BWETA"}
    x0, y0 = cx - CARVE_W // 2, cy - CARVE_H // 2
    for (x, y), ch in cells.items():
        X, Y = x0 + x, y0 + y
        if ch == "K":                       # left standing: the board itself
            a.px(X, Y, P_BASE)
            continue
        if ch == "g":                       # the eye's glint, a pale point left standing
            a.px(X, Y, P_LIT)
            continue
        shadow = (x, y - 1) not in cut or (x - 1, y) not in cut
        lit = ((x, y + 1) not in cut or (x + 1, y) not in cut) and not shadow
        if ch == "E":
            c = OUT
        elif filled:
            if ch == "W":
                c = HONEY_MID if shadow else HONEY_SHINE if lit else HONEY_LIGHT
            elif ch in "TA":
                c = HONEY_DEEP
            else:
                c = HONEY_DEEP if shadow else HONEY_LIGHT if lit else HONEY
        else:
            if ch == "W":
                c = P_DUSK if shadow else P_LIT if lit else P_GRAIN
            elif ch in "TA":
                c = P_NIGHT
            else:
                c = P_NIGHT if shadow else P_LIT if lit else P_SHADE
        a.px(X, Y, c)
    if filled:                               # the honey's glint, bottom right of the body
        bx = x0 + (10 if not left else CARVE_W - 11)
        a.px(bx, y0 + 8, HONEY_SHINE)
        a.px(bx + (-1 if not left else 1), y0 + 9, HONEY_SHINE)


def _flight(a, n_in):
    for x, y in FLIGHT_DOTS:                 # the flight path: little drilled dots
        a.px(OX + x, FY0 + y, P_NIGHT)
        a.px(OX + x + 1, FY0 + y, P_LIT)
    for i, (x, y, left) in enumerate(FLIGHT):
        _carving(a, OX + x, FY0 + y, left, i < n_in)
    if 0 < n_in < 5:
        # the newest one still brims: a bead of honey running down the board under it
        x, y, left = FLIGHT[n_in - 1]
        dx = OX + x + (-2 if not left else 2)
        for j in range(CARVE_H // 2 + 1, CARVE_H // 2 + 4):
            a.px(dx, FY0 + y + j, HONEY_MID if j == CARVE_H // 2 + 1 else HONEY)
        a.px(dx, FY0 + y + CARVE_H // 2 + 4, HONEY_DEEP)
        a.px(dx + 1, FY0 + y + CARVE_H // 2 + 2, HONEY_SHINE)


# --- worn paint ------------------------------------------------------------------------------
# Where hands wear the paint: the rim's ends, the plinth's ends, the joints. 'L' pine lit,
# 'p' pine, 's' pine in shade, 'd' the paint's deep step (the chip's shadow).
CHIPS = [
    (0, 1, ["Lp.", "psd", ".d."]),           # the rim band's left end
    (W - 5, 1, [".pL", "psp", "dd."]),       # its right end
    (0, PLINTH - FY0, ["Lpp", "psd", "d.."]),
    (W - 6, PLINTH - FY0 + 1, ["ppL", "sdd"]),
    (5, SEAM - FY0 + 1, ["Lp", "pd"]),       # the lower board's corner, by the joint
]
_CHIP_KEY = {"L": PINE_LIT, "p": PINE, "s": PINE_SHADE, "d": P_DEEP}


def _chips(a):
    for x0, y0, rows in CHIPS:
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != ".":
                    a.px(OX + x0 + i, FY0 + y0 + j, _CHIP_KEY[ch])
    # and the top's front rim, worn where the box is lifted
    a.px(_top_lr(FY0 - 2)[0] + 3, FY0 - 2, PINE_LIT)
    a.px(_top_lr(FY0 - 2)[0] + 4, FY0 - 2, PINE_LIT)
    a.px(_top_lr(FY0 - 1)[0] + 4, FY0 - 1, PINE)


def box_body(opt, n_in=0, glow=False, frame=0):
    """The box alone, inked, on a CW x CH canvas at one pixel per art pixel, in the box's own
    coordinates (FEET is its foot's middle)."""
    use(opt)
    rng = random.Random({"A": 3, "B": 5, "C": 8}[opt])
    a = bh.Art(CW, CH)
    lit_gaps = glow and opt in "AB"
    if _kind == "turned":
        _side(a, rng)
    _top(a, opt, rng, lit_gaps, occupied=range(n_in) if opt == "A" else ())
    _front(a, opt, rng)
    if opt == "A":
        _cleat(a)
    elif opt == "B":
        _window(a, n_in, frame, glow)
    else:
        _flight(a, n_in)
    _entrance(a)
    _chips(a)
    im = look.inked(a.im)
    return im.crop((1, 1, CW + 1, CH + 1))   # back onto the box's own grid; ink kept


# =============================================================================================
# The clump: a living cloud of look's bee
# =============================================================================================
def _bare(frame, left, pose):
    """look's bee with its wings left off: a bee deep in a clump, its wings folded under the
    bees on top of it, so the clump's middle is faces and stripes, not white wing blocks."""
    spec = dict(look._SPEC[BEE])
    spec["wings"] = dict(spec["wings"])
    spec["wings"]["none"] = [(["."], 0, 0)]
    legs = spec["legs"][frame % 2] if pose == "walk" else spec["rest_legs"]
    im = look._compose(spec, look.key(BEE), look.BEE_CANVAS, look.BODY_AT, "none", legs,
                       pose == "rest" and frame % 4 == 3)
    return look.flip(im) if left else im


def _lay(canvas, spr, x, y):
    """Composite one bee onto the clump (numpy RGBA, in place). Where its outline falls on a bee
    already there, the line is the soft brown, not the outline ink, so neighbours keep apart
    without the clump turning into a black lattice; its outline over the open air stays ink."""
    s = np.array(spr)
    h, w = s.shape[:2]
    a = s[..., 3] > 0
    p = np.pad(a, 1)
    edge = a & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    ink = (s[..., 0] == OUT[0]) & (s[..., 1] == OUT[1]) & (s[..., 2] == OUT[2])
    line = edge & ink
    H_, W_ = canvas.shape[:2]
    x0, y0 = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(w, W_ - x0), min(h, H_ - y0)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    sub = canvas[y0 + sy0:y0 + sy1, x0 + sx0:x0 + sx1]
    ss = s[sy0:sy1, sx0:sx1].copy()
    under = sub[..., 3] > 0
    soft = line[sy0:sy1, sx0:sx1] & under
    ss[soft, :3] = SOFT_LINE[:3]
    m = ss[..., 3] > 0
    sub[m] = ss[m]


def _ring_outline(canvas):
    """One shared outline round the whole clump's silhouette. Little holes between bees inside
    it are filled with the soft brown (the shade between bodies), not ringed in ink."""
    a = canvas[..., 3] > 0
    ext = np.zeros_like(a)
    ext[0, :], ext[-1, :], ext[:, 0], ext[:, -1] = ~a[0, :], ~a[-1, :], ~a[:, 0], ~a[:, -1]
    while True:
        grown = ext.copy()
        grown[1:, :] |= ext[:-1, :]
        grown[:-1, :] |= ext[1:, :]
        grown[:, 1:] |= ext[:, :-1]
        grown[:, :-1] |= ext[:, 1:]
        grown &= ~a
        if (grown == ext).all():
            break
        ext = grown
    holes = ~a & ~ext
    canvas[holes, :3] = SOFT_LINE[:3]
    canvas[holes, 3] = 255
    a = a | holes
    p = np.pad(ext, 1)
    edge = a & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
    canvas[edge, :3] = OUT[:3]


def cloud(n=14, seed=1, frame=0, box=(84, 66), spacing=(7.6, 5.2), n_loose=3, shape="clump",
          aspect=1.3, depth=0.2):
    """A swarm clump as a living cloud: about n bees (n_loose of them flying round it), their
    middles `spacing` apart so neighbours overlap by two or three pixels and every face that
    points out keeps its eye, glint and blush. The back rows (the top of the clump) are a ramp
    step darker with their wings tucked; the middle crawls wingless; the outer ring hovers,
    wings flickering, faces turned outwards. Where two bees touch the line is soft brown; one
    ink outline goes round the whole. Step `frame` to animate."""
    w, h = box
    rng = random.Random(seed)
    n_core = n - n_loose
    sx, sy = spacing
    area = n_core * sx * sy * 1.25
    ry = math.sqrt(area / (math.pi * aspect))
    rx = ry * aspect
    cx, cy = w / 2.0, h / 2.0
    pts = []
    for _ in range(20000):
        if len(pts) >= n_core:
            break
        u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
        if not look._inside(shape, u, v):
            continue
        x, y = cx + u * rx, cy + v * ry
        if all(((x - a) / sx) ** 2 + ((y - b) / sy) ** 2 >= 1.0 for a, b, _, _ in pts):
            pts.append((x, y, u, v))
    canvas = np.zeros((h, w, 4), np.uint8)
    pts.sort(key=lambda p: p[1])
    for x, y, u, v in pts:
        r = math.hypot(u, v)
        phase = rng.randrange(6)
        f = frame + phase
        outward = u < 0                        # a bee on the left faces left
        if v < -0.35 and r > 0.35:              # the back rows: tucked in and in shade
            left = rng.random() < 0.5
            pose = "rest" if rng.random() < 0.5 else "walk"
            spr = look.tinted(_bare(f, left, pose), OUT, depth)
            ax, ay = look.bee_anchor(BEE, pose, left, f)
        elif r < 0.55:                         # the middle: crawling over one another
            left = rng.random() < 0.5
            pose = "walk" if rng.random() < 0.7 else "rest"
            spr = _bare(f, left, pose)
            ax, ay = look.bee_anchor(BEE, pose, left, f)
        else:                                  # the outer ring: hovering, looking out
            left = outward if rng.random() < 0.85 else not outward
            pose = "hover" if rng.random() < 0.75 else "walk"
            spr = look.bee(BEE, f, facing_left=left, pose=pose)
            ax, ay = look.bee_anchor(BEE, pose, left, f)
        _lay(canvas, spr, x - ax, y - ay)
    _ring_outline(canvas)
    im = Image.fromarray(canvas, "RGBA")
    # the loose ones: on slow orbits round the clump, bobbing (drawn over, own outlines)
    for i in range(n_loose):
        a0 = rng.uniform(0, 2 * math.pi)
        a = a0 + frame * 0.22 * (1 if i % 2 else -1)
        rr = rng.uniform(1.35, 1.6)
        x = min(max(cx + math.cos(a) * (rx + 6) * rr, 9), w - 9)
        y = min(max(cy + math.sin(a) * (ry + 5) * rr, 9), h - 7)
        left = (math.sin(a) > 0) == (i % 2 == 0)
        f = frame + rng.randrange(6)
        spr = look.bee(BEE, f, facing_left=left, pose="fly")
        ax, ay = look.bee_anchor(BEE, "fly", left, f)
        im.alpha_composite(spr, (int(round(x - ax)), int(round(y - ay))))
    return im


# =============================================================================================
# Bees on and round the box
# =============================================================================================
def _stamp(layer, spr, at_xy, anchor):
    layer.alpha_composite(spr, (int(round(at_xy[0] - anchor[0])), int(round(at_xy[1] - anchor[1]))))


def _mid_of(spr):
    b = spr.getbbox()
    return ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)


def _half_in(spr, keep_top=True):
    """A bee half down a gap between two frames: the end still out shows, the rest is gone into
    the dark, its last row in the gap's shade."""
    out = spr.copy()
    b = out.getbbox()
    cut = (b[1] + b[3]) // 2
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            hidden = y > cut if keep_top else y < cut
            if hidden:
                px[x, y] = (0, 0, 0, 0)
            elif y == cut and px[x, y][3]:
                px[x, y] = DARKER
    return out


def _bar_bees(n_in, frame):
    """A: every clump poured in settles on the next frame, left to right. Each frame's crowd is
    its own: two or three crawling its bar (some head up, some head down, one across), one sat
    on its lug, one squeezing down the gap beside it with only its tail out. As the box fills
    the crowds spill onto the bar ends either side and the rim, so a full box heaves."""
    out = []
    span = FY0 - 3 - OY - 1
    for k in range(n_in):
        rng = random.Random(300 + 7 * k)
        crowd = [(0.08, "walk", rng.choice((1, 3)), None),
                 (0.42 + rng.uniform(-0.06, 0.06), "walk", 0, rng.random() < 0.5),
                 (0.72 + rng.uniform(-0.05, 0.05), "walk", rng.choice((1, 3)), None),
                 (1.0, "rest", 0, k >= 2)]
        if k % 2:
            crowd[1], crowd[2] = (crowd[1][0] + 0.12,) + crowd[1][1:], (0.25,) + crowd[2][1:]
        for t, pose, turn, left in crowd:
            y = OY + 1 + t * span
            x = bar_mid(k, int(round(y))) + 0.5 + rng.choice((-1, 0, 1))
            lf = rng.random() < 0.5 if left is None else left
            spr = look.bee(BEE, frame + k + int(t * 10), facing_left=lf, pose=pose, turn=turn)
            if t < 0.3:
                spr = look.tinted(spr, OUT, 0.18)   # the far end of the bar, in the box's shade
            out.append((y, spr, (x, y), _mid_of(spr)))
        # one squeezing down the gap beside it, only its tail out
        g = k + 1 if k % 2 == 0 else k
        y = OY + 1 + (0.55 + 0.1 * (k % 3)) * span
        x0, x1 = _gap_span(g, int(round(y)))
        spr = _half_in(look.bee(BEE, frame + k, facing_left=k % 2 == 0, pose="walk", turn=3))
        out.append((y - 0.5, spr, ((x0 + x1) / 2.0 + 0.5, y), _mid_of(spr)))
    # the spill, growing with the count: bees over the bar ends next door and onto the rim
    spill = [(n_in >= 3, (n_in, 0.95), "walk", False),
             (n_in >= 4, ("rim", 0.3), "walk", True),
             (n_in >= 4, (n_in, 0.55), "walk", True),
             (n_in >= 5, ("rim", 0.62), "rest", False),
             (n_in >= 5, ("rim", 0.86), "walk", True),
             (n_in >= 5, ("back", 0.4), "walk", False),
             (n_in >= 5, ("back", 0.7), "rest", True)]
    for i, (on, (where, t), pose, left) in enumerate(spill):
        if not on:
            continue
        if where == "rim":                     # on the front rim, over the lugs
            xl, xr = _top_lr(FY0 - 2)
            x, y = xl + t * (xr - xl), FY0 - 1
        elif where == "back":                  # along the back rim
            xl, xr = _top_lr(OY)
            x, y = xl + t * (xr - xl), OY - 1
        else:                                  # a bar end next door
            k = min(where, BARS - 1)
            y = OY + 1 + t * span
            x = bar_mid(k, int(round(y))) + 0.5
        spr = look.bee(BEE, frame + 2 * i, facing_left=left, pose=pose)
        if where == "back":
            spr = look.tinted(spr, OUT, 0.18)
        out.append((y, spr, (x, y), _mid_of(spr)))
    return out


def _fanners(frame):
    """A's call over a clump in hand: two bees on the landing board, tails to the entrance,
    fanning (wings a blur of up and down): the scent that tells a swarm where home is."""
    out = []
    for j, (dx, left) in enumerate(((-12, True), (12, False))):
        spr = look.bee(BEE, (frame + j) % 3, facing_left=left, pose="hover")
        for lx in (6, 9):                 # two legs down onto the board
            spr.putpixel((lx, look.BODY_AT[1] + 7), OUT)
        out.append((FY1 + 1, spr, (CX + dx, PLINTH + 1), (8, look.BODY_AT[1] + 7)))
    return out


def _guard(frame):
    """A guard bee walking the landing board: the same at every count (it is not a counter)."""
    spr = look.bee(BEE, frame, facing_left=False, pose="walk")
    return [(FY1, spr, (CX - 6, PLINTH + 1), (8, 13))]


def _c_sitters(frame):
    """C: two bees sat on the bars, the same at every count (the carvings count, not these)."""
    out = []
    for k, t, left in ((1, 0.7, True), (3, 0.35, False)):
        y = OY + 1 + t * (FY0 - 3 - OY - 1)
        spr = look.bee(BEE, frame + k, facing_left=left, pose="rest")
        out.append((y, spr, (bar_mid(k, int(round(y))) + 0.5, y), _mid_of(spr)))
    return out


BEAM_TALL = 24                           # B's beams: how far over the back rim they rise


def _beams(im, frame):
    """B's call: warm light standing up out of the open box like the finds' beams, the whole
    mouth wide, brighter over every gap between the frames: solid where it leaves the box,
    thinning through a 2x2 dither to nothing."""
    px = im.load()
    pale, lit, gold = look.SW["coin_pale"], look.SW["coin_lit"], look.SW["coin"]
    il, ir = _inside(OY + 2)
    gaps = set()
    for g in range(BARS + 1):
        x0, x1 = _gap_span(g, OY + 2)
        gaps.update(range(x0, x1 + 1))
    mid = (il + ir) / 2.0
    half = (ir - il) / 2.0
    for x in range(il, ir + 1):
        tall = BEAM_TALL * (1.0 - 0.45 * (abs(x - mid) / half) ** 2)
        tall *= 1.0 if x in gaps else 0.62
        tall = int(round(tall)) + (((x // 3) + frame) % 3) - 1
        for j in range(max(0, tall)):
            y = OY - 1 - j
            f = j / float(max(1, tall))
            level = 4 if f < 0.25 else 3 if f < 0.5 else 2 if f < 0.75 else 1
            if level < look_dither(x, y):
                continue
            px[x, y] = (pale if f < 0.4 else lit) if x in gaps else (lit if f < 0.3 else gold)


def _stars(a, frame):
    """C's call: the rim of the open box goes gold all round, the front's top arris with it, a
    star at each corner and one more chasing round the rim. The gaps stay dark."""
    gold, pale, deep = look.SW["coin_lit"], look.SW["coin_pale"], look.SW["coin"]
    px = a.im.load()
    for y in range(OY, FY0 + 1):
        for x in range(OX - 1, OX + W + SIDE + 1):
            c = px[x, y][:3]
            if c == P_LIT[:3]:
                px[x, y] = gold
            elif c == P_RIM_GRAIN[:3]:
                px[x, y] = deep
            elif y == FY0 and c == P_SOFT[:3]:
                px[x, y] = pale
    bl, br = _top_lr(OY)
    fl, fr = _top_lr(FY0 - 1)
    corners = [(bl, OY - 2), (br, OY - 2), (fl - 1, FY0 - 1), (fr + 1, FY0 - 1)]
    for i, (x, y) in enumerate(corners):
        arm = 3 if (i + frame) % 2 else 2
        bh.star(a, x, y, arm=arm, col=gold, tip=pale)
    # the chaser, round the rim from the back left (frame moves it a quarter of a side)
    t = ((frame % 8) + 0.5) / 8.0 * 4.0
    side, f = int(t), t - int(t)
    path = [corners[0], corners[1], corners[3], corners[2], corners[0]]
    (x0, y0), (x1, y1) = path[side], path[side + 1]
    bh.star(a, int(round(x0 + (x1 - x0) * f)), int(round(y0 + (y1 - y0) * f)), arm=2, col=pale,
            tip=pale)


def box_sprite(opt, n_in=0, glow=False, frame=0):
    """The box with everything on it: the bees on it, on its landing board and, with `glow`,
    its call. One picture on the CW x CH grid; FEET stands on FEET_AT."""
    im = box_body(opt, n_in, glow, frame)
    if glow and opt == "B":
        _beams(im, frame)
    items = []
    if opt == "A":
        items += _bar_bees(n_in, frame)
    elif opt == "C":
        items += _c_sitters(frame)
    items += _fanners(frame) if (opt == "A" and glow) else _guard(frame)
    items.sort(key=lambda t: t[0])
    for _, spr, at, anchor in items:
        _stamp(im, spr, at, anchor)
    if glow and opt == "C":
        a = bh.Art(CW, CH)
        a.im = im
        a.d = ImageDraw.Draw(im)
        _stars(a, frame)
    return im


# =============================================================================================
# On the plate
# =============================================================================================
CURSOR = Image.open(os.path.join(look.ROOT, "assets/cursor.png")).convert("RGBA")
CURSOR_TIP = (2, 2)                      # Pad.CURSOR_TIP: a hardware cursor, real screen px
SHADOW_RUN = (18, 6)                     # the shadow's reach down-right along the room's sun
# The box's footprint on the grass, by the wash room's perspective (y = 155 + 328 / d art rows
# for ground d tiles out): its foot is 2.23 tiles out on row 302, its back 0.48 further on row
# 276, a step narrower. Hidden by the box but for the shadow it throws.
FOOT_DEPTH, FOOT_INSET = 26, 10
HOMES = [(104, 112), (212, 82), (338, 66), (452, 88), (548, 118)]   # hive_step_catch HOMES
MOUTH_AT = (FEET_AT[0], FEET_AT[1] - (FY1 - FY0) - 6)


def box_origin():
    """Where the box canvas's (0, 0) lands on the art grid."""
    return (FEET_AT[0] - FEET[0], FEET_AT[1] - FEET[1])


def _hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def shadow_on(im, opt):
    """The box's shadow on the lawn: its base swept down-right along the room's sun (top-left),
    a solid core and a checkered fringe one cell round it, darkening the grass that is there."""
    use(opt)
    ox, oy = box_origin()
    x0, x1, fy = ox + OX, ox + OX + W - 1, FEET_AT[1]
    if _kind == "turned":
        foot = [(x0, fy + 1), (x1, fy + 1), (x1 + SIDE, fy - FOOT_DEPTH),
                (x0 + SIDE, fy - FOOT_DEPTH)]
    else:
        foot = [(x0, fy + 1), (x1, fy + 1), (x1 - FOOT_INSET, fy - FOOT_DEPTH),
                (x0 + FOOT_INSET, fy - FOOT_DEPTH)]
    poly = _hull(foot + [(x + SHADOW_RUN[0], y + SHADOW_RUN[1]) for x, y in foot])
    w, h = look.ROOM_GRID
    core = Image.new("L", (w, h), 0)
    ImageDraw.Draw(core).polygon(poly, fill=255)
    c = np.array(core) > 0
    grown = c.copy()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown |= np.roll(np.roll(c, dy, 0), dx, 1)
    fringe = grown & ~c
    yy, xx = np.mgrid[0:h, 0:w]
    fringe &= (xx + yy) % 2 == 0
    cells = _cells(im)
    ink = np.array(SHADOW_INK[:3], float)
    for mask, t in ((c, SHADOW_CORE), (fringe, SHADOW_FRINGE)):
        sub = cells[mask][:, :3].astype(float)
        cells[mask, :3] = np.round(sub + (ink - sub) * t).astype(np.uint8)
    _paint_back(im, cells)
    return im


def hem_on(im, seed=5):
    """Grass blades standing in front of the box's foot (Skirt.hem's idea): the line where the
    box meets the lawn is grass, not a ruled edge. Clear of the landing board."""
    ox, oy = box_origin()
    rng = random.Random(seed)
    fy = FEET_AT[1]
    blades = Image.new("RGBA", look.ROOM_GRID, (0, 0, 0, 0))
    for x in range(ox + OX - 2, ox + OX + W + 2):
        if abs(x - (ox + CX)) < 20 or rng.random() > 0.5:
            continue
        tall = rng.choice((2, 2, 3, 3, 4))
        lean = rng.choice((0, 0, 0, 1, -1))
        for j in range(tall):
            c = LAWN_TIP if j == tall - 1 else LAWN_LIT if j > 0 else LAWN
            bx = x + (lean if j == tall - 1 else 0)
            blades.putpixel((bx, fy + 1 - j), c)
    place(im, blades, (0, 0), G)
    return im


def put_box(im, opt, n_in, glow=False, frame=0):
    shadow_on(im, opt)
    spr = box_sprite(opt, n_in, glow, frame)
    look.place_art(im, spr, box_origin(), G)
    hem_on(im)
    return im


def put_clump(im, at, n=14, seed=1, frame=0, tight=False):
    box = (84, 66)
    cl = cloud(n, seed=seed, frame=frame, box=box,
               spacing=(7.0, 4.9) if tight else (7.6, 5.2), n_loose=2 if tight else 3)
    look.place_art(im, cl, at, G, anchor=(box[0] // 2, box[1] // 2))
    return im


def put_comet(im, head, toward, n=16, seed=3, frame=0, length=56):
    """A clump in hand being dragged: its middle at the pointer, the slow bees strung out
    behind it back along the way it came (hive_step_catch's CHASE spread). Laid like the
    clump: soft lines where bees touch, one outline round the lot, a bee's width apart."""
    rng = random.Random(seed)
    hx, hy = head
    dx, dy = toward[0] - hx, toward[1] - hy
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    px_, py_ = -uy, ux
    going_left = ux > 0              # moving away from `toward`
    size = 220
    canvas = np.zeros((size, size, 4), np.uint8)
    c0 = (110, 110)
    bees = []
    for _ in range(4000):
        if len(bees) >= n:
            break
        along = (rng.random() ** 2.2) * length
        side = rng.gauss(0, 1) * (5.0 + along * 0.16)
        x = c0[0] + ux * along + px_ * side
        y = c0[1] + uy * along + py_ * side * 0.7
        if all(((x - a) / 7.4) ** 2 + ((y - b) / 5.0) ** 2 >= 1.0 for _, a, b in bees):
            bees.append((along, x, y))
    bees.sort(key=lambda b: b[2])
    for along, x, y in bees:
        f = frame + rng.randrange(6)
        left = going_left if rng.random() < 0.85 else not going_left
        spr = look.bee(BEE, f, facing_left=left, pose="fly")
        a = look.bee_anchor(BEE, "fly", left, f)
        _lay(canvas, spr, x - a[0], y - a[1])
    _ring_outline(canvas)
    look.place_art(im, Image.fromarray(canvas, "RGBA"), head, G, anchor=c0)
    return im


def put_cursor(im, at_art):
    """The hardware cursor, always last, over every bee: its tip is where the player aims."""
    x, y = at_art[0] * G + G // 2, at_art[1] * G + G // 2
    im.alpha_composite(CURSOR, (x - CURSOR_TIP[0], y - CURSOR_TIP[1]))
    return im


# The middle home sits 8 art px lower than hive_step_catch's (338, 66): a clump of the new bee is
# about 50 art px across, and at 66 its top bees sat on the step board's foot (row 38).
HOME_NUDGE = {2: (0, 8)}
# The loose bees wandering the sky (HiveStep.wanderers, AIR 28 today): ten, by this sheet's
# call. Art cells, kept clear of the clumps, the step board and the cross.
LOOSE = [(40, 56), (168, 30), (250, 128), (272, 56), (402, 30), (486, 150), (612, 64),
         (150, 168), (522, 36), (70, 168)]


def home_of(k):
    dx, dy = HOME_NUDGE.get(k, (0, 0))
    return (HOMES[k][0] + dx, HOMES[k][1] + dy)


def put_loose(im, frame=0, skip_near=None):
    rng = random.Random(61)
    for i, (x, y) in enumerate(LOOSE):
        left = rng.random() < 0.5
        f = frame + rng.randrange(6)
        if skip_near and math.hypot(x - skip_near[0], y - skip_near[1]) < 30:
            continue
        spr = look.bee(BEE, f, facing_left=left, pose="fly")
        look.place_art(im, spr, (x, y), G, anchor=look.bee_anchor(BEE, "fly", left, f))
    return im


HEAD = (404, 176)                        # mid-catch: the pointer dragging a clump down


def scene(opt, n_in=2, frame=0):
    """Mid-catch: n_in clumps boxed, one in hand on its way down, the rest at their homes."""
    im = clean_plate()
    put_box(im, opt, n_in, False, frame)
    put_loose(im, frame)
    for k in range(len(HOMES)):
        if k in (2, 4):
            put_clump(im, home_of(k), 14, seed=11 + k, frame=frame + k)
    put_comet(im, HEAD, HOMES[3], seed=5, frame=frame)
    put_cursor(im, HEAD)
    return im


OVER = (MOUTH_AT[0], MOUTH_AT[1] - 36)    # a clump in hand held over the box
DRAG_AT = (MOUTH_AT[0] + 22, MOUTH_AT[1] - 46)


def drag_scene(opt, n_in=2, frame=0):
    """On its way to the box: strung out behind the moving pointer, the mouth dark."""
    im = clean_plate()
    put_box(im, opt, n_in, False, frame)
    put_comet(im, DRAG_AT, (DRAG_AT[0] + 80, DRAG_AT[1] - 24), seed=7, frame=frame, length=46)
    put_cursor(im, DRAG_AT)
    return im


def mouth_scene(opt, n_in=2, frame=0):
    """A clump in hand held still over the box: the trail has gathered back into a ball round
    the pointer, and the mouth answers."""
    im = clean_plate()
    put_box(im, opt, n_in, True, frame)
    put_clump(im, OVER, 16, seed=31, frame=frame, tight=True)
    put_cursor(im, OVER)
    return im


def _box_art(x, y):
    """A point in the box sprite's own pixels -> the room's art grid."""
    ox, oy = box_origin()
    return (ox + x, oy + y)


def _diver(left):
    """A bee diving head first (turned so its head points down the screen), wings out to one
    side: (sprite, anchor at its head's end)."""
    spr = look.bee(BEE, 1, facing_left=left, pose="hover", turn=1 if left else 3)
    b = spr.getbbox()
    return spr, ((b[0] + b[2]) // 2, b[3] - 1)


def pour_scene(opt, n_in=2, stage=1, frame=0):
    """Letting go over the box. stage 1: the clump falls apart into a curtain of bees diving
    head first between the frames, the mouth still lit, a few veering off (hive_step_catch
    MISS), the pointer where it let go; stage 2: in, the box counts one more and the last few
    bees go down."""
    im = clean_plate()
    rng = random.Random(90 + stage)
    if stage == 2:
        put_box(im, opt, n_in + 1, False, frame)
        n, most = 4, 0.8                    # the last few, on their way down
    else:
        put_box(im, opt, n_in, True, frame)
        cl = cloud(7, seed=33, frame=frame, box=(60, 44), spacing=(7.6, 5.2), n_loose=2)
        look.place_art(im, cl, (OVER[0], OVER[1] - 14), G, anchor=(30, 22))
        n, most = 15, 1.15
    use(opt)
    top_y = OY + 3                          # where a diving bee's head meets the box
    floor = top_y + 6
    bees = []
    tries = 0
    while len(bees) < n and tries < 2000:
        tries += 1
        d = most * rng.random() ** 0.9
        g = rng.randrange(BARS + 1)
        x0, x1 = _gap_span(g, top_y + 4)
        gx = (x0 + x1) / 2.0 + rng.uniform(-1.0, 1.0)
        gx = CX + (gx - CX) * (1.0 - 0.5 * min(1.0, d))
        gy = floor - d * 36
        if any(abs(gx - u) < 8 and abs(gy - v) < 8 for u, v, _ in bees):
            continue
        bees.append((gx, gy, d))
    bees.sort(key=lambda t: t[1])
    for gx, gy, d in bees:
        left = gx > CX if rng.random() < 0.7 else gx <= CX
        if rng.random() < 0.72:
            spr, anchor = _diver(left)
        else:                               # tumbling in sideways
            f = rng.randrange(6)
            spr = look.bee(BEE, f, facing_left=left, pose="fly")
            anchor = look.bee_anchor(BEE, "fly", left, f)
        if d < 0.22:                        # half in already: into the box's shade
            spr = look.tinted(spr, OUT, 0.3)
        at = _box_art(gx, gy)
        look.place_art(im, spr, (int(round(at[0] - anchor[0])), int(round(at[1] - anchor[1]))), G)
    if stage == 1:
        for (dx, dy), left in (((-46, -20), True), ((44, -26), False)):
            f = frame + 2
            spr = look.bee(BEE, f, facing_left=left, pose="fly")
            at = (OVER[0] + dx, OVER[1] + dy)
            look.place_art(im, spr, at, G, anchor=look.bee_anchor(BEE, "fly", left, f))
        put_cursor(im, OVER)
    return im


# =============================================================================================
# The sheet
# =============================================================================================
COLUMN = 620                             # the right-hand column of crops beside each plate
ZOOM = 3                                 # detail crops: 3x the plate (9 screen px an art px)
ZW = COLUMN // ZOOM                      # a 3x crop's width in plate px
ZW2 = COLUMN // 2                        # a 2x crop's width in plate px


def _box_px():
    """The box's own rectangle on the plate (plate px)."""
    ox, oy = box_origin()
    return ((ox + OX) * G, (oy + FY0) * G, (ox + OX + W + SIDE) * G, (oy + FY1 + 1) * G)


def _at_box(x, y, w, h):
    """A plate crop w x h centred on the box's own pixel (x, y)."""
    ox, oy = box_origin()
    cx, cy = (ox + x) * G + G // 2, (oy + y) * G + G // 2
    return (cx - w // 2, cy - h // 2, cx - w // 2 + w, cy - h // 2 + h)


def strip_crop(opt):
    """A crop round the box with the bees on its top and its shadow beside, 400 plate px wide."""
    x0, y0, x1, y1 = _box_px()
    return (x0 - 15, y0 - 110, x0 - 15 + 400, y1 + 30)


DETAIL = {
    # (what the 2x zoom shows, its plate box) per option: the count, close up
    "A": ("the count: two frames of bees, three bare", lambda: _at_box(CX, OY + 3, ZW2, 140)),
    "B": ("the count: six bees on the comb behind the glass",
          lambda: _at_box(CX, WIN[1] + WIN[3] // 2, ZW2, 120)),
    "C": ("the count: two carved bees full of honey, three still cut bare",
          lambda: _at_box(CX + 4, FY0 + 23, ZW2, 120)),
}
LIT_DETAIL = {
    "A": ("lit: the gaps glow, two bees fan on the landing board",
          lambda: _at_box(CX, PLINTH - 4, ZW, 100)),
    "B": ("lit: light stands up out of the mouth, the comb glows",
          lambda: _at_box(CX - 18, OY - 4, ZW, 100)),
    "C": ("lit: the rim goes gold, stars at the corners, gaps dark",
          lambda: _at_box(OX + SIDE + 20, OY + 4, ZW, 100)),
}
NAMES = {"A": "bees on the frames", "B": "the window", "C": "carved flight, turned box"}
CAPTIONS = {
    "A": ("Every clump poured in settles on the next frame, left to right: its own crowd on "
          "the bar, one squeezing down the gap, bees glimpsed below; at 4 and 5 they spill onto "
          "the rim. Over it the gaps glow and two bees fan on the landing board."),
    "B": ("An observation window in the front: the comb behind the glass fills with bees, three "
          "a clump, and that is the only count (the bars stay bare); over it, warm light "
          "stands up out of the mouth and the comb glows."),
    "C": ("The box set down a few degrees off square, so its shaded side and a cut hand-hold "
          "show. Five bees carved in a swoop fill with honey one clump at a time; over it the "
          "rim goes gold with a star at each corner and one chasing round, the gaps kept dark."),
}


def _label(s, w):
    return look.text_block(s, w, 18, "bold", look.INK)


def pour_crop():
    """The pour at 1:1: the box, its shadow and the air over it where the clump comes apart."""
    x0, y0, x1, y1 = _box_px()
    mx = (x0 + x1) // 2
    return (mx - 200, 450, mx + 200, y1 + 40)


def pour_zoom_crop():
    """The pour close up: the box's open top and the curtain of bees diving into it."""
    x0, y0, x1, y1 = _box_px()
    mx = (x0 + x1) // 2
    half = COLUMN // 4                     # 2x fills the column
    return (mx - half, 566, mx + half, 796)


def _column(opt, mouth, pouring):
    """The crops beside a plate: the pour at 2x, the count at 2x, the call at 3x."""
    parts = []
    parts.append(_label("letting go: the clump pours in, 2x", COLUMN))
    parts.append(zoom(pouring.crop(pour_zoom_crop()), 2))
    full = scene(opt, 2)
    t, box = DETAIL[opt]
    parts.append(_label(t + ", 2x", COLUMN))
    parts.append(zoom(full.crop(box()), 2))
    t, box = LIT_DETAIL[opt]
    parts.append(_label(t + ", 3x", COLUMN))
    parts.append(zoom(mouth.crop(box()), ZOOM))
    return stack(parts, "v", 6)


def _strip(opt):
    """The box at 0..5 clumps boxed, each at 1:1 on the plate."""
    sc = strip_crop(opt)
    cells = []
    for n in range(6):
        im = clean_plate()
        put_box(im, opt, n, False, frame=n)
        cap = "empty" if n == 0 else ("%d of 5, full" % n if n == 5 else "%d of 5" % n)
        cells.append(stack([_label(cap, sc[2] - sc[0]), im.crop(sc)], "v", 4))
    return stack(cells, "h", 12)


POUR_CAPS = ("dragging: strung out behind the pointer",
             "held still: the trail balls up, the mouth lights",
             "let go: it comes apart and dives in",
             "in: the box counts one more")


def _pour_row(drag, mouth, pouring, poured):
    pc = pour_crop()
    cells = [stack([_label(t, pc[2] - pc[0]), im.crop(pc)], "v", 4)
             for t, im in zip(POUR_CAPS, (drag, mouth, pouring, poured))]
    return stack(cells, "h", 12)


def option(opt):
    mid = scene(opt, 2)
    drag = drag_scene(opt, 2)
    mouth = mouth_scene(opt, 2)
    pouring = pour_scene(opt, 2, 1)
    poured = pour_scene(opt, 2, 2)
    top = stack([stack([_label("mid-catch: two clumps boxed, one in hand, 1:1 on the real "
                               "plate", 1920), mid], "v", 6),
                 _column(opt, mouth, pouring)], "h", 16)
    body = stack([top,
                  _label("the box as it fills, 1:1", top.width), _strip(opt),
                  _label("the third clump, from dragged to in, 1:1", top.width),
                  _pour_row(drag, mouth, pouring, poured)], "v", 10)
    return look.option_block(opt, NAMES[opt], CAPTIONS[opt], body, recommended=opt == RECOMMEND)


TODAY_BOX = (770, 630, 1170, 920)


def art_px_mid(xy):
    return (xy[0] * G + G // 2, xy[1] * G + G // 2)


def _around(c, w, h):
    return (c[0] - w // 2, c[1] - h // 2, c[0] - w // 2 + w, c[1] - h // 2 + h)


TODAY_SKY = (1540, 270, 1820, 430)
TODAY_DRAG = (1050, 400, 1270, 570)


def _bee_strip():
    """The shared bee's animation at 4x on the room's sky: the six fly frames (wings up, mid,
    down, the body bobbing up one art px on 3-5), then walk and the rest's blink."""
    sky = clean_plate().crop((1152, 180, 1152 + 66, 180 + 66))
    cells = []
    poses = [("fly", f) for f in range(6)] + [("walk", 0), ("walk", 1), ("rest", 0), ("rest", 3)]
    for pose, f in poses:
        tile = sky.copy()
        spr = look.bee(BEE, f, pose=pose)
        place(tile, spr, (G * 3, G * 3), G)
        name = "%s %d" % (pose, f) if pose != "rest" else ("rest" if f == 0 else "blink")
        cells.append(stack([look.text_block(name, 66 * 4, 15, "bold", look.INK_SOFT),
                            zoom(tile, 4)], "v", 2))
    return stack(cells, "h", 6)


def _clump_phases():
    out = []
    for f, name in ((0, "frame 0"), (3, "frame 3: wings flicked, loose bees round, bodies bob")):
        im = clean_plate()
        put_clump(im, home_of(4), 14, seed=15, frame=f)
        out.append(stack([look.text_block(name, ZW * ZOOM, 15, "bold", look.INK_SOFT),
                          zoom(im.crop(_around(art_px_mid(home_of(4)), ZW, ZW - 30)), ZOOM)],
                         "v", 2))
    return stack(out, "h", 10)


def header():
    """Today's step beside the new bee in the air, which all three options share."""
    today = look.plate("catch")
    small = look.downsample(today, G)
    new = scene("A", 2)
    hx, hy = art_px_mid(HEAD)
    parts = [
        panel(small, "today, at 1/3 (one pixel an art pixel)"),
        panel(today.crop(TODAY_BOX), "today's box, 1:1"),
        panel(zoom(today.crop(TODAY_SKY), 2), "today's clump in the sky, 2x"),
        panel(zoom(today.crop(TODAY_DRAG), 2), "today's dragged clump, 2x"),
        panel(_clump_phases(), "all three: a clump waiting in the sky, two frames, 3x"),
        panel(zoom(new.crop((hx - 100, hy - 190, hx + 106, hy + 60)), ZOOM),
              "all three: the clump in hand, cursor on top, 3x"),
        panel(new.crop(_around(art_px_mid(home_of(4)), 300, 260)),
              "all three: a waiting clump at 1:1"),
        panel(_bee_strip(), "the shared bee's frames, 4x (12 screen px an art px)"),
    ]
    return flow(parts, 1920 + 16 + COLUMN, 16)


NOTES = (
    "How it plays, unchanged: five clumps wait in the sky at the step's homes; press on one and "
    "drag, its bees chase the pointer at their own paces and string out behind it; hold it "
    "still and the trail gathers back into a ball round the pointer; let go over the box and it "
    "pours in. The box is today's size and place (its foot on art (318, 302)), a five-frame nuc "
    "in the hive's sky-blue paint (build_hive PAINTS['sky'], all four steps used as stepped "
    "bands: a proud rim band lit along its top with its shadow under it, two boards bevelled "
    "lit-top and shaded-foot, a proud plinth, the paint stepping darker towards the shaded "
    "right through a 2x2 dither on the front-on box, or a shaded side face on the turned one), "
    "lid off, the frames' pine showing. Box joints at both corners show the pine end grain "
    "every other tab; the paint is worn at the rim's and plinth's ends. The carcass and the "
    "counter are separate choices: A and B are front-on, C is turned a few degrees so its side "
    "and a cut hand-hold show, and any counter goes on either. Each option counts once: A the "
    "bees on the frames, B the window, C the carvings (its two bar bees and every option's "
    "guard bee on the landing board are the same at every count). The shadow is the footprint "
    "by the wash room's perspective thrown down-right by the room's top-left sun, a solid core "
    "and a checkered fringe, blades over the foot. A clump is about fourteen of look.py's bee "
    "(variant A, 10x7), a bee's width apart; the back rows a step darker with wings tucked, the "
    "middle crawling wingless, the outer ring hovering and looking out, soft brown where two "
    "touch and one ink outline round the lot, three loose bees on slow orbits. The cursor is "
    "the hardware cursor and draws over every bee. Every colour is a swatch or a mix of two; "
    "every sprite wears the 24,18,17 outline; everything sits on the plate's 3 px lattice. "
    "Two changes to the step's numbers come with the bigger bee: the middle home moves 8 art "
    "px down (338, 74), and the loose wanderers go 28 to 10. Flagged, not fixed here: the "
    "flower bed's white row cut flat along the window's foot belongs to the backdrop sheet, "
    "and the square slab in the big cloud's shadow at about (1440-1477, 287-337) is in the "
    "game's own capture, so a backdrop bug for build_wash_backdrop / the room's sky.")


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    opts = [option(o) for o in "ABC"]
    look.sheet("CATCH: THE NUC BOX AND THE SWARM", [header()] + opts, OUT_PATH,
               subtitle=("The catch step redrawn at real scale on the catch plate "
                         "(tools/last_hive_room_catch.png, 1920x1080, 3 screen px an art px) as the "
                         "backdrop sheet's recommended view shows it: no rubbish, ferry or dog, a bed "
                         "of flowers along the foot. Three ways for the box to say how full it is "
                         "and to answer a clump held over it; C also tries a turned carcass. A is "
                         "recommended."),
               notes=NOTES)
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

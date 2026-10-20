#!/usr/bin/env python
"""The smoke sheet (2026-10-16/17, the hive overhaul): the smoke step redrawn three ways, A / B / C.

OFFLINE MOCKUP ONLY. Writes tools/hive_look/last_smoke.png (and scratch under
tools/hive_look/_scratch_smoke/). Third pass (2026-10-17), off an art director's review.

Every option is drawn ON tools/last_hive_room_smoke.png at the room's own grain (3 screen px an
art px, the room a 640 x 360 art grid, measured), in one state of the step: the TOP of the beard
already smoked quiet, the MIDDLE band being smoked now, the entrance still to come. Beside each,
3x nearest crops, four frames of the motion at 2x (the bellows open, half, shut, half; the smoke
stepping 3 art px a frame) and the same at 1x.

The plate is cleaned first (`clean_plate`): today's beard, rings, smoke, smoker and wandering
bees come off; below the sky it is the backdrop sheet's recommended look, borrowed from
backdrop_mockup.py (no rubbish, no ferries, no dogs, the island's flowers along the foreground
lawn with bees at them). The game's own hive piece goes back where it stood. Every bee is
look.bee A (the coin bee) through look.bee_keyed's fixed ramp swaps: three hard light steps, a
calm step, a warm step, the under layer's; no per-bee lerp, every top bee keeps its outline.

The three options differ on every axis:
  A  marks: the bees themselves (rim whirring, buzz arcs, bees popping off; asleep, Zs).
     Smoke: separate billows, one a pump, along the band's edge to a curl that breaks up.
     Smoker: held in a leather glove, a stepped shadow on the path.
  B  marks: a ring of bees flying round the band, pollen trails. Smoke: one continuous column,
     parted where the pump paused. Smoker: standing on the lawn, its shadow, the column bending
     to the pointer.
  C  beard read: one dark mass, faces only on its rim. Marks: a warm flickering step and warm
     motes; sleep bubbles. Smoke: one long thin scarf wrapped round the band. Smoker: hung from
     the game's own pointer.

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages"         python tools/hive_look/smoke_mockup.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
from look import ROOM_GRAIN, zoom, panel, stack, flow, SW, OUT  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402
import numpy as np  # noqa: E402

bh = look.bh
OUT_PATH = os.path.join(look.HERE, "last_smoke.png")
SCRATCH = os.path.join(look.HERE, "_scratch_smoke")
V = "A"                      # the coin bee
G = ROOM_GRAIN
RECOMMEND = "A"
CROP_ZOOM = 3

# --- the step's own numbers (scripts/hive_step_smoke.gd), art px of the 640 x 360 room -------
HIVE_FEET = (233, 304)
HIVE_TL = (150, 96)              # hive_front's feet anchor (83, 208) on HIVE_FEET
ENTRANCE = (233, 264)            # hive_front's entrance anchor
RINGS = [(236, 142), (236, 178), (233, 246)]
RING_HALVES = [(50, 17), (56, 16), (40, 13)]
BAND_TO = [158, 194]             # the beard's rows each band runs down to
MASS_TOP, MASS_TALL = 124, 100   # the beard's rows
CX = HIVE_FEET[0] + 3.0          # the beard's middle


# =============================================================================================
# Cleaning the plate
# =============================================================================================
OLD_GOLD = np.array(bh.BEE_GOLD[:3])
OLD_DARK = [bh.BEE_STRIPE[:3], bh.BEE_THORAX[:3], bh.BEE_HEAD[:3], OUT[:3]]
UI_BOXES = [(756, 0, 1166, 120), (1822, 12, 1898, 68), (528, 950, 1396, 1046)]   # plank, X, hint


def _fill_rows(a, mask):
    """Every masked pixel takes the nearest unmasked pixel in its own row (left or right)."""
    for y in np.where(mask.any(1))[0]:
        row = mask[y]
        good = np.where(~row)[0]
        if good.size == 0:
            continue
        bad = np.where(row)[0]
        idx = np.searchsorted(good, bad)
        left = good[np.clip(idx - 1, 0, good.size - 1)]
        right = good[np.clip(idx, 0, good.size - 1)]
        pick = np.where(np.abs(bad - left) <= np.abs(right - bad), left, right)
        a[y, bad] = a[y, pick]


def _bee_mask(a, box):
    """Today's bees inside `box` (plate px): their gold, the dark parts and outline beside it, and
    the pale wings over them. Seeded on the gold, so a ground with dark pixels of its own (the
    trees' outlines) keeps them."""
    x0, y0, x1, y1 = box
    sub = a[y0:y1, x0:x1, :3].astype(int)
    gold = (np.abs(sub - OLD_GOLD).sum(-1) < 6)
    dark = np.zeros_like(gold)
    for c in OLD_DARK:
        dark |= (np.abs(sub - np.array(c)).sum(-1) < 6)
    pale = (sub[..., 0] > 170) & (sub[..., 1] > 190) & (sub[..., 2] > 190)
    near = gold.copy()
    for k in range(22):          # gold grown 22 px each way: a bee is 9 x 8 art px at 3 px
        g = near.copy()
        g[1:] |= near[:-1]
        g[:-1] |= near[1:]
        g[:, 1:] |= near[:, :-1]
        g[:, :-1] |= near[:, 1:]
        near = g
    m = gold | (dark & near) | (pale & near)
    full = np.zeros(a.shape[:2], bool)
    full[y0:y1, x0:x1] = m
    return full


def _copy_cols(a, src, box, dx):
    """Plate px `box` of `a` takes `src`'s pixels from `dx` along the same rows."""
    x0, y0, x1, y1 = box
    a[y0:y1, x0:x1] = src[y0:y1, x0 + dx:x1 + dx]


def _lake_fill(a, y0, y1, x0=0, x1=1920):
    """The lake band's rows: whatever is not one of a row's own water colours (the colours that
    fill at least 6% of it) takes the nearest water pixel in that row. Rubbish, the ferry, the
    hive and today's smoke all go; the water's flat bands and its long streaks stay."""
    keep_out = {(0, 0, 0), OUT[:3]}
    mask = np.zeros(a.shape[:2], bool)
    for y in range(y0, y1):
        row = a[y, x0:x1, :3]
        cols, counts = np.unique(row.reshape(-1, 3), axis=0, return_counts=True)
        water = [tuple(c) for c, n in zip(cols, counts) if n >= 0.06 * (x1 - x0)
                 and tuple(c) not in keep_out]
        ok = np.zeros(row.shape[0], bool)
        for c in water:
            ok |= (row == np.array(c)).all(-1)
        mask[y, x0:x1] = ~ok
    _fill_rows(a, mask)


LAKE_STATE = 4                    # dirty: fitted off the plate (83% of the lake's cells match it)
HIVE_WORK = (420, 597, 990, 960)  # the hive's stand and its contact shadow on the lawn, plate px
BACKDROP_NOTE = ["today's view retouched (rubbish, ferry and dog off)"]


BACKDROP_CACHE = os.path.join(SCRATCH, "backdrop_view.png")


def _backdrop_view(a, smoke):
    """`a` (the cleaned plate) below the sky replaced by the backdrop sheet's recommended look:
    its bank strip over `a`'s own sky, its lake in LAKE_STATE, its lawn, the hive's stand and
    shadow lifted back off the capture (what differs from the clean lawn in HIVE_WORK), its veil,
    its bed and the bees at it. The backdrop sheet is its own work and its script moves under
    this one (2026-10-17: its OPTIONS changed shape while this sheet was being made), so the last
    view built is cached in the scratch folder and used whenever the borrow fails."""
    try:
        view = _borrow_backdrop(a, smoke)
        os.makedirs(SCRATCH, exist_ok=True)
        Image.fromarray(view).save(BACKDROP_CACHE)
        return view
    except Exception as e:
        print("backdrop sheet not borrowed:", repr(e))
    if os.path.exists(BACKDROP_CACHE):
        BACKDROP_NOTE[:] = ["the backdrop sheet's recommended look (its last build here, cached)"]
        cached = np.array(Image.open(BACKDROP_CACHE).convert("RGBA"))
        out = a.copy()
        out[350:] = cached[350:]
        return out
    return a


def _borrow_backdrop(a, smoke):
    import backdrop_mockup as bm
    opt = bm.RECOMMEND
    entry = bm.OPTIONS[opt]
    if len(entry) == 6:                       # the sheet's first shape
        title, bed, veil, plan, small_far, _cap = entry
    else:                                     # (title, bed, plan, caption), one veil for all
        title, bed, plan, _cap = entry
        veil, small_far = getattr(bm, "SCENE_VEIL", 0.0), False
    ink = bm.fit_ink(smoke)
    view = a.copy()
    bank, trees = bm.render_bank(smoke, ink, a.copy())
    view[bm.BANK_TOP:bm.LAKE_FAR, :, :3] = bank
    view[bm.LAKE_FAR:bm.LAKE_NEAR, :, :3] = bm.render_lake(
        LAKE_STATE, ink, streak_share=0.7 * (1.0 - 0.5 * (veil > 0)))
    lawn = bm.render_lawn(ink)
    view[bm.LAKE_NEAR:, :, :3] = lawn
    x0, y0, x1, y1 = HIVE_WORK
    cap = smoke[y0:y1, x0:x1]
    clean = lawn[y0 - bm.LAKE_NEAR:y1 - bm.LAKE_NEAR, x0:x1]
    work = np.abs(cap[..., :3].astype(int) - clean.astype(int)).max(-1) > 4
    view[y0:y1, x0:x1][work] = cap[work]
    view[..., 3] = 255
    if veil > 0:
        bm.apply_veil(view, veil, trees)
    laid = bm.lay_bed(view, bed())
    img = Image.fromarray(view)
    if isinstance(laid, tuple):               # (spots, silhouette, ...)
        spots, sil = laid[0], laid[1]
        used = []
        for k, part in enumerate(bm._halves(spots)):
            bm.bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
    else:
        spots = laid
        for k, part in enumerate(bm._halves(spots)):
            bm.bees_at_bed(img, part, plan, seed=5 + 4 * k)
    BACKDROP_NOTE[:] = ["the backdrop sheet's recommended %s (%s, veil %.1f, the lake %s as "
                        "captured)" % (opt, title.lower(), veil, bm.STATES[LAKE_STATE])]
    return np.array(img)


_CLEAN = None


def clean_plate():
    """The smoke plate with today's step taken off it and the backdrop's rubbish, ferry and dog
    gone; the game's hive piece back on its feet. Cached."""
    global _CLEAN
    if _CLEAN is not None:
        return _CLEAN.copy()
    smoke = look.plate("smoke")
    catch = look.plate("catch")
    a = np.array(smoke)
    c = np.array(catch)
    ui = a.copy()
    # 1. the treeline under today's smoke and the beard's edge: the catch plate's, the same trees
    #    pixel for pixel; the ferry's: the same rows 150 px along, where nothing stands
    a[354:482, 438:1011] = c[354:482, 438:1011]
    _copy_cols(a, a.copy(), (1212, 354, 1380, 482), -150)
    # 2. the bees left in the sky, on the trees and on the catch rows just borrowed; the catch
    #    rows bring two pieces of its far-bank rubbish, which the same rows further along do not
    _fill_rows(a, _bee_mask(a, (0, 0, 1920, 482)))
    _copy_cols(a, a.copy(), (900, 440, 1062, 482), 450)
    # 3. the far strip and the lake: rubbish, the ferry's hull and today's smoke, row by row
    _lake_fill(a, 482, 600)
    # 4. the near beach and the lawn: the smoker and the dog, from clean stretches of the same rows
    _copy_cols(a, a.copy(), (996, 600, 1262, 812), 300)
    _copy_cols(a, a.copy(), (1518, 548, 1704, 690), -240)
    # 5. bees on the beach and the lawn
    _fill_rows(a, _bee_mask(a, (0, 600, 1920, 1080)))
    # 5b. below the sky, the backdrop sheet's recommended look (as the pour sheet borrows it):
    #     the bank re-laid, the lake redrawn with nothing on it, the lawn redrawn, the veil, the
    #     flower bed and its bees. Without that script, the retouched view above stands.
    a = _backdrop_view(a, np.array(smoke))
    # 6. the UI keeps what it was
    for x0, y0, x1, y1 in UI_BOXES:
        a[y0:y1, x0:x1] = ui[y0:y1, x0:x1]
    out = Image.fromarray(a)
    hive, _ = look.room_piece("hive_front")
    look.place_art(out, hive, HIVE_TL, G)
    _CLEAN = out
    return out.copy()


# =============================================================================================
# Small pixel tools
# =============================================================================================
STEEL = bh.STEEL
BRASS = bh.BRASS
LEATHER = bh.LEATHER
SMOKE_T = bh.SMOKE_T                          # the billows' four greys, palest first
SMOKE_INK = look.mix(SMOKE_T[3], OUT, 0.42)   # a puff's outline: its own deepest grey, darkened
GLOVE_L = {"lit": (252, 234, 178, 255), "base": (236, 206, 136, 255), "shade": (200, 164, 96, 255),
           "deep": (160, 122, 66, 255)}       # build_hive.glove's leather, and one step under
GLOVE_C = {"lit": (252, 252, 246, 255), "base": (234, 234, 224, 255), "shade": (196, 196, 184, 255)}
GROUND_SHADE = (0.72, 0.72, 0.86)             # the hive's own contact shadow on the lawn, measured
FUR = SW["bark_deep"]                         # what shows between the bees inside the mass
CALM_TO = SW["sky_low"]                       # the band asleep pales a little towards the sky


def lay(layer, im, at, anchor=(0, 0)):
    """Composite a 1x sprite onto a 1x layer so its `anchor` lands on art pixel `at`; clipped."""
    x = int(round(at[0])) - anchor[0]
    y = int(round(at[1])) - anchor[1]
    box = (max(0, -x), max(0, -y), min(im.width, layer.width - x), min(im.height, layer.height - y))
    if box[2] <= box[0] or box[3] <= box[1]:
        return layer
    layer.alpha_composite(im.crop(box), (x + box[0], y + box[1]))
    return layer


def blank():
    return Image.new("RGBA", look.ROOM_GRID, (0, 0, 0, 0))


def dilate(mask, n=1, diag=False):
    m = mask.copy()
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]
        g[:-1] |= m[1:]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        if diag:
            g[1:, 1:] |= m[:-1, :-1]
            g[1:, :-1] |= m[:-1, 1:]
            g[:-1, 1:] |= m[1:, :-1]
            g[:-1, :-1] |= m[1:, 1:]
        m = g
    return m


def fill_holes(mask):
    """Close the holes inside a mask: everything not reachable from the border is inside."""
    h, w = mask.shape
    outside = np.zeros_like(mask)
    outside[0, :] = ~mask[0, :]
    outside[-1, :] = ~mask[-1, :]
    outside[:, 0] = ~mask[:, 0]
    outside[:, -1] = ~mask[:, -1]
    while True:
        g = dilate(outside) & ~mask
        if (g == outside).all():
            break
        outside = g
    return ~outside


def deinked(im, col):
    """The sprite's outline (and eye, feelers) repainted in `col`: a bee seen deep in the mass,
    its edges blurred into the fur rather than ringed."""
    a = np.array(im)
    m = (a[..., 3] > 0) & (a[..., 0] == OUT[0]) & (a[..., 1] == OUT[1]) & (a[..., 2] == OUT[2])
    a[m] = col
    return Image.fromarray(a)


def star_at(layer, x, y, arm=2):
    a = bh.Art(layer.width, layer.height)
    a.im = layer
    a.d = ImageDraw.Draw(layer)
    bh.star(a, int(x), int(y), arm)
    return layer


def ellipse_cells(cx, cy, hx, hy):
    """Whole art pixels of an ellipse (plate px are art px x G)."""
    out = []
    for y in range(int(cy - hy), int(cy + hy) + 1):
        dy = (y + 0.5 - cy) / hy
        if abs(dy) >= 1:
            continue
        w = hx * math.sqrt(1 - dy * dy)
        for x in range(int(round(cx - w)), int(round(cx + w))):
            out.append((x, y))
    return out


def ground_shadow(plate_im, middle, half, flat=(44, 63, 32)):
    """A contact shadow on the plate in the hive's own ink, an ellipse of whole art px, in place.
    `middle` and `half` in art px. Measured off the plate: the hive's shadow is the lawn
    multiplied by GROUND_SHADE, and on the lawn's base green that is (44, 63, 32), which fills two
    thirds of it; the lawn's pale speckle is held down to that flat ink and only the darker
    speckle shows through, so a small shadow reads as a shape and not as more speckle."""
    a = np.array(plate_im).astype(float)
    f = np.array(flat, float)
    for x, y in ellipse_cells(middle[0], middle[1], half[0], half[1]):
        sy, sx = y * G, x * G
        cell = a[sy:sy + G, sx:sx + G, :3]
        dark = cell * np.array(GROUND_SHADE)
        light = cell.sum(-1, keepdims=True) > f.sum()
        a[sy:sy + G, sx:sx + G, :3] = np.where(light, f, dark)
    plate_im.paste(Image.fromarray(a.astype(np.uint8)))
    return plate_im


def tint_cells(base1x, cells, toward, t):
    """An overlay at 1x: each cell of `cells` (a bool mask) is the 1x base's colour mixed `t`
    towards `toward`."""
    b = np.array(base1x).astype(float)
    out = np.zeros(b.shape, np.uint8)
    col = np.array(toward[:3], float)
    mix_ = b[..., :3] * (1 - t) + col * t
    out[cells, :3] = np.round(mix_[cells]).astype(np.uint8)
    out[cells, 3] = 255
    return Image.fromarray(out)


# =============================================================================================
# Bee sprites in steps. Every bee is look.bee A drawn through look.bee_keyed with one of a few
# fixed ramp swaps: three light steps off the room's top-left sun (lit / mid / shade), the calm
# step (one step paler, eyes shut, wings folded), the warm step (C: the coin's gold swapped for
# the honey's), and the under layer's (two steps down, its outline in the fur's brown). The
# outline 'O' is never swapped on a top bee: every bee keeps its (24, 18, 17) ring.
# =============================================================================================
def _m(a, b, t=0.5):
    return look.mix(a, b, t)


TOP = {
    "lit": {"W": SW["water_shallow"], "V": SW["water_mid"]},
    "mid": {"L": SW["coin"], "G": SW["coin_shade"], "S": SW["coin_low"], "D": SW["coin_deep"],
            "k": SW["gold_shade"], "W": SW["water_mid"], "V": _m(SW["water_mid"], SW["stripe"]),
            "c": SW["roof"]},
    "shade": {"L": SW["coin_shade"], "G": SW["coin_low"], "S": SW["coin_deep"], "D": SW["gold_deep"],
              "K": SW["gold_shade"], "k": SW["gold_shade"], "W": _m(SW["water_mid"], SW["stripe"]),
              "V": SW["bark_deep"], "c": SW["roof_shade"]},
}
_CALM_LIT = {"L": SW["coin_pale"], "G": SW["coin_lit"], "S": SW["coin"], "D": SW["coin_shade"],
             "K": SW["gold_deep"], "k": SW["gold_low"], "W": SW["water_light"], "V": SW["water_shallow"],
             "c": SW["roof_lit"]}
CALM = {"lit": _CALM_LIT, "mid": _CALM_LIT, "shade": {"W": SW["water_shallow"], "V": SW["water_mid"]}}
WARM = {
    "lit": {"L": SW["honey_shine"], "G": SW["honey_light"], "S": SW["honey"], "D": SW["honey_mid"],
            "k": SW["honey_deep"], "W": SW["coin_pale"], "V": SW["coin_lit"]},
    "mid": {"L": SW["honey_light"], "G": SW["honey"], "S": SW["honey_mid"], "D": SW["honey_deep"],
            "k": SW["gold_shade"], "W": SW["coin_lit"], "V": SW["coin_shade"]},
    "shade": {"L": SW["honey"], "G": SW["honey_mid"], "S": SW["honey_deep"], "D": SW["gold_deep"],
              "K": SW["gold_shade"], "k": SW["gold_shade"], "W": SW["coin_shade"], "V": SW["coin_low"]},
}
FUR = {"lit": SW["bark_deep"], "mid": _m(SW["bark_deep"], SW["stripe"]), "shade": SW["stripe"]}
_DEEP_WING = SW["bark_deep"]
FUR_MID = _m(SW["bark_deep"], SW["stripe"])
UNDER = {
    "lit": {"L": SW["coin_shade"], "G": SW["coin_low"], "S": SW["coin_deep"], "D": SW["gold_deep"],
            "K": SW["gold_shade"], "k": SW["gold_deep"], "W": SW["bark"], "V": SW["bark_deep"],
            "w": SW["coin_low"], "c": SW["coin_deep"]},
    "mid": {"L": SW["coin_low"], "G": SW["coin_deep"], "S": SW["gold_deep"], "D": SW["gold_shade"],
            "K": SW["stripe"], "k": SW["gold_shade"], "W": SW["bark_deep"], "V": SW["bark_deep"],
            "w": SW["coin_deep"], "c": SW["gold_deep"]},
    "shade": {"L": SW["coin_deep"], "G": SW["gold_deep"], "S": SW["gold_shade"], "D": SW["stripe"],
              "K": SW["stripe"], "k": SW["stripe"], "W": FUR_MID, "V": FUR_MID,
              "w": SW["gold_deep"], "c": SW["gold_shade"]},
}
for _s in UNDER:
    for _ch in "OEAT":
        UNDER[_s][_ch] = FUR[_s]
STEPS = ("lit", "mid", "shade")


def down(step, n=1):
    return STEPS[min(2, STEPS.index(step) + n)]


def sprite(x, y, pose="walk", frame=0, left=False, turn=0, over=None, face=True):
    """(sprite, anchor) of the coin bee through a ramp swap, anchored on its body's middle."""
    spr = look.bee_keyed(V, frame, facing_left=left, pose=pose, turn=turn, over=over, face=face)
    if turn:
        return spr, (spr.width // 2, spr.height // 2)
    return spr, look.bee_anchor(V, pose, left, frame)


def put(layer, x, y, **kw):
    spr, an = sprite(x, y, **kw)
    return lay(layer, spr, (x, y), an)


# the agitated rim bee's 2-frame wing flicker: wings up (look's own), then a blurred fan in the
# wing swatches, ringed, on the same back
_FAN = {"far": (["OOOO.", "OVVVO", ".OOO."], 0, -2),
        "near": (["..OOOO.", ".OWWWVO", "OVVVVVO", ".OOOOO."], 1, -4)}
WHIRR = {"W": SW["foam"], "V": SW["water_light"]}       # a working wing keeps its pale swatches


def buzzing(frame, left, over=None):
    """A bee whirring in place: even frames the look wings up, odd frames a blurred fan."""
    over = dict(over or {})
    over.update(WHIRR)
    if frame % 2 == 0:
        return look.bee_keyed(V, 0, facing_left=left, pose="hover", over=over)
    k = dict(look.key(V))
    if over:
        k.update(over)
    spec = look._SPEC[V]
    bx, by = look.BODY_AT
    im = Image.new("RGBA", look.BEE_CANVAS, (0, 0, 0, 0))
    rows, wx, wy = _FAN["far"]
    look.grid(rows, k, bx + wx, by + wy, into=im)
    look.grid(look._body(spec), k, bx, by, into=im)
    for x, y, ch in spec["extra"]:
        look.grid([ch], k, bx + x, by + y, into=im)
    rows, wx, wy = _FAN["near"]
    look.grid(rows, k, bx + wx, by + wy, into=im)
    return look.flip(im) if left else im


# =============================================================================================
# The beard: hung under the gable's lower half (a strip of the pale gable and its knob left
# showing above it, two bees crawling on it), lumpy lobes bulging at mid height, three festoon
# chains off its foot, a few bees walking on the box below.
# =============================================================================================
MASS_TOP = 135
BAND_TO = [162, 197]
MASS_BOT = 233
MID_Y = 184
# (dx from CX, cy, half across, half down): the lobes the mass hangs in
LOBES = [(0, 142, 30, 7), (-18, 151, 22, 11), (17, 150, 24, 11),
         (-25, 175, 25, 19), (26, 180, 26, 20), (0, 171, 32, 22),
         (-13, 203, 23, 16), (12, 207, 21, 16), (-2, 221, 14, 10), (4, 228, 8, 6)]


def in_mass(x, y, inset=0.0):
    for dx, cy, hx, hy in LOBES:
        ax, ay = hx - inset, hy - inset * 0.75
        if ax <= 0.5 or ay <= 0.5:
            continue
        if ((x - CX - dx) / ax) ** 2 + ((y - cy) / ay) ** 2 <= 1.0:
            return True
    return False


def band_rows(band):
    top = MASS_TOP if band == 0 else BAND_TO[band - 1]
    bot = BAND_TO[band] if band < 2 else MASS_BOT + 4
    return top, bot


def _band(y):
    for b, to in enumerate(BAND_TO):
        if y < to:
            return b
    return 2


def _light(x, y):
    """0 on the beard's lit top-left, 1 on its shaded bottom-right."""
    return max(0.0, min(1.0, 0.5 + (x - CX) / 110.0 + (y - MID_Y) / 150.0))


def step_at(x, y):
    l = _light(x, y)
    return "lit" if l < 0.42 else "mid" if l < 0.72 else "shade"


def _points(seed, spacing, inset, n_try=14000):
    rng = random.Random(seed)
    sx, sy = spacing
    mine = []
    for _ in range(n_try):
        x = rng.uniform(CX - 60, CX + 60)
        y = rng.uniform(MASS_TOP - 2, MASS_BOT + 2)
        if not in_mass(x, y, inset):
            continue
        if all(((x - a) / sx) ** 2 + ((y - b) / sy) ** 2 >= 1.0 for a, b in mine):
            mine.append((x, y))
    return mine


def edge_distance(mask, most=10):
    d = np.full(mask.shape, most, int)
    cur = mask.copy()
    for k in range(most):
        er = cur.copy()
        er[1:] &= cur[:-1]
        er[:-1] &= cur[1:]
        er[:, 1:] &= cur[:, :-1]
        er[:, :-1] &= cur[:, 1:]
        d[cur & ~er] = k
        cur = er
    d[~mask] = -1
    return d


RIM_EVERY = 7.5
RIM_PX = 7                               # how far in from the silhouette a top bee is on the rim
FESTOONS = [(-15, 4), (6, 3), (21, 3)]          # (dx from CX, links) off the beard's foot
WALKERS = [(198, 246, False, 0), (277, 241, True, 1), (214, 131, False, 0), (259, 132, True, 0)]


def beard(states, seed=4101, frame=0, read="faces", lift_off=0, warm=False, guards=True):
    """The beard. states[b] per band: 'calm' (asleep: wings folded, eyes shut, one step paler),
    'agitated' (its rim bees whirring with a 1-px jitter that changes with `frame`, its inside
    bees awake and shuffling) or 'waiting' (crawling and resting).

    read 'faces' (A, B): an under layer packed tight, two steps down and lit in three hard steps,
    under a top layer where only about a third of the bees show their faces, the rest crawling
    up, down or away. read 'rim' (C): the under layer a step darker still, the faces only along
    the rim, a few gold backs inside. warm (C): the agitated band's fur and wings a step warmer,
    flickering with the frame.

    Returns {'under', 'top': [band images], 'festoon', 'walkers', 'guards', 'mask', 'dist',
    'lifted'}."""
    rng = random.Random(seed)
    agit = states.index("agitated") if "agitated" in states else -1
    flick = warm and frame % 2 == 0
    under = blank()
    for x, y in _points(seed, (5.0, 3.6), 0.5):
        st = step_at(x, y)
        if read == "rim":
            st = down(st)
        over = UNDER[st]
        if warm and _band(y) == agit:
            over = dict(UNDER[STEPS[max(0, STEPS.index(st) - 1)]])
            over.update({"G": SW["honey_mid"] if flick else SW["honey_deep"], "L": SW["honey"]})
        pose = rng.choice(("walk", "rest", "walk"))
        put(under, x, y, pose=pose, frame=rng.randrange(4), left=rng.random() < 0.5,
            turn=rng.choice((0, 0, 1, 3)), over=over, face=rng.random() < 0.4)
    al = np.array(under)
    mask = fill_holes(al[..., 3] > 0)
    holes = mask & (al[..., 3] == 0)
    yy, xx = np.indices(mask.shape)
    for y, x in zip(*np.where(holes)):
        st = step_at(x, y)
        if read == "rim":
            st = down(st)
        col = FUR[st]
        if warm and _band(y) == agit:
            col = SW["honey_deep"] if flick else _m(SW["honey_deep"], SW["bark_deep"])
        al[y, x] = col
    under = look.ring(Image.fromarray(al))
    mask = np.array(under)[..., 3] > 0
    dist = edge_distance(mask)

    top = [blank() for _ in range(3)]
    pts = _points(seed + 1, (6.6, 4.4), 3.0)
    pts.sort(key=lambda p: p[1] + rng.uniform(-3.5, 3.5))
    for x, y in pts:
        b = _band(y)
        st_name = states[b]
        d = dist[int(y), int(x)] if 0 <= int(y) < dist.shape[0] else 9
        rim = d <= RIM_PX
        if read == "rim" and not rim and rng.random() > 0.18:
            continue
        step = step_at(x, y)
        if read == "rim" and not rim:
            step = down(step)
        L = top[b]
        r = rng.random()
        left = rng.random() < 0.5 if not rim else (x < CX) ^ (rng.random() < 0.25)
        phase = rng.randrange(6)
        if read == "rim" and not rim:
            put(L, x, y, pose="walk", frame=frame + phase, left=left, turn=rng.choice((0, 1, 3)),
                over=TOP[step], face=False)
            continue
        if st_name == "calm":
            over = CALM[step]
            if r < 0.36:
                put(L, x, y + 1, pose="rest", frame=3, left=left, over=over)
            elif r < 0.62:
                put(L, x, y + 1, pose="rest", frame=3, left=left, turn=rng.choice((1, 3)), over=over)
            else:
                put(L, x, y + 1, pose="rest", frame=0, left=left, turn=rng.choice((0, 0, 1, 3)),
                    over=over, face=False)
        elif st_name == "agitated":
            over = (WARM[step] if flick else TOP[step]) if warm else TOP[step]
            if rim:
                jr = random.Random(seed * 31 + int(x * 7 + y * 13) + frame * 977)
                jx, jy = jr.choice((-1, 0, 1)), jr.choice((-1, 0, 0, 1))
                spr = buzzing(frame + phase, left, over)
                lay(L, spr, (x + jx, y + jy), look.bee_anchor(V, "hover", left, 0))
            elif r < 0.45:
                put(L, x, y, pose="walk", frame=frame + phase, left=left, over=over)
            elif r < 0.75:
                put(L, x, y, pose="walk", frame=frame + phase, left=left, turn=rng.choice((1, 3)),
                    over=over)
            else:
                put(L, x, y, pose="walk", frame=frame + phase, left=left,
                    turn=rng.choice((0, 1, 3)), over=over, face=False)
        else:
            over = TOP[step]
            if r < 0.3:
                put(L, x, y, pose=rng.choice(("walk", "rest")), frame=phase % 3, left=left, over=over)
            elif r < 0.6:
                put(L, x, y, pose="walk", frame=frame + phase, left=left, turn=rng.choice((1, 3)),
                    over=over)
            else:
                put(L, x, y, pose="walk", frame=frame + phase, left=left,
                    turn=rng.choice((0, 0, 1, 3)), over=over, face=False)
    # C: faces walked round the silhouette, 3 px in from it, one every RIM_EVERY px of edge
    if read == "rim":
        ys_, xs_ = np.where(dist == 0)
        mx, my = xs_.mean(), ys_.mean()
        ang = np.arctan2(ys_ - my, xs_ - mx)
        order = np.argsort(ang)
        last = None
        for i in order:
            x, y = float(xs_[i]), float(ys_[i])
            if last is not None and math.hypot(x - last[0], y - last[1]) < RIM_EVERY:
                continue
            last = (x, y)
            b = _band(y)
            if states[b] == "agitated":
                continue                     # its rim is the whirring bees below
            n = math.hypot(mx - x, my - y) or 1.0
            x, y = x + (mx - x) / n * 3.5, y + (my - y) / n * 3.0
            step = step_at(x, y)
            roll = rng.random()
            turn = 0 if roll < 0.45 else rng.choice((1, 3))
            face = roll < 0.75
            if states[b] == "calm":
                put(top[b], x, y + 1, pose="rest", frame=3, left=(x < mx) ^ (rng.random() < 0.3),
                    over=CALM[step], turn=turn, face=face)
            else:
                put(top[b], x, y, pose="walk", frame=frame + i, left=x < mx, over=TOP[step],
                    turn=0 if rng.random() < 0.7 else rng.choice((1, 3)))
    # the agitated band's rim: a whirring bee every few rows down both sides of the silhouette,
    # facing out, each with its own px of jitter, so the band's edge visibly shivers
    if agit >= 0:
        t0, t1 = band_rows(agit)
        L = top[agit]
        for k, y in enumerate(range(t0 + 2, t1 - 1, 5)):
            cols = np.where(mask[y])[0]
            if not cols.size:
                continue
            for side, edge in ((-1, cols.min()), (1, cols.max())):
                yy_ = y + (2 if side > 0 else 0)
                jr = random.Random(seed * 17 + y * 3 + side + frame * 911)
                jx, jy = jr.choice((-1, 0, 1)), jr.choice((-1, 0, 0, 1))
                x = edge - side * 3
                step = step_at(x, yy_)
                over = (WARM[step] if flick else TOP[step]) if warm else TOP[step]
                spr = buzzing(frame + k + (side > 0), side < 0, over)
                lay(L, spr, (x + jx, yy_ + jy), look.bee_anchor(V, "hover", side < 0, 0))
    # festoons: chains of bees hanging leg to leg off the foot, swaying a px
    fest = blank()
    for i, (dx, n) in enumerate(FESTOONS):
        x = int(round(CX + dx))
        col = np.where(mask[:, x])[0]
        y = col.max() - 2 if col.size else MASS_BOT
        for k in range(n):
            sway = int(round(math.sin(k * 1.4 + i + frame * 0.7) * (k > 0)))
            st = "shade" if dx > 8 else "mid"
            put(fest, x + sway, y + 3 + k * 5, pose="rest" if k == n - 1 else "walk",
                frame=frame + k, left=(k + i) % 2 == 0, turn=3 if (k + i) % 2 else 1,
                over=TOP[st], face=k == n - 1)
    walk = blank()
    for x, y, left, turn in WALKERS:
        put(walk, x, y, pose="walk", frame=frame, left=left, turn=turn, over=TOP[step_at(x, y)])
    g = blank()
    if guards:
        for dx, dy, pose, left, f in ((-17, 8, "walk", False, 0), (-6, 9, "rest", True, 1),
                                      (8, 8, "walk", True, 1), (19, 9, "rest", False, 2)):
            put(g, ENTRANCE[0] + dx, ENTRANCE[1] + dy, pose=pose, frame=frame + f, left=left)
        put(g, ENTRANCE[0] + 34, ENTRANCE[1] - 5, pose="fly", frame=frame + 2, left=True)
    lifted = []
    if agit >= 0 and lift_off:
        t0, t1 = band_rows(agit)
        for k in range(lift_off):
            y = t0 + 2
            cols = np.where(mask[int(y)])[0]
            x = (cols.min() if cols.size else CX - 50) - 4 - k * 9
            y = y - 6 - k * 6 - frame % 2
            put(top[agit], x, y, pose="fly", frame=frame + k, left=True)
            lifted.append((x, y, -1))
    return {"under": under, "top": top, "festoon": fest, "walkers": walk, "guards": g,
            "mask": mask, "dist": dist, "lifted": lifted}


def beard_layers(b):
    return [b["under"], b["top"][0], b["top"][2], b["festoon"], b["walkers"], b["guards"], b["top"][1]]


# =============================================================================================
# The smoker, sized to the hive (the can about one hive box tall), lit from the room's top-left.
# The bellows: two wooden boards hinged at their foot, a pleated leather bag between them (three
# folds), a steel spring across their tops; the outer board swings 7 art px between open and shut.
# =============================================================================================
def smoker(squeeze=0.0, spout="left"):
    """At one px an art px, facing left. squeeze 0 open .. 1 shut. spout 'left' bends the nozzle
    over towards the hive (held), 'up' keeps it high (standing). Returns (inked image, anchors:
    nozzle, grip (the outer board's middle), top, feet, can)."""
    W, H = 68, 68
    a = bh.Art(W, H)
    x0, x1, y0, y1 = 12, 36, 30, 63
    w = x1 - x0

    def can(x, y):
        f = (x - x0) / float(w)
        if y >= y1 - 1:
            return STEEL["deep"]
        for edge, c in ((0.07, "base"), (0.16, "lit"), (0.27, "hi"), (0.52, "lit"), (0.76, "base"),
                        (0.9, "shade")):
            if f < edge:
                return STEEL[c]
        return STEEL["deep"]

    a.fill_by([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], can)
    for y in range(y0 + 11, y1 - 2, 3):
        for x in range(x0 + 2 + (y // 3) % 2, x1 - 1, 3):
            a.px(x, y, STEEL["deep"] if (x - x0) / w > 0.45 else STEEL["shade"])
    a.rect(x0, y0 + 9, w, 1, STEEL["shade"])
    a.rect(x0, y1 - 3, w, 1, STEEL["shade"])
    a.fill_by([(x0, y0), (x1, y0), (x1 - 6, y0 - 7), (x0 + 6, y0 - 7)],
              lambda x, y: STEEL["hi"] if x < x0 + 9 else STEEL["lit"] if x < x0 + 14 else STEEL["base"])
    a.rect(x0 - 1, y0 - 1, w + 2, 2, STEEL["lit"])
    a.rect(x0 - 1, y0, w + 2, 1, STEEL["shade"])
    if spout == "left":
        a.poly([(x0 + 6, y0 - 6), (x0 + 13, y0 - 6), (x0 + 7, y0 - 13), (x0 - 4, y0 - 15),
                (x0 - 7, y0 - 12), (x0 + 1, y0 - 9)], BRASS["base"])
        a.poly([(x0 + 7, y0 - 8), (x0 + 4, y0 - 11), (x0 - 4, y0 - 13), (x0 - 5, y0 - 12)], BRASS["lit"])
        a.rect(x0 - 8, y0 - 15, 3, 4, BRASS["shade"])
        a.rect(x0 - 8, y0 - 14, 1, 2, OUT)
        nozzle = (x0 - 8, y0 - 13)
    else:
        a.poly([(x0 + 6, y0 - 6), (x0 + 14, y0 - 6), (x0 + 11, y0 - 15), (x0 + 5, y0 - 19),
                (x0 + 1, y0 - 17), (x0 + 6, y0 - 12)], BRASS["base"])
        a.poly([(x0 + 7, y0 - 8), (x0 + 6, y0 - 12), (x0 + 3, y0 - 16), (x0 + 2, y0 - 16)], BRASS["lit"])
        a.rect(x0 + 1, y0 - 21, 4, 3, BRASS["shade"])
        a.rect(x0 + 2, y0 - 21, 2, 1, OUT)
        nozzle = (x0 + 3, y0 - 21)
    # the bellows
    inner = x1 + 3                                  # the fixed board's outer face
    hinge = (x1 + 3, y1 - 1)
    swing = 13.0 - 7.0 * squeeze
    tip = (inner + swing, y0 + 2 + 2 * squeeze)    # the outer board's top end
    crease = _m(LEATHER["shade"], OUT, 0.45)
    bag_top = y0 + 7

    def bag(x, y):
        ang_in = math.pi / 2
        ang_out = math.atan2(hinge[1] - tip[1], tip[0] - hinge[0])
        ang = math.atan2(hinge[1] - y, x - hinge[0] + 0.5)
        f = (ang_in - ang) / max(0.01, ang_in - ang_out)
        f = max(0.0, min(0.999, f))
        g = f * 3 - int(f * 3)
        if g > 0.88:
            return crease
        return LEATHER["lit"] if g < 0.4 else LEATHER["base"] if g < 0.72 else LEATHER["shade"]

    # the bag's top runs in a zigzag: each fold bulges up a px at its middle
    top_pts = []
    for k in range(4):
        f = k / 3.0
        top_pts.append((inner + 1 + (tip[0] - 2 - inner - 1) * f, bag_top + 2 * squeeze * f))
    zig = [top_pts[0]]
    for k in range(3):
        p, q = top_pts[k], top_pts[k + 1]
        zig.append(((p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0 - 1.5))
        zig.append(q)
    a.fill_by(zig + [(hinge[0] + 2, hinge[1] - 1), (inner + 1, hinge[1] - 1)], bag)
    # the spring across the boards' tops, over the bag
    sx0, sx1 = inner + 1, int(tip[0]) - 2
    for k, x in enumerate(range(sx0, sx1 + 1)):          # a coil: a zigzag lit over its shade
        y = y0 + 3 + (0, 1, 2, 1)[k % 4]
        a.px(x, y, STEEL["lit"])
        a.px(x, y + 1, STEEL["deep"])
    # the fixed board along the can, lit on its left
    a.rect(x1, y0 + 1, 3, y1 - y0 - 1, bh.DARK_WOOD)
    a.rect(x1, y0 + 1, 1, y1 - y0 - 1, bh.DARK_WOOD_HI)
    # the outer board: 3 px thick, its lit left edge, its top a little cap
    for t in range(0, 101):
        u = t / 100.0
        x = hinge[0] + (tip[0] - hinge[0]) * u
        y = hinge[1] + (tip[1] - hinge[1]) * u
        a.px(int(round(x)), int(round(y)), bh.PINE_SHADE)
        a.px(int(round(x)) + 1, int(round(y)), bh.DARK_WOOD_HI)
        a.px(int(round(x)) + 2, int(round(y)), bh.DARK_WOOD)
    a.rect(int(round(tip[0])) - 1, int(round(tip[1])) - 1, 5, 2, bh.DARK_WOOD_HI)
    a.rect(int(round(tip[0])) - 1, int(round(tip[1])) - 1, 5, 1, bh.PINE_SHADE)
    a.rect(hinge[0] - 1, hinge[1] - 3, 5, 3, BRASS["shade"])
    a.px(hinge[0], hinge[1] - 3, BRASS["lit"])
    im = look.inked(a.im)
    mid = ((hinge[0] + tip[0]) / 2.0 + 1, (hinge[1] + tip[1]) / 2.0)
    anchors = {"nozzle": (nozzle[0] + 1, nozzle[1] + 1),
               "grip": (int(round(mid[0])) + 1, int(round(mid[1])) + 1),
               "top": (int(round(tip[0])) + 2, int(round(tip[1])) + 1),
               "feet": ((x0 + x1) // 2 + 1, y1 + 1),
               "can": (x0 + 1, x1 + 1)}
    return im, anchors


SQUEEZE = (0.0, 0.5, 1.0, 0.5)      # open, half, shut, half: the four frames


def leather_mitt():
    """A yellow leather beekeeping glove gripping the outer board from behind: the back of the
    hand, four knuckles curled over its front edge, the thumb along its top, and a short canvas
    cuff running off down-right. build_hive.glove's leather and canvas, lit top-left. Returns
    (inked image, the pixel that goes on the board's middle)."""
    L = GLOVE_L
    C = GLOVE_C
    a = bh.Art(26, 26)
    a.poly([(11, 13), (19, 9), (25, 21), (16, 25)], C["base"])
    a.poly([(11, 13), (14, 12), (19, 24), (16, 25)], C["shade"])
    a.poly([(17, 10), (19, 9), (25, 21), (23, 22)], C["lit"])
    a.poly([(12, 15), (20, 11), (21, 13), (13, 17)], C["shade"])
    a.ell(3, 4, 15, 14, L["base"])
    a.ell(4, 4, 10, 8, L["lit"])
    a.ell(9, 10, 9, 8, L["shade"])
    for k in range(4):
        a.ell(0, 3 + k * 3, 5, 4, L["base"] if k < 2 else L["shade"])
        a.px(1, 4 + k * 3, L["lit"])
        if k:
            a.rect(1, 3 + k * 3, 3, 1, L["deep"])
    a.ell(6, 0, 10, 6, L["base"])
    a.rect(8, 1, 5, 1, L["lit"])
    a.rect(9, 4, 6, 1, L["shade"])
    a.line([(9, 8), (13, 14)], L["shade"])
    return look.inked(a.im), (9, 10)


def hover_shadow(base, middle, half, mul=(0.82, 0.82, 0.9)):
    """The stepped contact shadow of something held in the air: an ellipse of whole art px on the
    ground under it and down-right (the room's sun is top-left), the ground multiplied a step."""
    a = np.array(base).astype(float)
    for x, y in ellipse_cells(middle[0], middle[1], half[0], half[1]):
        sy, sx = y * G, x * G
        a[sy:sy + G, sx:sx + G, :3] *= np.array(mul)
    for x, y in ellipse_cells(middle[0], middle[1], half[0] * 0.55, max(1.0, half[1] * 0.6)):
        sy, sx = y * G, x * G
        a[sy:sy + G, sx:sx + G, :3] *= np.array(mul)
    base.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)))
    return base


# =============================================================================================
# Smoke. Bodies in the billows' middle greys (SMOKE_T[1..3]); white (SMOKE_T[0]) only as one lit
# lip on the upper left, so the smoke reads apart from the sky's white clouds. Each billow a few
# lobes with a rough edge, ringed the way the room is lit. Old ones thin from the rim inwards.
# =============================================================================================
def billow(r, seed, fade=0.0, lobes=3):
    rng = random.Random(seed)
    size = int(r * 3.2) + 8
    c = size / 2.0
    lob = [(c, c + r * 0.15, r)]
    for k in range(lobes):
        ang = -math.pi * (0.1 + 0.8 * (k + rng.uniform(0.1, 0.9)) / lobes)
        d = r * rng.uniform(0.5, 0.8)
        lob.append((c + math.cos(ang) * d * 1.25, c + math.sin(ang) * d * 0.85, r * rng.uniform(0.42, 0.68)))
    if r > 3 and rng.random() < 0.7:
        lob.append((c + rng.uniform(-0.7, 0.7) * r, c + r * 0.55, r * 0.42))
    ph = rng.uniform(0, math.tau)
    owner = np.full((size, size), -1)
    tone = np.zeros((size, size), int)
    for yy in range(size):
        for xx in range(size):
            best, who = 9.0, -1
            for i, (lx, ly, lr) in enumerate(lob):
                th = math.atan2(yy + 0.5 - ly, xx + 0.5 - lx)
                q = math.hypot(xx + 0.5 - lx, (yy + 0.5 - ly) * 1.1) / (lr * (1 + 0.11 * math.sin(4 * th + ph + i)))
                q -= 0.07 * (c - ly) / r
                if q < best:
                    best, who = q, i
            if best > 1.0:
                continue
            owner[yy, xx] = who
            lx, ly, lr = lob[who]
            s = (xx + 0.5 - lx) / lr * 0.6 + (yy + 0.5 - ly) / lr * 0.9 + 0.4 * (yy - c) / r
            tone[yy, xx] = 1 if s < -0.2 else 2 if s < 0.5 else 3
    inside = owner >= 0
    # creases: where a lower lobe tucks under one above it
    for yy in range(1, size):
        for xx in range(size):
            o, up = owner[yy, xx], owner[yy - 1, xx]
            if o >= 0 and up >= 0 and o != up and lob[o][1] > lob[up][1] + 0.5:
                tone[yy, xx] = 3
    # the lit lip: the rim facing up-left, one px in
    out_up = np.zeros_like(inside)
    out_up[1:] = ~inside[:-1]
    out_up[0] = True
    out_left = np.zeros_like(inside)
    out_left[:, 1:] = ~inside[:, :-1]
    out_left[:, 0] = True
    yy, xx = np.indices(inside.shape)
    lip = inside & (out_up | out_left) & (((xx - c) + (yy - c) * 1.2) < -r * 0.2)
    tone[lip] = 0
    arr = np.zeros((size, size, 4), np.uint8)
    for t in range(4):
        arr[inside & (tone == t)] = SMOKE_T[t]
    im = Image.fromarray(arr)
    dark = np.array(look.ring(im, SMOKE_INK))
    lit = np.array(look.ring(im, SMOKE_T[3]))
    upper_left = ((xx - c) + (yy - c) * 1.2) < -r * 0.35
    dark[upper_left & ~inside] = lit[upper_left & ~inside]
    im = Image.fromarray(dark)
    if fade > 0:
        # thinning: the rim gets ragged, a px here and there gone off the outline and then off
        # the outermost body ring, never a checker across the puff
        al = np.array(im)
        m = al[..., 3] > 0
        d = edge_distance(m, 8)
        h = (np.sin(xx * 12.9898 + yy * 78.233 + seed) * 43758.5453) % 1.0
        cut = m & (d == 0) & (h < fade * 1.2)
        cut |= m & (d == 1) & (h < (fade - 0.4) * 1.2)
        al[cut] = (0, 0, 0, 0)
        im = Image.fromarray(al)
    return im, (int(c), int(c))


def catmull(pts, n_per=24):
    """A Catmull-Rom curve through `pts` (the ends repeated), sampled evenly per segment."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n_per):
            t = k / float(n_per)
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(pts[-1])
    return out


def smoke_body(discs, size, ink=True, fade_from=None, cross=8, lip_only=False):
    """Smoke as one body: the union of `discs` (x, y, r) on a `size` canvas, each pixel lit by the
    disc it belongs to (its own top-left lit, its bottom-right in shade), the outline ink where the
    body passes over itself (two discs far apart along it meet), a step of shade where a billow
    tucks under the next, ringed the way the room is lit. From disc `fade_from` on it thins in a
    checker, the way the foam dissolves."""
    W, H = size
    owner = np.full((H, W), -1)
    best = np.full((H, W), 9.0)
    yy, xx = np.indices((H, W))
    for i, (x, y, r) in enumerate(discs):
        q = np.hypot(xx + 0.5 - x, (yy + 0.5 - y) * 1.12) / max(r, 0.6)
        q = q - 0.002 * i          # the later disc wins a tie: the coil lies over its tail
        take = (q < 1.0) & (q < best)
        best[take] = q[take]
        owner[take] = i
    out = np.zeros((H, W, 4), np.uint8)
    inside = owner >= 0
    for i, (x, y, r) in enumerate(discs):
        m = owner == i
        if not m.any():
            continue
        sx = (xx + 0.5 - x) / max(r, 0.6)
        sy = (yy + 0.5 - y) / max(r, 0.6)
        s = sx * 0.6 + sy * 0.95
        if lip_only:
            tone = np.where(s < -0.1, 1, np.where(s < 0.55, 2, 3))
        else:
            tone = np.where(s < -0.3, 0, np.where(s < 0.5, 1, 2))
        for t in range(4):
            out[m & (tone == t)] = SMOKE_T[t]
    if lip_only:
        up_out = np.zeros_like(inside)
        up_out[1:] = ~inside[:-1]
        out[inside & up_out] = SMOKE_T[0]
    o = owner
    # where the coil passes over itself: the one behind gets the outline ink along the meeting
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        a_ = np.roll(np.roll(o, dy, 0), dx, 1)
        meet = (o >= 0) & (a_ >= 0) & (np.abs(o - a_) >= cross) & (o < a_)
        out[meet] = SMOKE_INK
    # billow creases: a later disc lower than the one above it
    ys, xs = np.where((o[1:] >= 0) & (o[:-1] >= 0) & (o[1:] != o[:-1]) & (np.abs(o[1:] - o[:-1]) < cross))
    for y, x in zip(ys + 1, xs):
        a, b = o[y, x], o[y - 1, x]
        if discs[a][1] > discs[b][1] + 1.0 and tuple(out[y, x][:3]) != SMOKE_INK[:3]:
            out[y, x] = SMOKE_T[3] if out[y, x][0] < 200 else SMOKE_T[2]
    im = Image.fromarray(out)
    if ink:
        dark = np.array(look.ring(im, SMOKE_INK))
        lit = np.array(look.ring(im, SMOKE_T[3]))
        f = inside.astype(float)
        gx = np.zeros((H, W))
        gy = np.zeros((H, W))
        gx[:, 1:-1] = f[:, 2:] - f[:, :-2]
        gy[1:-1] = f[2:] - f[:-2]
        lit_side = (gx + gy * 1.2) > 0.2       # the body lies down-right of it: the rim faces up-left
        dark[lit_side & ~inside] = lit[lit_side & ~inside]
        im = Image.fromarray(dark)
    if fade_from is not None:
        a = np.array(im)
        o2 = np.full((H, W), -1)
        o2[inside] = o[inside]
        grown = dilate(inside, 1, True) & ~inside
        # the rim's owner: the nearest inside pixel's
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            src = np.roll(np.roll(o2, dy, 0), dx, 1)
            take = grown & (o2 < 0) & (src >= 0)
            o2[take] = src[take]
        n = len(discs)
        f = np.clip((o2 - fade_from) / max(1.0, n - fade_from), 0, 1)
        cut = (f > 0.05) & ((xx + yy) % 2 == 0)
        cut |= (f > 0.55) & ((xx + 2 * yy) % 3 != 0)
        a[cut & (o2 >= 0)] = (0, 0, 0, 0)
        im = Image.fromarray(a)
    return im


def path_of(pts, n_per=40):
    line = catmull(pts, n_per)
    run = [0.0]
    for k in range(1, len(line)):
        run.append(run[-1] + math.hypot(line[k][0] - line[k - 1][0], line[k][1] - line[k - 1][1]))
    return line, run


def at_len(line, run, s):
    s = max(0.0, min(run[-1], s))
    k = int(np.searchsorted(run, s))
    k = min(max(k, 1), len(run) - 1)
    t = (s - run[k - 1]) / max(1e-6, run[k] - run[k - 1])
    return (line[k - 1][0] + (line[k][0] - line[k - 1][0]) * t,
            line[k - 1][1] + (line[k][1] - line[k - 1][1]) * t)


def normal_at(line, run, s):
    p, q = at_len(line, run, s - 1.0), at_len(line, run, s + 1.0)
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = math.hypot(dx, dy) or 1.0
    return -dy / n, dx / n


def chain(L, pts, frame, r0=2.2, r1=7.0, start=4.0, touch=0.9, seed=5, breakoff=3,
          stragglers=((0.35, 1, 1.6), (0.6, -1, 1.8)), pause=None, away=None):
    """A: separate billows along `pts` (nozzle first), set down one after another so each just
    touches the last (`touch` of their two radii), growing r0 -> r1, the whole chain moving
    `step` art px along a frame. The last part of the path is the curl: past it the billows
    break into `breakoff` small puffs thinning from the rim. A couple of checker-thinned
    stragglers drift beside the chain. Returns the billows' (x, y, r)."""
    line, run = path_of(pts)
    total = run[-1]
    placed = []
    s = start + 3.0 * (frame % 4)
    i = 0
    while s < total:
        u = s / total
        r = r0 + (r1 - r0) * u ** 0.8
        x, y = at_len(line, run, s)
        placed.append((x, y, r, 0.0, seed + i * 7))
        i += 1
        r_next = r0 + (r1 - r0) * min(1.0, (s + 2 * r) / total) ** 0.8
        s += (r + r_next) * touch
        if pause is not None and i == pause:
            s += 5.0
    # the curl breaks up into small puffs past the path's end, off along its last heading
    if placed:
        ex, ey = at_len(line, run, total)
        px_, py_ = at_len(line, run, total - 6)
        hx, hy = away if away else (ex - px_, ey - py_)
        n = math.hypot(hx, hy) or 1.0
        hx, hy = hx / n, hy / n
        last_r = placed[-1][2]
        for k in range(breakoff):
            d = last_r * 0.6 + 2 + k * 3.6 + (frame % 4) * 1.0
            side = (-1) ** k * 2.0
            placed.append((ex + hx * d - hy * side, ey + hy * d + hx * side, 2.9 - k * 0.55,
                           0.1 * k, seed + 90 + k))
    for u, side, r in stragglers:
        x, y = at_len(line, run, total * u + 3.0 * (frame % 4))
        nx, ny = normal_at(line, run, total * u)
        rr = r0 + (r1 - r0) * u ** 0.8
        placed.append((x + nx * side * (rr + 3), y + ny * side * (rr + 3), r, 0.5, seed + 300 + int(u * 100)))
    for x, y, r, fade, sd in sorted(placed, key=lambda p: -p[2]):
        im, c = billow(r, sd, fade=fade, lobes=2 if r < 3 else 3)
        lay(L, im, (x, y), c)
    return [(p[0], p[1], p[2]) for p in placed]


def column(L, pts, frame, r0=2.6, r1=7.5, start=4.0, seed=12, gaps=(4, 8), breakoff=3, away=None):
    """B: one rising column: billows overlapping (each set down a little over half the two radii
    from the last), so they run together into one lumpy body whose every billow keeps its own
    ring as a crease; `gaps` are where the pump paused and the column parts. Ends in a curl that
    breaks into small puffs."""
    return _column_gapped(L, pts, frame, r0, r1, start, seed, gaps, breakoff, away)


def _column_gapped(L, pts, frame, r0, r1, start, seed, gaps, breakoff, away=None):
    line, run = path_of(pts)
    total = run[-1]
    placed = []
    s = start + 3.0 * (frame % 4)
    i = 0
    while s < total:
        u = s / total
        r = r0 + (r1 - r0) * u ** 0.8
        x, y = at_len(line, run, s)
        nx, ny = normal_at(line, run, s)
        sway = math.sin(i * 1.9 + seed) * r * 0.32         # the column leans side to side
        placed.append((x + nx * sway, y + ny * sway, r * (0.85 + 0.3 * ((i * 7) % 3) / 2.0), 0.0,
                       seed + i * 5))
        i += 1
        r_next = r0 + (r1 - r0) * min(1.0, (s + 2 * r) / total) ** 0.8
        s += (r + r_next) * 0.6
        if i in gaps:
            s += r * 1.6
    ex, ey = at_len(line, run, total)
    px_, py_ = at_len(line, run, total - 6)
    hx, hy = away if away else (ex - px_, ey - py_)
    n = math.hypot(hx, hy) or 1.0
    hx, hy = hx / n, hy / n
    last_r = placed[-1][2] if placed else 4
    for k in range(breakoff):
        d = last_r * 0.6 + 2 + k * 3.6 + (frame % 4)
        side = (-1) ** k * 2.0
        placed.append((ex + hx * d - hy * side, ey + hy * d + hx * side, 2.9 - k * 0.55,
                       0.1 * k, seed + 90 + k))
    for u, side, r in ((0.3, 1, 1.5), (0.6, -1, 1.7), (0.85, 1, 1.6)):
        x, y = at_len(line, run, total * u + 3.0 * (frame % 4))
        nx, ny = normal_at(line, run, total * u)
        rr = r0 + (r1 - r0) * u ** 0.8
        placed.append((x + nx * side * (rr + 3), y + ny * side * (rr + 3), r, 0.5, seed + 300 + int(u * 100)))
    # the oldest (highest, biggest) drawn first; the nozzle's end over them
    for x, y, r, fade, sd in sorted(placed, key=lambda p: -p[2]):
        im, c = billow(r, sd, fade=fade, lobes=2 if r < 3 else 3)
        lay(L, im, (x, y), c)


def scarf(back, front, nozzle, frame, loop_c, loop_r, seed=3):
    """C: one long thin wisp of smoke, the classic pixel wisp: a strand two to four art px wide
    off the nozzle, once round the band like a scarf (its far half behind the beard, so only its
    ends past the silhouette show; its near half over it), throwing a small curl off its upper
    side every CURL_EVERY px, with a few breaks; its tail frays into small puffs. Drawn through
    smoke_body (one body, lit top-left, white only along its top edge, inked where it crosses)."""
    cx, cy = loop_c
    rx, ry = loop_r
    ctrl = [(nozzle[0], nozzle[1]), (nozzle[0] - 9, nozzle[1] + 5), (cx + rx, cy + 2)]
    ring_pts = []
    for k in range(1, 15):
        ang = k / 14.0 * math.tau * 0.93
        ring_pts.append((cx + math.cos(ang) * rx * (1 - 0.06 * k / 14), cy + math.sin(ang) * ry))
    pts = ctrl + ring_pts
    line, run = path_of(pts, 30)
    total = run[-1]
    lead = run[min(len(run) - 1, len(catmull(ctrl, 30)))]
    back_d, front_d = [], []
    drift = (frame % 4) * 2.5
    s_ = 2.0
    while s_ < total:
        u = s_ / total
        x, y = at_len(line, run, s_)
        r = 0.75 + 0.45 * min(1.0, u * 3) + 0.7 * abs(math.sin((s_ - drift) / 6.0 + seed)) ** 2
        behind = s_ > lead and y < cy - 0.5
        if math.sin((s_ - drift) / 9.0 + seed * 2.1) < 0.95:
            (back_d if behind else front_d).append((x, y, r))
        s_ += 0.6
    # the curls: a small spiral off the strand's upper side, growing along the wisp
    k = 0
    c_at = 10.0 + drift
    while c_at < total - 6:
        x, y = at_len(line, run, c_at)
        nx, ny = normal_at(line, run, c_at)
        if ny > 0:
            nx, ny = -nx, -ny                 # the upper side
        size = (2.0 + 1.6 * min(1.0, c_at / total * 2)) * (0.75 + 0.5 * ((k * 0.618) % 1.0))
        ox, oy = x + nx * size, y + ny * size
        behind = c_at > lead and y < cy - 0.5
        spin = 1 if k % 2 else -1
        for j in range(26):
            t = j / 25.0
            ang = math.atan2(-ny, -nx) + spin * t * math.tau * 1.15
            rr = size * (1.0 - 0.75 * t)
            (back_d if behind else front_d).append((ox + math.cos(ang) * rr, oy + math.sin(ang) * rr,
                                                    0.85 if t < 0.8 else 0.6))
        k += 1
        c_at += CURL_EVERY * (0.7 + 0.6 * ((k * 0.382 + 0.2) % 1.0))
    for discs, L in ((back_d, back), (front_d, front)):
        if discs:
            L.alpha_composite(smoke_body(discs, look.ROOM_GRID, lip_only=True, cross=40))
    ex, ey = at_len(line, run, total)
    for k in range(3):
        im, c = billow(2.2 - k * 0.5, seed + 40 + k, fade=0.15 * k, lobes=2)
        lay(back if ey < cy else front, im, (ex + 3 + k * 3.5, ey - 4 - k * 3), c)


CURL_EVERY = 21.0


# =============================================================================================
# Marks
# =============================================================================================
ZEDS = {
    4: ["####", "..#.", ".#..", "####"],
    5: ["#####", "...#.", "..#..", ".#...", "#####"],
    7: ["#######", ".....#.", "....#..", "...#...", "..#....", ".#.....", "#######"],
}


def zed(n):
    return look.inked(look.grid(ZEDS[n], {"#": SW["foam_light"]}))


def arc_cells(h, curv):
    pts = [(int(round(curv * (1 - (dy / float(h)) ** 2))), dy) for dy in range(-h, h + 1)]
    out = [pts[0]]
    for p in pts[1:]:
        q = out[-1]
        while abs(p[0] - q[0]) > 1:
            q = (q[0] + (1 if p[0] > q[0] else -1), q[1])
            out.append(q)
        out.append(p)
    return out


def buzz_arcs(layer, mask, rows, frame=0):
    """Comic buzz arcs at the mass's own edge on `rows` [(y, side)], three nested a side,
    opening a px and back with the frame, outline ink with a pale inner lip."""
    for k, (y, side) in enumerate(rows):
        y = int(round(y))
        cols = np.where(mask[y])[0]
        if not cols.size:
            continue
        edge = cols.min() if side < 0 else cols.max()
        push = (frame + k) % 2
        for j, (h, curv) in enumerate(((3, 1), (5, 2), (7, 3))):
            x0 = edge + side * (4 + j * 4 + push)
            for dx, dy in arc_cells(h, curv):
                px, py = int(x0 + side * dx), y + dy
                if 0 <= px < layer.width and 0 <= py < layer.height:
                    layer.putpixel((px, py), OUT)
                    lip = (px - side, py)
                    if layer.getpixel(lip)[3] == 0:
                        layer.putpixel(lip, SW["foam_light"])


def motion_ticks(layer, x, y, side, frame=0):
    for k in range(2):
        yy = int(y - 2 + k * 4)
        xx = int(x - side * (8 + (frame + k) % 2))
        for d in range(2):
            px = xx - side * d
            if 0 <= px < layer.width and 0 <= yy < layer.height:
                layer.putpixel((px, yy), OUT)


# pollen: round dots in the flower bed's yellows (the coin's ramp the bed's flowers wear), a
# shaded px under the lit one, no outline and no star crest
POLLEN_BIG = look.grid(["Wc", "cS"], {"W": SW["coin_lit"], "c": SW["coin"], "S": SW["coin_shade"]})
POLLEN = look.grid(["c"], {"c": SW["coin_lit"]})
POLLEN_DIM = look.grid(["c"], {"c": SW["coin_shade"]})
POLLEN_RING = look.inked(look.grid(["Wc", "cS"], {"W": SW["coin_pale"], "c": SW["coin_lit"],
                                                  "S": SW["coin"]}))
POLLEN_RING1 = look.inked(look.grid(["c"], {"c": SW["coin_lit"]}))


def orbit(back, front, band, mask, frame=0, n=16, seed=21):
    """B: the band being smoked boils off into a loose swirl of flying bees all round it, on
    ellipses of their own (a little wider or rounder each), turning anticlockwise a step a frame,
    the far half behind the beard; each trails two ringed pollen dots. The pointer's target is
    inside it."""
    rng = random.Random(seed)
    t0, t1 = band_rows(band)
    cy = (t0 + t1) / 2.0 + 2
    cols = np.where(mask[int(cy)])[0]
    half = (cols.max() - cols.min()) / 2.0 if cols.size else 50
    mid = (cols.max() + cols.min()) / 2.0 if cols.size else CX
    for i in range(n):
        rx = half + rng.uniform(12, 30)
        ry = rng.uniform(10, 20)
        u = (i / float(n) + rng.uniform(-0.02, 0.02) + frame * 0.03) % 1.0
        ang = u * math.tau
        x, y = mid + math.cos(ang) * rx, cy + math.sin(ang) * ry
        near = math.sin(ang) > 0
        L = front if near else back
        going_left = math.sin(ang) > 0
        for k, im in enumerate((POLLEN_RING, POLLEN_RING1)):
            a2 = ang - (0.09 + 0.07 * k)
            tx, ty = mid + math.cos(a2) * rx, cy + math.sin(a2) * ry
            lay(L if math.sin(a2) > 0 else back, im, (tx, ty), (1, 1))
        put(L, x, y + (frame + i) % 2, pose="fly", frame=frame + i, left=going_left, over=WHIRR)


def warm_motes(layer, mask, band, frame=0, seed=8):
    """C: warm motes rising off the band being smoked, from its sides only: 1-2 px of the
    coin's palest steps wavering up, smaller as they go."""
    t0, t1 = band_rows(band)
    rng = random.Random(seed)
    for side in (-1, 1):
        for k in range(6):
            y0 = rng.uniform(t0 + 6, t1 - 4)
            cols = np.where(mask[int(y0)])[0]
            if not cols.size:
                continue
            x0 = (cols.min() - 3) if side < 0 else (cols.max() + 3)
            rise = (rng.uniform(0, 14) + frame * 2.5) % 16
            x = x0 + side * (rise * 0.35) + math.sin(rise / 3.0 + k) * 1.5
            y = y0 - rise
            im = POLLEN_BIG if rise < 8 else POLLEN
            if rise > 12:
                im = POLLEN_DIM
            lay(layer, im, (x, y))


BUBBLE = {}


def bubble(r):
    if r in BUBBLE:
        return BUBBLE[r]
    s = 2 * r + 1
    a = bh.Art(s, s)
    for x, y in ellipse_cells(r + 0.5, r + 0.5, r + 0.5, r + 0.5):
        d = (x - r) * 0.7 + (y - r)
        a.px(x, y, SW["foam_light"] if d < r * 0.3 else SW["water_light"])
    a.px(r - max(1, r // 2), r - max(1, r // 2), (255, 255, 255, 255))
    im = look.inked(a.im, SW["water_mid"])
    BUBBLE[r] = im
    return im


# =============================================================================================
# Bees flying about the room, and the prompt card
# =============================================================================================
WANDER = [(96, 64, 0), (168, 88, 3), (408, 70, 1), (452, 118, 4), (560, 96, 2), (402, 150, 5),
          (520, 214, 1), (78, 196, 2), (604, 170, 4)]


def wanderers(L, frame=0, skip=()):
    for i, (x, y, f) in enumerate(WANDER):
        if i in skip:
            continue
        put(L, x, y, pose="fly", frame=frame + f, left=i % 3 == 0)


CARD_PAPER = (234, 219, 184, 255)
CARD_INK = (50, 36, 28, 255)
CARD_RED = (115, 40, 26, 255)
CARD_TEXT = (604, 978, 1376, 1018)      # the card's text area, plate px (the icon left of it)


def card(base, words):
    """The prompt card with new words: '*' marks the red word, Bungee at the card's own size."""
    d = ImageDraw.Draw(base)
    d.rectangle([CARD_TEXT[0], CARD_TEXT[1], CARD_TEXT[2], CARD_TEXT[3]], fill=CARD_PAPER)
    f = look.font(31, "label")
    parts = []
    red = False
    for chunk in words.split("*"):
        if chunk:
            parts.append((chunk.upper(), CARD_RED if red else CARD_INK))
        red = not red
    widths = [d.textlength(t, font=f) for t, _ in parts]
    x = (CARD_TEXT[0] + CARD_TEXT[2]) / 2.0 - sum(widths) / 2.0 + 6
    for (t, col), wdt in zip(parts, widths):
        d.text((x, 980), t, font=f, fill=col)
        x += wdt
    return base


# =============================================================================================
# The three options. Each returns (plate image, {name: crop box in plate px}).
# =============================================================================================
STATE = ["calm", "agitated", "waiting"]
CURSOR = Image.open(os.path.join(look.ROOT, "assets", "cursor.png")).convert("RGBA")
CURSOR_TIP = (2, 2)
HINTS = {"A": "*Smoke* the buzzing bees until they sleep",
         "B": "*Smoke* the bees inside the ring",
         "C": "*Smoke* the warm bees until they sleep"}
FRAME_BOX = (495, 366, 1176, 786)        # plate px: the whole beard, the guards and the smoker


def _finish(base, layers):
    L = blank()
    for l in layers:
        if l is not None:
            L.alpha_composite(l)
    look.place(base, L, (0, 0), G)
    return base


def option_a(frame=0):
    """A: the bees say it. The band being smoked whirrs at its rim, buzz arcs either side, bees
    popping off its left side; the band asleep folds its wings, shuts its eyes and breathes Zs.
    Separate billows, one a pump, along the band's right edge to a curl that breaks up. The
    smoker held at the bellows in a leather glove, its shadow on the path."""
    base = clean_plate()
    sm, an = smoker(SQUEEZE[frame % 4])
    noz = (322, 180)
    tl = (noz[0] - an["nozzle"][0], noz[1] - an["nozzle"][1])
    hover_shadow(base, (tl[0] + an["feet"][0] + 6, tl[1] + an["feet"][1] + 6), (13, 2))
    b = beard(STATE, frame=frame, lift_off=3)
    card(base, HINTS["A"])
    marks = blank()
    t0, t1 = band_rows(1)
    buzz_arcs(marks, b["mask"], [(t0 + 13, -1), (t1 - 6, -1)], frame)
    for x, y, side in b["lifted"]:
        motion_ticks(marks, x, y, side, frame)
    zs = blank()
    for n, (x, y) in ((4, (186, 136)), (5, (177, 124)), (7, (165, 108))):
        lay(zs, zed(n), (x, y + (frame + n) % 2))
    smoke = blank()
    chain(smoke, [(noz[0] - 3, noz[1]), (309, 186), (299, 191), (292, 187), (292, 178), (298, 171)],
          frame, r0=2.2, r1=6.6, start=4.0, seed=5, away=(0.55, -1.0))
    if SQUEEZE[frame % 4] == 1.0:
        im, c = billow(1.6, 77, lobes=2)
        lay(smoke, im, (noz[0] - 3, noz[1] - 1), c)
    held = blank()
    lay(held, sm, tl)
    gl, grip = leather_mitt()
    # the hand on the outer board's top end, pressing it in, so the pleats show under it
    lay(held, gl, (tl[0] + an["top"][0] + 3, tl[1] + an["top"][1] + 6), grip)
    fly = blank()
    wanderers(fly, frame)
    out = _finish(base, beard_layers(b) + [marks, zs, smoke, held, fly])
    crops = {"the band being smoked: rim whirring, buzz arcs, bees popping off": (500, 456, 740, 606),
             "the band smoked: eyes shut, wings folded, one step paler, Zs": (480, 318, 720, 474),
             "the smoke: one billow a pump, curling along the band's edge": (840, 450, 1000, 600),
             "the smoker, one box tall, in the leather glove, its shadow": (930, 480, 1176, 780),
             "the foot: festoons, bees on the box, guards": (560, 630, 860, 840)}
    return out, crops


def option_b(frame=0):
    """B: a ring of bees. Seven bees fly round the band being smoked, trailing pollen dots, the
    far half of the ring behind the beard; the band asleep is only its sleeping bees. The smoker
    stands on the lawn with its shadow: one rising column, parted where the pump paused, bends
    to the pointer and curls in at the band's edge."""
    base = clean_plate()
    sm, an = smoker(SQUEEZE[frame % 4], spout="up")
    feet = (330, 297)
    tl = (feet[0] - an["feet"][0], feet[1] - an["feet"][1])
    ground_shadow(base, (feet[0] + 15, feet[1] + 1), (26, 5))
    card(base, HINTS["B"])
    b = beard(STATE, frame=frame)
    back, front = blank(), blank()
    orbit(back, front, 1, b["mask"], frame)
    noz = (tl[0] + an["nozzle"][0], tl[1] + an["nozzle"][1])
    smoke = blank()
    column(smoke, [(noz[0], noz[1] - 3), (noz[0] - 3, noz[1] - 20), (noz[0] - 9, noz[1] - 38),
                   (300, 191), (294, 181), (297, 171)], frame, seed=12, away=(0.6, -1.0))
    if SQUEEZE[frame % 4] == 1.0:
        im, c = billow(1.6, 78, lobes=2)
        lay(smoke, im, (noz[0], noz[1] - 3), c)
    stand = blank()
    lay(stand, sm, tl)
    lawn = [(40, 70, 23, 255), (61, 87, 37, 255), (88, 109, 51, 255), (138, 153, 84, 255)]
    br = random.Random(17)
    for x in range(tl[0] + an["can"][0] - 1, tl[0] + an["can"][1] + 14):
        if br.random() < 0.55:
            for j in range(br.choice((1, 2, 2, 3))):
                stand.putpixel((x, feet[1] - j), lawn[min(3, j + br.randint(0, 1))])
    fly = blank()
    wanderers(fly, frame, skip=(6,))
    out = _finish(base, [back] + beard_layers(b) + [front, stand, smoke, fly])
    cx, cy = 291, 176
    out.alpha_composite(CURSOR, (cx * G - CURSOR_TIP[0], cy * G - CURSOR_TIP[1]))
    crops = {"the band being smoked: its bees boiling off round it, left": (460, 444, 700, 624),
             "the same, right, by the smoke": (820, 444, 1000, 624),
             "the band smoked: its bees asleep, nothing else": (560, 384, 800, 504),
             "the smoke: one column, parted where the pump paused, to the pointer": (840, 444, 1020, 760),
             "the smoker standing on the lawn, its shadow": (900, 640, 1140, 910)}
    return out, crops


def option_c(frame=0):
    """C: warmth and hush. The beard read as one dark mass with only its rim bees lit; the band
    being smoked a step warmer, flickering, warm motes rising off its sides; the band asleep
    blows sleep bubbles. One long thin scarf of smoke wraps round the band. The smoker hangs from
    the game's own pointer by its outer board, its shadow on the path."""
    base = clean_plate()
    sm, an = smoker(SQUEEZE[frame % 4])
    noz = (322, 180)
    tl = (noz[0] - an["nozzle"][0], noz[1] - an["nozzle"][1])
    hover_shadow(base, (tl[0] + an["feet"][0] + 6, tl[1] + an["feet"][1] + 6), (13, 2))
    card(base, HINTS["C"])
    b = beard(STATE, frame=frame, read="rim", warm=True)
    motes = blank()
    warm_motes(motes, b["mask"], 1, frame)
    bubbles = blank()
    for r, (x, y) in ((1, (189, 139)), (2, (182, 129)), (3, (173, 116)), (2, (167, 103))):
        lay(bubbles, bubble(r), (x, y - frame), (r + 1, r + 1))
    back, front = blank(), blank()
    t0, t1 = band_rows(1)
    scarf(back, front, (noz[0] - 3, noz[1]), frame, (CX, (t0 + t1) / 2.0 + 1), (60, 13))
    held = blank()
    lay(held, sm, tl)
    fly = blank()
    wanderers(fly, frame)
    out = _finish(base, [back] + beard_layers(b) + [motes, bubbles, front, held, fly])
    gx, gy = tl[0] + an["top"][0], tl[1] + an["top"][1]
    out.alpha_composite(CURSOR, (gx * G - CURSOR_TIP[0], gy * G - CURSOR_TIP[1]))
    crops = {"the band being smoked: warm, flickering, motes rising": (500, 456, 740, 606),
             "the band smoked: the dark mass, rim faces, sleep bubbles": (480, 288, 720, 480),
             "the smoke: one wisp wrapped round the band, curling": (530, 500, 1000, 620),
             "the smoker hung from the pointer, its shadow": (930, 450, 1176, 780)}
    return out, crops


OPTIONS = [
    ("A", "the bees say it", option_a,
     "The bees are the marks: the band being smoked whirrs along its rim (wings up / blurred, a "
     "px of jitter), buzz arcs off its edges and bees popping off its left side; the band "
     "smoked shuts its eyes, folds its wings, goes one step paler and breathes Zs. Smoke: "
     "separate billows, one a pump, growing along the band's right edge to a curl that breaks "
     "into puffs. Smoker: one hive box tall, held at the outer board in a leather glove, a "
     "stepped shadow on the path under it. Card: '*Smoke* the buzzing bees until they sleep' "
     "(HIVE_HINT_SMOKE reworded)."),
    ("B", "a ring of bees", option_b,
     "Seven bees fly a ring round the band being smoked, each trailing three pollen dots, the "
     "far half behind the beard, the ring turning a step a frame; the band smoked is only its "
     "sleeping bees. Smoke: one continuous column of overlapping billows, parted where the pump "
     "paused, rising from the smoker and curling in at the band's edge. Smoker: standing on the "
     "lawn in the grass with its shadow; pressing pumps it, and the column bends to the pointer "
     "(the game's wooden cursor at the curl). Card: '*Smoke* the bees inside the ring'."),
    ("C", "warmth and hush", option_c,
     "A different beard read: one dark mass, faces only along its rim, a few gold backs inside. "
     "The band being smoked: its bees and fur a step warmer (the honey's ramp), flickering, warm "
     "motes rising off its sides; the band smoked blows sleep bubbles. Smoke: one long thin scarf "
     "off the nozzle, once round the band (its far half behind the beard) and frayed at its "
     "tail. Smoker: hung from the game's own pointer by its outer board, no glove, a shadow on "
     "the path. Card: '*Smoke* the warm bees until they sleep'."),
]


# =============================================================================================
# The sheet
# =============================================================================================
SHEET_WIDE = 3640


def today_strip():
    p = look.plate("smoke")
    small = p.resize((960, 540), Image.NEAREST)
    ims = [look.panel(small, "today: the whole step, half size")]
    for title, box in (("today: the rings and the beard, 3x", (560, 420, 800, 600)),
                       ("today: the smoke, 3x", (740, 330, 980, 510)),
                       ("today: the smoker, 2x", (990, 470, 1270, 810))):
        ims.append(look.panel(zoom(p.crop(box), 2 if "2x" in title else 3), title))
    return look.flow(ims, SHEET_WIDE, 16)


def frames_strip(fn, n=4):
    out = []
    for f in range(n):
        im, _ = fn(f)
        out.append(look.panel(zoom(im.crop(FRAME_BOX), 2),
                              "frame %d: bellows %s" % (f, ("open", "half", "shut, a puff", "half")[f])))
    return look.stack([look.stack(out[:2], "h", 12), look.stack(out[2:], "h", 12)], "v", 12)


def option_block_for(label, name, fn, caption):
    im, crops = fn(0)
    marked = im.copy()
    crop_panels = []
    for title, box in crops.items():
        z = look.crop_zoom(im, box, CROP_ZOOM, mark_on=marked)
        crop_panels.append(look.panel(z, "%s, %dx" % (title, CROP_ZOOM)))
    big = look.panel(marked, "real scale on the smoke plate: 1920x1080, 3 screen px an art px")
    right = look.flow(crop_panels, SHEET_WIDE - big.width - 20, 14)
    top = look.stack([big, right], "h", 20)
    frames = look.panel(frames_strip(fn),
                        "four frames, 2x, the beard, the guards and the smoker: wings, marks, "
                        "bellows (open, half, shut, half) and the smoke stepping 3 art px a frame")
    one = look.panel(im.crop(FRAME_BOX), "frame 0 at 1x (as played)")
    body = look.stack([top, look.stack([frames, one], "h", 20)], "v", 16)
    return look.option_block(label, name, caption, body, recommended=(label == RECOMMEND),
                             width=SHEET_WIDE)


def parts_strip():
    sky = (161, 203, 229, 255)
    items = []

    def tile(im, title, s=4):
        b = Image.new("RGBA", (im.width + 4, im.height + 4), sky)
        b.alpha_composite(im, (2, 2))
        items.append(look.panel(zoom(b, s), title, size=14))

    for sq, t in ((0.0, "smoker, bellows open"), (0.5, "half"), (1.0, "shut")):
        tile(smoker(sq)[0], t)
    tile(smoker(0.0, "up")[0], "standing, spout up (B)")
    tile(leather_mitt()[0], "leather glove (A)")
    for r in (2.2, 4, 6.8):
        tile(billow(r, 5 + int(r))[0], "billow r%.1f" % r)
    tile(billow(4, 9, fade=0.5)[0], "billow thinning from its rim")
    marks = Image.new("RGBA", (34, 14), (0, 0, 0, 0))
    for n, x in ((4, 0), (5, 7), (7, 15)):
        lay(marks, zed(n), (x, 12 - n - 1))
    lay(marks, POLLEN_BIG, (26, 3))
    lay(marks, POLLEN, (30, 3))
    lay(marks, POLLEN_DIM, (32, 3))
    lay(marks, bubble(3), (24, 6))
    tile(marks, "Zs, pollen dots, a bubble")
    steps = Image.new("RGBA", (16 * 9, 16), (0, 0, 0, 0))
    samples = [(TOP["lit"], "walk", 0, True), (TOP["mid"], "walk", 0, True),
               (TOP["shade"], "walk", 0, True), (CALM["lit"], "rest", 3, True),
               (TOP["lit"], "walk", 0, False), (WARM["lit"], "walk", 0, True),
               (UNDER["lit"], "walk", 0, True), (UNDER["mid"], "walk", 0, True),
               (UNDER["shade"], "walk", 0, True)]
    for i, (over, pose, f, face) in enumerate(samples):
        steps.alpha_composite(look.bee_keyed(V, f, False, pose, 0, over, face), (i * 16, 0))
    tile(steps, "the bee's steps: lit, mid, shade, calm (eyes shut), from behind, warm (C), "
                "under layer lit / mid / shade")
    fan = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    fan.alpha_composite(buzzing(0, False), (0, 0))
    fan.alpha_composite(buzzing(1, False), (16, 0))
    tile(fan, "rim whirr: up, blurred fan")
    return look.flow(items, SHEET_WIDE, 14)


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    blocks = [look.option_block(
        "", "today",
        "Flat yellow UI ellipses for the rings, a soft grey blob of smoke, a smoker twice a hive "
        "box tall hanging in the air, and bees that read as brown scribble.", today_strip(),
        width=SHEET_WIDE)]
    for label, name, fn, cap in OPTIONS:
        blocks.append(option_block_for(label, name, fn, cap))
        im, _ = fn(0)
        im.convert("RGB").save(os.path.join(SCRATCH, "opt_%s.png" % label))
    blocks.append(look.option_block("", "the parts, 4x",
                                    "Every new piece alone on the room's sky: whole art px, ringed, "
                                    "lit from the top-left.", parts_strip(), width=SHEET_WIDE))
    look.sheet(
        "SMOKE: THE BEARD, THE SMOKE AND THE SMOKER", blocks, OUT_PATH,
        subtitle="One state of the step in every option: the TOP of the beard already smoked "
                 "quiet, the MIDDLE band being smoked now, the entrance (four guards on the "
                 "landing board) still to come. Every bee is look.bee A, the coin bee, drawn "
                 "through fixed ramp swaps (look.bee_keyed): three hard light steps off the "
                 "room's top-left sun, a calm step one paler, the under layer two down with its "
                 "outline in the fur's brown; every top bee keeps its (24,18,17) ring. The beard "
                 "hangs under the gable's lower half in lumpy lobes, three festoon chains off its "
                 "foot, bees walking on the gable and the box; only about a third of its top "
                 "bees show their faces. Whole art px at the room's grain (3 screen px). The "
                 "backdrop is %s: no rubbish, no ferries, no dogs (Richard's call), the island's "
                 "flowers in the bottom corners with bees at them. Pink boxes mark the zoom "
                 "crops." % BACKDROP_NOTE[0],
        notes="The prompt card's words follow each option (HIVE_HINT_SMOKE would be reworded: "
              "A '*Smoke* the buzzing bees until they sleep', B '*Smoke* the bees inside the "
              "ring', C '*Smoke* the warm bees until they sleep'; all no longer than today's, "
              "the other seven languages to follow). Colours: the bees, the pollen, the warm "
              "step and the motes are look.SW's (the coin's ramp, the finds' gold, the honey, "
              "the stripe browns); the fur is build_hive's bark; the smoke is build_hive."
              "SMOKE_T's four greys, white only on each billow's lit lip, its outline the "
              "deepest grey darkened; the smoker is build_hive's STEEL, BRASS, LEATHER and dark "
              "wood, sized to one hive box; the glove is build_hive.glove's leather and canvas; "
              "the bubbles are the palette's foam and clean water; the shadows are the ground "
              "multiplied a step; the pointer is assets/cursor.png. "
              "Script: tools/hive_look/smoke_mockup.py.")
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

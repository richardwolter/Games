#!/usr/bin/env python
"""The backdrop sheet (2026-10-16, the hive overhaul): what stands behind every hive-room step.

OFFLINE MOCKUP ONLY. Writes tools/hive_look/last_backdrop.png.

Today the hive room borrows the wash room's view (scripts/wash_backdrop.gd): the dirty lake
band with its rubbish, the ferries on two lanes, the pack trotting the lawn. Richard's call
(2026-10-16): the same view, with no rubbish, no ferries and no dogs, and a bed of the
island's own flowers along the foreground lawn with bees working it. Three options, A / B / C,
on three axes at once: how dense and tall the bed is, where it sits (front edge only, a border
at both sides, scattered clumps), and whether the far lake is calmed with a veil.

**The backdrop is re-drawn, not retouched.** Measured off the plates (this script's `fit_ink`
re-measures it every run): the room is a 1280x720 canvas at a 1.5 window stretch, the view's
geometry is WashBackdrop's own (EYE 0.43, NEAR_D 1.6, SHORE_D 7.5, FAR_D 33.5, PIXEL 2), so
  - the far bank strip (assets/wash_bank.png, FAR_PIXEL 1 canvas px a texel, slid 150 canvas
    px: HiveRoom.BANK_OFFSET) stands on screen rows 351-495 at 1.5 screen px a texel;
  - the lake is screen rows 495-597: seven flat bands of the state's ramp (BANDS), streaks one
    step up, the far foam line and the near one lapping;
  - the lawn strip (assets/wash_lawn.png, PIXEL 2) runs from row 597 at 3 screen px a texel;
  - everything below the sky is multiplied by the darken veil times the day's tint, fitted
    off the lawn (about 0.81 / 0.81 / 0.80; max error one level), and the lake's swatches
    times that ink are exactly what the plate shows (the dirty ramp: 24,56,16 / 19,47,13 ...).
So the lake is drawn fresh in any state with nothing on it, the bank with no hull in front,
the lawn with no dog. The sky is the plate's own, today's bees cleaned off (look.clean_bees).
The step's own work (the catch box, the bottling stand and jars, the prompt card) is lifted
back off the plate: on the ground by the difference against the clean lawn, above it by
hand-cut rectangles round the stand. Today's bees are replaced by look's bee (variant A), the
same bee every sheet shows, in today's places and numbers (measured off the plates): the catch
sky's two clumps and 26 loose bees, the heap on the box, the pour sky's six wanderers.

**The bed**: real pieces of assets/flora.png (the pack's beds, single heads and tulips for colour,
its leafy plants and fern behind), planted in DRIFTS of one colour family, brick-laid rows, and
GRADED BY DEPTH: the 3x5 heads and clovers at the back, the 5x7 tulips and the pack's clumps in
the middle, the 7x8 discs and 6x6 crosses (at least half a bee wide) and more clumps at the
window's foot, so the mass gets taller and coarser towards the eye. The pieces sit on a two-step
LEAF BODY (grass_dark, and grass_dark taken towards the outline ink; lit on the top edge, deep
under each head) that fills the closed silhouette's gaps, and the whole mass is ringed ONCE in
the game's outline, open at the foot: inside the bed there is no outline ink at all (the old
black mesh was a ring round every hole between heads). A one-row contact shade down and right
(the room's sun is top left); drawn over the backdrop's darken as its birds and dogs are. Bees at
the bed are look.bee (hover beside a head, rest on one, fly a little over it, the wings swept
back so the eye shows), kept inside the bed's silhouette plus one bee's width and two art px
clear of every other bee.

The far bank's dead trees are painted out of today's strip and its rust trunk band turned into
the strip's own deep greens (clean_bank_strip); the build should rebuild wash_bank.png off the
round-tree mix instead. No pigeons in any step.

The options are the BED (A a low hedge along the whole foot, B corner borders (recommended), C
separate posies), all shown under the same 0.6 veil; the VEIL is its own row (none / 0.6 / 1.0 on
B's bed, the dirty catch step). The CHECK row redraws the smoke, uncap and done views the same
way (check_work: today's bees off, the step's work lifted by hand-cut boxes and colour tests,
rubbish, ferries, dogs and pigeons left behind) with B's bed. The catch scene keeps the lake dirty
as captured, the pour scene shows it hazy (later in a run).

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/backdrop_mockup.py
"""
import json
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
from look import ROOM_GRAIN as G, place, panel, stack, flow, zoom  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

ROOT = look.ROOT
OUT_PATH = os.path.join(look.HERE, "last_backdrop.png")
SCRATCH = os.path.join(look.HERE, "_scratch_backdrop")
RECOMMEND = "B"
BEE = "A"
W, H = 1920, 1080

# =============================================================================================
# The view's geometry: WashBackdrop's numbers on a 1280x720 canvas, window stretch 1.5.
# =============================================================================================
CANVAS_H = 720
STRETCH = 1.5
EYE, NEAR_D, SHORE_D, FAR_D = 0.43, 1.6, 7.5, 33.5
PIXEL = 2.0
BANK_TALL = 96
BANK_OFFSET = 150
LAWN_PERIOD = 960
BANDS = [[0.04, 3], [0.07, 2], [0.14, 1], [0.30, 0], [0.22, 1], [0.14, 2], [0.09, 3]]
STREAKS = 110
STREAK_LONG = (5.0, 34.0)
LAP_LONG = 56.0


def _snapped(v, step):
    return math.floor(v / step + 0.5) * step


def y_at(d):
    return CANVAS_H * (EYE + (1.0 - EYE) * NEAR_D / max(d, 0.01))


LAKE_FAR_C = _snapped(y_at(FAR_D), PIXEL)     # 330 canvas
LAKE_NEAR_C = _snapped(y_at(SHORE_D), PIXEL)  # 398 canvas
BANK_TOP_C = LAKE_FAR_C - BANK_TALL           # 234 canvas


def S(v):
    """Canvas px -> window px."""
    return int(round(v * STRETCH))


BANK_TOP, LAKE_FAR, LAKE_NEAR = S(BANK_TOP_C), S(LAKE_FAR_C), S(LAKE_NEAR_C)   # 351 495 597

RAMP_STEPS = ["_deep", "_mid", "", "_shallow", "_light"]
STATES = ["clean", "hazy", "murky", "foul", "dirty"]

_bank_old = np.array(Image.open(os.path.join(ROOT, "assets/wash_bank.png")).convert("RGBA")).astype(float)
_lawn = np.array(Image.open(os.path.join(ROOT, "assets/wash_lawn.png")).convert("RGBA")).astype(float)

# The far bank as the mock draws it: today's strip with its dead trees and its rust trunk band
# painted out (CLAUDE.md, The Wood and the Pack Plants: no dead trees). FOR THE BUILD: rebuild
# assets/wash_bank.png off today's round-tree mix in tools/build_wash_backdrop.py rather than
# patching it like this.
BANK_TRUNKS_FROM = 70          # strip rows: above this a red pixel is a dead tree's branch
BANK_UNDER = [(10, 23, 6), (15, 35, 10), (17, 40, 12), (19, 46, 13), (24, 57, 17)]  # the strip's own
BANK_COPY = (64, -64, 96, -96, 128, -128, 160, -160, 192, -192)


def _red(px):
    return px[3] > 0 and px[0] > px[1] + 15 and px[0] > px[2]


def clean_bank_strip(a):
    """Paint the dead trees out of the strip (a red pixel above the trunk band takes the crown
    pixel of the same row 64, 96 ... columns away, the first that is not red: the canopy's own
    texture, not a smear of its neighbour) and turn the rust trunk band into the strip's own
    deep undergrowth greens, by brightness rank, so the bank reads as one calm green mass."""
    a = a.copy()
    h, w = a.shape[:2]
    red = (a[..., 3] > 0) & (a[..., 0] > a[..., 1] + 15) & (a[..., 0] > a[..., 2])
    for y in range(min(BANK_TRUNKS_FROM, h)):
        for x in np.nonzero(red[y])[0]:
            for dx in BANK_COPY:
                xx = (x + dx) % w
                if not red[y, xx] and a[y, xx, 3] > 0:
                    a[y, x] = a[y, xx]
                    break
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    band = red.copy()
    band[:BANK_TRUNKS_FROM] = False
    if band.any():
        vals = np.sort(lum[band])
        cuts = [vals[int(len(vals) * k / len(BANK_UNDER))] for k in range(1, len(BANK_UNDER))]
        for y, x in zip(*np.nonzero(band)):
            k = sum(lum[y, x] >= c for c in cuts)
            a[y, x, :3] = BANK_UNDER[k]
    return a


_bank = clean_bank_strip(_bank_old)


def _rgb(name):
    return np.array(look.PAL[name][:3], float)


def fit_ink(p):
    """The darken veil times the day's tint, per channel, off a stretch of lawn no step covers
    (the bottom-left corner, under any dog): what the plate's backdrop was multiplied by."""
    ys = np.arange(860, 1076)
    xs = np.arange(0, 200)
    tex = _lawn[((ys - LAKE_NEAR) // 3)[:, None], (xs // 3)[None, :]][..., :3]
    pt = p[860:1076, 0:200, :3].astype(float)
    return (pt * tex).sum((0, 1)) / (tex * tex).sum((0, 1))


def render_lawn(ink):
    ys = np.arange(LAKE_NEAR, H)
    xs = np.arange(W)
    tex = _lawn[((ys - LAKE_NEAR) // 3)[:, None], ((xs // 3) % LAWN_PERIOD)[None, :]][..., :3]
    return np.clip(np.round(tex * ink), 0, 255)


def render_bank(p, ink, keep_sky, strip=None):
    """The far bank strip over the plate's own sky. `keep_sky` is the plate with today's bees
    and anything standing in front of the trees cleaned off: it shows through between crowns.
    `strip` is the mock's cleaned strip unless today's is asked for (the check's reference)."""
    ys = np.arange(BANK_TOP, LAKE_FAR)
    xs = np.arange(W)
    kr = np.clip(np.floor(ys / STRETCH - BANK_TOP_C).astype(int), 0, BANK_TALL - 1)
    kc = (np.floor(xs / STRETCH).astype(int) + BANK_OFFSET) % 960
    tex = (_bank if strip is None else strip)[kr[:, None], kc[None, :]]
    a = tex[..., 3:] / 255.0
    sky = keep_sky[BANK_TOP:LAKE_FAR, :, :3].astype(float)
    return np.clip(np.round(tex[..., :3] * ink * a + sky * (1 - a)), 0, 255), (a[..., 0] > 0)


def lake_rows():
    """[(screen top, screen bottom, ramp step)] of the seven bands, far to near."""
    out = []
    y = LAKE_FAR_C
    h = LAKE_NEAR_C - LAKE_FAR_C
    for k, (share, step) in enumerate(BANDS):
        tall = _snapped(h * share, PIXEL)
        if k == len(BANDS) - 1:
            tall = LAKE_NEAR_C - y
        out.append((S(y), S(y + tall), step))
        y += tall
    return out


def render_lake(state, ink, streak_share=0.7, seed=4177, lap_phase=0.0):
    """The lake band, far waterline to near, in the state's ramp, nothing on it (WashBackdrop
    _draw_water: bands, streaks one step up, the far foam line, the near one lapping)."""
    ramp = [_rgb("water_" + STATES[state] + s) for s in RAMP_STEPS]
    out = np.zeros((LAKE_NEAR - LAKE_FAR, W, 3))
    rows = lake_rows()
    for top, bot, step in rows:
        out[top - LAKE_FAR:bot - LAKE_FAR] = ramp[step]
    rng = random.Random(seed)
    lake_h = LAKE_NEAR_C - LAKE_FAR_C
    for k in range(STREAKS):
        sx, sy, sz = rng.random(), rng.random(), rng.random()
        if rng.random() > streak_share:
            continue
        at_c = _snapped(LAKE_FAR_C + sy * (lake_h - PIXEL), PIXEL)
        at = S(at_c)
        step = 0
        for top, bot, st in rows:
            if top <= at < bot:
                step = st
        long_px = STREAK_LONG[0] + (STREAK_LONG[1] - STREAK_LONG[0]) * (sz * (0.3 + 0.7 * sy))
        x0 = S(_snapped(sx * (1280 + 80) - 80, PIXEL))
        x1 = x0 + S(_snapped(long_px * PIXEL, PIXEL))
        c = ramp[min(step + 1, 4)]
        out[at - LAKE_FAR:at - LAKE_FAR + 3, max(0, x0):max(0, min(W, x1))] = c
    foam = _rgb("foam_dirty") if state >= 3 else _rgb("foam")
    out[0:3] = foam
    x = 0.0
    span = 0
    while S(x) < W:
        up = math.sin(lap_phase * math.tau + span * 1.7) > 0.2
        x0, x1 = S(x), min(W, S(x + LAP_LONG))
        out[-3:, x0:x1] = ramp[3] if up else foam
        x += LAP_LONG
        span += 1
    return np.clip(np.round(out * ink), 0, 255)


# =============================================================================================
# The plates: what to clean, what is the step's own work
# =============================================================================================
# Rectangles (x0, y0, x1, y1), window px.
UI_KEEP = [(755, 0, 1166, 120), (1822, 12, 1898, 70)]          # the steps bar, the cross
CARD = {"catch": (645, 950, 1276, 1045), "pour": (570, 950, 1350, 1045)}
DOG = {"catch": (1520, 548, 1702, 686), "pour": (222, 596, 568, 842)}
# The backdrop's pigeons are taken out of the hive room in every step (a dark speck the size
# of a bee says "not bees"): no bird is kept, they are scrubbed back to sky (SCRUB).
BIRDS_KEEP = {}
# Over the bank and the lake the work is cut by hand: these are opaque wood and brass, so a
# rectangle is the piece (the bank and the rubbish only stand behind them).
WORK_RECTS = {
    "catch": [],
    "pour": [
        (798, 160, 1124, 438),   # the bucket, its rim up in the sky
        (759, 435, 1161, 468),   # the table top, its foot's outline
        (789, 466, 813, 600),    # left leg
        (1107, 466, 1131, 600),  # right leg
        (935, 458, 989, 499),    # the gate's head
        (945, 499, 975, 517),    # its neck
        (986, 471, 1062, 489),   # the lever
    ],
}
STREAM = (945, 517, 984, 600)
# Today's clumps in the catch sky, scrubbed back to sky and cloud (look.clean_bees leaves the
# densest of them smeared): any cell whose colour the sky elsewhere does not hold is refilled.
SCRUB = {"catch": [(1536, 250, 1866, 362), (1060, 330, 1300, 362)],
         "pour": [(536, 120, 634, 182)],                   # its two pigeons
         "uncap": [(70, 140, 172, 212)],                   # its two pigeons
         "done": [(700, 105, 800, 182)]}                   # its two pigeons
# Where today's swarm stood on the catch plate (the heap on the box is replaced too).
HEAP = (826, 618, 1132, 738)
BOX_AT = (263, 233)                 # the box piece's art cell on the room grid (matched)


def clean_sky(p, name):
    """The plate's sky and treetops with today's bees off: look.clean_bees over everything
    above the far waterline but the UI and the pigeons, in strips round them."""
    keep = UI_KEEP + BIRDS_KEEP.get(name, []) + [r for r in WORK_RECTS.get(name, []) if r[1] < LAKE_FAR]
    mask = np.ones((LAKE_FAR, W), bool)
    for x0, y0, x1, y1 in keep:
        mask[max(0, y0):min(LAKE_FAR, y1), x0:x1] = False
    # clean_bees works on a box; walk the free cells in boxes of art rows
    snapshot = np.array(p).copy()
    look.clean_bees(p, (0, 0, W, LAKE_FAR), G, (0, 0))
    a = np.array(p)
    a[:LAKE_FAR][~mask] = snapshot[:LAKE_FAR][~mask]
    p.paste(Image.fromarray(a))
    return p


def bank_alpha():
    """Which window px of the far bank's rows are tree or sand (the strip opaque there)."""
    ys = np.arange(BANK_TOP, LAKE_FAR)
    xs = np.arange(W)
    kr = np.clip(np.floor(ys / STRETCH - BANK_TOP_C).astype(int), 0, BANK_TALL - 1)
    kc = (np.floor(xs / STRETCH).astype(int) + BANK_OFFSET) % 960
    return _bank[kr[:, None], kc[None, :], 3] > 0


def sky_behind_trees(a, boxes, only_dark=False):
    """Inside `boxes`, the sky showing between the far bank's crowns is refilled from the
    nearest open sky of the same row outside the box (a hull's mast stood there). With
    only_dark, only what is too dark to be sky or cloud is refilled (today's bees)."""
    opaque = bank_alpha()

    def skyish(px):
        return int(px[0]) + int(px[1]) + int(px[2]) > 420
    for x0, y0, x1, y1 in boxes:
        for y in range(max(y0, BANK_TOP), min(y1, LAKE_FAR)):
            r = y - BANK_TOP
            for x in range(x0, x1):
                if opaque[r, x] or (only_dark and skyish(a[y, x])):
                    continue
                for k in range(1, 600):
                    hit = None
                    for xx in (x0 - k, x1 - 1 + k):
                        if 0 <= xx < W and not opaque[r, xx] and skyish(a[y, xx]):
                            hit = xx
                            break
                    if hit is not None:
                        a[y, x, :3] = a[y, hit, :3]
                        break
    return a


OLD_BEE_INK = {(24, 18, 17), (244, 184, 40), (116, 76, 40), (44, 30, 20), (34, 24, 18)}


def scrub(a, boxes, keep=()):
    """Refill every art cell of the sky (above the far waterline) whose colour is not one of the
    open sky's own (a colour the free sky holds at least 20 cells of, today's bee inks out) with
    the nearest good cell along its row. `boxes` are today's dense clumps, left out of the count;
    `keep` (the UI, the pigeons, the work) is left alone."""
    from collections import Counter
    mid = G // 2
    cells = a[mid:LAKE_FAR:G, mid::G, :3]
    rows, cols = cells.shape[:2]
    free = np.ones((rows, cols), bool)
    for x0, y0, x1, y1 in list(boxes) + list(keep):
        free[y0 // G:(y1 + G - 1) // G, x0 // G:(x1 + G - 1) // G] = False
    count = Counter(tuple(int(v) for v in c) for c in cells[free])
    sky = {c for c, n in count.items() if n >= 20 and c not in OLD_BEE_INK}
    hold = np.zeros((rows, cols), bool)
    for x0, y0, x1, y1 in keep:
        hold[y0 // G:(y1 + G - 1) // G, x0 // G:(x1 + G - 1) // G] = True
    for r in range(rows):
        good = [tuple(int(v) for v in cells[r, c]) in sky for c in range(cols)]
        src_row = cells[r].copy()
        for c in range(cols):
            if good[c] or hold[r, c]:
                continue
            for k in range(1, 80):
                hit = None
                for cc in (c - k, c + k):
                    if 0 <= cc < cols and good[cc] and not hold[r, cc]:
                        hit = cc
                        break
                if hit is not None:
                    a[r * G:(r + 1) * G, c * G:(c + 1) * G, :3] = src_row[hit]
                    break
    return a


def _rod(c):
    """The gate's wooden rod and brass where they stand over the bucket: browns and golds (the
    far bank's own red trunks are darker in green than any of these)."""
    r, g, b = c[..., 0].astype(int), c[..., 1].astype(int), c[..., 2].astype(int)
    return (r > g) & (g > b) & (r - b > 30) & (r > 80) & (g > 50)


def scrub_birds(a, name):
    """The pigeons out of the SCRUB boxes outright, pixel by pixel (they are not on the room's
    grid): a pixel darker than any sky or cloud, or a low-saturation grey no cloud is, grown by
    three px to take the pale wing fringe, takes the nearest clear pixel of its own row."""
    for x0, y0, x1, y1 in SCRUB.get(name, []):
        c = a[y0:y1, x0:x1, :3].astype(int)
        lo, hi = c.min(-1), c.max(-1)
        bird = (c.sum(-1) < 420) | ((hi - lo < 25) & (c.sum(-1) < 600))
        bird = dilate(bird, 3, 3)
        for r in range(bird.shape[0]):
            row = a[y0 + r, :, :3].copy()
            for cc in np.nonzero(bird[r])[0]:
                for k in range(1, 200):
                    hit = None
                    for q in (cc - k, cc + k):
                        if 0 <= q < bird.shape[1] and not bird[r, q]:
                            hit = x0 + q
                            break
                        if (q < 0 and x0 + q >= 0) or (q >= bird.shape[1] and x0 + q < W):
                            hit = x0 + q
                            break
                    if hit is not None:
                        a[y0 + r, x0 + cc, :3] = row[hit]
                        break
    return a


def clean_view(name, state, veil=0.0, lap_phase=0.0):
    """The plate's view with nothing on it: the sky (bees off), the bank, the lake in `state`,
    the lawn, plus the step's own work lifted back on. Returns (view RGBA, work RGBA, ink)."""
    plate = look.plate(name)
    pa = np.array(plate)
    ink = fit_ink(pa)
    sky = clean_sky(plate.copy(), name)
    sa = np.array(sky)
    keep = UI_KEEP + BIRDS_KEEP.get(name, []) + [r for r in WORK_RECTS.get(name, []) if r[1] < LAKE_FAR]
    scrub(sa, SCRUB.get(name, []), keep)
    if name != "catch":
        scrub_birds(sa, name)
    if name == "catch":
        # the mast of the ferry stands over the treeline's sky gaps
        bank_sky = sky_behind_trees(sa.copy(), [(1356, BANK_TOP, 1492, LAKE_FAR)])
        sky_behind_trees(bank_sky, [(1040, BANK_TOP, 1300, LAKE_FAR),
                                    (1536, BANK_TOP, 1866, LAKE_FAR)], only_dark=True)
    else:
        bank_sky = sa.copy()
    view = sa.copy()
    bank, trees = render_bank(pa, ink, bank_sky)
    view[BANK_TOP:LAKE_FAR, :, :3] = bank
    view[LAKE_FAR:LAKE_NEAR, :, :3] = render_lake(state, ink, lap_phase=lap_phase,
                                                  streak_share=0.7 * (1.0 - 0.5 * (veil > 0)))
    lawn = render_lawn(ink)
    view[LAKE_NEAR:, :, :3] = lawn
    view[..., 3] = 255
    if veil > 0:
        apply_veil(view, veil, trees)
    # the work
    work = np.zeros_like(pa)
    diff = np.abs(pa[LAKE_NEAR:, :, :3].astype(int) - lawn.astype(int)).max(-1) > 4
    m = np.zeros((H, W), bool)
    m[LAKE_NEAR:] = diff
    x0, y0, x1, y1 = DOG[name]
    m[y0:y1, x0:x1] = False
    if name == "catch":
        x0, y0, x1, y1 = HEAP
        m[y0:y1, x0:x1] = False
    for x0, y0, x1, y1 in WORK_RECTS.get(name, []):
        m[y0:y1, x0:x1] = True
    if name == "pour":
        # the bucket's sides over the far bank: only its own mint and outline, not the trees
        x0, y0, x1, y1 = WORK_RECTS["pour"][0]
        y0 = max(y0, BANK_TOP)
        c = pa[y0:y1, x0:x1, :3].astype(int)
        mint = (c[..., 0] > 130) & (c[..., 1] > 180) & (c[..., 2] > 160)
        ink_px = (c[..., 0] == 24) & (c[..., 1] == 18) & (c[..., 2] == 17)
        m[y0:y1, x0:x1] = mint | ink_px | _rod(c)
    if name == "pour":
        # the honey stream over the lake: its own colours, nothing behind it
        x0, y0, x1, y1 = STREAM
        c = pa[y0:y1, x0:x1, :3].astype(int)
        honey = (c[..., 1] > 0.35 * c[..., 0]) & (c[..., 0] - c[..., 2] > 100) & (c[..., 0] > 140)
        m[y0:y1, x0:x1] |= honey
    work[m] = pa[m]
    work[m, 3] = 255
    work_im = Image.fromarray(work)
    if name == "catch":
        box, _ = look.room_piece("box")
        top = box.crop((0, 0, box.width, 14))
        under = Image.new("RGBA", work_im.size, (0, 0, 0, 0))
        look.place_art(under, top, BOX_AT, G)
        work_im.alpha_composite(under)
    return Image.fromarray(view), work_im, ink


# =============================================================================================
# The veil: the far bank and the lake taken towards the sky's low step, in stepped bands
# (nearer, less), a mix of the plate's own swatches; the streaks halved.
# =============================================================================================
def sky_low(view):
    """The lowest sky step, read off the plate's sky just above the treeline."""
    from collections import Counter
    row = [tuple(c) for c in view[340, ::3, :3]]
    return np.array(Counter(row).most_common(1)[0][0], float)


# How much of the sky's low step each band takes at full strength: the far bank's trees most,
# the far water a little less, the near water least (three steps, hard edges at the bands).
VEIL_BANK = 0.42
VEIL_LAKE = (0.36, 0.30, 0.24)


def apply_veil(view, strength, trees):
    target = sky_low(view)
    a = view[..., :3].astype(float)
    t = VEIL_BANK * strength
    bank = a[BANK_TOP:LAKE_FAR]
    bank[trees] = bank[trees] + (target - bank[trees]) * t
    for i, (top, bot, _) in enumerate(lake_rows()):
        t = (VEIL_LAKE[0] if i < 3 else (VEIL_LAKE[1] if i < 5 else VEIL_LAKE[2])) * strength
        a[top:bot] = a[top:bot] + (target - a[top:bot]) * t
    view[..., :3] = np.clip(np.round(a), 0, 255)


# =============================================================================================
# Masks on the art grid, numpy only (no scipy in the venv)
# =============================================================================================
def _shift(m, dy, dx):
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = m[ys, xs]
    return out


def dilate(m, rx, ry):
    out = m.copy()
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if dx or dy:
                out |= _shift(m, dy, dx)
    return out


def erode(m, rx, ry):
    return ~dilate(~m, rx, ry)


def fill_holes(m):
    """`m` with every clear pixel not reachable from the top, left or right edge through clear
    pixels filled (the bottom edge is the window's foot, behind which the bed carries on)."""
    out = np.zeros_like(m)
    out[0] = ~m[0]
    out[:, 0] |= ~m[:, 0]
    out[:, -1] |= ~m[:, -1]
    while True:
        grow = out | _shift(out, 1, 0) | _shift(out, -1, 0) | _shift(out, 0, 1) | _shift(out, 0, -1)
        grow &= ~m
        if (grow == out).all():
            return m | ~out
        out = grow


def components(m):
    """[(cells [(y, x)], ...)] of the 8-connected parts of a small boolean grid."""
    seen = np.zeros_like(m)
    out = []
    h, w = m.shape
    for y0, x0 in zip(*np.nonzero(m)):
        if seen[y0, x0]:
            continue
        stack_ = [(y0, x0)]
        seen[y0, x0] = True
        part = []
        while stack_:
            y, x = stack_.pop()
            part.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and m[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack_.append((yy, xx))
        out.append(part)
    return out


# =============================================================================================
# The bed: real pieces of assets/flora.png at the room's grain, on a leaf body, ringed once.
# =============================================================================================
_FLORA = json.load(open(os.path.join(ROOT, "assets/flora.json")))
_FLORA_SHEET = Image.open(os.path.join(ROOT, "assets/flora.png")).convert("RGBA")


def flora(name):
    x, y, w, h = _FLORA[name]["full"]
    return _FLORA_SHEET.crop((x, y, x + w, y + h))


GRID_W, GRID_H = look.ROOM_GRID

# Pieces by colour family (the head colours measured off flora.png) and by SIZE, which is what
# grades the bed's depth: the window's foot is nearest the eye, so its rows take the biggest
# heads (the 7x8 discs and the 6x6 crosses, at least half a bee wide) and the pack's coarse
# 30x14 clumps; the middle rows the 5x7 tulips; the back rows, by the lawn behind, the 3x5
# heads and the clovers. The mass gets taller and coarser as it nears the window's foot.
CLUMP = {"white": "pk_bed_0", "pink": "pk_bed_1", "blue": "pk_bed_7", "yellow": "pk_bed_3",
         "lilac": "pk_bed_1"}
BIG = {"white": ["pk_flower_0", "pk_flower_3", "pk_flower_2"],      # 212 / 198 discs and crosses
       "pink": ["pk_flower_4"],                                     # 223,188,188 disc
       "blue": ["pk_flower_1", "pk_flower_6"],                      # 179,195,223 disc, 179,189,198
       "yellow": ["pk_flower_8", "pk_flower_3"],                    # 178,168,113 (and white)
       "lilac": ["pk_flower_5", "pk_flower_7"]}                     # 226,195,227 disc
MID = {"white": ["pk_flower_13"], "pink": ["pk_flower_9"], "blue": ["pk_flower_12"],
       "yellow": ["pk_flower_8"], "lilac": ["pk_flower_7"]}
SMALL = {"white": ["pk_flower_15", "clover_white"], "pink": ["clover_pink", "thrift"],
         "blue": ["pk_flower_14"], "yellow": ["pk_flower_10"], "lilac": ["pk_flower_11"]}
GREEN_BODY = ["pk_leafy_a", "pk_fern", "pk_leafy_b"]
# How often a front-row piece is its family's clump rather than a single head (coarse, 14 tall).
FRONT_CLUMPS = 0.28
FAMILIES = ("blue", "white", "pink", "yellow", "lilac")
DRIFT_ORDER = ["blue", "white", "pink", "yellow", "lilac", "white", "pink", "blue", "yellow"]

# The leaf body under and between the heads: two hard steps, the lawn's darkest blade swatch
# (grass_dark) and that taken towards the outline ink, so the gaps between heads are leafy
# shade rather than outline black or bare lawn. Lit on the mass's top edge (sun top left),
# deep straight under a head.
LEAF_LIT = look.PAL["grass_dark"]
LEAF_DEEP = look.mix(look.PAL["grass_dark"], look.OUT, 0.45)


def _hash(x, y, s=0):
    v = ((int(x) * 73856093) ^ (int(y) * 19349663) ^ (int(s) * 83492791)) & 0xffffffff
    v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
    return ((v ^ (v >> 16)) & 0xffff) / 65535.0


def _paste_clip(dst, im, left, top):
    x0, y0 = max(0, -left), max(0, -top)
    x1 = min(im.width, dst.width - left)
    y1 = min(im.height, dst.height - top)
    if x0 >= x1 or y0 >= y1:
        return
    part = im.crop((x0, y0, x1, y1))
    dst.alpha_composite(part, (max(0, left), max(0, top)))


def ring_open_foot(im, col=look.OUT):
    """look.ring, less the row under a flat foot: a clear pixel whose only opaque 4-neighbour is
    the one above it stays clear. A plant stands in the lawn, so its foot gets no black line
    (that read as a plate under every clump); the contact shade grounds it instead."""
    a = np.array(im)[..., 3] > 40
    p = np.pad(a, 1)
    up, down = p[:-2, 1:-1], p[2:, 1:-1]
    left, right = p[1:-1, :-2], p[1:-1, 2:]
    edge = ~a & (up | down | left | right)
    foot = ~a & up & ~down & ~left & ~right
    edge &= ~foot
    out = np.array(im).copy()
    out[edge] = col
    return Image.fromarray(out)


def _is_flower(px):
    r, g, b, al = (int(v) for v in px)
    if al < 200:
        return False
    if g > r + 6 and g > b + 6:      # leaf
        return False
    return r + g + b >= 150          # not the outline or a shadow


def top_heads(layer):
    """Every flower pixel the bed shows (the finished composite), above the window's foot:
    [(x, y)] on the room grid. Where a bee may work."""
    a = np.array(layer)
    ys, xs = np.nonzero(a[:GRID_H - 4, :GRID_W, 3] > 200)
    return [(int(x), int(y)) for x, y in zip(xs, ys) if _is_flower(a[y, x])]


def bed_layer(layout):
    """The bed at one pixel per art pixel on the room grid: the pieces composited back to front
    by their feet; their silhouette closed (gaps of up to two art px across and one down) and
    its holes filled, the space between pieces filled with the leaf body; then the WHOLE mass
    ringed once in the game's outline ink, open at the foot. Inside the mass there is no outline
    ink at all (the pack pieces carry none; the old mesh was the ring drawn round every hole).
    Returns (layer, spots, silhouette)."""
    pieces = Image.new("RGBA", (GRID_W, GRID_H + 24), (0, 0, 0, 0))
    for name, fx, fy in sorted(layout, key=lambda t: (t[2], t[1])):
        im = flora(name)
        _paste_clip(pieces, im, fx - im.width // 2, fy - im.height)
    pa = np.array(pieces)
    M = pa[..., 3] > 40
    S = erode(dilate(M, 2, 1), 2, 1) | M
    S = fill_holes(S)
    body = S & ~M
    out = np.zeros_like(pa)
    above_out = ~_shift(S, 1, 0)                 # the pixel above is outside the mass
    above_piece = _shift(M, 1, 0)
    ys, xs = np.nonzero(body)
    for y, x in zip(ys, xs):
        if above_out[y, x]:
            c = LEAF_LIT
        elif above_piece[y, x]:
            c = LEAF_DEEP
        else:
            c = LEAF_LIT if _hash((x + 2 * ((y // 2) % 2)) // 3, y // 2, 7) < 0.34 else LEAF_DEEP
        out[y, x] = c
    out[M] = pa[M]
    out[M, 3] = 255
    layer = ring_open_foot(Image.fromarray(out))
    return layer, top_heads(layer), S


def shade_bed(view, layer):
    """The contact shade: under the mass's lowest row in every column, one art row of lawn taken
    a third of the way to the outline ink, one art px to the right (the room's sun is top left).
    Hard edges, on the grid."""
    a = np.array(layer)[..., 3] > 0
    out_ink = np.array(look.OUT[:3], float)
    for x in range(a.shape[1] - 1):
        col = np.nonzero(a[:GRID_H, x])[0]
        if not len(col):
            continue
        y = col.max() + 1
        px, py = (x + 1) * G, y * G
        if py < H:
            cell = view[py:py + G, px:px + G, :3].astype(float)
            view[py:py + G, px:px + G, :3] = np.round(cell + (out_ink - cell) * 0.33)


def lay_bed(view, layout):
    """Lay the bed onto `view` (numpy RGBA, window px) at the room's grain, drawn over the
    backdrop's darken as its birds and dogs are, so the heads carry. Returns (spots, sil)."""
    layer, spots, sil = bed_layer(layout)
    shade_bed(view, layer)
    img = Image.fromarray(view)
    look.place_art(img, layer, (0, 0), G)
    view[:] = np.array(img)
    return spots, sil, layer


def drift_map(rng, x0=-40, x1=700, span=(30, 52), order=DRIFT_ORDER, start=0):
    """[(x from, x to, family)] along a row: drifts of one colour."""
    out = []
    x = x0
    k = start
    while x < x1:
        w = rng.uniform(*span)
        out.append((x, x + w, order[k % len(order)]))
        x += w
        k += 1
    return out


def family_at(drifts, x):
    for a, b, fam in drifts:
        if a <= x < b:
            return fam
    return drifts[-1][2]


def pool_of(kind, fam, rng, filler):
    if kind == "green":
        return GREEN_BODY
    if kind == "clump":
        return [CLUMP[fam]]
    if kind == "big":
        if rng.random() < FRONT_CLUMPS:
            return [CLUMP[fam]]
        return BIG["white"] if rng.random() < filler else BIG[fam]
    if kind == "mid":
        return MID["white"] if rng.random() < filler else MID[fam]
    return SMALL[fam]


def drift_rows(rng, rows, drifts, filler=0.08, mirror=False, lean=5):
    """A bed out of rows, planted in drifts: each (foot y, x from, x to, step, kind, jitter) lays
    a piece every `step` art px. kind is 'small' (back rows), 'mid', 'big' (front rows: the big
    heads and now and then the family's clump), 'clump' or 'green' (the leafy body plants). Each
    row reads the drift map shifted `lean` art px a row, so a drift's edge leans; `filler` of the
    heads are white whatever the drift."""
    out = []
    for i, (fy, x0, x1, step, kind, jit) in enumerate(rows):
        # brick-laid: each row half a step on from the last, so a head stands over the gap
        # between two of the row behind and the leaf body shows round it
        x = x0 + ((i % 2) * 0.5 + rng.uniform(0, 0.15)) * step
        last = None
        while x <= x1:
            fam = family_at(drifts, x + i * lean)
            pool = pool_of(kind, fam, rng, filler)
            choices = [p for p in pool if p != last] or pool
            name = rng.choice(choices)
            last = name
            fx = int(round(x + rng.uniform(-jit, jit)))
            fyy = int(round(fy + rng.uniform(-jit * 0.4, jit * 0.4)))
            out.append((name, GRID_W - fx if mirror else fx, fyy))
            x += step * rng.uniform(0.92, 1.08)
    return out


# =============================================================================================
# Bees: look's bee (variant A) for every one, at the room's grain, unveiled. Flight frames are
# the ones with the wings swept back (look.bee fly 1 and 4, hover 1): with the wings up (frames 0
# and 3) or flat (2 and 5) they sit over the head and at 1x the bee reads as a barrel with a bar
# on top; swept back they leave the eye and its glint in the clear.
# =============================================================================================
FLY_FRAMES = (1, 4)
HOVER_FRAMES = (1,)
# Two bees keep at least two art px between their boxes (the body with its outline is 10x7).
BEE_APART = (12, 10)


def put_bee(img, ax, ay, pose="hover", frame=0, left=False, mini=False):
    """A bee with its body's middle on art cell (ax, ay) of the room grid."""
    if mini:
        im = look.mini_bee(BEE, frame, facing_left=left, pose=pose)
        anc = look.mini_anchor(BEE, pose, left, frame)
    else:
        im = look.bee(BEE, frame, facing_left=left, pose=pose)
        anc = look.bee_anchor(BEE, pose, left, frame)
    look.place_art(img, im, (ax - anc[0], ay - anc[1]), G)


def _clear_of(bx, by, used):
    return all(abs(bx - u) >= BEE_APART[0] or abs(by - v) >= BEE_APART[1] for u, v in used)


# The prompt card's art columns (the widest card, pour's): a bee under it is not seen.
CARD_COLS = (188, 452)


def bees_at_bed(img, spots, plan, sil, used, seed=5):
    """`plan` [(pose, count)]: 'hover' beside a head and facing it, 'rest' on a head, 'fly' a
    little way over the bed. The bed's width is cut into as many bins as there are bees and each
    bee works a head in its own bin; poses are shuffled. Every bee keeps inside the bed's
    silhouette plus one bee's width (no bee working bare lawn), and two art px clear of every
    other bee in `used` (shared by the whole scene). Heads under the prompt card are left out."""
    rng = random.Random(seed)
    spots = [s for s in spots if not (CARD_COLS[0] <= s[0] <= CARD_COLS[1] and s[1] > 310)]
    if not spots:
        return used
    near = dilate(sil, 10, 9)
    poses = [p for p, n in plan for _ in range(n)]
    rng.shuffle(poses)
    x0 = min(s[0] for s in spots)
    x1 = max(s[0] for s in spots) + 1
    poses = poses[:max(1, (x1 - x0) // 15)]
    n = len(poses)
    for i, pose in enumerate(poses):
        lo, hi = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
        cand = [s for s in spots if lo <= s[0] < hi] or spots
        for attempt in range(120):
            sx, sy = rng.choice(cand if attempt < 60 else spots)
            left = rng.random() < 0.5
            if pose == "rest":
                bx, by, look_pose, fr = sx, sy - 3, "rest", rng.randrange(3)
            elif pose == "hover":
                side = -1 if left else 1
                bx, by = sx - side * 7, sy - rng.randint(3, 7)
                look_pose, fr = "hover", rng.choice(HOVER_FRAMES)
            else:
                bx, by = sx + rng.randint(-6, 6), sy - rng.randint(9, 15)
                look_pose, fr = "fly", rng.choice(FLY_FRAMES)
            if not (0 <= by < near.shape[0] and 0 <= bx < near.shape[1]) or not near[by, bx]:
                continue
            if CARD_COLS[0] - 6 <= bx <= CARD_COLS[1] + 6 and by > 305:
                continue
            if _clear_of(bx, by, used):
                used.append((bx, by))
                put_bee(img, bx, by, look_pose, fr, left)
                break
    return used


# =============================================================================================
# The step's own bees, in today's places, as look's bee: the catch sky's two clumps and its
# loose flyers and the heap on the box (measured off the catch plate: today's bee yellow
# 244,184,40 clustered), the pour sky's six wanderers (HiveStep.wanderers).
# =============================================================================================
CATCH_CLUMPS = [((1164, 492), 11), ((1656, 372), 12)]           # window px of the middle, seed
CATCH_FLYERS = [  # (x, y, bees) window px
    (1176, 180, 2), (1560, 276, 2), (732, 504, 2), (1536, 528, 2), (1572, 168, 1), (924, 180, 1),
    (1380, 180, 1), (864, 204, 1), (1788, 204, 1), (660, 228, 1), (948, 240, 1), (1368, 228, 1),
    (336, 276, 1), (1284, 276, 1), (1716, 276, 1), (240, 300, 1), (456, 300, 1), (720, 300, 1),
    (1188, 324, 1), (1812, 372, 1), (852, 396, 1), (1740, 420, 1), (480, 444, 1), (336, 528, 1),
    (516, 528, 1), (1632, 540, 1),
]
POUR_FLYERS = [(564, 60), (1140, 204), (516, 228), (348, 252), (516, 396), (336, 444)]
HEAP_MID = (320, 240)            # art: the middle of the heap's foot on the box's top bars


def flyers_at(img, points, used, rng, blocked=None):
    """Loose bees at art points, kept two art px apart from each other and from `used`, and (with
    `blocked`, an art-grid mask of the step's work) never half under the work."""
    for ax, ay in points:
        for k in range(12):
            bx, by = ax + (k % 4) * 4 * (1 if k % 2 else -1), ay + (k // 4) * 4
            if blocked is not None and blocked[max(0, by - 5):by + 5, max(0, bx - 7):bx + 7].any():
                continue
            if _clear_of(bx, by, used):
                used.append((bx, by))
                put_bee(img, bx, by, "fly", rng.choice(FLY_FRAMES), rng.random() < 0.5)
                break


def work_cells(work, extra=()):
    """The art cells the step's work covers (plus `extra` boxes, window px): no loose bee is put
    half under the work."""
    wa = np.array(work)[..., 3] > 0
    blocked = np.zeros((GRID_H, GRID_W), bool)
    for dy in range(G):
        for dx in range(G):
            blocked |= wa[dy::G, dx::G][:GRID_H, :GRID_W]
    for x0, y0, x1, y1 in extra:
        blocked[y0 // G:y1 // G + 1, x0 // G:x1 // G + 1] = True
    return blocked


def step_bees(img, name, used, frame=0, blocked=None):
    rng = random.Random(77 if name == "catch" else 78)
    if name == "catch":
        for (x, y), seed in CATCH_CLUMPS:
            cl = look.swarm(BEE, n=40, seed=seed, box=(84, 66), frame=frame)
            look.place_art(img, cl, (x // G - cl.width // 2, y // G - cl.height // 2), G)
        pts = []
        for x, y, n in CATCH_FLYERS:
            for k in range(n):
                pts.append((x // G + k * 14 - (n - 1) * 7, y // G + k * 4))
        flyers_at(img, pts, used, rng, blocked)
        heap = look.swarm(BEE, n=34, seed=21, box=(110, 54), frame=frame, shape="mound",
                          loose=0.0, depth=0.3)
        bb = heap.getbbox()
        look.place_art(img, heap, (HEAP_MID[0] - (bb[0] + bb[2]) // 2, HEAP_MID[1] - bb[3]), G)
    elif name == "pour":
        flyers_at(img, [(x // G, y // G) for x, y in POUR_FLYERS], used, rng, blocked)


# =============================================================================================
# The three beds on the room grid (640 x 360; the sand meets the lawn on row 237, the window's
# foot is row 360). One layout for every step, so nothing may stand where any step's work does:
# the lawn common to all seven plates is the two bottom corners (window x < 380 and x > 1700,
# art x < 127 and x > 567) and the strip under the prompt card (window y > 1045, art row 349).
# Every bed is graded by depth: small heads at the back, tulips, then big heads and clumps at
# the window's foot.
# =============================================================================================
def bed_A():
    """Low hedge: the whole width along the window's foot, in long drifts of colour, back to
    front: a row of small heads, the clumps, a row of tulips, then four rows of big heads;
    20-24 art px tall; under the card and behind the uncap bucket it simply goes on."""
    rng = random.Random(21)
    drifts = drift_map(rng, span=(44, 70))
    return drift_rows(rng, [
        (338, -6, 650, 6, "small", 1),
        (343, -14, 656, 17, "clump", 2),
        (345, -6, 650, 8, "mid", 1),
        (350, -2, 646, 9, "big", 1),
        (355, -6, 652, 9, "big", 1),
        (360, -2, 646, 9, "big", 1),
        (365, -6, 652, 9, "big", 1),
    ], drifts, lean=4)


def bed_B():
    """Corner borders: lush in both bottom corners, tallest at the window's edge (the pack's
    leafy plants and fern behind), back to front: small heads, clumps, tulips, then big heads
    and clumps; the leading edge stepping down as it sweeps out about a third of the way in.
    The middle stays bare lawn."""
    out = []
    for side, seed in ((False, 31), (True, 37)):
        rng = random.Random(seed)
        drifts = drift_map(rng, x0=-30, x1=260, span=(36, 56), start=seed % 5)
        out += drift_rows(rng, [
            (322, -14, 26, 18, "green", 2),
            (330, 8, 70, 18, "green", 3),
            (332, -8, 82, 6, "small", 1),
            (337, -10, 104, 16, "clump", 2),
            (340, -4, 128, 7, "mid", 1),
            (345, -4, 152, 9, "big", 1),
            (350, -2, 174, 9, "big", 1),
            (355, 0, 194, 9, "big", 1),
            (360, 0, 210, 9, "big", 1),
            (365, 24, 222, 9, "big", 1),
        ], drifts, mirror=side, lean=6)
    return out


# Posies in the free corners at two depths, and heads along the foot: (centre x, foot y, size)
# on the room grid. The sand-edge posies of the last pass are gone (3x5 heads with the small bee
# there read as weeds at 1x, the small bee no smaller than the near ones).
CLUMPS = [
    (60, 302, "mid"), (612, 304, "mid"),
    (22, 348, "big"), (112, 356, "big"), (596, 352, "big"),
    (172, 361, "foot"), (476, 361, "foot"),
]
CLUMP_FAMILY = ["blue", "pink", "white", "yellow", "lilac", "pink", "white"]


def _dome(rng, out, fam, cx, fy, rows):
    """A rounded posy: rows (kind, n, reach, dy) of heads, the middle ones highest."""
    for kind, n, reach, dy in rows:
        for j in range(n):
            t = (j - (n - 1) / 2.0) / max((n - 1) / 2.0, 1)
            pool = {"small": SMALL, "mid": MID, "big": BIG}[kind][fam]
            out.append((rng.choice(pool), cx + int(round(t * reach)) + rng.randint(-1, 1),
                        fy + dy + int(round(abs(t) * 3)) + rng.randint(0, 1)))


def bed_C():
    """Posies: separate rounded clumps over both free corners, each one colour, every one a
    dome of 18-21 heads in front of low fern leaves; a few big heads along the window's foot."""
    rng = random.Random(41)
    out = []
    for k, (cx, fy, size) in enumerate(CLUMPS):
        fam = CLUMP_FAMILY[k % len(CLUMP_FAMILY)]
        if size == "foot":
            for j in range(10):
                out.append((rng.choice(BIG[fam]), cx + rng.randint(-22, 22), fy + rng.randint(-1, 1)))
            continue
        out.append(("pk_fern", cx - 3, fy - 7))       # low leaves: the heads lead, not the plant
        out.append((CLUMP[fam], cx + 2, fy - 5))
        if size == "big":
            _dome(rng, out, fam, cx, fy, [("small", 6, 11, -7), ("mid", 7, 15, -3), ("big", 8, 21, 2)])
        else:
            _dome(rng, out, fam, cx, fy, [("small", 6, 10, -5), ("mid", 7, 14, -1), ("big", 5, 13, 3)])
    return [(n, max(-10, min(650, x)), y) for n, x, y in out]


# =============================================================================================
# One scene
# =============================================================================================
OPTIONS = {
    # label: (name, bed, bees (pose, count) per half, caption)
    "A": ("LOW HEDGE", bed_A, [("hover", 2), ("rest", 2), ("fly", 1)],
          "A low hedge right along the window's foot, the whole width, graded by depth (small "
          "heads behind, then the pack's clumps, tulips, and four rows of the big heads at the "
          "foot), on a dark leaf body, 20-24 art px tall, ten bees at it."),
    "B": ("CORNER BORDERS", bed_B, [("hover", 3), ("rest", 2), ("fly", 1)],
          "Lush borders in both bottom corners, tallest at the window's edge (leafy plants and "
          "fern behind, small heads, clumps, tulips, then five rows of big heads at the foot) on a "
          "dark leaf body, stepping down as they sweep a third of the way in; twelve bees."),
    "C": ("POSIES", bed_C, [("hover", 3), ("rest", 2)],
          "Separate posies over both free corners at two depths, each one colour and each a dome "
          "of 18-21 heads (small on top, big in front) on its leaves; a few big heads along the "
          "foot."),
}
STATES_SHOWN = {"catch": 4, "pour": 1}      # the catch as captured (dirty); the pour later (hazy)
# Every option scene is shown under the SAME veil, so the beds compare like for like; the veil
# is its own decision (the VEIL row: none / 0.6 / 1.0 on one bed).
SCENE_VEIL = 0.6
VEILS = (0.0, 0.6, 1.0)


def _halves(spots):
    return ([s for s in spots if s[0] < 320], [s for s in spots if s[0] >= 320])


def compose(opt, name, veil=SCENE_VEIL):
    title, bed, plan, _ = OPTIONS[opt]
    state = STATES_SHOWN[name]
    view, work, ink = clean_view(name, state, veil)
    va = np.array(view)
    spots, sil, _ = lay_bed(va, bed())
    img = Image.fromarray(va)
    used = []
    step_bees(img, name, used, blocked=work_cells(work))
    for k, part in enumerate(_halves(spots)):
        bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
    img.alpha_composite(work)
    return img


# =============================================================================================
# The CHECK row: the smoke, uncap and done steps, the view redrawn as the A/B/C scenes are (no
# rubbish, no ferries, no dogs, the mock's far bank, the recommended bed and veil), the step's
# work lifted back off its capture.
# =============================================================================================
# How the work is found, per capture (window px): sky boxes are taken whole (the scene's sky is
# that capture's own sky, today's bees off); bank boxes keep what differs from today's far bank
# redrawn with the capture's ink (exact, so only the work differs); lake boxes keep what is not
# one of the lake's own colours (the state's ramp times the ink, the foam); everything below the
# lake is what differs from the lawn redrawn, less `drop` (a dog, a ferry), less small parts in
# today's bee yellow (today's bees, redrawn as look's bee where they were). A box may carry a
# colour test: 'grey' (the smoke), 'gold' (the gate, the crown), 'curtain' (the honey curtains
# in front of uncap's dog).
CHECK = {
    "smoke": {"state": 4,
              "sky": [(445, 280, 910, BANK_TOP), (735, 318, 975, BANK_TOP)],
              "bank": [(445, 280, 910, LAKE_FAR), (735, 318, 980, LAKE_FAR, "grey")],
              "lake": [(503, LAKE_FAR, 899, LAKE_NEAR), (996, 532, 1114, LAKE_NEAR, "gold+"),
                       (1040, 560, 1258, LAKE_NEAR), (899, LAKE_FAR, 996, 532, "grey")],
              "drop": [(1525, 545, 1700, 690), (1220, 368, 1372, 512)]},
    "uncap": {"state": 2,
              "sky": [(465, 100, 1530, BANK_TOP)],
              "bank": [(405, 100, 1535, LAKE_FAR, "wood+"), (500, 100, 1413, LAKE_FAR),
                       (1388, 368, 1526, 420)],                       # the knife's handle
              "lake": [(405, LAKE_FAR, 500, LAKE_NEAR, "wood+"), (500, LAKE_FAR, 1413, LAKE_NEAR),
                       (1413, LAKE_FAR, 1530, LAKE_NEAR, "wood+")],
              "drop": [],
              "only": [(728, 650, 992, 688, "curtain")]},
    # done's stand is pour's stand: the same hand-cut boxes (WORK_RECTS["pour"]), the bucket
    # over the far bank by its own mint and outline; then the crown and the rays.
    "done": {"state": 1,
             "sky": [(790, 155, 1130, BANK_TOP)],
             "stand": True,
             "bank": [],
             "lake": [(1342, 552, 1424, LAKE_NEAR, "gold+"), (1150, 578, 1612, LAKE_NEAR)],
             "drop": [(130, 630, 520, 830)]},
}
CHECK_WORK_RECTS = {"smoke": [], "uncap": [], "done": []}
CURTAIN = {(238, 164, 38), (252, 204, 84), (255, 242, 190), (150, 72, 12)}
OLD_YELLOW = np.array([244, 184, 40])


def _test(c, kind):
    if kind.endswith("+"):
        sel = _test(c, kind[:-1])
        dark = np.all(c[..., :3].astype(int) <= 24, -1)
        return sel | (dark & dilate(sel, 2, 2))
    r, g, b = c[..., 0].astype(int), c[..., 1].astype(int), c[..., 2].astype(int)
    if kind == "wood":
        return (r > 180) & (g > 140) & (r - b > 60)
    if kind == "grey":
        return (np.abs(r - g) < 22) & (np.abs(g - b) < 26) & (r > 150)
    if kind == "gold":
        return (r > 140) & (g > 90) & (b < 140) & (r > b + 60)
    if kind == "curtain":
        out = np.zeros(c.shape[:2], bool)
        for col in CURTAIN:
            out |= (r == col[0]) & (g == col[1]) & (b == col[2])
        return out
    return np.ones(c.shape[:2], bool)


def plate_state(pa, ink):
    """Which lake state a capture shows: the state whose ramp (times the ink) covers most of its
    lake band."""
    band = pa[LAKE_FAR + 3:LAKE_NEAR - 3, :, :3].astype(int)
    best, best_n = 4, -1
    for s in range(5):
        cols = [np.round(_rgb("water_" + STATES[s] + k) * ink) for k in RAMP_STEPS]
        n = sum((np.abs(band - c).max(-1) <= 2).sum() for c in cols)
        if n > best_n:
            best, best_n = s, n
    return best


def pre_clean(pa):
    """Today's loose bees off a capture, wherever they are (sky, bank, lake, lawn, in front of the
    work): an 8-connected run of art cells in today's bee inks holding a cell of today's bee gold,
    no more than BEE_CELLS_MOST cells (the swarm on the hive is far bigger and stays: it is the
    step's work), with the pale wing cells over it, is refilled along each art row from the
    nearest cell outside it. Returns (cleaned capture, the bees' middles on the art grid)."""
    a = pa.copy()
    mid = G // 2
    cells = a[mid::G, mid::G, :3].astype(int)[:GRID_H, :GRID_W]
    inks = set(look.OLD_BEE) | OLD_BEE_INK
    beeish = np.zeros(cells.shape[:2], bool)
    gold = np.all(cells == OLD_YELLOW, -1)
    for c in inks:
        beeish |= np.all(cells == np.array(c), -1)
    beeish |= gold
    pale = (cells[..., 0] > 180) & (cells[..., 1] > 195) & (cells[..., 2] > 195)
    out_pts = []
    kill = np.zeros_like(beeish)
    for part in components(beeish):
        if len(part) > BEE_CELLS_MOST or not any(gold[y, x] for y, x in part):
            continue
        ys = [y for y, x in part]
        xs = [x for y, x in part]
        out_pts.append((int(round(sum(xs) / len(xs))), int(round(sum(ys) / len(ys)))))
        for y, x in part:
            kill[y, x] = True
        y0, y1 = max(0, min(ys) - 3), max(ys) + 1
        x0, x1 = max(0, min(xs) - 2), max(xs) + 3
        win = pale[y0:y1, x0:x1]
        if win.sum() <= 8:
            kill[y0:y1, x0:x1] |= win
        # and the dark bits of its wings and legs that the pale cells cut off from the body
        y2 = max(ys) + 2
        loose = beeish[y0:y2, x0:x1].copy()
        if loose.sum() <= len(part) + 12:
            kill[y0:y2, x0:x1] |= loose
    # today's flyers seen edge on are only their outline and their pale wings: small runs of the
    # outline ink alone in the sky, and of outline ink and white over the far bank (neither of
    # which the bank's own trees carry), go too
    outline = np.all(cells == np.array(look.OUT[:3]), -1)
    white = np.all(cells > 230, -1)
    sky_r, bank_r = BANK_TOP // G, LAKE_FAR // G
    for sel, r0, r1 in ((outline, 0, sky_r), (outline | white, sky_r, bank_r)):
        band = np.zeros_like(sel)
        band[r0:r1] = sel[r0:r1]
        for part in components(band):
            if len(part) <= 14 and any(outline[y, x] for y, x in part):
                for y, x in part:
                    kill[y, x] = True
    rows, cols = kill.shape
    for r in range(rows):
        if not kill[r].any():
            continue
        src = cells[r].copy()
        for c in np.nonzero(kill[r])[0]:
            for k in range(1, 40):
                hit = None
                for cc in (c - k, c + k):
                    if 0 <= cc < cols and not kill[r, cc] and not beeish[r, cc]:
                        hit = cc
                        break
                if hit is not None:
                    a[r * G:(r + 1) * G, c * G:(c + 1) * G, :3] = src[hit]
                    break
    return a, out_pts


BEE_CELLS_MOST = 60


def check_work(name):
    """(work RGBA image, bee points [(art x, art y)]) for one capture."""
    spec = CHECK[name]
    raw = np.array(look.plate(name))
    ink = fit_ink(raw)
    pa, bees = pre_clean(raw)
    m = np.zeros((H, W), bool)
    # the sky boxes are not lifted: the scene's sky IS this capture's own sky (its bees off), and
    # clean_sky keeps the boxes as they are, so the roof, the smoke and the bucket stand in it
    # the bank: what is not one of today's strip's own colours (times this capture's ink)
    strip_cols = np.unique(_bank_old[_bank_old[..., 3] > 0][:, :3], axis=0)
    strip_cols = np.unique(np.round(strip_cols * ink).astype(int), axis=0)
    band = pa[BANK_TOP:LAKE_FAR, :, :3].astype(int)
    key_band = (band[..., 0] << 16) | (band[..., 1] << 8) | band[..., 2]
    near = set()
    for c in strip_cols:
        for dr in (-1, 0, 1):
            for dg in (-1, 0, 1):
                for db in (-1, 0, 1):
                    near.add(((c[0] + dr) << 16) | ((c[1] + dg) << 8) | (c[2] + db))
    diff_bank = ~np.isin(key_band, np.array(sorted(near)))
    for box in spec["bank"]:
        x0, y0, x1, y1 = box[:4]
        y0, y1 = max(y0, BANK_TOP), min(y1, LAKE_FAR)
        if y0 < y1:
            d = diff_bank[y0 - BANK_TOP:y1 - BANK_TOP, x0:x1]
            if len(box) > 4:
                d = d & _test(pa[y0:y1, x0:x1, :3], box[4])
            m[y0:y1, x0:x1] |= d
    if spec.get("stand"):
        for x0, y0, x1, y1 in WORK_RECTS["pour"][:-1]:     # no lever: done's gate is shut
            m[max(y0, BANK_TOP):y1, x0:x1] = True
        x0, y0, x1, y1 = WORK_RECTS["pour"][0]
        y0 = BANK_TOP
        c = pa[y0:y1, x0:x1, :3].astype(int)
        mint = (c[..., 0] > 130) & (c[..., 1] > 180) & (c[..., 2] > 160)
        out_px = np.all(c <= 24, -1)
        m[y0:y1, x0:x1] = mint | out_px | _rod(c)
    # the lake: not one of the lake's own colours
    state = plate_state(pa, ink)
    water = [np.round(_rgb("water_" + STATES[state] + k) * ink) for k in RAMP_STEPS]
    water += [np.round(_rgb(f) * ink) for f in ("foam", "foam_dirty")]
    for box in spec["lake"]:
        x0, y0, x1, y1 = box[:4]
        c = pa[y0:y1, x0:x1, :3].astype(int)
        not_water = np.ones(c.shape[:2], bool)
        for wc in water:
            not_water &= np.abs(c - wc).max(-1) > 3
        if len(box) > 4:
            not_water &= _test(c, box[4])
        m[y0:y1, x0:x1] |= not_water
    # below the lake: against the lawn
    lawn = render_lawn(ink)
    m[LAKE_NEAR:] |= np.abs(pa[LAKE_NEAR:, :, :3].astype(int) - lawn.astype(int)).max(-1) > 4
    for x0, y0, x1, y1 in spec["drop"]:
        m[y0:y1, x0:x1] = False
    for x0, y0, x1, y1, kind in spec.get("only", []):
        m[y0:y1, x0:x1] &= _test(pa[y0:y1, x0:x1, :3], kind)
    work = np.zeros_like(pa)
    work[m] = pa[m]
    work[m, 3] = 255
    return Image.fromarray(work), bees, state, pa


def check_scene(name, opt=None, veil=SCENE_VEIL):
    """One step's capture with the view redrawn and opt's bed. Returns (picture, how many work
    pixels stand in front of the bed's own pixels)."""
    opt = opt or RECOMMEND
    title, bed, plan, _ = OPTIONS[opt]
    work, bee_pts, state, cleaned = check_work(name)
    pa = np.array(look.plate(name))
    ink = fit_ink(pa)
    plate = Image.fromarray(cleaned)
    sky = clean_sky(plate.copy(), name)
    sa = np.array(sky)
    keep = UI_KEEP + [r for r in CHECK[name]["sky"]]
    scrub(sa, SCRUB.get(name, []), keep)
    scrub_birds(sa, name)
    bank_sky = sa.copy()
    if name == "smoke":
        bank_sky = sky_behind_trees(bank_sky, [(1220, BANK_TOP, 1372, LAKE_FAR)])
    view = sa.copy()
    bank, trees = render_bank(pa, ink, bank_sky)
    view[BANK_TOP:LAKE_FAR, :, :3] = bank
    view[LAKE_FAR:LAKE_NEAR, :, :3] = render_lake(CHECK[name]["state"], ink,
                                                  streak_share=0.7 * (1.0 - 0.5 * (veil > 0)))
    view[LAKE_NEAR:, :, :3] = render_lawn(ink)
    view[..., 3] = 255
    if veil > 0:
        apply_veil(view, veil, trees)
    spots, sil, layer = lay_bed(view, bed())
    img = Image.fromarray(view)
    used = []
    rng = random.Random(90)
    wa = np.array(work)[..., 3] > 0
    blocked = np.zeros((GRID_H, GRID_W), bool)
    for dy in range(G):
        for dx in range(G):
            blocked |= wa[dy::G, dx::G][:GRID_H, :GRID_W]
    for x0, y0, x1, y1 in CHECK[name]["sky"]:
        blocked[y0 // G:y1 // G + 1, x0 // G:x1 // G + 1] = True
    flyers_at(img, bee_pts, used, rng, blocked)
    for k, part in enumerate(_halves(spots)):
        bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
    img.alpha_composite(work)
    bed_px = np.repeat(np.repeat(np.array(layer)[:GRID_H, :GRID_W, 3] > 0, G, 0), G, 1)
    return img, int((bed_px & wa).sum()), len(bee_pts)


# =============================================================================================
# The sheet
# =============================================================================================
def half(im):
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)


MARGIN = 30


def ticked(scene, boxes):
    """The real-scale scene, untouched, in a dark margin that carries the zoom marks: for each
    numbered box a pink bar along the top and bottom margins over its columns and along the left
    and right margins beside its rows, with its number. Nothing is drawn on the art itself."""
    out = Image.new("RGBA", (scene.width + 2 * MARGIN, scene.height + 2 * MARGIN), look.PANEL_BG)
    out.alpha_composite(scene, (MARGIN, MARGIN))
    d = ImageDraw.Draw(out)
    f = look.font(16, "bold")
    for k, (x0, y0, x1, y1) in enumerate(boxes):
        lane = 4 + (k % 3) * 8
        n = str(k + 1)
        d.rectangle([MARGIN + x0, lane, MARGIN + x1, lane + 4], fill=look.MARK)
        d.rectangle([MARGIN + x0, out.height - lane - 5, MARGIN + x1, out.height - lane - 1],
                    fill=look.MARK)
        d.rectangle([lane, MARGIN + y0, lane + 4, MARGIN + y1], fill=look.MARK)
        d.rectangle([out.width - lane - 5, MARGIN + y0, out.width - lane - 1, MARGIN + y1],
                    fill=look.MARK)
        d.text((MARGIN + x0 + 4, lane - 4 if lane > 6 else lane + 4), n, font=f, fill=look.INK)
    return out


# Zoom crops, window px (x0, y0, x1, y1): per option, on the catch (c) or pour (p) scene.
ZOOMS = {
    "A": [("c", (0, 930, 330, 1080), 4, "the hedge's left end and its bees (catch)"),
          ("p", (1500, 930, 1920, 1080), 3, "the hedge under the jar shelf's end (pour)"),
          ("c", (1240, 940, 1920, 1080), 2, "the hedge's right end (catch)")],
    "B": [("c", (0, 860, 330, 1080), 4, "the left border, tallest at the edge (catch)"),
          ("p", (1590, 870, 1920, 1080), 4, "the right border by the jar shelf (pour)"),
          ("c", (330, 300, 870, 620), 2, "the far bank, dead trees painted out, under the 0.6 veil")],
    "C": [("c", (0, 820, 400, 1080), 3, "the left corner's posies, middle and near (catch)"),
          ("p", (1680, 820, 1920, 1080), 3, "the right corner's posies (pour)"),
          ("c", (420, 990, 700, 1080), 3, "the big heads along the foot, beside the card")],
}


def option_body(opt, scenes):
    c, p = scenes
    zc = [b for w, b, s, l in ZOOMS[opt] if w == "c"]
    zp = [b for w, b, s, l in ZOOMS[opt] if w == "p"]
    zooms = []
    nc = np_ = 0
    for which, box, s, label in ZOOMS[opt]:
        src = c if which == "c" else p
        if which == "c":
            nc += 1
            tag = "catch %d" % nc
        else:
            np_ += 1
            tag = "pour %d" % np_
        zooms.append(panel(look.crop_zoom(src, box, s), "%s, %dx: %s" % (tag, s, label)))
    real = stack([panel(ticked(c, zc), "real scale, untouched: the CATCH step (3 px an art px), "
                                        "the lake dirty as captured, veil 0.6; the pink bars in "
                                        "the margin mark the zooms"),
                  panel(ticked(p, zp), "real scale, untouched: the POUR step, the lake later in "
                                        "the run (hazy), veil 0.6")],
                 "h", 18)
    return stack([real, flow(zooms, real.width, 18)], "v", 18)


def today_body():
    c, p = look.plate("catch"), look.plate("pour")
    return stack([panel(half(c), "today, half size: catch (rubbish, piers, a ferry, the dog, "
                                 "brown-gold bees)"),
                  panel(half(p), "today, half size: pour (rubbish, piers, the dog crossing "
                                 "the front)")], "h", 18)


VEIL_CROP = (0, 300, 1280, 1080)


def veil_body():
    """One bed (the recommended) on the catch scene, the dirty case, at veil 0, 0.6 and 1.0,
    side by side at real scale, plus a 2x crop of the same far bank and lake from each."""
    scenes = [compose(RECOMMEND, "catch", veil=v) for v in VEILS]
    big = [panel(s.crop(VEIL_CROP), "veil %.1f, real scale (window x 0-1280, y 300-1080)" % v)
           for s, v in zip(scenes, VEILS)]
    small = [panel(look.crop_zoom(s, (300, 340, 860, 600), 2),
                   "veil %.1f, 2x: the far bank and lake" % v) for s, v in zip(scenes, VEILS)]
    return stack([stack(big, "h", 18), stack(small, "h", 18)], "v", 18), scenes


def _padded(im):
    out = Image.new("RGBA", (im.width + 2, im.height + 2), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 1))
    return out


LAWN_SWATCH = (52, 70, 30, 255)


def pieces_body():
    """The pieces the beds are made of, by depth, at the room's grain, on the room's lawn."""
    rows = []
    for title, pools in (("back rows (small)", SMALL), ("middle (tulips)", MID),
                         ("front rows (big heads)", BIG)):
        names = []
        for fam in FAMILIES:
            for n in pools[fam]:
                if n not in names:
                    names.append(n)
        rows.append(names)
    rows.append([CLUMP[f] for f in ("white", "pink", "blue", "yellow")] + GREEN_BODY)
    strips = []
    for names in rows:
        ims = [_padded(flora(n)) for n in names]
        strips.append(stack(ims, "h", 4, align="start"))
    sample = bed_layer([("pk_bed_7", 20, 30), ("pk_flower_1", 8, 36), ("pk_flower_4", 16, 37),
                        ("pk_flower_0", 26, 36), ("pk_flower_13", 34, 33), ("pk_flower_14", 30, 26),
                        ("pk_flower_6", 34, 38)])[0].crop((0, 0, 48, 42))
    strips.append(stack([sample, look.bee(BEE, 1, pose="hover"), look.bee(BEE, 0, pose="rest"),
                         look.bee(BEE, 4, pose="fly")], "h", 6))
    strip = stack(strips, "v", 4)
    bg = Image.new("RGBA", (strip.width + 8, strip.height + 8), LAWN_SWATCH)
    bg.alpha_composite(strip, (4, 4))
    return panel(zoom(bg, G), "the pieces (assets/flora.png, real art) by depth: back rows "
                              "(3x5 heads, clovers), middle (5x7 tulips), front rows (7x8 discs "
                              "and 6x6 crosses), then the clumps and the green body; last, a "
                              "little bed on its leaf body ringed once, and look's bee (hover, "
                              "rest, fly with the wings back); 3x: the room's grain")


def main():
    os.makedirs(SCRATCH, exist_ok=True)
    blocks = [look.option_block("TODAY", "FOR COMPARISON",
                                "The room borrows the wash room's view: the dirty lake band with "
                                "rubbish, the piers, a ferry and the dog; nothing in it says bees.",
                                today_body())]
    for opt in ("A", "B", "C"):
        c, p = compose(opt, "catch"), compose(opt, "pour")
        c.convert("RGB").save(os.path.join(SCRATCH, f"{opt}_catch.png"))
        p.convert("RGB").save(os.path.join(SCRATCH, f"{opt}_pour.png"))
        name, _, _, cap = OPTIONS[opt]
        blocks.append(look.option_block(opt, name, cap + " Shown under veil 0.6 like the others "
                                        "(the veil is a separate choice: the VEIL row).",
                                        option_body(opt, (c, p)),
                                        recommended=(opt == RECOMMEND)))
    vb, vscenes = veil_body()
    for v, s in zip(VEILS, vscenes):
        s.convert("RGB").save(os.path.join(SCRATCH, "veil_%.1f.png" % v))
    blocks.append(look.option_block("VEIL", "A SEPARATE CHOICE: NONE / 0.6 / 1.0",
                                    f"{RECOMMEND}'s bed on the catch step, the dirtiest lake, "
                                    "under no veil, the light veil and the full veil. The veil "
                                    "takes the far bank and the lake towards the sky's own low "
                                    "step in three hard bands (far most) and halves the streaks; "
                                    "pick it apart from the bed. Recommended: 0.6 (the dirty "
                                    "lake still reads as the player's lake, the bank goes back).",
                                    vb))
    checks = []
    for n in ("smoke", "uncap", "done"):
        pic, hidden, nb = check_scene(n)
        pic.convert("RGB").save(os.path.join(SCRATCH, f"check_{n}.png"))
        checks.append(panel(half(pic), f"{n}, half size: the view redrawn, {RECOMMEND}'s bed, "
                                        f"veil 0.6, the step's work on top ({hidden} screen px of "
                                        f"bed behind it; {nb} of today's bees as look's bee)"))
        print(n, "bed px behind the work:", hidden, "bees:", nb)
    blocks.append(look.option_block("CHECK", "ONE LAYOUT FOR EVERY STEP",
                                    f"The smoke, uncap and done steps drawn the way the A/B/C "
                                    "scenes are: no rubbish, ferries, dogs or pigeons, the mock's "
                                    f"far bank, veil 0.6, {RECOMMEND}'s bed, and only the step's "
                                    "own work lifted back off its capture. The hive, the smoker, "
                                    "the rest, the jars and the shelf stand clear of the bed; "
                                    "only today's uncap bucket (oversized and cut off at the "
                                    "window's foot, the uncap sheet's to replace) covers the "
                                    "right border's heads. The work itself (today's swarm on "
                                    "the hive, the mint buckets) is shown as captured: it is the "
                                    "step sheets' to redraw. Queen and settled show the open "
                                    "hive over the whole window, so no backdrop shows there.",
                                    stack([flow(checks, 3880, 18), pieces_body()], "v", 18)))
    look.sheet("THE HIVE ROOM'S BACKDROP: A BED OF FLOWERS", blocks, OUT_PATH,
               subtitle="Richard's brief (2026-10-16): the island's view of the lake with no "
                        "rubbish, no ferries and no dogs, and a bed of the island's flowers along "
                        "the foreground lawn with bees working it. Each option is drawn on the "
                        "real catch and pour captures at the room's grain (3 screen px an art "
                        "px); the view is redrawn from WashBackdrop's own strips and lake ramps, "
                        "the step's work lifted back on, and every bee (the step's and the bed's) "
                        "is look's bee A. The bed and the veil are two separate choices.",
               notes="Script: tools/hive_look/backdrop_mockup.py (module tools/hive_look/look.py). "
                     "The bed is real flora.png pieces at the room's grain, graded by depth "
                     "(small heads behind, big heads at the window's foot), set on a two-step "
                     "leaf body (grass_dark and grass_dark towards the outline ink) that fills "
                     "the gaps between heads, the whole mass ringed ONCE in the game's outline "
                     "(24,18,17), open at the foot, a contact shade one art row down and right "
                     "(the room's sun is top left), drawn over the backdrop's darken like its "
                     "birds and dogs. The far bank's dead trees and rust trunk band are painted "
                     "out of today's strip for the mock; for the build, rebuild "
                     "assets/wash_bank.png off today's round-tree mix. The hive room's backdrop "
                     "carries no pigeons in any step. The mint bucket, the box, the jars and "
                     "how many bees the catch sky keeps are other sheets' calls and are shown as "
                     "they are today.")


if __name__ == "__main__":
    main()

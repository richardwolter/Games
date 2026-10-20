#!/usr/bin/env python
"""The pour sheet (2026-10-16, the hive overhaul): the bottling stand, the jars and the payoff.

OFFLINE MOCKUP ONLY. Writes tools/hive_look/last_pour.png.

Today (tools/last_hive_room_pour.png, _done.png): the uncap step's mint tub on a spindly
two-legged table, a plank shelf floating in the grass, a big dog crossing the front, and the
harvest's crown hanging in mid-air over the jars with gold rays.

Three options, A / B / C, each the uncap sheet's bucket of the same letter carried to the
bottling stand (uncap_mockup's pail / oak_bucket / crock, the same pixels, its outside honey
run wiped), each shown on the real plate at real scale in two states: the pour mid-fill
(first jar on the bench, the second filling under the gate, the third waiting), and the done
state (three jars on the bench, the payoff landed on them). A third, "start" state (lever
shut, the uncap's level) is rendered for the lever's hold cue and the bucket's level ladder.

    A  OAK TABLE + STUMP BENCH, CROWN STAMP   the hut's oak, a pegged table and a plank on two
                                              log rounds; done, a foil crown on a dark amber
                                              band on every label
    B  HIVE STACK + FENCE SHELF, ROSETTE      the stand is a hive: a coral cover over two
                                              sky-blue supers (hand-holds, the shutters' heart),
                                              the jars on its landing board; the bench a blue
                                              plank on brackets on two fence stakes; done, a
                                              prize rosette with the crown on its boss
    C  CRATES, CROWNED LID                    weathered crates, the jars inside the one on its
                                              side; done, the crown comes down on the middle
                                              jar's lid and stays there

The done payoff in all three is the room's shared payoff (HiveStep.payoff: rays fanning up out
of the thing finished, stars twinkling in turn, the crown with a halo) grounded on the jars:
short stepped gold rays from behind the bench, each jar in a two-step gold halo with a checker
fringe, stars rolled per option and timed in turn (a four-frame strip on the sheet), and the
crown on the jars (A stamp, B rosette boss, C lid crown) in place of the crown in the air.

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/pour_mockup.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
import pour_art as pa  # noqa: E402
import pour_backdrop  # noqa: E402
from look import ROOM_GRAIN as G, panel, stack, flow  # noqa: E402

OUT_PATH = os.path.join(look.HERE, "last_pour.png")
SCRATCH = os.path.join(look.HERE, "scratch_pour")
RECOMMEND = "A"
BEE = "A"
W, H = look.ROOM_GRID

# =============================================================================================
# The layout, art px on the room grid (640 x 360). Measured off the plate: the far waterline at
# row 163, the near waterline (the sand's top) at 198, the lawn from 235, the hint card's top
# at 315, the steps bar over rows 0..40. Every stand's top surface (its front row) is row 219,
# so the board lies on the sand, 8+ rows clear of the waterline seam, and the gate and lever
# hang on plain sand. Empty jar left, filling middle, finished right.
# =============================================================================================
STAND_X, STAND_W = 202, 100
TOP_FACE = 219                # every stand's top surface front row (the bucket's foot row)
STAND_TOP = {"A": TOP_FACE - 7, "B": TOP_FACE - 2, "C": TOP_FACE - 5}
CRATE_UPPER = 21              # C's upper crate's height
SHELF = 282                   # the low shelf / landing board: its top face rows SHELF-2 .. +2
STAND_FEET = 296
BUCKET_SHIFT = -6             # the bucket sits a little left of the stand's middle
WAIT_GAP = 34                 # the waiting jar's middle, left of the filling one
BENCH_X, BENCH_W = 326, 116
BENCH_TOP = 262
BENCH_FEET = 294
SLOTS = (20, 58, 96)          # the jars' middles along the bench
LEVEL_UNCAP = 0.55            # the uncap sheet's level, carried over (the start)
LEVEL_MID = 0.3               # after a jar and a half
LEVEL_DONE = 0.0
FILL_MID = 0.52               # the jar under the gate, part way to the line
OPEN = 0.82                   # the lever's swing while pouring

# The sun's cast shadow on the lawn: the room's sun is top left, so a thing `h` art px tall
# throws its top SUN_DX * h right and SUN_DY * h down the screen (towards the eye) from its
# foot. One step darker than the lawn: mixed SHADE_T towards the outline ink, a one-art-px
# checker fringe at half of that. The same recipe the uncap sheet should use for its bucket.
SUN_DX, SUN_DY = 0.15, 0.11
SHADE_T = 0.5

CAPTIONS = {
    "A": "Galvanised pail on a pegged oak table, jars to a plank on two log rounds; done, every "
         "label turns dark amber with a foil crown stamped on it, the jars glow in a gold halo "
         "and short rays fan up behind the bench.",
    "B": "Oak honey bucket on a stand built as a hive (coral cover, two sky-blue supers, the "
         "jars on its landing board), the jars to a blue plank on a stake fence; done, a coral "
         "prize rosette with the crown struck on its boss on the middle jar.",
    "C": "Honey crock on a crate laid on its side, jars to an upturned crate; done, the crown "
         "comes down on the middle jar's lid and stays there.",
}

DETAILS = {
    "A": "The hut's oak: a thick two-board top, an apron with corner brackets, square legs pegged "
         "at the joints, a low shelf for the jars between the front legs. The pail's brass honey "
         "gate with a brass lever and a fat oak grip. Done, the payoff is on the thing it "
         "rewards: a light gold foil crown, ringed so it reads at 1x, on a dark amber band on "
         "all three labels. Matches the uncap sheet's pick and the island's carpentry.",
    "B": "Of a piece with the island hive: the same sky blue and coral, chipped to the pine at "
         "the corners and on the cover, hand-holds routed in both supers, the heart cut into "
         "the upper one, the bottom board's entrance slot with a bee walking in. Jars stand on "
         "the landing board as on a hive's. Its own silhouette: a solid box stack, no legs to "
         "speak of. The bench is a fence: two pointed stakes, a rail behind, a plank on "
         "brackets.",
    "C": "Weathered grey boards, nail heads, a hand hole; the jars stand inside the crate's dark "
         "mouth, so the honey stream glows against it. The crock's oak spigot with an oak lever "
         "and a cream grip. The bench crate's top has a lit front board, straw clumps poke out "
         "of its gaps. The strongest read of the stream; the greys sit furthest from the "
         "island's carpentry.",
}

OPTION_NAMES = {"A": "OAK TABLE, STUMP BENCH, CROWN STAMP",
                "B": "HIVE STACK, FENCE SHELF, ROSETTE",
                "C": "CRATES, CROWNED LID"}


# =============================================================================================
# The backdrop: today's room with nothing of today's step on it, the UI put back, and the
# backdrop sheet's flower bed in the two bottom corners with its bees.
# =============================================================================================
_bg_cache = {}
BACKDROP_NOTE = []
# The plates' interface, pasted back over everything (screen px, measured tight on the frames).
UI = {"pour": [(818, 2, 1102, 118), (1824, 16, 1898, 68), (570, 951, 1351, 1042)],
      "done": [(818, 2, 1102, 118), (1824, 16, 1898, 68), (576, 951, 1347, 1042)]}


def backdrop():
    """The room behind the pour (full resolution RGBA). The sky is today's with its mint
    bucket, bees and pigeons taken off (pour_backdrop.clean). Below the sky it is the backdrop
    sheet's recommended look, borrowed from backdrop_mockup when that script is there: the far
    bank re-laid from its strip, the lake redrawn in its state with nothing on it, the lawn
    redrawn, its veil, its flower bed and the bees at it. Without it, today's view retouched
    (rubbish, ferry and dog off)."""
    if "view" in _bg_cache:
        return _bg_cache["view"].copy()
    raw_path = os.path.join(SCRATCH, "clean_full_raw.png")
    if os.path.exists(raw_path):
        raw = Image.open(raw_path).convert("RGBA")
    else:
        raw = pour_backdrop.clean("pour")
        os.makedirs(SCRATCH, exist_ok=True)
        raw.save(raw_path)
    try:
        import backdrop_mockup as bm
        opt = bm.RECOMMEND
        _title, bed, plan, _cap = bm.OPTIONS[opt]
        veil = bm.SCENE_VEIL
        plate = np.array(look.plate("pour"))
        ink = bm.fit_ink(plate)
        view = np.array(raw)
        bank, trees = bm.render_bank(plate, ink, view.copy())
        view[bm.BANK_TOP:bm.LAKE_FAR, :, :3] = bank
        view[bm.LAKE_FAR:bm.LAKE_NEAR, :, :3] = bm.render_lake(
            bm.STATES_SHOWN.get("pour", 1), ink, streak_share=0.7 * (1.0 - 0.5 * (veil > 0)))
        view[bm.LAKE_NEAR:, :, :3] = bm.render_lawn(ink)
        view[..., 3] = 255
        if veil > 0:
            bm.apply_veil(view, veil, trees)
        spots, sil, _layer = bm.lay_bed(view, bed())
        img = Image.fromarray(view)
        used = []
        for k, part in enumerate(bm._halves(spots)):
            bm.bees_at_bed(img, part, plan, sil, used, seed=5 + 4 * k)
        BACKDROP_NOTE[:] = ["the backdrop sheet's %s (%s, veil %.1f, lake %s)" % (
            opt, _title.lower(), veil, bm.STATES[bm.STATES_SHOWN.get("pour", 1)])]
    except Exception as e:                     # the backdrop sheet is its own work: carry on
        print("backdrop sheet not borrowed:", repr(e))
        BACKDROP_NOTE[:] = ["today's view retouched (the backdrop sheet was not there to borrow)"]
        img = raw
    _bg_cache["view"] = img
    return img.copy()


BAR = (818, 2, 1102, 118)     # the steps bar, screen px


def _done_bar():
    """The steps bar for the done state without today's payoff stars on it (the payoff is on
    the jars now). Built from the two captures: the pour bar everywhere (no stars), its OPEN pip
    moved 126 px onto FILL (a done pip is an OPEN pip), the cream FILL label from the done bar,
    and round the big current pip the done bar's own wood, any star pixel there swapped for the
    nearest wood to its left (only colours the pour bar's own wood and line use survive)."""
    if "bar" in _bg_cache:
        return _bg_cache["bar"]
    a = np.array(look.plate("pour").crop(BAR).convert("RGB")).astype(int)
    b = np.array(look.plate("done").crop(BAR).convert("RGB")).astype(int)
    out = b.copy()
    h, w = a.shape[:2]
    shift, tight, big, label = 126, (181, 16, 232, 66), (170, 8, 240, 72), (172, 72, 238, 96)

    def inb(x, y, bx):
        return bx[0] <= x < bx[2] and bx[1] <= y < bx[3]

    ok = {tuple(a[y, x]) for y in range(h) for x in range(w) if 106 <= x < 170 or x >= 240}
    diff = np.abs(a - b).sum(2) > 0
    for y in range(h):
        for x in range(w):
            if inb(x, y, label):
                continue
            if inb(x, y, tight):
                out[y, x] = a[y, x - shift]
            elif not diff[y, x]:
                continue
            elif not inb(x, y, big):
                out[y, x] = a[y, x]
            elif tuple(b[y, x]) not in ok:
                k = x - 1
                while k > 0 and tuple(out[y, k]) not in ok:
                    k -= 1
                out[y, x] = out[y, k]
    _bg_cache["bar"] = Image.fromarray(out.astype("uint8")).convert("RGBA")
    return _bg_cache["bar"]


def with_ui(pic, step):
    src = look.plate(step)
    for box in UI[step]:
        pic.paste(src.crop(box), box[:2])
    if step == "done":
        pic.paste(_done_bar(), BAR[:2])
    return pic


def pour_bar(pic):
    """The steps bar while pouring: OPEN done (a filled pip), FILL the step in progress, drawn
    as the current pip: its fill taken out to the bar's dark grain, a gold ring left inside its
    outline (the game's own two colours). Both pips filled only once done."""
    x0, y0 = BAR[:2]
    box = (170, 8, 240, 72)
    fills = {(252, 204, 84), (255, 242, 190), (255, 204, 77)}
    arr = np.array(pic)
    sub = arr[y0 + box[1]:y0 + box[3], x0 + box[0]:x0 + box[2]]
    rgb = sub[..., :3].astype(int)
    is_out = (np.abs(rgb - np.array([24, 18, 17])).sum(2) < 6)
    is_fill = np.zeros(is_out.shape, bool)
    for f in fills:
        is_fill |= (np.abs(rgb - np.array(f)).sum(2) < 4)
    near = np.zeros(is_out.shape, bool)
    h, w = is_out.shape
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            if dx * dx + dy * dy > 40:
                continue
            ys = slice(max(0, dy), h + min(0, dy))
            yd = slice(max(0, -dy), h + min(0, -dy))
            xs = slice(max(0, dx), w + min(0, dx))
            xd = slice(max(0, -dx), w + min(0, -dx))
            near[yd, xd] |= is_out[ys, xs]
    sub[is_fill & near, :3] = (255, 204, 77)
    sub[is_fill & ~near, :3] = (140, 84, 64)
    return Image.fromarray(arr)


def with_ui(pic, step):
    src = look.plate("done" if step == "done" else "pour")
    for box in UI["done" if step == "done" else "pour"]:
        pic.paste(src.crop(box), box[:2])
    if step == "done":
        pic.paste(_done_bar(), BAR[:2])
    else:
        pic = pour_bar(pic)
    return pic


# =============================================================================================
# Shadows and the payoff's glow, by art cells on the full-resolution plate
# =============================================================================================
def _rect(x0, x1, y0, y1):
    return {(x, y) for x in range(int(x0), int(x1) + 1) for y in range(int(y0), int(y1) + 1)}


def _thrown(x0, x1, y0, y1, h, sweep):
    """The cells of a footprint (x0..x1, y0..y1) thrown by the sun from a height h: swept from
    the foot to the top (a solid thing), or only the top's (a board up on legs)."""
    dx, dy = SUN_DX * h, SUN_DY * h
    n = max(1, int(math.ceil(max(dx, dy))))
    cells = set()
    for k in (range(n + 1) if sweep else (n,)):
        t = k / float(n)
        cells |= _rect(x0 + round(t * dx), x1 + round(t * dx), y0 + round(t * dy), y1 + round(t * dy))
    return cells


def _fringe(core):
    out = set()
    for (x, y) in core:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in core and (nx + ny) % 2 == 0:
                out.add((nx, ny))
    return out


def shadow_cells(option, st, bc):
    """The cast shadows of the stand and the bench on the lawn."""
    f = STAND_FEET
    top = STAND_TOP[option]
    core = set()
    if option == "A":
        h = f - top
        core |= _thrown(STAND_X, STAND_X + STAND_W - 1, f - 7, f, h, False)      # the top
        drift = int((f - top) / 17.0)
        for lx in (STAND_X + 3 - drift, STAND_X + STAND_W - 10 + drift):            # front legs
            core |= _thrown(lx, lx + 6, f - 1, f, h, True)
        for lx in (STAND_X + 13, STAND_X + STAND_W - 20):                          # back legs
            core |= _thrown(lx, lx + 4, f - 7, f - 6, h, True)
        core |= _thrown(STAND_X + 2, STAND_X + STAND_W - 3, f - 7, f, f - SHELF, False)
    else:
        pad = 4 if option == "B" else 0
        core |= _thrown(STAND_X - pad, STAND_X + STAND_W - 1 + pad, f - 8, f, f - top, True)
    g = BENCH_FEET
    if option == "A":
        for cx in (BENCH_X + 22, BENCH_X + BENCH_W - 22):
            core |= _thrown(cx - 13, cx + 13, g - 3, g, g - BENCH_TOP, True)
        core |= _thrown(BENCH_X, BENCH_X + BENCH_W - 1, g - 5, g, g - BENCH_TOP, False)
    elif option == "B":
        for (x0, x1, stop) in bc["posts"]:
            core |= _thrown(x0, x1 - 1, g - 2, g, g - stop, True)
        core |= _thrown(BENCH_X, BENCH_X + BENCH_W - 1, g - 5, g, g - BENCH_TOP, False)
    else:
        core |= _thrown(BENCH_X, BENCH_X + BENCH_W - 1, g - 5, g, g - BENCH_TOP, True)
    return core, _fringe(core)


def tint_cells(arr, cells_t, ink):
    """Mix every 3 x 3 screen block of each art cell `t` of the way towards `ink` (a fixed mix
    of two swatches per band, so the glow is stepped, never a gradient)."""
    inkv = np.array(ink[:3], float)
    for (x, y), t in cells_t.items():
        y0, x0 = y * G, x * G
        if y0 < 0 or x0 < 0 or y0 + G > arr.shape[0] or x0 + G > arr.shape[1]:
            continue
        blk = arr[y0:y0 + G, x0:x0 + G, :3].astype(float)
        arr[y0:y0 + G, x0:x0 + G, :3] = np.round(blk + (inkv - blk) * t).astype(np.uint8)


RAY_BANDS = (0.58, 0.36, 0.18)          # the rays' three stepped strengths, inner to outer


def ray_cells(option, cx, cy):
    """Short stepped gold rays fanning up out of the bench from behind the jars (the shared
    payoff's rays, grounded): nine wedges rolled per option, each of whole cells in three
    strengths by distance."""
    rnd = random.Random({"A": 3, "B": 7, "C": 11}[option])
    rays = []
    for i in range(9):
        th = -72 + i * 18 + rnd.uniform(-4, 4)
        rays.append((math.radians(th), rnd.uniform(46, 60) if i % 2 == 0 else rnd.uniform(32, 42)))
    out = {}
    for y in range(int(cy - 64), int(cy + 6)):
        for x in range(int(cx - 64), int(cx + 65)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r < 6 or dy > 2:
                continue
            ang = math.atan2(dx, -dy)
            for th, long in rays:
                if r > long:
                    continue
                if abs(ang - th) * r > 1.2 + r * 0.055:
                    continue
                t = RAY_BANDS[0] if r < long * 0.45 else RAY_BANDS[1] if r < long * 0.78 else RAY_BANDS[2]
                out[(x, y)] = max(out.get((x, y), 0), t)
    return out


def halo_cells(mask):
    """A stepped gold halo two art px round the jars (each already wears the finds' one-px
    rim), then a one-px checker fringe: strength by ring."""
    ys, xs = np.nonzero(mask)
    have = set(zip(xs.tolist(), ys.tolist()))
    out = {}
    ring = have
    for step, t in enumerate((0.45, 0.25, 0.14)):
        nxt = set()
        for (x, y) in ring:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    c = (x + dx, y + dy)
                    if c not in have and c not in out:
                        nxt.add(c)
        for c in nxt:
            if step < 2 or (c[0] + c[1]) % 2 == 0:
                out[c] = t
        have |= nxt
        ring = nxt
    return out


def payoff_stars(option, frame):
    """The finds' stars round the finished jars, rolled per option, each on its own beat: a star
    goes big, small, a pale dot, out, and round again, so they twinkle in turn."""
    rnd = random.Random({"A": 21, "B": 34, "C": 55}[option])
    spots = []
    tries = 0
    while len(spots) < 8 and tries < 400:
        tries += 1
        x = rnd.randint(BENCH_X - 6, BENCH_X + BENCH_W + 6)
        y = rnd.randint(BENCH_TOP - 66, BENCH_TOP - 4)
        on_jar = any(abs(x - (BENCH_X + s)) < 12 and y > BENCH_TOP - 46 for s in SLOTS)
        if on_jar and rnd.random() < 0.75:
            continue
        if all(abs(x - a) + abs(y - b) > 16 for a, b, _ in spots):
            spots.append((x, y, len(spots) % 4))
    out = []
    for (x, y, ph) in spots:
        state = (frame + ph) % 4
        if state < 3:
            out.append((x, y, state))
    return out


def star_sprite(state):
    if state == 0:
        return pa.star(True)
    if state == 1:
        return pa.star(False)
    return look.grid(["p"], {"p": pa.GOLD[5]})


# =============================================================================================
# One state of one option on the plate
# =============================================================================================
def _place_jar(lay, im, cx, feet):
    """A ringed jar (26 x 42) with its middle on column cx and its feet on row `feet`."""
    lay.alpha_composite(im, (cx - pa.JAR_FEET[0], feet - pa.JAR_FEET[1]))


def _shade_box(lay, x0, x1, y0, y1, t=0.32):
    """A cast shadow on a sprite already in the layer (a jar's on the shelf, the bucket's on the
    stand's top): opaque pixels in the box mixed towards the outline."""
    px = lay.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < lay.width and 0 <= y < lay.height and px[x, y][3] and px[x, y][:3] != pa.OUT[:3]:
                px[x, y] = look.mix(px[x, y], pa.OUT, t)[:3] + (255,)


_render_cache = {}


def render(option, step, frame=0):
    """The option drawn on the cleaned plate in `step`: 'start' (lever shut with its hold cue,
    the uncap's level, the jars empty), 'pour' (mid-fill) or 'done'. Returns (picture, boxes
    for the zooms in plate px, extra marks)."""
    key = (option, step, frame)
    if key in _render_cache:
        return _render_cache[key]
    lay = Image.new("RGBA", (W, H + 20), (0, 0, 0, 0))
    jars_lay = Image.new("RGBA", (W, H + 20), (0, 0, 0, 0))
    done, start = step == "done", step == "start"
    # --- the stand -------------------------------------------------------------------------
    top = STAND_TOP[option]
    if option == "A":
        st = pa.table_stand(lay, STAND_X, STAND_W, top, STAND_FEET, SHELF, kind="oak")
    elif option == "B":
        st = pa.hive_stand(lay, STAND_X, STAND_W, top, STAND_FEET, SHELF)
    else:
        st = pa.crate_stand(lay, STAND_X, STAND_W, top, STAND_FEET, SHELF, upper=CRATE_UPPER)
    top_face = st["top_face"]
    assert top_face == TOP_FACE, (option, top_face)
    jar_feet = st["shelf"] - 1
    # --- the bucket on it, its honey, its near wall ------------------------------------------
    b = pa.bucket(option)
    mid = STAND_X + STAND_W // 2 + BUCKET_SHIFT
    bx = int(round(mid - b["mouth"][0]))
    by = int(round(top_face - b["foot"][1]))
    if b["bail"] is not None:
        lay.alpha_composite(b["bail"], (bx - 1, by - 1))
    lay.alpha_composite(b["body"], (bx, by))
    hl = pa.Spr(W, H + 20)
    mouth = (b["mouth"][0] + bx, b["mouth"][1] + by)
    level = LEVEL_DONE if done else LEVEL_UNCAP if start else LEVEL_MID
    pa.bucket_honey(hl, mouth, b["inner"], level, b["taper"], was=LEVEL_UNCAP)
    lay.alpha_composite(hl.im)
    lay.alpha_composite(b["front"], (bx, by))
    foot_half = b["foot_half"][0]
    # the bucket's shadow on the stand's top, down and to the right
    _shade_box(lay, int(mid + foot_half + 1), int(mid + foot_half + 9), top_face - 2, top_face, 0.35)
    # --- the gate and the jar under it ----------------------------------------------------------
    gx = mid + b["gate_dx"]
    kind, ramp = pa.GATE_STYLE[option]
    gate, ga = pa.honey_gate(kind, ramp)
    gate_top = top_face - 13
    g0 = (gx - ga["top"][0], gate_top - ga["top"][1])
    spout_y = g0[1] + ga["spout"][1]
    stream_lay = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    boxes, marks = {}, {}
    if not done:
        # the waiting jar, empty, open, on the shelf at the left
        wait = pa.jar(0.0, lid=False, label=None)
        _place_jar(lay, wait, gx - WAIT_GAP, jar_feet)
        _shade_box(lay, gx - WAIT_GAP + 13, gx - WAIT_GAP + 15, jar_feet - 3, jar_feet, 0.35)
        # the jar under the gate: its back, the stream into its honey, its front
        fill = 0.0 if start else FILL_MID
        jb, jf = pa.jar_parts(fill, lid=False, label=None, line=True)
        jx, jy = gx - pa.JAR_FEET[0], jar_feet - pa.JAR_FEET[1]
        lay.alpha_composite(jb, (jx, jy))
        if not start:
            surf = jy + 1 + pa.jar_surface(FILL_MID)
            pa.stream(stream_lay, gx, spout_y, surf, OPEN)
            pa.dim_inside(stream_lay, jy + 1 + pa.JAR_NECK + 2)
            pa.coils(stream_lay, gx, surf, 9)
            lay.alpha_composite(stream_lay)
        lay.alpha_composite(jf, (jx, jy))
        _shade_box(lay, gx + 13, gx + 15, jar_feet - 3, jar_feet, 0.35)
    else:
        # a ring of honey left on the shelf where the last jar stood
        px = lay.load()
        for dx in range(-8, 9):
            y = jar_feet - 1 + (1 if abs(dx) > 5 else 0)
            if px[gx + dx, y][3]:
                px[gx + dx, y] = (pa.HONEY[1] if abs(dx) > 6 else pa.HONEY[2])[:3] + (255,)
    lay.alpha_composite(gate, g0)
    if done:
        pa.gate_bead(lay, gx, spout_y + 1)
    lv, lp, lg = pa.lever(OPEN if step == "pour" else 0.0, option, cue=start)
    pivot = (g0[0] + ga["pivot"][0], g0[1] + ga["pivot"][1])
    lay.alpha_composite(lv, (pivot[0] - lp[0], pivot[1] - lp[1]))
    marks["grip"] = (pivot[0] - lp[0] + lg[0], pivot[1] - lp[1] + lg[1])
    # --- the bench and its jars ----------------------------------------------------------------
    bench = {"A": pa.stump_bench, "B": pa.blue_bench, "C": pa.crate_bench}[option]
    bc = bench(lay, BENCH_X, BENCH_W, BENCH_TOP, BENCH_FEET)
    bfeet = bc["face"][0] + 3
    jar_top = bfeet - pa.JAR_FEET[1]
    n = 3 if done else 0 if start else 1
    for i in range(n):
        cx = BENCH_X + SLOTS[i]
        label = "crown" if (done and option == "A") else "hex"
        j = pa.jar(pa.JAR_LINE, lid=True, label=label, glow=done)
        if done:
            j = pa.gold_rim(j)
            at = (cx - pa.JAR_FEET[0] - 1, bfeet - pa.JAR_FEET[1] - 1)
            lay.alpha_composite(j, at)
            jars_lay.alpha_composite(j, at)
        else:
            _place_jar(lay, j, cx, bfeet)
        _shade_box(lay, cx + 13 + (1 if done else 0), cx + 15 + (1 if done else 0), bfeet - 3, bfeet, 0.35)
    if done:
        mid_jar = BENCH_X + SLOTS[1]
        if option == "B":
            ro, rc = pa.rosette(15)
            at = (mid_jar - rc[0] + 1, jar_top + 19 - rc[1])
            lay.alpha_composite(ro, at)
            jars_lay.alpha_composite(ro, at)
        if option == "C":
            cr = pa.big_crown()
            at = (mid_jar - cr.width // 2 + 1, jar_top - cr.height + 4)
            lay.alpha_composite(cr, at)
            jars_lay.alpha_composite(cr, at)
    # --- shadows and rays on the lawn, then everything onto the plate ---------------------------
    pic = backdrop()
    arr = np.array(pic)
    core, fringe = shadow_cells(option, st, bc)
    pa.shade_cells(arr, core, fringe, G, ink=pa.OUT, t=SHADE_T)
    if done:
        tint_cells(arr, ray_cells(option, BENCH_X + SLOTS[1], bfeet - 24), pa.GOLD[4])
    pic = Image.fromarray(arr)
    look.place(pic, lay, (0, 0), G)
    if done:
        arr = np.array(pic)
        tint_cells(arr, halo_cells(np.array(jars_lay)[..., 3] > 0), pa.GOLD[4])
        pic = Image.fromarray(arr)
        for sx, sy, state in payoff_stars(option, frame):
            s = star_sprite(state)
            look.place(pic, s, look.art_px((sx - s.width // 2, sy - s.height // 2)), G)
    # --- bees ------------------------------------------------------------------------------------
    def bee(x, y, pose="fly", frm=0, left=False):
        im = look.bee(BEE, frm, facing_left=left, pose=pose)
        look.place(pic, im, look.art_px((x, y)), G, anchor=look.bee_anchor(BEE, pose, left, frm))
    rim_y = int(mouth[1] - b["inner"][1] - 1)
    bee(int(mouth[0] - b["inner"][0] + 8), rim_y - 2, "rest", 0, False)
    if option == "B":
        bee(STAND_X + 84, SHELF - 3, "walk", frame % 2, True)       # walking in at the entrance
    if not done:
        if not start:
            bee(gx + 16, spout_y + 12, "fly", 1, True)             # drawn to the stream
            bee(BENCH_X + SLOTS[0] + 2, bfeet - pa.JAR_FEET[1] - 2, "walk", 0, True)   # on the lid
        bee(BENCH_X + 70, BENCH_TOP - 40, "fly", 4, False)
        bee(150, 176, "fly", 2, False)
        bee(470, 132, "fly", 5, True)
    else:
        bee(BENCH_X + 24, BENCH_TOP - 70, "fly", (1 + frame) % 6, False)
        bee(BENCH_X + 100, BENCH_TOP - 74, "fly", (4 + frame) % 6, True)
        if option == "A":
            bee(BENCH_X + SLOTS[1] + 1, jar_top - 2, "rest", frame % 4, True)
        elif option == "B":
            bee(BENCH_X + SLOTS[2] + 1, jar_top - 2, "rest", frame % 4, True)
        else:
            bee(BENCH_X + SLOTS[0] + 1, jar_top - 2, "rest", frame % 4, False)
        bee(gx + 6, spout_y + 10, "fly", (2 + frame) % 6, True)    # after the last drop
        bee(160, 170, "fly", 3, False)
    pic = with_ui(pic, step)
    # --- the zoom boxes (plate px) ------------------------------------------------------------
    def box(x0, y0, x1, y1):
        return (x0 * G, y0 * G, x1 * G, y1 * G)
    boxes["gate"] = box(gx - 24, gate_top - 26, gx + 30, jar_feet + 3)
    boxes["bucket"] = box(bx - 2, by - 4, bx + b["body"].width + 2, top_face + 4)
    boxes["stand"] = box(STAND_X - 6, top_face - 4, STAND_X + STAND_W + 20, STAND_FEET + 12)
    boxes["bench"] = box(BENCH_X - 8, BENCH_TOP - 70, BENCH_X + BENCH_W + 14, BENCH_FEET + 9)
    out = (pic, boxes, marks)
    _render_cache[key] = out
    return out


# =============================================================================================
# The sheet
# =============================================================================================
def hold_mark(z, box, grip, s=3):
    """On a zoom of `box` (s x), a dashed ring and HOLD tag round the lever's grip: the target
    the player holds (sheet ink only, never on the art)."""
    d = ImageDraw.Draw(z)
    gx = ((grip[0] + 0.5) * G - box[0]) * s
    gy = ((grip[1] + 0.5) * G - box[1]) * s
    r = 13 * G * s / 3.0
    for i in range(24):
        if i % 2:
            continue
        a0, a1 = i * 15, i * 15 + 15
        d.arc([gx - r, gy - r, gx + r, gy + r], a0, a1, fill=look.MARK, width=4)
    f = look.font(20, "label")
    d.text((gx + r - 10, gy - r - 24), "HOLD", font=f, fill=look.MARK)
    return z


def option_body(option):
    start, bs, ms = render(option, "start")
    pour, bp, mp_ = render(option, "pour")
    done, bd, md_ = render(option, "done")
    os.makedirs(SCRATCH, exist_ok=True)
    pour.convert("RGB").save(os.path.join(SCRATCH, "pour_%s.png" % option))
    done.convert("RGB").save(os.path.join(SCRATCH, "done_%s.png" % option))
    start.convert("RGB").save(os.path.join(SCRATCH, "start_%s.png" % option))
    mp, md = pour.copy(), done.copy()
    ladder = stack([panel(look.crop_zoom(start, bs["bucket"], 3), "0.55 (from uncap)"),
                    panel(look.crop_zoom(pour, bp["bucket"], 3, mp), "0.3 (mid-fill)"),
                    panel(look.crop_zoom(done, bd["bucket"], 3, md), "done (scraped)")], "h", 8)
    zs = look.crop_zoom(start, bs["gate"], 3)
    zs = hold_mark(zs, bs["gate"], ms["grip"])
    zp = look.crop_zoom(pour, bp["gate"], 3, mp)
    zp = hold_mark(zp, bp["gate"], mp_["grip"])
    z = [panel(ladder, "3x: the bucket's honey, level ladder (start / pour / done)"),
         panel(zs, "3x: start: lever shut, glint and wobble ticks ask to be held"),
         panel(zp, "3x: pouring: lever swung, the stream into the jar"),
         panel(look.crop_zoom(done, bd["gate"], 3, md), "3x: done: lever upright, a bead on the spout"),
         panel(look.crop_zoom(pour, bp["stand"], 3, mp), "3x: the stand, its sun shadow, the empty jar"),
         panel(look.crop_zoom(done, bd["bench"], 3, md), "3x: done: three new jars, the payoff on them")]
    strip = []
    for f in range(4):
        fr, bf, _ = render(option, "done", f)
        strip.append(panel(look.crop_zoom(fr, bf["bench"], 2), "frame %d" % f))
    twinkle = panel(stack(strip, "h", 8), "2x: the payoff's stars twinkling in turn (four beats, rolled for %s)" % option)
    plates = stack([panel(mp, "pour, mid-fill (real scale, 3 px an art px; pink boxes are the zooms)"),
                    panel(md, "done (real scale)")], "h", 16)
    zooms = flow(z + [twinkle], plates.width, 14)
    more = look.text_block(DETAILS[option], plates.width, 17, "text", look.INK_SOFT)
    return stack([plates, zooms, more], "v", 16)


def today_panel():
    pl, dn = look.plate("pour"), look.plate("done")
    mp, md = pl.copy(), dn.copy()
    z1 = look.crop_zoom(pl, (790, 160, 1170, 520), 2, mp)
    z2 = look.crop_zoom(pl, (1140, 690, 1620, 900), 2, mp)
    z3 = look.crop_zoom(dn, (1150, 540, 1620, 900), 2, md)
    halves = stack([panel(mp.resize((960, 540), Image.BOX), "today, pour (half size)"),
                    panel(md.resize((960, 540), Image.BOX), "today, done (half size)")], "h", 14)
    zooms = stack([panel(z1, "2x: the uncap's mint tub, off-palette, on a spindly table"),
                   panel(z2, "2x: the jar shelf: a plank floating in the grass"),
                   panel(z3, "2x: the crown hanging in mid-air over the jars")], "h", 14)
    return stack([halves, zooms], "v", 14)


def main():
    blocks = [today_panel()]
    for o in ("A", "B", "C"):
        body = option_body(o)
        blocks.append(look.option_block(o, OPTION_NAMES[o], CAPTIONS[o], body,
                                        recommended=(o == RECOMMEND)))
    notes = ("Common to all three. The bucket is the uncap sheet's own (uncap_mockup.pail / "
             "oak_bucket / crock, the same pixels, the pail's outside honey run wiped). Its honey "
             "is drawn inside the opening, a row clear of the near rim's lip, as an ellipse that "
             "narrows with the taper and drops as it empties: at 0.55 it shows whole with wall "
             "either side, at 0.3 only its far half under the far inside wall with a dotted tide "
             "mark where it stood, scraped out it is runs down the far inside wall (beads at their "
             "feet) and a little puddle over the near lip. Every stand's top surface is row 219, "
             "on the sand 8+ rows below the waterline seam, so the board and the gate sit on a calm "
             "field. Lever: a 14 px bar and a fat 8 x 6 grip with a knob, shut it glints and wobbles "
             "(the HOLD ring on the zooms is sheet ink). Empty glass shows the room through one "
             "faint step, with the base's back curve and the far wall's edge drawn so it reads "
             "hollow; the stream falls full strength over the mouth and a step dimmer behind the "
             "front glass, landing in a mound with folds. Labels carry the jar's mark, a red "
             "honeycomb cell with honey in it, the mark the HUD jar plate and the island shelf "
             "should wear too. Shadows: the room's sun is top left, so each thing throws its top "
             "0.15 h right and 0.11 h down the screen from its foot (the stand's top about 13 x 9 "
             "art px), swept for solid things, the lawn mixed 0.5 towards the outline with a one-px "
             "checker fringe at half; the uncap sheet should use this recipe and move its bucket's "
             "shadow to down-right. The done payoff is HiveStep.payoff grounded: rays (three "
             "stepped strengths, nine wedges rolled per option) fan up from behind the bench, each "
             "jar wears the finds' gold rim plus a two-step halo and a checker fringe, stars are "
             "rolled per option and each runs big / small / dot / out a beat apart, and the crown "
             "is on the jars; the other room sheets' payoffs should follow it. The FILL pip on the "
             "steps bar is the current step while pouring (emptied, a gold ring inside) and filled "
             "once done. Every colour: the hut's oak, build_hive's BRASS / PINE / WEATHERED / "
             "PAPER / GINGHAM / PAINTS sky / ROOF, the bark, the coin and the finds' gold, the "
             "hive's honey, the palette's clean water and foam; mixes of two at fixed steps.")
    look.sheet("POUR: THE BOTTLING STAND, THE JARS AND THE PAYOFF", blocks, OUT_PATH,
               subtitle="Richard's brief (2026-10-16): a palette bucket (tin, oak or crock, the "
                        "uncap sheet's three) on a sturdy bottling stand with a honey gate and "
                        "lever; the jars on a grounded bench with a shadow; no dog in front; the "
                        "done payoff grounded on the jars, the jars glowing, the bench showing the "
                        "three new jars. Each option drawn on the real capture at the room's grain.",
               notes=notes)
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

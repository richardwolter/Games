#!/usr/bin/env python
"""Pieces of the honey sheet (tools/hive_look/honey_mockup.py): honey ramps, drips and their
rings, bead finding on a recoloured net, the angler's mask, the orbiting bees, the honey coins.

OFFLINE MOCKUPS ONLY. Every colour is an in-game swatch (look.SW, build_hive's honey, the coin's
ramp, the palette's foam) or a mix of them. Sprites are 1 px per art px; world things on the lake
are 1 art px per world px (the angler's, the rubbish's and the pack critters' grain), foam rings
are 2 world px cells (Lake.ART_PIXEL, the splash foam's grain).
"""
import math
import random

import numpy as np
from PIL import Image

import look

bh = look.bh
OUT = look.OUT
SW = look.SW
FOAM = look.PAL["foam"]
FOAM_LIGHT = look.PAL["foam_light"]


def mix(a, b, t):
    return look.mix(a, b, t)


# =============================================================================================
# Honey ramps for the net's rim and beads: {deep, low, mid, lit, shade, shine}.
# =============================================================================================
# A: the jar's own honey (build_hive HONEY_*), one step down: the rim mid is the honey's mid,
# its lit row the honey itself; deep and shade are that honey taken towards the outline.
RAMP_HIVE = {
    "shade": mix(bh.HONEY_DEEP, OUT, 0.58),
    "deep": mix(bh.HONEY_DEEP, OUT, 0.28),
    "low": bh.HONEY_DEEP,
    "mid": bh.HONEY_MID,
    "lit": bh.HONEY,
    "shine": bh.HONEY_LIGHT,
}
# B: NetShape's AMBER_* as built today (scripts/net_shape.gd, 2026-10-16): redder and darker.
RAMP_GAME = {
    "shade": (54, 20, 4, 255), "deep": (104, 40, 8, 255), "low": (160, 70, 14, 255),
    "mid": (210, 108, 24, 255), "lit": (242, 154, 52, 255), "shine": bh.HONEY_LIGHT,
}
GOLD = {"shade": (70, 40, 8, 255), "deep": (122, 76, 18, 255), "low": (196, 136, 34, 255),
        "mid": (240, 190, 64, 255), "lit": (255, 226, 128, 255), "pale": (255, 244, 196, 255)}


# =============================================================================================
# Beads: the recoloured net's bead mask, clumped into beads.
# =============================================================================================
def beads_of(mask, min_px=4):
    """Connected clumps of a bool mask -> list of (cx, cy, x0, y0, x1, y1) in mask px."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    ys, xs = np.nonzero(mask)
    out = []
    for y, x in zip(ys, xs):
        if seen[y, x]:
            continue
        stack = [(y, x)]
        seen[y, x] = True
        pts = []
        while stack:
            cy, cx = stack.pop()
            pts.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(pts) >= min_px:
            py = [p[0] for p in pts]
            px = [p[1] for p in pts]
            out.append((sum(px) / len(px), sum(py) / len(py), min(px), min(py), max(px), max(py)))
    return out


# =============================================================================================
# A drip's life, at one px per world px, anchored on the bead's foot (0, 0) = the pixel under
# the bead's middle. No outline: a drop is an effect, like the splash's drops (whole pixels,
# no ring), lit from the top left.
#   0 swell   the bead sags a pixel
#   1 bead    a drop forming under it
#   2 hang    the drop on a one-px thread
#   3 stretch the thread long, the drop heavier
#   4 fall    the thread snapped, the drop falling with a tail
#   5 fall2   lower
#   6 plop    gone into the water: a ring and an amber dot (drawn by ring/dot)
# =============================================================================================
def drip_rows(stage):
    """Char rows and their top-left offset from the anchor (the pixel under the bead's middle).
    s shine, l lit, m mid, d deep. Honey is thick: a drop is three px across."""
    return {
        0: (["lmd"], (-1, 0)),
        1: (["lmd", "smd", ".d."], (-1, 0)),
        2: ([".m.", ".m.", "lmd", "smd", ".d."], (-1, 0)),
        3: ([".m.", ".m.", ".m.", ".m.", "lmd", "smd", ".d."], (-1, 0)),
        4: ([".m.", "...", "...", ".l.", "smd", "lmd", ".d."], (-1, 0)),
        5: ([".m.", "...", "...", "...", "...", "...", "slm", "lmd", ".d."], (-1, 0)),
    }[stage]


def drip(stage, ramp):
    rows, off = drip_rows(stage)
    key = {"s": ramp["shine"], "l": ramp["lit"], "m": ramp["mid"], "d": ramp["low"]}
    return look.grid(rows, key), off


def drop_bead(ramp):
    """Option B's bead: a plump honey drop hanging under the rim, 3 wide and 4 tall with its
    point down, a shine pixel, ringed in the ramp's shade (not the black outline: it sits on the
    cord, which has none)."""
    rows = [".m.", "slm", "lmd", "mmd", ".d."]
    key = {"s": ramp["shine"], "l": ramp["lit"], "m": ramp["mid"], "d": ramp["low"]}
    im = look.grid(rows, key)
    return im


# =============================================================================================
# The foam ring a drop leaves: WaterSplash.ripple's language, a 2:1 ellipse band one art px
# (2 world px) thick, torn into dashes, foam white, faint. `span` is its width in world px;
# returned at one px per world px with its middle at (cx, cy).
# =============================================================================================
# Small rings authored by hand: at two world px a cell an ellipse drawn by rule comes out a
# rectangle. Each is a 2:1 band one cell thick; they grow S -> M -> L as the ring spreads.
RINGS = {
    "S": [".xxxx.", "x....x", ".xxxx."],
    "M": ["..xxxx..", "xx....xx", "xx....xx", "..xxxx.."],
    "L": ["...xxxxxx...", ".xx......xx.", "x..........x", "x..........x", ".xx......xx.",
          "...xxxxxx..."],
}


def ring(size="M", seed=0, alpha=0.62, cell=2, torn=0.2):
    """A drop's ring on the water, (image, its middle). Foam white, faint, torn by `torn`."""
    rows = RINGS[size]
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w * cell, h * cell), (0, 0, 0, 0))
    rng = random.Random(seed)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != "x":
                continue
            roll = rng.random()
            if roll < torn:
                continue                                  # torn
            a = alpha if roll > 0.5 else alpha * 0.45     # remnant cells
            col = FOAM_LIGHT if (j * 2 < h - 1 and roll > 0.7) else FOAM
            for yy in range(cell):
                for xx in range(cell):
                    im.putpixel((i * cell + xx, j * cell + yy), col[:3] + (int(255 * a),))
    return im, (w * cell // 2, h * cell // 2)


# =============================================================================================
# The angler's own pixels on a plate (a bee behind him is hidden by them): everything inside
# his near-black outline, found by flooding the box from its border over anything else.
# =============================================================================================
def angler_mask(plate, box, dark=96):
    a = np.array(plate.convert("RGB")).astype(int)
    x0, y0, x1, y1 = box
    reg = a[y0:y1, x0:x1]
    edge = reg.sum(2) < dark
    h, w = edge.shape
    out = np.zeros((h, w), bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    for y, x in stack:
        if not edge[y, x]:
            out[y, x] = True
    stack = [(y, x) for y, x in stack if out[y, x]]
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not out[ny, nx] and not edge[ny, nx]:
                out[ny, nx] = True
                stack.append((ny, nx))
    full = np.zeros(a.shape[:2], bool)
    full[y0:y1, x0:x1] = ~out
    return full


# =============================================================================================
# The bees round the angler. Positions in world px relative to the angler's feet, with a depth
# flag (True = behind him). `n` bees at time `t` (seconds), 'full' 8 / 'half' 4 / 'out' 2.
# =============================================================================================
COUNTS = {"full": 8, "half": 4, "out": 1}
SHOW_T = 0.9          # the moment the sheet shows


def orbit_ring(n, t, rx=25.0, ry=8.0, up=20.0, speed=1.6):
    """A: one tilted ring round his middle, evenly spaced, each bee bobbing on its own beat."""
    out = []
    for i in range(n):
        a = t * speed + i * math.tau / n + 0.35
        x = math.cos(a) * rx
        y = -up + math.sin(a) * ry + round(math.sin(t * 9 + i * 1.7))
        out.append((x, y, math.sin(a) < 0, math.cos(a + math.pi / 2) < 0, i))
    return out


def orbit_crown(n, t, rx=12.0, ry=3.0, up=47.0, speed=2.2):
    """B: a crown of bees circling over his hat, close and quick."""
    out = []
    for i in range(n):
        a = t * speed + i * math.tau / max(n, 1) + 0.2
        x = math.cos(a) * rx
        y = -up + math.sin(a) * ry + round(math.sin(t * 11 + i * 2.3))
        out.append((x, y, math.sin(a) < 0, math.cos(a + math.pi / 2) < 0, i))
    return out


# Each escort bee's own loop: radius across, radius up/down, height over the feet, speed (its
# sign the way round), tilt, and where on its loop it stands at SHOW_T (the angle). Loose and
# uneven on purpose; the first ones are the last to leave. The angles are set so the moment the
# sheet shows has the bees spread round him (left and right, high and low, two crossing in front
# of his legs, three behind him but out past his outline): the escort's own radii are about his
# width, so golden-angle phases hid half of them behind his body.
_ESCORT = [
    (30, 7, 30, 1.7, 0.08, math.pi), (28, 8, 20, -2.1, -0.06, 0.30),
    (34, 9, 14, 1.3, 0.05, 3.60), (24, 6, 37, -1.6, 0.0, 5.90),
    (36, 10, 8, 1.1, -0.05, 0.15), (18, 5, 10, -2.6, 0.08, 1.90),
    (26, 8, 20, 1.5, -0.08, 2.20), (40, 12, 24, -1.0, 0.04, 5.50),
]


def orbit_escort(n, t):
    """C: every bee on a loop of its own (radius, height, speed, direction and tilt each its
    own), so the swarm looks alive rather than wheeled round; thinning takes the outer loops
    first. At SHOW_T each bee stands where its angle puts it."""
    out = []
    for i in range(n):
        rx, ry, up, sp, tilt, a0 = _ESCORT[i]
        a = (t - SHOW_T) * sp + a0
        x = math.cos(a) * rx
        y = -up + math.sin(a) * ry + math.cos(a) * rx * tilt * 0.3 + round(math.sin(t * 8 + i * 1.3))
        behind = (math.sin(a) < 0)
        heading = -math.sin(a) * sp
        out.append((x, y, behind, heading < 0, i))
    return out


ORBITS = {"A": orbit_ring, "B": orbit_crown, "C": orbit_escort}


# =============================================================================================
# Honey coins. The gold coin's own ramp (assets/coin.png) mapped onto the hive's honey, a step
# down, so a honey coin is orange where the money's coin is yellow.
# =============================================================================================
COIN_TO_HONEY = {
    (132, 88, 22): mix(bh.HONEY_DEEP, OUT, 0.28),
    (184, 133, 36): bh.HONEY_DEEP,
    (214, 160, 52): bh.HONEY_MID,
    (255, 204, 77): bh.HONEY,
    (255, 236, 150): bh.HONEY_LIGHT,
    (255, 252, 222): bh.HONEY_SHINE,
}
_coin_sheet = None


def coin_frames():
    global _coin_sheet
    if _coin_sheet is None:
        import os
        _coin_sheet = Image.open(os.path.join(look.ROOT, "assets/coin.png")).convert("RGBA")
    return [_coin_sheet.crop((i * 22, 0, i * 22 + 22, 20)) for i in range(9)]


def recolour(im, table):
    a = np.array(im)
    out = a.copy()
    for src, dst in table.items():
        m = (a[..., 0] == src[0]) & (a[..., 1] == src[1]) & (a[..., 2] == src[2]) & (a[..., 3] > 0)
        out[m, :3] = dst[:3]
    return Image.fromarray(out)


def honey_coin(frame=0, drip=True):
    """A: the money's coin turned honey, a drop hanging off its foot (drip True)."""
    im = recolour(coin_frames()[frame], COIN_TO_HONEY)
    if not drip:
        return im
    out = Image.new("RGBA", (22, 24), (0, 0, 0, 0))
    out.alpha_composite(im)
    # the drop: hung off the rim's lowest pixel row, a thread then a 2x2 bead, ringed in black
    b = im.getbbox()
    cx = 13 if frame in (0, 1, 7, 8) else (b[0] + b[2]) // 2 + 1
    rows = ["m", "m", "sm", "md"]
    key = {"s": bh.HONEY_LIGHT, "m": bh.HONEY_MID, "d": bh.HONEY_DEEP}
    d = look.inked(look.grid(rows, key))
    out.alpha_composite(d, (cx - 1 - 1, b[3] - 1 - 1))
    return out


# B: a drop of honey, point up, lit from the top left; three poses for the flight: round
# (leaving), long (stretched along the arc) and squashed (landing).
HONEY_DROP = {
    "round": [
        "....OO....",
        "...OsO....",
        "..OslmO...",
        "..OlHmO...",
        ".OslHHmO..",
        ".OlHHHmO..",
        "OslHHHHmO.",
        "OlHHHHHmO.",
        "OlHHHHMMO.",
        "OHHHHHMMO.",
        ".OHHHMMdO.",
        ".OMMMMdO..",
        "..OOOOO...",
    ],
    "long": [
        "...OO...",
        "..OsO...",
        "..OlmO..",
        "..OlmO..",
        ".OslHO..",
        ".OlHmO..",
        ".OlHmO..",
        "OslHHmO.",
        "OlHHHmO.",
        "OlHHMMO.",
        "OHHHMMO.",
        ".OHMMdO.",
        ".OMMdO..",
        "..OOO...",
    ],
    "squash": [
        "....OOOO....",
        "...OsllmO...",
        "..OslHHHmO..",
        ".OslHHHHHmO.",
        "OslHHHHHHMMO",
        "OHHHHHHHMMdO",
        ".OMMMMMMMdO.",
        "..OOOOOOOO..",
    ],
}
DROP_KEY = {"O": OUT, "s": bh.HONEY_SHINE, "l": bh.HONEY_LIGHT, "H": bh.HONEY, "m": bh.HONEY_MID,
            "M": bh.HONEY_MID, "d": bh.HONEY_DEEP}


def honey_drop(pose="round"):
    return look.grid(HONEY_DROP[pose], DROP_KEY)


# C: a bee bringing the money home. The worker bee (look.bee, the room's bee, at the HUD's grain)
# carries a small honey coin under its belly: a disc 10 px across by rule, lit from the top left
# in the hive's honey, ringed in the outline.
MINI_COIN = [
    "...OOO...",
    ".OOsllOO.",
    ".OslLLLO.",
    "OslmmmLmO",
    "OlLmLmLmO",
    "OlLmmmLmO",
    ".OLLLLmO.",
    ".OOmmmOO.",
    "...OOO...",
]


def mini_coin():
    """A small honey coin, 9 px, its struck ring in the middle, lit from the top left."""
    return look.grid(MINI_COIN, {"O": OUT, "s": bh.HONEY_SHINE, "l": bh.HONEY_LIGHT, "L": bh.HONEY,
                                 "m": bh.HONEY_MID})


def bee_coin(frame=0, facing_left=True):
    """A worker bee flying with a honey coin hugged under it: RGBA and the coin's middle."""
    b = look.bee("A", frame, facing_left=facing_left, pose="fly")
    ax, ay = look.bee_anchor("A", "fly", facing_left, frame)
    coin = mini_coin()
    out = Image.new("RGBA", (20, 22), (0, 0, 0, 0))
    bob = look.BOB[frame % 6]
    bx, by = 10 - ax, 8 - ay + bob - look.BOB[frame % 6]
    out.alpha_composite(coin, (6, 12 + bob))
    # two legs from the belly to the coin's rim
    for lx in (8, 11):
        out.putpixel((lx, 11 + bob), OUT)
    out.alpha_composite(b, (bx, by))
    return out, (10, 16 + bob)


# =============================================================================================
# The teardrop drip (second review, 2026-10-17): the 1-px thread and 2x2 drop of `drip` were
# three screen px at real scale and read as fringe. A drop is now a 3x4 teardrop with a lit
# pixel, ringed in the outline like every sprite (5x6 with it), on a 1-px thread; only a few
# hang at once. Anchored on the bead's foot (0, 0) = the pixel under the bead's middle.
#   'hang'    the drop under the bead on a 2 px thread
#   'stretch' the thread 5 px long, the drop heavier
#   'fall'    the thread snapped (a 1-px stub stays on the bead), the drop falling, a tail on it
# =============================================================================================
TEAR = [".l.",
        "slm",
        "lmd",
        ".d."]


def tear(ramp):
    key = {"s": ramp["shine"], "l": ramp["lit"], "m": ramp["mid"], "d": ramp["low"]}
    return look.inked(look.grid(TEAR, key))


def tear_drip(stage, ramp, fall=9):
    """A drip at `stage` ('hang', 'stretch', 'fall'): (RGBA, its top-left offset from the
    anchor). The thread is the ramp's mid, no outline (it is a hair of honey)."""
    drop = tear(ramp)
    thread = {"hang": 2, "stretch": 5, "fall": 0}[stage]
    if stage == "fall":
        tall = 1 + fall + drop.height
        im = Image.new("RGBA", (drop.width, tall), (0, 0, 0, 0))
        im.putpixel((2, 0), ramp["mid"])           # the stub left on the bead
        im.putpixel((2, fall - 1), ramp["lit"])    # the tail riding on the drop
        im.alpha_composite(drop, (0, fall))
        return im, (-2, 0)
    im = Image.new("RGBA", (drop.width, thread + drop.height), (0, 0, 0, 0))
    for y in range(thread):
        im.putpixel((2, y), ramp["mid"])
    im.alpha_composite(drop, (0, thread - 1 if thread else 0))
    return im, (-2, 0)


# The plop a drop leaves: a foam ring (the splash's 2 world px cells) that stays whole and
# bright enough to read on murky water, round a honey blob (2x2 with a lit pixel, inked) that
# floats a moment after the ring has spread. 'S' just in, 'M' spreading, 'L' going (fainter).
def plop(size="M", seed=0, ramp=None, dot=True):
    alpha = {"S": 0.92, "M": 0.85, "L": 0.55}[size]
    r, mid = ring(size, seed, alpha=alpha, torn=0.06 if size != "L" else 0.3)
    out = r.copy()
    if dot and ramp is not None:
        blob = look.inked(look.grid(["lm", "md"], {"l": ramp["lit"], "m": ramp["mid"],
                                                  "d": ramp["low"]}))
        out.alpha_composite(blob, (mid[0] - 2, mid[1] - 2))
    return out, mid


# The round mini bee carrying a small honey coin (option 4C's courier): the lake's bee, the
# coin a 5x5 disc slung under it on two legs.
TINY_COIN = [".OOO.", "OslLO", "OlmLO", "OLLmO", ".OOO."]


def tiny_coin():
    return look.grid(TINY_COIN, {"O": OUT, "s": bh.HONEY_SHINE, "l": bh.HONEY_LIGHT,
                                 "L": bh.HONEY, "m": bh.HONEY_MID})


def courier(frame=0, facing_left=True):
    """The round mini bee with a tiny honey coin hugged under it: RGBA and the coin's middle."""
    b = look.mini_round("A", frame, facing_left=facing_left, pose="fly")
    ax, ay = look.mini_round_anchor("A", "fly", facing_left, frame)
    out = Image.new("RGBA", (14, 16), (0, 0, 0, 0))
    bx, by = 7 - ax, 6 - ay
    coin = tiny_coin()
    cy = by + ay + 4
    out.alpha_composite(coin, (5, cy))
    out.alpha_composite(b, (bx, by))
    return out, (7, cy + 2)


# =============================================================================================
# The honey coin, drawn by rule (second review): the gold coin recoloured a step down read as
# the same coin in another hue. This one is struck differently: a thick HONEY_DEEP rim (two px,
# lit HONEY_MID on its top-left half), an amber HONEY face with a HONEY_LIGHT crescent and a
# shine pixel top-left, and a comb cell for its stamp (a flat-topped hex in HONEY_DEEP, honey
# inside it, a lit lip under it) where the money's coin has the recycle arrows. It turns
# through the gold coin's own nine widths. A drop of honey clings to its trailing (lower-right)
# rim on the face frames; edge-on there is nothing to hang it on.
# =============================================================================================
COIN_WIDTHS = [20, 16, 11, 7, 6, 7, 11, 16, 20]
HEX = {   # pointy-topped comb cells, at the face's three widths
    8: ["...x...", ".xx.xx.", "x.....x", "x.....x", "x.....x", ".xx.xx.", "...x..."],
    6: ["..x..", ".x.x.", "x...x", "x...x", "x...x", ".x.x.", "..x.."],
    4: [".x.", "x.x", "x.x", "x.x", ".x."],
}


def _coin_disc(w, h=20):
    cx, cy = w / 2.0, h / 2.0
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            if ((x + 0.5 - cx) / (w / 2.0)) ** 2 + ((y + 0.5 - cy) / (h / 2.0)) ** 2 < 1.0:
                m[y, x] = True
    return m


def _edge(m):
    e = np.zeros_like(m)
    h, w = m.shape
    for y in range(h):
        for x in range(w):
            if m[y, x]:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or not m[ny, nx]:
                        e[y, x] = True
                        break
    return e


def honey_coin2(frame=0, bead=True):
    """The honey coin at frame 0..8 (face, edge at 4, back at 8), on a 24x24 canvas, the disc's
    middle at (12, 10). Returns RGBA."""
    w = COIN_WIDTHS[frame]
    back = frame >= 5
    m = _coin_disc(w)
    o = _edge(m)
    inner = m & ~o
    r1 = inner & _edge(inner)
    inner2 = inner & ~r1
    r2 = inner2 & _edge(inner2) if w >= 11 else inner2
    face = inner2 & ~r2
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    ox = 12 - w // 2
    cx, cy = w / 2.0, 10.0
    face_col = mix(bh.HONEY, bh.HONEY_MID, 0.35) if back else bh.HONEY
    for y in range(20):
        for x in range(w):
            if not m[y, x]:
                continue
            lit = (x + 0.5 - cx) + (y + 0.5 - cy) < -1.0
            if o[y, x]:
                c = OUT
            elif r1[y, x] or r2[y, x]:
                c = bh.HONEY_MID if lit else bh.HONEY_DEEP
                if w < 11 and not back and x == int(cx) - 1:
                    c = bh.HONEY        # edge-on: a lit band down the thickness
            else:
                c = face_col
                d = math.hypot((x + 0.5 - cx) / (w / 2.0), (y + 0.5 - cy) / 10.0)
                if lit and d > 0.45 and not back:
                    c = bh.HONEY_LIGHT
            im.putpixel((ox + x, y), c)
    if w >= 11:
        key_ = 8 if w >= 20 else (6 if w >= 16 else 4)
        rows = HEX[key_]
        hexw = len(rows[0])
        hx = ox + (w - hexw) // 2
        hy = 10 - len(rows) // 2
        stamp = bh.HONEY_DEEP if not back else mix(bh.HONEY_DEEP, OUT, 0.3)
        for j, row in enumerate(rows):
            inside = [i for i, ch in enumerate(row) if ch == "x"]
            for i, ch in enumerate(row):
                if ch == "x":
                    im.putpixel((hx + i, hy + j), stamp)
                    # the lit lip under the stamp's lower edges
                    if j >= len(rows) - 2 and not back and im.getpixel((hx + i, hy + j + 1))[:3] == face_col[:3]:
                        im.putpixel((hx + i, hy + j + 1), bh.HONEY_LIGHT)
            if 0 < j < len(rows) - 1 and len(inside) == 2:
                for i in range(inside[0] + 1, inside[1]):
                    im.putpixel((hx + i, hy + j), bh.HONEY_LIGHT if not back else bh.HONEY)
        if not back:
            if hexw >= 5:
                im.putpixel((hx + 2, hy + 2), bh.HONEY_SHINE)
    if not back and w >= 16:
        im.putpixel((ox + int(w * 0.28), 4), bh.HONEY_SHINE)
    if bead and w >= 16:
        # the drop clinging to the lower-right rim: a 2x3 bead, inked, tucked onto the outline
        bx = ox + int(round(cx + w * 0.22))
        by = 18
        d = look.inked(look.grid(["lm", "md"], {"l": bh.HONEY_LIGHT, "m": bh.HONEY_MID,
                                                "d": bh.HONEY_DEEP}))
        im.alpha_composite(d, (bx - 1, by - 1))
    return im


def trail_drop(fade_step=0):
    """A 2x2 trail drop inked in the outline, at one of three hard alpha steps."""
    a = (255, 170, 95)[fade_step]
    d = look.inked(look.grid(["lm", "md"], {"l": bh.HONEY_LIGHT, "m": bh.HONEY_MID, "d": bh.HONEY_DEEP}))
    arr = np.array(d)
    arr[..., 3] = (arr[..., 3] > 0) * a
    return Image.fromarray(arr)

"""floor.py -- the house's floor boards through the three stages (house-stages mockup, 2026-10-11).

Everything STRUCTURAL on the boards, per art_source/house_inside/layout.json:

  stage 1  the four holes (h1 the sun hole, h2 the low corner, h3 the roof corner, h4 the
           stove's ghost) and what is under them (earth, joists, clods, pebbles, roots, the
           weeds and a fern, the low corner's pool, the stove's ash); the broken boards (b1
           sunk at the path's end, b2 the crease, b3 tented); the cracks c1-c3; the loose
           board l1; the worn path w1; the board stains (s1 the bleached seat, s3 the stove's
           rust ring, soot and dents, s4 s5 s6 s7 the water's marks); grime board by board;
           the threshold t1; the debris d1; the daylight slits on h2's earth (lt1).
  stage 2  fresh tan patches f1-f7 laid joint to joint, the two cores sawn square (h1 in
           flower, h2 waiting for its sill beam), the unnailed board lb2, the stack and saw
           st1, the old board split c5 (and c2), the faint stove ring, s8 s9 s10.
  stage 3  only the last-laid boards a step lighter, and one daisy in the seat's seam.

LEFT TO THE OTHER MODULES: the puddles p1-p3, their wet halos, drips, rings and the p1
trickle (damp.py), mushrooms m1-m6 and the skirting weeds (damp.py), the frame (veg.py),
the room's veil and anything in the air (life.py).

THE RULES THIS FILE KEEPS
  * The planks are the tile's own (assets/Shed_Floor_Tile.png): seam row at floor-rel
    y % 4 == 0, wood rows 4k+1..4k+3, butt joints at x = [6, 10, 4, 12][k % 4] + 16 m.
  * Every BLOCKING thing reads as blocking over its whole block, out to the block's exact
    edges. ROUND 2 (critics): b1 is wet boards sunk joint to joint (top gap only, the tile's
    wood x0.82 under a damp tint, one board snapped in a 2-px wedge); b2 is no longer the
    crease (it broke ACROSS the grain and read as a black lightning crack): it is the SILL
    ROT, two boards a row gone on the last three rows, ends on the tile's joints, a hole H5
    with earth and grass, the row-200 board over it snapped; b3 is the tile's own wood
    lifted 1 -> 3 px in a ridge (far slope x0.74, ridge x1.12, near x0.9, lit tops x1.12,
    gaps only where a board rises over the one above, its shadow x0.78 off its ends). No
    grey and no lift toward white anywhere: `mul` keeps the wood's hue.
  * A hole (round 2): the far rim's cut is an INK row, then the shadow INSIDE the hole (2
    rows of HOLE[1]) and the earth in one hard step; a 1-px HOLE[0] contact line down the
    side rims; nothing darkened outside the cut but the near rim's 1-px lip. The earth is a
    FLAT base step (the beam's patch a step up, the wall column and the last row a step
    down), textured only by clods (2x1..3x2, one lit pixel, one shade pixel under) and
    pebbles (2x1 stone over INK), 2 px apart: no per-pixel noise, no lone specks. Board ends
    are staggered 0-2 px per row in a 2-3 tooth profile seeded per board, each row ending in
    end grain (x1.12) and an INK edge into the hole, one pale tooth on about half of them;
    an end on a butt joint is level. Joists are 3 px of RAFTER, inked both sides; h4's is
    charred (HOLE[2], RAFTER[0] lit column) in grey ash-mud (ASHMUD) with one pale
    seedling. h4 has no dish and no rust ring in stage 1 (the ring read as a blur).
  * Cracks run along the grain inside one board (`split_line`): 3-8 px in the seam's colour,
    one step at most, a lit lip above, clear of the joints. s5's tide lines are dashes along
    the planks, not diagonal hairlines.
  * lt1, the daylight slits, is dropped (SLITS = []): on dark earth it read as a stick or a
    ladder however it was drawn. LT1 = True brings back a single streak.
  * Plants: grass in tufts (3-6 blades from one root); one draught for the whole floor
    (`sway`: a gust noise rolling across from the window, tips lean 1 px right a quarter of
    the time, only the tips of the tall blades; h1 changes <= ~15 px a tick, mostly still).
  * Whole source pixels, hard steps off ramps, no dither.
  * ROUND 3 (critics): b3 laid column by column as a hump (lift 1..4, 2-px crevices where a
    board rises over the one above, turned-down faces WOOD_FACE_HI/WOOD_FACE/WOOD_DEEP where
    it stands over the one below, lit top rows, the ridge lightest, moss only in crevices,
    no INK, the flat floor's shadow under its foot); s6 one hard step, whole boards. b1 sunk
    one step (x0.88, DEAD 0.15), HOLE[0] gap and the upper board's WOOD_DEEP face, cupped,
    lit arris where a sound board meets it, the snapped board OPEN to wet earth between two
    tipped halves with splinters. Holes: h2/h3 earth on three hard steps by depth (far band
    HOLE[0], upper, middle, lightest strip over a board near rim; `Hole.steps`), clods 3-8 px
    lit top-left with a shade row, snapped ends carried 0-3 px further per plank with a
    tapering tongue (WOOD_FACE body, pale tip, shade under), joint ends a RAFTER end-grain
    column and a nail hole. h1's earth one step lower, its band kept dark in the beam.
    Stage 2's fresh boards each their own tone (3, hashed), a sawn lip on a third of them.
  * Static pixels built once per stage and cached; a frame redraws the plants.

STAGE-UPS (8 fps ticks; life.py's veil steps at p .625 and .875 are left alone)
  1->2  boards under every stage-2 piece's base are down already at p 0; f2/f1 round the
        cores land first (p .19-.42), then the cores are sawn square 2 plank rows a tick from
        .44 while their stage-1 earth dissolves in 4 hash-ordered steps (.44 .5 .56 .69) and
        the pool dries about its middle in 4 steps two ticks apart (.44 .56 .69 .81; nothing
        else touches its pixels while they are water); the other patches land .30-.75, lb2 at
        .81; the stack is built WITHOUT it in s2 and set down whole, A .69, B .75, saw .81.
        Round 2: the cores are never bare: stage-2 plants stand up .31-.56 (as the first
        weeds under new boards go) and open .5-.69, and only then does the stage-1 grass
        rooted in a core thin out (.69 .75 .81). A plant outside the cores is gone the tick
        a landed board covers any pixel of it.
  2->3  the stack goes board by board (B as h2's core starts, A as h1's), h2's core boarded
        from the sill (.25-.48), h1's from the far rim (.5-.66), the saw with A; every new
        board weathers in three steps. stage_up(frm, 1.0) == draw(frm + 1) exactly
        (out/_ff_endcheck.py), and stage_up(2, 0) == draw(2).
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import base  # noqa: E402
from base import (DEAD, FRESH, HOLE, INK, LEAF, MOSS, WATER, WHITE, YELLOW,  # noqa: E402
                  mix, vnoise)

hsh = base.h

# ------------------------------------------------------------------ geometry (floor-relative)
_CTX = base.Ctx(1)
FX, FY, FW, FH = _CTX.floor                # (84, 84, 336, 224) in source px
X0, X1, Y0, Y1 = 6, 330, 10, 214           # the boards inside the moulding
JOINT = (6, 10, 4, 12)
LAY = base.load_layout()
FEAT = {f["id"]: f for f in LAY.get("features", [])}


def jx(k):
    return JOINT[k % 4]


def is_jt(x, k):
    return (x - jx(k)) % 16 == 0


def seg_of(x, k):
    return (x - jx(k)) // 16


def runs_of(rects):
    """layout rects [x, y, w, h] -> [(y, x0, x1, hh)]"""
    return [(r[1], r[0], r[0] + r[2], r[3]) for r in rects]


def mask_of(runs):
    m = np.zeros((FH, FW), bool)
    for y, x0, x1, hh in runs:
        m[y:y + hh, x0:x1] = True
    return m


def hsh_np(x, y, seed):
    x = np.asarray(x).astype(np.uint64)
    y = np.asarray(y).astype(np.uint64)
    n = (x * np.uint64(374761393) + y * np.uint64(668265263) + np.uint64(seed * 2147483647)) & np.uint64(0xFFFFFFFF)
    n = ((n ^ (n >> np.uint64(13))) * np.uint64(1274126177)) & np.uint64(0xFFFFFFFF)
    return ((n ^ (n >> np.uint64(16))) & np.uint64(0xFFFFFF)).astype(np.float64) / float(0xFFFFFF)


# ------------------------------------------------------------------ colours
FLOOR_RGB = np.asarray(base.shell_src(1)).astype(np.int32)[FY:FY + FH, FX:FX + FW].copy()


def floor_c(x, y):
    return tuple(int(v) for v in FLOOR_RGB[y, x])


ROT = (72, 40, 36)          # where grime and rot pull a board
WETC = (96, 82, 76)         # where water pulls it (darker AND greyer)
BLEACH = (234, 206, 172)    # where the sun pulls it
SOOT = (46, 40, 40)
RUST = (122, 46, 28)
WOOD_FACE = (128, 74, 52)   # a board's edge face / end grain, old wood
WOOD_FACE_HI = (152, 92, 62)
WOOD_DEEP = (92, 52, 40)
EDGE_LIP = (58, 38, 30)     # the near rim's lip: the hole's lower outline

# earth, darkest first (6 steps); the shadow band under every far rim is HOLE.
DRY = [(36, 26, 20), (54, 39, 28), (76, 55, 37), (100, 73, 48), (126, 94, 62), (154, 120, 80)]
WETE = [(16, 12, 12), (25, 19, 17), (36, 27, 23), (50, 38, 30), (66, 51, 38), (86, 68, 50)]
DAMP = [mix(a, b, 0.4) for a, b in zip(DRY, WETE)]
ASH = [(34, 31, 31), (52, 48, 46), (72, 68, 64), (95, 90, 84), (120, 114, 106), (150, 143, 132)]
# h4's ash-mud (round 2): greys from DEAD[0] toward a wet ash grey, flatter than any earth
ASHMUD = [(30, 26, 22), (42, 37, 31), (56, 50, 40), (70, 66, 58), (82, 78, 71), (98, 94, 87)]
STONE = [(44, 40, 40), (84, 80, 76), (124, 118, 110), (168, 162, 150)]
ROOT = [(84, 62, 44), (128, 98, 68), (172, 142, 102)]
JOIST = [(40, 28, 22), (66, 44, 33), (100, 68, 47), (136, 98, 66)]   # RAFTER, lit a step
CHAR = [(22, 19, 19), (38, 33, 32), (60, 52, 49), (90, 80, 74)]
DUST = [(176, 156, 128), (212, 194, 164), (236, 222, 198)]
NAIL = (74, 68, 66)
NAIL_HI = (180, 176, 168)
METAL = [(52, 54, 60), (104, 108, 116), (162, 166, 172), (220, 224, 226)]
LIGHT = (246, 214, 150)     # the daylight slits' colour
PALE_UNDER = (214, 176, 132)  # a sprung board's raw underside


def dk(c, n):
    return mix(c, ROT, 0.15 * n)


def wt(c, n):
    return mix(c, WETC, 0.16 * n)


def lt(c, n):
    return mix(c, BLEACH, 0.2 * n)


def mul(c, k):
    """The same wood a step lighter (k > 1) or darker (k < 1), its hue kept: never toward
    white or grey (round 2: lifted toward white, boards read as grey stone shelves)."""
    return tuple(min(255, max(0, int(round(v * k)))) for v in c[:3])


def clampi(v, a, b):
    return a if v < a else b if v > b else v


# ------------------------------------------------------------------ the beam (off the capture)

def _beam():
    full, top, alpha, shell, inside = base._layers(1)
    t = top[1::3, 1::3, 0] * 255
    a = alpha[1::3, 1::3, 0]
    v = np.clip((t - 30) / 70.0, 0, 1)[FY:FY + FH, FX:FX + FW].copy()
    occ = a[FY:FY + FH, FX:FX + FW] > 0.5
    for x in range(FW):                       # furniture: take the pixel above
        for y in range(1, FH):
            if occ[y, x]:
                v[y, x] = v[y - 1, x]
    return v


BEAM = _beam()


# ------------------------------------------------------------------ canvases

class Can:
    """The floor box on the source grid: the colour I show (rgb) and where I show it (a)."""

    def __init__(self):
        self.rgb = FLOOR_RGB.copy()
        self.a = np.zeros((FH, FW), bool)

    def put(self, x, y, c, free=False):
        x, y = int(x), int(y)
        ok = (0 <= x < FW and 0 <= y < FH) if free else (X0 <= x < X1 and Y0 <= y < Y1)
        if ok:
            self.rgb[y, x] = c[:3]
            self.a[y, x] = True

    def get(self, x, y):
        return tuple(int(v) for v in self.rgb[int(y), int(x)])

    def tint(self, x, y, fn):
        if X0 <= x < X1 and Y0 <= y < Y1:
            self.put(x, y, fn(self.get(x, y)))

    def image(self):
        out = np.zeros((FH, FW, 4), np.uint8)
        out[..., :3] = np.clip(self.rgb, 0, 255)
        out[..., 3] = np.where(self.a, 255, 0)
        return out


class Ov:
    """A per-frame overlay (plants, dust): opaque pixels, floor-relative."""

    def __init__(self):
        self.px = np.zeros((FH, FW, 4), np.uint8)

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < FW and 0 <= y < FH:
            self.px[y, x, :3] = c[:3]
            self.px[y, x, 3] = 255


# ------------------------------------------------------------------ re-laying planks

class Relay:
    """Per-(plank, column) offsets and looks for every broken board, laid in one pass."""

    def __init__(self):
        self.off = {}        # (k, x) -> px down (+) or up (-)
        self.look = {}       # (k, x) -> fn(r, c) -> colour (r 0 seam, 1..3 wood)
        self.face = {}       # (k, x) -> fn(i, n) -> colour of plank k's own edge face
        self.cracks = []     # (k, x, side): a break through plank k at x

    def lay(self, can: Can):
        cols = sorted({x for (k, x) in list(self.off) + list(self.look)})
        ks = [k for (k, x) in list(self.off) + list(self.look)]
        k0, k1 = min(ks), max(ks)
        for x in cols:
            prev = 0
            for k in range(k0 - 1, k1 + 2):
                o = self.off.get((k, x), 0)
                y = 4 * k
                if o > prev:                        # the plank above shows its edge face
                    n = o - prev
                    ff = self.face.get((k - 1, x), _face)
                    for i in range(n):
                        can.put(x, y + prev + i, ff(i, n))
                lk = self.look.get((k, x))
                for r in range(4):
                    if not (0 <= y + r < FH):
                        continue
                    c = floor_c(x, y + r)
                    if lk is not None:
                        c = lk(r, c)
                    can.put(x, y + o + r, c)
                prev = o
        for k, x, side in self.cracks:
            o = self.off.get((k, x), 0)
            y = 4 * k + o
            skip = 1 + int(hsh(k, x, 31) * 3)
            for r in (1, 2, 3):
                if r == skip and hsh(k, x, 32) < 0.6:
                    can.put(x, y + r, dk(can.get(x, y + r), 3))
                    continue
                can.put(x, y + r, mix(can.get(x, y + r), HOLE[1], 0.75))
            fr = 1 + int(hsh(k, x, 33) * 3)
            can.put(x + side, y + fr, FRESH[4])


def _face(i, n):
    return WOOD_FACE_HI if (i == 0 and n > 1) else WOOD_FACE


def _lit_face(i, n):
    return WOOD_FACE_HI if i == 0 else WOOD_FACE


def _dark_face(i, n):
    return WOOD_FACE if i < n - 1 else WOOD_DEEP


def relay_b1(R: Relay):
    """THE PATH'S END: wet boards sunk a pixel (two at the snapped board's V), cupped (lit
    edge, dark trough), split along the grain, joints opened; dark gaps along their tops."""
    snap = 168
    for y, x0, x1, hh in runs_of(FEAT["b1"]["block"]):
        k = y // 4
        for x in range(x0, x1):
            o = 1
            if k == 14 and abs(x - snap) <= 5:
                o = 2
            R.off[(k, x)] = o
            split = (k == 13 and 156 <= x < 166) or (k == 15 and 141 <= x < 152)

            def lk(r, c, x=x, k=k, split=split):
                w = wt(c, 2)
                if r == 0:
                    return mix(c, HOLE[2], 0.65)
                if is_jt(x, k):
                    return dk(w, 3)
                if split and r == 2:
                    return dk(w, 4)
                return (lt(w, 1), w, dk(w, 1))[r - 1] if not (split and r == 1) else lt(w, 2)
            R.look[(k, x)] = lk
            R.face[(k - 1, x)] = _dark_face
        for xe, side in ((x0, 1), (x1 - 1, -1)):
            if not is_jt(xe, k) and not is_jt(xe + (1 if side < 0 else 0), k):
                R.cracks.append((k, xe, side))
        if k == 14:
            R.cracks.append((k, snap, 1))
            R.cracks.append((k, snap + 1, -1))


CREASE_XC = 93
# the slit's width per plank row (k 44..53): nothing in the bowed top rows, widening to the sill
CREASE_SLIT = {44: 0, 45: 0, 46: 1, 47: 1, 48: 2, 49: 2, 50: 3, 51: 4, 52: 5, 53: 6}
CREASE_JIT = {46: 0, 47: 1, 48: 0, 49: 1, 50: 0, 51: 0, 52: 1, 53: 0}


def crease_slit(k):
    """(x0, x1) of the slit on plank row k, ragged: each board snapped its own way."""
    ws = CREASE_SLIT.get(k, 0)
    if not ws:
        return None
    a = CREASE_XC - ws // 2 + CREASE_JIT.get(k, 0)
    return a, a + ws


def relay_b2(R: Relay):
    """THE CREASE: the joist's end dropped off the rotten sill and the boards over it bent
    down into it: every seam dips toward the joist line (1 px, 2 near the sill), the boards
    left of it turned from the window (a step or two darker), right of it toward it
    (lighter); the V widens from a single bowed board to the sill, and from the fourth row
    the boards have parted over the joist: a ragged slit (`_crease_slit`). One board end on
    row 204 sprung up off its nail (pale underside, a dark gap under it)."""
    runs = {y // 4: (x0, x1) for y, x0, x1, hh in runs_of(FEAT["b2"]["block"])}
    xc = CREASE_XC
    for k in range(44, 54):
        y = 4 * k
        t = (y - 176) / 36.0
        env = 2.5 + 11.5 * t
        x0, x1 = runs[k]
        wl = min(env, xc - x0) if k != 51 else xc - x0
        wr = min(env, x1 - 1 - xc) if k != 50 else x1 - 1 - xc
        depth = 1 if k <= 46 else 2 if k <= 50 else 3
        for x in range(int(xc - wl), int(xc + wr) + 1):
            w = wl if x < xc else wr
            f = max(0.0, 1 - abs(x - xc) / (w + 0.5))
            o = int(round(depth * f))
            left = x < xc
            sprung = k == 51 and 84 <= x <= 89
            if sprung:
                o = -1
            R.off[(k, x)] = o

            def lk(r, c, f=f, left=left, sprung=sprung):
                if sprung:
                    return lt(c, 1) if r != 2 else lt(c, 2)
                if r == 0:
                    return dk(c, 3 if f > 0.5 else 2) if f > 0.15 else c
                if left:
                    return dk(c, 3 if f > 0.7 else 2 if f > 0.4 else 1) if f > 0.12 else c
                return lt(c, 2 if f > 0.6 else 1) if f > 0.2 else c
            R.look[(k, x)] = lk
            if sprung:
                R.face[(k, x)] = lambda i, n: PALE_UNDER


def relay_b3(R: Relay):
    """THE TENTED BOARDS: swelled up off their joists in a hump against the gable wall,
    highest on the ridge (rows 48-55) and at the wall, falling to nothing at each run's end:
    boards on the far slope face away (darker, crowded), boards on the near slope show their
    edges stepping down toward us; the seams opened dark, moss in them."""
    for y, x0, x1, hh in runs_of(FEAT["b3"]["block"]):
        k = y // 4
        lmax = {8: 1, 9: 1, 10: 2, 11: 2, 12: 3, 13: 3, 14: 2, 15: 2}.get(k, 1)
        for x in range(x0, x1):
            f = clampi((x1 - x) / max(1, x1 - X0) * 1.5, 0, 1)
            L = int(round(lmax * f))
            R.off[(k, x)] = -L
            far = k < 12
            ridge = 12 <= k <= 13 and L >= 2

            def lk(r, c, x=x, k=k, far=far, ridge=ridge, L=L):
                if r == 0:
                    if L and vnoise(x, k * 4, 3, 41) > 0.55:
                        return MOSS[1] if vnoise(x, k, 2, 42) > 0.5 else MOSS[0]
                    return HOLE[2] if L else dk(c, 2)
                if is_jt(x, k):
                    return dk(c, 3)
                if L == 0:
                    return (c, c, dk(c, 1))[r - 1]
                if ridge:
                    return (lt(c, 3), lt(c, 2), lt(c, 1))[r - 1]
                if far:
                    return (dk(c, 1), dk(c, 2), dk(c, 2))[r - 1]
                return (lt(c, 2), lt(c, 1), c)[r - 1]
            R.look[(k, x)] = lk
            R.face[(k, x)] = _lit_face


# ------------------------------------------------------------------ the broken boards, painted
# Each one must read as "cannot step here" across its WHOLE block (the game blocks walking
# and placing on every pixel of it), so each is drawn right out to the block's edges.

def _runs(fid):
    return {y // 4: (x0, x1, hh) for y, x0, x1, hh in runs_of(FEAT[fid]["block"])}


def _sunk_col(snap, x, y):
    """The colour a sunk board's pixel takes (round 3): the board's own (grimed) wood ONE
    step down (x0.88), a touch toward DEAD[0] (0.15: it stays warm wood, not grey)."""
    return mix(mul(tuple(int(v) for v in snap[y, x]), 0.88), DEAD[0], 0.15)


def paint_b1(can):
    """THE PATH'S END (round 3): every plank row of the block is a wet board sunk a pixel
    (two where the snapped board's halves tip into the break), laid column by column the
    way a stepped floor lies, far boards first:
      * the gap on a sunk board's top edge (HOLE[0]), and under it one row of the sound
        board above's own face in deep shade (WOOD_DEEP) where that board stands higher;
      * the board itself cupped: its first row lit (x1.1), its second the trough (x0.9);
      * where a sound board below meets it, that board's top arris lit (x1.15), the step's
        lip catching the light; the sound board right of a run's end lit on its end column,
        the sunk board's first column in the left neighbour's shadow (HOLE[2]);
      * a split along the grain on two of the boards;
      * the snapped board OPEN between its two halves: a slot down to the earth (the far
        rim's cut HOLE[0], a 2-row shadow band HOLE[1] / HOLE[2], wet earth WETE[2] / WETE[3]
        with one lit clod, the near rim's lip), each half tipped down toward the break and
        ending in pale splinters (FRESH[4] / PALE_UNDER) pointing into it."""
    R = _runs("b1")
    ks = sorted(R)
    k_snap = ks[1]
    x0s, x1s, _ = R[k_snap]
    slot = (x0s + 3, x0s + 13)                       # the opened break (its first board)
    snap = can.rgb.copy()

    def off(k, x):
        if k not in R or not (R[k][0] <= x < R[k][1]):
            return 0
        if k == k_snap and slot[0] - 2 <= x < slot[1] + 2:
            return 2                                 # the halves, tipped into the break
        return 1

    def sound(x, y):
        return tuple(int(v) for v in snap[y, x])

    xs0 = min(r[0] for r in R.values()) - 1
    xs1 = max(r[1] for r in R.values()) + 1
    for x in range(xs0, xs1 + 1):
        for k in range(ks[0], ks[-1] + 2):
            o, prev = off(k, x), off(k - 1, x)
            if o == 0 and prev == 0:
                continue
            y = 4 * k
            if k == k_snap and slot[0] <= x < slot[1]:
                continue                             # the slot, painted below
            n = o - prev
            for i in range(max(0, n)):               # the face of the board above
                can.put(x, y + prev + i, WOOD_DEEP if i == n - 1 else WOOD_FACE)
            if o > prev:
                can.put(x, y + o, HOLE[0])           # the gap at the sunk board's top
            elif o < prev:
                can.put(x, y + o, mul(sound(x, y + 1), 1.15))   # the sound board's arris
            elif o:
                can.put(x, y + o, HOLE[1])           # two sunk boards: the seam opened
            if o == 0:
                for r_ in (1, 2, 3):                 # a sound board (its arris above)
                    can.put(x, y + r_, sound(x, y + r_))
                continue
            for r_ in (1, 2, 3):
                c = _sunk_col(snap, x, y + r_)
                c = mul(c, 1.1) if r_ == 1 else mul(c, 0.9) if r_ == 2 else c
                can.put(x, y + r_ + o, c)
    # the ends of each run: the sound board beyond lit on its end, the sunk one in its lee
    for k, (x0, x1, hh) in R.items():
        y = 4 * k
        for r_ in (1, 2, 3):
            if off(k - 1, x1) == 0 or r_ > 1:
                can.put(x1, y + r_, mul(sound(x1, y + r_), 1.12))
            can.put(x0, y + r_ + 1, HOLE[2])
    # splits along the grain (the wet wood checked)
    for k, sx, n in ((ks[0], R[ks[0]][0] + 3, 6), (ks[2], R[ks[2]][0] + 5, 7)):
        y = 4 * k + 1
        for i in range(n):
            can.put(sx + i + (1 if i >= n - 2 else 0), y + 2, HOLE[1])
            can.put(sx + i, y + 1, mul(_sunk_col(snap, sx + i, y), 1.18))
    # the slot: the snapped board opened down to the wet earth
    y = 4 * k_snap
    a, b = slot
    rows = [HOLE[0], HOLE[1], HOLE[2], WETE[3], WETE[4]]
    for x in range(a, b):
        for i, c in enumerate(rows):
            can.put(x, y + i, c)
        can.put(x, y + len(rows), EDGE_LIP)          # the near rim's lip
    for cx in (a + 4, a + 5, a + 6):                 # one clod, lit top-left, shade under
        can.put(cx, y + 3, WETE[5])
    can.put(a + 4, y + 3, mul(WETE[5], 1.25))
    for cx in (a + 5, a + 6, a + 7):
        can.put(cx, y + 4, WETE[2])
    can.put(a, y + 3, FRESH[4])                      # the left half's broken end: a
    can.put(a + 1, y + 3, PALE_UNDER)                # 2-px tongue, its shade under it
    can.put(a, y + 4, FRESH[3])
    can.put(a + 1, y + 4, HOLE[0])
    can.put(b - 1, y + 4, FRESH[4])                  # the right half's: one short splinter


def paint_b2(can):
    """THE SILL ROT (round 2, redrawn: the crease broke across the grain). The open part is
    the hole H5 (painted with the other holes); here only the row-200 board over it, snapped
    in the middle: its halves tipped into the gap (left x0.88 then x0.75 toward the break,
    right x0.82 then lit x1.1 at its far end), a 2-px dark wedge, splinters at both ends."""
    y = 200
    x0, x1, brk = 84, 100, 91
    for x in range(x0, x1):
        for r_ in range(4):
            c = floor_c(x, y + r_)
            if r_ == 0:                                     # its seam, opened a little
                can.put(x, y, mul(c, 0.7) if brk - 1 <= x <= brk + 2 else c)
                continue
            if x < brk:
                c = mul(c, 0.88 if x < brk - 3 else 0.75)
            elif x > brk + 1:
                c = mul(c, 0.82 if x < x1 - 4 else 1.1)
            else:
                c = HOLE[0] if not (x == brk + 1 and r_ == 3) else HOLE[1]
            can.put(x, y + r_, c)
    can.put(brk - 1, y + 1, FRESH[4])
    can.put(brk - 1, y + 2, FRESH[3])
    can.put(brk + 2, y + 1, FRESH[4])
    for r_ in (1, 2, 3):                                    # the ends it pulled away from
        can.put(x0, y + r_, mul(floor_c(x0, y + r_), 0.62))
        can.put(x1 - 1, y + r_, mul(floor_c(x1 - 1, y + r_), 0.62))


B3_LIFT = {8: 1, 9: 1, 10: 2, 11: 3, 12: 4, 13: 4, 14: 3, 15: 2, 16: 2, 17: 1, 18: 1}
B3_TONE = {"far": 0.9, "ridge": 1.1, "near": 1.0}
B3_FACE = {1: (WOOD_FACE,), 2: (WOOD_FACE, WOOD_DEEP), 3: (WOOD_FACE_HI, WOOD_FACE, WOOD_DEEP),
           4: (WOOD_FACE_HI, WOOD_FACE, WOOD_FACE, WOOD_DEEP)}


def paint_b3(can):
    """THE TENTED BOARDS (round 3): swelled up off their joists in a hump along the gable
    wall, each board the floor's own (damp) wood lifted whole, 1 px on the outer rows to 4 on
    the ridge (rows 48..55). Laid column by column, far boards first, as the hump stands:
      * a board rising over the one above leaves a 2-px crevice on its top edge (HOLE[1]
        over HOLE[2]): the far slope's boards crowd and lose rows to it;
      * a board standing higher than the one below shows its face under itself, turned
        down (WOOD_FACE_HI / WOOD_FACE / WOOD_DEEP, as tall as the drop), then a 1-px HOLE[0]
        crevice; where the board below is the flat floor, a row of shadow on it (x0.75);
      * every lifted board's top row lit a step (x1.14), its body at its slope's tone (far
        x0.9, ridge x1.1, near x1.0): the ridge is the lightest thing in the hump;
      * moss only in the crevices; no INK anywhere (boards are not objects);
      * a run's end: the lifted board stops, its shadow a column on the flat board right of
        it (x0.75), a pale splinter where it snapped off the rest of its board."""
    R = _runs("b3")
    snap = can.rgb.copy()

    def lift(k, x):
        if k not in R or not (R[k][0] <= x < R[k][1]):
            return 0
        return B3_LIFT.get(k, 1)

    def base_c(x, y):
        return tuple(int(v) for v in snap[y, x])

    ks = sorted(R)
    for x in range(X0, max(r[1] for r in R.values()) + 2):
        for k in range(ks[0], ks[-1] + 2):
            L, Lp, Ln = lift(k, x), lift(k - 1, x), lift(k + 1, x)
            if not L:
                continue
            y = 4 * k
            slope = "far" if k < 12 else "ridge" if k <= 13 else "near"
            tone = B3_TONE[slope]
            mossy = hsh(x // 3, k, 46) < 0.35
            if L > Lp:                               # rising over the board above
                can.put(x, y - L - 1, HOLE[1])
                can.put(x, y - L, (MOSS[1] if x % 3 else MOSS[2]) if mossy else HOLE[2])
            else:                                    # under the face of the one above
                can.put(x, y - L, (MOSS[0] if x % 2 else MOSS[1]) if mossy else HOLE[0])
            for r_ in (1, 2, 3):
                c = mul(base_c(x, y + r_), tone)
                if r_ == 1:
                    c = mul(base_c(x, y + r_), tone * 1.14)
                can.put(x, y + r_ - L, c)
            n = L - Ln
            if n > 0:
                for i, c in enumerate(B3_FACE[min(4, n)]):
                    can.put(x, y + 4 - L + i, c)
                if Ln == 0:                          # meeting the flat floor
                    can.put(x, y + 4, HOLE[0])
                    can.put(x, y + 5, mul(base_c(x, y + 5), 0.75))
    for k in ks:                                     # each run's end
        x0, x1, hh = R[k]
        y = 4 * k
        L = lift(k, x1 - 1)
        for r_ in (1, 2, 3):
            if not lift(k, x1):
                can.put(x1, y + r_, mul(base_c(x1, y + r_), 0.75))
        if not is_jt(x1, k):
            can.put(x1, y + 2 - L, PALE_UNDER)       # where it snapped off the rest
            can.put(x1, y + 3 - L, mul(base_c(x1, y + 3), 0.75))


def relay_dish(R: Relay, hole):
    """THE STOVE'S DISH: the boards round h4 sag a pixel toward it (its weight bent them);
    the far rim tilts toward us (a step lighter), the near rim away (a step darker)."""
    D = _dist_field(hole.m, 4)
    cy = (hole.bbox[1] + hole.bbox[3]) / 2
    for k in range(18, 30):
        for x in range(200, 284):
            if hole.m[4 * k + 2, x]:
                continue
            d = min(D[4 * k + r, x] for r in (1, 2, 3))
            if d > 3:
                continue
            R.off[(k, x)] = 1 if d <= 2 else 0
            far = 4 * k < cy
            R.look[(k, x)] = (lambda r, c, far=far, d=d: c if r == 0 else
                              (lt(c, 1) if far else dk(c, 2 if d <= 1 else 1)))


def _dist_field(m, reach):
    """Steps of 1 px (4-neighbour) from a mask, up to `reach`; 99 beyond."""
    d = np.full(m.shape, 99, np.int32)
    d[m] = 0
    cur = m.copy()
    for k in range(1, reach + 1):
        nb = cur.copy()
        nb[1:, :] |= cur[:-1, :]
        nb[:-1, :] |= cur[1:, :]
        nb[:, 1:] |= cur[:, :-1]
        nb[:, :-1] |= cur[:, 1:]
        d[nb & (d == 99)] = k
        cur = nb
    return d


# ------------------------------------------------------------------ board surface: grime, stains

def grime(can: Can, level: float, seed: int):
    """Board by board, so a stain stops at the board's joint and seam as it does in wood."""
    for k in range(2, 54):
        for m in range(-1, 22):
            a = jx(k) + 16 * m
            bx0, bx1 = max(X0, a + 1), min(X1, a + 16)
            if bx1 <= bx0:
                continue
            cx, cy = (bx0 + bx1) / 2, 4 * k + 2
            n = vnoise(cx, cy, 40, seed) * 0.6 + hsh(k, m, seed) * 0.4
            shade_side = clampi((cx - 150) / 180, 0, 1)
            wall = max(0, 1 - min(cx - X0, X1 - cx, cy - Y0, Y1 - cy) / 26)
            g = n * 0.75 + shade_side * 0.35 + wall * 0.35
            lvl = 2 if g > 1.08 * level else 1 if g > 0.9 * level else 0
            if lvl == 0:
                continue
            fn = (lambda c, lvl=lvl: wt(c, lvl)) if hsh(k, m, 7) < 0.5 else (lambda c, lvl=lvl: dk(c, lvl))
            for y in range(4 * k + 1, 4 * k + 4):
                if Y0 <= y < Y1:
                    for x in range(bx0, bx1):
                        can.tint(x, y, fn)
            if hsh(k, m, seed + 3) < 0.22:              # a scuff along the grain
                sx = bx0 + 2 + int(hsh(k, m, 9) * max(1, bx1 - bx0 - 7))
                sy = 4 * k + 1 + int(hsh(k, m, 10) * 3)
                for i in range(2 + int(hsh(k, m, 11) * 3)):
                    can.tint(sx + i, sy, lambda c: dk(c, 1))


def grain_noise(x, y, seed):
    """Noise stretched along the planks: a wood stain spreads along the grain."""
    return vnoise(x / 3.2, y, 4, seed) * 0.7 + vnoise(x / 2, y, 2, seed + 1) * 0.3


def stain_field(can, box, field, levels, fn, seed=0):
    """Tint every pixel of box whose field value passes a level: hard steps, grain-wise."""
    x0, y0, w, hh = box
    for y in range(y0, y0 + hh):
        for x in range(x0, x0 + w):
            v = field(x, y) + (grain_noise(x, y, seed) - 0.5) * 0.45
            n = sum(1 for l in levels if v > l)
            if n:
                can.tint(x, y, lambda c, n=n: fn(c, n))


def tide_line(can, cx, cy, rx, ry, a0, a1, seed, fn, wob=1.5, grain=False):
    """A 1-px stepped arc: the edge of an old flood. `grain` (round 2): the water's line
    follows the wood, so on each plank it is a short dash along the board's last row where
    the arc crosses it, not a diagonal hairline across the planks."""
    if grain:
        hit = {}
        steps = int(max(rx, ry) * abs(a1 - a0) * 2) + 8
        for i in range(steps + 1):
            a = a0 + (a1 - a0) * i / steps
            r = 1 + (vnoise(a * 20, 0, 3, seed) - 0.5) * wob / max(rx, ry) * 2
            x, y = int(round(cx + math.cos(a) * rx * r)), int(round(cy + math.sin(a) * ry * r))
            hit.setdefault(y // 4, []).append(x)
        for k, xs in hit.items():
            xm = sum(xs) // len(xs)
            n = max(3, min(7, max(xs) - min(xs) + 2))
            for x in range(xm - n // 2, xm - n // 2 + n):
                if not is_jt(x, k):
                    can.tint(x, 4 * k + 3, fn)
        return
    pts = set()
    steps = int(max(rx, ry) * abs(a1 - a0) * 2) + 8
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        r = 1 + (vnoise(a * 20, 0, 3, seed) - 0.5) * wob / max(rx, ry) * 2
        pts.add((int(round(cx + math.cos(a) * rx * r)), int(round(cy + math.sin(a) * ry * r))))
    for x, y in pts:
        can.tint(x, y, fn)


def split_line(can, x0, x1, y, seed, step=True, lip=True):
    """One split along the grain of the plank whose seam is at y, from x0 to x1 (both inside
    ONE board): a line in the tile's own seam colour on the board's middle row, at most one
    1-px step to the row above or below, and a 1-px lit lip (x1.12) on the row above it."""
    r = random.Random(seed)
    n = x1 - x0
    row = y + 2
    jat = x0 + r.randint(2, max(2, n - 2)) if (step and n >= 5) else x1 + 1
    jd = r.choice((-1, 1))
    for x in range(x0, x1):
        rr = row + (jd if x >= jat else 0)
        can.put(x, rr, floor_c(x, y))
        if lip and rr - 1 > y and r.random() < 0.7:
            can.put(x, rr - 1, mul(floor_c(x, rr - 1), 1.12))


def crack(can, x0, y, length, seed, grey=False):
    """Round 2: cracks run ALONG the grain inside one board, never across a joint. The rect's
    plank row is cut into its boards and one or two of them get a split of 3-8 px that
    starts and ends at least 1 px clear of the board's joints. `grey`: those boards greyed
    a step (old, dried wood)."""
    k = y // 4
    r = random.Random(seed)
    boards = []
    for m in range(-1, 22):
        a = jx(k) + 16 * m
        bx0, bx1 = max(x0, a + 1), min(x0 + length, a + 16)
        if bx1 - bx0 >= 5:
            boards.append((bx0, bx1))
    r.shuffle(boards)
    for i, (bx0, bx1) in enumerate(boards[:2 if len(boards) > 1 else 1]):
        if grey:
            for yy in (y + 1, y + 2, y + 3):
                for x in range(bx0, bx1):
                    can.tint(x, yy, lambda c: wt(c, 2))
        n = min(8, max(3, bx1 - bx0 - 3 - r.randint(0, 3)))
        sx = bx0 + 1 + r.randint(0, max(0, bx1 - bx0 - 2 - n))
        split_line(can, sx, sx + n, y, seed * 7 + i)


def dent(can, x, y, faint=False):
    """A cast foot's dent: a small dish, dark on its top, lit on its lower lip, rust in it."""
    n = 1 if faint else 2
    for dx in (-1, 0, 1):
        can.tint(x + dx, y - 1, lambda c: dk(c, n))
    can.tint(x - 2, y, lambda c: dk(c, 1))
    can.tint(x - 1, y, lambda c: dk(c, n))
    can.tint(x, y, lambda c: mix(dk(c, 1), RUST, 0.3 if faint else 0.55))
    can.tint(x + 1, y, lambda c: dk(c, 1))
    if not faint:
        for dx in (-1, 0, 1):
            can.tint(x + dx, y + 1, lambda c: lt(c, 1))


# ------------------------------------------------------------------ holes

class Hole:
    """One hole: its runs, what is under it, and how its rims are cut."""

    def __init__(self, runs, earth, band, seed, sawn=False, lit=False, shade_len=1, lit_cap=4,
                 flat=False, lift=0, old=False, lit_most=1):
        self.runs = runs
        self.m = mask_of(runs)
        self.earth = earth
        self.band = band
        self.seed = seed
        self.sawn = sawn
        self.lit = lit
        self.shade_len = shade_len
        self.lit_cap = lit_cap
        self.flat = flat
        self.lift = lift            # whole earth steps up (h3 under the veil)
        self.old = old              # years-old ends: splinters weathered grey-brown
        self.lit_most = lit_most    # how many steps the beam may lift the earth
        self.base_e = 2             # the flat base step (round 2)
        self.steps = None           # round 3: (far band, upper, middle, near strip) indices
        self.band_in_beam = None    # round 3: the far band's colour where the beam falls
        self.face = np.zeros((FH, FW), bool)
        self.depth = np.full((FH, FW), -1, np.int32)
        for x in range(FW):
            d = None
            for y in range(FH):
                if self.m[y, x]:
                    if d is None:
                        d = 0
                        if y % 4 == 0 and y - 1 >= Y0 and not self.m[y - 1, x]:
                            self.face[y, x] = True
                            continue
                    self.depth[y, x] = d
                    d += 1
                else:
                    d = None
        self.interior = self.m & ~self.face
        ys, xs = np.nonzero(self.m)
        self.bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        # the light: how far each pixel is behind the board end on its left (same row)
        self.behind = np.full((FH, FW), 99, np.int32)
        for y in range(FH):
            run = 99
            for x in range(FW):
                if self.m[y, x]:
                    run = run + 1 if run < 99 else 99
                    self.behind[y, x] = run
                else:
                    run = 0
        # and how far above the near rim (the last rows before the near board are in shade)
        self.above_near = np.full((FH, FW), 99, np.int32)
        for x in range(FW):
            run = 99
            for y in range(FH - 1, -1, -1):
                if self.m[y, x]:
                    run = run + 1 if run < 99 else 99
                    self.above_near[y, x] = run
                else:
                    run = 0 if Y0 <= y < Y1 else 99

    def inside(self, x, y):
        return 0 <= x < FW and 0 <= y < FH and bool(self.m[y, x])

    def earth_ok(self, x, y, margin=0):
        if not (0 <= x < FW and 0 <= y < FH) or not self.interior[y, x]:
            return False
        return self.depth[y, x] >= self.band_at(x) + margin

    def band_at(self, x):
        return self.band

    def earth_idx(self, x, y):
        """Round 2: a FLAT base step, not noise. Only large, hard-edged regions change it:
        the beam's patch (one step up), the column against a wall and the last row before
        the near lip (one step down). Texture is clods and pebbles, laid on top."""
        if self.steps is not None:              # round 3: three hard steps, far to near
            d = self.depth[y, x]
            _, up, mid, near = self.steps
            e = near if self.above_near[y, x] <= 3 else up if d < self.band + 3 else mid
            if self.lit and BEAM[y, x] > 0.42:
                e += self.lit_most
            return clampi(e, 0, len(self.earth) - 1)
        e = self.base_e + self.lift
        if self.lit:
            b = BEAM[y, x]
            e += min(self.lit_most, 1 if b > 0.42 else 0)
            e = min(e, self.lit_cap)
        if x - 1 < X0 or x + 1 >= X1:              # the walls go on down into the dark
            e -= 1
        if self.above_near[y, x] == 1:              # the last row before the near lip
            e -= 1
        return clampi(e, 0, len(self.earth) - 1)

    def paint(self, can: Can):
        """The far rim's cut (one row of the board's edge face), then the shadow INSIDE the
        hole: `band` rows of HOLE[1] under it, then the earth in one hard step. Down the
        side rims a 1-px HOLE[0] contact line where the earth meets the board end. Nothing
        is darkened outside the cut but the near rim's 1-px lip."""
        E = self.earth
        for y in range(FH):
            for x in range(FW):
                if not self.m[y, x]:
                    continue
                if self.face[y, x]:                 # the far rim's cut, an INK edge
                    c = FRESH[1] if self.sawn else INK
                    can.put(x, y, c)
                    continue
                d = self.depth[y, x]
                if d < self.band:
                    c = HOLE[1] if self.steps is None else HOLE[self.steps[0]]
                    if self.band_in_beam is not None:
                        c = self.band_in_beam[min(d, len(self.band_in_beam) - 1)]
                        if self.lit and BEAM[y, x] > 0.42:
                            c = HOLE[max(0, HOLE.index(c) - 1)]
                else:
                    side = (not self.m[y, x - 1]) or (x + 1 < FW and not self.m[y, x + 1])
                    side = side and X0 <= x - 1 and x + 1 < X1
                    c = HOLE[0] if side else E[self.earth_idx(x, y)]
                can.put(x, y, c)
        for x in range(FW):                       # the near rim's lip
            for y in range(FH - 1):
                if self.m[y, x] and not self.m[y + 1, x] and y + 1 < Y1:
                    can.put(x, y + 1, FRESH[1] if self.sawn else EDGE_LIP)

    def texture(self, can: Can, clods=1.0, pebbles=1.0, roots=2, crumbs=1.0, sheen=0):
        """Round 2: on the flat base, CLODS (2x1 to 3x2: a body one step up, one lit pixel on
        its top, one shade pixel under it) and PEBBLES (2x1 stone, an INK pixel under). They
        keep 2 px apart; no lone mid-tone pixels. Roots hang off the far wall."""
        r = random.Random(self.seed * 31 + 7)
        E = self.earth
        x0, y0, x1, y1 = self.bbox
        area = int(self.interior.sum())
        taken = np.zeros((FH, FW), bool)

        def free(pts):
            for x, y in pts:
                if not self.earth_ok(x, y, 0):
                    return False
                if taken[max(0, y - 2):y + 3, max(0, x - 2):x + 3].any():
                    return False
                if self.above_near[y, x] <= 1 or self.depth[y, x] < self.band + 1:
                    return False
                if not (self.m[y, x - 1] and self.m[y, x + 1]):
                    return False
            return True

        tries = int(area / 22 * clods) + 2
        for _ in range(tries * 3):
            if tries <= 0:
                break
            x, y = r.randint(x0, x1), r.randint(y0, y1)
            w, hh = r.choice(((3, 1), (2, 2), (3, 2), (3, 2), (4, 2)))
            body = [(x + i, y + j) for i in range(w) for j in range(hh)]
            under = [(x + i, y + hh) for i in range(1, w)]
            if not free(body + under):
                continue
            tries -= 1
            e = self.earth_idx(x, y)
            for bx, by in body:
                can.put(bx, by, E[clampi(e + 1, 0, len(E) - 1)])
            can.put(x, y, E[clampi(e + 2, 0, len(E) - 1)])                 # lit top-left
            if w >= 3:
                can.put(x + 1, y, E[clampi(e + 2, 0, len(E) - 1)])
            for ux, uy in under:                                            # its shade
                can.put(ux, uy, E[clampi(e - 1, 0, len(E) - 1)] if e > 0 else HOLE[0])
            for bx, by in body + under:
                taken[by, bx] = True
        n_peb = int(area / 140 * pebbles) + (1 if pebbles > 0 else 0)
        for _ in range(n_peb * 4):
            if n_peb <= 0:
                break
            x, y = r.randint(x0, x1), r.randint(y0, y1)
            pts = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            if not free(pts):
                continue
            n_peb -= 1
            lit = 1 if (self.lit and BEAM[y, x] > 0.42) else 0
            can.put(x, y, STONE[2 + lit])
            can.put(x + 1, y, STONE[1 + lit])
            can.put(x, y + 1, INK)
            can.put(x + 1, y + 1, INK)
            for px, py in pts:
                taken[py, px] = True
        tops = [(x, y) for y in range(1, FH) for x in range(FW)
                if self.interior[y, x] and self.depth[y, x] == 0 and self.face[y - 1, x]
                and self.m[y, x - 1] and self.m[y, x + 1]]
        r.shuffle(tops)
        used = []
        for x, y in tops:
            if len(used) >= roots:
                break
            if any(abs(x - u) < 5 for u in used):
                continue
            used.append(x)
            n = r.randint(3, 5)
            for i in range(n):
                yy = y + i
                if not self.interior[yy, x]:
                    break
                can.put(x, yy, ROOT[0] if i < self.band else ROOT[1] if i < n - 1 else ROOT[0])

    def ragged(self, can: Can, n):
        """Break the near rim: `n` snapped teeth of the near board standing up into the hole
        (2-3 px wide, 1-2 tall): the tile's own wood, its top lit x1.12 (old ends a third
        weathered toward DEAD), an INK pixel on each face that drops into the hole."""
        r = random.Random(self.seed * 77)
        lips = [(x, y) for y in range(FH - 1) for x in range(FW)
                if self.m[y, x] and not self.m[y + 1, x] and y + 1 < Y1 and self.interior[y, x]
                and self.m[y, x - 1] and self.m[y, x + 1]]
        r.shuffle(lips)
        used = []
        for x, y in lips:
            if len(used) >= n:
                break
            if any(abs(x - u) < 6 for u in used):
                continue
            if not all(self.interior[y, x + i] for i in range(-1, 4)):
                continue
            used.append(x)
            w = r.choice((2, 2, 3))
            for i in range(w):
                hgt = 2 if (i == w // 2 and r.random() < 0.6) else 1
                for j in range(hgt):
                    c = floor_c(x + i, y + 2)
                    c = mul(c, 1.12) if j == hgt - 1 else c
                    if self.old:
                        c = mix(c, DEAD[2], 0.3)
                    can.put(x + i, y - j, c)
                if self.interior[y - hgt, x + i]:
                    can.put(x + i, y - hgt, INK)
            for xx in (x - 1, x + w):
                if self.interior[y, xx]:
                    can.put(xx, y, INK)

    def ends(self, can: Can):
        """Board ends at the hole (round 2). Sawn (stage-2 cores): square, pale end grain.
        Otherwise every end is snapped: the board's rows staggered 0-2 px into the hole in a
        2-3 tooth profile seeded per board, each row's last pixel its END GRAIN (the tile's
        wood x1.12, a third toward DEAD on the old holes), a 1-px INK edge on the face that
        drops into the hole, and on about half the ends one tooth (a different one each
        time) pale: FRESH[4] in the sun hole, DEAD[3] on the old ones. An end on a butt joint
        keeps its rows level (the board came out whole) but still shows grain and ink."""
        for y, x0, x1, hh in self.runs:
            k = y // 4
            rows = [y + i for i in range(hh) if (y + i) % 4 != 0]
            for side, xe in ((-1, x0), (1, x1)):
                bx = xe - 1 if side < 0 else xe
                if not (X0 <= bx < X1) or any(self.inside(bx, rr) for rr in rows):
                    continue
                if self.sawn:                       # square, pale end grain, inked
                    for rr in rows:
                        can.put(bx, rr, FRESH[4] if rr % 4 != 3 else FRESH[3])
                        ix = bx - side
                        if self.inside(ix, rr) and self.interior[rr, ix]:
                            can.put(ix, rr, INK)
                    continue
                r = random.Random(self.seed * 1000 + y * 7 + xe)
                joint = is_jt(xe, k) or is_jt(bx, k)
                old = self.old
                if joint:                           # the board came out whole at its joint:
                    for j, rr in enumerate(rows):   # a column of end grain, a nail hole
                        can.put(bx, rr, base.RAFTER[1] if j < len(rows) - 1 else base.RAFTER[0])
                        ix = bx - side
                        if self.inside(ix, rr) and self.interior[rr, ix]:
                            can.put(ix, rr, INK)
                    can.put(bx + side, rows[len(rows) // 2], HOLE[0])
                    continue
                # snapped (round 3): the plank's wood carried 0-3 px further than its
                # neighbours (so the rim does not step by the same amount row after row),
                # its rows staggered, the longest a tapering tongue: WOOD_FACE body, a
                # pale tip (FRESH[4] in the sun hole, PALE_UNDER weathered on the old
                # ones), a 1-px shade under it
                carry = r.choice((0, 1, 1, 2, 3))
                pat = r.choice(((0, 1, 3), (1, 3, 0), (3, 1, 0), (0, 3, 1), (1, 0, 3), (2, 0, 3)))
                lens = [carry + t for t in pat][:len(rows)] if len(rows) == 3 else \
                    [carry + r.choice((1, 3)), carry][:len(rows)]
                tongue = lens.index(max(lens))
                tip_c = mix(PALE_UNDER, DEAD[2], 0.35) if old else (FRESH[4] if r.random() < 0.6 else FRESH[5])
                for j, (rr, n) in enumerate(zip(rows, lens)):
                    got = 0
                    for i in range(1, n + 1):
                        sx = bx - side * i
                        if not self.inside(sx, rr):
                            break
                        got = i
                    n = got
                    for i in range(1, n + 1):
                        sx = bx - side * i
                        wc = floor_c(bx, rr)
                        if old:
                            wc = mix(wc, DEAD[1], 0.2)
                        if j == tongue and i >= n - 1 and n >= 2:
                            wc = tip_c if i == n else WOOD_FACE
                        can.put(sx, rr, wc)
                    ex = bx - side * n
                    if not (j == tongue and n >= 2):
                        g = mul(floor_c(bx, rr), 1.12)
                        if old:
                            g = mix(g, DEAD[2], 0.33)
                        can.put(ex, rr, g)
                    ix = ex - side
                    if self.inside(ix, rr) and self.interior[rr, ix]:
                        can.put(ix, rr, INK if not (j == tongue and n >= 2) else HOLE[0])
                    if j == tongue and n >= 2:      # the shade under the tongue
                        below = rr + 1
                        nb = lens[j + 1] if j + 1 < len(lens) else 0
                        for i in range(nb + 1, n + 1):
                            sx = bx - side * i
                            if self.inside(sx, below) and self.interior[below, sx]:
                                can.put(sx, below, HOLE[0])


def joist(can, hole: Hole, x0, w, kind="old", end=None, seed=1, shade=1):
    """A joist crossing a hole front to back (round 2: timber, not a wire): 3 px of the
    RAFTER ramp, its window-side column lit, INK down both sides where it meets the earth,
    in the far rim's shadow for its first rows. `char` (h4): burnt black-brown (HOLE[2]
    body, RAFTER[0] lit column, a char crack every few rows), no grey."""
    r = random.Random(seed)
    for y in range(FH):
        if end is not None and y > end:
            break
        for i in range(w):
            x = x0 + i
            if not hole.interior[y, x]:
                continue
            d = hole.depth[y, x]
            if kind == "char":
                c = base.RAFTER[0] if i == 0 else HOLE[2] if i < w - 1 else HOLE[1]
                if (y + seed) % 6 == 0 and i > 0:
                    c = HOLE[0]                      # a char check across the grain
            else:
                c = JOIST[3] if i == 0 else JOIST[2] if i < w - 1 else JOIST[1]
                if i == 1 and (y + seed) % 7 in (0, 1):
                    c = JOIST[1]                     # the grain
            if d < hole.band:                        # under the far rim's shadow
                c = mul(c, 0.55)
            can.put(x, y, c)
        for xs in (x0 - 1, x0 + w):                  # ink down both its sides
            if 0 <= xs < FW and hole.interior[y, xs] and hole.depth[y, xs] >= hole.band:
                can.put(xs, y, INK)
        for s in range(1, shade):
            xs = x0 + w + s
            if xs < FW and hole.interior[y, xs] and hole.depth[y, xs] >= hole.band:
                can.put(xs, y, HOLE[1])
    if end is not None:                           # its broken end, facing us
        for i in range(w):
            x = x0 + i
            e = end + (1 if r.random() < 0.5 else 0) - (i == w - 1)
            can.put(x, e, (150, 116, 80) if i < w - 1 else (112, 84, 58))
            can.put(x, e + 1, (124, 92, 62) if i == 0 else JOIST[1])
            if i in (0, 2):
                can.put(x, e + 2, (168, 136, 96))      # splinters pointing at the sill
            for yy in range(e + 2 + (i in (0, 2)), e + 5):
                if yy < FH and hole.interior[yy, x]:
                    can.put(x, yy, HOLE[1])


# ------------------------------------------------------------------ the holes

H1 = Hole(runs_of(FEAT["h1"]["block"]), DRY, 2, seed=11, lit=True, shade_len=3, lit_cap=3,
          lit_most=0, lift=-1)
H1.band_in_beam = (HOLE[1], HOLE[2])
H2 = Hole(runs_of(FEAT["h2"]["block"]), WETE, 2, seed=22, old=True)
H2.steps = (0, 2, 3, 4)
H3 = Hole(runs_of(FEAT["h3"]["block"]), WETE, 2, seed=33, lift=1, old=True)
H3.steps = (0, 3, 4, 5)
H4 = Hole(runs_of(FEAT["h4"]["block"]), ASHMUD, 2, seed=44, old=True)
# b2, the sill rot: the hole under the snapped row-200 board (its rows 204..213)
H5 = Hole([r for r in runs_of(FEAT["b2"]["block"]) if r[0] >= 204], DAMP, 2, seed=55, old=True)
H1C = Hole(runs_of(FEAT["h1"]["block_s2"]), DAMP, 2, seed=11, lit=True, sawn=True, shade_len=3,
           lit_cap=3, lit_most=1, lift=-1)
H1C.band_in_beam = (HOLE[1], HOLE[2])
H2C = Hole(runs_of(FEAT["h2"]["block_s2"]), WETE, 2, seed=22, sawn=True)


POOL_C = (318, 206)          # h2's standing water, its middle (it runs on into the corner)
POOL_R = (12.5, 6.5)


def _pool_set(hole: Hole, scale=1.0):
    """The pool's pixels: an ellipse whose rim wobbles 1-2 px every 3-4 px of its edge, the
    low right side (toward the corner, where the floor is lowest) reaching furthest. Kept a
    pixel in from the earth's edges so it never takes the hole's own outline; against the
    walls it runs up to them. `scale` shrinks it about the corner (the stage-up's drying)."""
    if scale <= 0:
        return set()
    cx, cy = POOL_C                             # round 3: it dries about its own middle
    rx, ry = POOL_R[0] * scale, POOL_R[1] * scale
    out = set()
    for y in range(int(cy - ry - 3), min(Y1, int(cy + ry + 4))):
        for x in range(int(cx - rx - 3), min(X1, int(cx + rx + 4))):
            near_wall = x >= X1 - 2 or y >= Y1 - 2
            if not hole.earth_ok(x, y, 0 if near_wall else 1):
                continue
            th = math.atan2((y - cy) / ry, (x - cx) / rx)
            R = rx * ry / math.hypot(ry * math.cos(th), rx * math.sin(th))   # the ellipse, px
            arc = th * (rx + ry) / 2                    # px along the edge
            wob = (vnoise(arc / 3.5 + 7, 0, 1.0, 909) - 0.5) * 2 * 2.0       # +-2 px / 3-4 px
            low_right = max(0.0, math.cos(th - 0.6)) * 2.5 * scale
            if math.hypot(x - cx, y - cy) < R + wob + low_right:
                out.add((x, y))
    return out


def slits():
    """lt1: daylight through one gap high in the far gable's corner, falling as a single
    streak across h2's earth and stopping at the pool's edge: the line points of its left
    core column (the core is 2 px wide). (Two parallel streaks read as a ladder.)"""
    out = []
    pool = _pool_set(H2)
    for (xa, ya, xb, yb) in ((329, 158, 309, 206),):
        n = max(abs(xb - xa), abs(yb - ya))
        for i in range(n + 1):
            x, y = int(round(xa + (xb - xa) * i / n)), int(round(ya + (yb - ya) * i / n))
            if (x, y) in pool or (x + 1, y) in pool:
                break
            out.append((x, y))
    return out


# Dropped after round 1 (two critics): on dark earth, drawn either as a flat tan line or as
# lit earth, the streak read as a stick or a ladder lying in the hole, never as light, and
# the weeds rooted along it made it a branch. The corner keeps its pool, weeds and dark.
# (life.py reads SLITS for its veil gaps and slit motes; empty, it draws neither.)
LT1 = False
SLITS = slits() if LT1 else []


def _slit_light():
    """{(x, y): k} the beams' light: the 2-px core at .65 of LIGHT, a .3 margin each side."""
    lit = {}
    for x, y in SLITS:
        for dx, k in ((0, 0.65), (1, 0.65), (-1, 0.3), (2, 0.3)):
            lit[(x + dx, y)] = max(lit.get((x + dx, y), 0), k)
    return lit


SLIT_LIGHT = _slit_light()


def paint_pool(can, hole: Hole, stage, scale=1.0):
    """Stage 1: standing water in the low corner, an organic edge, a 1-px rim of wet mud
    (WETE[1]) round it, its body deep (WATER[0], the first rows under its far edge WATER[1]),
    2-3 short reflection dashes (WATER[2]) on the first inner rows, and one lit ripple where
    the daylight beam reaches it. Stage 2 (roof mended): only wet mud in the corner and a
    3-px sheen; no open water."""
    if stage != 1:
        cx, cy = 322, 209
        for y in range(cy - 4, Y1):
            for x in range(cx - 8, X1):
                if hole.earth_ok(x, y) and math.hypot((x - cx) / 8.0, (y - cy) / 4.0)                         + (vnoise(x, y, 3, 909) - 0.5) * 0.5 < 1:
                    can.put(x, y, WETE[0])
        for x in (321, 322, 323):
            if hole.earth_ok(x, 208):
                can.put(x, 208, mix(WETE[2], WATER[1], 0.5))
        return set()
    ps = _pool_set(hole, scale)
    if not ps:
        return ps
    for x, y in ps:
        c = WATER[0]
        if (x, y - 1) not in ps:
            c = WATER[1]                          # under its far edge: the room's light
        can.put(x, y, c)
    # reflections: short dashes on the first inner rows
    rows = {}
    for x, y in ps:
        rows.setdefault(y, []).append(x)
    ys = sorted(rows)
    for (yy, x0, n) in ((1, 3, 3), (2, 8, 2), (3, 2, 2)):
        if yy < len(ys):
            row = sorted(rows[ys[yy]])
            if len(row) > x0 + n:
                for i in range(n):
                    can.put(row[x0 + i], ys[yy], WATER[2])
    # one lit ripple: where the beam reaches the water, or under its far edge
    if scale >= 0.99:
        ex, ey = _beam_end(0) if SLITS else (312, 200)
        for dx, c in ((-1, WATER[3]), (0, WATER[4]), (1, WATER[4]), (2, WATER[3])):
            if (ex + dx, ey + 1) in ps:
                can.put(ex + dx, ey + 1, c)
        for dx in (-2, 3):
            if (ex + dx, ey + 2) in ps:
                can.put(ex + dx, ey + 2, WATER[2])
    for x, y in ps:                                # the mud rim, one pixel
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            q = (x + dx, y + dy)
            if q not in ps and hole.earth_ok(*q):
                can.put(*q, WETE[1])
    return ps


def lit_by(c, k):
    """Light falling on a colour: it multiplies what is there (so the earth's own clods and
    crumbs still show through it) and warms it a touch; never a flat colour laid over."""
    g = 1 + 1.9 * k
    return mix(tuple(min(255, int(v * g)) for v in c[:3]), LIGHT, 0.12 * k)


def _beam_end(i):
    """The last point of beam i (0 A, 1 B) before the water."""
    runs, run = [], []
    for pt in SLITS:
        if run and max(abs(pt[0] - run[-1][0]), abs(pt[1] - run[-1][1])) > 2:
            runs.append(run)
            run = []
        run.append(pt)
    runs.append(run)
    return runs[min(i, len(runs) - 1)][-1]


def paint_h2_extras(can, hole: Hole, stage, pool=1.0):
    paint_pool(can, hole, stage, pool)
    if stage != 1:
        return
    # the fallen board, lying tilted on the earth (an object: ringed in INK)
    x0, y0 = 293, 184
    for i in range(13):
        bx, by = x0 + i, y0 + (i * 3) // 13
        for j, c in enumerate((INK, (118, 76, 54), (100, 64, 46), (74, 46, 34), INK)):
            can.put(bx, by + j - 1, c)
        if i % 5 == 2:
            can.put(bx, by + 1, (88, 56, 40))      # grain
        if hole.earth_ok(bx + 1, by + 4):
            can.put(bx + 1, by + 4, HOLE[0])
    for j in range(5):
        can.put(x0 - 1, y0 + j - 1, INK)
        can.put(x0 + 13, y0 + 2 + j - 1, INK)
    can.put(x0, y0, (150, 104, 74))                # its lit end
    can.put(x0 + 12, y0 + 2, DEAD[2])              # its snapped end, weathered
    can.put(x0 + 12, y0 + 3, mix(DEAD[1], WOOD_FACE, 0.4))
    # the daylight: two beams from one gap, the 2-px core bright, a soft margin, lighting
    # the earth and the board ends they cross (and nothing dark beside them)
    for (xx, y), k in SLIT_LIGHT.items():
        if not (X0 <= xx < X1 and Y0 <= y < Y1):
            continue
        can.put(xx, y, lit_by(can.get(xx, y), k))


def paint_h3_moss(can, hole: Hole):
    """Moss on the soft board ends round the roof corner: cushions on the rim boards next to
    the hole (top lit MOSS[3], body MOSS[2], under-edge MOSS[1])."""
    D = _dist_field(hole.m, 3)
    for y in range(Y0, 72):
        for x in range(228, X1):
            if hole.m[y, x] or D[y, x] > 2:
                continue
            v = vnoise(x, y, 4, 77) + (0.15 if D[y, x] == 1 else 0)
            if v > 0.6:
                up = not (D[y - 1, x] <= 2 and vnoise(x, y - 1, 4, 77) + (0.15 if D[y - 1, x] == 1 else 0) > 0.6)
                dn = y + 1 < FH and hole.m[y + 1, x]
                c = MOSS[3] if up else MOSS[1] if dn else MOSS[2]
                can.put(x, y, c)


def moss_joist(can, hole, x0, w):
    for y in range(FH):
        for i in range(w):
            x = x0 + i
            if hole.interior[y, x] and hole.depth[y, x] >= 2:
                v = vnoise(x, y, 4, 70)
                if v > 0.5:                       # MOSS[2..3]: it must survive the veil
                    c = MOSS[3] if i == 0 or v > 0.66 else MOSS[2]
                    can.put(x, y, c)


def paint_ash(can, hole: Hole):
    """h4's ash crust (round 2): a small hard patch just right of the charred joist where the
    flue's drip splashes (238, 96): a wet dark middle (ASHMUD[1]) in a ring of pale ash
    (ASHMUD[4]), no checker, and one cinder. Laid before the joist, which crosses over it."""
    cx, cy = 241, 98
    for y in range(cy - 2, cy + 3):
        for x in range(cx - 4, cx + 5):
            if not hole.earth_ok(x, y, 1):
                continue
            d = math.hypot((x - cx) / 3.6, (y - cy) / 1.7)
            if d < 0.55:
                can.put(x, y, ASHMUD[1])
            elif d < 1.05:
                can.put(x, y, ASHMUD[4])
    x, y = 246, 101
    if hole.earth_ok(x, y, 1) and hole.earth_ok(x + 1, y + 1, 1):
        can.put(x, y, base.RAFTER[0])
        can.put(x + 1, y, HOLE[2])
        can.put(x, y + 1, INK)
        can.put(x + 1, y + 1, INK)


def paint_stove(can, hole: Hole, stage):
    """s3: the rust ring 2-3 px out from the hole where the stove's base sat, the soot fan
    up and right (the draught), and the four dents of its cast feet."""
    D = _dist_field(hole.m, 5)
    faint = stage == 2
    for y in range(66, 124):
        for x in range(196, 290):
            if hole.m[y, x] or not (X0 <= x < X1):
                continue
            d = D[y, x]
            if faint and d in (2, 3):               # stage 2 only (round 2: in stage 1 the
                                                    # ring read as a blur round the cut)
                v = vnoise(x, y, 5, 61)
                if v > (0.3 if not faint else 0.58):
                    k = (0.5 if d == 2 else 0.3) * (0.6 if faint else 1)
                    can.tint(x, y, lambda c, k=k: mix(c, RUST, k))
    if stage == 1:
        x0, y0, x1, y1 = hole.bbox
        ox, oy = (x0 + x1) / 2 + 6, y0 + 6
        for y in range(Y0, y0 + 8):
            for x in range(x0 - 6, min(X1, x1 + 20)):
                if hole.m[y, x] or D[y, x] <= 3:
                    continue
                dx, dy = x - ox, oy - y
                if dy < -3:
                    continue
                ang = math.atan2(dy, dx)
                if not (0.3 < ang < 2.2):
                    continue
                rr = math.hypot(dx, dy * 1.2)
                v = 1 - rr / 20 + (grain_noise(x, y, 64) - 0.5) * 0.5
                lvl = 2 if v > 0.55 else 1 if v > 0.22 else 0
                if lvl:
                    can.tint(x, y, lambda c, lvl=lvl: mix(c, SOOT, 0.12 * lvl))
    feet = [(217, 76), (267, 76), (219, 115), (267, 115)]
    if stage == 2:
        feet = [feet[0], feet[3]]
    for fx, fy in feet:
        dent(can, fx, fy, faint=faint)


# ------------------------------------------------------------------ the surface, stage 1

def stains_s1(can):
    # s1: the window seat, bleached a step lighter (sun and rain), board by board
    for y in range(98, 128):
        for x in range(6, 24):
            if y % 4:
                can.tint(x, y, lambda c: lt(c, 1))
    # s6 (round 3): the gable wall's damp round the tented boards, ONE hard step (wt 1),
    # whole boards: it ends only on seam rows and butt joints. No moss film (moss lives in
    # the hump's crevices).
    for k in range(6, 21):
        for m in range(-1, 6):
            a = jx(k) + 16 * m
            bx0, bx1 = max(X0, a + 1), min(X1, a + 16)
            if bx1 <= bx0:
                continue
            cx, cy = (bx0 + bx1) / 2, 4 * k + 2
            if math.hypot((cx - 6) / 64, (cy - 53) / 30) + (hsh(k, m, 12) - 0.5) * 0.25 > 0.85:
                continue
            for yy in range(4 * k + 1, 4 * k + 4):
                for x in range(bx0, bx1):
                    can.tint(x, yy, lambda c: wt(c, 1))

    # s4: the right wall's wet margin from the roof corner down to the low corner: each
    # board row stops on its own butt joint (or 2-6 px either side of it), so the edge steps
    # board by board, as water creeps along wood; three steps wetter toward the wall
    for k in range(15, 37):
        y = 4 * k
        t = 314 + (vnoise(k, 0, 3, 140) - 0.5) * 8
        js = [jx(k) + 16 * m for m in range(-1, 22)]
        j = min(js, key=lambda v: abs(v - t))
        off = 0 if hsh(k, 1, 141) < 0.4 else int(round((2 + hsh(k, 2, 142) * 4) * (1 if hsh(k, 3, 143) < 0.5 else -1)))
        xe = j + off
        fade = 1 if 17 <= k <= 35 else 0
        for r_ in (1, 2, 3):
            for x in range(xe, X1):
                d = x - xe
                lvl = (1 if d < 5 else 2 if d < 10 else 3) - (1 - fade)
                if lvl > 0:
                    can.tint(x, y + r_, lambda c, lvl=lvl: wt(c, lvl))
    for y in range(64, 148):
        for x in range(320, X1):
            if y % 4 == 0 and x > 324 and grain_noise(x, y, 15) > 0.7:
                can.put(x, y, MOSS[1] if (x + y) % 3 else MOSS[0])

    # s7: the back wall's foot darker toward the roof corner, fading toward the door
    def f7(x, y):
        return (x - 204) / 36 - (y - Y0) / 8
    stain_field(can, (200, Y0, 52, 10), f7, (0.2, 0.6), lambda c, n: wt(c, n), seed=16)
    # s5: old flood tide lines on the open floor, curving round toward the low corner
    for i, (rad, a0, a1) in enumerate(((60, 2.5, 3.6), (70, 2.58, 3.5), (82, 2.72, 3.38))):
        tide_line(can, 300, 214, rad, rad * 0.8, a0, a1, seed=50 + i,
                  fn=lambda c, i=i: dk(c, 2 if i == 0 else 1), grain=True)
    # the worn path, the loose board, the threshold
    worn(can, 1)
    threshold(can)


def worn(can, stage):
    """w1: forty years of boots: down the dish's middle the boards a step paler and the grain
    standing proud (light dashes along the planks); its edges a step darker. l1 in it."""
    x0, y0, w, hh = FEAT["w1"]["rect"]
    cx = x0 + w / 2
    for y in range(y0, y0 + hh):
        if y % 4 == 0:
            continue
        for x in range(x0, x0 + w):
            u = abs(x - cx) / (w / 2)
            fade = 1 - (y - y0) / hh * 0.35
            wear = (1 - u * u) * fade - (0.25 if stage == 2 else 0)
            dash = hsh((x + (y // 4) * 3) // 4, y, 21)
            if wear > 0.5 and dash < 0.6:
                can.tint(x, y, lambda c: lt(c, 1))
            if wear > 0.72 and y % 4 == 2 and dash < 0.35:
                can.tint(x, y, lambda c: lt(c, 2))
            if stage == 1 and 0.86 < u < 1.0 and hsh(x, y, 22) < 0.6:
                can.tint(x, y, lambda c: dk(c, 1))
    # the loose board: nail proud, a dark hairline at its far end
    lx, ly, lw, lh = FEAT["l1"]["rect"]
    for i in range(1, 4):
        can.put(lx + lw - 1, ly + i, dk(can.get(lx + lw - 1, ly + i), 3))
    can.tint(lx + lw - 1, ly + 4, lambda c: dk(c, 2))
    can.put(lx + 3, ly + 1, NAIL_HI)
    can.put(lx + 3, ly + 2, NAIL)
    can.tint(lx + 4, ly + 2, lambda c: dk(c, 2))


def threshold(can):
    """t1: under the door the gap is dark wood (WOOD_DEEP), with daylight showing through it
    in two short slivers; the tufts (plants) stand in it."""
    x0, y0, w, hh = FEAT["t1"]["rect"]
    for x in range(x0 + 1, x0 + w - 1):
        can.put(x, Y0, WOOD_DEEP)
    for x in (163, 164, 174, 175, 176):
        can.put(x, Y0, mix(WOOD_DEEP, LIGHT, 0.55))


def crack_c3(can):
    """c3 (round 2): a split along the grain of one board below the player's puddle p2, and
    a shorter one in the board under it: no diagonal hairlines across the planks."""
    split_line(can, 108, 115, 160, 301)
    split_line(can, 113, 117, 164, 302, step=False)


def debris(can):
    """d1: a loose piece of board lying FLAT on the boards (walkable: no ink ring, it is
    not furniture): a lit top row, its body, a dark underside row and end grain, and a few
    splinters beside it."""
    for i in range(11):
        bx, by = 48 + i, 196 + (1 if i > 6 else 0)
        base_c = floor_c(bx, by + 1)
        can.put(bx, by, shade_w(base_c, 1.2))
        can.put(bx, by + 1, base_c)
        can.put(bx, by + 2, shade_w(base_c, 0.6))
    for by in (196, 197):
        can.put(47, by, shade_w(floor_c(47, by), 0.75))
    for by in (197, 198):
        can.put(59, by, shade_w(floor_c(59, by), 0.6))       # its end grain, in shade
    for (sx, sy, n) in ((64, 199, 3), (69, 193, 2), (41, 202, 3), (66, 205, 2)):
        for i in range(n):
            can.put(sx + i, sy, mix(floor_c(sx + i, sy), FRESH[3], 0.55) if i < n - 1 else FRESH[3])
            can.tint(sx + i + 1, sy + 1, lambda c: dk(c, 1))


def shade_w(c, k):
    return base.shade(c, k)


# ------------------------------------------------------------------ fresh boards (stage 2)

def fresh_board(can, x, y, w, hh, tone=0, level=0.0, seam_old=True, seed=0, dy=0,
                gap_end=None, nails=True):
    """A fresh tan board (or a run of them, joint to joint), the tile's own geometry. `level`
    0 fresh .. 1 the floor's own tone (weathered); `dy` drawn that many px high (dropping)."""
    k = y // 4
    # round 3: each board its own tone, half a FRESH step either way (0 as cut, 1 a step
    # darker, 2 paler): a patch is boards, not one sheet of new material
    if tone == 1:
        ramp = [mix(c, FRESH[max(0, i - 1)], 0.5) for i, c in enumerate(FRESH)]
    elif tone == 2:
        ramp = [mix(c, FRESH[min(5, i + 1)], 0.4) for i, c in enumerate(FRESH)]
    else:
        ramp = list(FRESH)
    lipped = hsh(x, y, seed + 19) < 0.35            # only some boards show a sawn end lip
    grain = hsh(x, y, seed + 17) < 0.35
    gx = x + 3 + int(hsh(x, y, seed + 18) * max(1, w - 9))
    for yy in range(y, y + hh):
        row = yy % 4
        for xx in range(x, x + w):
            if not (X0 <= xx < X1):
                continue
            pu = (xx - jx(k)) % 16
            if row == 0:
                c = mix(ramp[1], (116, 68, 46), 0.45) if seam_old else ramp[2]
            elif pu == 0 and xx != x:
                c = ramp[1]                            # the joint between two new boards
            elif pu == 1 and lipped:
                c = mix(ramp[4], FRESH[5], 0.3)        # a paler sawn end after a joint
            else:
                c = ramp[3]
                if grain and row == 2 and gx <= xx < gx + 5:
                    c = mix(ramp[3], ramp[2], 0.6)
            if level > 0:
                c = mix(c, floor_c(xx, yy), level)
            can.put(xx, yy - dy, c)
    if nails and hh == 4:
        for xx in range(x, x + w):
            pu = (xx - jx(k)) % 16
            if pu == 2 and X0 <= xx < X1:
                c = mix(ramp[1], NAIL, 0.4)
                if level > 0:
                    c = mix(c, floor_c(xx, y + 2), min(1.0, level * 1.3))
                can.put(xx, y + 2 - dy, c)
    if gap_end is not None and level < 0.5:
        for yy in range(y + 1, y + hh):
            if yy % 4:
                can.put(gap_end, yy - dy, mix(FRESH[0], HOLE[1], 0.5))


PATCHES = ["f1", "f2", "f3", "f4", "f5", "f6", "f7"]


def split_boards(x, y, w, hh):
    """A [x, y, w, h] run into its boards, joint to joint."""
    k = y // 4
    xs = [x] + [xx for xx in range(x + 1, x + w) if is_jt(xx, k)] + [x + w]
    return [(a, y, b - a, hh) for a, b in zip(xs, xs[1:]) if b > a]


def _joint_boards(fid):
    """Boards (x, y, w, h) laying over a block joint to joint: each run widened out to the
    butt joints either side of it."""
    out = []
    for y, x0, x1, hh in runs_of(FEAT[fid]["block"]):
        k = y // 4
        a = x0
        while not is_jt(a, k) and a > X0:
            a -= 1
        b = x1
        while not is_jt(b, k) and b < X1:
            b += 1
        out.append([a, y, b - a, hh])
    return out


def _patch_boards(pid):
    """The patch's boards as authored, unless they no longer cover what they mend (the
    layout moved the damage): then laid over the damage's own block, joint to joint."""
    mends = {"f1": "h1", "f2": "h2", "f3": "h3", "f4": "h4", "f5": "b1", "f6": "b2", "f7": "b3"}
    bs = FEAT[pid]["boards"]
    dmg = mends.get(pid)
    if dmg and dmg in FEAT:
        cover = mask_of(runs_of(bs))
        need = mask_of(runs_of(FEAT[dmg]["block"]))
        if dmg in ("h1", "h2"):
            need &= ~mask_of(runs_of(FEAT[dmg]["block_s2"]))
        if (need & ~cover).sum() > 0:
            return _joint_boards(dmg) if dmg not in ("h1", "h2") else bs
    return bs


def _s2_boards():
    """Every fresh board of stage 2: (patch, (x, y, w, h), tone, gap)."""
    out = []
    for pid in PATCHES:
        for b in _patch_boards(pid):
            for bx, by, bw, bh in split_boards(*b):
                v = hsh(bx, by, 91)
                tone = 1 if v < 0.38 else 2 if v < 0.62 else 0
                gap = bx + bw - 1 if (hsh(bx, by, 92) < 0.14 and bw >= 8) else None
                out.append((pid, (bx, by, bw, bh), tone, gap))
    return out


S2_BOARDS = _s2_boards()


def stack_and_saw(can, parts=("A", "B", "saw"), dy=None):
    """st1: two fresh boards lying crossed beside the low corner's core, a saw on them,
    three nails beside; objects, so ringed in INK. `dy` {part: px above its place}: a part
    dropping in (the 1 -> 2 play-in), drawn whole that high."""
    x0, y0 = 204, 191
    dy = dy or {}
    if "A" in parts:
        _board_a(can, x0, y0 - dy.get("A", 0))
    if "B" in parts:
        _board_b(can, x0, y0 - dy.get("B", 0))
    if "saw" in parts:
        _saw_and_nails(can, x0, y0 - dy.get("saw", 0))


def _board_a(can, x0, y0):
    for x in range(x0 + 1, x0 + 31):
        can.put(x, y0, INK)
        can.put(x, y0 + 1, FRESH[5] if x % 9 else FRESH[4])
        can.put(x, y0 + 2, FRESH[4])
        can.put(x, y0 + 3, FRESH[3])
        can.put(x, y0 + 4, FRESH[2])
        can.put(x, y0 + 5, INK)
        can.tint(x + 1, y0 + 6, lambda c: dk(c, 2))
    for yy in range(y0, y0 + 6):
        can.put(x0, yy, INK)
        can.put(x0 + 31, yy, INK)
    can.put(x0 + 30, y0 + 1, FRESH[3]); can.put(x0 + 30, y0 + 2, FRESH[3])    # end grain
    can.put(x0 + 30, y0 + 3, FRESH[2]); can.put(x0 + 30, y0 + 4, FRESH[1])
    can.tint(x0 + 32, y0 + 6, lambda c: dk(c, 2))


def _board_b(can, x0, y0):
    # board B across it, skew: from the floor on the left up over A to the right
    pts = [(x0 + 5 + i, y0 + 7 - (i * 6) // 22) for i in range(22)]
    for bx, by in pts:
        can.put(bx, by - 3, INK)
        can.put(bx, by - 2, FRESH[5])
        can.put(bx, by - 1, FRESH[4])
        can.put(bx, by, FRESH[2])
        can.put(bx, by + 1, INK)
    for j in range(-3, 2):
        can.put(x0 + 4, y0 + 7 + j, INK)
        can.put(x0 + 27, y0 + 2 + j, INK)
    for bx, by in pts[:9]:
        can.tint(bx + 1, by + 2, lambda c: dk(c, 2) if c[0] > 120 else c)


def _saw_and_nails(can, x0, y0):
    # the saw lying on the floor below them: blade to the left, handle to the right
    sx, sy = x0 + 6, y0 + 10
    blade_len = 15
    for i in range(blade_len):
        x = sx + i
        tall = 2 if i < 5 else 3
        can.put(x, sy - 1 - (tall == 3), INK)
        can.put(x, sy - (tall == 3), METAL[3])
        if tall == 3:
            can.put(x, sy, METAL[2])
        can.put(x, sy + 1, METAL[1] if i % 2 else METAL[2])
        can.put(x, sy + 2, INK if i % 2 == 0 else METAL[0])    # the teeth
        can.tint(x + 1, sy + 3, lambda c: dk(c, 1))
    can.put(sx - 1, sy, INK); can.put(sx - 1, sy + 1, INK)
    hx, hy = sx + blade_len, sy - 3
    grip = ["xxxx.",
            "x22xx",
            "x1x1x",
            "x1x1x",
            "x000x",
            ".xxx."]
    G = [(118, 58, 36), (168, 92, 52), (206, 128, 74)]
    for j, row in enumerate(grip):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            can.put(hx + i, hy + j, INK if ch == "x" else G[int(ch)])
    for i in range(5):
        can.tint(hx + i + 1, hy + 6, lambda c: dk(c, 1))
    # three nails
    for nx, ny in ((x0 + 25, y0 + 9), (x0 + 28, y0 + 10), (x0 + 3, y0 + 9)):
        can.put(nx, ny, METAL[3])
        can.put(nx + 1, ny, METAL[1])
        can.tint(nx + 1, ny + 1, lambda c: dk(c, 2))


def loose_new_board(can, level=0.0):
    """lb2: laid but not nailed, a pixel proud: its face one row up, its edge under it, a
    shadow under that; no nails."""
    x, y, w, hh = FEAT["lb2"]["rect"]
    fresh_board(can, x, y, w, hh, tone=1, level=level, dy=1, nails=False)
    for xx in range(x, x + w):
        if X0 <= xx < X1:
            can.put(xx, y + 3, mix(FRESH[1], floor_c(xx, y + 3), level))
            if not H2C.inside(xx, y + 4):
                can.put(xx, y + 4, mix(mix(FRESH[0], HOLE[1], 0.4), floor_c(xx, y + 4), level))


def stains_s2(can):
    for y in range(98, 128):                       # s1: the seat still bleached
        for x in range(6, 24):
            if y % 4:
                can.tint(x, y, lambda c: lt(c, 1))
    worn(can, 2)
    # s8 / s9: pale dried rings where the fresh leak and the roof corner's overflow were
    p2c, p3c = FEAT["p2"]["center"], FEAT["p3"]["center"]
    for (cx, cy, rx, ry, sd) in ((p2c[0], p2c[1], 19, 8.0, 81), (p3c[0], p3c[1], 13, 5.0, 82)):
        tide_line(can, cx, cy, rx, ry, 0, 2 * math.pi, seed=sd, fn=lambda c: lt(c, 1), wob=1.2)
    # s10: the old boards at the back wall's foot still dark beside the new ones
    for y in range(Y0, 16):
        for x in range(222, 236):
            if y % 4:
                can.tint(x, y, lambda c: wt(c, 1))


# ------------------------------------------------------------------ the cores' boards (2 -> 3)

def _core_boards():
    out = {}
    for name, hole, order in (("h2", H2C, -1), ("h1", H1C, 1)):
        bs = []
        for y, x0, x1, hh in hole.runs:
            bs += split_boards(x0, y, x1 - x0, hh)
        bs.sort(key=lambda b: (order * b[1], b[0]))
        out[name] = bs
    return out


CORE_BOARDS = _core_boards()
# the last laid, a step lighter in stage 3 (the repairs weathered in, like the cosy hut)
S3_KEEPERS = [b for b in CORE_BOARDS["h1"] if b[:2] in ((54, 112), (44, 108))] + \
             [b for b in CORE_BOARDS["h2"] if b[:2] in ((276, 184), (262, 192))]
S3_LEVEL = 0.7


# ------------------------------------------------------------------ static builds

_STATIC = {}


def build(stage, pool=1.0, stack=True):
    key = (stage, round(pool, 3), stack)
    if key in _STATIC:
        return _STATIC[key]
    can = Can()
    if stage == 1:
        grime(can, 1.0, seed=3)
        stains_s1(can)
        paint_b1(can)
        paint_b2(can)
        paint_b3(can)
        paint_stove(can, H4, 1)
        for c_id, seed, grey in (("c1", 4, True), ("c2", 5, False)):
            x, y, w, hh = FEAT[c_id]["rect"]
            crack(can, x, y, w, seed, grey=grey)
        crack_c3(can)
        for hole in (H1, H2, H3, H4, H5):
            hole.paint(can)
        H1.texture(can, clods=1.2, pebbles=0.6, roots=3)
        H2.texture(can, clods=0.9, pebbles=0.25, roots=3, sheen=1)
        H3.texture(can, clods=0.9, pebbles=0.3, roots=3, sheen=1)
        H4.texture(can, clods=0.6, pebbles=0.5, roots=0)
        H5.texture(can, clods=1.0, pebbles=1.0, roots=1, sheen=1)
        joist(can, H1, 64, 3, seed=1, shade=2)
        joist(can, H2, 286, 3, end=199, seed=2)
        joist(can, H3, 304, 3, seed=3)
        moss_joist(can, H3, 304, 3)
        paint_ash(can, H4)                           # the joist crosses over the crust
        joist(can, H4, 236, 3, kind="char", seed=4)
        paint_h2_extras(can, H2, 1, pool)
        paint_h3_moss(can, H3)
        for hole in (H1, H2, H3, H4, H5):
            hole.ends(can)
        H4.ragged(can, 4)
        H2.ragged(can, 3)
        debris(can)
    elif stage == 2:
        grime(can, 1.4, seed=3)
        stains_s2(can)
        paint_stove(can, H4, 2)
        x, y, w, hh = FEAT["c2"]["rect"]
        crack(can, x, y, w, 5)
        x, y, w, hh = FEAT["c5"]["rect"]
        crack(can, x, y, w, 6, grey=True)
        for pid, (bx, by, bw, bh), tone, gap in S2_BOARDS:
            fresh_board(can, bx, by, bw, bh, tone=tone, seam_old=True, seed=bx + by, gap_end=gap)
        for hole in (H1C, H2C):
            hole.paint(can)
        H1C.texture(can, clods=1.3, pebbles=1.1, roots=3, crumbs=1.0)
        H2C.texture(can, clods=0.9, pebbles=0.5, roots=3, crumbs=0.8, sheen=1)
        joist(can, H1C, 64, 3, seed=1, shade=2)
        joist(can, H2C, 286, 4, end=199, seed=2)
        paint_h2_extras(can, H2C, 2)
        for hole in (H1C, H2C):
            hole.ends(can)
        loose_new_board(can)
        if stack:
            stack_and_saw(can)
    else:
        for (bx, by, bw, bh) in S3_KEEPERS:
            fresh_board(can, bx, by, bw, bh, level=S3_LEVEL, seam_old=False)
    _STATIC[key] = can.image()
    return _STATIC[key]


def _crease_slit(can):
    """The slit where the crease's boards parted over the joist: dark, the joist's lit top
    in it (it sits right under the crease), splinters off the board ends on both lips;
    and the sprung board's nail and the dark gap under its raised end."""
    for k in range(44, 54):
        sl = crease_slit(k)
        if not sl:
            continue
        a, b = sl
        o = 1 if k <= 46 else 2 if k <= 50 else 3
        y = 4 * k
        for x in range(a, b):
            for r in range(0, 4 + o):
                yy = y + r
                if not (Y0 <= yy < Y1):
                    continue
                if 92 <= x <= 94 and k >= 49 and r >= o:
                    c = JOIST[3] if x == 92 else JOIST[2] if x == 93 else JOIST[1]
                    if r == o:
                        c = JOIST[1]                   # under the boards' lip, in shade
                else:
                    c = HOLE[0] if r >= o else HOLE[1]
                can.put(x, yy, c)
        r = random.Random(k * 13)
        for side, xe in ((-1, a), (1, b - 1)):
            for rr in (1, 2, 3):
                if r.random() < 0.45:
                    can.put(xe, y + o + rr, FRESH[4] if r.random() < 0.6 else FRESH[3])
    can.put(88, 202, NAIL_HI)                      # the nail the sprung board came off
    can.put(88, 203, NAIL)
    for x in range(84, 90):
        can.put(x, 208, HOLE[1])                    # the gap under the sprung end


# ------------------------------------------------------------------ plants (drawn per frame)

def sway(ts, x, phase, rate=0.32):
    """0 or 1 px on the stepped clock: one draught for the whole floor, the damp module's
    rule. A gust is a value noise running across the room from the window (left to right),
    so neighbours move together and a gust rolls over a patch; past 0.62 the tops lean one
    pixel right, away from the light, about a quarter of the time, and rest otherwise. The
    plant's own phase only nudges it a tenth (`rate` is kept for the callers, unused)."""
    v = vnoise(ts * 0.5 - x / 80.0 + (phase % 1.0) * 0.1, 0, 1.0, 808)
    return 1 if v > 0.62 else 0


def p_blade(ov, x, y, tall, lean, ramp, lit, ts, phase, bend=2.0, moves=True):
    """One blade standing on (x, y): its foot in the darkest step, its body a step up, its
    top third two, the tip lit when the beam is on it; leans `lean` px over its height (-
    is left, into the window), its top third sways a pixel on the stepped clock."""
    s = sway(ts, x, phase) if moves else 0
    for k in range(tall):
        f = k / max(1, tall - 1)
        lx = x + int(round(lean * f ** bend))
        if k >= tall - 2 and k >= 2:           # only the tip moves in a draught
            lx += s
        t = 0 if k == 0 else 1 if f < 0.4 else 2 if f < 0.75 else 3
        if k == tall - 1 and lit:
            t = 4
        ov.put(lx, y - k, ramp[t])


def p_tuft(ov, x, y, tall, lean, ramp, lit, ts, phase):
    """A clump: a fan of blades from one foot, the tallest in the middle leaning most."""
    p_blade(ov, x, y, tall, lean, ramp, lit, ts, phase)
    p_blade(ov, x - 1, y, max(2, tall - 4), lean - 1.5, ramp, lit, ts, phase + 0.15)
    p_blade(ov, x + 1, y, max(2, tall - 2), lean + 0.5, ramp, lit, ts, phase + 0.3)
    if tall > 6:
        p_blade(ov, x - 2, y + 1, max(2, tall - 6), lean - 2, ramp, lit, ts, phase + 0.4)
    if tall > 8:
        p_blade(ov, x + 2, y, max(2, tall - 5), lean + 1.5, ramp, lit, ts, phase + 0.55)
    ov.put(x, y + 1, ramp[0])
    ov.put(x + 1, y + 1, ramp[0])


def p_plantain(ov, x, y, ts, phase, lit=False):
    """A broad-leaved weed: a rosette of four ribbed leaves lying out round its foot."""
    s = sway(ts, x, phase, 0.18)
    ramp = LEAF if not lit else [LEAF[1], LEAF[2], LEAF[3], LEAF[4], LEAF[4]]
    for ang, L, W in ((-2.6, 5, 1.6), (-0.5, 5, 1.6), (-1.6, 4, 1.4), (2.9, 3, 1.1)):
        p_leafshape(ov, x, y, ang, L, W, ramp, s if ang < -1 else 0)
    ov.put(x, y, LEAF[0])


def p_clump(ov, x, y, n, tall, lit, ts, phase, ramp=LEAF):
    """A tuft of grass: `n` blades (3-6) out of one dark root, fanning; the middle ones
    tallest, each leaning out by its place in the fan and a little toward the window. The
    blades on the window side carry a lit tip (LEAF[4]) when the beam is on the tuft."""
    r = random.Random(x * 131 + y)
    if lit:                                        # in the beam the whole tuft is lit a step
        ramp = [ramp[1], ramp[2], ramp[3], ramp[3], ramp[4]]
    for i in range(n):
        u = i - (n - 1) / 2.0
        h_ = max(3, int(round(tall - abs(u) * 1.4 + r.uniform(-0.6, 0.6))))
        lean = u * 1.5 - 0.6
        foot = x + (1 if u > 0.8 else -1 if u < -0.8 else 0)
        p_blade(ov, foot, y, h_, lean, ramp, lit and u <= 0, ts, phase, bend=1.25,
                moves=abs(u) < 1.0)                # the tall middle blades catch the draught
    ov.put(x, y, ramp[0])
    ov.put(x - 1, y + 1, ramp[0])
    ov.put(x, y + 1, ramp[0])
    ov.put(x + 1, y + 1, ramp[0])


def p_droop(ov, x, y, n, ramp, ts, phase):
    """A blade bowed out over the near rim: up a pixel, then down onto the board."""
    s = sway(ts, x, phase, 0.27)
    ov.put(x, y, ramp[1])
    ov.put(x, y - 1, ramp[2])
    for i in range(n):
        ov.put(x - 1 - i + (s if i == n - 1 else 0), y - 1 + i, ramp[3 if i < n - 1 else 4])


def p_clover(ov, x, y, ramp, ts, phase, lit=False):
    s = sway(ts, x, phase, 0.21)
    for lx, ly in ((-1, -1), (2, -1), (0, -3)):
        for dx, dy, t in ((0, 0, 2), (1, 0, 3), (0, 1, 1), (1, 1, 2)):
            ov.put(x + lx + dx + (s if ly < -2 else 0), y + ly + dy, ramp[t + (lit and dy == 0)])
    ov.put(x, y + 1, ramp[1])


def p_dandelion(ov, x, y, tall, lean, ts, phase, clock=False, opened=1.0):
    s = sway(ts, x, phase, 0.29)
    for dx, dy, t in ((-2, 0, 2), (-3, 1, 1), (-4, 0, 2), (2, 0, 2), (3, -1, 3), (4, 0, 2),
                      (-1, 1, 1), (1, 1, 1), (0, 1, 1)):
        ov.put(x + dx, y + dy, LEAF[t])          # the rosette's toothed leaves
    hx = x
    for k in range(1, tall):
        f = k / tall
        hx = x + int(round(lean * f)) + (s if f > 0.6 else 0)
        ov.put(hx, y - k, LEAF[2] if k < tall - 2 else LEAF[3])
    cy = y - tall
    if opened <= 0.0:
        return
    if clock:                                     # the seed clock: a ring of white, gaps
        for dx, dy, c in ((0, -2, WHITE[2]), (-1, -2, WHITE[2]), (1, -2, WHITE[1]),
                          (-2, -1, WHITE[2]), (2, -1, WHITE[1]), (-2, 0, WHITE[1]),
                          (2, 0, WHITE[0]), (-1, 1, WHITE[1]), (1, 1, WHITE[0]),
                          (0, 1, WHITE[0]), (-1, -1, WHITE[1]), (1, 0, WHITE[1]),
                          (0, -1, WHITE[1]), (0, 0, (190, 180, 146)), (-1, 0, WHITE[1])):
            ov.put(hx + dx, cy + dy, c)
        return
    if opened < 0.5:
        ov.put(hx, cy, YELLOW[1])
        ov.put(hx, cy + 1, LEAF[3])
        return
    for dx, dy, t in ((0, -1, 2), (-1, 0, 2), (0, 0, 1), (1, 0, 1), (-1, -1, 1), (1, -1, 2),
                      (-1, 1, 0), (0, 1, 0), (1, 1, 0)):
        ov.put(hx + dx, cy + dy, YELLOW[t])


def p_daisy(ov, x, y, tall, lean, ts, phase, opened=1.0):
    s = sway(ts, x, phase, 0.3)
    hx = x
    for k in range(tall):
        f = k / max(1, tall)
        hx = x + int(round(lean * f)) + (s if f > 0.55 else 0)
        ov.put(hx, y - k, LEAF[1] if k == 0 else LEAF[2])
    ov.put(x - 1, y, LEAF[2])
    ov.put(x + 1, y - 1, LEAF[3])
    cy = y - tall
    if opened <= 0.0:
        return
    if opened < 0.5:
        ov.put(hx, cy, WHITE[1])
        ov.put(hx, cy + 1, LEAF[3])
        return
    for dx, dy, c in ((0, -1, WHITE[2]), (-1, 0, WHITE[2]), (1, 0, WHITE[1]), (0, 1, WHITE[0]),
                      (-1, -1, WHITE[1]), (1, 1, (150, 150, 140)), (0, 0, YELLOW[1])):
        ov.put(hx + dx, cy + dy, c)


def p_seedling(ov, x, y, ts, phase):
    """One pale seedling (h4's ash grows nothing else): a LEAF[2] stem, two seed leaves in
    LEAF[3] with a lit LEAF[4] tip, swaying a pixel."""
    s = sway(ts, x, phase, 0.25)
    ov.put(x, y, LEAF[1])
    ov.put(x, y - 1, LEAF[2])
    ov.put(x, y - 2, LEAF[2])
    for dx, c in ((-1, LEAF[3]), (-2, LEAF[4]), (1, LEAF[3]), (2, LEAF[3])):
        ov.put(x + dx + s, y - 3, c)


def p_fern(ov, x, y, ts, phase, lit=0, small=False):
    """A young fern: four fronds arching out, leaflets in pairs, a fiddlehead unrolling.
    `lit` lifts every step (h3 is under the veil: LEAF[2..3], the crozier's tip LEAF[4]);
    `small` is a sprout: two short fronds and the crozier."""
    s = sway(ts, x, phase, 0.22)
    L = lambda t: LEAF[min(4, t + lit)]
    fronds = ((-1, 11, -6), (1, 10, 6), (-1, 7, -9), (1, 7, 9)) if not small else         ((-1, 5, -4), (1, 4, 4))
    for sgn, tall, reach in fronds:
        prev = None
        for k in range(tall):
            f = k / tall
            fx = x + int(round(reach * f * f)) + (s if f > 0.55 else 0)
            fy = y - int(round(tall * 0.9 * math.sin(f * math.pi * 0.6)))
            ov.put(fx, fy, L(1) if k < 2 else L(2))
            if k > 1 and k % 2 == 0:
                ov.put(fx, fy - 1, L(3) if f > 0.4 else L(2))
                ov.put(fx + sgn, fy + 1, L(1))
            prev = (fx, fy)
        if prev:
            ov.put(prev[0] + sgn, prev[1], L(3))
    for dx, dy, t in ((0, 0, 1), (0, -1, 1), (0, -2, 2), (0, -3, 2), (0, -4, 2), (0, -5, 2),
                      (1, -6, 3), (2, -6, 3), (3, -5, 2), (2, -4, 2), (1, -5, 4)):
        c = LEAF[4] if t == 4 else L(t)
        ov.put(x + dx + (s if dy < -3 else 0), y + dy, c)


def p_leafshape(ov, x, y, ang, L, W, ramp, s=0):
    """A leaf from (x, y) along `ang` (radians, screen: 0 right, -pi/2 up), L long and W
    wide at its widest; the upper half a step lighter, the midrib and the lower edge a
    step darker, the tip lit; its outer half shifted `s` px (the sway)."""
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx
    xs = [x + dx * L + nx * W, x + dx * L - nx * W, x + nx * W, x - nx * W]
    ys = [y + dy * L + ny * W, y + dy * L - ny * W, y + ny * W, y - ny * W]
    for py in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for px in range(int(min(xs)) - 1, int(max(xs)) + 2):
            rx, ry = px - x, py - y
            t = rx * dx + ry * dy
            d = rx * nx + ry * ny
            if not (0 <= t <= L):
                continue
            w = W * math.sin(math.pi * min(1.0, (t + 0.6) / (L + 0.6))) ** 0.8
            if abs(d) > w + 0.35:
                continue
            up = (d * ny) < 0                    # the half facing up the screen
            if abs(d) < 0.5 and t < L - 1:
                c = ramp[1]
            elif abs(d) > w - 0.6 and not up:
                c = ramp[1]
            else:
                c = ramp[3] if up else ramp[2]
            if t > L - 1.2:
                c = ramp[4] if up else ramp[3]
            ov.put(px + (s if t > L * 0.55 else 0), py, c)


def p_dockleaf(ov, x, y, ang, L, s=0):
    """One dock leaf from its root (x, y): a 2-px stalk, then a long pointed oval L long and
    3 px across at its widest, along `ang` (radians, screen: 0 right, -pi/2 up). LEAF[3]
    along its upper edge, LEAF[2] its upper half, LEAF[1] its lower half, a 1-px LEAF[0]
    midrib, a LEAF[2] tip pixel; its outer half `s` px over (the sway)."""
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy, dx
    if ny > 0:                                     # n points up the screen
        nx, ny = -nx, -ny
    for i in (1, 2):                               # the stalk
        ov.put(x + int(round(dx * i)), y + int(round(dy * i)), (150, 62, 46) if i == 1 else LEAF[1])
    sx, sy = x + dx * 2, y + dy * 2
    pts = {}
    for py in range(int(min(sy, sy + dy * L)) - 3, int(max(sy, sy + dy * L)) + 4):
        for px in range(int(min(sx, sx + dx * L)) - 3, int(max(sx, sx + dx * L)) + 4):
            rx, ry = px - sx, py - sy
            t = rx * dx + ry * dy
            d = rx * nx + ry * ny                  # > 0 the upper half
            if not (0 <= t <= L):
                continue
            w = 1.55 * math.sin(math.pi * min(1.0, (t + 0.5) / (L + 0.5))) ** 0.7
            if abs(d) > w + 0.25:
                continue
            if t > L - 1.0:
                c = LEAF[2]                        # the tip
            elif abs(d) < 0.5:
                c = LEAF[0]                        # the midrib
            elif d > 0:
                c = LEAF[3] if abs(d) > w - 0.75 else LEAF[2]
            else:
                c = LEAF[1]
            pts[(px + (s if t > L * 0.55 else 0), py)] = c
    for (px, py), c in pts.items():
        ov.put(px, py, c)


def p_dock(ov, x, y, ts, phase, flip=False):
    """A dock in the light: three long pointed leaves leaning out from a red root, 20-40
    degrees off the ground, all to one side of the beam it stands in (`flip` the other)."""
    s = sway(ts, x, phase, 0.2)
    sg = -1 if flip else 1
    ov.put(x, y, (122, 48, 40))
    # a rosette: one leaf out to each side at 20-40 degrees off the ground, a shorter one
    # standing up between them (leaning to the plant's side)
    for side, deg, L in ((sg, 26, 9), (-sg, 34, 8), (sg, 74, 7)):
        a = math.radians(deg)
        ang = -a if side > 0 else math.pi + a
        p_dockleaf(ov, x, y, ang, L, s)


def p_nettle(ov, x, y, tall, ts, phase):
    s = sway(ts, x, phase, 0.26)
    for k in range(tall):
        f = k / tall
        sx = x + (s if f > 0.6 else 0)
        ov.put(sx, y - k, LEAF[1] if k < 2 else LEAF[2])
        if k % 3 == 2:
            for side in (-1, 1):
                ov.put(sx + side, y - k, LEAF[2])
                ov.put(sx + 2 * side, y - k + 1, LEAF[3] if side > 0 else LEAF[2])
                ov.put(sx + 3 * side, y - k + 1, LEAF[1])
                ov.put(sx + 2 * side, y - k + 2, LEAF[1])
    ov.put(x + s, y - tall, LEAF[3])
    ov.put(x + s - 1, y - tall + 1, LEAF[2])
    ov.put(x + s + 1, y - tall + 1, LEAF[3])


def p_leaf(ov, x, y, c0, c1):
    """A dead leaf, curled: two tones and a dark under-edge."""
    ov.put(x, y, c1)
    ov.put(x + 1, y, c0)
    ov.put(x, y + 1, c0)
    ov.put(x - 1, y + 1, DEAD[0])


def _on(hole, x, y):
    """Walk down from (x, y) to the first earth the hole shows; None if there is none."""
    yy = y
    while yy < FH and not hole.earth_ok(x, yy):
        yy += 1
        if yy - y > 8:
            return None
    return yy if yy < FH else None


def _plants(stage):
    r = random.Random(100 + stage)
    out = []
    if stage == 1:
        # wd1: h1's grass gathered in tufts (each 3-6 blades from one root), two dandelions,
        # a plantain and a clover; nothing loose on the open earth
        for x, y, n, tall in ((36, 112, 5, 8), (46, 124, 6, 10), (57, 104, 5, 9), (76, 116, 6, 10),
                              (90, 108, 4, 8), (84, 128, 6, 9), (54, 134, 4, 7)):
            yy = _on(H1, x, y)
            if yy is not None:
                out.append(("clump", x, yy, n, tall, BEAM[yy, x] > 0.3, r.random()))
        for x, y in ((40, 116), (88, 104)):
            yy = _on(H1, x, y)
            if yy is not None:
                out.append(("dandelion", x, yy, 9 + r.randint(0, 3), -2, r.random()))
        out.append(("plantain", 80, _on(H1, 80, 122) or 122, r.random(), True))
        out.append(("clover", 98, _on(H1, 98, 118) or 118, MOSS, r.random(), True))
        for x in (34, 66, 92):                         # blades bowed out over the near rim
            for y in range(FH - 2, 0, -1):
                if H1.interior[y, x] and not H1.m[y + 1, x]:
                    if H1.depth[y, x] >= 4:
                        out.append(("droop", x, y, 3, LEAF, r.random()))
                    break
        # wd2: tiny tufts in the tongue's slot only (tall green only ever inside a block)
        for x, tall in ((102, 2), (109, 1), (115, 2)):
            out.append(("blade", x, 115, tall, -0.5, LEAF, True, r.random()))
            out.append(("blade", x + 1, 115, max(1, tall - 1), 0.5, LEAF, False, r.random()))
        # wd3: h2's rank weeds, rooted ON the daylight beams (one each side of each beam,
        # never reaching across from one to the other)
        if SLITS:
            spots = []
            for y, kind, extra in ((194, "dock", True), (178, "dock", False),
                                   (186, "nettle", 9), (168, "tuft", None)):
                xs = [q[0] for q in SLITS if q[1] == y]
                if xs:
                    spots.append((xs[0], y, kind, extra))
        else:                                          # round the pool and the wall
            spots = [(303, 200, "dock", True), (320, 190, "dock", False),
                     (327, 184, "nettle", 9), (326, 168, "tuft", None)]
        for x, y, kind, extra in spots:
            if kind == "dock":
                out.append(("dock", x, y, r.random(), extra))
            elif kind == "nettle":
                out.append(("nettle", x, y, extra, r.random()))
            else:
                out.append(("tuft", x, y, 4, 0.5, MOSS, False, r.random()))
        # wd4: the fern unrolling under the roof corner's drip line (lifted for the veil)
        out.append(("fern", 292, 43, r.random(), 1))
        out.append(("tuft", 318, 55, 3, 0, MOSS, False, r.random()))
        # h4: nothing grows in ash but one pale seedling
        yy = _on(H4, 227, 98)
        if yy is not None:
            out.append(("seedling", 227, yy, r.random()))
        # wd5: the sill rot's grass: a tuft each side of the joist and one plantain
        for x, y, n, tall in ((84, 211, 4, 5), (100, 212, 3, 4)):
            yy = _on(H5, x, y)
            if yy is not None:
                out.append(("clump", x, yy, n, tall, False, r.random()))
        yy = _on(H5, 78, 211)
        if yy is not None:
            out.append(("blade", 78, yy, 3, -1, LEAF, False, r.random()))
        # t1: under the door: four tufts at uneven spacing, one leaning, one dead straw
        for x, tall, lean, ramp in ((159, 3, 0, LEAF), (161, 2, 0, LEAF), (166, 4, -2, LEAF),
                                    (170, 3, 0.5, [DEAD[0], DEAD[1], DEAD[2], DEAD[3], DEAD[3]])):
            out.append(("blade", x, Y0 + 2, tall, lean, ramp, False, r.random()))
            out.append(("blade", x + 1, Y0 + 2, max(1, tall - 1), lean + 0.5, ramp, False, r.random()))
        out.append(("leaves", 158, 13))
        out.append(("leaves", 177, 12))
        out.append(("leaves", 62, 202))
    elif stage == 2:
        # wd7: h1's core in flower, in the beam (all inside the core)
        picks = [(46, 112, "clock"), (60, 108, "daisy"), (74, 112, "daisy"), (56, 120, "tuft"),
                 (80, 116, "clover"), (68, 124, "daisy"), (50, 116, "clover"), (72, 107, "tuft"),
                 (84, 114, "daisy"), (62, 117, "tuft"), (48, 117, "daisy"), (66, 122, "daisy")]
        for x, y, kind in picks:
            yy = _on(H1C, x, y)
            if yy is None:
                continue
            if kind == "clock":
                out.append(("dandelion_clock", x, yy, 9, -1, r.random()))
            elif kind == "daisy":
                out.append(("daisy", x, yy, 4 + r.randint(0, 3), -1, r.random()))
            elif kind == "clover":
                out.append(("clover", x, yy, MOSS, r.random(), True))
            else:
                out.append(("tuft", x, yy, 5 + r.randint(0, 4), -1.5, LEAF, True, r.random()))
        out.append(("daisy", 10, 104, 3, -1, 0.4))     # in the window seat's seam
        # wd9: the low corner's stubble and one dandelion
        for x, y in ((286, 207), (296, 202), (305, 196), (276, 211), (318, 192), (271, 205)):
            if H2C.earth_ok(x, y):
                out.append(("blade", x, y, 2, 0, MOSS, False, r.random()))
        out.append(("dandelion", 299, 207, 6, 0, r.random()))
    else:
        out.append(("daisy", 10, 104, 3, -1, 0.4))
    return out


PLANTS = {s: _plants(s) for s in (1, 2, 3)}


class Rec:
    """Records one plant's pixels, so the caller can cull, wither or grow it as a whole."""

    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        self.px[(int(x), int(y))] = c[:3]


def _commit(ov, rec, keep=1.0, grow=False):
    """Draw a recorded plant: all of it, or (keep < 1) only part of it in whole rows:
    withering takes the top rows first (tips down); growing shows the bottom rows first."""
    if not rec.px:
        return
    if keep >= 1.0:
        for (x, y), c in rec.px.items():
            ov.put(x, y, c)
        return
    if keep <= 0.0:
        return
    ys = [y for (_, y) in rec.px]
    y0, y1 = min(ys), max(ys)
    n = y1 - y0 + 1
    rows = max(1, int(math.ceil(n * keep)))
    for (x, y), c in rec.px.items():
        if (y1 - y) < rows:                    # the bottom `rows` rows
            ov.put(x, y, c)


def draw_plants(ov, plants, ts, cover=None, opened=1.0, keep=None):
    """`cover` a bool array (FH, FW): a plant any of whose pixels lies under it is not drawn
    (a board has landed over it). `keep` fn(plant) -> 0..1: how much of it stands."""
    for p in plants:
        rec = Rec()
        _draw_plant(rec, p, ts, opened)
        if cover is not None and any(0 <= y < FH and 0 <= x < FW and cover[y, x]
                                     for (x, y) in rec.px):
            continue
        _commit(ov, rec, 1.0 if keep is None else keep(p))


def _draw_plant(ov, p, ts, opened):
        kind, x, y = p[0], p[1], p[2]
        if kind == "tuft":
            p_tuft(ov, x, y, p[3], p[4], p[5], p[6], ts, p[7])
        elif kind == "blade":
            p_blade(ov, x, y, p[3], p[4], p[5], p[6], ts, p[7])
        elif kind == "droop":
            p_droop(ov, x, y, p[3], p[4], ts, p[5])
        elif kind == "clover":
            p_clover(ov, x, y, p[3], ts, p[4], p[5])
        elif kind == "dandelion":
            p_dandelion(ov, x, y, p[3], p[4], ts, p[5], opened=opened)
        elif kind == "dandelion_clock":
            p_dandelion(ov, x, y, p[3], p[4], ts, p[5], clock=True, opened=opened)
        elif kind == "daisy":
            p_daisy(ov, x, y, p[3], p[4], ts, p[5], opened=opened)
        elif kind == "fern":
            p_fern(ov, x, y, ts, p[3], lit=p[4] if len(p) > 4 else 0)
        elif kind == "sprout":
            p_fern(ov, x, y, ts, p[3], small=True)
        elif kind == "clump":
            p_clump(ov, x, y, p[3], p[4], p[5], ts, p[6])
        elif kind == "dock":
            p_dock(ov, x, y, ts, p[3], p[4])
        elif kind == "nettle":
            p_nettle(ov, x, y, p[3], ts, p[4])
        elif kind == "seedling":
            p_seedling(ov, x, y, ts, p[3])
        elif kind == "plantain":
            p_plantain(ov, x, y, ts, p[3], p[4])
        elif kind == "leaves":
            p_leaf(ov, x, y, DEAD[1], DEAD[2])
            p_leaf(ov, x + 2, y + 1, DEAD[2], DEAD[3])
            p_leaf(ov, x - 1, y + 2, DEAD[0], DEAD[1])


# ------------------------------------------------------------------ the contract

def _blit(under, arr):
    under.alpha_composite(Image.fromarray(arr, "RGBA"), dest=(FX, FY))


def light_plants(ov):
    """The daylight streak lights whatever leaves stand in it, as it lights the earth."""
    for (x, y), k in SLIT_LIGHT.items():
        if 0 <= x < FW and 0 <= y < FH and ov.px[y, x, 3]:
            ov.px[y, x, :3] = lit_by(tuple(int(v) for v in ov.px[y, x, :3]), k * 0.6)


def draw(stage, t, ctx, under, over):
    ts = ctx.step(t, 8.0)
    _blit(under, build(stage))
    ov = Ov()
    draw_plants(ov, PLANTS[stage], ts)
    if stage == 1:
        light_plants(ov)
    _blit(under, ov.px)


# ------------------------------------------------------------------ stage up
#
# The play-in runs on the game's stepped clock (8 fps, p = ticks / 16). life.py lifts the
# veil on the ticks at p .625 and .875 (1->2) and .375 / .5625 / .75 (2->3, its own steps);
# nothing big of the floor's changes on .625 or .875, so the room never jumps all at once.
# stage_up(frm, 1.0) draws exactly draw(frm + 1) (checked by out/_ff_endcheck.py).

_YY, _XX = np.mgrid[0:FH, 0:FW]
_K = _YY // 4
_SEG = (_XX - np.take(np.array(JOINT), _K % 4)) // 16
BOARD_KEY = np.where(_YY % 4 == 0, _K * 64 + 63, _K * 64 + _SEG + 2)
VEIL_TICKS = (0.625, 0.875)


def _off_veil(thr):
    """Move a switch time off the ticks that land on the veil's own steps."""
    out = thr.copy()
    for vt in VEIL_TICKS:
        m = (out >= vt - DROP) & (out < vt)
        out[m] -= DROP
    return out


DROP = 0.0625          # one tick of the 8 fps clock, in p (2 s = 1)
THR12 = _off_veil(hsh_np(BOARD_KEY, 5, 2) * 0.55 + 0.25)   # each old board scrubbed, 1 -> 2
THR23 = hsh_np(BOARD_KEY, 6, 3) * 0.5 + 0.35                # 2 -> 3
PATCH_PX = np.zeros((FH, FW), bool)
for _pid, (_bx, _by, _bw, _bh), _t, _g in S2_BOARDS:
    PATCH_PX[_by:_by + _bh, _bx:_bx + _bw] = True
CORE_PX = H1C.m | H2C.m
CORE_IN = H1C.interior | H2C.interior
_d = _dist_field(CORE_PX, 1)
EDGE_PX = (_d <= 1) & ~CORE_IN                              # face, lip, sawn end grain
PIX_HASH = hsh_np(_XX, _YY, 4242)

# 1 -> 2: the boards round the cores are laid first, then the cores are sawn square and
# their stage-1 contents go, then the rest of the room is mended.
STARTS = {"f1": (0.2, 0.42), "f2": (0.1875, 0.42), "f3": (0.30, 0.72), "f4": (0.34, 0.72),
          "f7": (0.38, 0.75), "f5": (0.42, 0.75), "f6": (0.46, 0.75)}
LAST_DOWN = 0.8125                                           # lb2 and the stack land (puffs
                                                             # gone 3 ticks later, by p 1)
DISSOLVE_TICKS = (0.4375, 0.5, 0.5625, 0.6875)               # the cores' contents go
POOL_STEPS = (1.0, 0.7, 0.45, 0.2, 0.0)                      # the low corner's pool dries
POOL_TICKS = (0.4375, 0.5625, 0.6875, 0.8125)                # two ticks apart (round 3)
STACK_LAND = {"A": 0.6875, "B": 0.75, "saw": LAST_DOWN}      # the stack set down part by part
SAW_FROM = 0.4375                                            # 2 plank rows a tick from here
# round 2: the core is never bare. Stage 2's plants stand up from the tick the first weeds
# under the new boards start to go (.3125) and open from .5; the stage-1 grass inside the
# cores stays until they have, then thins in three ticks (.6875 .75 .8125), off the veil's.
GROW = (0.3125, 0.5)                                         # stage-2 plants stand up
OPEN = (0.5, 0.6875)                                         # and open
CORE_GO = (0.6875, 0.75, 0.8125)                             # the stage-1 grass in the cores


def _drop_state(p, pland):
    """-> (dy px above its place, or None if not yet; age in s since it landed)."""
    d = pland - p
    if d > DROP * 3 - 1e-9:
        return None, 0.0
    if d > 1e-9:
        return int(math.ceil(d / DROP - 1e-9)), 0.0
    return 0, (p - pland) * 2.0


def _rows_sched(keys, p0, p1):
    ks = sorted(set(keys))
    return {k: p0 + (p1 - p0) * i / max(1, len(ks) - 1) for i, k in enumerate(ks)}


def _puff(ov, x, y, age, seed):
    """Dust off a board landing: whole pixels thrown out low and wide, thinning over 3 ticks."""
    tick = int(age * 8 + 1e-6)
    if tick > 2 or age < 0 or hsh(seed, 3, 17) > 0.25:  # one board end in four puffs
        return
    r = random.Random(seed)
    for i in range(3 - tick):
        a = r.uniform(math.pi * 0.85, math.pi * 2.15)
        d = 1 + tick + r.random() * 0.8
        px = x + int(round(math.cos(a) * d * 1.7))
        py = y + int(round(math.sin(a) * d * 0.7)) - (tick > 0)
        if 0 <= px < FW and 0 <= py < FH:      # dust is a haze over the boards, not salt
            ov.put(px, py, mix(floor_c(px, py), DUST[2 - min(2, tick + (i % 2))], 0.5))


def _under_pieces(ctx):
    """Floor-rel mask of every stage-2 piece's base: the boards under them are laid
    already when the play-in starts (nothing ever stands over a hole)."""
    m = np.zeros((FH, FW), bool)
    for pc in getattr(ctx, "pieces", []):
        x, y, w, hh = pc["base"]
        x, y = x - FX, y - FY
        m[max(0, y):max(0, y + hh), max(0, x):max(0, x + w)] = True
    return m


def stage_up(frm, p, ctx, under, over):
    ts = ctx.step(getattr(ctx, "t", 0.0), 8.0)
    ps = min(1.0, ts / 2.0)                         # p, on the stepped clock
    if frm == 1:
        _up_12(ps, ts, under, ctx)
    else:
        _up_23(ps, ts, under, ctx)


def _paste(can, src, mask):
    can.rgb[mask] = src[mask][..., :3]
    can.a[mask] = src[mask][..., 3] > 0


def _n_steps(p, ticks):
    return sum(1 for t in ticks if p >= t - 1e-9)


def _pool_px(scale):
    """The pool's pixels and its 1-px mud rim (what build(1, scale) shows as water)."""
    m = np.zeros((FH, FW), bool)
    for x, y in _pool_set(H2, scale):
        m[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = True
    return m


def _up_12(p, ts, under, ctx):
    s2 = build(2, stack=False)                       # the stack is set down by hand, below
    nd = _n_steps(p, DISSOLVE_TICKS)                 # 0..4 dissolve steps done
    npool = _n_steps(p, POOL_TICKS)                  # 0..4 drying steps, two ticks apart
    s1 = build(1, POOL_STEPS[npool])                 # the pool shrinks about its middle
    wet = _pool_px(POOL_STEPS[npool]) if npool < 4 else np.zeros((FH, FW), bool)
    out = s1.copy()
    sw = (p > THR12) & ~PATCH_PX & ~CORE_PX & ~EDGE_PX & ~wet
    out[sw] = s2[sw]                                 # old boards scrubbed one by one
    if nd:                                           # the cores' contents, hash-ordered;
        q = nd / 4.0                                 # the water only goes as it dries
        m = CORE_IN & (PIX_HASH < q) & ~wet
        out[m] = s2[m]
    can = Can()
    can.rgb = out[..., :3].astype(np.int32)
    can.a = out[..., 3] > 0
    ov = Ov()
    landed = np.zeros((FH, FW), bool)
    early = _under_pieces(ctx)
    for pid in PATCHES:
        bs = [b for b in S2_BOARDS if b[0] == pid]
        p0, p1 = STARTS[pid]
        sched = _rows_sched([b[1][1] for b in bs], p0, p1)
        for _pid, (bx, by, bw, bh), tone, gap in bs:
            if early[by:by + bh, bx:bx + bw].any():
                dy, age = 0, 9.0
            else:
                dy, age = _drop_state(p, sched[by])
            if dy is None:
                continue
            if dy == 0:
                sl = (slice(by, by + bh), slice(bx, bx + bw))
                m = np.zeros((FH, FW), bool)
                m[sl] = True
                _paste(can, s2, m & ~EDGE_PX)        # exactly the stage-2 board
                landed[sl] = True
                _puff(ov, bx - 1, by + 3, age, bx * 7 + by)
                _puff(ov, bx + bw, by + 3, age, bx * 5 + by + 1)
                for yy in range(by, by + bh):        # unsawn edge pixels: plain new board
                    for xx in range(bx, bx + bw):
                        if EDGE_PX[yy, xx]:
                            can.rgb[yy, xx] = s2[yy, xx, :3] if _sawn(p, yy) else S2_PLAIN[yy, xx]
                            can.a[yy, xx] = True
            else:
                fresh_board(can, bx, by, bw, bh, tone=tone, seed=bx + by, dy=dy, gap_end=gap)
    # the cores sawn square: 2 plank rows a tick, the face, lip and end grain of each row
    # appearing as it is cut
    for yy in range(FH):
        if _sawn(p, yy):
            m = EDGE_PX[yy] & ~PATCH_PX[yy]
            can.rgb[yy, m] = s2[yy, m, :3]
            can.a[yy, m] = s2[yy, m, 3] > 0
    if p >= LAST_DOWN - DROP * 2:                     # last: the unnailed board
        dy, age = _drop_state(p, LAST_DOWN)
        if dy is not None:
            x, y, w, hh = FEAT["lb2"]["rect"]
            sl = (slice(y - 1, y + 5), slice(x, x + w))
            if dy == 0:
                can.rgb[sl] = s2[sl][..., :3]
                can.a[sl] = s2[sl][..., 3] > 0
    # the stack (round 3): set down part by part, each whole, through _drop_state: A, then B
    # across it, the saw last; nothing of a part shows before its own drop starts
    dys, shown = {}, []
    for part in ST_PARTS:
        dy, age = _drop_state(p, STACK_LAND[part])
        if dy is None:
            continue
        dys[part] = dy
        shown.append(part)
        if dy == 0:
            sa, sb = {"A": (79, 84), "B": (81, 85), "saw": (87, 90)}[part]   # seeds that puff
            _puff(ov, 204 if part != "saw" else 209, 197 if part != "saw" else 202, age, sa)
            _puff(ov, 236 if part != "saw" else 231, 197 if part != "saw" else 202, age, sb)
    if shown:
        stack_and_saw(can, tuple(shown), dys)
    _blit(under, can.image())
    # plants: stage 1's under a landed board are gone; those in the cores wither tips
    # down with the dissolve; the rest (the door's tufts, the leaves) are pulled one by one
    def keep1(pl):
        x, y = pl[1], pl[2]
        if CORE_PX[min(FH - 1, y), x]:
            return 1.0 - _n_steps(p, CORE_GO) / 3.0
        t0 = 0.3 + hsh(x, y, 61) * 0.3
        return max(0.0, 1.0 - max(0.0, p - t0) / (DROP * 3))
    core1 = [pl for pl in PLANTS[1] if CORE_PX[min(FH - 1, pl[2]), pl[1]]]
    draw_plants(ov, [pl for pl in PLANTS[1] if pl not in core1], ts, cover=landed, keep=keep1)
    draw_plants(ov, core1, ts, keep=keep1)          # rooted in a core: no board ever lands on them
    g = clampi((p - GROW[0]) / (GROW[1] - GROW[0] + DROP), 0.0, 1.0) if p >= GROW[0] else 0.0
    if g > 0:
        opened = 0.0 if p < OPEN[0] else 0.4 if p < OPEN[1] else 1.0
        g = math.floor(g * 4 + 1e-9) / 4.0 if g < 1 else 1.0
        draw_plants(ov, PLANTS[2], ts, opened=opened,
                    keep=lambda pl: g)
    _blit(under, ov.px)


def _sawn(p, yy):
    """Is plank row yy's edge sawn yet? From SAW_FROM, 2 plank rows a tick, both cores
    together, each from its far rim down; never landing on a veil tick."""
    for hole in (H1C, H2C):
        y0, y1 = hole.bbox[1], hole.bbox[3]
        if y0 - 1 <= yy <= y1:
            k = max(0, (yy - y0) // 4)
            t = SAW_FROM + (k // 2) * DROP
            for vt in VEIL_TICKS:
                if t >= vt - 1e-9:
                    t += DROP
            return p >= t - 1e-9
    return True


def _s2_plain():
    """Every stage-2 board as fresh_board lays it, before the cores are sawn."""
    tmp = Can()
    for _pid, (bx, by, bw, bh), tone, gap in S2_BOARDS:
        fresh_board(tmp, bx, by, bw, bh, tone=tone, seed=bx + by, gap_end=gap)
    return tmp.rgb.copy()


S2_PLAIN = _s2_plain()


def _weather(p, bx, by, keeper, since):
    """0 fresh .. 1 the floor's own tone, in three hard steps; keepers stop at S3_LEVEL.
    -> (level, final?)"""
    start = since + hsh(bx, by, 93) * 0.12
    step = int(clampi((p - start) / 0.05, 0, 3))
    lvl = (0.0, 0.4, S3_LEVEL, 1.0)[step]
    if keeper:
        return min(lvl, S3_LEVEL), step >= 2
    return lvl, step >= 3


ST_PARTS = ("A", "B", "saw")


def _up_23(p, ts, under, ctx):
    s2, s3 = build(2), build(3)
    out = s2.copy()
    sw = (p > THR23) & ~PATCH_PX & ~CORE_PX & ~EDGE_PX
    out[sw] = s3[sw]
    can = Can()
    can.rgb = out[..., :3].astype(np.int32)
    can.a = out[..., 3] > 0
    ov = Ov()
    sched = {"h2": _rows_sched([-b[1] for b in CORE_BOARDS["h2"]], 0.25, 0.48),
             "h1": _rows_sched([b[1] for b in CORE_BOARDS["h1"]], 0.5, 0.66)}
    first_drop = {n: min(sched[n].values()) - DROP * 3 for n in sched}
    last_land = max(max(v.values()) for v in sched.values())
    # the stack goes down one board at a time: B (on top) when h2's first core board starts
    # to drop, A when h1's does; the saw and the nails last, once the last board is down
    parts = set(ST_PARTS)
    if p >= first_drop["h2"]:
        parts.discard("B")
    if p >= first_drop["h1"]:                         # A and the saw are taken up together
        parts.discard("A")                            # (round 3: the saw never lies alone
        parts.discard("saw")                          # on the finished boards)
    if parts != set(ST_PARTS):
        x, y, w, hh = FEAT["st1"]["rect"]
        sl = (slice(y - 2, y + 14), slice(x - 1, x + w + 3))
        m = np.zeros((FH, FW), bool)
        m[sl] = True
        _paste(can, s3, m)
        stack_and_saw(can, parts)
    for part, (px_, py_), t_go in (("B", (210, 196), first_drop["h2"]),
                                   ("A", (220, 196), first_drop["h1"]),
                                   ("saw", (212, 202), first_drop["h1"])):
        if p >= t_go:                                 # a puff where each was picked up
            _puff(ov, px_, py_, (p - t_go) * 2.0, {"A": 177, "B": 182, "saw": 184}[part])
    covered = np.zeros((FH, FW), bool)
    edge_until = {}                                   # plank row -> p its core board lands
    for name in ("h2", "h1"):
        for (bx, by, bw, bh) in CORE_BOARDS[name]:
            key = -by if name == "h2" else by
            land = sched[name][key]
            k = by // 4
            edge_until[k] = max(edge_until.get(k, 0), land)
            dy, age = _drop_state(p, land)
            if dy is None:
                continue
            keeper = (bx, by, bw, bh) in S3_KEEPERS
            lvl, final = _weather(p, bx, by, keeper, land + 0.05)
            if dy == 0 and final:
                m = np.zeros((FH, FW), bool)
                m[by:by + bh, max(X0, bx):min(X1, bx + bw)] = True
                _paste(can, s3, m)
            else:
                fresh_board(can, bx, by, bw, bh, level=lvl, seam_old=False, dy=dy)
            if dy == 0:
                covered[by:by + bh, bx:bx + bw] = True
                _puff(ov, bx - 1, by + 3, age, bx * 7 + by)
                _puff(ov, bx + bw, by + 3, age, bx * 3 + by + 1)
    for pid, (bx, by, bw, bh), tone, gap in S2_BOARDS:   # the patches weather in
        lvl, final = _weather(p, bx, by, False, 0.3)
        m = np.zeros((FH, FW), bool)
        m[by:by + bh, max(X0, bx):min(X1, bx + bw)] = True
        if final:
            _paste(can, s3, m & ~EDGE_PX)
        elif lvl > 0:
            fresh_board(can, bx, by, bw, bh, tone=tone, level=lvl, seed=bx + by, gap_end=gap)
    # the cores' sawn edges stay until the board across that row has landed
    for yy in range(FH):
        k = yy // 4
        m = EDGE_PX[yy]
        if not m.any():
            continue
        land = max(edge_until.get(k, 0), edge_until.get(k - 1, 0) if yy % 4 == 0 else 0)
        if p < land - 1e-9:
            can.rgb[yy, m] = s2[yy, m, :3]
            can.a[yy, m] = s2[yy, m, 3] > 0
        else:
            lvl, final = _weather(p, 0, yy, False, land + 0.05)
            if final:
                can.rgb[yy, m] = s3[yy, m, :3]
                can.a[yy, m] = s3[yy, m, 3] > 0
    x, y, w, hh = FEAT["lb2"]["rect"]                # lb2: nailed down first, then weathers
    lv, final = _weather(p, 266, 180, False, 0.3)
    m = np.zeros((FH, FW), bool)
    m[y - 1:y + 5, max(X0, x):min(X1, x + w)] = True
    if final:
        _paste(can, s3, m)
    elif p < 0.08:
        pass                                          # still proud, as in s2
    else:
        _paste(can, s3, m)
        fresh_board(can, x, y, w, hh, tone=1, level=lv, seam_old=True)
        _puff(ov, x - 1, y + 3, (p - 0.08) * 2, 991)
    _blit(under, can.image())
    draw_plants(ov, PLANTS[2], ts, cover=covered)
    _blit(under, ov.px)


# ------------------------------------------------------------------ close-ups (absolute source px)

CLOSEUPS = [
    ("floor_hole_sun", 1, (FX + 18, FY + 84, 108, 66)),
    ("floor_hole_corner", 1, (FX + 228, FY + 142, 108, 74)),
    ("floor_hole_roof", 1, (FX + 226, FY + 6, 108, 64)),
    ("floor_hole_stove", 1, (FX + 196, FY + 66, 92, 58)),
    ("floor_hole_sill", 1, (FX + 60, FY + 186, 64, 30)),
    ("floor_broken_path", 1, (FX + 126, FY + 30, 70, 42)),
    ("floor_broken_tented", 1, (FX + 0, FY + 26, 70, 56)),
    ("floor_patch_sun", 2, (FX + 8, FY + 86, 120, 62)),
    ("floor_patch_corner", 2, (FX + 182, FY + 140, 152, 76)),
    ("floor_patch_roof", 2, (FX + 220, FY + 6, 114, 62)),
]

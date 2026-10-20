#!/usr/bin/env python
"""The pour sheet's drawing kit: the bucket, its gate and lever, the bottling stands, the jars,
the benches, the stream and the payoffs, at one pixel per art pixel (the room's grid, 3 screen
px an art px).

OFFLINE MOCKUPS ONLY (2026-10-16, the hive's visual overhaul). Imported by pour_mockup.py.

The buckets are the uncap sheet's own three (uncap_mockup.pail / oak_bucket / crock), so the
pour carries the very bucket the uncap step filled. Their small shut gate is left off here and
the working gate (with its lever, the thing the player holds) is drawn on in the same place,
bigger: the uncap sheet's little gate is this one seen shut.

Rules kept everywhere here (the game's settled style):
- whole art pixels, hard edges, stepped shading, no blur;
- colours are in-game swatches (look.SW, build_hive's BRASS / PINE / WEATHERED / PAPER /
  GINGHAM / PAINTS, the hut's oak ramp, the bark), or fixed mixes of two of them;
- every part ringed in the game's outline (24, 18, 17) on its own;
- the room's sun is top-left: lit faces left and up, shadows down and to the right.
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402

bh = look.bh
OUT = look.OUT
SW = look.SW
CLEAR = (0, 0, 0, 0)


def _c(t):
    return tuple(t[:3]) + (255,)


# --- ramps, darkest first ----------------------------------------------------------------------
BRASS = [_c(bh.BRASS[k]) for k in ("deep", "shade", "base", "lit")] + [SW["coin_pale"]]
# the hut's oak (build_shed_v2.WALL, the recycle box's "oak" ramp), seven steps
OAK = [_c(c) for c in ((38, 24, 22), (58, 36, 29), (78, 48, 36), (100, 64, 45), (122, 80, 54),
                       (168, 118, 76), (214, 166, 110))]
PINE = [_c(bh.PINE_DEEP), _c(bh.PINE_SHADE), _c(bh.PINE), _c(bh.PINE_LIT)]
BARK = [_c(bh.BARK[2]), _c(bh.BARK[1]), _c(bh.BARK[0])]
# the island hive's sky-blue paint (build_hive PAINTS["sky"]), deep .. lit
PAINT = [_c(c) for c in reversed(bh.PAINTS["sky"])]
# weathered boards (build_hive WEATHERED, the hive's old grey wood), deep .. lit
GREY = [_c(c) for c in reversed(bh.WEATHERED)]
HONEY = [SW["honey_deep"], SW["honey_mid"], SW["honey"], SW["honey_light"], SW["honey_shine"]]
GOLD = [SW["gold_shade"], SW["gold_deep"], SW["gold_low"], SW["gold"], SW["gold_lit"], SW["gold_pale"]]
COIN = [SW["coin_deep"], SW["coin_low"], SW["coin_shade"], SW["coin"], SW["coin_lit"], SW["coin_pale"]]
CORAL = [_c(bh.ROOF["deep"]), SW["roof_shade"], SW["roof"], SW["roof_lit"]]
GING = [_c(bh.GINGHAM_RED), _c(bh.GINGHAM_PINK), _c(bh.GINGHAM_WHITE)]
PAPER = _c(bh.PAPER)
PAPER_EDGE = _c(bh.PAPER_EDGE)
CREAM = _c(bh.CREAM)
GLASS = _c(bh.PAL["water_clean_light"])
GLASS_EDGE = _c(bh.PAL["water_clean_shallow"])
WHITE = SW["foam_light"]

# The land's shadow ink, measured off today's table shadow on the lawn: (61, 87, 37) -> (44, 63, 32)
# is a 0.42 mix towards (20, 30, 24); the fringe is half that, on a checker.
SHADE_INK = (20, 30, 24, 255)
SHADE_T = 0.42


def hsh(*v):
    """A stable hash of integers to [0, 1)."""
    h = 2166136261
    for n in v:
        h = ((h ^ (int(n) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFFFF) / float(0x1000000)


# =============================================================================================
# The sprite canvas
# =============================================================================================
class Spr:
    """A small RGBA canvas worked a pixel at a time. `put` with an alpha under 255 mixes onto
    what is there (a fixed mix of two swatches, never a gradient)."""

    def __init__(self, w, h):
        self.w, self.h = int(w), int(h)
        self.im = Image.new("RGBA", (self.w, self.h), CLEAR)
        self.p = self.im.load()

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if c is None or not (0 <= x < self.w and 0 <= y < self.h):
            return
        if len(c) == 4 and c[3] < 255:
            b = self.p[x, y]
            if b[3] == 0:
                self.p[x, y] = tuple(c)
                return
            t = c[3] / 255.0
            self.p[x, y] = tuple(int(round(b[i] * (1 - t) + c[i] * t)) for i in range(3)) + (255,)
            return
        self.p[x, y] = tuple(c[:3]) + (255,)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[int(x), int(y)]
        return CLEAR

    def has(self, x, y):
        return self.get(x, y)[3] > 0

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.put(xx, yy, c)

    def hline(self, x0, x1, y, c):
        for x in range(int(x0), int(x1) + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(int(y0), int(y1) + 1):
            self.put(x, y, c)

    def erase(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[int(x), int(y)] = CLEAR

    def paste(self, im, x, y):
        layer = Image.new("RGBA", self.im.size, CLEAR)
        layer.paste(im, (int(x), int(y)))
        self.im.alpha_composite(layer)

    def darken(self, x, y, t, toward=OUT):
        """Mix an opaque pixel `t` towards the outline ink (a cast shadow on a sprite)."""
        p = self.get(x, y)
        if p[3]:
            self.p[int(x), int(y)] = look.mix(p, toward, t)[:3] + (255,)

    def ringed(self):
        """The game's outline round everything opaque, the canvas one px bigger a side."""
        return look.inked(self.im)


def espan(cx, cy, hx, hy, y):
    """Row y of the ellipse (cx, cy, hx, hy): (left, right) inclusive, or None."""
    if hx <= 0 or hy <= 0:
        return None
    dy = (y + 0.5 - cy) / hy
    if abs(dy) >= 1.0:
        return None
    w = hx * math.sqrt(1.0 - dy * dy)
    lo = int(math.floor(cx - w + 0.5))
    hi = int(math.floor(cx + w - 0.5))
    if hi < lo:
        return None
    return lo, hi


def in_ell(cx, cy, hx, hy, x, y):
    s = espan(cx, cy, hx, hy, y)
    return s is not None and s[0] <= x <= s[1]


def grain_runs(s, x0, x1, y0, y1, col, seed, odds=0.08, long=(3, 7), skip=None):
    """Short horizontal grain dashes over a board's face, seeded (the hut's siding rule)."""
    rnd = random.Random(seed)
    for y in range(y0, y1 + 1):
        x = x0 + rnd.randint(0, 6)
        while x <= x1:
            if rnd.random() < odds * 6:
                n = rnd.randint(*long)
                for k in range(n):
                    if x + k <= x1 and (skip is None or not skip(x + k, y)):
                        s.put(x + k, y, col)
                x += n + rnd.randint(4, 12)
            else:
                x += rnd.randint(3, 9)


# =============================================================================================
# The bucket: the uncap sheet's own, its small shut gate left off (the pour's gate goes on).
# =============================================================================================
def bucket(option):
    """The uncap sheet's bucket for option A / B / C, without its small gate and without the
    run of honey the pail wears down its outside front (honey belongs inside the bucket and on
    the gate, never leaking down the wall). Returns the uncap's dict (body, front, bail, mouth,
    inner, foot, foot_half, deep, name) with 'gate_dx' (the gate's middle from the mouth's
    middle, as the uncap sheet put it) and 'taper' (how much narrower the honey's surface gets,
    in px, from the rim down to the bottom) added."""
    import uncap_mockup as um
    orig, orig_drip = bh.inked, um._drip_down

    def no_gate(im, *a, **k):
        # the uncap's gate is an 11 x 12 (pail, crock) or 10 x 13 (oak) Art, inked on its own
        if im.size in ((11, 12), (10, 13)):
            return Image.new("RGBA", (im.width + 2, im.height + 2), CLEAR)
        return orig(im, *a, **k)
    bh.inked = no_gate
    um._drip_down = lambda *a, **k: None
    try:
        b = um.BUCKETS[option]()
    finally:
        bh.inked = orig
        um._drip_down = orig_drip
    b["gate_dx"] = {"A": 14, "B": 13, "C": 14}[option]
    b["taper"] = {"A": 3.5, "B": 2.0, "C": 2.5}[option]
    return b


def _honey_geometry(mouth, inner, taper, level):
    """Where the honey's surface is for a fill `level` (1 = to the rim, 0 = the bottom), seen
    through the mouth: its middle and half sizes. The eye looks down into the bucket, so the
    surface is a smaller ellipse the deeper it lies (`taper` px narrower a side at the bottom,
    plus a share of the mouth for the depth) and its middle drops from just under the far rim
    to under the near rim. At 0.55 its widest row still shows (round ends, wall either side);
    at 0.3 only its far half shows, a dome under the far inside wall with the near rim in
    front of it; at 0 it is out of sight."""
    mx, my = mouth
    ix, iy = inner
    sx = (ix - 0.5) * (0.94 - 0.26 * (1.0 - level)) - taper * (1.0 - level)
    sy = iy * sx / ix
    sx0 = (ix - 0.5) * 0.68 - taper
    sy0 = iy * sx0 / ix
    return mx, my - 1.0 + (1.0 - level) ** 1.5 * (iy + sy0 + 1.0), sx, sy


def bucket_honey(s, mouth, inner, level, taper=3.0, was=0.55):
    """The honey left in the bucket on a 1x Spr, clipped to the bucket's opening and kept a
    row off the near rim's inner lip (the rim stays in front of it).

    level > 0.06: the surface, an ellipse following the taper at its depth: a lit meniscus
    along its far edge, a shine streak left of middle, a step darker under the near rim and
    at the walls. Above it on the far inside wall a faint tide mark where it stood (`was`) and
    two short runs sliding down from it.
    level <= 0.06 (scraped out): no surface, two or three tapering runs down the far inside
    wall (1-2 px, lit edge, a bead at the foot, different lengths) and a small puddle in the
    bottom's curve just showing over the near lip. Returns the surface's middle row."""
    mx, my = mouth
    ix, iy = inner

    def opening(x, y):
        return in_ell(mx, my, ix, iy, x, y) and in_ell(mx, my, ix, iy, x, y + 1)

    def far_wall(u):
        """The first row under the far rim's shadow at u across the mouth (-1..1)."""
        return int(math.floor(my - iy * math.sqrt(max(0.0, 1 - u * u)))) + 2

    empty = level <= 0.06
    cx, cy, sx, sy = _honey_geometry(mouth, inner, taper, max(level, 0.0))

    def surf(x, y):
        return opening(x, y) and in_ell(cx, cy, sx, sy, x, y)

    y_lo, y_hi = int(my - iy - 2), int(my + iy + 3)
    x_lo, x_hi = int(mx - ix - 2), int(mx + ix + 3)
    if not empty:
        # the tide mark where the honey stood: a dotted film along that surface's far edge
        tx, ty, tsx, tsy = _honey_geometry(mouth, inner, taper, was)
        for x in range(x_lo, x_hi):
            for y in range(y_lo, y_hi):
                if opening(x, y) and in_ell(tx, ty, tsx, tsy, x, y) and not in_ell(tx, ty, tsx, tsy, x, y - 1):
                    if not surf(x, y) and (x % 3) != 2:
                        s.put(x, y, HONEY[1][:3] + (150,))
                    break
        for y in range(y_lo, y_hi):
            for x in range(x_lo, x_hi):
                if not surf(x, y):
                    continue
                c = HONEY[2]
                if not surf(x, y - 1):
                    c = HONEY[3]                         # the meniscus on the far edge
                if not opening(x, y + 2):
                    c = HONEY[1]                         # under the near rim's shadow
                if not (surf(x - 1, y) and surf(x + 1, y)):
                    c = HONEY[0]                         # where it meets the wall
                s.put(x, y, c)
        srow = int(cy - sy * 0.45)
        for x in range(int(cx - sx * 0.6), int(cx - sx * 0.18)):
            if surf(x, srow) and surf(x, srow - 1):
                s.put(x, srow, HONEY[4])
        return cy
    # --- scraped out: runs on the far inside wall and a puddle in the bottom -------------------
    for u, long, wob in ((-0.5, 8, 1), (-0.06, 5, -1), (0.42, 10, 1)):
        x0 = int(mx + u * ix)
        top = far_wall(u)
        foot = top + long
        ok = True
        for y in range(top, foot):
            t = (y - top) / max(1, long - 1)
            x = x0 + (wob if t > 0.5 else 0)           # a wobble half way down
            if not opening(x, y):
                ok = False
                break
            # a thin film (a step darker, it is honey on the wall) thickening towards the bead
            s.put(x, y, HONEY[1] if t < 0.6 else HONEY[2])
            if t >= 0.6:
                s.put(x + 1, y, HONEY[0])
        if ok:
            x = x0 + wob
            for dx, dy, c in ((0, -1, HONEY[3]), (-1, 0, HONEY[3]), (0, 0, HONEY[4]), (1, 0, HONEY[2]),
                              (-1, 1, HONEY[1]), (0, 1, HONEY[2]), (1, 1, HONEY[0]), (0, 2, HONEY[0])):
                if opening(x + dx, foot + dy):
                    s.put(x + dx, foot + dy, c)
    # the puddle left in the bottom's curve: the top of a little pool just over the near lip
    px_, py_ = mx + 1.5, my + iy - 0.5
    phx, phy = ix * 0.36, 2.6
    for y in range(int(py_ - 4), int(py_ + 2)):
        for x in range(int(px_ - ix), int(px_ + ix)):
            if opening(x, y) and in_ell(px_, py_, phx, phy, x, y):
                c = HONEY[2]
                if not in_ell(px_, py_, phx, phy, x, y - 1):
                    c = HONEY[3]
                if not (in_ell(px_, py_, phx, phy, x - 1, y) and in_ell(px_, py_, phx, phy, x + 1, y)):
                    c = HONEY[0]
                if not opening(x, y + 2):
                    c = HONEY[1] if c != HONEY[0] else c
                s.put(x, y, c)
    sh = int(py_ - phy) + 1
    for x in range(int(px_ - phx * 0.55), int(px_ - phx * 0.1)):
        if opening(x, sh) and in_ell(px_, py_, phx, phy, x, sh - 1):
            s.put(x, sh, HONEY[4])
    return py_


# =============================================================================================
# The gate and its lever. A: a brass honey gate (a slide in a square housing); B: a brass barrel
# tap; C: an oak spigot. All three take the same lever: hold it and it swings to the right.
# =============================================================================================
OAK5 = [OAK[1], OAK[2], OAK[4], OAK[5], OAK[6]]          # deep, shade, base, lit, hi
GATE_STYLE = {"A": ("gate", BRASS), "B": ("tap", BRASS), "C": ("tap", OAK5)}


def honey_gate(kind="gate", ramp=BRASS):
    """The gate front-on. Returns (ringed sprite, anchors): 'top' (where it meets the bucket),
    'pivot' (the lever's) and 'spout' (the lowest pixel of the honey's way out), in the ringed
    sprite's pixels."""
    d, sh, b, l, hi = ramp
    s = Spr(18, 22)
    if kind == "gate":
        # the flange bolted to the bucket: a wider plate at the top with two bolt heads
        for y in range(0, 4):
            for x in range(1, 17):
                c = l if y == 0 else b if x < 12 else sh
                s.put(x, y, c)
        s.put(3, 1, d)
        s.put(14, 1, d)
        s.put(3, 2, hi)
        # the housing: a square body lit down its left, the slide's channel down the middle
        for y in range(4, 15):
            for x in range(3, 15):
                u = (x - 3) / 11.0
                s.put(x, y, l if u < 0.18 else b if u < 0.68 else sh)
        for y in range(5, 14):
            s.put(8, y, d)
            s.put(9, y, l if y < 9 else b)
            s.put(10, y, sh)
        s.hline(3, 14, 14, sh)
        # the spout: a short square nose stepping down to its mouth
        for y, (lo, hi_) in zip(range(15, 21), ((5, 12), (5, 12), (6, 11), (6, 11), (7, 10), (7, 10))):
            for x in range(lo, hi_ + 1):
                u = (x - lo) / max(1, hi_ - lo)
                s.put(x, y, l if u < 0.25 else b if u < 0.65 else sh)
        s.hline(7, 10, 20, d)
        top, pivot, spout = (9, 1), (9, 6), (9, 21)
    else:
        # a round flange, the barrel coming out of it, the spout turned down
        for y in range(0, 12):
            sp = espan(9, 6, 7.5, 6, y)
            if sp:
                for x in range(sp[0], sp[1] + 1):
                    u = (x - sp[0]) / max(1, sp[1] - sp[0])
                    c = l if u < 0.3 else b if u < 0.7 else sh
                    if y <= 1:
                        c = hi
                    s.put(x, y, c)
        for y in range(3, 10):
            sp = espan(9, 6.5, 4, 3.5, y)
            if sp:
                for x in range(sp[0], sp[1] + 1):
                    s.put(x, y, l if x < 8 else b)
        s.put(7, 4, hi)
        for y in range(10, 20):
            lo, hi_ = (6, 11) if y < 16 else (7, 10)
            for x in range(lo, hi_ + 1):
                u = (x - lo) / max(1, hi_ - lo)
                s.put(x, y, l if u < 0.3 else b if u < 0.7 else sh)
        for x in range(5, 13):
            s.put(x, 12, sh if x > 9 else b)
        s.hline(7, 10, 19, d)
        top, pivot, spout = (9, 1), (9, 6), (9, 20)
    out = s.ringed()
    return out, {"top": (top[0] + 1, top[1] + 1), "pivot": (pivot[0] + 1, pivot[1] + 1),
                 "spout": (spout[0] + 1, spout[1] + 1)}


LEVER_ARM = 14                 # the bar from the pivot to the grip
LEVER_GRIP = 8                 # the grip's length; it is 6 px across
LEVER_LONG = LEVER_ARM + LEVER_GRIP


def lever(turn, option="A", cue=False):
    """The lever off the gate's pivot, `turn` 0 upright (shut) to 1 a quarter turned to the
    right (open): a 3 px bar 14 long, a fat 8 x 6 grip with a rounded knob end, lit on its
    upper left, ringed. A and B: a brass bar with an oak grip; C: oak with a cream grip.
    cue: the shut lever asks to be held (a glint on the knob, a pair of wobble ticks either
    side of the grip). Returns (ringed sprite, pivot in it, the grip's middle in it)."""
    n = 64
    s = Spr(n, n)
    c0 = n / 2.0
    a = turn * math.pi * 0.5
    d = (math.sin(a), -math.cos(a))
    side = (math.cos(a), math.sin(a))
    bar = OAK5 if option == "C" else BRASS
    for y in range(n):
        for x in range(n):
            px, py = x + 0.5 - c0, y + 0.5 - c0
            along = px * d[0] + py * d[1]
            across = px * side[0] + py * side[1]
            if along < -1.0 or along > LEVER_LONG:
                continue
            grip = along > LEVER_ARM
            half = 3.0 if grip else 1.5
            # the knob: the grip's end rounded off
            if grip and along > LEVER_LONG - 2.0 and abs(across) > 3.0 - (along - (LEVER_LONG - 2.0)) * 1.2:
                continue
            if grip and along < LEVER_ARM + 1.0 and abs(across) > 2.2:
                continue                                  # a ferrule step where it meets the bar
            if abs(across) > half:
                continue
            if grip:
                ring_ = LEVER_ARM + 1.0 < along < LEVER_ARM + 2.0
                if option == "C":
                    c = CREAM if across < -1.2 else PAPER if across < 1.2 else PAPER_EDGE
                else:
                    c = OAK[6] if across < -1.2 else OAK[5] if across < 1.2 else OAK[4]
                if ring_:
                    c = bar[2]                            # the brass (or oak) ferrule
            else:
                c = bar[4] if across < -0.6 else bar[2] if across < 0.6 else bar[1]
            s.put(x, y, c)
    for y in range(n):
        for x in range(n):
            r = math.hypot(x + 0.5 - c0, y + 0.5 - c0)
            if r <= 3.2:
                s.put(x, y, bar[1] if r > 2.0 else bar[3])
    s.put(int(c0) - 1, int(c0) - 1, bar[4])
    out = s.ringed()
    gm = (c0 + d[0] * (LEVER_ARM + LEVER_GRIP / 2.0), c0 + d[1] * (LEVER_ARM + LEVER_GRIP / 2.0))
    if cue:
        o = Spr(out.width, out.height)
        o.paste(out, 0, 0)
        kx, ky = int(c0 + d[0] * (LEVER_LONG - 3) + side[0] * -2) + 1, int(c0 + d[1] * (LEVER_LONG - 3) + side[1] * -2) + 1
        for dx, dy, c in ((0, 0, WHITE), (-1, 0, GOLD[5]), (0, -1, GOLD[5])):
            o.put(kx + dx, ky + dy, c)
        gx, gy = int(gm[0]) + 1, int(gm[1]) + 1
        for sgn in (-1, 1):                               # the wobble ticks, foam white
            for k in range(3):
                o.put(gx + sgn * 6, gy - 1 + k, WHITE if k != 1 else SW["foam"])
            o.put(gx + sgn * 8, gy, WHITE)
        out = o.im
    return out, (int(c0) + 1, int(c0) + 1), (int(gm[0]) + 1, int(gm[1]) + 1)


# =============================================================================================
# The jar: glass ringed in ink, honey inside a painted px at a time, a gingham lid tied with
# twine, a paper label. Two layers so the stream can fall inside the glass: `back` (the glass's
# tint and the honey) and `front` (the outline, the glass's edges and shine, label, lid).
# =============================================================================================
JAR_W, JAR_H = 24, 40          # body canvas; the ringed jar is 26 x 42, feet on its last row
JAR_NECK = 8                   # the neck's top row (the lid sits over rows 0..10)
JAR_IN = (12, 38)              # the honey's room: top row, bottom row
JAR_FEET = (13, 41)            # in the ringed jar
JAR_LINE = 0.86                # the dashed fill line (fill share)


def _jar_rows():
    rows = {}
    for y in range(JAR_NECK, JAR_H):
        if y <= 10:
            hw = 9
        elif y == 11:
            hw = 10.5
        elif y == 12:
            hw = 11.5
        elif y <= 37:
            hw = 12
        elif y == 38:
            hw = 11.5
        else:
            hw = 10.5
        rows[y] = (int(12 - hw), int(12 + hw) - 1)
    return rows


JAR_ROWS = _jar_rows()


def jar_surface(fill):
    """The honey's top row in the body canvas for a fill of 0..1 (1 = up to the shoulder)."""
    lo, hi = JAR_IN
    return int(round(hi - (hi - lo) * min(max(fill, 0.0), 1.0)))


def jar_parts(fill, lid=True, label="hex", glow=False, line=False):
    """The jar in two ringed layers (26 x 42), feet on (13, 41). label: None, 'hex' (the
    hive's honey hex, today's label) or 'crown' (the harvest's gold crown stamped on). glow:
    the honey a step lighter all through (a finished jar in the payoff). line: the dashed fill
    line on the glass."""
    back = Spr(JAR_W, JAR_H)
    front = Spr(JAR_W, JAR_H)
    hon = HONEY[1:] + [WHITE] if glow else HONEY
    surface = jar_surface(fill) if fill > 0 else JAR_H + 5
    for y, (l, r) in JAR_ROWS.items():
        for x in range(l + 1, r):
            u = (x - l) / max(1, r - l)
            climb = 1 if (x - l <= 2 or r - x <= 2) else 0
            if y >= JAR_IN[0] and y >= surface - climb:
                d = (y - surface) / max(1.0, JAR_IN[1] - surface)
                if y == surface - climb:
                    c = hon[4] if 0.2 < u < 0.75 else hon[3]
                elif d < 0.18:
                    c = hon[3]
                elif d < 0.6:
                    c = hon[2]
                else:
                    c = hon[1]
                if u < 0.16 and y > surface:
                    c = hon[3]
                if u > 0.84 and y > surface + 1:
                    c = hon[1]
                if y >= JAR_IN[1]:
                    c = hon[0] if u > 0.3 else hon[1]
                back.put(x, y, c)
            else:
                back.put(x, y, GLASS[:3] + (34,))     # empty glass: the room shows, one faint step
    # the inside reads hollow: the base's back curve and the far wall's edge, where empty
    for x in range(4, 20):
        u = (x + 0.5 - 12) / 8.5
        y = int(round(36 - 2.2 * math.sqrt(max(0.0, 1 - u * u))))
        if y < surface - 1:
            back.put(x, y, look.mix(GLASS_EDGE, OUT, 0.3)[:3] + (170,))
            back.put(x, y + 1, GLASS[:3] + (110,))
    for y in range(13, 35):
        if y < surface - 1:
            back.put(JAR_ROWS[y][1] - 3, y, GLASS_EDGE[:3] + (120,))
    if not lid:
        # the open mouth: the far lip seen through, a dark ring inside the neck
        for x in range(4, 20):
            back.put(x, JAR_NECK + 1, look.mix(GLASS_EDGE, OUT, 0.35)[:3] + (210,))
    for y, (l, r) in JAR_ROWS.items():
        front.put(l, y, WHITE if y < 30 else GLASS)
        front.put(r, y, GLASS_EDGE)
    for y in range(14, 33):
        front.put(JAR_ROWS[y][0] + 2, y, WHITE)
    for y in range(16, 21):
        front.put(JAR_ROWS[y][0] + 3, y, WHITE[:3] + (190,))
    for y in range(25, 31):
        front.put(JAR_ROWS[y][1] - 2, y, WHITE[:3] + (150,))
    for x in range(4, 20):
        front.put(x, JAR_NECK, WHITE if x < 12 else GLASS)
        front.put(x, JAR_NECK + 2, GLASS_EDGE[:3] + (200,))
    for x in range(2, 22):
        front.put(x, 11, GLASS_EDGE[:3] + (170,))
    for x, y in ((3, 12), (4, 12), (5, 12), (4, 11), (5, 11), (6, 11)):
        front.put(x, y, WHITE)                    # the shoulder catching the sun
    if line:
        ly = jar_surface(JAR_LINE)
        for x in range(2, 22):
            if (x // 2) % 2 == 0:
                front.put(x, ly, SW["coin_pale"])
    if label:
        _label(front, label)
    if lid:
        _lid(front)
    sil = Image.new("RGBA", (JAR_W, JAR_H), CLEAR)
    for y, (l, r) in JAR_ROWS.items():
        for x in range(l, r + 1):
            sil.putpixel((x, y), OUT)
    sil.alpha_composite(front.im)
    ring = look.inked(sil)
    ring_only = Image.new("RGBA", ring.size, CLEAR)
    rp, op = ring.load(), ring_only.load()
    for y in range(ring.height):
        for x in range(ring.width):
            inside = 1 <= x <= JAR_W and 1 <= y <= JAR_H and sil.getpixel((x - 1, y - 1))[3] > 0
            if rp[x, y][3] and not inside:
                op[x, y] = rp[x, y]
    b = Image.new("RGBA", ring.size, CLEAR)
    b.alpha_composite(back.im, (1, 1))
    f = Image.new("RGBA", ring.size, CLEAR)
    f.alpha_composite(front.im, (1, 1))
    f.alpha_composite(ring_only)
    return b, f


LABEL_BOX = (5, 18, 19, 29)    # x0, y0, x1, y1 inclusive, in the body canvas

# A's payoff: the label turns to a dark amber band with the harvest's crown foil-stamped on it
# (the queen's crown a size up): light gold foil, lit on its upper left, ringed in the outline
# so it reads at 1x, a coral jewel. 9 x 6, ringed 11 x 8, on the 15 x 12 label.
STAMP = [
    "p...p...p",
    "pp.ppp.pp",
    "ppppppppp",
    "pppLRLppp",
    "lllllllll",
    "ddddddddd",
]

# The jar's mark, the same on the HUD's jar plate and the island shelf: a honeycomb cell in the
# label's red with a drop of honey in it (5 x 4).
MARK_CELL = [".RRR.",
             "RhHhR",
             "RHhHR",
             ".RRR."]


def _label(s, kind):
    x0, y0, x1, y1 = LABEL_BOX
    foil = kind == "crown"
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if foil:
                c = HONEY[1]
                if x == x0:
                    c = HONEY[2]
                if y in (y0, y1) or x == x1:
                    c = HONEY[0]
            else:
                c = PAPER
                if x == x1:
                    c = PAPER_EDGE
                if y in (y0, y1):
                    c = GING[0] if x < x1 else look.mix(GING[0], OUT, 0.25)
            s.put(x, y, c)
    if foil:
        st = Spr(len(STAMP[0]), len(STAMP))
        for j, row in enumerate(STAMP):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                if ch == "R":
                    c = CORAL[2]
                elif ch == "L":
                    c = GOLD[4]
                elif ch == "d":
                    c = GOLD[2]
                elif ch == "l":
                    c = GOLD[4]
                else:
                    up = j == 0 or STAMP[j - 1][i] == "."
                    left = i == 0 or row[i - 1] == "."
                    c = GOLD[5] if (up or left or i < 3) else GOLD[4]
                    if j == 0:
                        c = WHITE
                st.put(i, j, c)
        ring = st.ringed()
        s.paste(ring, (x0 + x1) // 2 - ring.width // 2 + 1, y0 + 2)
    else:
        look.grid(MARK_CELL, {"R": GING[0], "h": HONEY[3], "H": HONEY[2]},
                  (x0 + x1) // 2 - 2, (y0 + y1) // 2 - 1, into=s.im)


def _lid(s):
    """The gingham cloth over the neck: its top seen a little from above, the skirt hanging in
    a zigzag hem, tied round the neck with twine and a bow."""
    for y in range(0, 10):
        top = espan(12, 3.5, 11, 3.5, y)
        if y <= 4 and top:
            l, r = top
        elif 4 < y <= 9:
            l, r = 1, 22
        else:
            continue
        for x in range(l, r + 1):
            if y == 9 and (x // 2) % 2 == 1:
                continue
            check = ((x // 2) % 2) + ((y // 2) % 2)
            c = GING[0] if check == 2 else GING[1] if check == 1 else GING[2]
            u = (x - 1) / 21.0
            if y > 4 and u > 0.7:
                c = look.mix(c, OUT, 0.18)
            if y > 4 and u < 0.12:
                c = look.mix(c, WHITE, 0.25)
            s.put(x, y, c)
    for x in range(3, 21):
        s.put(x, 8, OAK[3] if x < 14 else OAK[2])
    bow = ["T.T", "TKT", "T.T"]
    look.grid(bow, {"T": OAK[5], "K": OAK[3]}, 11, 7, into=s.im)


def jar(fill, **kw):
    b, f = jar_parts(fill, **kw)
    b.alpha_composite(f)
    return b


def gold_rim(im, col=None):
    """The finds' own trick (LakeGrid's rim): a one-px gold ring round the outside of a sprite,
    so a finished jar reads as treasure. Returns the sprite one px bigger a side."""
    col = col or GOLD[4]
    out = Image.new("RGBA", (im.width + 2, im.height + 2), CLEAR)
    out.alpha_composite(im, (1, 1))
    a = out.getchannel("A")
    px, ap = out.load(), a.load()
    ring = []
    for y in range(out.height):
        for x in range(out.width):
            if ap[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < out.width and 0 <= yy < out.height and ap[xx, yy]:
                    ring.append((x, y))
                    break
    for x, y in ring:
        px[x, y] = col
    return out


# =============================================================================================
# The stream of honey from the spout into the jar, and where it lands
# =============================================================================================
def stream(layer, x, y0, y1, open_=0.7):
    """A gooey stream from (x, y0) down to row y1: widest off the spout and narrowing, lit on
    its left, a wobble growing as it falls. Straight onto a 1x layer image."""
    s = layer.load()
    wide0 = 3 + 3 * open_
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        w = max(3, int(round(wide0 * (1 - 0.4 * t ** 0.6))))
        wob = int(round(math.sin(y * 0.15 + 0.6) * 1.2 * t * t))
        lft = int(round(x - w / 2.0)) + wob
        for k in range(w):
            u = k / max(1, w - 1)
            if k == 0:
                c = HONEY[1]
            elif k == w - 1:
                c = HONEY[0]
            elif u < 0.4:
                c = HONEY[4] if (y // 3) % 3 else HONEY[3]
            elif u < 0.7:
                c = HONEY[3]
            else:
                c = HONEY[2]
            if 0 <= lft + k < layer.width and 0 <= y < layer.height:
                s[lft + k, y] = c


def coils(layer, x, y, wide=9):
    """Where the stream lands on the jar's honey (the game's _draw_coils): a mound in the
    surface's own light under the stream, a fold of the rope each side sliding out along the
    surface (a hump lit on top with its shadow under it), a darker swirl sinking under."""
    s = layer.load()

    def put(xx, yy, c):
        if 0 <= xx < layer.width and 0 <= yy < layer.height:
            s[xx, yy] = c
    # the mound: 7 / 5 / 3 wide, three rows up from the surface
    for k, half in enumerate((3, 2, 1)):
        for dx in range(-half, half + 1):
            put(x + dx, y - k, HONEY[4] if (k == 2 or abs(dx) == half and k > 0) else HONEY[3])
    put(x - 1, y - 2, WHITE)
    # the folds: a hump each side, then a smaller one further out
    for side in (-1, 1):
        for dist, big in ((5, True), (8, False)):
            hx = x + side * dist
            put(hx, y - 1, HONEY[4])
            if big:
                put(hx - 1, y - 1, HONEY[3])
                put(hx + 1, y - 1, HONEY[3])
                put(hx - 1, y, HONEY[4])
                put(hx + 1, y, HONEY[3])
            put(hx, y, HONEY[3])
            put(hx, y + 1, HONEY[1])                  # the fold's own shadow on the surface
            if big:
                put(hx + side, y + 1, HONEY[1])
    # the swirl sinking under, a step darker
    for dx, dy in ((-3, 3), (-2, 4), (-1, 4), (0, 4), (1, 3), (2, 3), (3, 2)):
        put(x + dx, y + dy, HONEY[1])


def dim_inside(layer, y_from):
    """The stream from row y_from down is behind the jar's front glass: every honey pixel a
    step dimmer (the glass's highlights go over it after)."""
    s = layer.load()
    step = {tuple(HONEY[i][:3]): HONEY[max(0, i - 1)] for i in range(len(HONEY))}
    step[tuple(WHITE[:3])] = HONEY[4]
    for y in range(max(0, y_from), layer.height):
        for x in range(layer.width):
            p = s[x, y]
            if p[3] and tuple(p[:3]) in step:
                s[x, y] = step[tuple(p[:3])]


def gate_bead(layer, x, y):
    """A drop of honey hanging off the shut spout, ringed."""
    b = Spr(3, 4)
    look.grid([".H.", "LHM", "LHM", ".M."], {"H": HONEY[2], "L": HONEY[4], "M": HONEY[1]}, into=b.im)
    layer.alpha_composite(b.ringed(), (x - 2, y - 1))


# =============================================================================================
# The bottling stands. Each is drawn on a full-size 1x layer (the room grid) in parts, every
# part ringed on its own, back to front. Returns the anchors the scene needs:
#   'top_face' (y of the top surface's front row: the bucket's foot stands one row above it),
#   'shelf' (y the jars' feet stand on), 'inner' (x0, x1 between the front legs), 'feet' (y).
# =============================================================================================
def _ramp(kind):
    """A board ramp: hi, lit, base, mid, shade, deep."""
    if kind == "oak":
        return {"hi": OAK[6], "lit": OAK[5], "base": OAK[4], "mid": OAK[3], "shade": OAK[2],
                "deep": OAK[1]}
    if kind == "paint":
        return {"hi": PAINT[3], "lit": PAINT[2], "base": look.mix(PAINT[2], PAINT[1], 0.5),
                "mid": PAINT[1], "shade": PAINT[0], "deep": look.mix(PAINT[0], OUT, 0.35)}
    return {"hi": GREY[3], "lit": look.mix(GREY[3], GREY[2], 0.5), "base": GREY[2],
            "mid": look.mix(GREY[2], GREY[1], 0.5), "shade": GREY[1], "deep": GREY[0]}


def _paste_ringed(lay, s, x, y):
    lay.alpha_composite(s.ringed(), (int(x) - 1, int(y) - 1))


def _wear(s, x, y, kind):
    """Chipped paint showing the pine under it (the island hive's worn sky blue)."""
    if kind == "paint" and s.has(x, y):
        s.put(x, y, PINE[3] if (x + y) % 3 else PINE[2])


# The island hut's shutters' heart, cut clean through a painted apron (the room shows through).
HEART = [".HHH.HHH.",
         "HHHHHHHHH",
         "HHHHHHHHH",
         "HHHHHHHHH",
         ".HHHHHHH.",
         "..HHHHH..",
         "...HHH...",
         "....H...."]


def cut_heart(s, x, y):
    """Cut the heart out of a sprite at (x, y) (its top-left): the pixels go clear, so once the
    piece is ringed the hole wears the outline and the room shows through it."""
    for j, row in enumerate(HEART):
        for i, ch in enumerate(row):
            if ch == "H":
                s.erase(x + i, y + j)


def _board(w, h, r, kind, seed, top_rows=0, arris=True, ends=True):
    """A board front-on: `top_rows` of its top face seen from above (lit), then its front edge
    (base, grain, a shaded last row). The front arris (the last top row) is the lightest line,
    its left end shows lit end grain. Paint wears at the arris and the ends."""
    s = Spr(w, h)
    for y in range(h):
        for x in range(w):
            if y < top_rows:
                c = r["lit"]
                if arris and y == top_rows - 1:
                    c = r["hi"]
            else:
                c = r["base"]
                if y == h - 1:
                    c = r["mid"]
            s.put(x, y, c)
    if top_rows:
        grain_runs(s, 1, w - 2, 0, top_rows - 2, r["base"], seed, odds=0.07)
        # a seam between two boards along the top
        if top_rows >= 6:
            seam = top_rows // 2 - 1
            s.hline(0, w - 1, seam, r["mid"])
            s.hline(0, w - 1, seam + 1, r["lit"])
    grain_runs(s, 2, w - 3, top_rows + 1, h - 2, r["mid"], seed + 7, odds=0.06)
    if ends:
        for y in range(top_rows, h - 1):
            s.put(0, y, r["lit"])
            s.put(w - 1, y, r["mid"])
        if h - top_rows >= 4:
            s.put(1, top_rows + (h - top_rows) // 2, r["mid"])
    if kind == "paint":
        rnd = random.Random(seed + 3)
        x = rnd.randint(2, 9)
        while x < w - 2:                      # chips along the front arris, in short runs
            if top_rows:
                for k in range(rnd.randint(1, 3)):
                    _wear(s, x + k, top_rows - 1, kind)
            x += rnd.randint(9, 22)
        for x in range(w):
            if rnd.random() < 0.035:
                _wear(s, x, h - 1, kind)
        for y in range(top_rows, h):
            if rnd.random() < 0.3:
                _wear(s, 0, y, kind)
    return s


def _leg(w, h, r, kind, seed, pegs=(), splay=0.0):
    """A square leg front-on, lit down its left arris, shaded right; pegs are dark dowel ends.
    `splay` (px a row, + leans out to the right going down, - to the left) shears it in whole
    pixels, a step every 1/|splay| rows, so the outline stair-steps like any pixel slope."""
    shift = int(abs(splay) * h) + 1
    s = Spr(w + shift, h)
    cols = [r["hi"], r["lit"]] + [r["base"]] * (w - 4) + [r["mid"], r["shade"]]
    rnd = random.Random(seed)
    for y in range(h):
        off = int(abs(splay) * y)
        ox = off if splay > 0 else shift - off - 1
        for x in range(w):
            c = cols[x]
            if y == 0:
                c = r["shade"]
            elif y == 1:
                c = r["mid"]
            elif y == h - 1:
                c = r["deep"]
            elif x == w // 2 and rnd.random() < 0.08:
                c = r["mid"]
            s.put(ox + x, y, c)
        if y in pegs:
            s.put(ox + w // 2, y, r["deep"])
            s.put(ox + w // 2 - 1, y - 1, r["hi"] if kind != "paint" else PINE[3])
        if kind == "paint" and (y > h - 6 or rnd.random() < 0.12) and 1 < y < h - 1:
            _wear(s, ox, y, kind)
            if y > h - 6:
                _wear(s, ox + rnd.randint(1, w - 1), y, kind)
    return s


def leg_x(x, row, splay):
    """Where a splayed leg's left column is `row` rows below its top."""
    off = int(abs(splay) * row)
    return x + off if splay > 0 else x - off


def table_stand(lay, x0, w, top, feet, shelf, kind="oak", heart=False, splay=1.0 / 17):
    """A sturdy bottling table: a thick top of two boards, an apron under it (a heart cut out of
    it on the painted one, the island hive's shutters' heart), corner brackets, four square
    legs splayed a little (the back two seen behind, darker, braced by a stretcher), a low shelf
    the jars stand on between the front legs, dowel pegs at the joints."""
    r = _ramp(kind)
    TOP_ROWS, EDGE = 8, 5
    LEG = 7
    edge_y = top + TOP_ROWS                    # the top's front edge's first row
    apron_y = edge_y + EDGE                    # the apron's first row
    lx0, lx1 = x0 + 3, x0 + w - 3 - LEG        # the front legs' left columns, at the top
    lh = feet - edge_y + 1
    srow = shelf - edge_y                      # the shelf's row down the legs
    # back legs: inset, splayed less, seen between the apron and the shelf; a stretcher
    # between them half way down
    bl = [lx0 + 10, lx1 - 10]
    bh_ = shelf + 4 - apron_y
    for i, bx in enumerate(bl):
        sp = -splay * 0.6 if i == 0 else splay * 0.6
        s = Spr(5 + int(abs(sp) * bh_) + 1, bh_)
        for y in range(bh_):
            off = int(abs(sp) * y)
            ox = off if sp > 0 else s.w - 5 - off
            for x in range(5):
                s.put(ox + x, y, [r["mid"], r["shade"], r["shade"], r["deep"], r["deep"]][x])
        _paste_ringed(lay, s, bx if sp > 0 else bx - (s.w - 5), apron_y)
    mid_y = apron_y + (shelf - apron_y) // 2
    st = Spr(bl[1] - bl[0] - 2, 4)
    for y in range(4):
        for x in range(st.w):
            st.put(x, y, r["shade"] if y < 3 else r["deep"])
    st.hline(0, st.w - 1, 0, r["mid"])
    _paste_ringed(lay, st, bl[0] + 4, mid_y)
    # the shelf: its top face (5 rows) the jars stand on, its front edge (4 rows); its ends run
    # in under the legs at that height
    sx0 = leg_x(lx0, srow, -splay) + 3
    sx1 = leg_x(lx1, srow, splay) + LEG - 3
    sh = _board(sx1 - sx0, 9, r, kind, 41, top_rows=5)
    _paste_ringed(lay, sh, sx0, shelf - 2)
    # the apron, between the legs, its first row in the top's shadow
    ax0, ax1 = lx0 + LEG, lx1
    APRON = 11 if heart else 6
    ap = _board(ax1 - ax0, APRON, r, kind, 23, top_rows=0, ends=False)
    ap.hline(0, ap.w - 1, 0, r["shade"])
    if heart:
        cut_heart(ap, ap.w // 3 - 5, 2)
    _paste_ringed(lay, ap, ax0, apron_y)
    # corner brackets under the apron, inside each front leg
    for side in (0, 1):
        b = Spr(7, 7)
        for y in range(7):
            for x in range(7):
                inside = (x + y <= 6) if side == 0 else ((6 - x) + y <= 6)
                if inside:
                    edge = (x + y == 6) if side == 0 else ((6 - x) + y == 6)
                    b.put(x, y, r["mid"] if edge else r["base"] if y > 0 else r["shade"])
        bx = ax0 if side == 0 else ax1 - 7
        _paste_ringed(lay, b, bx, apron_y + APRON)
    # the front legs, splayed out, pegged where the apron and the shelf meet them
    for i, lx in enumerate((lx0, lx1)):
        sp = -splay if i == 0 else splay
        leg = _leg(LEG, lh, r, kind, 61 + i, pegs=(EDGE + 2, srow + 2), splay=sp)
        _paste_ringed(lay, leg, lx if sp > 0 else lx - (leg.w - LEG), edge_y)
    # the top, over everything
    tp = _board(w, TOP_ROWS + EDGE, r, kind, 11, top_rows=TOP_ROWS)
    _paste_ringed(lay, tp, x0, top)
    return {"top_face": top + TOP_ROWS - 1, "shelf": shelf + 2,
            "inner": (leg_x(lx0, srow, -splay) + LEG, leg_x(lx1, srow, splay) - 1),
            "feet": feet, "edge": (edge_y, edge_y + EDGE - 1), "box": (x0 - 6, top, x0 + w + 6, feet)}


def _slatted(w, h, r, seed, top_rows=6, slat=6):
    """A closed crate front-on: its top (lit), front slats with a dark gap between each, a
    corner post at each end with nail heads."""
    s = Spr(w, h)
    dark = look.mix(r["deep"], OUT, 0.35)
    for y in range(h):
        for x in range(w):
            if y < top_rows:
                c = r["hi"] if y == top_rows - 1 else r["lit"]
            else:
                k = (y - top_rows) % (slat + 1)
                c = dark if k == slat else r["base"] if k < slat - 1 else r["mid"]
            s.put(x, y, c)
    grain_runs(s, 1, w - 2, 0, top_rows - 2, r["base"], seed, odds=0.07)
    grain_runs(s, 7, w - 8, top_rows, h - 2, r["mid"], seed + 1, odds=0.05,
               skip=lambda x, y: (y - top_rows) % (slat + 1) >= slat - 1)
    for post in (0, w - 6):
        for y in range(top_rows, h):
            for x in range(6):
                s.put(post + x, y, [r["hi"], r["lit"], r["base"], r["base"], r["mid"], r["shade"]][x])
        for ny in range(top_rows + 2, h - 1, slat + 1):
            s.put(post + 2, ny, r["deep"])
            s.put(post + 3, ny, r["mid"])
    s.hline(0, w - 1, h - 1, r["mid"])
    return s


def crate_stand(lay, x0, w, top, feet, shelf, upper=30):
    """Two weathered crates: the bottom one laid on its side, its open front to the room (the
    board edges framing a dark inside, the back slats and their gaps, the inner floor the jars
    stand on, nail heads, a hand hole), the top one standing closed on it with the crock on its
    lid; two runners under them on the lawn."""
    r = _ramp("grey")
    TOP_ROWS, EDGE = 6, 5
    SIDE = 6
    ctop = top + upper - 4                     # the lower crate's top face (the upper stands on it)
    floor_y = shelf - 2                        # the inner floor's top face (5 rows)
    in_x0, in_x1 = x0 + SIDE, x0 + w - SIDE - 1
    in_y0 = ctop + TOP_ROWS + EDGE
    s = Spr(w, feet - ctop)
    dark = look.mix(r["deep"], OUT, 0.35)
    slat = [look.mix(r["shade"], OUT, 0.25), r["shade"], r["shade"], look.mix(r["shade"], OUT, 0.25)]
    for y in range(in_y0 - ctop, floor_y - ctop + 1):
        for x in range(in_x0 - x0, in_x1 - x0 + 1):
            k = (y - (in_y0 - ctop)) % 12
            c = dark if k == 11 else slat[min(3, k // 3)]
            s.put(x, y, c)
    for x in range(in_x0 - x0, in_x1 - x0 + 1):
        s.put(x, in_y0 - ctop, dark)
        s.put(x, in_y0 - ctop + 1, look.mix(dark, r["shade"], 0.5))
    for y in range(in_y0 - ctop, floor_y - ctop + 1):
        for k in range(3):
            s.put(in_x0 - x0 + k, y, dark if k < 2 else look.mix(dark, r["shade"], 0.5))
        s.put(in_x1 - x0, y, r["mid"])           # the inner right wall catches the light
        s.put(in_x1 - x0 - 1, y, r["base"])
    lay.alpha_composite(s.im, (x0, ctop))
    fl = _board(in_x1 - in_x0 + 1, 9, r, "grey", 71, top_rows=5, ends=False)
    lay.alpha_composite(fl.im, (in_x0, floor_y))
    fr = Spr(w, feet - 4 - ctop)
    for y in range(fr.h):
        for x in range(w):
            on_side = x < SIDE or x >= w - SIDE
            on_top = y < TOP_ROWS + EDGE
            on_floor = y >= floor_y - ctop + 5
            if not (on_side or on_top or on_floor):
                continue
            if y < TOP_ROWS:
                c = r["hi"] if y == TOP_ROWS - 1 else r["lit"]
            elif on_top and not on_side:
                c = r["base"] if y < TOP_ROWS + EDGE - 1 else r["mid"]
            elif on_side:
                u = x if x < SIDE else x - (w - SIDE)
                c = [r["hi"], r["lit"], r["base"], r["base"], r["mid"], r["shade"]][u]
            else:
                c = r["base"] if y < fr.h - 1 else r["mid"]
            fr.put(x, y, c)
    grain_runs(fr, 2, w - 3, 0, TOP_ROWS - 2, r["base"], 5, odds=0.07)
    grain_runs(fr, 7, w - 8, TOP_ROWS + 1, TOP_ROWS + EDGE - 2, r["mid"], 6, odds=0.05)
    for nx in (2, w - 4):
        for ny in (TOP_ROWS + 2, fr.h - 3):
            fr.put(nx, ny, r["deep"])
            fr.put(nx + 1, ny, r["mid"])
    for x in range(w // 2 - 6, w // 2 + 6):
        fr.put(x, TOP_ROWS + 2, dark)
        fr.put(x, TOP_ROWS + 3, dark if abs(x - w // 2) < 5 else r["mid"])
    lay.alpha_composite(fr.ringed(), (x0 - 1, ctop - 1))
    for rx in (x0 + 4, x0 + w - 18):
        rn = Spr(14, 5)
        for y in range(5):
            for x in range(14):
                rn.put(x, y, r["lit"] if y == 0 else r["base"] if y < 4 else r["mid"])
        rn.put(0, 2, r["lit"])
        _paste_ringed(lay, rn, rx, feet - 4)
    # the upper crate, closed, standing on the lower one's lid, a little narrower
    uw = w - 8
    up = _slatted(uw, upper + 2, r, 81)
    _paste_ringed(lay, up, x0 + 4, top)
    # its shadow on the lower crate's lid, down and to the right
    px = lay.load()
    for y in range(ctop, ctop + TOP_ROWS - 1):
        for x in range(x0 + 4 + uw, x0 + 4 + uw + 4):
            if 0 <= x < lay.width and px[x, y][3] and px[x, y][:3] != OUT[:3]:
                px[x, y] = look.mix(px[x, y], OUT, 0.3)[:3] + (255,)
    return {"top_face": top + 5, "shelf": floor_y + 2, "inner": (in_x0 + 2, in_x1 - 2),
            "feet": feet, "edge": (top + 6, top + 10), "box": (x0, top, x0 + w, feet)}


def _hive_face(w, h, r, seed, top_row=True, under_row=True):
    """One painted hive box front-on (a super): its top arris the pale blue (the lit top edge),
    lit down its left, shaded down its right, its last row the shaded underside, grain."""
    s = Spr(w, h)
    for y in range(h):
        for x in range(w):
            c = r["base"]
            if x <= 1:
                c = r["lit"] if x else r["hi"]
            elif x >= w - 2:
                c = r["shade"] if x == w - 1 else r["mid"]
            if top_row and y == 0:
                c = r["hi"]
            elif top_row and y == 1 and 1 < x < w - 2:
                c = r["lit"]
            if under_row and y == h - 1:
                c = r["deep"]
            elif under_row and y == h - 2 and 1 < x < w - 1:
                c = r["mid"]
            s.put(x, y, c)
    grain_runs(s, 3, w - 4, 3, h - 3, r["mid"], seed, odds=0.05)
    return s


def _hand_hole(s, x, y, w, r):
    """A hand-hold routed into a box's face: a dark slot with its upper wall in shadow and its
    lower lip catching the sun, the cut showing the pine."""
    dark = look.mix(r["deep"], OUT, 0.45)
    for k in range(w):
        s.put(x + k, y, dark)
        s.put(x + k, y + 1, look.mix(r["deep"], OUT, 0.25))
        s.put(x + k, y + 2, PINE[3] if 0 < k < w - 1 else PINE[2])
    s.put(x - 1, y + 1, r["mid"])
    s.put(x + w, y + 1, r["lit"])


def _painted_heart(s, x, y):
    """The shutters' heart cut into a painted face (not through it: this is a box): its inside
    dark, its upper-left walls in shadow (ink), its lower-right walls the pine the cut shows,
    lit by the sun from the top left."""
    cells = {(i, j) for j, row in enumerate(HEART) for i, ch in enumerate(row) if ch == "H"}
    for (i, j) in cells:
        c = look.mix(PAINT[0], OUT, 0.6)
        if (i - 1, j) not in cells or (i, j - 1) not in cells:
            c = OUT
        elif (i + 1, j) not in cells or (i, j + 1) not in cells:
            c = PINE[2]
        s.put(x + i, y + j, c)


def hive_stand(lay, x0, w, top, feet, shelf):
    """B: the bottling stand built as a hive (of a piece with the island hive): a coral outer
    cover overhanging a stack of two sky-blue supers, each with a routed hand-hold, the heart
    cut into the upper one, the bottom board's entrance slot over a landing board the jars
    stand on, the whole on a short hive stand. Paint chipped to the pine at the corners and on
    the cover. Every part ringed in the outline, so the blue holds against the lake and the
    sand. Returns the stand's anchors (see table_stand)."""
    r = _ramp("paint")
    COVER, UPPER = 7, 20
    land = shelf - 2                        # the landing board's top face (5 rows)
    up_y = top + COVER
    lo_y = up_y + UPPER
    # the hive stand's legs: back pair darker, then the front pair
    for bx in (x0 + 16, x0 + w - 21):
        b = Spr(5, feet - (land + 8) + 1)
        for y in range(b.h):
            for x in range(5):
                b.put(x, y, [r["mid"], r["shade"], r["shade"], r["deep"], r["deep"]][x])
        _paste_ringed(lay, b, bx, land + 8)
    for i, lx in enumerate((x0 + 2, x0 + w - 11)):
        leg = _leg(9, feet - (land + 8) + 1, r, "paint", 141 + i)
        _paste_ringed(lay, leg, lx, land + 8)
    # the lower super, its foot the bottom board with the entrance slot
    lo_h = land - lo_y
    lo = _hive_face(w, lo_h, r, 131)
    ent_y = lo_h - 5
    for x in range(14, w - 14):
        lo.put(x, ent_y, OUT)
        lo.put(x, ent_y + 1, look.mix(r["deep"], OUT, 0.5))
        lo.put(x, ent_y + 2, PINE[3] if 15 < x < w - 15 else PINE[2])
    lo.hline(0, w - 1, ent_y - 2, r["mid"])           # the joint between box and bottom board
    lo.hline(1, w - 2, ent_y - 1, r["lit"])
    _hand_hole(lo, w - 26, 9, 14, r)
    for (cx, cy) in ((0, lo_h - 3), (w - 1, lo_h - 4), (1, 2), (w - 2, 14)):
        for k in range(3):
            _wear(lo, cx, cy + k, "paint")
    _paste_ringed(lay, lo, x0, lo_y)
    # the upper super: the heart left, the hand-hold right
    up = _hive_face(w, UPPER, r, 133)
    _painted_heart(up, 14, 6)
    _hand_hole(up, w - 26, 8, 14, r)
    for (cx, cy) in ((0, UPPER - 4), (w - 1, 3), (37, 0), (38, 0), (71, 0)):
        for k in range(2 if cy else 1):
            _wear(up, cx, cy + k, "paint")
    # the cover's shadow on its first two rows, down and to the right
    for y in range(0, 2):
        for x in range(3, w):
            up.darken(x, y, 0.35 if y == 0 else 0.2)
    _paste_ringed(lay, up, x0, up_y)
    # the landing board, wider than the hive, the jars stand on its top face
    lw = w + 8
    lb = Spr(lw, 8)
    for y in range(8):
        for x in range(lw):
            c = r["lit"] if y < 4 else r["hi"] if y == 4 else r["base"] if y < 7 else r["mid"]
            if y == 0:
                c = look.mix(r["lit"], r["deep"], 0.35)      # under the hive's shadow at the back
            s_ = c
            lb.put(x, y, s_)
    grain_runs(lb, 2, lw - 3, 1, 3, r["base"], 151, odds=0.06)
    for x in range(lw):
        if hsh(x, 9) < 0.12:
            _wear(lb, x, 4, "paint")
    for y in range(5, 8):
        lb.put(0, y, r["lit"])
        lb.put(lw - 1, y, r["mid"])
    _paste_ringed(lay, lb, x0 - 4, land)
    # the outer cover, coral like the island hive's roof, overhanging three px a side
    cw = w + 6
    cv = Spr(cw, COVER)
    for y in range(COVER):
        for x in range(cw):
            if y < 2:
                c = look.mix(CORAL[3], CORAL[2], 0.4)
            elif y == 2:
                c = CORAL[3]                                 # the front arris, lit
            elif y < COVER - 1:
                c = CORAL[2] if x > 1 else CORAL[3]
            else:
                c = CORAL[1]
            if x == cw - 1 and y > 2:
                c = CORAL[1]
            cv.put(x, y, c)
    grain_runs(cv, 2, cw - 3, 0, 1, CORAL[2], 161, odds=0.06)
    for (cx, cy, n) in ((9, 2, 3), (44, 2, 2), (cw - 14, 2, 4), (0, 4, 2), (cw - 1, 3, 2), (60, 0, 2)):
        for k in range(n):
            xx, yy = (cx + k, cy) if cy <= 2 else (cx, cy + k)
            cv.put(xx, yy, PINE[3] if (xx + yy) % 3 else PINE[2])
    _paste_ringed(lay, cv, x0 - 3, top)
    return {"top_face": top + 2, "shelf": land + 4, "inner": (x0 + 6, x0 + w - 7),
            "feet": feet, "edge": (top + 3, top + COVER - 1), "box": (x0 - 4, top, x0 + w + 4, feet),
            "solid": True}


# =============================================================================================
# The benches the finished jars stand on
# =============================================================================================
def stump_bench(lay, x0, w, top, feet):
    """A: an oak plank laid on two log rounds. Each round a short trunk in the bark's browns,
    ridged, lit down its left, its roots flaring into the lawn, its sawn top showing as a pale
    crescent of rings in front of the plank; the plank's top (5 rows) and front edge over it."""
    r = _ramp("oak")
    for k, cx in enumerate((x0 + 22, x0 + w - 22)):
        hw = 12
        ty = top + 9                          # the sawn top's middle row, under the plank's edge
        s = Spr(2 * hw + 6, feet - ty + 6)
        ox, oy = 3, 4
        for y in range(-3, feet - ty + 1):
            flare = 2 if y >= feet - ty - 2 else 1 if y >= feet - ty - 4 else 0
            for x in range(-hw - flare, hw + flare):
                u = (x + hw) / float(2 * hw)
                c = BARK[2] if u < 0.24 else BARK[1] if u < 0.68 else BARK[0]
                if (x * 3 + 7 * k) % 5 == 0 and 0.08 < u < 0.92 and hsh(x, y // 3, k) < 0.75:
                    c = BARK[1] if c == BARK[2] else BARK[0] if c == BARK[1] else look.mix(BARK[0], OUT, 0.35)
                if y >= 0 or in_ell(0, 0, hw, 3, x, y):
                    s.put(ox + hw + x, oy + y, c)
        # the sawn top: rings in the oak's pale steps, its far half under the plank
        for y in range(-3, 4):
            sp = espan(0, 0.5, hw - 0.5, 3, y)
            if sp is None:
                continue
            for x in range(sp[0], sp[1] + 1):
                d = math.hypot(x / (hw - 0.5), (y + 0.5 - 0.5) / 3.0)
                c = OAK[6] if d > 0.82 else OAK[5] if d > 0.55 else OAK[6] if d > 0.3 else OAK[4]
                if d > 0.95:
                    c = OAK[4]
                s.put(ox + hw + x, oy + y, c)
        _paste_ringed(lay, s, cx - hw - ox, ty - oy)
    pl = _board(w, 9, r, "oak", 91, top_rows=5)
    pl.put(w // 3, 6, r["mid"])
    pl.put(w // 3 + 1, 6, r["shade"])
    pl.put(w // 3 + 2, 6, r["mid"])
    _paste_ringed(lay, pl, x0, top)
    return {"face": (top, top + 4), "feet": feet, "box": (x0, top, x0 + w, feet)}


def blue_bench(lay, x0, w, top, feet):
    """B: a shelf on a little stake fence: two pointed fence stakes driven into the lawn with a
    rail between them behind, a sky-blue plank fixed across their fronts on two triangular
    brackets, the paint chipped to the pine at the arris and the ends."""
    r = _ramp("paint")
    SW_ = 7
    stake_top = top - 46
    stakes = (x0 + 1, x0 + w - SW_ - 1)
    # the rail behind, between the stakes
    rl = Spr(stakes[1] - stakes[0], 4)
    for y in range(4):
        for x in range(rl.w):
            rl.put(x, y, r["mid"] if y == 0 else r["shade"] if y < 3 else r["deep"])
    _paste_ringed(lay, rl, stakes[0] + 3, feet - 13)
    _paste_ringed(lay, rl, stakes[0] + 3, stake_top + 8)      # the top rail, behind the jars
    # the stakes: square posts with a three-row point, lit left, worn
    for i, sx in enumerate(stakes):
        h = feet - stake_top + 1
        st = Spr(SW_, h)
        for y in range(h):
            half = (SW_ - 1) / 2.0
            if y < 3:
                half = 0.5 + y * 1.2
            for x in range(SW_):
                if abs(x - (SW_ - 1) / 2.0) > half + 0.01:
                    continue
                c = [r["hi"], r["lit"], r["base"], r["base"], r["base"], r["mid"], r["shade"]][x]
                if y == h - 1:
                    c = r["deep"]
                st.put(x, y, c)
            if y > h - 7 or hsh(i, y, 3) < 0.1:
                _wear(st, 0 if y > 3 else 3, y, "paint")
        st.put(3, 9, r["deep"])                   # a nail head
        _paste_ringed(lay, st, sx, stake_top)
    # the brackets under the plank, inside each stake
    for side, sx in ((0, stakes[0] + SW_), (1, stakes[1] - 9)):
        bk = Spr(9, 9)
        for y in range(9):
            for x in range(9):
                inside = (x + y <= 8) if side == 0 else ((8 - x) + y <= 8)
                if inside:
                    edge = (x + y == 8) if side == 0 else ((8 - x) + y == 8)
                    bk.put(x, y, r["mid"] if edge else r["lit"] if y < 2 else r["base"])
        _paste_ringed(lay, bk, sx, top + 9)
    pl = _board(w, 9, r, "paint", 93, top_rows=5)
    for x in (11, 12, 13, w - 30, w - 29):
        _wear(pl, x, 1, "paint")
    _paste_ringed(lay, pl, x0, top)
    return {"face": (top, top + 4), "feet": feet, "box": (x0, stake_top, x0 + w, feet),
            "posts": [(sx, sx + SW_, stake_top) for sx in stakes]}


def crate_bench(lay, x0, w, top, feet):
    """C: a long weathered crate turned upside down: its bottom boards the bench's top (a lit
    face the jars stand on, then a 3-row front board with its own lit arris, so the top has a
    thickness), its front slats with dark gaps, clumps of the straw it was packed with poking
    out of the gaps at all angles in two straw tones, a corner post at each end."""
    r = _ramp("grey")
    h = feet - top + 1
    s = Spr(w, h)
    dark = look.mix(r["deep"], OUT, 0.35)
    FACE, EDGE = 5, 3
    for y in range(h):
        for x in range(w):
            if y < FACE:
                c = r["hi"] if y == FACE - 1 else r["lit"]
            elif y < FACE + EDGE:
                c = r["hi"] if y == FACE else r["base"] if y < FACE + EDGE - 1 else r["mid"]
            elif y == FACE + EDGE:
                c = dark
            else:
                k = (y - FACE - EDGE - 1) % 8
                c = dark if k == 7 else r["base"] if k < 6 else r["mid"]
            s.put(x, y, c)
    grain_runs(s, 1, w - 2, 0, 3, r["base"], 17, odds=0.07)
    grain_runs(s, 7, w - 8, FACE + EDGE + 1, h - 2, r["mid"], 18, odds=0.05,
               skip=lambda x, y: (y - FACE - EDGE - 1) % 8 >= 6)
    # straw: two or three clumps a gap, each a root in the gap's dark and 3-4 strands fanning
    # out of it (up and down), 2-4 px, in two straw tones
    rnd = random.Random(19)
    tones = [PINE[2], PINE[3]]
    gaps = [FACE + EDGE] + [g for g in range(FACE + EDGE + 8, h - 1, 8)]
    for n_gap, gy in enumerate(gaps):
        xs = sorted(rnd.sample(range(12, w - 14), 2 if n_gap % 2 else 3))
        for x in xs:
            for k, (dx, dy) in enumerate(rnd.sample(((-1, -1), (0, -1), (1, -1), (-1, 1), (1, 1), (2, -1)), rnd.randint(3, 4))):
                ln = rnd.randint(2, 4)
                px, py = x, gy
                for j in range(ln):
                    px += dx if (j % 2 == 0 or abs(dx) > 1) else 0
                    py += dy if j % 3 != 2 else 0
                    if 0 <= py < h and py != gy:
                        s.put(px, py, tones[(j + k) % 2])
            s.put(x, gy, look.mix(PINE[0], OUT, 0.3))
    for post in (0, w - 6):
        for y in range(FACE, h):
            for x in range(6):
                s.put(post + x, y, [r["hi"], r["lit"], r["base"], r["base"], r["mid"], r["shade"]][x])
        for ny in range(FACE + 2, h - 1, 8):
            s.put(post + 2, ny, r["deep"])
            s.put(post + 3, ny, r["mid"])
    s.hline(0, w - 1, h - 1, r["deep"])
    _paste_ringed(lay, s, x0, top)
    return {"face": (top, top + 4), "feet": feet, "box": (x0, top, x0 + w, feet), "solid": True}


# =============================================================================================
# The payoffs on the jars
# =============================================================================================
ROSETTE_CROWN = [            # 11 x 7 on the boss: three clear points, jewels, a band
    "p....p....p",
    "p...ppp...p",
    "pp..ppp..pp",
    "ppp.ppp.ppp",
    "ppppppppppp",
    "ppJpppRppJp",
    "ddddddddddd",
]


def rosette(tail_long=14):
    """B's payoff: a prize rosette pinned on the middle jar. A pleated ring in the hive roof's
    coral, a big gold boss with the harvest's crown struck on it (three clear points, 9 x 7,
    ringed in the coin's deepest step, the coral jewel), two tails with V-cut ends, `tail_long`
    px under the boss so they stop above the jar's foot. Ringed; returns (sprite, the boss's
    middle)."""
    R_OUT, R_IN = 11.2, 8.2
    h = int(12 + tail_long + 2)
    s = Spr(25, h)
    cx, cy = 12.5, 12.0
    for side in (-1, 1):
        for y in range(int(cy + 4), int(cy + tail_long) + 1):
            t = (y - cy - 4) / max(1.0, tail_long - 4)
            xm = cx + side * (2.5 + 3.5 * t)
            for k in range(-1, 2):
                x = int(round(xm + k))
                c = CORAL[3] if k == -1 else CORAL[2] if k == 0 else CORAL[1]
                if y >= cy + tail_long - 1 and k == 0:
                    continue                      # the V cut in each tail's end
                s.put(x, y, c)
    for y in range(s.h):
        for x in range(s.w):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy))
            if d <= R_OUT:
                ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                pleat = int((ang + math.pi) / (math.pi * 2) * 18) % 2
                c = CORAL[3] if pleat else CORAL[2]
                if d > R_OUT - 1.2:
                    c = CORAL[1] if pleat else CORAL[0]
                if (x + 0.5 - cx) + (y + 0.5 - cy) > 7:
                    c = look.mix(c, OUT, 0.15)
                s.put(x, y, c)
            if d <= R_IN:
                c = COIN[1]
                if d > R_IN - 1.0:
                    c = COIN[0]
                elif (x + 0.5 - cx) + (y + 0.5 - cy) < -5.0:
                    c = COIN[2]
                s.put(x, y, c)
    cr = Spr(11, 7)
    for j, row in enumerate(ROSETTE_CROWN):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            if ch == "R":
                c = CORAL[2]
            elif ch == "J":
                c = PAINT[2]
            elif ch == "d":
                c = COIN[2]
            else:
                c = COIN[5] if i < 3 or j == 4 else COIN[4]
                if j == 0 or (j < 3 and (i == 0 or i == 5 or i == 10) and j == 0):
                    c = WHITE
            cr.put(i, j, c)
    ring = cr.ringed()
    s.paste(ring, int(cx) - 6, int(cy) - 5)
    return s.ringed(), (int(cx) + 1, int(cy) + 1)


BIG_CROWN = [
    "Y.......Y.......Y",
    "YY.....YYY.....YY",
    "YYY...YYYYY...YYY",
    "YYYY.YYYYYYY.YYYY",
    "YYYYYYYYYYYYYYYYY",
    "YYJYYYYYRYYYYYJYY",
    "YYYYYYYYYYYYYYYYY",
    "ddddddddddddddddd",
]


def big_crown():
    """C's payoff: the queen's crown as the harvest's prize (a size up from today's 17 x 11
    pop), come down on the middle jar's lid and staying there. The coin's gold lit down its
    left third and shaded down its right, white balls on its points, a coral jewel in the
    middle and two sky-blue ones (the island hive's paint), a dark band at its foot."""
    w, h = len(BIG_CROWN[0]), len(BIG_CROWN)
    s = Spr(w, h + 1)
    for j, row in enumerate(BIG_CROWN):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            u = i / (w - 1)
            if ch == "R":
                c = CORAL[2]
            elif ch == "J":
                c = PAINT[2]
            elif ch == "d":
                c = COIN[1] if u > 0.3 else COIN[2]
            else:
                c = COIN[4] if u < 0.3 else COIN[3] if u < 0.72 else COIN[2]
                if j == 0:
                    c = WHITE
                elif j == 4 and u < 0.85:
                    c = COIN[5] if u < 0.3 else COIN[4]
            s.put(i, j + 1, c)
    s.put(int(w / 2), 0, WHITE)                 # the middle point's ball stands a row taller
    s.put(int(w / 2), 1, COIN[4])
    return s.ringed()


STAR_BIG = [
    "..g..",
    "..p..",
    "gpWpg",
    "..p..",
    "..g..",
]
STAR_SMALL = [".p.", "pWp", ".p."]


def star(big=True):
    """The finds' four-point star in whole art pixels, gold going white (GlintTwinkle)."""
    rows = STAR_BIG if big else STAR_SMALL
    return look.grid(rows, {"g": GOLD[4], "p": GOLD[5], "W": WHITE})


# =============================================================================================
# Shadows on the plate (full resolution, by art cells: the lawn's own texture kept under them)
# =============================================================================================
def shade_cells(full, cells_core, cells_fringe, grain=3, ink=SHADE_INK, t=SHADE_T):
    """Mix every 3 x 3 screen block of the given art cells towards the land's ink: the core by
    `t`, the fringe by half. `full` is a numpy uint8 RGBA array, changed in place."""
    import numpy as np
    inkv = np.array(ink[:3], float)
    for cells, tt in ((cells_core, t), (cells_fringe, t * 0.5)):
        for (x, y) in cells:
            y0, x0 = y * grain, x * grain
            if y0 < 0 or x0 < 0 or y0 + grain > full.shape[0] or x0 + grain > full.shape[1]:
                continue
            blk = full[y0:y0 + grain, x0:x0 + grain, :3].astype(float)
            full[y0:y0 + grain, x0:x0 + grain, :3] = np.round(blk + (inkv - blk) * tt).astype(np.uint8)


def foot_shadow(x0, x1, y, rows=4, run=8):
    """A contact shadow on the lawn under something standing from x0 to x1 with its feet on row
    y: a band leaning down and to the right (the room's sun is top-left), a checker fringe
    round it. Returns (core cells, fringe cells)."""
    core, fringe = set(), set()
    for k in range(rows):
        dx = int(round(run * (k + 1) / rows))
        for x in range(x0 + dx - 1, x1 + dx + 2):
            core.add((x, y + k))
    for (x, yy) in list(core):
        for nx, ny in ((x - 1, yy), (x + 1, yy), (x, yy + 1)):
            if (nx, ny) not in core and (nx + ny) % 2 == 0:
                fringe.add((nx, ny))
    return core, fringe

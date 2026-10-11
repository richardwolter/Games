"""veg.py: the vegetation on the room's border frame (house-stages mockup, 2026-10-11).

The moulding round the whole room (the top run over the back wall, both side runs, the
front sill, the door's jambs and lintel) and what hangs off it: over the lake outside the
frame, down the back wall's paper, into the top of the doorway. Everything is drawn in
`under` (the furniture covers it where it stands against the walls).

  Stage 1  ABANDONED: dead ivy (base.DEAD) running most of every run: stems in DEAD[0]/[1]
           in broken pieces, an old trunk 2 px thick at each root (its lit top/left side
           DEAD[2]), 1-px stubs where leaves fell, brittle twigs (curves turning 45 degrees at
           most every 3 px, one every 5..14 px), dry leaf pairs (DEAD[3]/[2], on the wood
           only) every 14..24 px, sparse tangles of bare twigs at the corners and the lintel,
           curled brown leaves, dry strands over the lake and dead roots dangling into the
           doorway. MOSS patches (CUSHIONS), the neglected hut's roof moss lying in the
           wood: flat and ragged, 1-2 px thick (3 at a corner), 3-12 px long, hugging a
           board against its groove and wicking a pixel into it; MOSS[2] body, MOSS[1] in
           the crease and at the ends, a scattered MOSS[3] speck; gaps of 6-40 px, now and
           then two or three touching, longer and thicker toward the corners; over the
           outer edge only at the two bottom corners; no leaf shapes, so
           the green leaf first appears with the ivy in stage 2.
  Stage 2  SEMI-FIXED: the same stems greened (base.LEAF) and grown on from every root (the
           corners, both jambs); leaf clusters at the corners and over the door's lintel;
           strands hanging off the sill and the left side onto the lake; five tendrils over
           the back wall's top and down the paper; buds (a pink, white or yellow tip on a
           pale green stalk; wisteria as a green-violet nub). Moss remnants where it is
           still damp: on the sill by the leak, and a smear in the shade side's floor-rail
           crease.
  Stage 3  FIXED: lush, like the cosy hut: every run grown on and in flower at an uneven pitch
           (gaps of 6-24 px, now and then a pair), each run bloom in a tuft of two or
           three leaf stamps
           (3x3 and 5-px roses, a red one every fourth, small white flowers, half-open
           blooms, buds; plus crosses under a third), a short wisteria raceme every ~40 px;
           each corner a billowing
           cluster with smaller ones tapering off it along both runs, roses arching over
           the door (red and pink, two rose heads by turns, small ones elsewhere), pink
           blooms, daisies and small yellow flowers, wisteria hanging off the sill, the left
           side, the paper and the lintel, the window on the left wall framed by two sprays
           with its opening (y 190..203) left clear for the light.

COMPOSITION: one plan, authored once and the same every save. Every stem has one path from
its root; each stage draws a longer stretch of it, so stage 2 is stage 1 greened and grown
and stage 3 is stage 2 grown and in flower; stage 2's buds are where stage 3's flowers
open; the old trunks stay woody in every stage (the same plant, alive again). Growth
gathers at the FOCI (the four corners, the door, the window): leaf density falls off as
exp(-d / 34 px); a node every 2 px at a focus, up to 8 px in a bare run; leaves (two
deep along a run: RUN_SHAPES, 2x2 and 3x2, lit top-left) come single (alternating sides of
the stem), in pairs or in rosettes of three, rosettes and pairs likelier near a focus;
blooms on runs at 3% + 50% x density (halved by the window). Strands hang in cascades at
the bottom corners with single accents between.

RULES (the game's): whole source pixels; hard steps off the hut's own ramps only (LEAF,
DEAD, MOSS, PINK, RED, WISTERIA, WHITE, YELLOW, INK; a red rose's lit edge is PINK[2]);
lit from the top-left, like the furniture. A run's leaf shades per pixel off its own centre
(three tones; a highlight pixel on about a third of the outer ones); a cluster is leaf
stamps (STAMPS: 3x2, 2x3, 4x2, 4x3 ovals, LEAF[3] lit top-left, LEAF[2] body, LEAF[1]
underside) overlapping back to front over a LEAF[0] body that shows only in the gaps, its
lower-right leaves a step darker; a pixel left alone of its leaf goes back to the gap. A
green stem wanders a pixel every 4..7 px and changes step (LEAF[1], LEAF[0]) in runs. Foliage with body (a filled 2x2:
leaves, the 2-px trunk) throws a 1-px hard shadow down-right onto the wood and the paper
(black at alpha SHADOW_A 70: ~27% darker); a 1-px stem or twig and the flat moss throw none.
Blooms keep apart (_spaced): two rose heads 3 px of leaf between, a rose and any flower 2,
any two flowers 1; the lintel carries three heads (red, pink, red), a red head is 4x4 and
round (ROSE_RED). Over the lake the silhouette is
ringed in base.INK, as the hut's is. The room's dim (alpha 0.263, measured off the
captures, the same in all three) darkens these pixels inside the room and not over the lake,
so pixels over the lake are drawn pre-dimmed by the same amount (DIM 0.737, + (3, 2, 1)): the
plant is one material across the frame's edge. In the game the vegetation should sit
under the room's dim, the dim reaching over the hanging parts. Nothing is drawn within
3 px of the Decorate shelf (its title plank stands out to x 423 on rows 53..65).

MOTION (the game's 8 fps stepped clock, whole pixels): what hangs sways from its root, the
tip most, each strand on its own period (2.8..4.6 s) and phase; amplitude 0 under 4 px
long, 1 px under 9, 2 px from 9, at most 1 px indoors (the paper, the doorway); wisteria's
lower florets swing a little further, a short raceme over the lake its tip a pixel. Leaves
out over the lake (stage 3: 40% of a cluster's rim; stage 2: 35% of its rim and of the run
leaves out there) twitch 1 px sideways, each when its own slow sine passes 0.86 (about a sixth of the
time). Moss, stems and run leaves are still. Blooms are redrawn every frame, so a twitching
leaf never covers a flower.

STAGE-UP (p 0..1 over the ~2 s play-in; every change lands by p = 1):
  1 -> 2  each stem greens from its root outwards (t0 = 0.05 + 0.7 x i / length, 0.12 each);
          dead leaves turn green where a stage-2 leaf grows from them and drop otherwise;
          new leaves unfurl along the same wave (a curled pixel, a half leaf, the leaf:
          0.22); twigs and tangles drop; moss dissolves pixel by pixel (0.3) to its
          remnants; cluster bodies and leaves swell out from each centre; dead strands green
          from the root down and lengthen, their ends budding.
  2 -> 3  stems run on, more leaves unfurl, clusters fill out; buds open (bud, half-open,
          open: 0.3; a bloom with no bud first buds); strands lengthen (0.45, starting at
          0.15..0.5) and their ends open: wisteria from a nub to a short then a full raceme.

For life.py: flower_spots(stage) -> [(x, y, kind)], the open blooms on the source grid
(strand ends at rest included). A Bloom's t0 is honest: in the 2 -> 3 play-in it is open by
p = t0 + 0.3.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import base
from base import DEAD, INK, LEAF, MOSS, PINK, RED, WHITE, WISTERIA, YELLOW, h, vnoise

W, H = base.GRID

# ---------------------------------------------------------------- the frame, off the shell
XL, XR = 84, 419            # the room's outer outline columns
YT, YB = 52, 307            # its outer outline rows
DOOR = (241, 262)           # the door opening, x; rows 56..83
JAMBS = ((235, 240), (263, 268))
WINDOW_Y = 196              # the window on the left wall (the sun's way in)
DIM = 0.737                 # 1 - the room's dim
DIM_ADD = np.array([3, 2, 1], np.float32)
SHADOW_A = 70               # a foliage shadow darkens what is under it ~27%
FPS = 8.0                   # the game's pixel clock

LANES = {   # lane: (axis it runs along, centre, half-width of the wander)
    "top": ("x", 56.5, 2.5),
    "sill": ("x", 302.5, 2.5),
    "left": ("y", 86.5, 1.5),
    "right": ("y", 416.5, 1.5),
    "jambL": ("y", 237.5, 1.5),
    "jambR": ("y", 265.5, 1.5),
    "lintel": ("x", 54.0, 1.0),
}
OUTWARD = {"top": (0, -1), "sill": (0, 1), "left": (-1, 0), "right": (1, 0),
           "jambL": (-1, 0), "jambR": (1, 0), "lintel": (0, -1)}

# Where growth gathers: the corners, the door and the window. Leaves crowd near them and
# the runs between thin out.
FOCI = [(XL, YT, 1.0), (XR, YT, 0.8), (XL, YB, 1.0), (XR, YB, 1.0), (252, 54, 1.0),
        (86, WINDOW_Y, 0.8)]


def density(x, y):
    return max(w * math.exp(-math.hypot(x - fx, y - fy) / 34.0) for fx, fy, w in FOCI)


# ---------------------------------------------------------------- canvas

class Cv:
    """The vegetation's canvas. `flat` marks pixels that lie flat on the wood (moss) and so
    throw no shadow whatever their width."""

    def __init__(self):
        self.c = np.zeros((H, W, 4), np.uint8)
        self.flat = np.zeros((H, W), bool)

    def put(self, x, y, col, flat=False):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.c[y, x, :3] = col[:3]
            self.c[y, x, 3] = 255
            self.flat[y, x] = flat


# ---------------------------------------------------------------- sprites

# Leaf masks drawn tip DOWN; rotated to point away from their stem.
LEAF_MASKS = {
    "heart": ["#.#", "###", ".#."],
    "round": [".#.", "###", ".#."],
    "oval": ["##.", "###", ".##"],
    "big": [".#.#", "####", "####", ".##."],
    "small": ["##", "#."],
    # the run leaves (2026-10-11, round 3: the 3x3 'heart'/'round' read as '+' crosses on a
    # 1-px stem): two deep, lit pixel top-left, body, a shaded pixel bottom-right
    "s2": ["##", "##"],
    "h3": ["###", "##."],
    "h3r": ["###", ".##"],
}
RUN_SHAPES = ("s2", "h3", "h3r", "h3", "s2", "h3r")


def _mask(name, d):
    rows = LEAF_MASKS[name]
    pts = [(i, j) for j, r in enumerate(rows) for i, ch in enumerate(r) if ch == "#"]
    hh = len(rows) - 1
    if d == (0, -1):
        pts = [(i, hh - j) for i, j in pts]
    elif d == (1, 0):
        pts = [(j, i) for i, j in pts]
    elif d == (-1, 0):
        pts = [(hh - j, i) for i, j in pts]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return pts, cx, cy


def leaf(cv, x, y, name, d=(0, 1), dark=0, sheen=0.0, ramp=LEAF, seed=0, rim=False, flat=False):
    """A leaf centred near (x, y) pointing along d, shaded per pixel off its own centre:
    top-left lit, bottom-right in shade; `sheen` the odds of one highlight pixel; `rim` a
    darkest edge under its lower-right side, which parts it from the leaves behind (in a
    cluster, drawn back to front, the next leaf down covers most of it)."""
    pts, cx, cy = _mask(name, d)
    top = min(pts, key=lambda p: (p[0] + p[1], p[1]))
    if rim:
        own = set(pts)
        for px, py in pts:
            for ex, ey in ((1, 0), (0, 1), (1, 1)):
                if (px + ex, py + ey) not in own:
                    cv.put(x + px + ex - round(cx), y + py + ey - round(cy), ramp[0])
    for px, py in pts:
        u = (px - cx) + (py - cy)
        t = 3 if u < -0.6 else 2 if u <= 0.6 else 1
        if flat:                    # two tones: a lit top-left half and the body
            t = 3 if u < -0.3 else 2
        if sheen and (px, py) == top and h(x, y, seed + 7) < sheen:
            t = 4
        t = max(0, t - dark)
        cv.put(x + px - round(cx), y + py - round(cy), ramp[t])


DEAD_LEAVES = [["ab.", "bbc", ".cd"], [".a.", "abb", ".bd"], ["a..", "bb.", ".bd"],
               ["ab", "bc", "d."], [".ab", "abc", "dd."], ["a", "b", "c", "d"]]


def dead_leaf(cv, x, y, v):
    """A curled brown leaf hanging on: DEAD[2] body, DEAD[1] fold, DEAD[0] the curled-under
    tip, and ONE DEAD[3] pixel on its lit top-left edge (the rest of the edge DEAD[2]); over
    the lake it has no DEAD[3] at all (the pale pixel read as straw there)."""
    lit = False
    for j, r in enumerate(DEAD_LEAVES[v % len(DEAD_LEAVES)]):
        for i, ch in enumerate(r):
            if ch == ".":
                continue
            wet = not (0 <= x + i < W and 0 <= y + j < H and inside_mask()[y + j, x + i])
            # over the lake the whole leaf sits a step darker (it read as straw on the water)
            k = {"a": 2, "b": 2, "c": 1, "d": 0}[ch] - (1 if wet and ch != "d" else 0)
            if ch == "a" and not lit:
                lit = True
                k += 1
            cv.put(x + i, y + j, DEAD[k])


# Roses from above, lit top-left: the petals' dark swirl (picked off a test sheet over the
# moulding and over leaves) or concentric petals round a dark heart, by turns; a small one.
ROSES = ([".22.", "2310", "2101", ".10."], [".21.", "2302", "1021", ".11."])
# A red head (2026-10-11 review): 4x4 and round, corners left to the leaves, RED[2] on its
# top-left, RED[1] body, one RED[0] heart. The old red swirl borrowed PINK[2] and, stacked,
# read as a salmon-to-wine bar.
ROSE_RED = [".22.", "2111", "2101", ".11."]
ROSE_S = ["22.", "201", ".11"]
# A head's box on the grid (dx0, dy0, dx1, dy1 off its anchor) and the gap kept round it.
ROSE_BOX = (-1, -1, 2, 2)
SMALL_BOX = (-1, -1, 1, 1)


# The run blooms (2026-10-11, second review: every bloom was the same plus cross). Tones by
# ramp index; '.' none. A 3x3 rose lit top-left with a glint and a dark rim; a 5-px rose with
# a darker spiral pixel; a half-open bloom on a green sepal; a small white flower with a
# yellow eye; buds of one or two pixels.
ROSE3 = ["321", "211", "10."]
ROSE5 = ["22.", "201"]
NEW_KINDS = ("rose3", "rose3_red", "rose5", "rose5_red", "half", "white2",
             "bud_pink", "bud_white", "bud_violet")
# What life.py is told each kind is (its bees and petals know the old names).
VISIT_KIND = {"rose3": "rose_pink", "rose3_red": "rose_red", "rose5": "rose_pink_s",
              "rose5_red": "rose_red_s", "half": "pink", "white2": "daisy", "raceme": "wisteria"}


def _flower_new(cv, x, y, kind, stage):
    red = kind.endswith("_red")
    R = [RED[0], RED[1], RED[2], PINK[2]] if red else PINK
    if kind.startswith("bud_"):
        c = {"bud_pink": PINK[1], "bud_white": WHITE[2], "bud_violet": WISTERIA[2]}[kind]
        if stage == 0:
            cv.put(x, y, LEAF[2])
            return
        cv.put(x, y, c)
        if (x + y) % 3:                      # most on a green calyx, some bare
            cv.put(x, y + 1, LEAF[2])
        return
    if stage == 0:                           # a bud
        cv.put(x, y, R[1] if kind != "white2" else WHITE[1])
        cv.put(x, y + 1, LEAF[2])
        return
    if kind == "white2":
        if stage == 1:
            cv.put(x, y, WHITE[2]); cv.put(x, y + 1, LEAF[2])
            return
        cv.put(x, y, WHITE[2]); cv.put(x + 1, y, WHITE[1])
        cv.put(x, y + 1, WHITE[1]); cv.put(x + 1, y + 1, YELLOW[1])
        return
    if kind == "half" or stage == 1:
        cv.put(x, y, R[2]); cv.put(x + 1, y, R[1])
        cv.put(x, y + 1, LEAF[2]); cv.put(x + 1, y + 1, R[0])
        return
    rows, ox = (ROSE3, 1) if kind.startswith("rose3") else (ROSE5, 0)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch != ".":
                cv.put(x + i - ox, y + j - ox, R[int(ch)])


def flower(cv, x, y, kind, q=1.0):
    """A bloom at (x, y). q 0..1 opens it: bud (q < 1/3), half-open, open."""
    stage = 0 if q < 1 / 3 else 1 if q < 2 / 3 else 2
    if kind in NEW_KINDS:
        _flower_new(cv, x, y, kind, stage)
        return
    if kind.startswith("rose"):
        # a red rose's lit petal edge is the pink ramp's light step: base.RED has only three
        R = [RED[0], RED[1], RED[2], PINK[2]] if kind.startswith("rose_red") else PINK
        if stage == 0:
            cv.put(x, y, R[1]); cv.put(x, y + 1, LEAF[2]); cv.put(x - 1, y + 1, LEAF[3])
            return
        if stage == 1:
            cv.put(x, y, R[2]); cv.put(x + 1, y, R[1]); cv.put(x, y + 1, R[0])
            cv.put(x + 1, y + 1, R[1]); cv.put(x - 1, y + 1, LEAF[2])
            return
        if kind.endswith("_s"):
            rows = ROSE_S
        elif kind.startswith("rose_red"):
            rows = ROSE_RED
        else:
            rows = ROSES[(x * 7 + y * 3) % 2]
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != ".":
                    cv.put(x + i - 1, y + j - 1, R[int(ch)])
        return
    ramp, centre = {
        "daisy": (WHITE, YELLOW[1]),
        "pink": ([PINK[0], PINK[1], PINK[2]], YELLOW[1]),
        "yellow": ([YELLOW[0], YELLOW[1], YELLOW[2]], YELLOW[0]),
    }[kind]
    if stage == 0:
        cv.put(x, y, ramp[1]); cv.put(x, y + 1, LEAF[3])
        return
    if stage == 1:
        cv.put(x, y - 1, ramp[2]); cv.put(x - 1, y, ramp[2]); cv.put(x, y, centre)
        cv.put(x, y + 1, LEAF[3])
        return
    for dx, dy, t in ((0, -1, 2), (-1, 0, 2), (1, 0, 1), (0, 1, 1)):
        cv.put(x + dx, y + dy, ramp[t])
    cv.put(x, y, centre)


def raceme(cv, x, y, n, sway=0):
    """Wisteria: a drooping cluster n rows long hanging from (x, y): 2x2 florets beading
    down either side of its axis by turns (the top ones with a third floret beside them),
    then single florets tapering to the darkest at the tip; each bead lit on its top-left.
    `sway` swings the lower rows (whole pixels, most at the tip)."""
    cv.put(x, y, LEAF[2])
    r, k = 1, 0
    while r <= n:
        f = r / n
        off = int(round(sway * f * f))
        side = -1 if k % 2 == 0 else 0
        if f < 0.62 and r < n:
            for dx, dy, t in ((0, 0, 3), (1, 0, 2), (0, 1, 2), (1, 1, 1)):
                cv.put(x + off + side + dx, y + r + dy, WISTERIA[t])
            if f < 0.36:
                cv.put(x + off + (side + 2 if side < 0 else side - 1), y + r + 1, WISTERIA[1])
        else:
            cv.put(x + off, y + r, WISTERIA[2 if k % 2 == 0 else 1])
        r += 1
        k += 1
    cv.put(x + int(round(sway)), y + n, WISTERIA[0])


def raceme_bud(cv, x, y):
    cv.put(x, y, LEAF[2]); cv.put(x, y + 1, LEAF[3]); cv.put(x, y + 2, WISTERIA[1])


# ---------------------------------------------------------------- paths

def lane_path(segs, seed):
    """A runner along lanes: [(lane, from, to)] along each lane's axis, root first."""
    pts = []
    for si, (lane, a, b) in enumerate(segs):
        axis, c, hw = LANES[lane]
        step = 1 if b >= a else -1
        # the stem wanders a pixel at a time, every 4..7 px (2026-10-11 review: the smooth
        # noise held it ruler-straight for tens of px), held inside the lane
        lo, hi = int(math.floor(c - hw + 0.5)), int(math.floor(c + hw + 0.5))
        cur = int(math.floor(c + hw * (2 * vnoise(a, 3, 9, seed) - 1) + 0.5))
        nxt = 4 + int(h(a, si, seed + 60) * 3.99)
        for k, s in enumerate(range(a, b + step, step)):
            if k == nxt:
                d = 1 if h(s, 1, seed + 61) < 0.5 else -1
                if not lo <= cur + d <= hi:
                    d = -d
                cur += d
                nxt = k + 4 + int(h(s, 2, seed + 62) * 3.99)
            off = cur
            p = (s, off) if axis == "x" else (off, s)
            if pts:
                lx, ly = pts[-1]
                while abs(p[0] - lx) > 1 or abs(p[1] - ly) > 1:
                    lx += (p[0] > lx) - (p[0] < lx)
                    ly += (p[1] > ly) - (p[1] < ly)
                    pts.append((lx, ly))
                if p == pts[-1]:
                    continue
            pts.append(p)
    return pts


def _lane_of(x, y, segs):
    best, bd = segs[-1][0], 1e9
    for lane, a, b in segs:
        axis, c, hw = LANES[lane]
        lo, hi = min(a, b), max(a, b)
        s, o = (x, y) if axis == "x" else (y, x)
        d = abs(o - c) + max(0, lo - s, s - hi) * 3
        if d < bd:
            best, bd = lane, d
    return best


# ---------------------------------------------------------------- the plan
#
# Stems: (name, segments root first, seed, {stage: [(i0, i1), ...]} path spans drawn).
# Stage 1 spans are DEAD (broken pieces), stage 2 and 3 GREEN and continuous from the root.
STEMS = [
    ("left", [("left", 305, 56)], 11,
     {1: [(0, 40), (47, 92), (100, 150), (158, 200)], 2: [(0, 158)], 3: [(0, 210)]}),
    ("sill_l", [("sill", 88, 244)], 12,
     {1: [(0, 26), (33, 56), (64, 104), (112, 146)], 2: [(0, 98)], 3: [(0, 156)]}),
    ("top_l", [("top", 86, 233)], 13,
     {1: [(0, 24), (31, 64), (71, 108), (116, 140)], 2: [(0, 104)], 3: [(0, 147)]}),
    ("tl_down", [("left", 57, 150)], 14,
     {1: [(0, 22), (30, 60)], 2: [(0, 44)], 3: [(0, 93)]}),
    ("jamb_l", [("jambL", 92, 56), ("lintel", 239, 262)], 15,
     {1: [(0, 13), (18, 36)], 2: [(0, 52)], 3: [(0, 64)]}),
    ("jamb_r", [("jambR", 92, 56), ("lintel", 265, 241)], 16,
     {1: [(0, 17)], 2: [(0, 48)], 3: [(0, 64)]}),
    ("right", [("right", 305, 56)], 17,
     {1: [(0, 26), (37, 62), (70, 118), (126, 170), (178, 226)], 2: [(0, 195)], 3: [(0, 249)]}),
    ("sill_r", [("sill", 417, 246)], 18,
     {1: [(0, 24), (32, 78), (86, 132)], 2: [(0, 106)], 3: [(0, 171)]}),
    ("top_r", [("top", 417, 270)], 19,
     {1: [(0, 40), (48, 92), (100, 138)], 2: [(0, 56)], 3: [(0, 147)]}),
    ("tr_down", [("right", 57, 130)], 20,
     {1: [(0, 14), (20, 50)], 2: [(0, 30)], 3: [(0, 73)]}),
]

# The old woody trunk at each root, px from the root (2 px thick, brown in every stage).
TRUNK = {"left": 22, "sill_l": 14, "top_l": 10, "jamb_l": 12, "jamb_r": 10, "right": 20,
         "sill_r": 16, "top_r": 8}

# Foliage clusters: (x, y, rx, ry, seed, stage-2 share of the radius, stage-3 flowers as
# (kind, dx, dy) in radii). Each corner billows out over the lake, with smaller clusters
# tapering off it along both runs; the lintel arch is roses; two sprays frame the window.
CLUSTERS = [
    (86, 57, 9, 8, 31, 0.6, [("rose_red", 0.3, 0.1), ("pink", -0.6, -0.4), ("daisy", 0.4, -0.7), ("yellow", -0.6, 0.6)]),
    (86, 82, 3, 8, 39, 0.3, [("daisy", 0.0, 0.3)]),
    (409, 54, 11, 4, 32, 0.45, [("pink", -0.5, -0.4), ("daisy", 0.2, -0.8), ("rose_pink_s", 0.55, 0.1)]),
    (416, 77, 3, 9, 40, 0.0, [("pink", 0.0, -0.2)]),
    (87, 304, 14, 8, 33, 0.62, [("rose_red", 0.1, -0.2), ("rose_pink", -0.6, 0.4), ("daisy", 0.6, -0.6), ("pink", 0.65, 0.5), ("yellow", -0.4, -0.75), ("rose_pink_s", -0.15, 0.7)]),
    (123, 304, 8, 4, 41, 0.3, [("pink", -0.3, -0.5), ("daisy", 0.5, 0.2)]),
    (86, 273, 3, 9, 42, 0.35, [("yellow", 0.0, -0.4), ("pink", 0.0, 0.4)]),
    (413, 304, 11, 8, 34, 0.55, [("rose_pink", -0.1, -0.1), ("pink", -0.6, 0.5), ("daisy", 0.4, -0.7), ("yellow", 0.6, 0.5), ("rose_red_s", -0.65, -0.35)]),
    (385, 304, 8, 4, 43, 0.0, [("daisy", 0.0, -0.4)]),
    (416, 272, 3, 8, 44, 0.3, [("pink", 0.0, 0.0)]),
    # the lintel: three heads at most, red, pink, red, 10 px apart (a band of four read as
    # speckled noise at play size)
    (252, 53, 16, 3, 35, 0.55, [("rose_red", -0.62, 0.0), ("rose_pink", 0.0, -0.3), ("rose_red", 0.62, 0.0)]),
    (237, 61, 3, 5, 45, 0.0, [("rose_pink_s", 0.0, 0.0)]),
    (266, 61, 3, 5, 46, 0.4, [("rose_pink_s", 0.0, -0.1)]),   # pink under the red head
    (86, 183, 3, 6, 36, 0.0, [("daisy", 0.0, -0.4), ("yellow", 0.3, 0.5)]),
    (86, 210, 3, 6, 37, 0.55, [("daisy", 0.2, 0.3), ("pink", -0.3, -0.5)]),
]

# Stage 1's corners: the dead version of the clusters, a tangle of bare twigs with a few
# curled leaves left on it: (x, y, rx, ry, seed, strokes).
TANGLES = [(86, 57, 9, 7, 61, 7), (87, 303, 12, 7, 62, 8), (252, 54, 10, 2, 63, 4),
           (409, 55, 7, 3, 64, 3), (86, 196, 3, 10, 65, 4), (413, 303, 7, 5, 66, 4)]

# Hanging things: (where, x, y, {stage: length}, end, seed), gathered into cascades at the
# corners with single accents between.
#   sill: off the sill's front edge, down over the lake. left: over the side's outer edge,
#   then down its outside. right: down the outside 2 px out (the shelf stands 6 px away).
#   paper: over the back wall's top, down the paper. door: off the lintel into the doorway.
STRANDS = [
    ("sill", 92, 304, {1: 5, 2: 8, 3: 12}, "wisteria", 1),
    ("sill", 98, 304, {3: 9}, "pink", 2),
    ("sill", 105, 304, {2: 4, 3: 6}, "leaf", 3),
    ("sill", 112, 304, {1: 3, 2: 6, 3: 11}, "daisy", 4),
    ("sill", 121, 304, {3: 7}, "wisteria", 5),
    ("sill", 167, 304, {3: 6}, "pink", 6),
    ("sill", 214, 304, {3: 5}, "leaf", 7),
    ("sill", 379, 304, {3: 8}, "rose_pink_s", 8),
    ("sill", 388, 304, {1: 3, 2: 7, 3: 12}, "wisteria", 9),
    ("sill", 396, 304, {1: 4, 3: 6}, "pink", 10),
    ("sill", 404, 304, {1: 3, 2: 5, 3: 10}, "leaf", 11),
    ("sill", 411, 304, {3: 7}, "daisy", 12),
    ("left", 86, 292, {1: 4, 2: 4, 3: 8}, "leaf", 21),
    ("left", 86, 280, {3: 5}, "pink", 22),
    ("left", 86, 236, {1: 5, 2: 5, 3: 9}, "pink", 23),
    ("left", 86, 172, {1: 3, 2: 4, 3: 6}, "daisy", 24),
    ("left", 86, 217, {1: 3, 3: 6}, "wisteria", 25),
    ("left", 86, 124, {3: 5}, "leaf", 26),
    ("left", 86, 78, {2: 3, 3: 7}, "rose_red_s", 27),
    ("right", 417, 284, {2: 3, 3: 6}, "leaf", 31),
    ("right", 417, 262, {3: 5}, "leaf", 32),
    ("right", 417, 98, {3: 4}, "leaf", 33),
    ("right", 417, 178, {2: 4, 3: 6}, "leaf", 34),
    ("paper", 128, 60, {2: 7, 3: 10}, "curl", 41),
    ("paper", 140, 60, {3: 7}, "wisteria", 42),
    ("paper", 186, 60, {3: 6}, "pink", 43),
    ("paper", 216, 60, {2: 4, 3: 7}, "curl", 44),
    ("paper", 276, 60, {2: 5, 3: 8}, "wisteria", 45),
    ("paper", 286, 60, {3: 6}, "curl", 46),
    ("paper", 337, 60, {3: 5}, "rose_pink_s", 47),
    ("paper", 372, 60, {3: 6}, "pink", 48),
    ("paper", 392, 60, {2: 6, 3: 9}, "wisteria", 49),
    ("paper", 403, 60, {2: 4, 3: 6}, "curl", 50),
    ("door", 244, 55, {1: 6, 2: 3, 3: 5}, "leaf", 51),
    ("door", 250, 55, {1: 4}, "leaf", 52),
    ("door", 257, 55, {1: 7, 2: 4, 3: 4}, "wisteria", 53),
    ("door", 261, 55, {3: 6}, "wisteria", 54),
]

# ---------------------------------------------------------------- geometry masks

_masks = {}


def frame_mask():
    """The moulding: the outer runs, the wall-foot run and the door's jambs and lintel."""
    if "frame" in _masks:
        return _masks["frame"]
    m = np.zeros((H, W), bool)
    m[YT:62, XL:XR + 1] = True
    m[56:84, DOOR[0]:DOOR[1] + 1] = False
    m[YT:YB + 1, XL:XL + 6] = True
    m[YT:YB + 1, XR - 5:XR + 1] = True
    m[298:YB + 1, XL:XR + 1] = True
    m[84:94, XL:XR + 1] = True
    m[84:94, DOOR[0]:DOOR[1] + 1] = False
    for a, b in JAMBS:
        m[56:94, a:b + 1] = True
    _masks["frame"] = m
    return m


def inside_mask():
    if "inside" not in _masks:
        m = np.zeros((H, W), bool)
        m[YT:YB + 1, XL:XR + 1] = True
        _masks["inside"] = m
    return _masks["inside"]


SHELF_PLANK = (49, 70, 420)   # the shelf's title plank stands out to x 423 on rows 53..65


def allowed_mask(board):
    """Everywhere but the Decorate shelf and 3 px round it."""
    key = ("allowed", tuple(board))
    if key not in _masks:
        m = np.ones((H, W), bool)
        bx, by, bw, bh = board
        m[max(0, by - 3):by + bh + 3, bx - 3:] = False
        m[SHELF_PLANK[0]:SHELF_PLANK[1], SHELF_PLANK[2]:] = False
        _masks[key] = m
    return _masks[key]


BOARD = (426, 59, 135, 249)   # ctx.board, for the plan's own reach tests


WINDOW_GAP = (190, 203)       # the window's opening on the left wall: leaves keep off it


def _reach(x, y, inward=2):
    """May foliage stand here? On the frame, over the lake, or up to `inward` px in off the
    frame; never at the shelf, nor over the window's opening on the left wall."""
    if not (0 <= x < W and 0 <= y < H) or not allowed_mask(BOARD)[y, x]:
        return False
    if x < XL + 9 and WINDOW_GAP[0] <= y <= WINDOW_GAP[1] and x >= XL - 1:
        return False
    if not inside_mask()[y, x]:
        return True
    f = frame_mask()
    return bool(f[max(0, y - inward):y + inward + 1, max(0, x - inward):x + inward + 1].any())


# ---------------------------------------------------------------- items

class Item:
    """One thing that grows: `states` stage -> its state (None: absent); `t0` when it
    starts changing in the stage-up (0..1); `dyn` redrawn every frame."""
    dyn = False
    t0 = 0.0

    def state(self, stage):
        return self.states.get(stage)


class StemPx(Item):
    def __init__(self, x, y, states, t0, bark, tone=1):
        self.x, self.y, self.states, self.t0, self.bark = x, y, states, t0, bark
        self.tone = tone                      # a green stem's step: LEAF[1] or LEAF[0]

    def draw(self, cv, a, b, q):
        if a == b or q >= 1:
            s = b if q >= 1 else a
        elif a is None:
            s = b if q > 0 else None
        elif b is None:
            s = a if q < 0.5 else None
        else:
            s = b if q > 0.5 else a
        if s == "dead":
            cv.put(self.x, self.y, DEAD[1] if self.bark else DEAD[0])
        elif s == "bark":                     # the old trunk's lit top/left side
            cv.put(self.x, self.y, DEAD[2])
        elif s == "green":
            cv.put(self.x, self.y, LEAF[self.tone])


class Twig(Item):
    """A dead twig poking off a stem (stage 1), a curled leaf on some. DEAD[0] on the wood,
    DEAD[1] over the lake (DEAD[0] would vanish into the dark water), its last pixel the lit
    tip in DEAD[2]; never DEAD[3] (that read as straw)."""

    def __init__(self, pts, t0, curl):
        self.pts, self.t0, self.curl = pts, t0, curl
        self.states = {1: "dead"}

    def draw(self, cv, a, b, q):
        if a == "dead" and (b == "dead" or q < 0.45):
            last = len(self.pts) - 1
            for k, (x, y) in enumerate(self.pts):
                over_lake = not inside_mask()[y, x]
                c = DEAD[1] if over_lake else DEAD[0]
                if k and k == last and not over_lake:
                    c = DEAD[2]
                cv.put(x, y, c)
            if self.curl is not None:
                x, y = self.pts[-1]
                dead_leaf(cv, x - 1, y + 1, self.curl)


class DryPair(Item):
    """Stage 1: a pair of dry leaves still hanging on a dead stem, either side of it, each two
    pixels: the lit one DEAD[3] with DEAD[2] behind it, the lower one DEAD[2] over DEAD[1].
    Only on the wood (DEAD[3] read as straw over the lake)."""

    def __init__(self, pts, t0):
        self.pts, self.t0 = pts, t0
        self.states = {1: "dead"}

    def draw(self, cv, a, b, q):
        if a == "dead" and (b == "dead" or q < 0.45):
            for x, y, k in self.pts:
                cv.put(x, y, DEAD[k])


def _curve(x, y, ang, n, seed):
    """A twig n px long from (x, y), heading `ang`: a curve that turns by at most 45
    degrees every 3 px (the old ones zigzagged and stamped the same 'Λ' along a run).
    Whole pixels, 8-connected."""
    pts, fx, fy = [], float(x), float(y)
    for j in range(1, n + 1):
        if j > 1 and (j - 1) % 3 == 0:
            ang += (2 * h(j, n, seed) - 1) * 0.785
        fx += math.cos(ang)
        fy += math.sin(ang)
        p = (int(math.floor(fx + 0.5)), int(math.floor(fy + 0.5)))
        if p != (x, y) and (not pts or pts[-1] != p):
            pts.append(p)
    return pts


class Leaf(Item):
    def __init__(self, x, y, name, d, dark, states, t0, seed, sheen=0.3, flutter=False, rim=False):
        self.x, self.y, self.name, self.d, self.dark = x, y, name, d, dark
        self.rim = rim
        self.states, self.t0, self.seed, self.sheen = states, t0, seed, sheen
        self.flutter = flutter
        self.dyn = flutter
        self.period = 2.8 + 1.8 * h(x, y, seed + 3)
        self.phase = 6.283 * h(x, y, seed + 4)

    def _green(self, cv, q, dx=0):
        if q >= 0.66:
            leaf(cv, self.x + dx, self.y, self.name, self.d, self.dark, self.sheen, seed=self.seed,
                 rim=self.rim, flat=self.rim)
        elif q >= 0.33:                          # half unfurled
            leaf(cv, self.x + dx, self.y, "small", self.d, self.dark, 0, seed=self.seed)
        elif q > 0:                              # curled
            cv.put(self.x + dx, self.y, LEAF[3])

    def draw(self, cv, a, b, q, t=0.0):
        dx = 0
        if self.flutter:
            s = math.sin(6.283 * base.Ctx.step(t, FPS) / self.period + self.phase)
            dx = 1 if s > 0.86 else 0
        if a == b:
            if a == "green":
                self._green(cv, 1.0, dx)
            elif a == "dead":
                dead_leaf(cv, self.x, self.y, int(self.seed))
            return
        if a == "dead" and b == "green":
            if q < 0.3:
                dead_leaf(cv, self.x, self.y, int(self.seed))
            else:
                self._green(cv, 0.34 + (q - 0.3) / 0.7 * 0.66, dx)
        elif a == "dead" and b is None:
            if q < 0.3:
                dead_leaf(cv, self.x, self.y, int(self.seed))
        elif a is None and b == "green":
            self._green(cv, q, dx)
        elif a == "green" and b is None and q < 0.5:
            self._green(cv, 1.0, dx)


# Leaf stamps for the clusters, tone per pixel (3 lit, 2 body, 1 underside; '.' none).
STAMPS = {
    "h3": ["322", "211"],
    "v3": ["32", "22", "11"],
    "h4": ["3222", "2211"],
    "o4": [".32.", "3221", ".11."],
    "v4": [".3.", "322", "221", ".1."],
}


def _stamp_px(name, x, y, dark=0, sheen=False):
    """A stamp's pixels [(x, y, tone)], centred near (x, y)."""
    rows = STAMPS[name]
    ox, oy = len(rows[0]) // 2, len(rows) // 2
    out, lit_done = [], False
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == ".":
                continue
            t = max(1, int(ch) - dark)
            if sheen and ch == "3" and not lit_done:
                t, lit_done = 4, True
            out.append((x + i - ox, y + j - oy, t))
    return out


class StampLeaf(Item):
    """A cluster's rim leaf out over the lake that twitches 1 px sideways when its own slow
    sine passes 0.86, drawn every frame on top of the cluster."""
    dyn = True

    def __init__(self, x, y, name, dark, sheen, stage, t0):
        self.x, self.y, self.name, self.dark, self.sheen = x, y, name, dark, sheen
        self.states, self.t0 = {stage: "green"}, t0
        self.period = 2.8 + 1.8 * h(x, y, 93)
        self.phase = 6.283 * h(x, y, 94)

    def draw(self, cv, a, b, q, t=0.0):
        on = (a and b) or (a and q < 0.5) or (b and q >= 0.5)
        if not on:
            return
        s = math.sin(6.283 * base.Ctx.step(t, FPS) / self.period + self.phase)
        dx = 1 if s > 0.86 else 0
        for x, y, k in _stamp_px(self.name, self.x + dx, self.y, self.dark, self.sheen):
            if _reach(x, y, 2):
                cv.put(x, y, LEAF[k])


class Tuft(Item):
    """Leaf stamps round a run bloom (2026-10-11, round 3: a 1-px stem carrying blooms at an
    even pitch read as a string of fairy lights): two or three overlapping stamps, drawn
    with the run's leaves (the bloom, redrawn every frame, stays on top). Unfurls in the
    2 -> 3 play-in as a half stamp, then the stamp."""

    def __init__(self, stamps, states, t0):
        self.stamps, self.states, self.t0 = stamps, states, t0

    def draw(self, cv, a, b, q, t=0.0):
        k = 1.0 if a == b else q if b else (1.0 if q < 0.5 else 0.0)
        if k <= 0:
            return
        for name, x, y, dark, sheen in self.stamps:
            pts = _stamp_px(name, x, y, dark, sheen)
            if k < 0.6:                      # half unfurled: its lit top-left half
                pts = pts[: max(1, len(pts) // 2)]
            for px_, py_, tone in pts:
                if _reach(px_, py_, 2):
                    cv.put(px_, py_, LEAF[tone])


class Clump(Item):
    """A cluster laid out once per stage as a pixel map; in a play-in each pixel takes its
    new look when the swell from the centre reaches it."""

    def __init__(self, maps, t0s, flutters):
        self.maps, self.t0s, self.flutters = maps, t0s, flutters
        self.states = {s: True for s in maps}

    def draw(self, cv, a, b, p, dur=0.22):
        ma, mb = self.maps.get(a, {}), self.maps.get(b, {})
        if a == b:
            for (x, y), c in ma.items():
                cv.put(x, y, c)
            return
        for xy in set(ma) | set(mb):
            q = max(0.0, min(1.0, (p - min(1.0, self.t0s[xy]) * (1 - dur)) / dur))
            c = mb.get(xy) if q >= 0.5 else ma.get(xy)
            if c is not None:
                cv.put(xy[0], xy[1], c)


def _clump(cx, cy, rx, ry, seed, share2):
    body = {}
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            dx, dy = (x - cx) / (rx + 0.5), (y - cy) / (ry + 0.5)
            rr = dx * dx + dy * dy
            if rr > 1 + 0.4 * (vnoise(x, y, 3, seed) - 0.5) or not _reach(x, y, 2):
                continue
            body[(x, y)] = rr ** 0.5
    # leaf centres on a staggered lattice (3 across, 2 down), jittered a pixel
    stamps = []
    for gy in range(-ry - 1, ry + 2, 2):
        row = (gy + ry + 1) // 2
        for gx in range(-rx - 2, rx + 3, 3):
            x = cx + gx + (1 if row % 2 else 0) + int(h(gx, gy, seed) * 2.99) - 1
            y = cy + gy + int(h(gx, gy, seed + 1) * 1.99)
            if (x, y) not in body:
                continue
            r = body[(x, y)]
            ex, ey = abs(x - cx) / (rx + 1), abs(y - cy) / (ry + 1)
            k = h(x, y, seed + 2)
            if r < 0.5 and min(rx, ry) > 3:
                name = ("o4", "h4", "v4", "o4")[int(k * 3.99)]
            elif ex > ey * 1.3:
                name = "v3" if k < 0.7 else "v4"
            elif ey > ex * 1.3:
                name = "h3" if k < 0.7 else "h4"
            else:
                name = ("h3", "v3", "o4")[int(k * 2.99)]
            u = (x - cx) / (rx + 1) + (y - cy) / (ry + 1)
            dark = 1 if u > 0.35 or (u > -0.2 and h(x, y, seed + 3) < 0.25) else 0
            sheen = u < -0.3 and h(x, y, seed + 4) < 0.4
            outside = not inside_mask()[y, x]
            stamps.append((y, x, name, dark, sheen, r, outside))
    stamps.sort()
    maps, t0s, flutters = {}, {}, []
    for s in (2, 3):
        if s == 2 and share2 <= 0:
            continue
        lim = 9.0 if s == 3 else share2
        tone, lid = {}, {}
        for p_, r in body.items():
            if r < (lim if s == 3 else share2 * 0.9):
                tone[p_], lid[p_] = 0, -1
        for idx, (y, x, name, dark, sheen, r, outside) in enumerate(stamps):
            if r >= lim:
                continue
            fl = outside and (r > 0.67 and h(x, y, seed + 9) < 0.4 if s == 3
                              else r > share2 * 0.45 and h(x, y, seed + 19) < 0.35)
            if fl:
                flutters.append(StampLeaf(x, y, name, dark, sheen, s,
                                          0.12 + 0.6 * r + 0.08 * h(x, y, 4)))
                continue
            for px_, py_, k in _stamp_px(name, x, y, dark, sheen):
                if _reach(px_, py_, 2):
                    tone[(px_, py_)], lid[(px_, py_)] = k, idx
        # a pixel left alone of its leaf goes back to the gap (or away, off the body)
        for _ in range(2):
            for p_ in list(tone):
                i_ = lid[p_]
                if i_ < 0:
                    continue
                x, y = p_
                if any(lid.get(n_) == i_ for n_ in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                    continue
                if p_ in body and body[p_] < lim:
                    tone[p_], lid[p_] = 0, -1
                else:
                    del tone[p_], lid[p_]
        maps[s] = {p_: LEAF[k] for p_, k in tone.items()}
        for p_ in tone:
            r = body.get(p_, 1.0)
            t0s[p_] = 0.12 + 0.6 * r + 0.08 * h(p_[0], p_[1], 4)
    return Clump(maps, t0s, flutters)


class Bloom(Item):
    """A flower: 'bud' (stage 2), 'open' (stage 3). Its t0 is honest: in the 2->3 play-in
    it starts opening at p = t0 and is open by p = t0 + 0.3 (life.py times its visits off
    that)."""
    honest = True

    def __init__(self, x, y, kind, states, t0):
        self.x, self.y, self.kind, self.states = x, y, kind, states
        self.t0 = min(1.0, t0) * 0.7

    def draw(self, cv, a, b, q, t=0.0):
        lvl = {None: -1.0, "bud": 0.0, "open": 1.0}
        la, lb = lvl[a], lvl[b]
        if a == b or q >= 1:
            v = lb if q >= 1 else la
        else:
            v = la + (lb - la) * q
            if v < 0 and lb >= 0 and q > 0.15:
                v = 0.0
        if v >= 0:
            flower(cv, self.x, self.y, self.kind, v)


class Raceme(Item):
    """A short wisteria raceme hanging 3-5 px off the moulding: a green stalk pixel, two
    florets across at the top tapering to one, WISTERIA[3] at the top to [0] at the tip.
    Over the lake its tip swings a pixel on its own slow sine."""
    honest = True
    kind = "raceme"

    def __init__(self, x, y, n, states, t0, sway, lead=()):
        self.x, self.y, self.n, self.states = x, y, n, states
        self.lead = lead
        self.t0 = min(1.0, t0) * 0.7
        self.sway = sway
        self.period = 3.0 + 1.6 * h(x, y, 95)
        self.phase = 6.283 * h(x, y, 96)

    def draw(self, cv, a, b, q, t=0.0):
        lvl = {None: -1.0, "bud": 0.0, "open": 1.0}
        la, lb = lvl[a], lvl[b]
        v = la if a == b else lb if q >= 1 else la + (lb - la) * q
        if v < 0:
            return
        for lx_, ly_ in self.lead:
            cv.put(lx_, ly_, LEAF[1])
        cv.put(self.x, self.y, LEAF[1])
        if v < 0.34:
            cv.put(self.x, self.y + 1, WISTERIA[1])
            return
        n = max(2, int(round(self.n * min(1.0, 0.4 + (v - 0.34) / 0.66 * 0.6))))
        sw = 0
        if self.sway:
            s_ = math.sin(6.283 * base.Ctx.step(t, FPS) / self.period + self.phase)
            sw = 1 if s_ > 0.7 else -1 if s_ < -0.7 else 0
        for r in range(n):
            tone = 3 - int(round(3 * r / max(1, n - 1)))
            dx = sw if r >= n - 2 else 0
            cv.put(self.x + dx, self.y + 1 + r, WISTERIA[tone])
            if r < (n + 1) // 2:
                cv.put(self.x + 1 + dx, self.y + 1 + r, WISTERIA[max(0, tone - 1)])


class MossPx(Item):
    """One pixel that comes and goes (a moss pixel, a cluster's dark body). `flat`: lies on
    the wood, throws no shadow."""

    def __init__(self, x, y, col, states, t0, flat=False):
        self.x, self.y, self.col, self.states, self.t0 = x, y, col, states, t0
        self.flat = flat

    def draw(self, cv, a, b, q):
        if (a and b) or (a and q < 1) or (b and q > 0):
            cv.put(self.x, self.y, self.col, self.flat)


class Strand(Item):
    """Something hanging off the frame, swaying from its root."""
    dyn = True

    def __init__(self, where, x, y, lens, end, seed):
        self.where, self.x, self.y, self.lens, self.end, self.seed = where, x, y, lens, end, seed
        self.states = {s: ("dead" if s == 1 else "green") for s in lens}
        self.period = 2.8 + 1.8 * h(seed, 1, 91)
        self.phase = 6.283 * h(seed, 2, 92)

    def _sway(self, t, n):
        amp = 0 if n < 4 else 1 if n < 9 else 2
        if self.where in ("door", "paper"):
            amp = min(amp, 1)       # indoors: barely a draught
        s = math.sin(6.283 * base.Ctx.step(t, FPS) / self.period + self.phase)
        return lambda k: int(round(amp * (k / max(1, n)) ** 1.5 * s))

    def lead(self):
        """Where it leaves the frame: the pixels over the edge, and where the hanging part
        starts."""
        x, y = self.x, self.y
        if self.where == "left":
            return [(x - 1, y), (x - 2, y), (x - 3, y + 1)], (x - 4, y + 2)
        if self.where == "right":
            return [(x + 1, y), (x + 2, y + 1)], (x + 3, y + 2)
        if self.where == "sill":
            return [(x, y + 1), (x, y + 2)], (x, y + 3)
        return [(x, y + 1)], (x, y + 2)

    def drift_at(self, k):
        drift = 0
        for j in range(1, k + 1):
            if j % 4 == 0 and h(self.seed, j, 3) < 0.4:
                drift = max(-1, min(1, drift + (1 if h(self.seed, j, 4) < 0.5 else -1)))
        return drift

    def bloom_at(self, n):
        """Where its end bloom opens at rest (n px long), or None."""
        if self.end in ("leaf", "curl") or n <= 0:
            return None
        lead, (hx, hy) = self.lead()
        m = n - len(lead)
        if m < 0:
            return None
        tx, ty = hx + self.drift_at(m - 1 if m > 0 else 0), hy + m
        return (tx, ty + 3) if self.end == "wisteria" else (tx, ty + 2)

    def render(self, cv, n, dead, end_q, t, green_from=None):
        """n px long; dead: brittle brown; end_q: how open the end is (None: no end);
        green_from: in a stage-up, how far down from the root it has greened."""
        if n <= 0:
            return
        off = self._sway(t, n)
        rnd = lambda k, s=0: h(self.seed, k, s)
        is_dead = (lambda k: dead) if green_from is None else (lambda k: k >= green_from)
        # where it leaves the frame: a short run over the edge, a drape of leaves there
        lead, (hx, hy) = self.lead()
        drape = {"left": [(self.x - 3, self.y - 1, (-1, 0)), (self.x - 5, self.y + 2, (0, 1))],
                 "sill": [(self.x - 2, self.y + 3, (-1, 0)), (self.x + 2, self.y + 3, (1, 0))],
                 "paper": [(self.x + 2, self.y + 2, (1, 0))]}.get(self.where, [])
        for k, (sx, sy) in enumerate(lead):
            if k >= n:
                return
            cv.put(sx, sy, DEAD[0] if is_dead(k) else LEAF[1])
        m = n - len(lead)
        drift, px = 0, hx
        for k in range(m):
            if k and k % 4 == 0 and rnd(k, 3) < 0.4:
                drift = max(-1, min(1, drift + (1 if rnd(k, 4) < 0.5 else -1)))
            px = hx + drift + off(k)
            py = hy + k
            if is_dead(k + len(lead)):
                cv.put(px, py, DEAD[1])
                if k % 3 == 1 and rnd(k, 5) < 0.5:
                    cv.put(px + (1 if rnd(k, 6) < 0.5 else -1), py, DEAD[0])
                continue
            cv.put(px, py, LEAF[1] if k % 2 else LEAF[2])
            step = 2 if k < m * 0.5 else 3
            if k % step == 1 and k < m - 1:
                s = 1 if ((k // step) + self.seed) % 2 else -1
                if self.where == "right":
                    if s > 0:
                        cv.put(px + 1, py + 1, LEAF[3])
                    else:
                        leaf(cv, px - 1, py + 1, "small", (-1, 0), seed=self.seed + k)
                    continue
                young = k > m * 0.7
                name = "small" if young else ("heart" if rnd(k, 7) < 0.55 else "round")
                leaf(cv, px + s * 2, py + 1, name, (s, 0), dark=1 if s > 0 and rnd(k, 8) < 0.5 else 0,
                     sheen=0.3, seed=self.seed + k)
        if not is_dead(len(lead)) and n >= 4:
            for dx_, dy_, d in drape:
                leaf(cv, dx_, dy_, "round", d, dark=0, sheen=0.4, seed=self.seed + 50)
        tipx, tipy = hx + drift + off(m), hy + m
        if is_dead(n - 1):
            if rnd(0, 9) < 0.35:
                dead_leaf(cv, tipx - 1, tipy, self.seed)
            return
        if end_q is None:
            return
        if self.end == "wisteria":
            if end_q < 0.34:
                raceme_bud(cv, tipx, tipy)
            else:
                # over the lake they hang long; indoors (paper, doorway) shorter
                rows = (7 + self.seed % 3) if self.where in ("sill", "left") else (5 + self.seed % 3)
                rows = max(2, round(rows * min(1.0, (end_q - 0.34) / 0.66 * 0.6 + 0.4)))
                raceme(cv, tipx, tipy, rows, sway=off(m) - off(max(0, m - 3)))
        elif self.end == "leaf":
            leaf(cv, tipx, tipy + 1, "heart" if self.seed % 2 else "round", (0, 1), seed=self.seed)
        elif self.end == "curl":
            # a tendril's tip curling back up on itself
            for dx_, dy_ in ((0, 0), (1, 1), (2, 1), (3, 0), (3, -1), (2, -2)):
                cv.put(tipx + dx_, tipy + dy_, LEAF[2] if dy_ < 1 else LEAF[1])
        else:
            cv.put(tipx, tipy, LEAF[2])
            flower(cv, tipx, tipy + 2, self.end, end_q)


# ---------------------------------------------------------------- building the plan

_plan = {}


def _in(spans, s, i):
    return any(a <= i <= b for a, b in spans.get(s, []))


def plan():
    if "items" in _plan:
        return _plan["items"]
    stems, leaves, blooms, mosses, twigs, strands = [], [], [], [], [], []
    clumps, rblooms = [], []
    cblooms = []
    for name, segs, seed, spans in STEMS:
        path = lane_path(segs, seed)
        n3 = spans[3][-1][1]
        path = path[:n3 + 1]
        # a green stem changes step in runs of 3..6 px (LEAF[1] lit, LEAF[0] in shade)
        tones, tone, run = [], 1, 0
        for i in range(len(path)):
            if run <= 0:
                tone = 1 - tone if i else 1
                run = (3 + int(h(i, 7, seed + 63) * 3.99)) * (2 if tone == 1 else 1)
            tones.append(tone)
            run -= 1
        for i, (x, y) in enumerate(path):
            st = {s: ("dead" if s == 1 else "green") for s in (1, 2, 3) if _in(spans, s, i)}
            if st:
                stems.append(StemPx(x, y, st, 0.05 + 0.7 * i / n3, h(x, y, seed + 30) < 0.12,
                                    tones[i]))
        # the old trunk: the first TRUNK px from the root are 2 px thick and woody in every
        # stage (dark wood, a lit line on its top/left side): the dead ivy of stage 1 is
        # the same plant that lives again in stage 2
        trunk = TRUNK.get(name, 0)
        for i, (x, y) in enumerate(path[:trunk]):
            lane = _lane_of(x, y, segs)
            bx, by = (x, y - 1) if lane in ("top", "sill", "lintel") else (x - 1, y)
            if lane in ("left", "jambL"):
                bx = x + 1
            if _reach(bx, by, 1) and not (i > trunk - 4 and h(x, y, seed + 32) < 0.5):
                st = {s_: "bark" for s_ in (1, 2, 3) if _in(spans, s_, i)}
                stems.append(StemPx(bx, by, st, 0.05, True))
            stems.append(StemPx(x, y, {s_: "dead" for s_ in (1, 2, 3) if _in(spans, s_, i)}, 0.0, False))
        # leaf nodes: single leaves, pairs and rosettes, crowding near the foci
        i = 2
        alt = int(h(seed, 0, 12) < 0.5)
        while i < len(path):
            x, y = path[i]
            d = density(x, y)
            r = h(x, y, seed + 1)
            lane = _lane_of(x, y, segs)
            ox, oy = OUTWARD[lane]
            group = "rosette" if r < 0.05 + 0.4 * d else "pair" if r < 0.22 + 0.45 * d else "single"
            if lane == "right" and 100 <= y <= 255 and _in(spans, 2, i):
                group = "pair"               # the shade side's middle (it read bare in stage 2)
            alt = 1 - alt if group == "single" else alt
            side = 1 if alt else -1          # single leaves alternate sides of the stem
            sides = {"single": [(side, 0)], "pair": [(1, -1), (-1, 1)],
                     "rosette": [(1, 0), (-1, -1), (-1, 1)]}[group]
            shape0 = RUN_SHAPES[int(h(x, y, seed + 5) * 5.99)]
            for sd, al in sides:
                ax, ay = (al, 0) if oy else (0, al)
                # a two-deep leaf sits against the stem on either side (its mask is laid from
                # its own rounded centre, so the step differs by the side it is on)
                off = 2 if (ox + oy) * sd < 0 else 1
                lx, ly = x + ox * off * sd + ax, y + oy * off * sd + ay
                if not _reach(lx, ly):
                    continue
                rr = h(lx, ly, seed + 4)
                st = {}
                if _in(spans, 1, i) and rr < 0.13 + 0.12 * d:
                    st[1] = "dead"
                elif _in(spans, 1, i) and rr < 0.7:
                    # a stub where a leaf fell: one or two px of dead stalk
                    sx, sy = x + ox * sd, y + oy * sd
                    pts = [(sx, sy)] + ([(sx + ox * sd, sy + oy * sd)] if rr > 0.6 else [])
                    if all(_reach(a_, b_, 1) for a_, b_ in pts):
                        twigs.append(Twig(pts, 0.1 + 0.6 * i / n3, None))
                if _in(spans, 2, i) and rr < 0.8:
                    st[2] = "green"
                if _in(spans, 3, i):
                    st[3] = "green"
                if not st:
                    continue
                young = _in(spans, 3, i) and i > n3 - 8
                shape = "small" if young else shape0
                dark = 1 if sd < 0 or h(lx, ly, seed + 6) < 0.2 else 0
                t0 = 0.08 + 0.72 * i / n3 + 0.06 * h(lx, ly, 3)
                fl = bool(st.get(2) or st.get(3)) and not inside_mask()[ly, lx]                     and h(lx, ly, seed + 19) < 0.35
                leaves.append(Leaf(lx, ly, shape, (ox * sd, oy * sd), dark, st, t0, seed + i,
                                   sheen=0.35 if sd > 0 else 0.0, flutter=fl))
            # a bloom on the outer side
            fd = d if not (x < 100 and abs(y - WINDOW_Y) < 40) else d * 0.45
            if _in(spans, 3, i) and h(x, y, seed + 8) < 0.03 + 0.5 * fd:
                kind = _bloom_kind(x, y, seed + i)
                fx, fy = x + ox * 2 + (1 if oy else 0), y + oy * 2 + (1 if ox else 0)
                if _reach(fx, fy):
                    bst = {3: "open"}
                    if _in(spans, 2, i) and h(fx, fy, 2) < 0.6:
                        bst[2] = "bud"
                    blooms.append(Bloom(fx, fy, kind, bst, 0.12 + 0.7 * i / n3))
            gap = 2 + int(round((1 - d) ** 2 * (2.0 + 4.5 * h(x, y, seed + 9))))
            i += max(2, gap)
        # dead twigs (stage 1), some with a curled leaf hanging on: one every 5..14 px (some
        # gaps left bare), each its own length and bend, so no two along a run match
        i = 3 + int(h(seed, 0, 47) * 6)
        while i < len(path):
            x, y = path[i]
            at = i
            i += 5 + int(h(x, y, seed + 46) * 9.99)
            if not _in(spans, 1, at) or h(x, y, seed + 40) > 0.62:
                continue
            lane = _lane_of(x, y, segs)
            ox, oy = OUTWARD[lane]
            sd = 1 if h(x, y, seed + 41) < 0.72 else -1
            tilt = (0.35 + 0.6 * h(x, y, seed + 42)) * (1 if h(x, y, seed + 48) < 0.5 else -1)
            ang = math.atan2(oy * sd, ox * sd) + tilt
            n = 3 + int(h(x, y, seed + 43) * 4.99)
            pts = []
            for p_ in _curve(x, y, ang, n, seed + x + y):
                if not _reach(p_[0], p_[1], 1):
                    break
                pts.append(p_)
            if len(pts) >= 2:
                curl = int(h(x, y, seed + 44) * 6) if h(x, y, seed + 45) < 0.25 else None
                twigs.append(Twig(pts, 0.1 + 0.6 * at / n3, curl))
        # dry leaf pairs on the dead stems, one every 14..24 px where the stem is on the wood
        i = 6 + int(h(seed, 3, 48) * 8)
        while i < len(path):
            x, y = path[i]
            at = i
            i += 14 + int(h(x, y, seed + 49) * 10.99)
            if not _in(spans, 1, at):
                continue
            lane = _lane_of(x, y, segs)
            if lane in ("top", "sill", "lintel"):
                pts = [(x - 1, y - 1, 3), (x - 2, y - 1, 2), (x + 1, y + 1, 2), (x + 2, y + 1, 1)]
            else:
                pts = [(x - 1, y - 1, 3), (x - 1, y - 2, 2), (x + 1, y + 1, 2), (x + 1, y + 2, 1)]
            fm, ins = frame_mask(), inside_mask()
            if all(0 <= px_ < W and 0 <= py_ < H and fm[py_, px_] and ins[py_, px_]
                   for px_, py_, _k in pts):
                twigs.append(DryPair(pts, 0.1 + 0.6 * at / n3))
        # stage 3's run blooms (2026-10-11, second review: the long runs read as ivy with
        # speckles): a bloom every 10..14 px along the outer runs, roses (3x3, or the 5-px
        # one every third, every fourth rose red) by turns with a small white flower or a
        # half-open bloom, a bud beside some; and every ~40 px a short wisteria raceme, off
        # the top run's inner edge onto the paper or off a side's outer edge onto the lake
        if segs[0][0] in ("top", "sill", "left", "right"):
            i, c, rc = 5 + int(h(seed, 4, 70) * 6), 0, 0
            paper = [sx for w_, sx, sy, *_ in STRANDS if w_ == "paper"]
            sides = [sy for w_, sx, sy, *_ in STRANDS if w_ in ("left", "right")]
            next_rac = 18 + int(h(seed, 5, 71) * 20)
            while i < len(path):
                x, y = path[i]
                at = i
                # an uneven pitch: gaps of 6..24 px, now and then a pair close together
                rp = h(x, y, seed + 72)
                if rp < 0.2:
                    i += 5 + int(h(x, y, seed + 80) * 1.99)
                else:
                    i += 6 + int(((rp - 0.2) / 0.8) ** 1.4 * 18.99)
                if not _in(spans, 3, at):
                    continue
                lane = _lane_of(x, y, segs)
                if lane not in ("top", "sill", "left", "right"):
                    continue
                if lane == "top" and 222 <= x <= 282:
                    continue
                ox, oy = OUTWARD[lane]
                if c % 2 == 0:
                    kind = "rose5" if rc % 3 == 2 else "rose3"
                    if rc % 4 == 3:
                        kind += "_red"
                    rc += 1
                else:
                    kind = "white2" if (c // 2) % 2 == 0 else "half"
                c += 1
                bx, by = x + ox, y + oy
                if kind.startswith("rose3"):
                    bx, by = x + ox * 1, y + oy * 1
                if not all(_reach(bx + dx_, by + dy_, 2) for dx_ in (-1, 0, 1) for dy_ in (-1, 0, 1)):
                    continue
                bst = {3: "open"}
                if _in(spans, 2, at) and h(bx, by, 73) < 0.5:
                    bst[2] = "bud"
                t0 = 0.12 + 0.7 * at / n3
                rblooms.append(Bloom(bx, by, kind, bst, t0))
                leaves.append(_tuft(x, y, ox, oy, seed + at, t0))
                if h(x, y, seed + 74) < 0.45:      # a bud beside it, further along
                    k2 = ("bud_pink", "bud_white", "bud_violet")[int(h(x, y, seed + 75) * 2.99)]
                    ax_, ay_ = (5, 0) if oy else (0, 5)
                    sgn = 1 if h(x, y, seed + 76) < 0.5 else -1
                    qx, qy = bx + ax_ * sgn, by + ay_ * sgn + (1 if oy else 0)
                    if _reach(qx, qy, 2) and _reach(qx, qy + 1, 2):
                        rblooms.append(Bloom(qx, qy, k2, {3: "open"}, t0 + 0.05))
                if at >= next_rac:
                    next_rac = at + 34 + int(h(x, y, seed + 77) * 12)
                    n = 3 + int(h(x, y, seed + 78) * 2.99)
                    rst = {3: "open"}
                    if _in(spans, 2, at) and h(x, y, 79) < 0.5:
                        rst[2] = "bud"
                    if lane == "top" and all(abs(x - px_) > 8 for px_ in paper):
                        rblooms.append(Raceme(x, 62, n, rst, t0, False, lead=[(x, 61)]))
                    elif lane == "left" and all(abs(y - py_) > 7 for py_ in sides)                             and not WINDOW_GAP[0] - 8 <= y <= WINDOW_GAP[1] + 2:
                        rblooms.append(Raceme(XL - 2, y + 1, n, rst, t0, True,
                                              lead=[(XL - 1, y)]))
                    elif lane == "right" and y > 74 and all(abs(y - py_) > 7 for py_ in sides):
                        rblooms.append(Raceme(XR + 1, y + 1, n, rst, t0, True,
                                              lead=[(XR, y)]))
    # clusters (2026-10-11, second review: single pixels in four greens read as noise): built
    # from leaf stamps (3x2, 2x3, 4x2 and 4x3 ovals: LEAF[3] lit top-left, LEAF[2] body,
    # LEAF[1] underside) overlapping back to front over a LEAF[0] body that shows only in the
    # gaps; the cluster's lower-right leaves a step darker (never to LEAF[0]); a pixel left
    # alone of its leaf by the ones over it goes back to the gap. The rim leaves out over the
    # lake twitch (40% in stage 3, 20% of stage 2's rim), drawn every frame on top.
    for cx, cy, rx, ry, seed, share2, flw in CLUSTERS:
        clumps.append(_clump(cx, cy, rx, ry, seed, share2))
        leaves.extend(clumps[-1].flutters)
        for j, (kind, fx, fy) in enumerate(flw):
            x, y = int(round(cx + fx * rx)), int(round(cy + fy * ry))
            if not _reach(x, y, 2):
                continue
            bst = {3: "open"}
            if share2 > 0 and (fx * fx + fy * fy) ** 0.5 < share2 + 0.15:
                bst[2] = "bud"
            cblooms.append(Bloom(x, y, kind, bst, 0.3 + 0.5 * h(x, y, 7)))
    for cx, cy, rx, ry, seed, n in TANGLES:
        twigs.extend(_tangle(cx, cy, rx, ry, seed, n))
    for c in CUSHIONS:
        mosses.extend(_cushion_items(c))
    for args in STRANDS:
        strands.append(Strand(*args))
    # the authored cluster flowers first, then the stems' own: a bloom too close to one
    # already kept is dropped (in every stage, so stage 2's bud never sits where no flower
    # opens)
    blooms = _spaced(cblooms + rblooms + blooms)
    _plan["items"] = (mosses, stems, twigs, leaves, blooms, strands, clumps)
    return _plan["items"]


def _tangle(cx, cy, rx, ry, seed, n):
    """A corner's dead tangle: n bare twigs crossing every way, each a curve turning 45
    degrees at most every 3 px, forking now and then, a few curled leaves caught in it."""
    out = []
    for k in range(n):
        a = h(k, 0, seed) * 6.283
        r = h(k, 1, seed) ** 0.7
        x0 = int(round(cx + math.cos(a) * r * rx))
        y0 = int(round(cy + math.sin(a) * r * ry))
        ang = h(k, 2, seed) * 6.283
        ln = 4 + int(h(k, 3, seed) * 4.99)
        pts = []
        for p_ in [(x0, y0)] + _curve(x0, y0, ang, ln, seed + k):
            if not _reach(p_[0], p_[1], 1):
                break
            pts.append(p_)
        if len(pts) < 3:
            continue
        if h(k, 4, seed) < 0.35 and len(pts) >= 4:
            fx, fy = pts[len(pts) // 2]
            fang = ang + (0.6 if h(k, 8, seed) < 0.5 else -0.6)
            fork = _curve(fx, fy, fang, 2 + int(h(k, 9, seed) * 2.99), seed + 50 + k)
            if fork and all(_reach(a_, b_, 1) for a_, b_ in fork):
                out.append(Twig(fork, 0.1 + 0.5 * h(k, 7, seed), None))
        curl = int(h(k, 5, seed) * 6) if h(k, 6, seed) < 0.2 else None
        out.append(Twig(pts, 0.1 + 0.5 * h(k, 7, seed), curl))
    return out


def _box(b):
    """A bloom's open box on the grid: (x0, y0, x1, y1, is_rose)."""
    if b.kind == "raceme":
        d = (0, 0, 1, b.n + 1)
    elif b.kind.startswith("bud_"):
        d = (0, 0, 0, 1)
    elif b.kind in ("white2", "half") or b.kind.startswith("rose5"):
        d = (0, 0, 2 if b.kind.startswith("rose5") else 1, 1)
    elif b.kind.startswith("rose") and not b.kind.endswith("_s"):
        d = ROSE_BOX
    else:
        d = SMALL_BOX
    return (b.x + d[0], b.y + d[1], b.x + d[2], b.y + d[3], b.kind.startswith("rose"))


def _tuft(x, y, ox, oy, seed, t0):
    """Two or three leaf stamps round a run bloom at stem point (x, y): one each side along
    the run (3..5 px off), sometimes one behind it on the inner side, the inner ones a step
    darker. Horizontal stamps on the top run and the sill, upright ones down the stiles."""
    along = (1, 0) if oy else (0, 1)
    flat = ("h3", "h4", "o4", "h3") if oy else ("v3", "v4", "v3", "v4")
    out = []
    n = 2 + (h(x, y, seed + 81) < 0.55)
    for j in range(n):
        r = h(x, y, seed + 82 + j)
        name = flat[int(r * 3.99)]
        if j < 2:
            sg = -1 if j == 0 else 1
            dist = 3 + int(h(x, y, seed + 86 + j) * 2.99)
            across = 1 if h(x, y, seed + 88 + j) < 0.6 else 0      # 1: out over the edge
            cx = x + along[0] * sg * dist + ox * across
            cy = y + along[1] * sg * dist + oy * across
            dark = 0 if across else 1
        else:                                # one behind, on the inner side of the stem
            cx, cy = x - ox * 2 + along[0], y - oy * 2 + along[1]
            dark = 1
        out.append((name, cx, cy, dark, h(cx, cy, seed + 90) < 0.3))
    return Tuft(out, {3: "green"}, t0)


def _spaced(blooms):
    """Keep blooms apart (2026-10-11 review): two rose heads with 3 px of leaf between
    (centres 7 px apart for the big ones), a rose and any flower 2 px, any two flowers
    1 px. First come first kept, so the authored cluster flowers win."""
    kept, boxes = [], []
    for b in blooms:
        x0, y0, x1, y1, rose = _box(b)
        ok = True
        for a0, b0, a1, b1, arose in boxes:
            gap = 3 if rose and arose else 2 if rose or arose else 1
            if x0 <= a1 + gap and a0 <= x1 + gap and y0 <= b1 + gap and b0 <= y1 + gap:
                ok = False
                break
        if ok:
            kept.append(b)
            boxes.append((x0, y0, x1, y1, rose))
    return kept


def _bloom_kind(x, y, seed):
    r = h(x, y, seed)
    if math.hypot(x - 252, y - 54) < 30:
        # the lintel's three heads are authored (CLUSTERS); the stems round the door carry
        # small blooms and small roses only, so the arch never runs into a band of heads
        if y < 60:
            return ("pink", "daisy", "pink")[int(r * 2.99)]
        return "rose_red_s" if r < 0.5 else "rose_pink_s"
    if abs(y - WINDOW_Y) < 34 and x < 100:
        return ("daisy", "yellow", "pink")[int(r * 2.99)]
    if y > 290:
        return ("pink", "daisy", "pink", "rose_pink_s", "yellow")[int(r * 4.99)]
    if y < 70:
        return ("yellow", "daisy", "pink", "rose_red_s")[int(r * 3.99)]
    return ("pink", "daisy", "yellow")[int(r * 2.99)]


# Moss patches (2026-10-11, round 3 review: the domed cushions read as stamped bushes). The
# neglected hut's roof moss as it lies on the moulding: flat, ragged patches IN the wood,
# 1-2 px thick (3 at a corner), 3-12 px long, MOSS[2] body, MOSS[1] where it creeps into a
# crease and at ragged ends, a scattered MOSS[3] speck, no domed highlight. A patch hugs one
# side of a board, against a groove, and wicks a pixel or two into that groove. Spaced
# irregularly (gaps of 6-40 px, now and then two or three touching), longer and thicker
# toward the corners; only at the two bottom corners does it spill over the outer edge onto
# the lake. Flat: it throws no shadow.
#   MOSS_BANDS: run -> [(hug row/col, wick row/col or None, grow dir across)]
#   A patch: (run, at, n, th, opt, seed, kept2, crown)
MOSS_BANDS = {
    # top run: outline 52, wood 53..55, groove 56, wood 57..60, inner outline 61
    "top": [(55, 56, -1, 3), (57, 56, 1, 4), (60, 61, -1, 4)],
    # sill: inner outline 298, wood 299..301, groove 302, wood 303..306, outer outline 307
    "sill": [(301, 302, -1, 3), (299, 298, 1, 3), (303, 302, 1, 4), (306, None, -1, 4)],
    # the back wall's floor rail: outline 84, wood 85..87, groove 88, wood 89..92, outline 93
    "foot": [(87, 88, -1, 3), (89, 88, 1, 4), (92, 93, -1, 4)],
    # the stiles: outer outline 84 / 419, wood 85..88 / 415..418, inner outline 89 / 414
    "left": [(88, 89, -1, 4), (85, None, 1, 4)],
    "right": [(415, 414, 1, 4), (418, None, -1, 4)],
}
_ALONG_X = ("top", "sill", "foot")


def _moss_plan():
    """Where the patches lie. Authored by rule off fixed seeds, so the same every save."""
    out = []
    corners = {"top": (XL, XR), "sill": (XL, XR), "left": (YT, YB), "right": (YT, YB)}

    def run(name, a0, a1, seed, skip=(), busy=1.0):
        lo, hi = corners[name]
        s = a0 + int(h(a0, 1, seed) * 5)
        k = 0
        group = 0
        while s < a1:
            r = lambda j: h(s, j, seed)
            near = min(s - lo, hi - s)
            ck = max(0.0, 1.0 - near / 44.0)            # 1 at a corner, 0 from 44 px in
            n = 3 + int(r(2) * 6.99) + int(ck * 4.5)
            th = 1 + (r(3) < 0.45 + 0.4 * ck) + (r(4) < 0.45 * ck * ck)
            opt = int(r(5) * len(MOSS_BANDS[name]) * 0.999)
            if MOSS_BANDS[name][opt][1] is None and r(6) < 0.6:
                opt = 0                                  # most patches sit in a crease
            if not any(a <= s <= b or a <= s + n - 1 <= b for a, b in skip):
                bottom = name == "sill" or (name in ("left", "right") and s + n > YB - 16)
                crown = bottom and ck > 0.55
                out.append((name, s, n, th, opt, seed + k, False, crown))
            k += 1
            if group < 2 and r(7) < 0.22 + 0.25 * ck:    # the next one touches this one
                group += 1
                s += n - 1 + int(r(8) * 2.99)
                continue
            group = 0
            gap = 6 + int((r(9) ** 1.5) * 34.99)
            s += n + max(6, int(gap * busy * (1.0 - 0.45 * ck)))

    run("top", XL + 16, XR - 18, 201, skip=((226, 278),))
    run("sill", XL + 16, XR - 18, 202, skip=((284, 299),))
    run("left", YT + 18, YB - 18, 203, skip=((WINDOW_GAP[0] - 6, WINDOW_GAP[1] + 3),))
    run("right", YT + 20, YB - 18, 204, busy=0.7)       # the shade side, wetter
    # the corners: a mat in both boards of a run with the groove between half filled, and a
    # longer patch down the stile; at the bottom two the moss spills over onto the lake
    out += [("top", 85, 12, 3, 0, 231, False, False), ("top", 87, 9, 2, 1, 232, False, False),
            ("left", 63, 10, 2, 0, 233, False, False), ("left", 57, 6, 2, 1, 234, False, False),
            ("top", 403, 13, 3, 0, 235, False, False), ("top", 407, 8, 2, 1, 236, False, False),
            ("right", 63, 11, 2, 0, 237, False, False), ("right", 76, 4, 1, 1, 238, False, False),
            ("sill", 86, 13, 3, 2, 239, False, True), ("sill", 89, 9, 2, 0, 240, False, False),
            ("left", 283, 13, 2, 0, 241, False, True), ("left", 294, 9, 2, 1, 242, False, True),
            ("sill", 401, 14, 3, 2, 243, False, True), ("sill", 404, 9, 2, 0, 244, False, False),
            ("right", 282, 14, 2, 0, 245, False, True), ("right", 293, 8, 2, 1, 246, False, True)]
    # the leak's wet spots: the wall foot in the shade side, the sill under it (stage 2 keeps
    # the two marked True: a long thin smear in the floor rail's crease, a short one beside
    # it, and one on the sill)
    out += [("foot", 355, 11, 3, 1, 225, True, False), ("foot", 365, 4, 1, 0, 226, True, False),
            ("foot", 381, 5, 1, 2, 227, False, False), ("foot", 398, 7, 2, 1, 228, False, False),
            ("sill", 286, 10, 3, 2, 229, True, False)]
    return out


CUSHIONS = _moss_plan()


def _cushion(run, at, n, th, opt, seed, kept2, crown):
    """One patch's pixels and their MOSS steps (see CUSHIONS)."""
    if crown:                         # a spilling patch lies against the outer edge
        opt = {"sill": 3, "left": 1, "right": 1}.get(run, opt)
    hug, wick, d, room = MOSS_BANDS[run][opt]

    def xy(s, a):                     # along, across -> pixel
        return (s, a) if run in _ALONG_X else (a, s)

    px = {}
    # the thickness wanders a pixel at a time (never a symmetric lens, which reads as a dome)
    prev = 1
    for i in range(n):
        s = at + i
        r = h(s, 11, seed)
        if i == 0 or i == n - 1:
            t = 1
        else:
            if prev < th:
                step = 1 if r < 0.55 else -1 if r > 0.92 else 0
            else:
                step = -1 if r < 0.28 else 0
            t = max(1, min(th, prev + step))
            if t == 1 and prev == 1 and h(s, 21, seed) < 0.1:
                prev = 1
                continue                  # a bare pixel inside the patch
        prev = t
        for k in range(min(t, room)):
            px[xy(s, hug + d * k)] = 2
        if t == 1 and h(s, 12, seed) < 0.3:
            px[xy(s, hug)] = 1
    # lit from above (and the left): where a body is two deep its lower (right-hand) pixel
    # is the shaded step
    for (x, y) in list(px):
        a, b = ((x, y - 1), (x, y + 1)) if run in _ALONG_X else ((x - 1, y), (x + 1, y))
        if px[(x, y)] == 2 and a in px and b not in px:
            px[(x, y)] = 1
    # ragged ends: a loose pixel a gap past either end now and then
    for j, s in ((0, at - 2), (1, at + n + 1)):
        if h(at, 13 + j, seed) < 0.4:
            px[xy(s, hug)] = 1
    # wicks: a pixel or two crept into the groove beside the hugged edge
    if wick is not None:
        w = 0
        for i in range(1, n - 1):
            if w < 3 and h(at + i, 15, seed) < (0.16 if n > 4 else 0.3):
                px[xy(at + i, wick)] = 1
                w += 1
                if h(at + i, 16, seed) < 0.35 and i + 1 < n:
                    px[xy(at + i + 1, wick)] = 1
        if w == 0 and n >= 5:
            px[xy(at + n // 2, wick)] = 1
    # the two bottom corners: moss spilling over the outer edge onto the lake
    if crown:
        for i in range(1, n - 1):
            s = at + i
            if h(s, 17, seed) < 0.7:
                if run == "sill":
                    px[(s, YB)] = 2 if h(s, 20, seed) < 0.6 else 1
                    if h(s, 18, seed) < 0.5:
                        px[(s, YB + 1)] = 1
                elif run in ("left", "right"):
                    e = XL if run == "left" else XR
                    o = -1 if run == "left" else 1
                    px[(e, s)] = 2 if h(s, 20, seed) < 0.6 else 1
                    if h(s, 18, seed) < 0.5:
                        px[(e + o, s)] = 1
    # scattered specks of the lit step on the body, never two side by side
    out = dict(px)
    for (x, y), tone in px.items():
        if tone == 2 and h(x, y, seed + 19) < 0.11:
            if not any(out.get((x + a, y + b)) == 3 for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[(x, y)] = 3
    return out


def _cushion_items(c):
    kept2 = c[6]
    seed = c[5]
    allowed = allowed_mask(BOARD)
    items = []
    for (x, y), t in _cushion(*c).items():
        if not (0 <= x < W and 0 <= y < H) or not allowed[y, x]:
            continue
        if x < XL + 9 and WINDOW_GAP[0] <= y <= WINDOW_GAP[1] and x >= XL - 2:
            continue
        st = {1: True}
        if kept2:
            st[2] = True
        items.append(MossPx(x, y, MOSS[t], st,
                            0.05 + 0.4 * h(x, y, seed + 5) + 0.2 * h(seed, 1, 2), flat=True))
    return items


# ---------------------------------------------------------------- drawing

_static = {}


def _draw_items(cv, a, b, p, t, which):
    mosses, stems, twigs, leaves, blooms, strands, clumps = plan()

    def qof(it, dur=0.22):
        # an item's t0 (0..1) is squeezed into 0..1-dur, so every change has landed by
        # p = 1; a Bloom's t0 is already honest (life.py reads it)
        if a == b:
            return 1.0
        t0 = it.t0 if getattr(it, "honest", False) else min(1.0, it.t0) * (1 - dur)
        return max(0.0, min(1.0, (p - t0) / dur))

    if which in ("static", "all"):
        for it in mosses:
            sa, sb = it.state(a), it.state(b)
            if sa or sb:
                it.draw(cv, sa, sb, qof(it, 0.3))
        for it in stems:
            it.draw(cv, it.state(a), it.state(b), qof(it, 0.12))
        for it in twigs:
            it.draw(cv, it.state(a), it.state(b), qof(it))
    # the leaves that never move are cached; the rim leaves that twitch, then the blooms
    # (so no twitching leaf ever covers a flower), then what hangs, are drawn every frame
    for dyn in (False, True):
        if which == "static" and dyn or which == "dyn" and not dyn:
            continue
        for it in leaves:
            if it.dyn != dyn:
                continue
            sa, sb = it.state(a), it.state(b)
            if sa or sb:
                it.draw(cv, sa, sb, qof(it), t)
        if not dyn:
            for c in clumps:
                if c.state(a) or c.state(b):
                    c.draw(cv, a, b, p)
    if which in ("dyn", "all"):
        for it in blooms:
            sa, sb = it.state(a), it.state(b)
            if sa or sb:
                it.draw(cv, sa, sb, qof(it, 0.3), t)
    if which in ("dyn", "all"):
        for s in strands:
            na, nb = s.lens.get(a, 0), s.lens.get(b, 0)
            if a == b:
                if na:
                    s.render(cv, na, a == 1, 1.0 if a == 3 else 0.0, t)
                continue
            q = max(0.0, min(1.0, (p - 0.15 - 0.35 * h(s.seed, 5, 1)) / 0.45))
            n = int(round(na + (nb - na) * q))
            endq = 0.0 if b == 2 else max(0.0, (q - 0.4) / 0.6)
            if a == 1 and na and nb:
                s.render(cv, max(n, 1), False, endq if q > 0.5 else None, t,
                         green_from=int(round(n * min(1.0, q * 1.6))))
            elif nb:
                s.render(cv, n, False, endq if (q > 0.5 or a == 2 and na) else None, t)
            elif na and q < 0.5:
                s.render(cv, na, a == 1, 1.0 if a == 3 else 0.0, t)


def _finish(cv, ctx, under):
    c = cv.c
    allowed = allowed_mask(ctx.board)
    a = (c[..., 3] > 0) & allowed
    inside = inside_mask()
    ring = np.zeros_like(a)
    ring[1:, :] |= a[:-1, :]
    ring[:-1, :] |= a[1:, :]
    ring[:, 1:] |= a[:, :-1]
    ring[:, :-1] |= a[:, 1:]
    ring &= ~a & ~inside & allowed
    out = np.zeros((H, W, 4), np.float32)
    out[a] = c[a]
    out[ring, :3] = INK
    out[ring, 3] = 255
    o = (a | ring) & ~inside
    out[o, :3] = out[o, :3] * DIM + DIM_ADD
    # only what has body throws a shadow: pixels in a filled 2x2 (leaves, the 2-px trunk),
    # never a 1-px stem or twig (shadowed, it read 2 px wide and muddy) nor flat moss
    cast = a & ~cv.flat
    blk = cast[:-1, :-1] & cast[1:, :-1] & cast[:-1, 1:] & cast[1:, 1:]
    thick = np.zeros_like(a)
    thick[:-1, :-1] |= blk
    thick[1:, :-1] |= blk
    thick[:-1, 1:] |= blk
    thick[1:, 1:] |= blk
    sh = np.zeros_like(a)
    sh[1:, 1:] = thick[:-1, :-1]
    sh &= ~a & inside
    shadow = np.zeros((H, W, 4), np.uint8)
    shadow[sh, 3] = SHADOW_A
    under.alpha_composite(Image.fromarray(shadow, "RGBA"))
    under.alpha_composite(Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA"))


def draw(stage, t, ctx, under, over):
    if stage not in _static:
        cv = Cv()
        _draw_items(cv, stage, stage, 1.0, 0.0, "static")
        _static[stage] = (cv.c.copy(), cv.flat.copy())
    cv = Cv()
    cv.c[:], cv.flat[:] = _static[stage]
    _draw_items(cv, stage, stage, 1.0, t, "dyn")
    _finish(cv, ctx, under)


def stage_up(frm, p, ctx, under, over):
    cv = Cv()
    _draw_items(cv, frm, frm + 1, p, getattr(ctx, "t", 0.0), "all")
    _finish(cv, ctx, under)


def flower_spots(stage):
    """The open blooms at a stage, [(x, y, kind)] on the source grid (for life.py: bees and
    butterflies visit them, petals fall from them). Strand ends at rest included."""
    out = [(b.x, b.y, VISIT_KIND.get(b.kind, b.kind)) for b in plan()[4]
           if b.state(stage) == "open" and not b.kind.startswith("bud_")]
    if stage == 3:
        for s in plan()[5]:
            at = s.bloom_at(s.lens.get(3, 0))
            if at:
                out.append((at[0], at[1], s.end))
    return out


CLOSEUPS = [
    ("veg_corner_s1", 1, (356, 34, 70, 58)),     # the roof corner: moss mats, dead stems
    ("veg_door_s1", 1, (222, 44, 58, 54)),       # dead roots in the doorway, bare jambs
    ("veg_corner_s2", 2, (64, 262, 76, 64)),     # the ivy greened, buds, first strands
    ("veg_door_s2", 2, (222, 44, 58, 54)),       # the jambs climbed, the lintel framed
    ("veg_corner_s3", 3, (64, 262, 84, 64)),     # the bottom-left cascade in flower
    ("veg_door_s3", 3, (216, 40, 72, 46)),       # the rose arch, wisteria at the door
    ("veg_strand", 3, (370, 296, 54, 31)),       # the bottom-right cascade over the lake
    ("veg_wisteria", 3, (120, 52, 40, 30)),      # tendrils and wisteria down the paper
    ("veg_window_s3", 3, (64, 166, 40, 62)),     # the window on the left wall, framed
]

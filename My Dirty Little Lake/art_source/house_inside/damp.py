"""damp.py -- the house-stages mockup: water and decay (2026-10-11).

Everything here is whole source pixels on hard steps; the only mixes are the cobwebs' threads,
the wet halos and the stains' shadows, each one fixed step over what is under it. Colours are
the lake's clean water ramp (base.WATER), its foam, the hut's LEAF / DEAD ramps and the room's
own paper, read off the shell.

STAGE 1 (abandoned)
  PUDDLES p2 p3 at layout.json's centres and sizes. A puddle is three overlapping lobes (the
    biggest nudged to the low, right side), its edge nudged by noise, with 1-px fingers wicking
    along the seam grooves (1 px left, 1-3 px right). Painted: far edge and sides one ramp step
    darker than the body, the near edge (lip) one step lighter, the plank seams showing through
    as dashes one step down (only well inside the water), level reflection dashes on the first
    inner rows, a glint. Looks:
      p1 lit    drawn by hand (P1_ROWS) inside its footprint (12 x 5, abs 90..101 x 184..188):
                a lumpy lozenge, rounder on the window side, its low right side sagging a row,
                a pixel of wet wood between it and the left moulding; far edge WATER[2], body
                WATER[3], near lip WATER[4], the window's reflection in WATER[4] across its
                widest inner row (window side), a white-then-foam glint. Painted as what must
                SHOW and run through aimed() (composed = (light + (1 - dim) * painted) under
                life.py's veil), a colour past what the frame can show there scaled down whole
                (hue kept), a near-white glint clipped to the brightest there is: the lightest
                water in the room
      p2 open   body WATER[2], dark WATER[1], lip WATER[3], dashes WATER[3], a foam glint
      p3 shade  body WATER[1], dark WATER[0], lip WATER[2], a 3-px WATER[3] dash on its far
                edge and one foam pixel
    WET HALO: the boards within 1 px a step darker (WET (56,28,16) at 0.30), a broken second
    step (0.15) out to 2 px on the left and 4 px on the low right, and further along the seams.
    In rain a puddle grows to rain_grow (x1.4, x1.4, x1.5) across, 0.6 of that down.
  p1's WET LINE: a 1-px WATER[2] line along rel row 102 from the puddle's right edge to h1's
    notch (rel x 37), a pixel of WATER[1] here and there, two or three pixels of plain wet wood
    where it thins, a 1-px kink into each butt joint (aimed like p1). Every 1.8 s (faster in
    rain) a bead slides along it in 6 ticks, then one pixel drops over the lip into h1 over 3
    ticks, then nothing until the next bead.
  DRIPS from the ceiling, DRIP_HIGH 32 px above each landing on screen: p1 every 2.6 s, p2 3.3 s
    (landing 8 px right, 1 px down of its centre: beside the boots, clear of the figure), p3
    2.2 s, the flue into h4's ash-mud at rel (221, 101) (left of the joist and the seedling)
    every 3.8 s; each drop jittered +-22% of
    its period; every period halved in a full shower. A drop's life:
      bead   SWELL 0.25 s, two ticks: a dim speck where the drop's top pixel will be, then the
             2-px teardrop growing down from it, exactly where the fall's first tick draws it
             (it only ever grows and moves down: never a pixel above the speck)
      fall   DRIP_FALL 0.40 s, accelerating (y ~ s^2), 1 x 2 px (foam over WATER[4]) with a
             1-px WATER[2] trail at alpha 140 once it has fallen 2 px. p1's drop burns white-gold in the lit band (its last tick before
             landing is held inside it) and lands with a 1-tick white pixel. No four-point
             star: in this game that means a find. A drop is hidden while it falls behind a
             walker standing over its landing (p2 lands just in front of the angler's boots)
      crown  in over, the landing tick: one foam pixel 2 px above the landing; 2 foam
             droplets thrown out and up under 360 px/s^2, gone in SPLASH_LIFE 0.32 s
      ring   in under: a 2:1 ellipse of foam dashes (2 on, 1 off round it), its half-width
             3 -> 4 -> 5 -> 6 over four 8-fps ticks, faded on the last, clipped to the water;
             only while it animates (the stills are timed so no ring stands at rest)
    The flue's ring is a 2:1 outline 5 x 3 opening to 9 x 5 over five ticks in the ash-mud's
    own light steps (ASH), dissolving a pixel at a time, drawn only on ash-mud pixels.
  TWINKLES: between drips, every 12 ticks per puddle one inner pixel flicks white a tick and
    foam a tick.
  RAIN INTO h3 (shower only): 22 drops at full rain falling 32 px in 0.22 s onto random pixels
    of h3's blocks, 3-px streaks; on earth a WATER[3] pixel at 0.6 and two MUD[2] (MOSS[3] on
    the joist) flecks at 0.4, foam only where a drop lands in p3's water.
  THE PATH IN RAIN (shower only, rain >= 0.25): the boots' worn dish (abs x ~252, y 96..134):
    whole board segments one hard WET step darker, their ends on seams and butt joints, the
    seams between two wet boards too, and one or two 2-3 px WATER[4] glints along a seam
    inside. No water stands on the door's lane.
  THE WALL, right half of the back paper (x 269..413, y 62..83):
    every stain is the paper's own colour stepped down (LEVELS 1..6), never a lighter fill.
      BLOOMS spread from the top moulding where the roof let water in, at x 300 (old), 327
      (wet), 345 (old), 358 (faint) and 385 (wet, mostly under the flap): each the union of
      three to five circles hung from just above the moulding, every one rolled its own size
      and place, so the lower edge is a run of uneven scallops, never a bowl or a goblet; where
      two meet the deeper owns the column. A tide line (the rim, broken here and there) round
      the edge and down the sides below the top two rows, a band inside it, a receded line a
      row or two further in, broken, and a soaked band under the moulding (BLOOM_LOOK). STREAKS
      run on down off the lower edge, two pixels where they leave it, one below, stepping a
      pixel the way they lean at most twice, each ending a step darker; the two long ones off
      the wet blooms stop 3 rows above the foot band. No cores, no straight runs. A darker
      band along the foot from x 298 (1.5 rows) rising to the corner (~8.5 rows), its top row
      the tide line; an older tide line 3 rows above it, broken. Mould is ten irregular
      2-5 px clusters of MOSS[0]/[1] under the torn corner, no two alike
    the flap: strip 378..390's top came unglued and hangs folded off a hinge sloping from row
      66 (left) to 70 (right): the paper's ramp two steps down (FLAP), FLAP_SIDE on its sides,
      a 1-px lit edge along the outer fold, INK only on the underside facing the gap, one hard
      shadow row under it and down its right side;
      the lap boards behind with butt joints
    the torn corner: x 402..413, a ragged diagonal tear, a fibre edge, its foot lifting off
    water still running: a bead slides out of each wet bloom and down its long streak a pixel
      a tick, every ~4 s (twice as often in rain)
    the left half (the dry side): yellowed in broad patches along its top, one step (YELLOWED)
  COBWEBS: crisp 1-px threads (WEB_MAP, by hand), each one fixed step (WEB_STEP) off what is
    under it: darker on the paper, lighter on the torn corner's dark boards. The wall's top
    corners only, (90, 62) and (413, 62, mirrored): two spokes at 30 and 60 degrees, the hub
    open, two taut threads strung wall to wall across them, the outer one broken and hanging.
    Nothing lies along the walls (that read as a bracket). None in the doorway, none on the
    floor. The top-left one's spider lets itself down 7 px every 9 s and climbs back.
  MUSHROOMS, no ink ring, lit from the window's side like the hut's plants: m1 cream caps with a
    DEAD rim and a gill row over a paler stem, by p3; m2 two stepped bracket shelves (6 and 4
    wide) on the right wall's inner edge (banded top, lit rim, DEAD[0] underside); m3
    chocolate caps at the tented boards' foot; m4 three pale pins (WHITE/DEAD caps, a dark
    underside inked at its ends, 1-px stems of three heights) at the back wall's foot;
    m5 two chocolate caps by the crease. A pixel of damp shade under each.
  WEEDS out of the skirting's crack: 14 tufts (2-3 blades fanning from one root, lit tips, the
    dead ones straw with a seed head) along the back wall, the left wall, the right wall's wet
    margin and the sill, off the door's lane and the holes; the tips sway a pixel in a slow
    draught on the 8 fps clock.

STAGE 2 (semi-fixed)
  p1 alone, P1_ROWS[2] (8 x 4, its footprint filled: the same rules a step deeper, WATER[1]
  far edge, WATER[2] body, WATER[3] reflection and lip, or pale water on the pale new boards
  is not there),
  dripping every 4.4 s (no ring up in the still), its wet line only a 4-px run off its right
  edge; m6 two cream caps 3 rows below its lip. The wall's two worst strips (x 360..413)
  re-papered a hair fresher (FRESH_PAPER), joins at 360 and 390; the rest keeps stage 1's
  stains one level fainter (the faintest gone). No webs, weeds, other mushrooms.

STAGE 3 (fixed): nothing.

STAGE UP (p 0..1 over ~2 s, held to the 8 fps clock)
  1 -> 2  no drips; p2 and p3 shrink in 6 steps and are gone by p 0.7, their halos fading in 3
          steps (p 0.15..0.85); p1 shrinks to its stage-2 size in 4 steps by p 0.6, its line
          lengthening onto the new boards; the webs (by p 0.45), mushrooms (0.55) and weeds
          (0.6) dissolve a pixel at a time; the stains dry from their feet up, every pixel at
          its own moment (rims and fill alike, never an outline alone) in 6 steps (p 0.05..0.75),
          the ghost line left behind, while the new paper unrolls down the two strips (p 0.2..0.8, its rolled end
          pale over a shade row); m6 pushes up from its foot (p 0.55..0.95).
  2 -> 3  p1 shrinks away by p 0.65, its halo fading by 0.9, its line dissolving by 0.4; m6
          dissolves by 0.6; the new paper's brightness and the ghosts dissolve into the room's
          own paper (p 0.1..0.9).

Every number is a first guess for Richard's eye.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import base
from base import DEAD, FOAM, LEAF, WATER, h, vnoise

W, H = base.GRID

# ======================================================================== geometry
# Absolute source px on the 640x360 grid (base.Ctx: floor (84, 84, 336, 224)).
FX, FY = 84, 84
PAPER_Y0, PAPER_Y1 = 62, 83          # the wallpaper's rows (inclusive)
PAPER_L = (90, 234)                  # left half, inclusive
PAPER_R = (269, 413)                 # right half

# The room's paper, measured off the shell.
PAPER = (226, 199, 160)
STRIPE = (228, 210, 170)

# ======================================================================== ramps
# Stains on the paper: tea-brown, a tide-lined edge darker than the inside (water dries at its
# edge and leaves its dirt there).
ST1 = (197, 159, 109)        # a light stain
ST2 = (181, 140, 90)         # a soaked stain
TIDE = (146, 102, 60)        # the tide line round a stain
FAINT_IN = (213, 181, 136)   # a faint stain
FAINT_RIM = (194, 157, 108)
CORE = (138, 98, 60)         # the wet path down the middle of a strong streak
YELLOWED = (222, 192, 146)   # the dry side, old paper
YELLOWED_S = (226, 202, 158)
MILDEW = [(66, 72, 54), (104, 106, 80), (146, 140, 104)]
BACK = [(196, 170, 128), (220, 198, 160), (238, 222, 190)]   # the paper's pale back, dark to light
FRESH_PAPER = (238, 214, 177)
FRESH_STRIPE = (240, 226, 189)
GHOST = (219, 190, 148)
# The hut's wall boards, in the gloom behind the paper.
BOARD_BACK = [(46, 30, 26), (78, 50, 36), (104, 68, 46), (130, 88, 60)]

WET = (56, 28, 16)           # the wet halo is this laid over the boards
MUD = [(76, 66, 58), (104, 92, 80), (132, 118, 102)]   # ash-mud splash, dark to light
SHEEN = (150, 156, 160)      # a wet ring on mud

DRIP_FALL = 0.40             # seconds for a drop to fall its 32 px
DRIP_HIGH = 32               # px above the landing: the ceiling, on screen
SWELL = 0.25                 # two ticks: a dim speck, then the teardrop already moving
FLASH_UP = 6                 # p1's drop meets the window's lit band this far above the puddle
RING_LIFE = 1.0              # a ripple's life (the lake's is 1.15 over a far bigger ring)
RING_LIFE_SMALL = 0.6        # on a puddle under 14 px across
RING_FROM = 2.5              # the smallest ring's half-width: a 5x3 ellipse, never a box
SPLASH_LIFE = 0.32


def rel(x, y):
    return x + FX, y + FY


def seam_row(y):
    return (y - FY) % 4 == 0


def stripe_at(x):
    return (x - 90) % 15 in (1, 5, 12)


# ======================================================================== a pixel layer

class Px:
    """A straight-alpha RGBA layer on the source grid, painted a pixel at a time."""

    def __init__(self):
        self.a = np.zeros((H, W, 4), np.float32)

    def put(self, x, y, c, a=1.0):
        x, y = int(x), int(y)
        if not (0 <= x < W and 0 <= y < H) or a <= 0:
            return
        if a >= 1.0:
            self.a[y, x, 0], self.a[y, x, 1], self.a[y, x, 2] = c[0], c[1], c[2]
            self.a[y, x, 3] = 255.0
            return
        ua = self.a[y, x, 3] / 255.0
        oa = a + ua * (1 - a)
        for i in range(3):
            self.a[y, x, i] = (c[i] * a + self.a[y, x, i] * ua * (1 - a)) / oa
        self.a[y, x, 3] = oa * 255.0

    def img(self):
        return Image.fromarray(np.clip(self.a + 0.5, 0, 255).astype(np.uint8), "RGBA")


def _seen(stage, under):
    """What the room shows at each pixel so far: the bare room with `under` laid on it."""
    shell = np.asarray(base.shell_src(stage)).astype(np.float32)
    u = np.asarray(under).astype(np.float32)
    a = u[..., 3:] / 255.0
    return shell * (1 - a) + u[..., :3] * a


# p1 sits in the window's beam, which the room adds on top of everything (the capture's light).
# Added to blue water it greys it towards a silver smear; in the game the puddle will be drawn
# so the beam lifts it at most one ramp step. Here: inside P1_BOX, every opaque pixel of the
# layer is pre-darkened by most of the light that will land on it, so what shows is the
# painted colour plus BEAM_KEEP of the light. Pieces and walkers standing there are skipped.
P1_BOX = (80, 176, 126, 202)        # x0, y0, x1, y1 (exclusive), abs
BEAM_KEEP = 0.3
_LIGHT = {}


def _light(stage):
    if stage not in _LIGHT:
        full, top, alpha, shell, inside = base._layers(stage)
        _LIGHT[stage] = (top[1::base.S, 1::base.S] * 255.0, alpha[1::base.S, 1::base.S].min(axis=2),
                         alpha[1::base.S, 1::base.S])
    return _LIGHT[stage]


def veil_alpha(stage, rain=0.0, up=None):
    """life.py's veil over the room (HxW, 0..1), the one `over` lays on top of the frame:
    stage 1's dim, a step lighter in stage 2, none in 3; `up` = (frm, p) its play-in. Zeros
    when life.py is not there."""
    key = (stage, round(rain, 2), None if up is None else (up[0], int(math.floor(up[1] * 16 + 1e-9))))
    if key in _VEIL:
        return _VEIL[key]
    a = np.zeros((H, W), np.float32)
    try:
        import life                                 # noqa: WPS433 (read only)
        if up is not None:
            v = life.up_veil(up[0], key[2][1])
            if v is not None:
                a = np.asarray(v).astype(np.float32)[..., 3] / 255.0
        else:
            al = life.rainy(life.VEIL_ALPHA.get(stage), rain)
            if al:
                st = life.veil_steps(stage)
                for k, v in enumerate(al):
                    a[st == k] = v
    except Exception:
        pass
    _VEIL[key] = a
    return a


_VEIL = {}
VEIL_INK = (18, 20, 30)          # life.py's


def aimed(img, stage, veil=None):
    """img (PIL RGBA) whose colours are what must SHOW on the composed frame: each pixel is
    turned into the colour that lands there once the room's dim and its light are laid over it
    (composed = light + (1 - dim) * painted) and, given `veil` (veil_alpha()), life.py's veil
    over that. p1 is painted this way, so it is the lightest water in the room in the room's own
    terms. Pixels a piece or walker covers are left alone."""
    top, a, ac = _light(stage)
    arr = np.asarray(img).astype(np.float32).copy()
    on = (arr[..., 3] > 0) & (a < 0.6)
    want = arr[..., :3]
    ink = np.array(VEIL_INK, np.float32)
    va = np.zeros(want.shape[:2] + (1,), np.float32) if veil is None else np.minimum(veil, 0.9)[..., None]
    # The brightest the frame can show here (painted 255 under the dim, the light and the
    # veil): a colour past it is scaled down whole, keeping its hue, rather than clipped per
    # channel (a clipped blue goes grey).
    most = (255.0 * np.maximum(1 - ac, 0.3) + top) * (1 - va) + ink * va
    fit = np.min(most / np.maximum(want, 1.0), axis=2, keepdims=True)
    # ... but a near-white highlight (a glint) is clipped: the brightest the frame has there,
    # which in the window's light is the sun's own cream.
    white = np.min(want, axis=2, keepdims=True) > 200
    want = np.where(white, np.minimum(want, most), want * np.minimum(1.0, fit))
    want = (want - ink * va) / (1 - va)
    conv = (want - top) / np.maximum(1 - ac, 0.3)
    arr[..., :3] = np.where(on[..., None], np.clip(conv, 0, 255), arr[..., :3])
    return Image.fromarray((arr + 0.5).astype(np.uint8), "RGBA")


def shown(stage, seen, x, y):
    """What the composed frame shows at (x, y) over the colour `seen` there."""
    top, a, ac = _light(stage)
    return tuple(float(top[y, x, i] + (1 - ac[y, x, i]) * seen[y, x, i]) for i in range(3))


def unlight(img, stage, box=P1_BOX):
    """img (PIL RGBA, the source grid) with the beam's light taken back out inside `box`."""
    top, a, _ = _light(stage)
    x0, y0, x1, y1 = box
    arr = np.asarray(img).astype(np.float32).copy()
    sub = arr[y0:y1, x0:x1]
    keep = (sub[..., 3] >= 255) & (a[y0:y1, x0:x1] < 0.6)
    k = (1 - BEAM_KEEP) * top[y0:y1, x0:x1] / np.maximum(1 - a[y0:y1, x0:x1], 0.4)[..., None]
    sub[..., :3] = np.where(keep[..., None], np.clip(sub[..., :3] - k, 0, 255), sub[..., :3])
    arr[y0:y1, x0:x1] = sub
    return Image.fromarray((arr + 0.5).astype(np.uint8), "RGBA")


# ======================================================================== layout

def _features(ctx):
    return {f["id"]: f for f in ctx.layout.get("features", [])}


# ======================================================================== puddles

# How each puddle looks: (body, far edge, near lip, seams through, reflection, glint).
LOOKS = {
    # p1 in the window's beam: one step up on p3, never towards white. Painted through
    # unlight() so the beam's additive light does not grey it (see P1_BOX).
    "lit": dict(body=WATER[2], far=WATER[0], lip=WATER[3], seam=WATER[1], refl=WATER[3],
                glint=WATER[4], glints=2, dashes=1),
    "open": dict(body=WATER[2], far=WATER[1], lip=WATER[3], seam=WATER[1], refl=WATER[3],
                 glint=FOAM, glints=1, dashes=2),
    # p3 in the shade: dull, but a 3-px dash of light along its far edge and one foam pixel,
    # or it reads as a slick of oil beside p2
    "shade": dict(body=WATER[1], far=WATER[0], lip=WATER[2], seam=WATER[0], refl=WATER[3],
                  glint=FOAM, glints=1, dashes=1, dash_most=3),
}
# Puddle id -> (look, seed, where its drip lands relative to the centre, drip period s,
# the clock offset that puts something worth seeing in the stills at t = 0).
PUDDLES = {
    "p1": ("lit", 11, (0, 0), 2.6, 0.2),      # falling past the window at t = 0, no ring up
    "p2": ("open", 23, (8, 1), 3.3, -0.16),   # beside the boots: the fall clears the angler's figure
    "p3": ("shade", 37, (2, 0), 2.2, 0.75),   # a bead swelling at the ceiling
}
# The demo's half-mended room (tools/build_house_inside.py --half, 2026-10-15) boards h4 over:
# no flue drip falls into it.
NO_FLUE = False
FLUE = ((221, 101), 3.8, -0.28)               # h4's ash-mud left of the joist and the seedling (rel), period, offset
ASH = [(56, 50, 40), (70, 66, 58), (82, 78, 71)]   # the ash-mud's own steps (floor.py's h4)


def puddle_mask(cx, cy, w, hh, seed):
    """A shallow puddle on the planks: three overlapping lobes (the biggest a little to the low,
    right side), its edge nudged by a little noise, and the water wicking on along the seam
    grooves in 1-px fingers."""
    lobes = [
        (0.0, 0.0, 0.42, 0.52),
        (0.17 + 0.06 * h(seed, 1), 0.12, 0.33, 0.42),
        (-0.21 - 0.05 * h(seed, 2), -0.14 + 0.12 * h(seed, 3), 0.24, 0.40),
    ]
    pts = set()
    for y in range(int(cy - hh) - 2, int(cy + hh) + 3):
        for x in range(int(cx - w) - 2, int(cx + w) + 3):
            best = -9.0
            for ox, oy, rx, ry in lobes:
                dx = (x + 0.5 - (cx + ox * w)) / max(rx * w, 0.8)
                dy = (y + 0.5 - (cy + oy * hh)) / max(ry * hh, 0.9)
                best = max(best, 1.0 - (dx * dx + dy * dy))
            best += (vnoise(x, y, 4.0, seed) - 0.5) * 0.28
            if best > 0:
                pts.add((x, y))
    # Tidy: no lone pixels, no pinholes.
    for _ in range(2):
        drop = {p for p in pts if sum((p[0] + dx, p[1] + dy) in pts
                                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) < 2}
        pts -= drop
        if not pts:
            return pts
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        fill = set()
        for y in range(min(ys), max(ys) + 1):
            for x in range(min(xs), max(xs) + 1):
                if (x, y) not in pts and sum((x + dx, y + dy) in pts
                                             for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 3:
                    fill.add((x, y))
        pts |= fill
    # Fingers along the seams: a pixel to the left, two or three to the low right.
    for y in sorted({p[1] for p in pts}):
        if not seam_row(y):
            continue
        row = [x for x, yy in pts if yy == y]
        lo, hi = min(row), max(row)
        if h(lo, y, seed) < 0.6:
            pts.add((lo - 1, y))
        for k in range(1, 2 + int(h(hi, y, seed) * 2.5)):
            pts.add((hi + k, y))
    return pts


def small_mask(cx, cy, w, hh):
    """The last leak's little puddle (stage 2): a plain flat ellipse, no lobes, no fingers,
    no notch. w x hh px, rows centred on cx; 8 x 4 is rows of 6, 8, 8, 6."""
    pts = set()
    n = max(1, int(round(hh)))
    for j in range(n):
        dy = (j + 0.5 - n / 2.0) / (n / 2.0)
        wide = int(round(w * math.sqrt(max(0.0, 1 - dy * dy)) / 2.0)) * 2
        wide = max(2, min(int(round(w)), wide))
        x0 = int(math.floor(cx - wide / 2.0 + 0.5))
        for x in range(x0, x0 + wide):
            pts.add((x, int(math.floor(cy - n / 2.0 + 0.5)) + j))
    return pts


# p1, the window seat's puddle, drawn by hand inside its footprint (layout.json: 12 x 5 at
# rel (6, 100), abs x 90..101, y 184..188; stage 2 8 x 4, abs x 92..99, y 184..187): a lumpy
# lozenge, rounder on the window side, its low right side sagging a row, one pixel of wet wood
# between it and the left moulding (the boards start at abs 90). Lit by the sun off the
# window: see paint_p1.
P1_ROWS = {
    1: ["..#####.....",
        ".#########..",
        ".###########",
        "..#########.",
        ".....####..."],
    2: ["...######...",
        "..########..",
        "..########..",
        ".....####..."],
}
P1_LEFT = 90


def p1_mask(ctx, stage, rain=0.0, step=None):
    """p1's pixels at a stage (or, `step` 0..1 during the stage-up, part way from 1 to 2)."""
    f = _features(ctx).get("p1")
    cy = rel(*f["center"])[1]
    if step is not None and 0 < step < 1:
        rows = P1_ROWS[1]
        cut = int(round(step * 3))              # shaved off each row's ends, the right first
        rows = [r for r in rows if r.count("#") > 2 * cut] or rows[1:3]
    else:
        rows = P1_ROWS[2 if (stage == 2 or (step or 0) >= 1) else 1]
        cut = 0
    top = cy - len(rows) // 2
    pts = set()
    for j, row in enumerate(rows):
        xs = [i for i, ch in enumerate(row) if ch == "#"]
        if not xs:
            continue
        a, b = xs[0] + cut // 2, xs[-1] - (cut - cut // 2)
        for i in range(a, b + 1):
            pts.add((P1_LEFT + i, top + j))
    g = int(round(rain * 3))                    # a shower: it spreads to the right and down
    for _ in range(g):
        pts |= {(x + 1, y) for x, y in pts}
    if g:
        lo = max(y for _, y in pts)
        row = sorted(x for x, y in pts if y == lo)
        pts |= {(x, lo + 1) for x in row[len(row) // 3: -1]}
    return pts


P1_GLINT = (255, 255, 246)       # the sun's own glint on p1, white


def paint_p1(A, pts, look=1):
    """p1 as it must show (A is aimed afterwards). Stage 1 (look 1): water catching the
    window's light, every step lighter than the room's other puddles. The far edge (each
    column's top) WATER[2], the ends and body WATER[3], the near lip WATER[4] lit; across its
    widest inner row, from the window side, the window's reflection in WATER[4]; on the first
    inner row a glint, white then foam, nearest the window. Stage 2 (look 2, the last leak on
    the bright new boards): the same, a step deeper all through, or pale water on pale wood
    is not there at all."""
    far, body, refl, lip = (WATER[2], WATER[3], WATER[4], WATER[4]) if look == 1 else         (WATER[1], WATER[2], WATER[3], WATER[3])
    if not pts:
        return
    for (x, y) in pts:
        if (x, y - 1) not in pts:
            c = far                             # the far edge
        elif (x, y + 1) not in pts:
            c = lip                             # the lit near lip
        else:
            c = body                            # the ends and the body
        A.put(x, y, c)
    inner = lambda x, y: all(q in pts for q in ((x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y)))
    rows = {}
    for (x, y) in pts:
        if inner(x, y):
            rows.setdefault(y, []).append(x)
    if not rows:
        return
    # the window's reflection: the widest inner row, its window-side two thirds
    ry = max(rows, key=lambda y: (len(rows[y]), y))
    xs = sorted(rows[ry])
    for x in xs[:max(1, (len(xs) * 2 + 2) // 3)]:
        A.put(x, ry, refl)
    # the glint: the first inner row, a quarter in from the window side
    gy = min(rows)
    xs = sorted(rows[gy])
    gx = xs[len(xs) // 4]
    A.put(gx, gy, P1_GLINT)
    if len(xs) >= 4:
        A.put(gx + 1, gy, FOAM)


def paint_small(L, pts):
    """Body WATER[2], its far (top) row WATER[3], one foam glint on the first inner row."""
    if not pts:
        return
    top = min(y for _, y in pts)
    for (x, y) in pts:
        L.put(x, y, WATER[3] if (x, y - 1) not in pts else WATER[2])
    inner = sorted(p for p in pts if p[1] == top + 1 and (p[0] - 1, p[1]) in pts)
    if inner:
        L.put(inner[min(1, len(inner) - 1)][0], top + 1, FOAM)


def paint_puddle(L, pts, look, seed):
    """Water on the boards: a darker rim at the far edge and sides (the water's lip against the
    wood), a lit near edge, the body, the seams showing through it as short dashes, and the
    room's light lying on it as level dashes with one glint."""
    if look == "small":
        paint_small(L, pts)
        return
    lk = LOOKS[look]
    if not pts:
        return
    for (x, y) in pts:
        u = (x, y - 1) in pts
        d = (x, y + 1) in pts
        lf = (x - 1, y) in pts
        rt = (x + 1, y) in pts
        if not u and not d:
            c = lk["far"]                     # a finger in a seam
        elif not d:
            c = lk["lip"]
        elif not u or not lf or not rt:
            c = lk["far"]
        else:
            c = lk["body"]
            if seam_row(y) and (x - 2, y) in pts and (x + 2, y) in pts and h(x, y, seed) < 0.55:
                c = lk["seam"]
        L.put(x, y, c)
    # Reflections: on the first two inner rows, level dashes, the second shorter and nudged right.
    ys = sorted({y for _, y in pts})
    inner_rows = [y for y in ys if any((x, y - 1) in pts and (x, y + 1) in pts for x, yy in pts if yy == y)]
    first = None
    for k, y in enumerate(inner_rows[:lk["dashes"]]):
        xs = sorted(x for x, yy in pts if yy == y and (x, y - 1) in pts and (x, y + 1) in pts
                    and (x - 1, y) in pts and (x + 1, y) in pts)
        if len(xs) < 3:
            continue
        span = xs[-1] - xs[0]
        a = xs[0] + int(span * (0.18 + 0.16 * k))
        n = min(max(1, int(span * (0.34 - 0.12 * k))), lk.get("dash_most", 99))
        for x in range(a, a + n):
            if (x, y) in pts:
                L.put(x, y, lk["refl"])
        if first is None:
            first = (a, y)
    if lk["glint"] and first:
        L.put(first[0], first[1], lk["glint"])
        if lk["glints"] > 1:
            L.put(first[0] + 1, first[1], lk["glint"])


def wet_halo(L, pts, seed, strength=1.0):
    """The boards round a puddle a step darker; further along the seams and on the low side."""
    if not pts or strength <= 0:
        return
    near, far = set(), set()
    for (x, y) in pts:
        for dy in range(-2, 3):
            for dx in range(-3, 5):
                q = (x + dx, y + dy)
                if q in pts:
                    continue
                cheb = max(abs(dx), abs(dy))
                if cheb <= 1:
                    near.add(q)
                else:
                    reach = 2 if dx < 0 else 4         # the low side is the right
                    if abs(dy) <= 1 and abs(dx) <= reach and h(q[0], q[1], seed) < 0.55:
                        far.add(q)
                    elif seam_row(q[1]) and dy == 0 and dx <= reach:
                        far.add(q)
    far -= near
    for q in near:
        L.put(q[0], q[1], WET, 0.30 * strength)
    for q in far:
        L.put(q[0], q[1], WET, 0.15 * strength)


def _ring_px(cx, cy, rx):
    """A 2:1 ring, 1 px thick, as whole pixels: never a box. The four corner pixels of its
    bounding box are left out, so even the smallest (half-width 2.5) is a 5x3 ellipse."""
    ry = rx * 0.5
    rnd = lambda v: int(math.floor(v + 0.49))      # halves round down: 2.5 is 5 wide
    R, Ry = rnd(rx), max(1, rnd(ry))
    pts = set()
    for i in range(0, R + 1):                       # walk across: the top and bottom arcs
        y = rnd(ry * math.sqrt(max(0.0, 1 - (i / (R + 0.0)) ** 2)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts.add((cx + sx * i, cy + sy * y))
    for j in range(0, Ry + 1):                      # walk down: the steep ends
        x = rnd(rx * math.sqrt(max(0.0, 1 - (j / (Ry + 0.0)) ** 2)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts.add((cx + sx * x, cy + sy * j))
    pts.discard((cx, cy))
    if pts:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for c in ((min(xs), min(ys)), (min(xs), max(ys)), (max(xs), min(ys)), (max(xs), max(ys))):
            pts.discard(c)
    return pts


def ripple(L, pts, at, age, seed, colour=FOAM, most=6.0, clip=True, life=RING_LIFE):
    """The lake's ripple, small: a 2:1 ring of foam opening fast and coasting, one pixel thick,
    torn into dashes that dissolve (whole, remnant, nothing) as it goes. Stepped at 8 fps."""
    a = math.floor(age * 8) / 8.0
    if a < 0 or a >= life:
        return
    t = a / life
    out = 1 - (1 - t) * (1 - t)
    rx = RING_FROM + (most - RING_FROM) * out
    cx, cy = at
    for (x, y) in sorted(_ring_px(cx, cy, rx)):
        if clip and (x, y) not in pts:
            continue
        roll = h(x, y, seed)
        keep = 0.15 + t * 0.8            # cells rolled under this are gone
        if roll < keep - 0.25:
            continue
        L.put(x, y, colour, 0.85 if roll >= keep else 0.4)


# ======================================================================== the drips

DRIP_RING_TICKS = 4           # a drip's ring: x-radius 2, 3, 4, 5 over four 8-fps ticks


def drip_ring(L, pts, at, age, seed, colour=FOAM, clip=True):
    """A drip's ring: a 2:1 ellipse of foam dashes (2 on, 1 off round it, so its top and
    bottom arcs curve), its half-width 3 -> 4 -> 5 -> 6 over four ticks, faded on the last,
    clipped to the water."""
    tick = int(math.floor(age * 8))
    if tick < 0 or tick >= DRIP_RING_TICKS:
        return
    cx, cy = at
    ring = sorted(_ring_px(cx, cy, 3.0 + tick),
                  key=lambda q: math.atan2((q[1] - cy) * 2.0, q[0] - cx))
    par = int(h(seed, 3, 97) * 2)
    alpha = 0.95 if tick < DRIP_RING_TICKS - 1 else 0.45
    for i, (x, y) in enumerate(ring):
        if (i + par) % 3 == 2:                      # torn: 2 on, 1 off, so the arcs still curve
            continue
        if clip and (x, y) not in pts:
            continue
        L.put(x, y, colour, alpha)

def _land_times(offset, period, seed, t):
    """The drops whose life (swell, fall, ring) covers t: [(k, land time)]."""
    out = []
    k0 = math.floor((t - offset) / period)
    for k in range(k0 - 1, k0 + 3):
        jit = 0.0 if k == 0 else (h(k, 5, seed) - 0.5) * 0.45 * period
        land = offset + k * period + jit
        if land - DRIP_FALL - SWELL <= t <= land + RING_LIFE:
            out.append((k, land))
    return out


def drop_streak(O, x, y_top, y_land, s, colour_head, colour_tail, lit_from=None):
    """A falling drop at fall progress s (0..1): 1 x 2 px, a foam pixel on top over a WATER[4]
    one, and a 1-px WATER[2] trail behind it at alpha 140 while it falls. Below `lit_from`
    (the window's light) it burns white-gold."""
    y = y_top + (y_land - y_top) * s * s
    yi = int(round(y))
    top, low, trail = FOAM, WATER[4], WATER[2]
    if lit_from is not None and yi >= lit_from:
        top, low, trail = (255, 252, 236), (255, 240, 200), (255, 226, 170)
    if yi - y_top >= 2:                         # a trail only once it has fallen a little
        O.put(x, yi - 2, trail, 140 / 255.0)
    O.put(x, yi - 1, top)
    O.put(x, yi, low)


def bead(O, x, y, age):
    """The drop letting go of the ceiling: two ticks, a dim speck where the falling drop's top
    pixel will be, then the 2-px teardrop growing down from it, exactly where the fall's first
    tick draws it. It only ever grows and moves down: never a pixel above the speck. No
    hanging bead: there is no ceiling to hang from on screen, and a still speck reads as a
    fleck of paint."""
    a = math.floor(age * 8) / 8.0
    if a < 0 or a >= SWELL:
        return
    if a < 0.125:
        O.put(x, y - 1, WATER[3])               # the speck: the drop's top pixel to be
    else:                                       # the drop as it falls at s = 0
        O.put(x, y - 1, FOAM)
        O.put(x, y, WATER[4])


def splash(O, at, age, seed, light, dark, n=4, crown=None):
    """The landing: a crown at once (one pixel above the landing for a drip on water, five
    for the flue's mud), then a few droplets thrown up and out on little arcs, back down
    within a third of a second. Whole pixels."""
    if age < 0 or age >= SPLASH_LIFE:
        return
    x0, y0 = at
    if age < 1 / 8.0 and crown == "pixel":
        O.put(x0, y0 - 2, light)
    elif age < 1 / 12:
        O.put(x0, y0 - 1, light)
        O.put(x0 - 1, y0, light, 0.85)
        O.put(x0 + 1, y0, light, 0.85)
        O.put(x0 - 2, y0, dark, 0.5)
        O.put(x0 + 2, y0, dark, 0.5)
    for i in range(n):
        side = -1 if i % 2 == 0 else 1
        vx = side * (8 + 22 * h(i, 1, seed))
        vy = -(26 + 26 * h(i, 2, seed))
        tt = age
        x = x0 + vx * tt
        y = y0 + vy * tt + 0.5 * 360 * tt * tt
        if y > y0 + 0.5 and tt > 0.08:
            continue
        O.put(int(round(x)), int(round(y)), light if i < 2 else dark, 0.95 if i < 2 else 0.7)


# ======================================================================== the wall

# A water stain is the paper's own colour stepped down, never a lighter fill: LEVELS 1..6, one
# step each. Stage 2 draws the same shapes one level fainter.
LEVELS = {1: (212, 181, 137), 2: ST1, 3: ST2, 4: TIDE, 5: (118, 82, 48), 6: (98, 64, 36)}
# Blooms: where the roof let water in at the top moulding it soaked out into the paper and
# dried, leaving its dirt in a tide line round the edge. Widest under the moulding, the lower
# edge scalloped by two side lobes and a little noise, never a mirror of itself:
# (middle x, half-width, depth in rows, kind, seed). "wet" still runs: a soaked band under the
# moulding, a body two steps down, a dark rim, a receded line inside it, streaks. "old" dried
# long ago: a body one step down, a darker broken rim, a receded line. "faint": body and rim
# one step each.
BLOOMS = [
    (300, 7.5, 7.0, "old", 70),
    (327, 6.5, 9.0, "wet", 3),
    (345, 5.0, 6.0, "old", 71),
    (358, 3.5, 4.0, "faint", 5),
    (385, 6.5, 10.0, "wet", 4),        # the corner, the worst: mostly under the flap
]
BLOOM_LOOK = {   # body, soak band, rim, receded line, streak, streak tip
    "wet": (2, 3, 4, 3, 3, 5),
    "old": (1, 2, 3, 2, 2, 3),
    "faint": (1, 1, 2, 0, 1, 2),
}
# Streaks run on down off a bloom's lower edge, narrowing from two pixels to one and wandering
# a pixel now and then the way they lean: (bloom, x off its middle, rows below its edge (None:
# on down to 3 rows above the foot band), lean -1 / +1, seed). The long ones still run (the
# beads in wall_beads slide down them).
STREAKS = [
    (1, -2, None, -1, 81),
    (1, 3, 4, 1, 82),
    (0, 3, 3, 1, 83),
    (3, -1, 4, -1, 84),
    (4, 2, None, 1, 85),
]
# Mould under the torn corner: irregular clusters of 2-5 px in the hut's moss, no two alike,
# densest under the tear and thinning out to the left and down: (x, y, pixels).
MOULD_AT = [(409, 73, 5), (405, 74, 4), (412, 75, 3), (407, 77, 5), (402, 76, 3),
            (410, 79, 4), (399, 75, 2), (404, 80, 3), (395, 78, 2), (400, 82, 2)]

# The paper hanging off the wall. Each map is laid from its top-left corner (abs).
#   b bare boards   f torn fibres   c the fold, lit   1 2 3 the paper's back, light to shade
#   4 the curl's rolled underside   s shadow on the paper   g a gap   l a lifted edge, lit
PEEL_CORNER = ((402, 62), [        # the top corner torn away, the tear's foot lifting off
    "..ffbbbbbbbb",
    "...fbbbbbbbb",
    "....fbbbbbbb",
    "....ffbbbbbb",
    ".....fbbbbbb",
    "......ffbbbb",
    ".......l1bbb",
    "........l2bb",
    ".........sub",
    "..........ss",
])
PEELS = [PEEL_CORNER]
# The paper hanging off the wall is the wallpaper's own ramp two steps darker (its back, in the
# shade of its own fold): FLAP the body, FLAP_SIDE a step further on its sides, a 1-px lit edge
# in the paper's light (the stripe, lifted) along the outer fold, and ink only on the underside
# that faces the gap behind it. The torn corner's lifted foot wears the same.
FLAP = (196, 168, 128)
FLAP_SIDE = (176, 146, 106)
FLAP_LIT = (240, 222, 184)
LIFTED = FLAP
LIFTED_LIT = FLAP_LIT
PEEL_COLOURS = {
    "f": (244, 234, 210), "c": FLAP_LIT, "1": FLAP, "2": FLAP, "k": FLAP,
    "3": FLAP_SIDE, "e": FLAP_SIDE, "4": FLAP_SIDE, "u": base.INK, "g": (92, 64, 46),
    "l": FLAP_LIT,
}
# Butt joints in the lap boards where the paper has gone (a board ends every so often).
BOARD_JOINTS = (381, 387, 406, 411)
# The flap: the strip 378..390's top came unglued where the 386 water ran, and hangs folded
# down off a hinge that slopes (the wet right side let go further): (left x, right x, hinge
# row at the left, at the right, how far the flap hangs).
FLAP_AT = (378, 390, 66, 70, 4)


def _flap_roles():
    """The flap: bare boards above the hinge, the lit fold on it, the paper's back hanging
    below, its free edge (sides and foot) outlined, one hard shadow row under it and down its
    right side where it stands off the wall."""
    x0, x1, y0, y1, n = FLAP_AT
    roles = {}
    for x in range(x0, x1 + 1):
        f = (x - x0) / (x1 - x0)
        yh = int(round(y0 + (y1 - y0) * f))
        side = x in (x0, x1)
        for y in range(PAPER_Y0, yh):
            roles[(x, y)] = "b"
        roles[(x, yh)] = "c" if not side else "e"
        for k in range(1, n + 1):
            roles[(x, yh + k)] = "u" if k == n else ("e" if side else "k")
        roles[(x, yh + n + 1)] = "s"
        if x == x1:                       # the flap stands off the wall: shadow to its right
            for k in range(1, n + 2):
                roles.setdefault((x + 1, yh + k), "s")
    # where the hinge meets the neighbouring strips, the paper tore a little
    roles[(x0 - 1, y0 - 1)] = "f"
    roles[(x1 + 1, y1 - 2)] = "f"
    return roles


def wall_beads(L, t, rain):
    """Water still running down the wet blooms' long streaks: now and then a bead of it slides
    out of the soaked band and down the streak, a pixel a tick, and is gone a row short of its
    end. Twice as often in a shower."""
    tick = int(math.floor(t * 8))
    roles = _peel_roles()
    for i, path in enumerate(_bead_paths()):
        period = int(round((30 + 8 * i) / (1.0 + rain)))
        ph = (tick + i * 11) % period
        if ph >= len(path) - 1:
            continue
        x, y = path[ph]
        if (x, y) in roles:
            continue
        L.put(x, y, (236, 230, 214))
        if ph > 0 and path[ph - 1] not in roles:
            L.put(path[ph - 1][0], path[ph - 1][1], ST2)


def _tide_top():
    out = {}
    for x in range(298, PAPER_R[1] + 1):
        f = (x - 298) / (PAPER_R[1] - 298)
        hgt = 1.5 + 7.0 * f ** 1.25 + (vnoise(x, 0, 4.0, 41) - 0.5) * 2.2
        out[x] = int(round(PAPER_Y1 - hgt))
    return out


def _scallops(i):
    """A bloom's scallops: (x, y, radius) circles hung from just above the moulding, three to
    five across its width, the middle ones biggest, every one rolled its own size and place, so
    the lower edge is a run of uneven arcs (the outline a drying stain leaves), never a bowl."""
    bx, w, depth, kind, seed = BLOOMS[i]
    n = 3 + int(h(seed, 9) * 2.99)
    out = []
    for k in range(n):
        f = (k + 0.5) / n * 2 - 1                         # -1 .. 1 across the bloom
        x = bx + f * w * 0.8 + (h(seed, 20 + k) - 0.5) * 2.4
        r = depth * (0.55 + 0.45 * (1 - f * f)) * (0.7 + 0.45 * h(seed, 40 + k))
        out.append((x, PAPER_Y0 - 0.35 * r, r))
    return out


def _bloom_map():
    """({x: the last stained row}, {x: which bloom}) along the top of the right half (cached):
    the union of every bloom's scallops; where two blooms meet the deeper one owns the column."""
    if "bm" in _ROLES:
        return _ROLES["bm"]
    edge, owner = {}, {}
    for x in range(PAPER_R[0], PAPER_R[1] + 1):
        best, who = -1.0, None
        for i in range(len(BLOOMS)):
            for cx, cy, r in _scallops(i):
                dx = x + 0.5 - cx
                if abs(dx) < r:
                    low = cy + math.sqrt(r * r - dx * dx)
                    if low > best:
                        best, who = low, i
        if who is not None and best >= PAPER_Y0 + 0.5:
            edge[x] = int(math.floor(best))
            owner[x] = who
    _ROLES["bm"] = (edge, owner)
    return edge, owner


def _streak_path(x, y0, n, lean, seed):
    """[(x, y)] one per row, the pixel the streak is on; it shifts a pixel the way it leans at
    most twice, never on its first two rows."""
    out, shifts = [], 0
    for k in range(n):
        if k >= 2 and shifts < 2 and h(x, y0 + k, seed) < 0.22:
            out.append((x, y0 + k))                    # the step: both pixels on that row
            x += lean
            shifts += 1
        out.append((x, y0 + k))
    return out


def _streaks():
    """[(path, kind, n)] every streak's pixels (cached)."""
    if "st" in _ROLES:
        return _ROLES["st"]
    tide = _tide_top()
    out = []
    for bi, off, n, lean, seed in STREAKS:
        bx, w, depth, kind, bseed = BLOOMS[bi]
        edge = _bloom_map()[0]
        x = bx + off
        y0 = edge.get(x, PAPER_Y0 + depth - 1) + 1
        if n is None:
            n = tide.get(x, PAPER_Y1) - 4 - y0 + 1
        out.append((_streak_path(x, y0, max(1, n), lean, seed), kind, n))
    _ROLES["st"] = out
    return out


def _bead_paths():
    """The running streaks' paths for wall_beads: down the bloom from the moulding, on down the
    streak (one pixel a row, the later of a step's two)."""
    if "bp" in _ROLES:
        return _ROLES["bp"]
    out = []
    for (path, kind, n), (bi, off, nn, lean, seed) in zip(_streaks(), STREAKS):
        if kind != "wet" or nn is not None:
            continue
        x0, y0 = path[0]
        rows = {}
        for p in path:
            rows[p[1]] = p                              # the later pixel of a step wins
        out.append([(x0, y) for y in range(PAPER_Y0, y0)] + [rows[y] for y in sorted(rows)])
    _ROLES["bp"] = out
    return out


def _wall_levels():
    """{pixel: level 1..6} for the stained right half of the paper (cached)."""
    if "lv" in _ROLES:
        return _ROLES["lv"]
    lv = {}

    def setl(x, y, l):
        if PAPER_R[0] <= x <= PAPER_R[1] and PAPER_Y0 <= y <= PAPER_Y1 and l > 0:
            lv[(x, y)] = max(lv.get((x, y), 0), l)

    tide = _tide_top()
    # the foot band: a darker band rising to the corner, its top row the tide line
    for x, top in tide.items():
        for y in range(top, PAPER_Y1 + 1):
            k = y - top
            setl(x, y, 4 if k == 0 else 3 if k == 1 else 2)
    # an older tide line, higher, broken, along the wettest stretch
    for x in range(332, 402):
        if vnoise(x, 9, 3.0, 44) > 0.3:
            setl(x, tide[x] - 3, 2)
    # the blooms
    edge, owner = _bloom_map()
    inside = {(x, y) for x, last in edge.items() for y in range(PAPER_Y0, last + 1)}
    for (x, y) in inside:
        bx, w, depth, kind, seed = BLOOMS[owner[x]]
        body, soak, rim, inner, _, _ = BLOOM_LOOK[kind]
        below = (x, y + 1) not in inside
        beside = (x - 1, y) not in inside or (x + 1, y) not in inside
        k = edge[x] - y                                  # rows above the lower edge
        if below or (beside and y > PAPER_Y0 + 1):
            l = rim                                      # the tide line: dirt left at the edge
            if h(x, y, seed + 7) < (0.3 if kind == "old" else 0.12):
                l = rim - 1                              # the rim, broken
            if kind == "faint" and not below:
                l = body
        elif k == 1 or (beside and y <= PAPER_Y0 + 1):
            l = body + 1 if kind == "wet" else body      # the band inside the rim
        else:
            l = body
            band = 1 + int(vnoise(x, 1, 3.0, seed) * 2.6)
            if kind != "faint" and y - PAPER_Y0 < band:
                l = soak                                 # soaked where it came in
            # the line it dried back to once, a row or two inside the rim, broken
            if (inner and k == 2 + (1 if vnoise(x, 2, 4.0, seed) > 0.55 else 0)
                    and (x - 1, y) in inside and (x + 1, y) in inside and h(x, 4, seed) > 0.18):
                l = inner
        setl(x, y, l)
    # the streaks: two pixels wide where they leave the edge, one below, a darker tip
    for path, kind, n in _streaks():
        _, _, _, _, st, tip = BLOOM_LOOK[kind]
        last = path[-1]
        for i, (x, y) in enumerate(path):
            setl(x, y, tip if (x, y) == last else st)
        x0, y0 = path[0]
        lean = 1 if path[-1][0] >= x0 else -1
        setl(x0 - lean, y0, max(1, st - 1))           # the shoulder where it leaves the edge
    _ROLES["lv"] = lv
    return lv


def _board_back(x, y, wet=False):
    """The hut's wall boards in the gloom where the paper has gone: lap boards 5 rows tall,
    the top row darkest under the moulding's lip."""
    r = (y - PAPER_Y0) % 5
    if y == PAPER_Y0 or r == 0:
        return BOARD_BACK[0]
    if r == 1:
        c = BOARD_BACK[3] if not wet else BOARD_BACK[2]
    else:
        c = BOARD_BACK[2] if not wet else BOARD_BACK[1]
    if h(x, y, 61) < 0.1:
        c = BOARD_BACK[1]
    if x in BOARD_JOINTS and r > 0:
        c = BOARD_BACK[0]          # a butt joint: one board ends, the next begins
    elif wet and r == 1 and h(x, y, 8) < 0.3:
        c = BOARD_BACK[3]          # the wet top edge catching the light, warm
    return c


_ROLES = {}


def _peel_roles():
    if "r" in _ROLES:
        return _ROLES["r"]
    roles = _flap_roles()
    for (ax, ay), rows in PEELS:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != ".":
                    roles[(ax + i, ay + j)] = ch
    _ROLES["r"] = roles
    return roles


def _level_colour(x, l):
    c = LEVELS[l]
    if stripe_at(x) and l <= 3:
        c = tuple(min(255, v + 5) for v in c)
    return c


def paint_wall_s1(L):
    lv = _wall_levels()
    roles = _peel_roles()
    x0, x1 = PAPER_R
    for y in range(PAPER_Y0, PAPER_Y1 + 1):
        for x in range(x0, x1 + 1):
            r = roles.get((x, y))
            l = lv.get((x, y), 0)
            if r == "b":
                L.put(x, y, _board_back(x, y, wet=abs(x - 386) <= 3))
            elif r == "s":
                base_c = _level_colour(x, l) if l else (STRIPE if stripe_at(x) else PAPER)
                L.put(x, y, tuple(int(v * 0.72) for v in base_c))      # one hard shadow step
            elif r:
                L.put(x, y, PEEL_COLOURS[r])
            elif l:
                L.put(x, y, _level_colour(x, l))
    for p, c in _mould().items():
        if p in roles or not (PAPER_Y0 <= p[1] <= PAPER_Y1):
            continue
        L.put(p[0], p[1], c)


def _mould():
    """{pixel: colour}: each cluster a little random walk of n pixels from its seed pixel, the
    first ones MOSS[0], the rest MOSS[1]; a walk that comes out the same shape as an earlier
    one is walked again, so no two clusters match."""
    out, shapes = {}, set()
    for i, (mx, my, n) in enumerate(MOULD_AT):
        cells = [(0, 0)]
        for attempt in range(12):
            cells, x, y = [(0, 0)], 0, 0
            k = 0
            while len(cells) < n and k < 40:
                d = int(h(i * 31 + attempt, k, 93) * 6)
                dx, dy = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1))[d]
                x, y = (x + dx, y + dy) if h(i, k + attempt, 94) < 0.7 else cells[0]
                if (x, y) not in cells:
                    cells.append((x, y))
                k += 1
            shape = tuple(sorted(cells))
            if shape not in shapes:
                break
        shapes.add(tuple(sorted(cells)))
        for j, (dx, dy) in enumerate(cells):
            out[(mx + dx, my + dy)] = base.MOSS[0] if j < max(1, n // 2) else base.MOSS[1]
    return out


def paint_wall_yellow(L):
    """The dry side: the paper yellowed in broad soft patches along its top. One step."""
    for x in range(PAPER_L[0], PAPER_L[1] + 1):
        if vnoise(x, 1, 26.0, 52) < 0.42:
            continue
        depth = 2 + int(round(4 * vnoise(x, 0, 9.0, 51) + math.sin(x / 3.1) * 0.6))
        for y in range(PAPER_Y0, PAPER_Y0 + depth):
            L.put(x, y, YELLOWED_S if stripe_at(x) else YELLOWED)


def paint_wall_s2(L):
    """Two strips re-papered over the worst (360..413), a hair fresher; the rest keeps the same
    stains one step fainter (the faintest gone)."""
    for y in range(PAPER_Y0, PAPER_Y1 + 1):
        for x in range(360, PAPER_R[1] + 1):
            c = FRESH_STRIPE if stripe_at(x) else FRESH_PAPER
            if x in (360, 390):
                c = (221, 195, 156)        # the new strips' joins
            L.put(x, y, c)
    for (x, y), l in _wall_levels().items():
        if x < 360 and l >= 2:
            L.put(x, y, _level_colour(x, l - 1))


# ======================================================================== cobwebs

def bres(x0, y0, x1, y1):
    """The pixels of a 1-px line, whole pixels only."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


WEB_ON_PAPER = (132, 122, 108)      # the thread's dark: on the pale paper it is a shade
WEB_ON_DARK = (214, 208, 196)       # the thread's light: on dark wood a catch of light
WEB_STEP = 0.4                      # a thread is this one fixed step from what is under it


# A corner web, drawn by hand off the corner (dx right, dy down; a top-right one is mirrored).
# Nothing lies along the walls (two threads hugging them read as a bracket, a frame drawn round
# the corner): two spokes out of the corner at 30 and 60 degrees, the hub left open; two taut
# threads strung from wall to wall across them, the inner one straight, the outer one bending
# where it crosses each spoke, broken short of the left wall with its end hanging. Gaps of 2 px
# and more everywhere but where threads cross, so it reads as a web and not a smudge.
WEB_MAP = (
    [(4, 2), (5, 3), (6, 3), (7, 4), (8, 5), (9, 5), (10, 6), (11, 6), (12, 7)]          # 30 deg
    + [(2, 4), (3, 5), (3, 6), (4, 7), (5, 8), (5, 9), (6, 10), (6, 11), (7, 12)]        # 60 deg
    + [(7, 1), (6, 2), (5, 3), (4, 4), (3, 5), (2, 6), (1, 7)]                          # inner
    + [(14, 1), (13, 2), (12, 3), (12, 4), (11, 5), (10, 6), (9, 7), (8, 8), (7, 9),
       (6, 10), (5, 11)]                                                                 # outer
    + [(5, 12), (5, 13)]                                                                 # its end
)


def web_pixels(at, flip=False):
    """The pixels of WEB_MAP hung off corner `at` (mirrored for a right-hand corner)."""
    ax, ay = at
    return {(ax - dx if flip else ax + dx, ay + dy) for dx, dy in WEB_MAP}


def web(L, seen, at, flip=False, avoid=None):
    """Lay a web one fixed step off what is under each thread: darker on the paper, lighter on
    dark wood. `avoid(x, y)` drops a thread pixel (water)."""
    pix = web_pixels(at, flip)
    out = set()
    for (x, y) in pix:
        if not (0 <= x < W and 0 <= y < H):
            continue
        if avoid and avoid(seen, x, y):
            continue
        under = tuple(float(v) for v in seen[y, x])
        lum = 0.3 * under[0] + 0.59 * under[1] + 0.11 * under[2]
        to = WEB_ON_PAPER if lum > 120 else WEB_ON_DARK
        L.put(x, y, base.mix(under, to, WEB_STEP))
        out.add((x, y))
    return out


def _is_water(seen, x, y):
    r, g, b = seen[y, x]
    return b > r + 12


WEBS = [
    # (corner, mirrored?, clip off water?)
    ((90, 62), False, False),          # paper, top left
    ((413, 62), True, False),          # over the torn corner, top right
]


def paint_webs(L, seen):
    return [web(L, seen, at, flip, _is_water if clip else None) for at, flip, clip in WEBS]


SPIDER_AT = (98, 70)        # on the top-left web's outer thread
SPIDER_CYCLE = 9.0
SPIDER = (36, 28, 26)


def spider(L, t):
    """The top-left web's spider: sits on its spoke most of the time, then lets itself down a
    few pixels on a thread, hangs there with its legs flicking, and climbs back. Stepped on
    the 8 fps clock, every pixel whole."""
    tick = math.floor(t * 8) / 8.0
    ph = (tick + 2.0) % SPIDER_CYCLE
    x, y0 = SPIDER_AT
    drop = 0
    if 5.0 <= ph < 6.25:
        drop = int((ph - 5.0) / 1.25 * 7)
    elif 6.25 <= ph < 8.0:
        drop = 7 + (1 if int(ph * 4) % 3 == 0 else 0)
    elif 8.0 <= ph < 9.0:
        drop = 7 - int((ph - 8.0) * 7)
    y = y0 + drop
    for k in range(1, drop + 1):                      # its thread
        L.put(x, y0 + k - 1, base.mix(PAPER, WEB_ON_PAPER, WEB_STEP))
    L.put(x, y, SPIDER)
    L.put(x, y + 1, SPIDER)
    flick = 1 if drop and int(tick * 8) % 6 < 2 else 0
    for dx, dy in ((-1, 0 + flick), (1, 0 + flick), (-1, 2), (1, 2)):
        L.put(x + dx, y + dy, SPIDER)


GLINT_EVERY = 12              # ticks between a puddle's twinkles


def twinkles(L, t, pud, A=None):
    """Between drips, now and then the light catches a wavelet: one pixel of a puddle flicks
    white for a tick, a remnant the next."""
    k = int(math.floor(t * 8))
    for i, (pid, (pts, c)) in enumerate(sorted(pud.items())):
        if not pts:
            continue
        off = int(h(i, 0, 707) * GLINT_EVERY)
        ph = (k + off) % GLINT_EVERY
        if ph > 1:
            continue
        inner = _inner(pid, pts)
        if not inner:
            continue
        n = (k + off) // GLINT_EVERY
        x, y = inner[int(h(n, i, 708) * len(inner)) % len(inner)]
        if pid == "p1":                 # painted as it must show (A is aimed)
            (A or L).put(x, y, FOAM if ph == 0 else WATER[4])
        else:
            L.put(x, y, (255, 255, 246) if ph == 0 else FOAM, 1.0 if ph == 0 else 0.5)


_INNER = {}


def _inner(pid, pts):
    key = (pid, len(pts), min(pts))
    if key not in _INNER:
        _INNER[key] = sorted(p for p in pts if all((p[0] + dx, p[1] + dy) in pts
                                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0))))
    return _INNER[key]


# ======================================================================== mushrooms

# Mushroom caps (dark, mid, light, highlight), lit from the window's side (upper left) like the
# hut's own plants: no ink ring, the cap's darkest step is its contour on the shade side.
CAP_PALE = [(150, 136, 114), (204, 192, 168), (232, 224, 206), (250, 246, 236)]
CAP_BROWN = [(70, 42, 30), (112, 70, 44), (156, 104, 64), (204, 156, 102)]
CAP_PIN = [base.DEAD[2], base.DEAD[3], base.WHITE[1], base.WHITE[2]]   # pale pins
CAP_INK = [(84, 78, 72), (150, 140, 126), (198, 190, 174), (232, 226, 214)]   # ink caps, grey bells
STEM = [(178, 166, 146), (234, 228, 214)]
# Pale caps that read as caps, not pegs: cream, ringed in the hut's DEAD brown, a darker gill
# row under them and a paler stem below that. (D M L H, rim)
CAP_CREAM = [(196, 176, 140), (196, 176, 140), (226, 212, 184), (246, 238, 218), DEAD[1]]
GILL_PALE = (128, 102, 72)
GILL = (92, 70, 54)
BRACKET = [(84, 56, 38), (150, 106, 62), (196, 150, 92), (228, 192, 130), (244, 226, 184)]

# Sprites, bottom row on the ground. H L M D the cap highlight..dark, u the gills' shadow,
# S s the stem lit and shaded.
CAP_SPRITES = {
    "tall": [
        ".LHM.",
        "LHLMD",
        "DMMDD",
        ".uSs.",
        "..Ss.",
        "..Ss.",
    ],
    "small": [
        ".HM.",
        "LLMD",
        "DMDD",
        ".Ss.",
    ],
    "button": [
        "HM",
        "MD",
    ],
    "ptall": [           # a pale cap, 5 wide: rim, cream top, gill row, stem
        ".rrr.",
        "rHHLr",
        "rLLMr",
        ".ggg.",
        "..Ss.",
        "..Ss.",
    ],
    "psmall": [
        ".rr.",
        "rHLr",
        ".gg.",
        ".Ss.",
    ],
    "pin3": [            # a pale pin: a cap, its lower edge inked, on a 1-px stem
        ".HL.",
        "HLLM",
        "kuuk",
        ".S..",
        ".S..",
        ".s..",
    ],
    "pin2": [
        ".HL",
        "HLM",
        "kuk",
        ".S.",
        ".s.",
    ],
    "pin1": [
        "HL",
        "kk",
        "S.",
    ],
    "bell": [            # an ink cap: a tall grey bell on a thread of a stem
        ".L.",
        "LHM",
        "LMD",
        "DMD",
        ".S.",
        ".s.",
    ],
}


def mushroom(L, x, y, kind, cap, flip=False):
    """A mushroom standing on (x, y), its sprite centred on x, a pixel of damp shade at its foot."""
    rows = CAP_SPRITES[kind]
    hgt = len(rows)
    wid = len(rows[0])
    for k in (-1, 0, 1):
        L.put(x + k, y + 1, WET, 0.28 if k else 0.4)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            ii = (wid - 1 - i) if flip else i
            px, py = x - wid // 2 + ii, y - hgt + 1 + j
            c = {"H": cap[3], "L": cap[2], "M": cap[1], "D": cap[0],
                 "r": cap[4] if len(cap) > 4 else cap[0], "g": GILL_PALE,
                 "u": GILL, "S": STEM[1], "s": STEM[0], "k": base.INK}[ch]
            L.put(px, py, c)


# Bracket fungus: two stepped shelves out of the right wall's inner edge, right-aligned on it.
# P the lit growing rim, L M the banded top (rings round where it meets the wall), u the
# underside (DEAD[0]), the upper shelf 6 wide, the lower 4.
BRACKET_SHELVES = [
    ["...PLM",
     "..PLML",
     ".PLMLM",
     "PPPPPP",
     ".uuuuu"],
    ["..PL",
     ".PLM",
     "PPPP",
     ".uuu"],
]


def bracket(L, x, y):
    """Two shelves stepped down the wall's foot (x is the last board pixel against the
    moulding): the upper 6 wide, the lower 4 wide a row below its underside. Each a banded top,
    a lit rim along its front, one dark underside row and a pixel of damp under the lower."""
    oy = y
    for rows in BRACKET_SHELVES:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                c = {"P": BRACKET[4], "L": BRACKET[3], "M": BRACKET[1], "u": DEAD[0]}[ch]
                L.put(x - len(row) + 1 + i, oy + j, c)
        oy += len(rows) + 1
    for k in range(4):
        L.put(x - 3 + k, oy - 1, WET, 0.3)


def paint_mushrooms_s1(L):
    # m1: pale caps on the soft boards beside p3, in the shade (rel 290..304, 70..76)
    mushroom(L, *rel(295, 75), "ptall", CAP_CREAM)
    mushroom(L, *rel(301, 75), "psmall", CAP_CREAM)
    mushroom(L, *rel(290, 76), "psmall", CAP_CREAM, flip=True)
    # m2: a bracket shelf on the right wall's foot just above h2's slot (rel 316..330, 140..148)
    bracket(L, *rel(329, 141))
    # m3: brown caps at the tented boards' foot (rel 20..34, 68..74)
    mushroom(L, *rel(23, 73), "tall", CAP_BROWN)
    mushroom(L, *rel(28, 73), "small", CAP_BROWN)
    mushroom(L, *rel(32, 74), "button", CAP_BROWN)
    # m4: three pale pins at the back wall's foot where h3's arm thins out (rel 222..234,
    # 12..18), on 1-px stems of three heights, the cap's lower edge inked
    mushroom(L, *rel(225, 17), "pin3", CAP_PIN)
    mushroom(L, *rel(229, 17), "pin2", CAP_PIN)
    mushroom(L, *rel(232, 16), "pin1", CAP_PIN)
    # m5: two caps at the crease's foot, by the sill, in its shade (rel 108..118, 206..212)
    mushroom(L, *rel(111, 211), "small", CAP_BROWN)
    mushroom(L, *rel(115, 212), "button", CAP_BROWN)


def paint_mushrooms_s2(L):
    # m6: two pale caps on the window seat beside the last leak (rel 8..18, 102..108)
    mushroom(L, *rel(9, 113), "ptall", CAP_CREAM)        # clear of the puddle's near lip
    mushroom(L, *rel(14, 113), "psmall", CAP_CREAM)


# ======================================================================== skirting weeds

# Where a crack along the skirting lets a weed through: (abs x, abs y of the root, height,
# kind, blades). Kept off the door's lane, the holes and the pieces' feet; most of them on
# the damp side.
WEEDS = [
    (131, 95, 5, "green", 3), (139, 95, 3, "dead", 2), (197, 95, 4, "green", 2),
    (301, 95, 5, "dead", 3), (307, 95, 3, "green", 2),
    (91, 171, 4, "green", 3), (91, 255, 5, "dead", 2), (91, 284, 3, "green", 2),
    (412, 189, 4, "green", 3), (412, 216, 5, "dead", 2),
    (107, 296, 4, "green", 3), (143, 296, 5, "dead", 3), (150, 296, 3, "green", 2),
    (238, 296, 4, "green", 3),
]
SEED_HEAD = (214, 200, 150)


def weeds(L, t, fade=None):
    """Grass out of the skirting's crack: a tuft of 2-3 blades fanning from one root, the middle
    one tallest, lit at the tips; the dead ones straw with a pale seed head. The tips sway a
    pixel on the stepped clock in a slow draught under the door."""
    tick = math.floor(t * 8) / 8.0
    for i, (x, y, tall, kind, blades) in enumerate(WEEDS):
        ramp = [LEAF[1], LEAF[2], LEAF[3], LEAF[4]] if kind == "green" else [DEAD[1], DEAD[2], DEAD[3], DEAD[3]]
        sway = 1 if vnoise(tick * 1.4, i * 5, 1.0, 808) > 0.6 else 0
        px = []
        tips = [(0, tall)] if blades == 1 else [(-2, tall - 1), (1, tall)] if blades == 2 else [(-2, tall - 1), (2, tall - 2), (0, tall)]
        for dx, bt in tips:
            line = bres(x, y, x + dx, y - bt + 1)
            for k, (lx, ly) in enumerate(line):
                c = ramp[0] if k == 0 else ramp[1] if k < len(line) // 2 else ramp[2]
                if k == len(line) - 1:
                    c = ramp[3]
                    lx += sway
                px.append((lx, ly, c))
            if kind == "dead" and dx == 0:
                px.append((x + sway, y - bt, SEED_HEAD))
        for lx, ly, c in px:
            if fade is not None and h(lx, ly, 909) < fade:
                continue
            L.put(lx, ly, c)
        if fade is None or h(x, y, 910) >= fade:
            L.put(x, y + 1, (40, 24, 18), 0.45)     # the crack it comes out of
            L.put(x + 1, y + 1, (40, 24, 18), 0.3)


# ======================================================================== statics

_STATIC = {}


def _puddle_pts(ctx, pid, stage, rain, scale=1.0, size=None):
    f = _features(ctx).get(pid)
    if not f:
        return set(), (0, 0)
    w, hh = f.get("size_s2", f["size"]) if stage == 2 else f["size"]
    if size is not None:
        w, hh = size
    grow = 1.0 + (f.get("rain_grow", 1.3) - 1.0) * rain
    w, hh = w * grow * scale, hh * (1 + (grow - 1) * 0.6) * scale
    cx, cy = rel(*f["center"])
    look, seed, land, _, _ = PUDDLES[pid]
    if pid == "p1":
        key = ("p1", stage, round(rain, 2), round(scale, 2))
        if key not in _STATIC:
            pts = p1_mask(ctx, stage, rain)
            if scale < 1:                           # drying away: eaten from its ends inward
                for _ in range(int(round((1 - scale) * 5))):
                    pts = {(x, y) for x, y in pts if (x - 1, y) in pts and (x + 1, y) in pts}
            _STATIC[key] = pts
        return _STATIC[key], (cx, cy)
    small = pid == "p1" and stage == 2
    key = (pid, round(w * 2) / 2, round(hh * 2) / 2, small)
    if key not in _STATIC:
        if w < 1.5:
            _STATIC[key] = set()
        elif small:
            _STATIC[key] = small_mask(cx + 0.5, cy + 0.5, w, hh)
        else:
            _STATIC[key] = puddle_mask(cx + 0.5, cy + 0.5, w, hh, seed)
    return _STATIC[key], (cx, cy)


FLOOR_RAMP = [(194, 125, 96), (186, 115, 85), (180, 107, 62), (167, 98, 56), (150, 86, 48),
              (134, 76, 42)]
TRICKLE_ROW = 102             # rel: p1's middle row, straight on to h1's notch at (37, 100)


def _trickle(stage, ctx):
    """p1's wet line: along the seam under the puddle's near lip. Stage 1: from the puddle's
    last wet pixel on that seam to h1's rim on the same row (rel x 30), so it ends in the hole.
    Stage 2: only a short wet run, 4 px off the little puddle's edge (the core is far off)."""
    y = rel(0, TRICKLE_ROW)[1]
    pts, _ = _puddle_pts(ctx, "p1", stage, 0.0)
    row = [x for x, yy in pts if yy == y] or [x for x, yy in pts]
    x0 = (max(row) if row else rel(18, 0)[0]) + 1
    if stage == 1:
        f = _features(ctx).get("h1")
        rim = min((r[0] for r in f["block"] if r[1] <= TRICKLE_ROW < r[1] + r[3]), default=30)
        x1 = rel(rim, 0)[0] - 1
    else:
        x1 = x0 + 3
    return [(x, y) for x in range(x0, x1 + 1)]


def _wetter(c):
    """Wet wood: three steps down the floor's own ramp (the beam adds its light on top and
    eats the first two), or the same depth off it (the wet halo, the fresh boards)."""
    c = tuple(int(v) for v in c[:3])
    for i, r in enumerate(FLOOR_RAMP[:-1]):
        if max(abs(a - b) for a, b in zip(c, r)) <= 3:
            return FLOOR_RAMP[min(i + 3, len(FLOOR_RAMP) - 1)]
    return tuple(int(v * 0.76) for v in c)


def _joint(seen, x, y):
    """Is (x, y) the foot or head of a board's butt joint (a dark pixel between two lighter)?"""
    if not (1 <= x < W - 1 and 0 <= y < H):
        return False
    lum = lambda q: 0.3 * q[0] + 0.59 * q[1] + 0.11 * q[2]
    m = lum(seen[y, x])
    return lum(seen[y, x - 1]) - m > 6 and lum(seen[y, x + 1]) - m > 6


def paint_trickle(A, pts, seen, t, stage, rain=0.0, into_hole=True, sh=None):
    """p1's water running on across the seat: a 1-px WATER[2] line (painted as it must show, A
    is aimed); where a board's butt joint meets it the water runs a pixel into the joint, so
    the line kinks. Every so often a bead slides along it (WATER[4] with WATER[3] behind) and,
    stage 1, drops over the lip into h1: three ticks, a pixel a tick, then nothing until the
    next bead."""
    if not pts:
        return
    sh = sh or stage                                # whose light the wet wood is judged in
    for (x, y) in pts:
        up, dn = _joint(seen, x, y - 1), _joint(seen, x, y + 1)
        if up or dn:
            jy = y - 1 if up else y + 1
            A.put(x, jy, WATER[1])                  # the water takes the joint for a pixel
            if h(x, y, 72) < 0.5:
                continue                            # and leaves the seam there: a kink
        roll = h(x, y, 73)
        if 0 < pts.index((x, y)) < len(pts) - 2 and roll < 0.14:
            A.put(x, y, tuple(int(v * 0.72) for v in shown(sh, seen, x, y)))   # a dry-ish gap: wet wood
        else:
            A.put(x, y, WATER[1] if roll > 0.78 else WATER[2])
    tick = int(math.floor(t * 8))
    period = int(round((1.8 if stage == 1 else 3.6) * 8 / (1.0 + rain)))
    slide = 6 if stage == 1 else 4                  # ticks the bead takes along the line
    ph = tick % period
    if ph < slide:
        k = int(ph / slide * len(pts))
        x, y = pts[min(k, len(pts) - 1)]
        A.put(x, y, WATER[4])
        if k > 0:
            A.put(pts[k - 1][0], pts[k - 1][1], WATER[3])
    elif into_hole and stage == 1 and ph < slide + 3:
        lx, ly = pts[-1]                            # over the lip, one pixel a tick
        A.put(lx + 1, ly + 1 + (ph - slide), WATER[3])


# In a shower, rain blown in under the door wets the boots' worn dish (w1): whole board
# segments of it go one hard step darker, their ends on the seams and the butt joints, and a
# glint or two lies along a seam inside. No water stands on the door's lane.
PATH_X, PATH_Y0, PATH_Y1 = 252, 96, 134


def path_skin(L, t, rain, seen):
    if rain < 0.25:
        return
    k = min(1.0, (rain - 0.25) / 0.6)
    y1 = PATH_Y0 + int((PATH_Y1 - PATH_Y0) * (0.45 + 0.55 * k))
    spans = {}
    for sy in range(PATH_Y0, y1 + 1):
        if not seam_row(sy):
            continue
        mid = sy + 2
        cx = PATH_X + (1 if h(sy, 0, 66) > 0.6 else 0) - (1 if h(sy, 1, 66) > 0.7 else 0)
        hw = 3 + int(round(2 * vnoise(sy, 0, 8.0, 68)))
        lo, hi = cx - hw, cx + hw
        joints = [x for x in range(lo - 4, hi + 5) if _joint(seen, x, mid)]
        for j in joints:                            # a segment ends where its board does
            if lo - 4 <= j <= lo + 1:
                lo = j + 1
            if hi - 1 <= j <= hi + 4:
                hi = j - 1
        spans[sy] = (lo, hi)
        for y in range(sy + 1, sy + 4):
            for x in range(lo, hi + 1):
                L.put(x, y, WET, 0.26)
        prev = spans.get(sy - 4)
        if prev:                                    # the seam between two wet boards
            for x in range(max(lo, prev[0]), min(hi, prev[1]) + 1):
                L.put(x, sy, WET, 0.26)
    # one or two glints along a seam inside the wet
    wet_seams = [sy for sy in spans if sy - 4 in spans]
    for n, sy in enumerate(wet_seams[1:3]):
        lo, hi = spans[sy]
        plo, phi = spans[sy - 4]
        a, b = max(lo, plo), min(hi, phi)
        if b - a < 3:
            continue
        x0 = a + 1 + int(h(sy, n, 67) * max(1, b - a - 3))
        for x in range(x0, x0 + 2 + (n % 2)):
            L.put(x, sy, WATER[4])


def _static(stage, ctx, under):
    key = ("static", stage, round(ctx.rain, 2))
    if key in _STATIC:
        return _STATIC[key]
    L = Px()
    if stage == 1:
        paint_wall_yellow(L)
        paint_wall_s1(L)
    elif stage == 2:
        paint_wall_s2(L)
    # puddles and their halos
    pud = {}
    for pid in ("p1", "p2", "p3"):
        f = _features(ctx).get(pid)
        if not f or stage not in f.get("stages", []):
            continue
        pts, c = _puddle_pts(ctx, pid, stage, ctx.rain)
        wet_halo(L, pts, PUDDLES[pid][1])
        pud[pid] = (pts, c)
    A = Px()                                     # p1: painted as it must show, then aimed
    for pid, (pts, c) in pud.items():
        if pid == "p1":
            paint_p1(A, pts, stage)
        else:
            paint_puddle(L, pts, PUDDLES[pid][0], PUDDLES[pid][1])
    if stage == 1:
        paint_mushrooms_s1(L)
    elif stage == 2:
        paint_mushrooms_s2(L)
    img = unlight(L.img(), stage)
    img.alpha_composite(aimed(A.img(), stage, veil_alpha(stage, ctx.rain)))
    webs = None
    if stage == 1:
        # webs read what is under them: the room as drawn so far, with this module's own
        tmp = under.copy()
        tmp.alpha_composite(img)
        seen = _seen(stage, tmp)
        W2 = Px()
        paint_webs(W2, seen)
        webs = W2.img()
        img.alpha_composite(webs)
    _STATIC[key] = dict(img=img, webs=webs, pud=pud, trickle=_trickle(stage, ctx))
    return _STATIC[key]


# ======================================================================== the moving parts

def _drip_points(ctx, stage, pud):
    """Every dripper of the stage: (name, landing, period, offset, seed, puddle pts, kind)."""
    out = []
    for pid, (pts, c) in pud.items():
        look, seed, land, period, offset = PUDDLES[pid]
        if stage == 2:
            period, offset = 4.4, 1.0            # at t = 0 the little puddle lies still
        at = (c[0] + land[0], c[1] + land[1])
        if at not in pts and pts:
            at = min(pts, key=lambda p: (p[0] - at[0]) ** 2 + (p[1] - at[1]) ** 2)
        out.append((pid, at, period, offset, seed, pts, "water"))
    if stage == 1 and not NO_FLUE:
        (fx, fy), period, offset = FLUE
        out.append(("flue", rel(fx, fy), period, offset, 55, set(), "mud"))
    return out


def _walker_boxes(ctx):
    """The walkers' pictures as boxes (x0, y0, x1, y1), feet at the bottom: the player 16 px
    wide and 40 tall, a dog 20 wide and 18 tall."""
    out = []
    px, py = ctx.player
    out.append((px - 8, py - 40, px + 8, py + 1))
    for dx, dy, _ in ctx.dogs:
        out.append((dx - 10, dy - 18, dx + 10, dy + 1))
    return out


def _hidden_by(boxes, x, y_land):
    """The box of a walker standing over a drop's landing spot (or close behind it): the drop
    falls behind that picture, unseen, and only its ring shows at the walker's feet."""
    for b in boxes:
        if b[0] - 2 <= x <= b[2] + 2 and b[1] <= y_land <= b[3] + 8:
            return b
    return None


def flue_ring(U, seen, at, age, seed):
    """The flue drip's ring on the ash-mud: a 2:1 ellipse outline, 5 x 3 opening to 9 x 5 over
    five ticks (~0.6 s), in the ash's light steps, dissolving a pixel at a time; only on ash-mud
    pixels, never across the joist or the rim."""
    tick = int(math.floor(age * 8))
    if tick < 0 or tick >= 5:
        return
    cx, cy = at
    rx = (2, 3, 3, 4, 4)[tick]
    for (x, y) in _ring_px(cx, cy, rx + 0.0):
        if not (0 <= x < W and 0 <= y < H) or h(x, y, seed) < tick / 5.0:
            continue
        r, g, b = (int(v) for v in seen[y, x])
        if not (40 <= r <= 90 and max(r, g, b) - min(r, g, b) <= 20):
            continue                                # not ash-mud (the joist, the rim, a board)
        U.put(x, y, ASH[2] if tick < 3 else ASH[1])


def drips(t, ctx, stage, pud, U, O, P=None, seen=None):
    """Every drip of the stage. U the floor's layer, O the air's, P p1's own floor layer
    (unlit afterwards; U when not given)."""
    rain = ctx.rain
    boxes = _walker_boxes(ctx)
    P = P if P is not None else U
    for name, at, period, offset, seed, pts, kind in _drip_points(ctx, stage, pud):
        per = period / (1.0 + rain)
        x, y_land = at
        cover = _hidden_by(boxes, x, y_land)
        for k, land in _land_times(offset / (1.0 + rain), per, seed, t):
            y_top = y_land - DRIP_HIGH
            start = land - DRIP_FALL
            if t < start:
                if not (cover and cover[1] <= y_top <= cover[3]):
                    bead(O, x, y_top, t - (start - SWELL))
            elif t < land:
                s = (t - start) / DRIP_FALL
                lit = y_land - FLASH_UP - 2 if name == "p1" else None
                if name == "p1" and t >= land - 1 / 8.0:
                    # the last tick before it lands it is always inside the beam's band, so
                    # the drop flashes white-gold once, whatever the frame rate
                    s = max(s, math.sqrt((DRIP_HIGH - FLASH_UP) / DRIP_HIGH))
                yi = int(round(y_top + DRIP_HIGH * s * s))
                if not (cover and cover[1] <= yi <= cover[3] + 1):
                    drop_streak(O, x, y_top, y_land, s, WATER[4], WATER[3], lit)
            if t >= land:
                age = t - land
                if kind == "water":
                    drip_ring(P if name == "p1" else U, pts, at, age, seed * 100 + k)
                    if name == "p1" and age < 1 / 8.0:
                        O.put(x, y_land, (255, 255, 246))   # the drop's own flash, landing
                    splash(O, (x, y_land), age, seed * 100 + k, FOAM, WATER[3], n=2, crown="pixel")
                else:
                    if seen is not None:
                        flue_ring(U, seen, at, age, seed * 100 + k)
                    splash(O, (x, y_land), age, seed * 100 + k, MUD[2], ASH[1], n=3)


def rain_into_h3(t, ctx, O, seen=None, water=()):
    """In a shower, rain falling straight down through the roof's hole into h3. On earth a
    drop lands as a dull wet pixel with two mud (or moss, on the joist) flecks; foam only where
    it lands in p3's water."""
    if ctx.rain <= 0:
        return
    rects = [r for f in ctx.layout.get("features", []) if f["id"] == "h3" for r in f["block"]]
    if not rects:
        return
    n = int(round(22 * ctx.rain))
    for i in range(n):
        period = 0.55 + 0.35 * h(i, 1, 202)
        phase = (t / period + h(i, 2, 202)) % 1.0
        cyc = math.floor(t / period + h(i, 2, 202))
        r = rects[int(h(i, cyc, 203) * len(rects)) % len(rects)]
        lx = r[0] + FX + int(h(i, cyc, 204) * r[2])
        ly = r[1] + FY + int(h(i, cyc, 205) * r[3])
        fall = 0.22
        tt = phase * period
        if tt < fall:
            s = tt / fall
            y = ly - DRIP_HIGH + DRIP_HIGH * s * s
            yi = int(round(y))
            O.put(lx, yi, WATER[4], 0.75)
            O.put(lx, yi - 1, WATER[3], 0.55)
            O.put(lx, yi - 2, WATER[3], 0.3)
        elif tt < fall + 1 / 12:
            if (lx, ly) in water:
                O.put(lx, ly, FOAM, 0.7)
                O.put(lx - 1, ly - 1, FOAM, 0.4)
                O.put(lx + 1, ly - 1, FOAM, 0.4)
                continue
            fleck = MUD[2]
            if seen is not None and 0 <= ly < H and 0 <= lx < W:
                r, g, b = seen[ly, lx]
                if g > r + 4:
                    fleck = base.MOSS[3]                # the moss on the joist
            O.put(lx, ly, WATER[3], 0.6)
            O.put(lx - 1, ly - 1, fleck, 0.4)
            O.put(lx + 1, ly - 1, fleck, 0.4)


# ======================================================================== the module

def draw(stage, t, ctx, under, over):
    if stage not in (1, 2):
        return
    st = _static(stage, ctx, under)
    boards = _seen(stage, under)                    # the floor as the floor drew it: its joints
    under.alpha_composite(st["img"])
    seen = _seen(stage, under)
    U, O, A = Px(), Px(), Px()
    if "p1" in st["pud"]:
        paint_trickle(A, st["trickle"], boards, t, stage, ctx.rain)
    if stage == 1:
        path_skin(U, t, ctx.rain, seen)
        wall_beads(U, t, ctx.rain)
        weeds(U, t)
        spider(U, t)
    twinkles(U, t, st["pud"], A)
    drips(t, ctx, stage, st["pud"], U, O, A, seen)
    if stage == 1 and ctx.rain > 0:
        rain_into_h3(t, ctx, O, seen,
                     st["pud"].get("p3", (set(), None))[0])
    under.alpha_composite(unlight(U.img(), stage))
    under.alpha_composite(aimed(A.img(), stage, veil_alpha(stage, ctx.rain)))   # p1's water: as it must show
    over.alpha_composite(O.img())


# ---------------------------------------------------------------- stage up

def _steps(p, a, b, n=3):
    """p over [a, b] in n hard steps, 0..1."""
    if p <= a:
        return 0.0
    if p >= b:
        return 1.0
    return math.floor((p - a) / (b - a) * n) / n


def _dissolve(dst, src_img, q, seed):
    """Lay src over dst keeping only the pixels whose roll is still above q (0 all, 1 none)."""
    a = np.asarray(src_img).astype(np.float32).copy()
    ys, xs = np.nonzero(a[..., 3] > 0)
    for y, x in zip(ys, xs):
        if h(x, y, seed) < q:
            a[y, x, 3] = 0
    dst.alpha_composite(Image.fromarray(a.astype(np.uint8), "RGBA"))


def _recede(img, q):
    """The stage-1 wall drying: down every column left of the new paper, each run of stain (and
    of yellowing) dries from its foot up, every pixel at its own moment (how far up its run it
    sits, a little roll on top), rims and fill alike, so the stain shrinks up towards the
    moulding raggedly and never stands as an outline; q 0..1 in hard steps. Right of x 360
    the new paper covers it. Returns the layer and a mask of the pixels already dried."""
    a = np.asarray(img).astype(np.float32).copy()
    gone = np.zeros(a.shape[:2], bool)
    if q <= 0:
        return a, gone
    for x in range(PAPER_L[0], 360):
        col = a[PAPER_Y0:PAPER_Y1 + 1, x, 3] > 0
        y = 0
        while y < len(col):
            if not col[y]:
                y += 1
                continue
            y0 = y
            while y < len(col) and col[y]:
                y += 1
            ya, yb = PAPER_Y0 + y0, PAPER_Y0 + y - 1
            n = yb - ya + 1
            for yy in range(ya, yb + 1):
                up = (yb - yy + 0.5) / n                   # 0 at the foot, 1 at the top
                if 0.72 * up + 0.28 * h(x, yy, 515) < q:
                    a[yy, x, 3] = 0
                    gone[yy, x] = True
    return a, gone


def stage_up(frm, p, ctx, under, over):
    t = getattr(ctx, "t", 0.0)
    tick = math.floor(t * 8) / 8.0
    p = min(1.0, tick / 2.0) if p > 0 else 0.0     # held to the stepped clock
    rain = ctx.rain
    if frm == 1:
        c1 = base.Ctx(1, rain)
        s1 = _static(1, c1, under)
        s2 = _static(2, ctx, under)
        # the wall: stage 1's decay dissolving into stage 2's, the new paper unrolling down
        L1, L2 = Px(), Px()
        paint_wall_yellow(L1)
        paint_wall_s1(L1)
        paint_wall_s2(L2)
        q = _steps(p, 0.05, 0.75, 6)
        a1, gone = _recede(L1.img(), q)
        under.alpha_composite(Image.fromarray(a1.astype(np.uint8), "RGBA"))
        a2 = np.asarray(L2.img()).astype(np.float32).copy()
        unroll = _steps(p, 0.2, 0.8, 11)
        cut = PAPER_Y0 + int(round(unroll * (PAPER_Y1 - PAPER_Y0 + 1)))
        a2[cut:, 360:PAPER_R[1] + 1, 3] = 0
        # the ghost lines left of 360 are what the receding water leaves behind it
        for y in range(PAPER_Y0, PAPER_Y1 + 1):
            for x in range(PAPER_R[0], 360):
                if a2[y, x, 3] > 0 and not gone[y, x]:
                    a2[y, x, 3] = 0
        under.alpha_composite(Image.fromarray(a2.astype(np.uint8), "RGBA"))
        # the paper's rolled lower end as it comes down
        if 0 < unroll < 1:
            for x in range(360, PAPER_R[1] + 1):
                under.putpixel((x, cut), BACK[2] + (255,))
                if cut + 1 <= PAPER_Y1:
                    under.putpixel((x, cut + 1), BACK[0] + (255,))
        # webs, mushrooms, weeds: gone a pixel at a time
        L = Px()
        paint_mushrooms_s1(L)
        _dissolve(under, L.img(), _steps(p, 0.0, 0.55, 5), 502)
        if s1["webs"] is not None:
            _dissolve(under, s1["webs"], _steps(p, 0.0, 0.45, 4), 503)
        Wd = Px()
        weeds(Wd, t, fade=_steps(p, 0.1, 0.6, 4))
        under.alpha_composite(Wd.img())
        # puddles: p2 and p3 dry away, p1 shrinks to its stage 2 size
        U = Px()
        fade = 1.0 - _steps(p, 0.15, 0.85, 3)
        for pid in ("p2", "p3"):
            if pid in s1["pud"]:
                sc = 1.0 - _steps(p, 0.0, 0.7, 6)
                pts, c = _puddle_pts(c1, pid, 1, rain, scale=max(sc, 0.0))
                wet_halo(U, pts or s1["pud"][pid][0], PUDDLES[pid][1], fade)
                if sc > 0:
                    paint_puddle(U, pts, PUDDLES[pid][0], PUDDLES[pid][1])
        A = Px()
        if "p1" in s1["pud"]:
            step = _steps(p, 0.0, 0.6, 4)
            pts = p1_mask(ctx, 1, rain, step=step)
            wet_halo(U, pts, PUDDLES["p1"][1])
            paint_p1(A, pts, 2 if step >= 1 else 1)
            later = p > 0.15                            # h1's rim is boarded by then
            paint_trickle(A, s2["trickle"] if later else s1["trickle"], _seen(2 if later else 1, under),
                          t, 2 if later else 1, sh=1)
        # m6 pushes up beside p1, row by row from its foot
        if p > 0.55:
            M = Px()
            paint_mushrooms_s2(M)
            a = np.asarray(unlight(M.img(), 2)).astype(np.float32).copy()
            grow = _steps(p, 0.55, 0.95, 4)
            top = rel(0, 113)[1] - int(round(grow * 6))
            a[:top + 1, :, 3] = 0
            U_img = unlight(U.img(), 2)
            U_img.alpha_composite(Image.fromarray(a.astype(np.uint8), "RGBA"))
            under.alpha_composite(U_img)
        else:
            under.alpha_composite(unlight(U.img(), 2))
        under.alpha_composite(aimed(A.img(), 1, veil_alpha(1, rain, up=(1, p))))
    else:
        s2 = _static(2, ctx, under)
        L2 = Px()
        paint_wall_s2(L2)
        _dissolve(under, L2.img(), _steps(p, 0.1, 0.9, 6), 601)
        M = Px()
        paint_mushrooms_s2(M)
        _dissolve(under, unlight(M.img(), 3), _steps(p, 0.0, 0.6, 5), 602)
        U, A = Px(), Px()
        if "p1" in s2["pud"]:
            sc = 1.0 - _steps(p, 0.0, 0.65, 5)
            pts, c = _puddle_pts(ctx, "p1", 2, rain, scale=max(sc, 0.0))
            fade = 1.0 - _steps(p, 0.2, 0.9, 3)
            wet_halo(U, pts or s2["pud"]["p1"][0], PUDDLES["p1"][1], fade)
            if sc > 0:
                paint_p1(A, pts, 2)
            if p < 0.4:
                for x, y in s2["trickle"]:
                    if h(x, y, 77) >= p / 0.4:
                        A.put(x, y, WATER[2])
        under.alpha_composite(unlight(U.img(), 3))
        under.alpha_composite(aimed(A.img(), 2, veil_alpha(2, rain, up=(2, p))))


# The close-ups worth a 3x look: (name, stage, (x, y, w, h)) on the source grid. The stills
# are t = 0, timed (PUDDLES' offsets) so each shows something moving.
CLOSEUPS = [
    ("damp_puddle_drop", 1, (204, 200, 40, 46)),     # p2: the ring opening, the crown at the boots
    ("damp_window_leak", 1, (84, 156, 44, 48)),      # p1 in the light, its wet line
    ("damp_wall", 1, (266, 56, 152, 32)),            # streaks, tide line, the flap, the torn corner
    ("damp_mushrooms", 1, (366, 112, 50, 52)),       # p3 under the roof corner, its bead, m1
    ("damp_corner_web", 1, (84, 54, 34, 28)),        # the top-left web and its spider
    ("damp_wall_s2", 2, (266, 56, 152, 32)),         # the new paper, the ghosts
    ("damp_last_leak", 2, (84, 176, 44, 26)),        # p1 alone, m6, the wet line over new boards
]

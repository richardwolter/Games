"""life.py -- the house-stages mockup: things in the air, and the light (2026-10-11).

What this module draws (all in `over` unless stated):

  stage 1  THE ROOM IN THE DARK: a cool, see-through veil (VEIL_INK) over the room under the
           whole top run (y 62 down) and inside the side mouldings, never on the moulding ring,
           the door's jambs and lintel or the lake, in four hard steps: the shaft's core 0.04,
           its margin 0.12, the room 0.23, the shade side 0.33. No noise on any edge: the
           cone's steps are the game's shaft (shed_room.gd), worked out per source pixel on
           the wall and BOARD BY BOARD on the floor (a whole board takes one step, so an edge
           runs along a seam and steps at a butt joint: the light falls off plank by plank);
           a hole takes one step over the whole of it. The shade side is the back wall from
           x 269 (the right jamb's edge carries it) and a band down the room's right, wide at
           the back, narrow at the front (SHADE_LINE), snapped to the planks' joints.
           floor.py's daylight slits across the low corner are light too: the veil gives way.
           DUST MOTES (56) drift in the shaft: one source px each, drawn only where the shaft
           is at least MOTE_FROM and never over a piece's picture, the player or a dog (going behind
           one, it fades out in three steps, no pop), lit in hard
           steps of the sun's cream, in slow lazy loops (<= 3 px/s), rising and fading in and
           out in steps; the brightest now and then flick white for one tick (about one
           glint every 1-2 s over the whole shaft). Four more slide slowly along
           the daylight slits. In a shower the shaft thins as the game's does (RAIN_SUN): the
           veil takes the beam one step down and half the motes go, the rest a step dimmer.
  stage 2  the veil a step lighter (room 0.10, shade side 0.17, the shaft clear) and given way
           round the lit fire and lamp (their pools, the game's sums); 20 motes.
  stage 3  no veil, 7 motes. BEES (4), the lake's bee one pixel longer (yellow, yellow, the
           dark band trailing; both wings flicking every other frame, folded when sat):
           circling a bloom on the lake's orbit, flying bloom to bloom, landing a while.
           BUTTERFLIES: a lemon one along the top run, a sky-blue one at the window's flowers
           (and the flower vase on the table, when it stands there), a third (lemon) in off
           the lake under the sill now and then, round the sill's blooms and away. No flier
           ever crosses the Decorate shelf (off_shelf). Over the ivy a bee's band is ink and
           one wing pixel always shows; its wings flick on a fixed 16 Hz clock. Butterflies: a notched
           3x2 forewing over a 2x1 hindwing each side, the outer tip a step darker, a 1x2 INK
           body in every frame; on the stepped 8 fps clock (open, lifting, shut, lifting), mostly open when perched; a step
           lighter crossing the window's shaft; a faint shadow on the boards below them.
           PETALS: one every ~4.4 s off a pink bloom on the top or side runs (never one with
           a standing piece in its way), tumbling down (two pixels flat, one edge-on) with a
           sway, landing on the boards (in `under`, beneath anything standing there) and
           going in steps: whole, see-through, one pixel, gone.
  Every visit is asked of veg.py's flower_spots(3) by kind and place, never by index, and
  blooms a piece of furniture stands over are never visited.

stage_up 1->2 the veil lifts in three steps; the extra dust settles out mote by mote.
stage_up 2->3 the veil goes in three steps, the dust thins; a lemon butterfly comes in off
              the lake and lands on its bloom once veg.py has opened it; the bees follow it in.

Numbers are first guesses for Richard's eye. Every position is a whole source pixel.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import base
from base import BLUE, PINK, RED, WHITE, YELLOW, h, put, vnoise

# ======================================================================== the light

# The window's shaft, in source px, from the game's own numbers (shed_room.gd: SHAFT_WIDE 0.6
# cells, SHAFT_SPREAD 0.36, SHAFT_LONG 34 cells, cell 8, the cone's axis level). The axis is
# fitted to the captures: the lit band's middle runs at y 198-199 across the floor.
WIN = (90.0, 198.0)
SHAFT_WIDE = 4.8
SHAFT_SPREAD = 0.36
SHAFT_LONG = 272.0

# The room inside its moulding: the outer ring of the frame (6 px at the sides, 5 at the top,
# the sill at the foot) is not the room, so the vines on it and over the lake are never veiled.
IN_X0, IN_Y0, IN_X1, IN_Y1 = 90, 62, 413, 297      # inclusive: under the whole top run (52..61)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def shaft_map() -> np.ndarray:
    """The shaft's strength per source pixel, 0..1, the game's Gaussian cone (360 x 640)."""
    ys, xs = np.mgrid[0:base.GRID[1], 0:base.GRID[0]].astype(np.float32)
    along = xs + 0.5 - WIN[0]
    across = ys + 0.5 - WIN[1]
    wide = SHAFT_WIDE + np.maximum(along, 0) * SHAFT_SPREAD
    beam = np.exp(-(across * across) / (wide * wide))
    reach = _smooth(-SHAFT_WIDE, SHAFT_WIDE * 1.5, along) * np.exp(-np.maximum(along, 0) / SHAFT_LONG)
    m = beam * reach
    inside = np.zeros_like(m, bool)
    inside[IN_Y0:IN_Y1 + 1, IN_X0:IN_X1 + 1] = True
    return np.where(inside, m, 0.0)


_SHAFT = None


def shaft() -> np.ndarray:
    global _SHAFT
    if _SHAFT is None:
        _SHAFT = shaft_map()
    return _SHAFT


def shaft_at(x, y) -> float:
    x, y = int(x), int(y)
    if 0 <= x < base.GRID[0] and 0 <= y < base.GRID[1]:
        return float(shaft()[y, x])
    return 0.0


# ======================================================================== the veil

# A cool dark, so the warm boards go dusty under it and the warm shaft stands out of it.
VEIL_INK = (18, 20, 30)
# Alpha per step: 0 the shaft's core, 1 its margin, 2 the room, 3 the shade side. Small steps
# (about 0.1 apart) so no step edge reads as a line drawn on the boards: it reads as falloff.
VEIL_ALPHA = {1: (0.04, 0.12, 0.23, 0.33), 2: (0.0, 0.0, 0.07, 0.11)}
# Where the steps change, in light (the sun's shaft at SUN plus any lit piece's pool, the
# game's own sums). No noise on any edge: the game's shaft is a clean cone (shed_light).
SUN = 0.5                # the shaft's share at a middling hour (SUN_POWER 0.30..0.62)
CORE_AT = 0.21
MARGIN_AT = 0.11
FADE_FROM, FADE_TO = 0.50, 0.92   # the shaft gives out across the room's shade side
# The boards start here (floor-rel y 10, under the floor box's top rail). Above: the back wall
# and its rail, where steps are worked out per pixel; on the boards, board by board.
BOARDS_Y = 94
FLOOR_Y = 84             # the floor box's top (floor-rel 0): plank rows count from here
# The planks (floor.py / layout hints): seam rows at floor-rel y % 4 == 0, butt joints in
# plank k at x = [6, 10, 4, 12][k % 4] + 16 m. Light on the boards is worked out per board.
PLANK_JOINTS = (6, 10, 4, 12)
PLANK_LONG = 16
# The shade side: the back wall's right half (from the paper's first column under the door's
# right jamb, so the jamb's edge carries the step) and a band down the room's right side,
# wide at the back where the roof is worst, narrowing to the front. On the boards its edge
# is this line snapped to each plank's nearest butt joint. (x at y), abs source px.
SHADE_WALL_X = 269
SHADE_LINE = ((BOARDS_Y, 274.0), (160, 364.0), (297, 398.0))
# The door's jambs and lintel are moulding, not room: never veiled (abs, inclusive).
DOOR_FRAME = (235, 52, 268, 83)
# A lit piece throws a pool the veil gives way to (shed_room.gd FIRE_*/LAMP_*, the shader's
# pool: squashed, reaching further down the screen than up). (reach px, power) by piece, for
# the views that are lit.
POOLS = {"decor_pk_fireplace": ({1}, 72.0, 0.34), "decor_pk_floor_lamp": ({1}, 44.0, 0.22),
         "decor_pk_table_lamp": ({1}, 44.0, 0.22)}
POOL_SQUASH, POOL_AHEAD, POOL_BACK = 0.62, 1.45, 2.4


def _pools(ctx, xs, ys):
    out = np.zeros(xs.shape, np.float32)
    for p in getattr(ctx, "pieces", []):
        got = POOLS.get(p["piece"])
        if not got or p["view"] not in got[0]:
            continue
        x, y, w, hh = p["rect"]
        cx, cy = x + w / 2.0, y + hh            # the pool sits on the piece's foot
        ox = xs + 0.5 - cx
        oy = ys + 0.5 - cy
        oy = np.where(oy < 0, oy * POOL_BACK, oy / POOL_AHEAD) / POOL_SQUASH
        d = np.sqrt(ox * ox + oy * oy) / got[1]
        out += got[2] * np.exp(-d * d * 3.2)
    return out


def _boards(xs, ys):
    """For every pixel on the boards, the id of the board it is on (plank row by joint), and
    the board's middle; -1 off the boards."""
    ry = ys - FLOOR_Y
    k = ry // 4
    off = np.take(np.array(PLANK_JOINTS), k % 4)
    rx = xs - 84
    m = np.floor((rx - off) / PLANK_LONG).astype(np.int64)
    bid = np.where(ys >= BOARDS_Y, k * 64 + (m + 2), -1)
    mid_x = 84 + off + PLANK_LONG * m + PLANK_LONG / 2.0
    mid_y = FLOOR_Y + k * 4 + 2.0
    return bid, mid_x, mid_y


def _per_board(v, bid):
    """v averaged over each board (pixels off the boards keep their own value)."""
    on = bid >= 0
    if not on.any():
        return v
    ids = bid[on]
    uniq, inv = np.unique(ids, return_inverse=True)
    sums = np.bincount(inv, weights=v[on])
    cnts = np.bincount(inv)
    out = v.copy()
    out[on] = (sums / cnts)[inv]
    return out


def _shade_x(y):
    """The shade edge's x at row y, along SHADE_LINE."""
    pts = SHADE_LINE
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, x0), (y1, x1) in zip(pts, pts[1:]):
        if y <= y1:
            return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
    return pts[-1][1]


def _shade_mask(xs, ys):
    """True on the shade side: the wall and its rail from SHADE_WALL_X right; on the boards
    from each plank's butt joint nearest the shade line (so it steps board by board)."""
    out = np.zeros(xs.shape, bool)
    wall = ys < BOARDS_Y
    out |= wall & (xs >= SHADE_WALL_X)
    for y in range(BOARDS_Y, IN_Y1 + 1):
        k = (y - FLOOR_Y) // 4
        off = PLANK_JOINTS[k % 4]
        mid = FLOOR_Y + k * 4 + 2
        want = _shade_x(mid) - 84
        jx = 84 + off + PLANK_LONG * round((want - off) / PLANK_LONG)
        out |= (ys == y) & (xs >= jx)
    return out


def _veil_steps(stage) -> np.ndarray:
    """The veil's step (0..3) per pixel, -1 where nothing is veiled. Static: the shaft does not
    move on this time scale, and a veil that crawled would read as a bug."""
    ctx = _ctx(stage)
    sh = shaft()
    H, W = sh.shape
    steps = np.full((H, W), -1, np.int8)
    ys, xs = np.mgrid[IN_Y0:IN_Y1 + 1, IN_X0:IN_X1 + 1]
    across = (xs - IN_X0) / (IN_X1 - IN_X0)
    v = SUN * sh[IN_Y0:IN_Y1 + 1, IN_X0:IN_X1 + 1] * (1 - 0.85 * _smooth(FADE_FROM, FADE_TO, across))
    v = v + _pools(ctx, xs, ys)
    bid, _mx, _my = _boards(xs, ys)
    v = _per_board(v.astype(np.float64), bid)
    s = np.where(v >= CORE_AT, 0, np.where(v >= MARGIN_AT, 1, 2)).astype(np.int8)
    s = np.where((s == 2) & _shade_mask(xs, ys), 3, s).astype(np.int8)
    # A hole is earth, not boards: one step over the whole of it (its commonest), or a step
    # edge across it reads as two materials in the one hole.
    for f in ctx.layout.get("features", []):
        if f.get("kind") != "hole" or stage not in f.get("stages", []):
            continue
        m = np.zeros(s.shape, bool)
        for rx, ry, rw, rh in f.get("block", []):
            x0, y0 = ctx.to_abs(rx, ry)
            m[max(0, y0 - IN_Y0):y0 + rh - IN_Y0, max(0, x0 - IN_X0):x0 + rw - IN_X0] = True
        if m.any():
            vals, cnt = np.unique(s[m], return_counts=True)
            s[m] = vals[np.argmax(cnt)]
    # On the wall (worked out per pixel): no lone pixels, a step edge is a contour.
    wall = ys < BOARDS_Y
    for _ in range(2):
        p = np.pad(s, 1, mode="edge")
        n = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        alone = (n != s[None]).all(axis=0) & wall
        s = np.where(alone, n[0], s)
    steps[IN_Y0:IN_Y1 + 1, IN_X0:IN_X1 + 1] = s
    x0, y0, x1, y1 = DOOR_FRAME
    steps[max(y0, IN_Y0):y1 + 1, x0:x1 + 1] = -1
    # Daylight through the far gable's gaps (floor.py's slits across the low corner, stage 1)
    # is light too: the veil gives way along them, so they stay the brightest thing there.
    if stage == 1:
        try:
            import floor  # noqa: WPS433
            for rx, ry in floor.SLITS:                # floor-relative (placement px)
                x, y = ctx.to_abs(rx, ry)
                for dx, k in ((0, 0), (1, 1)):
                    if IN_X0 <= x + dx <= IN_X1 and IN_Y0 <= y <= IN_Y1 and steps[y, x + dx] >= 0:
                        steps[y, x + dx] = min(int(steps[y, x + dx]), k)
        except Exception:
            pass
    return steps


_CTX = {}
_STEPS = {}
_VEILS = {}


def _ctx(stage):
    if stage not in _CTX:
        _CTX[stage] = base.Ctx(stage)
    return _CTX[stage]


def veil_steps(stage):
    if stage not in _STEPS:
        _STEPS[stage] = _veil_steps(stage)
    return _STEPS[stage]


def _rgba(alpha) -> Image.Image:
    rgba = np.zeros(alpha.shape + (4,), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = VEIL_INK
    rgba[..., 3] = np.round(alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def veil_image(stage, alphas) -> Image.Image:
    key = (stage,) + tuple(round(a, 3) for a in alphas)
    if key in _VEILS:
        return _VEILS[key]
    st = veil_steps(stage)
    a = np.zeros(st.shape, np.float32)
    for k, al in enumerate(alphas):
        a[st == k] = al
    _VEILS[key] = _rgba(a)
    return _VEILS[key]


def draw_veil(over, stage, alphas):
    if alphas is None or max(alphas) <= 0:
        return
    over.alpha_composite(veil_image(stage, alphas))


# The play-in lifts the veil by moving its edges, never its alpha: the light spreads out from
# the window across the room in SWEEPS, board by board, and the shade side gives way last.
# NEAR_TICKS (8 fps; p 1 = 16 ticks) each take a sixth of the lit boards nearest the window,
# clear of floor.py's core work (1->2: the cores sawn at tick 10, the stack at 15; 2->3: h2's
# core started at tick 1, h1's at tick 7). The back wall (its lit part) lightens all over in
# one hard step at each of them: swept column by column it left a hard vertical seam across
# the paper that read as a cut rectangle.
# FAR_TICKS then take the rest, one tick each: one front on over the far lit boards and on
# across the shade side to the right wall, board by board, each plank row split so every tick
# lifts the same share of its veil (the right wall's paper lightens all over a step a tick meanwhile).
# Taken whole at the last sweep, the shade side popped the right third by 20 points at once.
NEAR_TICKS = {1: (3, 5, 7), 2: (3, 5, 8)}
FAR_TICKS = {1: (8, 9, 10, 11, 12, 13, 14), 2: (9, 10, 11, 12, 13, 14)}
NEAR_SHARE = 0.7          # the share of the lit boards (nearest the window) the near ticks take
WEDGE_WALL_X = IN_X1 + 9  # past the last board's middle: where the shade has receded to at the end


def _alpha_of(stage):
    st = veil_steps(stage)
    a = np.zeros(st.shape, np.float32)
    if stage in VEIL_ALPHA:
        for k, al in enumerate(VEIL_ALPHA[stage]):
            a[st == k] = al
    return a


def _sweep_order(frm):
    """The tick (1..16) at which each pixel takes the new veil; 0 where the old veil is none."""
    st = veil_steps(frm)
    H, W = st.shape
    ys, xs = np.mgrid[0:H, 0:W]
    bid, mx, my = _boards(xs, ys)
    cx = np.where(bid >= 0, mx, xs + 0.5)
    cy = np.where(bid >= 0, my, float(BOARDS_Y))
    # Out from the window: along the beam, and a little less fast across it.
    d = (cx - WIN[0]) + np.abs(cy - WIN[1]) * 0.9
    near_t, far_t = NEAR_TICKS[frm], FAR_TICKS[frm]
    order = np.zeros((H, W), np.int8)
    room = st >= 0
    lit = room & (st < 3)
    lit_boards = lit & (bid >= 0)
    wedge = room & (st == 3)
    # The near half of the lit boards, in equal sixths by distance from the window.
    nn = len(near_t)
    qs = np.quantile(d[lit_boards], [NEAR_SHARE * i / nn for i in range(1, nn + 1)])
    o = np.zeros((H, W), np.int8)
    for q in qs[:-1]:
        o += (d > q).astype(np.int8)
    near = lit_boards & (d <= qs[-1])
    order = np.where(near, np.take(np.array(near_t, np.int8), o), order)
    order = np.where(lit & (bid < 0), -1, order)          # the wall: see up_veil
    order = np.where(room & (st == 3) & (bid < 0), -2, order)
    # The far set, as one front: on over the far lit boards out from the window (as a share of
    # the way to the shade side's edge in that row, so the light reaches the edge all along it
    # together: by distance alone the front-right corner came last in one big bite), then on
    # across the shade side to the right wall (the same share of each row's width a tick).
    far_lit = lit_boards & ~near
    row = np.where(bid >= 0, my, ys).astype(np.float64)
    sx = np.vectorize(_shade_x)(row)
    key = np.zeros((H, W), np.float64)
    d_edge = (sx - WIN[0]) + np.abs(row - WIN[1]) * 0.9
    key = np.where(far_lit, np.minimum(0.999, d / np.maximum(1.0, d_edge)), key)
    f = np.clip((cx - sx) / np.maximum(1.0, WEDGE_WALL_X - sx), 0.0, 0.999)
    floor_wedge = wedge & (bid >= 0)
    key = np.where(floor_wedge, 1.0 + f, key)
    # A hole is not held together here: the big one at the back right taken whole in one tick
    # was a jump of its own (the play-in boards it over anyway).
    far = far_lit | floor_wedge
    far_t = FAR_TICKS[frm]
    if far.any():
        # Split by the veil each pixel loses, so every far tick lifts about the same amount;
        # a board (one key) goes in one tick.
        # Row by row (each plank row its own schedule): every row loses the same share of its
        # far veil a tick, so no stretch of the room takes a big bite in one tick.
        lift = np.abs(_alpha_of(frm) - _alpha_of(frm + 1)).astype(np.float64) + 1e-4
        for r in np.unique(row[far]):
            m = far & (row == r)
            kk = key[m]
            u, inv = np.unique(kk, return_inverse=True)
            mass = np.bincount(inv, weights=lift[m])
            cum = (np.cumsum(mass) - mass / 2.0) / mass.sum()
            gt = np.minimum(len(far_t) - 1, np.floor(cum * len(far_t))).astype(np.int64)
            order[m] = np.take(np.array(far_t, np.int8), gt[inv])
    return order


_ORDER = {}
_UPVEIL = {}


def up_veil(frm, tick) -> Image.Image | None:
    """The veil `tick` ticks into the play-in from stage frm."""
    if frm not in _ORDER:
        _ORDER[frm] = _sweep_order(frm)
    order = _ORDER[frm]
    near_n = sum(1 for k in NEAR_TICKS[frm] if tick >= k)
    far_n = sum(1 for k in FAR_TICKS[frm] if tick >= k)
    key = (frm, int(np.sum(np.unique(order[order > 0]) <= tick)), near_n, far_n)
    if key in _UPVEIL:
        return _UPVEIL[key]
    st0 = veil_steps(frm)
    a0, a1 = _alpha_of(frm), _alpha_of(frm + 1)
    swept = (order >= 1) & (order <= tick)
    # A pixel the old veil did not reach (outside the room) takes the new one at once.
    a = np.where(swept | (st0 < 0), a1, a0)
    # The back wall's lit paper (order -1) is lit across, not swept: it goes from the old veil
    # to the new in one hard step at each near tick, the same everywhere on it, so no seam runs
    # down the paper and no one tick pops it.
    # Its shade side (order -2) the same, a hard step at each of the shade's own ticks.
    for mark, k in ((-1, near_n / len(NEAR_TICKS[frm])), (-2, far_n / len(FAR_TICKS[frm]))):
        a = np.where(order == mark, np.round((a0 + (a1 - a0) * k) * 255) / 255, a)
    _UPVEIL[key] = _rgba(a) if a.max() > 0 else None
    return _UPVEIL[key]


# ======================================================================== dust motes

# How many float in the shaft. One list: stage 2 keeps the first 20 of stage 1's, stage 3 the
# first 7, so a stage-up only ever takes motes away.
MOTES = {1: 56, 2: 20, 3: 7}
# Three hard steps of the sun's cream, by how much of the shaft a mote is in.
MOTE_BRIGHT = (255, 246, 222)
MOTE_MID = (246, 222, 170)          # FRESH[5]
MOTE_DIM = (236, 198, 140)          # FRESH[4], see-through
MOTE_SPARK = WHITE[2]
MOTE_SEEN = (0.20, 0.34, 0.55)      # dim / mid / bright from this lit strength up
MOTE_RISE = (14.0, 26.0)            # seconds for one slow rise of RISE_PX
RISE_PX = 14.0
TWINKLE_EVERY = (160, 280)          # stepped ticks (8 fps) between a mote's glints: one
                                    # glint every second or two over the whole shaft, dust not treasure
MOTE_FROM = 0.34                    # a mote is drawn only where the shaft is this strong
# The player's picture round their feet (source px: left, up, right), where no mote is drawn.
PLAYER_BOX = (-11, -42, 11)        # the figure is ~40 tall with a wide hat brim
DOG_BOX = (-5, -18, 5)              # a dog's picture round its feet
TWINKLE_GLOW = 0.95                 # only the motes this lit (their own `glow`) ever glint


def _make_motes():
    sh = shaft()
    out = []
    k = 0
    tries = 0
    while len(out) < MOTES[1] and tries < 20000:
        tries += 1
        x = 94 + h(tries, 1, 401) * 230
        y = 150 + h(tries, 2, 401) * 100
        s = shaft_at(x, y)
        if s < 0.22:
            continue
        # Denser near the window, where the light is strongest.
        if h(tries, 3, 401) > s ** 1.1:
            continue
        r = lambda n, a, b: a + h(k, n, 777) * (b - a)
        out.append({
            "x": x, "y": y,
            "ax": r(1, 2.0, 5.0), "wx": r(2, 0.15, 0.40), "px": r(3, 0, 6.3),
            "ay": r(4, 1.2, 3.5), "wy": r(5, 0.12, 0.35), "py": r(6, 0, 6.3),
            "bx": r(7, 0.5, 1.2), "wb": r(8, 0.6, 1.2), "pb": r(9, 0, 6.3),
            "rise": r(10, *MOTE_RISE), "ro": r(11, 0, 1),
            "glow": r(12, 0.75, 1.15),
            "tw": int(r(13, *TWINKLE_EVERY)),
            "to": int(r(14, 0, 1) * r(13, *TWINKLE_EVERY)),   # spread over its own period
        })
        k += 1
    return out


_MOTES = None


def motes():
    global _MOTES
    if _MOTES is None:
        _MOTES = _make_motes()
    return _MOTES


def _mote_state(m, t):
    """(x, y, fade 0..1 in steps) of one mote at t."""
    r = (t / m["rise"] + m["ro"]) % 1.0
    x = m["x"] + m["ax"] * math.sin(t * m["wx"] + m["px"]) + m["bx"] * math.sin(t * m["wb"] + m["pb"])
    y = m["y"] + m["ay"] * math.sin(t * m["wy"] + m["py"]) + RISE_PX * (0.5 - r)
    # In and out at the ends of its rise, a step at a time.
    edge = min(r, 1.0 - r) / 0.12
    fade = 1.0 if edge >= 1 else (0.66 if edge >= 0.5 else 0.33)
    return math.floor(x), math.floor(y), fade


def _blocked(ctx):
    """The rects (x0, y0, x1, y1, inclusive) a mote is never drawn in: every piece's picture and
    the player's. Dust in front of a blanket reads as a speck on the blanket."""
    out = [(x, y, x + w - 1, y + hh - 1) for x, y, w, hh in (p["rect"] for p in getattr(ctx, "pieces", []))]
    pl = getattr(ctx, "player", None)
    if pl:
        out.append((pl[0] + PLAYER_BOX[0], pl[1] + PLAYER_BOX[1], pl[0] + PLAYER_BOX[2], pl[1]))
    for d in getattr(ctx, "dogs", []) or []:
        out.append((d[0] + DOG_BOX[0], d[1] + DOG_BOX[1], d[0] + DOG_BOX[2], d[1]))
    return out


def _hidden_at(m, t, blocked):
    """True where a mote at t would not be drawn: out of the shaft or over a picture."""
    x, y, _f = _mote_state(m, t)
    if shaft_at(x, y) < MOTE_FROM:
        return True
    return any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in blocked)


def _cover_fade(m, t, blocked):
    """A mote going behind a picture or out of the shaft fades the way its rise ends do, a
    step a tick (0.66, 0.33, gone over three 8 fps ticks), and comes back the same way: no
    hard pop at a piece's edge. Stateless: it looks two ticks ahead and two back."""
    if _hidden_at(m, t, blocked):
        return 0.0
    for k, f in ((1, 0.33), (2, 0.66)):
        if _hidden_at(m, t + k / 8.0, blocked) or _hidden_at(m, t - k / 8.0, blocked):
            return f
    return 1.0


def draw_motes(over, t, n, gone=None, sun=1.0, ctx=None, dim=0):
    """The first `n` motes. `gone(i)` -> a fade multiplier for settling ones (stage-up);
    `sun` how much of the shaft is shining; `dim` takes every mote that many hard steps down
    (a shower: bright to mid, mid to dim, dim out, and no glints)."""
    tick = math.floor(t * 8)
    blocked = _blocked(ctx) if ctx is not None else []
    for i, m in enumerate(motes()[:n]):
        x, y, fade = _mote_state(m, t)
        fade = min(fade, _cover_fade(m, t, blocked))
        if fade <= 0:
            continue
        if gone is not None:
            fade *= gone(i)
            if fade <= 0:
                continue
        lit = shaft_at(x, y) * m["glow"] * sun
        if lit < MOTE_SEEN[0]:
            continue
        twinkle = (dim == 0 and m["glow"] >= TWINKLE_GLOW and (tick + m["to"]) % m["tw"] < 1
                   and lit >= MOTE_SEEN[1] and fade >= 1)
        if twinkle:
            put(over, x, y, MOTE_SPARK)              # a single white flick, no star
            continue
        step = (2 if lit >= MOTE_SEEN[2] else 1 if lit >= MOTE_SEEN[1] else 0) - dim
        if step < 0:
            continue
        c, a = ((MOTE_DIM, 170), (MOTE_MID, 235), (MOTE_BRIGHT, 255))[step]
        put(over, x, y, c, int(a * fade))


# The daylight slits across the low corner (floor.py's lt1, stage 1) carry a little dust of
# their own: a few motes sliding slowly along each streak, seen only while in it.
SLIT_MOTES = 4
SLIT_DRIFT = 0.035        # share of a slit's length a second


def _slit_runs(ctx):
    try:
        import floor  # noqa: WPS433
        pts = [ctx.to_abs(x, y) for x, y in floor.SLITS]
    except Exception:
        return []
    runs, run = [], []
    for pt in pts:
        if run and max(abs(pt[0] - run[-1][0]), abs(pt[1] - run[-1][1])) > 2:
            runs.append(run)
            run = []
        run.append(pt)
    if run:
        runs.append(run)
    return [r for r in runs if len(r) > 6]


def draw_slit_motes(over, ctx, t):
    runs = _slit_runs(ctx)
    if not runs:
        return
    tick = math.floor(t * 8)
    for i in range(SLIT_MOTES):
        run = runs[i % len(runs)]
        # Up and down the streak, slowly, out of step with the others.
        u = 0.5 + 0.42 * math.sin(t * SLIT_DRIFT * 2 * math.pi + h(i, 1, 55) * 6.3)
        x, y = run[min(len(run) - 1, int(u * len(run)))]
        lift = int(h(i, 2, 55) * 3)                  # in the air over the streak, not on it
        if (tick + i * 13) % 52 < 1:
            put(over, x, y - lift, MOTE_SPARK)
        else:
            put(over, x, y - lift, MOTE_MID, 200)


# ======================================================================== the frame's blooms

# Where the flowers are, if veg.py cannot say: (x, y, kind) on the source grid. veg.py's
# flower_spots(3) is the truth; these only keep the module drawing on its own.
FALLBACK_BLOOMS = [
    (92, 54, "rose_red"), (97, 53, "daisy"), (89, 58, "pink"), (84, 62, "daisy"),
    (186, 69, "pink"), (210, 53, "daisy"), (230, 54, "rose_pink"), (234, 54, "rose_red"),
    (246, 54, "rose_pink"), (258, 51, "rose_red"), (269, 65, "rose_red"), (291, 54, "pink"),
    (366, 305, "yellow"), (398, 306, "rose_pink"), (331, 304, "pink"), (402, 53, "pink"),
    (412, 52, "rose_pink"), (419, 68, "pink"), (420, 97, "pink"), (84, 167, "pink"),
    (87, 186, "yellow"), (84, 197, "daisy"), (84, 234, "daisy"), (411, 306, "rose_pink"),
    (390, 307, "pink"),
]
_BLOOMS = {}
_COVER = {}      # stage -> the pieces' rects, grown a pixel: a bloom under one is not visited


def blooms(stage=3):
    """The frame's open flowers as [(x, y, kind)], from veg.py's flower_spots(stage), less any
    a piece of furniture stands over (the bookshelf, the paintings and the clock reach up over
    the top run): a bee would be seen sitting on the picture frame."""
    if stage in _BLOOMS:
        return _BLOOMS[stage]
    got = None
    try:
        import veg  # noqa: WPS433
        got = [(int(x), int(y), str(k)) for x, y, k in veg.flower_spots(stage)]
    except Exception:
        got = None
    got = got if got else list(FALLBACK_BLOOMS)
    cover = _COVER.get(stage)
    if cover is None:
        cover = [p["rect"] for p in base.Ctx(stage).pieces]

    def seen(x, y):
        return not any(px - 1 <= x <= px + pw and py - 1 <= y <= py + ph for px, py, pw, ph in cover)
    _BLOOMS[stage] = [b for b in got if seen(b[0], b[1]) and seen(b[0], b[1] - 1)]
    return _BLOOMS[stage]


def base_kind(kind):
    """veg.py's small roses ('rose_red_s') are roses all the same."""
    return kind[:-2] if kind.endswith("_s") else kind


def _kind_ok(kind, group):
    kind = base_kind(kind)
    if group == "any":
        return kind != "wisteria"
    if group == "rose":
        return kind.startswith("rose")
    if group == "pinkish":
        return kind in ("pink", "rose_pink", "rose_red")
    return kind == group


# Blooms inside the room, off the furniture: the flower vase's head, when the vase stands in
# the room (decor_pk_flower_vase: its daisy is 3 px in and 2 down from its picture's corner).
INDOOR = {"vase": ("decor_pk_flower_vase", (3, 2))}
_INDOOR = {}


def find_indoor(ctx):
    _INDOOR.clear()
    for p in getattr(ctx, "pieces", []):
        for name, (piece, (dx, dy)) in INDOOR.items():
            if p["piece"] == piece:
                _INDOOR[name] = (p["rect"][0] + dx, p["rect"][1] + dy)


def _plan_here(plan):
    """A plan less the visits to indoor blooms that are not in the room."""
    return [v for v in plan if v[0] not in INDOOR or v[0] in _INDOOR]


def bloom_near(group, at, stage=3):
    """The open bloom of `group` nearest `at`: where a visitor is sent. Asked by place and
    kind, not by index, so veg.py may move its flowers and the visits follow them."""
    if group in _INDOOR:
        return _INDOOR[group]
    best, bd = None, 1e9
    for x, y, k in blooms(stage):
        if not _kind_ok(k, group):
            continue
        d = (x - at[0]) ** 2 + (y - at[1]) ** 2
        if d < bd:
            best, bd = (x, y), d
    return best if best else tuple(at)


def bloom_open_at(at):
    """When, in the 2->3 play-in (p), the bloom at `at` is fully open (veg.py's own timing:
    t0 plus its 0.3 opening). 0.6 when veg.py cannot say."""
    try:
        import veg  # noqa: WPS433
        for b in veg.plan()[4]:
            if (b.x, b.y) == tuple(at):
                return min(1.0, b.t0 + 0.3)
    except Exception:
        pass
    return 0.6


# ======================================================================== bees

# The lake's bee (scripts/flora.gd _draw_bees): a yellow pixel, a dark band trailing the way it
# flies, a wing pixel over it flicking every other frame; circling a bloom on the lake's own
# orbit (rx 5..10, ry 3..6, 2.2..3.5 rad/s, a wobble at 2.3x). In the house it also goes
# bloom to bloom, and lands a while on the ones marked so: wings still, a pixel over the bloom.
BEE_BODY = (245, 204, 71)
BEE_BAND = (46, 33, 15)
BEE_WING = (237, 247, 250)
BEE_WING_A = 140          # the lake's 0.55
BEE_SPEED = 34.0          # source px a second between blooms
BEE_LAND = (0.28, 0.78)   # the share of a landing stay spent sat on the bloom
# Each bee: (seconds into its loop at t 0, [(kind, near, seconds there, lands?)]).
BEES = [
    (1.5, [("rose_pink", (266, 53), 3.0, True), ("rose", (253, 52), 2.4, False),
           ("rose", (236, 77), 3.2, True), ("rose", (259, 52), 2.2, False)]),
    (0.4, [("pinkish", (89, 55), 3.4, True), ("daisy", (91, 49), 2.2, False),
           ("rose", (85, 62), 2.8, True), ("pinkish", (85, 67), 2.0, False)]),
    (2.6, [("rose", (416, 53), 2.6, False), ("daisy", (418, 62), 3.4, True),
           ("rose", (419, 63), 2.4, False), ("daisy", (417, 81), 3.0, True)]),
    (0.9, [("rose", (409, 305), 3.2, True), ("yellow", (400, 305), 2.4, False),
           ("pinkish", (393, 305), 2.8, True), ("daisy", (406, 306), 2.2, False)]),
]


def _legs(plan, speed, min_gap=0.0):
    """A looping plan of visits laid out as legs: ('stay', at, secs, land) / ('fly', a, secs, b).
    A stop resolving closer than `min_gap` to the one before it is dropped: a flight of a few
    pixels is a twitch, not a flutter, and it cuts the stay short (butterflies only)."""
    if min_gap > 0 and len(plan) > 1:
        kept = []
        for v in plan:
            if kept and math.dist(bloom_near(*kept[-1][:2]), bloom_near(*v[:2])) < min_gap:
                continue
            kept.append(v)
        while len(kept) > 1 and math.dist(bloom_near(*kept[-1][:2]), bloom_near(*kept[0][:2])) < min_gap:
            kept.pop()
        plan = kept
    legs = []
    for k, (group, near, stay, land) in enumerate(plan):
        a = bloom_near(group, near)
        g2, n2 = plan[(k + 1) % len(plan)][:2]
        b = bloom_near(g2, n2)
        legs.append(("stay", a, stay, land))
        legs.append(("fly", a, math.dist(a, b) / speed + 0.35, b))
    return legs


def _on_legs(legs, t):
    total = sum(l[2] for l in legs)
    tt = t % total
    for leg in legs:
        if tt < leg[2]:
            return leg, tt / leg[2]
        tt -= leg[2]
    return legs[-1], 1.0


def _bee_at(b, t):
    off, plan = BEES[b]
    leg, s = _on_legs(_legs(plan, BEE_SPEED), t + off)
    seed = b * 7.3 + 1.1
    a = t * (2.2 + math.fmod(seed, 1.3)) + seed
    if leg[0] == "stay":
        fx, fy = leg[1]
        k = 1.0                                  # 1 circling, 0 sat on the bloom
        if leg[3]:
            lo, hi = BEE_LAND
            if lo <= s <= hi:
                return fx, fy - 1, 0, True
            k = min(1.0, (lo - s) / 0.18) if s < lo else min(1.0, (s - hi) / 0.18)
        rx = 5.0 + math.fmod(seed, 5.0)
        ry = 3.0 + math.fmod(seed * 1.7, 3.0)
        x = fx + (math.cos(a) * rx + math.sin(a * 2.3) * 2.0) * k
        y = fy - 1 + (math.sin(a * 1.6) * ry - 1.0) * k
        return x, y, (1 if math.sin(a) >= 0 else -1), False
    (ax, ay), (bx, by) = leg[1], leg[3]
    x = ax + (bx - ax) * s + math.sin(s * math.pi * 3 + seed) * 3.0
    y = ay + (by - ay) * s - math.sin(s * math.pi) * 7.0 + math.sin(t * 9 + seed) * 1.0
    return x, y, (1 if bx >= ax else -1), False


# The Decorate shelf stands right of the room (its title plank from y 52, x 422 on): nothing in
# the air may cross it, or it would be drawn over the menu. A flier's middle that strays past
# SHELF_X while level with the shelf is folded back (mirrored about the line), which keeps the
# motion smooth; the sprite's own half-width is allowed for.
SHELF_X = 421             # the first column the shelf's wood may stand in, less one
SHELF_TOP, SHELF_FOOT = 46, 311


def off_shelf(x, y, half):
    lim = SHELF_X - half
    if SHELF_TOP <= y <= SHELF_FOOT and x > lim:
        return lim - (x - lim)
    return x


def _wing_beat(t, b):
    """The wings' flick on a fixed clock (16 Hz, the parity of a 16 fps tick), not the mock's
    frame rate: in the game at 60 fps it stays a flick, not a shimmer."""
    return (int(base.Ctx.step(t, 16) * 16) + b) % 2


def _on_foliage(under, x, y):
    """True where veg.py has drawn leaves under the bee (a green pixel in `under`)."""
    if under is None or not (0 <= x < under.width and 0 <= y < under.height):
        return False
    r, g, bb, a = under.getpixel((int(x), int(y)))
    return a > 0 and g > r + 8 and g > bb


def draw_bee(over, x, y, way, landed, t, b, under=None):
    """Two yellow pixels and the dark band trailing the way it flies: one pixel longer than
    the lake's bee, because the house is drawn one size finer (a source pixel is 3 screen px,
    a lake art pixel about 4) and a bee in a rose bush has to read. The yellow is unbroken so
    over the dark lake it is still one body, not two specks. Flying, both wings flick over it
    every other frame; sat on a bloom they lie folded, one pale pixel."""
    x, y = math.floor(off_shelf(x, y, 1)), math.floor(y)
    way = way or 1
    # Over the ivy the dark band is lost in the leaves' own darks: there it is ink, and a wing
    # pixel always shows (the flick moves it rather than taking it away), so the bee still reads
    # as body, band and wing and not as a yellow dash.
    leafy = any(_on_foliage(under, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0))
    put(over, x + way, y, BEE_BODY)
    put(over, x, y, BEE_BODY)
    put(over, x - way, y, base.INK if leafy else BEE_BAND)
    beat = _wing_beat(t, b)
    if leafy:
        if landed or beat == 0:
            put(over, x, y - 1, WHITE[1])
        else:
            put(over, x - way, y - 1, WHITE[1])
    elif landed:
        put(over, x, y - 1, BEE_WING, BEE_WING_A)
    elif beat == 0:
        put(over, x, y - 1, BEE_WING, BEE_WING_A)
        put(over, x - way, y - 1, BEE_WING, BEE_WING_A)


def draw_bees(over, t, under=None):
    for b in range(len(BEES)):
        draw_bee(over, *_bee_at(b, t), t, b, under=under)


# ======================================================================== butterflies

# Two pastels, the cosy hut's: a brimstone lemon and a sky blue, a lit forewing over a
# shaded hindwing, each wing's outer tip a step darker, and an INK body (the furniture's
# outline colour) so the silhouette reads over the lake and over the cream paper alike.
BUTTER = [
    {"wing": YELLOW[2], "hind": YELLOW[1], "edge": YELLOW[0], "body": base.INK},
    {"wing": BLUE[2], "hind": BLUE[1], "edge": BLUE[0], "body": base.INK},
]


# Frames on the stepped clock, as (dx, dy, part) round the body: w forewing, e its darker
# outer tip, s hindwing, b body. Seen from above, seven across: open is a 3x2 forewing each
# side, notched at its outer foot (three over two), over a smaller 2x1 hindwing, and a 1x2
# body between them; lifting, the wings rise and narrow; shut, they stand up together over
# the body. The 1x2 body shows in every frame.
def _sprite(rows):
    return [(i - 3, j - 1, ch) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch in "wesb"]


_OPEN = _sprite(["eww.wwe", ".wwbww.", ".ssbss."])
_HALF = _sprite([".ew.we.", "..wbw..", "..sbs.."])
_SHUT = _sprite(["...e...", "..wbw..", "...b..."])
FLAP = [_OPEN, _HALF, _SHUT, _HALF]            # flying: a lazy flap, two beats a second
PERCH = [_OPEN] * 9 + [_HALF, _SHUT, _SHUT, _SHUT, _HALF]   # perched: open, now and then a slow close
BUTTER_SPEED = 20.0
BUTTER_GAP = 16.0          # a butterfly never hops between blooms closer than this
# Residents: (colour, seconds into its loop at t 0, [(kind, near, seconds perched)]).
BUTTERFLIES = [
    (0, 0.8, [("pinkish", (124, 55), 3.4), ("yellow", (162, 55), 2.6), ("daisy", (197, 55), 3.0),
              ("pinkish", (217, 56), 2.4)]),
    (1, 1.2, [("daisy", (86, 181), 3.6), ("daisy", (86, 145), 2.6), ("vase", (135, 134), 3.2),
              ("daisy", (87, 212), 2.8)]),
]
# The visitor: (colour, its period, when it first comes, its blooms, in from, out to): in off
# the lake under the sill, round the sill's blooms, and away again under the sill, never
# across the Decorate shelf (x <= 420 the whole way).
VISITOR = (0, 30.0, 3.2, [("rose", (409, 305), 3.0), ("yellow", (380, 306), 2.6),
                         ("pinkish", (343, 303), 2.8)], (400, 345), (420, 352))


def _perch_at(at):
    """Sat on a bloom: the body's tail on its top petal, so the flower shows under the wings."""
    return at[0], at[1] - 2


def _fly_between(a, b, s, t, seed):
    """A flutter from a to b: a bowed path, a bob with the flap, never a straight line. The
    side wiggle scales with the leg: a short one drifts, a long one flutters (about 1.2
    swings a second of flight), so a hop never zig-zags a pixel or two every frame."""
    (ax, ay), (bx, by) = a, b
    d = max(1.0, math.dist((ax, ay), (bx, by)))
    nx, ny = -(by - ay) / d, (bx - ax) / d
    bulge = math.sin(s * math.pi) * min(22.0, d * 0.3) * (1 if seed % 2 else -1)
    secs = d / BUTTER_SPEED + 0.35
    wig = 2.0 * min(1.0, d / 30.0)
    cycles = max(1, round(secs * 1.2))
    x = ax + (bx - ax) * s + nx * bulge + math.sin(s * math.pi * 2 * cycles + seed) * wig
    y = ay + (by - ay) * s + ny * bulge - math.sin(s * math.pi) * 6.0 + math.sin(t * 7.5 + seed) * 1.5
    return x, y


def _butter_at(n, t):
    colour, off, plan = BUTTERFLIES[n]
    legs = _legs([(g, at, stay, True) for g, at, stay in _plan_here(plan)], BUTTER_SPEED, BUTTER_GAP)
    leg, s = _on_legs(legs, t + off)
    if leg[0] == "stay":
        return _perch_at(leg[1]) + (True,)
    return _fly_between(_perch_at(leg[1]), _perch_at(leg[3]), s, t, n) + (False,)


def _visitor_at(t):
    colour, period, start, plan, come, go = VISITOR
    tt = (t - start) % period
    legs = _legs([(g, at, stay, True) for g, at, stay in plan], BUTTER_SPEED, BUTTER_GAP)
    first, last = _perch_at(legs[0][1]), _perch_at(legs[-2][1])
    t_in = math.dist(come, first) / BUTTER_SPEED
    body = sum(l[2] for l in legs[:-1])          # all but the flight back to the first bloom
    t_out = math.dist(last, go) / BUTTER_SPEED
    if tt < t_in:
        return _fly_between(come, first, tt / t_in, t, 3) + (False,)
    tt -= t_in
    if tt < body:
        leg, s = _on_legs(legs[:-1], tt)
        if leg[0] == "stay":
            return _perch_at(leg[1]) + (True,)
        return _fly_between(_perch_at(leg[1]), _perch_at(leg[3]), s, t, 3) + (False,)
    tt -= body
    if tt < t_out:
        return _fly_between(last, go, tt / t_out, t, 4) + (False,)
    return None


SUN_LIT = (255, 244, 214)   # a flier crossing the window's shaft catches it: a step towards this
LIT_FROM = 0.45             # shaft strength
FLY_HIGH = 9                # px a flier over the boards is above its shadow, on screen
SHADOW_INK = (24, 18, 17)   # base.INK
SHADOW_A = 64


def draw_butterfly(over, x, y, colour, perched, t, seed=0, under=None):
    tick = math.floor(t * 8) + seed
    frame = PERCH[tick % len(PERCH)] if perched else FLAP[tick % len(FLAP)]
    c = BUTTER[colour]
    x, y = math.floor(off_shelf(x, y, 3)), math.floor(y)
    wing, hind, edge = c["wing"], c["hind"], c["edge"]
    if shaft_at(x, y + FLY_HIGH) >= LIT_FROM:
        wing, hind = base.mix(wing, SUN_LIT, 0.4), base.mix(hind, SUN_LIT, 0.3)
        edge = base.mix(edge, SUN_LIT, 0.25)
    look = {"w": wing, "e": edge, "s": hind, "b": c["body"]}
    if under is not None and not perched and _on_boards(x, y + FLY_HIGH):
        # Its shadow on the boards below it, as wide as its wings are open.
        span = {id(_OPEN): 3, id(_HALF): 2}.get(id(frame), 1)
        for dx in range(-span, span + 1):
            put(under, x + dx, y + FLY_HIGH, SHADOW_INK, SHADOW_A)
    for dx, dy, part in frame:
        put(over, x + dx, y + dy, look[part])


def _on_boards(x, y):
    return 91 <= x <= 412 and 95 <= y <= 296


def draw_butterflies(over, t, under=None):
    for n in range(len(BUTTERFLIES)):
        x, y, perched = _butter_at(n, t)
        draw_butterfly(over, x, y, BUTTERFLIES[n][0], perched, t, seed=n * 5, under=under)
    v = _visitor_at(t)
    if v:
        draw_butterfly(over, v[0], v[1], VISITOR[0], v[2], t, seed=11, under=under)


# ======================================================================== petals

PETAL_EVERY = 4.4          # seconds between petals, on average
PETAL_FALL = 9.0           # source px a second
PETAL_REST = 1.8           # seconds lying whole before it starts to go
PETAL_GO = 0.8             # seconds each step of going lasts
# (lit, dark) falling, in `over`; lying on the boards, in `under`, a step paler, because the
# room's dim goes over the boards and what lies on them (it does not over what is in the air).
PETAL_LOOK = {"pink": (PINK[2], PINK[1]), "rose_pink": (PINK[2], PINK[1]),
              "rose_red": (RED[2], RED[1])}
PETAL_LYING = {"pink": (PINK[3], PINK[2]), "rose_pink": (PINK[3], PINK[2]),
               "rose_red": (RED[2], PINK[2])}
# Pictures hang flat on the wall: a petal falls in front of them. Anything else standing at the
# wall's foot a petal would fall behind, so its blooms drop none.
FLAT_ON_WALL = ("decor_pk_landscape", "decor_pk_portrait")
WALL_LAND = (96, 110)      # where a petal off the top run lands: the boards at the wall's foot


def _petal_sources(ctx):
    """Blooms a petal may fall from: pink ones on the top run and the side runs (the sill's
    would fall on the lake), with somewhere visible to land."""
    out = []
    pieces = [p["rect"] for p in getattr(ctx, "pieces", []) if p["piece"] not in FLAT_ON_WALL]

    def hidden(x, y):
        return any(px - 1 <= x <= px + pw and py <= y < py + ph for px, py, pw, ph in pieces)
    for x, y, k in blooms(3):
        k = base_kind(k)
        if k not in PETAL_LOOK or y > 280:
            continue
        if y < 62 and 92 <= x <= 412:
            land, drift = (WALL_LAND[0] + WALL_LAND[1]) // 2, 0
        elif x < 92 and y >= 62:
            land, drift = y + 20, 7
        elif x > 412 and y >= 62:
            land, drift = y + 20, -7
        else:
            continue
        path = [(x + round(drift * i / 8), y + 2 + (land - y - 2) * i // 8) for i in range(9)]
        if any(hidden(px, py) or hidden(px + 1, py) for px, py in path):
            continue
        out.append((x, y, k, drift))
    return out


PETAL_SPREAD = 48          # the frame is cut in stretches this long, each as likely to drop one


def _petal_source(srcs, k):
    """Which bloom petal k falls from: a stretch of the frame first, then a bloom in it, so
    the door's crowd of roses does not drop every petal."""
    groups = {}
    for src in srcs:
        groups.setdefault((src[0] // PETAL_SPREAD, src[1] // PETAL_SPREAD), []).append(src)
    keys = sorted(groups)
    g = groups[keys[int(h(k, 2, 91) * len(keys)) % len(keys)]]
    return g[int(h(k, 9, 91) * len(g)) % len(g)]


def _petals(ctx, t, opened=None):
    """The petals alive at t: (x, y, look, landed, step, flat). `opened(src)` (the play-in)
    leaves out the petals off blooms not yet open."""
    srcs = _petal_sources(ctx)
    if not srcs:
        return []
    out = []
    life = 8.0 + PETAL_REST + 3 * PETAL_GO
    for k in range(int(math.floor((t - life) / PETAL_EVERY)) - 1, int(math.floor(t / PETAL_EVERY)) + 1):
        born = k * PETAL_EVERY + (h(k, 1, 91) - 0.5) * 2.0
        age = t - born
        if age < 0:
            continue
        sx, sy, kind, drift = _petal_source(srcs, k)
        if opened is not None and not opened((sx, sy)):
            continue
        land = (WALL_LAND[0] + int(h(k, 3, 91) * (WALL_LAND[1] - WALL_LAND[0]))) if sy < 62 \
            else min(IN_Y1 - 2, sy + 16 + int(h(k, 3, 91) * 10))
        drop = land - sy
        fall = drop / PETAL_FALL
        sway = 1.6 + h(k, 6, 91) * 1.4
        ph = h(k, 7, 91) * 6.3
        w = 2 * math.pi * (0.5 + h(k, 8, 91) * 0.3)
        if age < fall:
            s = age / fall
            x = sx + drift * s + math.sin(age * w + ph) * sway * min(1.0, age * 1.2)
            y = sy + 1 + drop * s
            # It tumbles: flat (two pixels) most of the time, edge-on (one) at the sway's turns.
            flat = abs(math.cos(age * w + ph)) > 0.45
            out.append((x, y, kind, False, 0, flat))
            continue
        rest = age - fall
        x = min(IN_X1 - 2, max(IN_X0 + 1, sx + drift + math.sin(fall * w + ph) * sway))
        step = 0 if rest < PETAL_REST else 1 + int((rest - PETAL_REST) / PETAL_GO)
        if step > 2:
            continue
        out.append((x, land, kind, True, step, True))
    return out


def draw_petals(under, over, ctx, t, opened=None):
    """Falling, in `over` (in the air, in front of the wall and the pictures on it); lying on
    the boards, in `under` (beneath anything that stands or walks there)."""
    for x, y, kind, landed, step, flat in _petals(ctx, t, opened):
        x, y = math.floor(x), math.floor(y)
        if not landed:
            lit, dark = PETAL_LOOK[kind]
            if flat:
                put(over, x, y, lit)
                put(over, x + 1, y, dark)
            else:
                put(over, x, y, dark)
            continue
        # Lying, then going a step at a time: whole, see-through, one pixel, gone.
        lit, dark = PETAL_LYING[kind]
        if step == 0:
            put(under, x, y, lit)
            put(under, x + 1, y, dark)
        elif step == 1:
            put(under, x, y, lit, 150)
            put(under, x + 1, y, dark, 150)
        else:
            put(under, x, y, dark, 110)


# ======================================================================== the stages

# In a shower the window's shaft thins to RAIN_SUN of itself (shed_room.gd): the veil closes
# over it a step (rainy), and half the motes it lit go, the rest a step dimmer.
RAIN_SUN = 0.25


def rainy(alphas, rain):
    """A shower takes the beam one step down: its core to the margin's veil, its margin to
    the room's. The room and the shade side were never lit by it and do not move."""
    if alphas is None or rain <= 0:
        return alphas
    k = min(1.0, rain)
    a0, a1, a2, a3 = alphas
    return (a0 + (a1 - a0) * k, a1 + (a2 - a1) * k, a2, a3)


def draw(stage, t, ctx, under, over):
    rain = getattr(ctx, "rain", 0.0)
    draw_veil(over, stage, rainy(VEIL_ALPHA.get(stage), rain))
    # A shower: half the dust in the beam, each speck a step dimmer (the shaft itself is a step
    # down under the veil, above). Halving keeps the first motes, so nothing jumps.
    n = MOTES[stage] if rain <= 0 else max(1, round(MOTES[stage] * (1 - 0.5 * rain)))
    draw_motes(over, t, n, ctx=ctx, dim=1 if rain >= 0.5 else 0)
    if stage == 1 and rain < 0.5:
        draw_slit_motes(over, ctx, t)
    if stage == 3:
        find_indoor(ctx)
        draw_petals(under, over, ctx, t)
        draw_bees(over, t, under)
        draw_butterflies(over, t, under)


def _stepped(p, a, b, steps=3):
    """p 0..1 across a..b, in `steps` hard steps."""
    q = min(1.0, max(0.0, (p - a) / (b - a)))
    return math.floor(q * steps + 1e-9) / steps


def _settling(p, lo, hi, a, b):
    """For a stage-up: motes past the first `lo` settle out one by one between p a..b, each
    going in three steps."""
    def gone(i):
        if i < lo:
            return 1.0
        when = a + (b - a) * (i - lo) / max(1, hi - lo)
        return 1.0 - _stepped(p, when, when + 0.15, 3)
    return gone


# The play-in, 2 -> 3: each resident butterfly comes in off the lake (from these points, on
# the lake beside the room) as the first blooms open, and the bees follow from these sides.
# Every flier homes on where stage 3 will have it at that moment, so at p = 1 the play-in is
# draw(3) exactly and nothing pops when it hands over.
ARRIVE_FROM = [(50.0, 46.0), (40.0, 150.0)]
ARRIVE_START = [0.1, 0.22]
BEES_IN_FROM = {"left": (40.0, 90.0), "right": (418.0, 20.0), "low": (400.0, 345.0)}


def stage_up(frm, p, ctx, under, over):
    t = getattr(ctx, "t", 0.0)
    find_indoor(ctx)
    # The veil's edges move out from the window, sweep by sweep (never its alpha all at once).
    v = up_veil(frm, int(math.floor(p * 16 + 1e-9)))
    if v is not None:
        over.alpha_composite(v)
    if frm == 1:
        # The extra dust settles out of the shaft, mote by mote.
        draw_motes(over, t, MOTES[1], _settling(p, MOTES[2], MOTES[1], 0.2, 0.8), ctx=ctx)
        return
    draw_motes(over, t, MOTES[2], _settling(p, MOTES[3], MOTES[2], 0.15, 0.65), ctx=ctx)
    # Petals start falling off a bloom once veg.py has opened it.
    draw_petals(under, over, ctx, t, opened=lambda src: p >= bloom_open_at((src[0], src[1])))
    for n in range(len(BUTTERFLIES)):
        colour, off, plan = BUTTERFLIES[n]
        plan = _plan_here(plan)
        first = bloom_near(plan[0][0], plan[0][1])
        land_at = max(0.85, min(0.95, bloom_open_at(first) + 0.1))
        q = (p - ARRIVE_START[n]) / (land_at - ARRIVE_START[n])
        tx, ty, perched = _butter_at(n, t)
        if q >= 1:
            draw_butterfly(over, tx, ty, colour, perched, t, seed=n * 5, under=under)
        elif q > 0:
            # In low over the lake and the frame, slowing as it comes, bobbing with every flap.
            e = 1 - (1 - q) ** 1.6
            fx, fy = ARRIVE_FROM[n]
            x = fx + (tx - fx) * e + math.sin(q * math.pi * 3) * 2.0
            y = fy + (ty - fy) * e - math.sin(q * math.pi) * 7.0 + math.sin(t * 7.5) * 1.5 * (1 - e)
            draw_butterfly(over, x, y, colour, False, t, seed=n * 5, under=under)
    if p >= 1:
        vis = _visitor_at(t)
        if vis:
            draw_butterfly(over, vis[0], vis[1], VISITOR[0], vis[2], t, seed=11, under=under)
    # The bees follow it in, one by one, each homing on where its loop has it.
    for b, (boff, bplan) in enumerate(BEES):
        at = bloom_near(bplan[0][0], bplan[0][1])
        side = "low" if at[1] > 200 else ("left" if at[0] < 250 else "right")
        start = 0.5 + 0.1 * b
        q = (p - start) / max(1e-6, min(0.38, 1.0 - start))
        if q <= 0:
            continue
        bx, by, bway, blanded = _bee_at(b, t)
        if q >= 1:
            draw_bee(over, bx, by, bway, blanded, t, b, under=under)
            continue
        e = 1 - (1 - q) ** 2
        ox, oy = BEES_IN_FROM[side]
        x = ox + (bx - ox) * e + math.sin(t * 9 + b) * 2.0 * (1 - q)
        y = oy + (by - oy) * e - math.sin(q * math.pi) * 8.0
        draw_bee(over, x, y, 1 if bx >= ox else -1, False, t, b, under=under)


CLOSEUPS = [
    ("life_shaft", 1, (88, 160, 150, 84)),        # the dim room, the shaft, its motes
    ("life_slits", 1, (360, 236, 60, 66)),        # the low corner's daylight slits through the veil
    ("life_shaft_s2", 2, (88, 160, 150, 84)),     # stage 2: the veil a step lighter, fewer motes
    ("life_bee", 3, (248, 40, 40, 28)),           # a bee sat on a rose over the door
    ("life_butterfly", 3, (104, 38, 48, 30)),     # the lemon butterfly on its bloom
]

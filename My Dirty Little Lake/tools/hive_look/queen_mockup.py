#!/usr/bin/env python
"""The queen sheet (2026-10-16, the hive's visual overhaul; second round 2026-10-17 after the
art director's review): three compositions for the "find the queen" step, A / B / C.

OFFLINE MOCKUP ONLY. Writes tools/hive_look/last_queen.png. Every option is drawn on the real
capture's own lattice (the room: 3 screen px an art px, a 640 x 360 art grid) with the game's
own pieces where they exist (the brood frame and its comb from build_hive, the clean backdrop
off the catch plate re-laid from assets/wash_bank.png and wash_lawn.png, the HUD's plaque, card
and cross pasted back from the queen plate) and the hive look's round coin bee and its queen
(look.py variant "R", the bee sheet's A reworked after this sheet's review). The magnifying
glass is the step's own glass laid out from scripts/hive_step_queen.gd (ZOOM 2, the brass rim,
the wooden handle), its radius grown from the step's LENS_R 33 to 44 art px so her court fits
in the glass with her. Every option is shown twice: while the player is still searching (the
glass elsewhere, no payoff), and the moment she is found (the gold rays fanning out from
behind the glass, stepped gold halo rings, four-point stars round the rim).

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/queen_mockup.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
import backdrop_mockup as bd  # noqa: E402
from look import zoom, panel, stack  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

bh = look.bh
G = look.ROOM_GRAIN                  # 3 screen px an art px
W, H = look.ROOM_GRID                # 640 x 360 art px
SCREEN = (W * G, H * G)
V = "R"                              # look's round coin bee (the bee sheet's A, reworked)
OUT_PATH = os.path.join(look.HERE, "last_queen.png")
RECOMMEND = "B"

OUT = look.OUT
SW = look.SW
PINE, PINE_LIT, PINE_SHADE, PINE_DEEP = bh.PINE, bh.PINE_LIT, bh.PINE_SHADE, bh.PINE_DEEP
PAINT = bh.PAINTS["sky"]             # the hive's sky-blue paint: lit, base, shade, deep
WELL_DARK, WELL_DEEPER = bh.WELL_DARK, bh.WELL_DEEPER
WAX, WAX_LIT, WAX_SHADE, WAX_WALL = bh.WAX, bh.WAX_LIT, bh.WAX_SHADE, bh.WAX_WALL
HONEY, HONEY_MID, HONEY_DEEP = bh.HONEY, bh.HONEY_MID, bh.HONEY_DEEP
HONEY_LIGHT, HONEY_SHINE = bh.HONEY_LIGHT, bh.HONEY_SHINE
STAR_WHITE = (255, 247, 217, 255)    # HiveArt.STAR_WHITE
SHADE_INK = OUT[:3] + (96,)          # a contact shadow: the outline ink, the game's way

# The HUD the room draws over every step, pasted back from the queen plate (screen px). The
# plaque's foot is screen row 117 (art row 39): every frame's top bar starts below it.
HUD_PLAQUE = (756, 3, 1164, 117)
HUD_CROSS = (1826, 18, 1894, 65)
HUD_CARD = (768, 950, 1155, 1042)
FRAME_TOP = 42


# =============================================================================================
# The backdrop: no rubbish, no ferry, no dog (Richard's call for the room).
# =============================================================================================
_backdrop = None
VEIL = 0.6                           # the backdrop sheet's recommended veil (its option B)


def backdrop():
    global _backdrop
    if _backdrop is None:
        view, _work, _ink = bd.clean_view("catch", bd.STATES_SHOWN["catch"], VEIL)
        _backdrop = view.convert("RGBA")
    return _backdrop.copy()


def bed_into(art_im, layout):
    """The backdrop sheet's bed (bd.bed_layer: real flora.png pack pieces composited back to
    front by their feet, ringed in the game's outline, open at the foot) laid into an option's
    1x art, with its contact shade one art row under each column, one px right."""
    layer = bd.bed_layer(layout)[0]
    a = np.array(layer)[..., 3] > 0
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = shade.load()
    for x in range(W - 1):
        col = np.nonzero(a[:H, x])[0]
        if len(col) and col.max() + 1 < H:
            px[x + 1, int(col.max()) + 1] = OUT[:3] + (84,)
    art_im.alpha_composite(shade)
    art_im.alpha_composite(layer.crop((0, 0, W, H)))
    return layer


def showing(layer, art_im):
    la = np.array(layer.crop((0, 0, W, H)))
    fa = np.array(art_im)
    return [(x, y) for x, y in bd.top_heads(layer) if y < H and (la[y, x] == fa[y, x]).all()]


def rows_of(rng, rows):
    """A bed out of rows: each (foot y, x from, x to, step, pool, jitter) lays a pack piece
    every `step` art px with a little jitter, never the same piece as its neighbour."""
    out = []
    for fy, x0, x1, step, pool, jit in rows:
        x = x0 + rng.uniform(0, step * 0.5)
        last = None
        while x < x1:
            name = rng.choice([p for p in pool if p != last] or pool)
            out.append((name, int(x + rng.uniform(-jit, jit)), fy + rng.randint(-2, 2)))
            last = name
            x += step
    return out


# The pack's flower heads (assets/flora.json), for the lawn between the rest's legs.
ROUND_HEADS = ["pk_flower_%d" % i for i in range(8)]
SMALL_HEADS = ["pk_flower_%d" % i for i in (10, 11, 14, 15)] + ["clover_white", "clover_pink"]
CARD_ART = (252, 314, 388, 350)       # the prompt card's art box: no bee under it


def bed_bees(img, room, spots, plan=(("hover", 3), ("rest", 2), ("fly", 1)), seed=5):
    """Bees at the bed, on the 1x art: the bed's width cut into as many bins as there are bees,
    each bee working a head in its own bin: hovering beside it and facing it (its pale wings
    up), resting on it, or flying a little way over the bed. Kept a pixel clear of every bee
    already laid (`room`) and off the prompt card."""
    rng = random.Random(seed)
    spots = [s for s in spots if not (CARD_ART[0] - 8 <= s[0] <= CARD_ART[2] + 8 and s[1] > CARD_ART[1] - 8)]
    for part in ([s for s in spots if s[0] < W // 2], [s for s in spots if s[0] >= W // 2]):
        if not part:
            continue
        poses = [p for p, n in plan for _ in range(n)]
        rng.shuffle(poses)
        x0 = min(s[0] for s in part)
        x1 = max(s[0] for s in part) + 1
        poses = poses[:max(1, (x1 - x0) // 18)]
        n = len(poses)
        for i, pose in enumerate(poses):
            lo, hi = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
            cand = [s for s in part if lo <= s[0] < hi] or part
            for attempt in range(80):
                sx, sy = rng.choice(cand)
                left = rng.random() < 0.5
                if pose == "rest":
                    bx, by, p_, fr = sx, sy - 3, "rest", rng.randrange(3)
                elif pose == "hover":
                    bx, by = sx + (7 if left else -7), sy - rng.randint(3, 6)
                    p_, fr = "hover", 0
                else:
                    bx, by = sx + rng.randint(-6, 6), sy - rng.randint(12, 20)
                    p_, fr = "fly", rng.choice((0, 3))
                if by > H - 6 or not (0 <= bx < W):
                    continue
                if try_bee(room, bx, by, p_, left, 0, fr):
                    put_bee(img, bx, by, p_, left, 0, fr, room=room)
                    break


# =============================================================================================
# Drawing helpers (1x art)
# =============================================================================================
def darker(c, t):
    return look.mix(c, OUT, t)


def mul(c, f):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f), c[3] if len(c) > 3 else 255)


# Each cell steps down its OWN ramp in the dark of the box (the review: a flat veil turned the
# honey to dull ochre). Unknown colours (pollen, the cell walls' dark) fall back to the outline
# ink a step at a time.
RAMPS = [
    [HONEY_SHINE, HONEY_LIGHT, HONEY, HONEY_MID, HONEY_DEEP, darker(HONEY_DEEP, 0.3), darker(HONEY_DEEP, 0.55)],
    [WAX_LIT, WAX, WAX_SHADE, WAX_WALL, darker(WAX_WALL, 0.3), darker(WAX_WALL, 0.55)],
    [bh.BROOD_LIT, bh.BROOD, bh.BROOD_SHADE, darker(bh.BROOD_SHADE, 0.3), darker(bh.BROOD_SHADE, 0.55)],
    [PINE_LIT, PINE, PINE_SHADE, PINE_DEEP, darker(PINE_DEEP, 0.35), darker(PINE_DEEP, 0.6)],
]
_RAMP_AT = {}
for _r in RAMPS:
    for _i, _c in enumerate(_r):
        _RAMP_AT.setdefault(_c[:3], (_r, _i))


def step_down(c, n):
    if n <= 0:
        return c
    hit = _RAMP_AT.get(c[:3])
    if hit:
        r, i = hit
        return r[min(i + n, len(r) - 1)][:3] + (c[3],)
    return look.mix(c, OUT, min(0.17 * n, 0.7))[:3] + (c[3],)


def stepped(im, steps_at):
    """Every opaque pixel stepped down its ramp by steps_at(x, y) (an int)."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3]:
                n = steps_at(x, y)
                if n:
                    px[x, y] = step_down(p, n)
    return out


def comb_glints(im, every=0.22, seed=4):
    """The comb draws one shine pixel in the middle of every honey cell (read as a grid of
    rivets in the dark of the box). Take them all back to honey, then give about one honey cell
    in four or five a glint: two pixels of the honey ramp's light step at the cell's top left.
    Returns the glints' spots, so they can be stepped one less than the comb round them."""
    rng = random.Random(seed)
    px = im.load()
    spots = []
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] and px[x, y][:3] == HONEY_SHINE[:3]:
                px[x, y] = HONEY
                if rng.random() < every:
                    spots += [(x, y), (x + 1, y)]
    return spots


def star(img, x, y, arm):
    """HiveArt.star on whole art px, solid: a white middle, the first arm pixel pale gold, the
    rest gold."""
    d = ImageDraw.Draw(img, "RGBA")
    d.point((x, y), fill=STAR_WHITE)
    for k in range(1, arm + 1):
        ink = SW["gold_pale"] if k == 1 else SW["gold"]
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            d.point((x + dx, y + dy), fill=ink)


# --- bees, placed so no two outlines touch -------------------------------------------------------
def _rot(xy, size, turn):
    x, y = xy
    for _ in range(turn % 4):
        x, y = y, size[0] - 1 - x
    return x, y


_SPRITES = {}


def _grown(a):
    """The mask grown one px (8-neighbour): an outline must not touch another's."""
    p = np.pad(a, 1)
    g = np.zeros_like(p)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            g |= np.roll(np.roll(p, dy, 0), dx, 1)
    return g[1:-1, 1:-1]


def bee_sprite(pose, left, turn, frame):
    k = (pose, left, turn, frame % 6)
    if k not in _SPRITES:
        b = look.bee(V, frame, facing_left=left, pose=pose, turn=turn)
        ax, ay = _rot(look.bee_anchor(V, pose, left, frame), look.BEE_CANVAS, turn)
        a = np.array(b)[..., 3] > 0
        _SPRITES[k] = (b, (ax, ay), a, _grown(a))
    return _SPRITES[k]


class Room:
    """What is taken on the art grid by the bees laid so far (their drawn silhouettes)."""
    PAD = 24

    def __init__(self):
        self.occ = np.zeros((H + 2 * self.PAD, W + 2 * self.PAD), bool)

    def _sl(self, a, ox, oy):
        p = self.PAD
        return self.occ[oy + p:oy + p + a.shape[0], ox + p:ox + p + a.shape[1]]

    def fits(self, grown, ox, oy):
        if not (-self.PAD < ox < W and -self.PAD < oy < H):
            return False
        return not (self._sl(grown, ox, oy) & grown).any()

    def add(self, a, ox, oy):
        s = self._sl(a, ox, oy)
        s |= a


def put_sprite(img, im, at, shadow=False):
    if shadow:
        a = np.array(im)
        sh = np.zeros_like(a)
        sh[a[..., 3] > 0] = SHADE_INK
        img.alpha_composite(Image.fromarray(sh), (at[0] + 1, at[1] + 1))
    img.alpha_composite(im, at)


def put_bee(img, x, y, pose="walk", left=False, turn=0, frame=0, tint=0, shadow=False, room=None):
    """A bee with its body's middle on art (x, y). tint: steps down its ramp (depth)."""
    b, (ax, ay), a, g = bee_sprite(pose, left, turn, frame)
    ox, oy = int(round(x - ax)), int(round(y - ay))
    if room is not None:
        room.add(a, ox, oy)
    if tint:
        b = stepped(b, lambda *_: tint)
    put_sprite(img, b, (ox, oy), shadow)


def try_bee(room, x, y, pose, left, turn, frame):
    b, (ax, ay), a, g = bee_sprite(pose, left, turn, frame)
    ox, oy = int(round(x - ax)), int(round(y - ay))
    return room.fits(g, ox, oy)


def put_queen(img, x, y, left=False, laying=False, frame=0, room=None):
    q = look.queen(V, frame, laying=laying, facing_left=left)
    ax, ay = look.queen_anchor(V, left)
    ox, oy = int(round(x - ax)), int(round(y - ay))
    if room is not None:
        room.add(np.array(q)[..., 3] > 0, ox, oy)
    img.alpha_composite(q, (ox, oy))


def queen_fits(room, x, y, left):
    q = look.queen(V, 0, facing_left=left)
    ax, ay = look.queen_anchor(V, left)
    return room.fits(_grown(np.array(q)[..., 3] > 0), int(round(x - ax)), int(round(y - ay)))


def crowd(room, rect, n, seed, density=None, inside=None):
    """Up to n workers over rect (art px), each one's outline a pixel clear of every other
    silhouette laid so far (bees, the queen, her court). Thicker where density(x, y) is high.
    Returns (x, y, pose, left, turn, frame) sorted by y, already claimed in `room`."""
    rng = random.Random(seed)
    out = []
    tries = 0
    while len(out) < n and tries < n * 400:
        tries += 1
        x = rng.uniform(rect[0], rect[2])
        y = rng.uniform(rect[1], rect[3])
        if density is not None and rng.random() > density(x, y):
            continue
        if inside is not None and not inside(x, y):
            continue
        r = rng.random()
        if r < 0.56:
            pose, turn = "walk", 0
        elif r < 0.66:
            pose, turn = "walk", rng.choice((1, 3))
        elif r < 0.9:
            pose, turn = "rest", 0
        else:
            pose, turn = "hover", 0
        left = rng.random() < 0.5
        frame = rng.randrange(6)
        if try_bee(room, x, y, pose, left, turn, frame):
            b, (ax, ay), a, g = bee_sprite(pose, left, turn, frame)
            room.add(a, int(round(x - ax)), int(round(y - ay)))
            out.append((x, y, pose, left, turn, frame))
    out.sort(key=lambda t: t[1])
    return out


def draw_crowd(img, bees, tint=0):
    for x, y, pose, left, turn, f in bees:
        put_bee(img, x, y, pose, left, turn, f, tint)


COURT_ANGLES = (0, 50, 130, 180, 230, 310)   # degrees round her; none over her crown


def court(room, qx, qy, left):
    """Her court: workers in a loose ring, every one facing her, each pushed out from her until
    its outline clears hers and its neighbours'."""
    out = []
    for k, deg in enumerate(COURT_ANGLES):
        a = math.radians(deg if not left else 180 - deg)
        for grow in range(0, 14):
            rx, ry = 15.0 + grow, 8.5 + grow * 0.6
            x, y = qx + math.cos(a) * rx, qy + math.sin(a) * ry
            dx, dy = qx - x, qy - y
            if abs(dx) >= abs(dy) * 1.1:
                pose = ("walk", dx < 0, 0, k)
            else:
                pose = ("walk", False, 1 if dy < 0 else 3, k)
            if try_bee(room, x, y, pose[0], pose[1], pose[2], pose[3]):
                b, (ax, ay), am, g = bee_sprite(*pose)
                room.add(am, int(round(x - ax)), int(round(y - ay)))
                out.append((x, y) + pose)
                break
    return out


def fliers(img, spots, seed=3, room=None):
    rng = random.Random(seed)
    for x, y, left in spots:
        put_bee(img, x, y, "fly", left, 0, rng.randrange(6), room=room)


def queen_and_court(img, room, q, left):
    """Lay her silhouette in the room first (so the crowd keeps off her), then her court."""
    qim = look.queen(V, 0, facing_left=left)
    ax, ay = look.queen_anchor(V, left)
    room.add(_grown(np.array(qim)[..., 3] > 0), int(round(q[0] - ax)), int(round(q[1] - ay)))
    return court(room, q[0], q[1], left)


# =============================================================================================
# The glass, laid out as scripts/hive_step_queen.gd lays it (art px round its middle)
# =============================================================================================
LENS_R = 44            # the step's 33, grown so her court fits in the glass with her
ZOOM = 2
BRASS_LIT, BRASS_BASE, BRASS_SHADE = (252, 222, 128, 255), (216, 166, 62, 255), (160, 112, 38, 255)
WOOD_HI, WOOD, WOOD_LO = (150, 110, 76, 255), (120, 84, 56, 255), (90, 60, 40, 255)
RAYS = 12
RAY_REACH = (26, 54)   # art px past the halo
HANDLE_ANGLE = 45      # degrees (screen, y down): the handle runs off down and to the right


def _lens_maps():
    r = float(LENS_R)
    disc, rim, sheen, handle = [], {}, {}, {}
    for y in range(-LENS_R - 11, LENS_R + 12):
        for x in range(-LENS_R - 11, LENS_R + 12):
            q = math.sqrt(x * x + y * y)
            lean = (-x - y) / max(q, 1.0)
            if q <= r - 0.5:
                disc.append((x, y))
            if (r - 0.5 < q <= r + 0.5) or (r + 4.5 < q <= r + 5.5):
                rim[(x, y)] = OUT
            elif r + 0.5 < q <= r + 4.5:
                rim[(x, y)] = BRASS_LIT if lean > 0.45 else BRASS_SHADE if lean < -0.45 else BRASS_BASE
            # the glass's highlight: a stepped arc on the top left in the sky's own pale blue,
            # a foam line inside it at its brightest; solid swatches, no grey end cap
            if r - 8.5 < q <= r - 6.5 and lean > 0.82:
                sheen[(x, y)] = SW["sky_low"]
            elif r - 6.5 < q <= r - 5.5 and lean > 0.93:
                sheen[(x, y)] = SW["foam"]
    half = int(r * 0.5)
    rim[(-half, -half - 4)] = SW["foam"]
    along = (math.cos(math.pi / 4), math.sin(math.pi / 4))
    across = (-along[1], along[0])
    for y in range(0, LENS_R + 48):
        for x in range(0, LENS_R + 48):
            k = x * along[0] + y * along[1]
            w = x * across[0] + y * across[1]
            if abs(w) > 5.5 or k < r + 1.5 or k > r + 40.5:
                continue
            if abs(w) > 4.5 or k > r + 39.5:
                ink = OUT
            elif k < r + 10.0:
                ink = BRASS_LIT if w < -1.5 else (BRASS_BASE if w < 2.5 else BRASS_SHADE)
            else:
                ink = WOOD_HI if w < -1.5 else (WOOD if w < 2.5 else WOOD_LO)
            handle[(x, y)] = ink
    return disc, rim, sheen, handle


LENS = _lens_maps()


def _layer_of(pixels, centre):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = layer.load()
    cx, cy = centre
    for (x, y), c in pixels.items():
        if 0 <= cx + x < W and 0 <= cy + y < H:
            px[cx + x, cy + y] = c
    return layer


def _off_handle(deg, margin=24):
    d = (deg - HANDLE_ANGLE + 180) % 360 - 180
    return abs(d) > margin


def payoff_back(centre):
    """The found moment, behind the glass: gold rays fanning out all round it (a pale coin-cream
    core edged in gold, so they carry over honey as well as wax; solid on whole art px, their
    tips thinned by a 2 x 2 ordered dither) and a halo hugging the brass in three stepped rings
    (solid cream, then gold at a half dither, then gold at a quarter). No soft alpha anywhere."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    cx, cy = centre
    r0 = LENS_R + 6

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = c

    for k in range(RAYS):
        deg = -90 + 360.0 * (k + 0.5) / RAYS
        if not _off_handle(deg, 26):
            continue
        frac = (math.sin(k * 12.9898) * 43758.5453) % 1.0
        long_ = RAY_REACH[0] + (RAY_REACH[1] - RAY_REACH[0]) * frac
        a = math.radians(deg)
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        for s_ in range(int(long_ * 3)):
            d = s_ / 3.0
            u = d / long_
            half = 3.6 * (1 - u) + 0.4
            for wv in np.arange(-half, half + 0.01, 0.34):
                x = int(math.floor(cx + 0.5 + dx * (r0 + d) + nx * wv))
                y = int(math.floor(cy + 0.5 + dy * (r0 + d) + ny * wv))
                if u > 0.6 and (x + y) % 2:
                    continue          # the tip, thinned by the dither
                core = abs(wv) < half - 1.0
                put(x, y, SW["coin_pale"] if core else SW["gold"])
    for y in range(-LENS_R - 14, LENS_R + 15):
        for x in range(-LENS_R - 14, LENS_R + 15):
            q = math.hypot(x, y)
            deg = math.degrees(math.atan2(y, x))
            if not _off_handle(deg, 13):
                continue
            X, Y = cx + x, cy + y
            if LENS_R + 5.5 < q <= LENS_R + 7.5:
                put(X, Y, SW["coin_pale"])
            elif LENS_R + 7.5 < q <= LENS_R + 9.5 and (X + Y) % 2 == 0:
                put(X, Y, SW["gold_lit"])
            elif LENS_R + 9.5 < q <= LENS_R + 11.5 and X % 2 == 0 and Y % 2 == 0:
                put(X, Y, SW["gold"])
    return img


STAR_SPOTS = ((-150, 2, 3), (-112, 9, 2), (-70, 4, 3), (-24, 11, 1), (8, 6, 2), (70, 10, 2),
              (112, 4, 3), (156, 9, 1), (196, 5, 2))   # (degrees, px past the rim, arm)


def payoff_front(centre):
    """The stars twinkling round the rim, solid four-point stars on whole art px."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy = centre
    for deg, out, arm in STAR_SPOTS:
        a = math.radians(deg)
        rr = LENS_R + 3 + out
        star(img, int(round(cx + math.cos(a) * rr)), int(round(cy + math.sin(a) * rr)), arm)
    return img


def draw_lens(screen, scene1x, centre, found=True):
    """The glass at art px `centre` on the screen image (in place), magnifying scene1x twice
    about the corner of its middle cell, so every magnified pixel is two art px (6 screen px)
    and its edges fall on the room's 3 px lattice. The comb shows through untinted: what is
    in the glass is the comb outside it, bigger. found: the payoff behind and round it."""
    disc, rim, sheen, handle = LENS
    cx, cy = centre
    if found:
        screen.alpha_composite(zoom(payoff_back(centre), G))
    screen.alpha_composite(zoom(_layer_of(handle, centre), G))
    src = np.array(scene1x)
    big = np.zeros((H, W, 4), np.uint8)
    for x, y in disc:
        ax, ay = cx + x, cy + y
        if 0 <= ax < W and 0 <= ay < H:
            sx = cx + math.floor(x / ZOOM)
            sy = cy + math.floor(y / ZOOM)
            big[ay, ax] = src[min(max(sy, 0), H - 1), min(max(sx, 0), W - 1)]
            big[ay, ax, 3] = 255
    screen.alpha_composite(zoom(Image.fromarray(big), G))
    screen.alpha_composite(zoom(_layer_of(sheen, centre), G))
    screen.alpha_composite(zoom(_layer_of(rim, centre), G))
    if found:
        screen.alpha_composite(zoom(payoff_front(centre), G))


# =============================================================================================
# The HUD, pasted back
# =============================================================================================
def hud(screen):
    q = look.plate("queen")
    screen.paste(q.crop(HUD_PLAQUE), HUD_PLAQUE[:2])
    screen.paste(q.crop(HUD_CARD), HUD_CARD[:2])
    cross = q.crop(HUD_CROSS)
    a = np.array(cross)
    sky = (a[..., 2].astype(int) - a[..., 0] > 40) & (a[..., 2] > 170)
    a[sky, 3] = 0
    screen.alpha_composite(Image.fromarray(a), HUD_CROSS[:2])
    return screen


# =============================================================================================
# The pieces every option shares
# =============================================================================================
def brood(w, h, seed=5):
    """The step's own brood frame (build_hive.brood_frame) with the bigger cells: a cell about
    a bee's size reads as comb under her rather than as texture. Returns the picture and its
    comb's box in it. The picture is (w + 28) x (h + 4), its top bar's ears 12 px past the side
    bars on either end (the lugs)."""
    im = bh.brood_frame(w, h, seed=seed, cell=bh.CELL_BIG)
    return im, (21, 10, w + 7, h - 5)


def honey_kind(top_wax, honey_to):
    def kind_of(x, y, rng):
        if y < top_wax:
            return "wax" if rng.random() < 0.9 else "honey"
        if y < honey_to:
            r = rng.random()
            return "honey" if r < 0.72 else "fresh" if r < 0.86 else "pollen"
        r = rng.random()
        return "brood" if r < 0.55 else "pollen" if r < 0.75 else "empty"
    return kind_of


def bar(a, x0, x1, y, h, seed):
    """A frame's top bar: pine lit along its top, its front face shaded, propolis smudges."""
    rng = random.Random(seed)
    a.rect(x0, y, x1 - x0, h, PINE)
    a.rect(x0, y, x1 - x0, max(1, h // 4), PINE_LIT)
    a.rect(x0, y + h - max(1, h // 3), x1 - x0, max(1, h // 3), PINE_SHADE)
    a.rect(x0, y + h - 1, x1 - x0, 1, PINE_DEEP)
    for _ in range(int((x1 - x0) / 22)):
        x = rng.randint(int(x0) + 4, int(x1) - 10)
        a.rect(x, y + rng.randint(1, max(1, h - 3)), rng.randint(3, 7), 1, PINE_DEEP)


def gap(a, x0, x1, y0, y1, seed, honey=0.45):
    """The dark between two bars and, far down in it, the wax edge of the comb under them."""
    rng = random.Random(seed)
    a.rect(x0, y0, x1 - x0, y1 - y0, WELL_DEEPER)
    if y1 - y0 >= 4:
        y = y0 + (y1 - y0) // 2
        x = int(x0) + 2
        while x < int(x1) - 2:
            run = rng.randint(4, 14)
            col = bh.CELL_DEEP if rng.random() > honey else darker(HONEY_DEEP, 0.25)
            a.rect(x, y + (1 if rng.random() < 0.3 else 0), run, 1, col)
            if col != bh.CELL_DEEP and rng.random() < 0.18:
                a.px(x + run // 2, y, HONEY_MID)
            x += run + rng.randint(0, 3)


CAP = [".xxxx.", "xxxxxx", "xxxxxx", "xxxxxx", ".xxxx."]


def brace_ridge(img, x, top, bottom, cols=3):
    """Brace comb: a lump of capped cells the bees have built across the gap from one bar to
    the next, staggered like comb (`cols`, then one fewer, then `cols` again), each cap lit on
    its top left (the room's sun) with a wax wall between, the whole lump ringed in the dark
    outline and lapping two px onto both bars (top-2 .. bottom+2)."""
    pitch_x, pitch_y = 5, 4
    w = cols * pitch_x + 2
    h = 3 * pitch_y + 2
    a = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ap = a.load()
    for row in range(3):
        n = cols if row != 1 else cols - 1
        ox = 0 if row != 1 else pitch_x // 2 + 1
        for k in range(n):
            x0, y0 = ox + k * pitch_x, row * pitch_y
            for yy, line in enumerate(CAP):
                for xx, ch in enumerate(line):
                    if ch != "x" or not (0 <= x0 + xx < w and 0 <= y0 + yy < h):
                        continue
                    edge = (xx == 0 or yy == 0 or xx == len(line) - 1 or yy == len(CAP) - 1
                            or line[xx - 1] == "." or (xx + 1 < len(line) and line[xx + 1] == "."))
                    if edge:
                        c = WAX_WALL
                    elif xx <= 2 and yy <= 2 and (xx + yy) <= 3:
                        c = WAX_LIT
                    elif xx >= 4 or yy >= 3:
                        c = WAX_SHADE
                    else:
                        c = WAX
                    ap[x0 + xx, y0 + yy] = c
    lump = look.inked(a)
    img.alpha_composite(lump, (int(x - lump.width // 2), top - 3))


BEAD = [".hll.", "hllmm", "lmmmd", ".mdd."]


def honey_bead(img, x, y):
    """A glossy bead of honey lying ON a bar's top (y the bar's top row): lit on its top left
    (the room's sun), rounded, edged in honey's own deep tone, with a one-px shadow down and to
    the right on the pine."""
    px = img.load()
    ink = {"h": HONEY_SHINE, "l": HONEY_LIGHT, "m": HONEY, "d": HONEY_MID}

    def put(xx, yy, c):
        if 0 <= xx < img.width and 0 <= yy < img.height:
            px[xx, yy] = c

    for yy, line in enumerate(BEAD):
        for xx, ch in enumerate(line):
            if ch != ".":
                put(x + xx + 1, y + yy, PINE_DEEP)
    for yy, line in enumerate(BEAD):
        for xx, ch in enumerate(line):
            if ch != ".":
                put(x + xx, y + yy - 1, ink[ch])
    for xx in range(1, 4):
        put(x + xx, y + 3, HONEY_DEEP)


def peeker(img, x, bar_top, left=False, frame=0):
    """A bee peeping over a bar's front edge out of the dark behind it: resting, its folded
    wings, its eye and the top of its band above the edge, the rest hidden by the bar (drawn
    before the bar in front)."""
    b, (ax, ay), a, g = bee_sprite("rest", left, 0, frame)
    img.alpha_composite(b, (int(round(x - ax)), int(round(bar_top - 2 - ay))))


# =============================================================================================
# B: the well, deeper. Today's camera (down into the open box at a tilt), rebalanced.
# =============================================================================================
def b_inner(y):
    t = (y - 18) / float(H - 18)
    return 70 + (12 - 70) * t, 570 + (628 - 570) * t


B_FRAME_AT = (120, FRAME_TOP)
B_FRAME = (372, 232)
B_QUEEN = (262, 174)
B_SEARCH = (412, 128)
NEXT = (94, 546)          # the next frame back's outer edges (its end bars), art x


def b_wall(y):
    """The inner face of a side wall, art px wide at row y: wider towards the eye."""
    return 10 + int(22 * (y - 18) / float(H - 18))


def option_b():
    art = bh.Art(W, H)
    room = Room()
    fx, fy = B_FRAME_AT
    tipped, comb_box = brood(*B_FRAME)
    # the dark inside of the box
    for y in range(18, H):
        l, r = b_inner(y)
        art.rect(int(l), y, int(r - l) + 1, 1, WELL_DEEPER)
    # the back wall, its raw rim and the paint beyond
    l0, r0 = b_inner(18)
    art.rect(int(l0) - 34, 0, int(r0 - l0) + 68, 5, PAINT[1])
    art.rect(int(l0) - 34, 0, int(r0 - l0) + 68, 1, PAINT[0])
    art.rect(int(l0) - 34, 5, int(r0 - l0) + 68, 6, PINE)
    art.rect(int(l0) - 34, 5, int(r0 - l0) + 68, 2, PINE_LIT)
    art.rect(int(l0), 11, int(r0 - l0), 7, bh.DARK_WOOD_LO)
    # the frames further back: their top bars in a row, the comb's wax edge in the gaps
    for k, (y, h) in enumerate(((19, 2), (23, 3))):
        l, r = b_inner(y)
        gap(art, int(l) + b_wall(y), int(r) - b_wall(y), y - 2, y, 90 + k, honey=0.5)
        bar(art, int(l) + b_wall(y), int(r) - b_wall(y), y, h, 95 + k)
    # in the gap between the next frame and each wall, the face of the one behind it: comb
    # stepped three down its ramps, one more where the wall's shade falls (the left)
    behind = bh.Art(W, H)
    bh.comb(behind, 0, 28, W, H, honey_kind(60, 170), cell=bh.CELL_SMALL, seed=44)
    beh = behind.im
    comb_glints(beh, 0.0, 7)
    beh = stepped(beh, lambda x, y: 4 if x < W // 2 else 3)
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.polygon([b_inner(28)[0], 28, NEXT[0], 28, NEXT[0], H, b_inner(H)[0], H], fill=255)
    md.polygon([NEXT[1], 28, b_inner(28)[1], 28, b_inner(H)[1], H, NEXT[1], H], fill=255)
    cut = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cut.paste(beh, (0, 0), mask)
    art.paste(cut, 0, 0)
    # the next frame back: an upright face behind the tipped one, bounded by its own end bars
    # and top bar, its comb a size smaller (further off) and stepped down its ramps: one step at
    # the top of the box, two lower, three at the foot, one more in the tipped frame's shadow
    # (down and right: the sun is top left); a glint on about one honey cell in four
    nxt = bh.Art(W, H)
    bh.comb(nxt, NEXT[0] + 6, 34, NEXT[1] - 6, H, honey_kind(64, 168), cell=bh.CELL_SMALL, seed=31)
    glint = comb_glints(nxt.im, 0.22, 4)
    shadow = tipped.getchannel("A").point(lambda v: 255 if v > 40 else 0)

    def depth(x, y):
        n = 1 if y < 110 else 2 if y < 200 else 3
        sx, sy = x - fx - 7, y - fy - 5
        if 0 <= sx < shadow.width and 0 <= sy < shadow.height and shadow.getpixel((sx, sy)):
            n += 1
        return n

    face = stepped(nxt.im, depth)
    fpx = face.load()
    for x, y in glint:
        if fpx[x, y][3]:
            fpx[x, y] = step_down(HONEY_LIGHT, depth(x, y) - 1)
    art.paste(face, 0, 0)
    end = bh.Art(W, H)
    for x0 in (NEXT[0], NEXT[1] - 6):
        end.rect(x0, 30, 6, H - 30, PINE)
        end.rect(x0, 30, 2, H - 30, PINE_LIT)
        end.rect(x0 + 5, 30, 1, H - 30, PINE_DEEP)
    end.rect(NEXT[0] - 6, 28, NEXT[1] - NEXT[0] + 12, 6, PINE)
    end.rect(NEXT[0] - 6, 28, NEXT[1] - NEXT[0] + 12, 2, PINE_LIT)
    end.rect(NEXT[0] - 6, 33, NEXT[1] - NEXT[0] + 12, 1, PINE_DEEP)
    art.paste(stepped(end.im, lambda x, y: 1 if y < 110 else 2), 0, 0)
    # the side walls: the raw rim on top, the inner face as wood (the left in the shade of its
    # own rim, the right lit: the sun is top left), planked; the paint outside
    for y in range(18, H):
        l, r = b_inner(y)
        l, r = int(l), int(r)
        rim = 6 + int(9 * (y / H))
        fw = b_wall(y)
        plank = (y - 18) % 26 == 0
        art.rect(l - rim - 8, y, 8, 1, PAINT[0] if y % 24 else PAINT[1])
        art.rect(l - rim, y, rim, 1, PINE_LIT if y % 11 else PINE)
        art.rect(l, y, fw, 1, PINE_DEEP if plank else PINE_SHADE)
        art.rect(l, y, 1, 1, darker(PINE_SHADE, 0.3))
        art.rect(l + fw, y, 1, 1, OUT)
        art.rect(r - fw + 1, y, fw, 1, PINE if plank else PINE_LIT)
        art.rect(r - fw, y, 1, 1, OUT)
        art.rect(r, y, rim, 1, PINE if y % 11 else PINE_SHADE)
        art.rect(r + rim, y, 8, 1, PAINT[2] if y % 24 else PAINT[3])
        art.px(l - rim - 9, y, OUT)
        art.px(r + rim + 8, y, OUT)
    # bees on the next frame's face where the tipped frame leaves it showing, stepped down with it
    side = Room()
    for k, rect in enumerate(((NEXT[0] + 7, 44, fx + 16, 268), (fx + B_FRAME[0] + 12, 44, NEXT[1] - 7, 268))):
        for x, y, pose, left, turn, f in crowd(side, rect, 5, 8 + k):
            put_bee(art.im, x, y, pose, left, turn, f, tint=2 if y < 160 else 3)
    # the tipped frame and everything on it
    art.paste(tipped, fx, fy)
    cb = (fx + comb_box[0], fy + comb_box[1], fx + comb_box[2], fy + comb_box[3])
    q = B_QUEEN
    mx, my = (cb[0] + cb[2]) / 2, (cb[1] + cb[3]) / 2 + 8

    def dens(x, y):
        d = math.hypot((x - mx) / ((cb[2] - cb[0]) / 2), (y - my) / ((cb[3] - cb[1]) / 2))
        return 1.0 if d < 0.6 else 0.7 if d < 0.85 else 0.4

    court_bees = queen_and_court(art.im, room, q, False)
    workers = crowd(room, (cb[0] + 4, cb[1] + 4, cb[2] - 4, cb[3] - 3), 184, 17, dens)
    draw_crowd(art.im, workers)
    draw_crowd(art.im, court_bees)
    put_queen(art.im, q[0], q[1], left=False)
    # the front: two bars (was seven), with life on them, then the box's near wall
    y_foot = fy + B_FRAME[1] + 4
    for y in range(y_foot, H):
        l, r = b_inner(y)
        art.rect(int(l) + 4, y, int(r - l) - 7, 1, WELL_DEEPER)
    bars = ((282, 9), (301, 12))
    prev = y_foot
    peekers = {1: [(266, False, 0), (404, True, 1), (176, True, 2)]}
    for k, (y, h) in enumerate(bars):
        l, r = b_inner(y + h)
        gap(art, int(l) + 4, int(r) - 4, prev, y, 40 + k)
        for x, left, f in peekers.get(k, ()):
            peeker(art.im, x, y, left, f)
        bar(art, int(l) + 2, int(r) - 2, y, h, 50 + k)
        prev = y + h
    l, r = b_inner(320)
    gap(art, int(l) + 4, int(r) - 4, prev, 321, 60)
    # the near wall: its raw rim, then its painted face, planked, lit from the top left
    art.rect(0, 321, W, 9, PINE)
    art.rect(0, 321, W, 3, PINE_LIT)
    art.rect(0, 329, W, 1, PINE_SHADE)
    art.rect(0, 330, W, H - 330, PAINT[1])
    art.rect(0, 330, W, 2, PAINT[0])
    for yy in (343, 356):
        art.rect(0, yy, W, 1, PAINT[2])
    for xx in range(14, W, 96):
        art.rect(xx, 334, 1, 8, PAINT[2])
    # brace comb across the two gaps (a ridge of caps, bar to bar), beads of honey lying on the
    # bars, and the bees standing on them with their shadows
    brace_ridge(art.im, 452, 291, 301, 3)
    brace_ridge(art.im, 128, 313, 321, 3)
    honey_bead(art.im, 330, 283)
    honey_bead(art.im, 504, 302)
    life = [(150, 286, "walk", False), (214, 286, "rest", True), (372, 286, "walk", True),
            (556, 286, "rest", False), (112, 306, "walk", True), (240, 306, "walk", False),
            (436, 306, "walk", True), (580, 306, "rest", True)]
    rng = random.Random(9)
    for x, y, pose, left in life:
        put_bee(art.im, x, y, pose, left, 0, rng.randrange(6), shadow=True)
    fliers(art.im, [(64, 120, False), (580, 92, True), (66, 236, True), (590, 214, False),
                    (612, 262, True), (40, 300, False)])
    return art.im, q, B_SEARCH, None


# =============================================================================================
# A: held up. The frame lifted out of the box by its lugs in two gloved hands, first person,
# the top of the box below it at the same eye level, the flower bed in front.
# NEEDS A RULE CHANGE: "No hands anywhere" (The Beehive, 2026-09-30).
# =============================================================================================
A_FRAME_AT = (110, 46)
A_FRAME = (392, 214)
A_QUEEN = (390, 150)
A_SEARCH = (214, 196)
# The gloves are the smoker's bellows leather (build_hive LEATHER); the sleeves the palette's
# sand taken down towards the outline, so they sit under the comb in value.
GLOVE = {"lit": bh.LEATHER["lit"], "base": bh.LEATHER["base"], "shade": bh.LEATHER["shade"],
         "deep": darker(bh.LEATHER["shade"], 0.3)}
SLEEVE = {"lit": darker(look.PAL["sand"], 0.22), "base": darker(look.PAL["sand"], 0.36),
          "shade": darker(look.PAL["sand"], 0.5), "deep": darker(look.PAL["sand"], 0.62)}
LIGHT = (-0.7071, -0.7071)      # towards the room's sun, top left


def _blob(w, h, ramp):
    a = bh.Art(w, h)
    a.ell(0, 0, w, h, ramp["base"])
    a.ell(max(0, w // 2 - 1), max(0, h // 2), w - w // 2 + 1, h - h // 2, ramp["shade"])
    a.ell(0, 0, w, h - max(2, h // 3), ramp["base"])
    a.ell(1, 1, max(2, w // 2), max(2, h // 2 - 1), ramp["lit"])
    return look.inked(a.im)


def hand_sprite():
    """The left glove closed round a lug: the back of the hand over the lug's outer end, the
    thumb lying along its top, three fingers curled under it. Returns the picture and where
    the lug's outer top corner goes in it."""
    im = Image.new("RGBA", (36, 34), (0, 0, 0, 0))
    e, t = 13, 9
    im.alpha_composite(_blob(14, 20, GLOVE), (e - 10, t - 4))        # the back of the hand
    for k in range(3):                                               # fingers under the lug
        im.alpha_composite(_blob(10 - k, 6, GLOVE), (e + 1 + k * 3, t + 6 + k * 2))
    im.alpha_composite(_blob(14, 7, GLOVE), (e - 1, t - 5))          # the thumb, on top
    return im, (e, t)


def arm(lug, side):
    """A forearm from the window's side edge up to a glove closed round the frame's lug (`lug`
    its outer top corner; `side` -1 the left arm): a leather gauntlet most of the way, then a
    short cuff of sleeve at the edge, lit on whichever edge faces the top left."""
    lx, ly = lug
    wrist = (lx + side * 2, ly + 16)
    foot = (lx + side * 150, ly + 300)
    dx, dy = foot[0] - wrist[0], foot[1] - wrist[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    lit_edge = 1 if (nx * LIGHT[0] + ny * LIGHT[1]) > 0 else -1
    GAUNT = 0.55

    def wide(t):
        # the forearm widening towards the eye (it comes from the window's lower corner)
        return 18 + 16 * min(t / GAUNT, 1.0) if t < GAUNT else 40 + 26 * (t - GAUNT) / (1 - GAUNT)

    left = [(wrist[0] + dx * t - nx * wide(t) / 2, wrist[1] + dy * t - ny * wide(t) / 2)
            for t in [k / 40 for k in range(41)]]
    right = [(wrist[0] + dx * t + nx * wide(t) / 2, wrist[1] + dy * t + ny * wide(t) / 2)
             for t in [k / 40 for k in range(41)]]

    def tone(x, y):
        px_, py_ = x - wrist[0], y - wrist[1]
        t = (px_ * ux + py_ * uy) / ln
        s_ = (px_ * nx + py_ * ny) / max(wide(max(0, min(1, t))), 1)
        lit_s = s_ * lit_edge
        ramp = GLOVE if t < GAUNT else SLEEVE
        if abs(t - GAUNT) * ln < 1.5:
            return GLOVE["deep"]                     # the gauntlet's turned-back rim
        if t > GAUNT and (abs(t - 0.72) * ln < 0.8 or abs(t - 0.9) * ln < 0.8) and abs(s_) < 0.4:
            return SLEEVE["shade"]                   # a fold
        if lit_s > 0.24:
            return ramp["lit"]
        if lit_s < -0.26:
            return ramp["shade"]
        return ramp["base"]

    a = bh.Art(W, H)
    a.fill_by(left + right[::-1], tone)
    hand, (ex, ey) = hand_sprite()
    if side > 0:
        hand = look.flip(hand)
        ex = hand.width - 1 - ex
    a.paste(hand, lug[0] - ex, lug[1] - ey)
    return look.inked(a.im)


def option_a():
    art = bh.Art(W, H)
    room = Room()
    # the top of the box at the same eye level as the frame: its rim edge-on, the slot the
    # frame came up out of, its painted front face; the beds stand in front of it
    bx0, bx1, rim_y = 120, 520, 314
    meadow = bed_into(art.im, lawn_scatter(7, (20, 274, 620, 318), 16))
    art.rect(bx0, rim_y, bx1 - bx0, 5, PINE)
    art.rect(bx0, rim_y, bx1 - bx0, 1, PINE_LIT)
    art.rect(bx0 + 8, rim_y + 1, bx1 - bx0 - 16, 2, WELL_DEEPER)     # the open top, edge-on
    for x in range(bx0 + 12, bx1 - 12, 9):
        art.rect(x, rim_y + 1, 6, 1, PINE_SHADE)                     # the bars' ends in it
    art.rect(bx0, rim_y + 5, bx1 - bx0, H - rim_y - 5, PAINT[1])
    art.rect(bx0, rim_y + 5, bx1 - bx0, 2, PAINT[0])
    art.rect(bx0, rim_y + 5, 6, H - rim_y - 5, PAINT[0])
    art.rect(bx1 - 6, rim_y + 5, 6, H - rim_y - 5, PAINT[2])
    for yy in (334, 352):
        art.rect(bx0 + 6, yy, bx1 - bx0 - 12, 1, PAINT[2])
        art.rect(bx0 + 6, yy + 1, bx1 - bx0 - 12, 1, PAINT[0])
    art.rect(bx0 - 1, rim_y, 1, H - rim_y, OUT)
    art.rect(bx1, rim_y, 1, H - rim_y, OUT)
    art.rect(bx0 - 1, rim_y - 1, bx1 - bx0 + 2, 1, OUT)
    # the frame, held up (its top bar below the step plaque)
    fx, fy = A_FRAME_AT
    frame, comb_box = brood(*A_FRAME, seed=12)
    art.paste(frame, fx, fy)
    cb = (fx + comb_box[0], fy + comb_box[1], fx + comb_box[2], fy + comb_box[3])
    q = A_QUEEN
    mx, my = (cb[0] + cb[2]) / 2, (cb[1] + cb[3]) / 2 + 8

    def dens(x, y):
        d = math.hypot((x - mx) / ((cb[2] - cb[0]) / 2), (y - my) / ((cb[3] - cb[1]) / 2))
        return 1.0 if d < 0.6 else 0.7 if d < 0.85 else 0.35

    court_bees = queen_and_court(art.im, room, q, True)
    workers = crowd(room, (cb[0] + 4, cb[1] + 4, cb[2] - 4, cb[3] - 3), 176, 23, dens)
    draw_crowd(art.im, workers)
    draw_crowd(art.im, court_bees)
    put_queen(art.im, q[0], q[1], left=True)
    # bees on the box's rim, standing with their shadows, and in the air below the frame
    rng = random.Random(4)
    for x, y, pose, left in ((150, 311, "walk", False), (220, 311, "rest", True),
                             (420, 311, "walk", True), (492, 311, "rest", False)):
        put_bee(art.im, x, y, pose, left, 0, rng.randrange(6), shadow=True)
    fliers(art.im, [(170, 284, False), (300, 292, True), (470, 280, False), (300, 70, True),
                    (602, 80, False), (40, 66, False)], 6)
    # the flower bed in front of the box: corner borders and the low hedge along the foot
    bed = bed_into(art.im, bd.bed_B() + bd.bed_A())
    # the arms, from the window's side edges up to the lugs
    for side, lug in ((-1, (fx + 1, fy)), (1, (fx + A_FRAME[0] + 26, fy))):
        art.paste(arm(lug, side), -1, -1)
    bed_bees(art.im, room, showing(bed, art.im) + showing(meadow, art.im),
             (("hover", 3), ("rest", 2), ("fly", 1)), 11)
    return art.im, q, A_SEARCH, None


# =============================================================================================
# C: on the rest. The frame stood on the uncap step's own pine rest; the open hive it came out
# of at the same scale, its box running off the window's left edge (a brood frame is the box's
# inner width, so the whole box does not fit beside it); the flower bed along the lawn.
# =============================================================================================
C_FRAME = (346, 204)
C_FRAME_AT = (186, 44)
C_QUEEN = (452, 150)
C_SEARCH = (296, 128)


def big_box():
    """The hive's deep box at the frame's scale (inner width 372, as the frame with its ears),
    front-on and lit from the top left, open at the top: only its right end shows. Planked
    boards with a lit lip under every seam, the joint between two lifts, a pine hand cleat
    with its shadow, the end in shade. Returns the picture and its front's right edge and top."""
    w, h = 420, 230
    a = bh.Art(w + 16, h + 12)
    top = 8
    lit_, base, shade, deep = PAINT
    rng = random.Random(3)
    # the open top: the far rim, the frames' top bars edge-on with dark between, the near rim
    a.rect(0, top - 7, w, 2, PINE)
    a.rect(0, top - 7, w, 1, PINE_LIT)
    a.rect(0, top - 5, w, 5, WELL_DEEPER)
    for x in range(6, w - 6, 10):
        a.rect(x, top - 2, 8, 1, PINE_SHADE)        # the frames' top bars, low in the dark
        a.rect(x + 1, top - 3, 6, 1, darker(PINE_SHADE, 0.35))
    a.rect(0, top, w, 4, PINE)
    a.rect(0, top, w, 1, PINE_LIT)
    # the painted front: boards, each seam a dark line with a lit lip under it, a few streaks
    a.rect(0, top + 4, w, h, base)
    a.rect(0, top + 4, w, 2, lit_)
    for yy in range(top + 26, top + h, 26):
        a.rect(0, yy - 1, w, 2, deep)
        a.rect(0, yy + 1, w, 1, lit_)
    for _ in range(70):
        x, y = rng.randrange(0, w - 12), rng.randrange(top + 8, top + h - 4)
        a.rect(x, y, rng.randint(4, 14), 1, shade)
    joint = top + 104                            # where the lift above meets the one below
    a.rect(0, joint, w, 2, deep)
    a.rect(0, joint + 2, w, 2, shade)
    # the hand cleat: a pine batten across the upper lift, its shadow under it on the paint
    cx0, cy0 = w - 78, top + 44
    a.rect(cx0 + 2, cy0 + 6, 52, 2, darker(shade, 0.25))
    a.rect(cx0, cy0, 52, 6, PINE)
    a.rect(cx0, cy0, 52, 2, PINE_LIT)
    a.rect(cx0, cy0 + 5, 52, 1, PINE_DEEP)
    # the right end, in shade (the sun is top left)
    a.rect(w, top - 6, 14, h + 10, shade)
    a.rect(w, top - 6, 14, 4, PINE_SHADE)
    for yy in range(top + 26, top + h, 26):
        a.rect(w, yy, 14, 1, deep)
    a.rect(w, joint, 14, 2, deep)
    return bh.inked(a.im), (w, top)


def lawn_scatter(seed=5, box=(150, 290, 626, 332), apart=15):
    """Small flowers and grass tufts dotted over the lawn between the rest's legs at random,
    no two closer than `apart`: the pack's clover, small heads and grass."""
    rng = random.Random(seed)
    pool = SMALL_HEADS + ["pk_grass_%d" % i for i in range(8)] + ROUND_HEADS[:4]
    pts = []
    for _ in range(900):
        x, y = rng.uniform(box[0], box[2]), rng.uniform(box[1], box[3])
        if all(math.hypot(x - u, (y - v) * 1.8) >= apart for u, v, _n in pts):
            pts.append((x, y, rng.choice(pool)))
    return [(n, int(x), int(y)) for x, y, n in pts]


def leg_shadows(art, rest, rx, ry, foot):
    """Each leg of the rest rooted by a short shadow falling down and to the right (the room's
    sun is top left), on whole art px in the outline ink at the game's shadow strength."""
    a = np.array(rest)[..., 3] > 0
    row = foot - 2
    cols = np.nonzero(a[row])[0]
    runs = []
    for c in cols:
        if runs and c == runs[-1][1] + 1:
            runs[-1][1] = c
        else:
            runs.append([c, c])
    sh = bh.Art(W, H)
    for c0, c1 in runs:
        for k in range(14):
            sh.rect(rx + c0 + 2 + k, ry + foot - 1 + k // 5, c1 - c0 + 1, 1, OUT[:3] + (78,))
    art.paste(sh.im, 0, 0)


def option_c():
    art = bh.Art(W, H)
    room = Room()
    fx, fy = C_FRAME_AT
    frame, comb_box = brood(*C_FRAME, seed=19)
    rest, frame_tl, foot = bh.uncap_rest(C_FRAME[0] + 2, C_FRAME[1])
    rx, ry = fx - frame_tl[0], fy - frame_tl[1]
    # the box at the window's left edge, its foot standing in the bed
    box, (bw, btop) = big_box()
    bxr = 96                                    # where its front's right edge lands
    bx, by = bxr - bw, 148 - btop
    art.paste(box, bx, by)
    # the bed behind the rest (small heads in the lawn between its legs), then the rest
    lawn = lawn_scatter()
    leg_shadows(art, rest, rx, ry, foot)
    bed_back = bed_into(art.im, lawn)
    art.paste(rest, rx, ry)
    art.paste(frame, fx, fy)
    # the beds in front: corner borders and the low hedge along the foot
    bed = bed_into(art.im, bd.bed_B() + bd.bed_A())
    cb = (fx + comb_box[0], fy + comb_box[1], fx + comb_box[2], fy + comb_box[3])
    q = C_QUEEN
    mx, my = (cb[0] + cb[2]) / 2, (cb[1] + cb[3]) / 2 + 8

    def dens(x, y):
        d = math.hypot((x - mx) / ((cb[2] - cb[0]) / 2), (y - my) / ((cb[3] - cb[1]) / 2))
        return 1.0 if d < 0.6 else 0.7 if d < 0.85 else 0.35

    court_bees = queen_and_court(art.im, room, q, False)
    workers = crowd(room, (cb[0] + 4, cb[1] + 4, cb[2] - 4, cb[3] - 3), 152, 29, dens)
    draw_crowd(art.im, workers)
    draw_crowd(art.im, court_bees)
    put_queen(art.im, q[0], q[1], left=False)
    # a few bees coming up out of the open box, apart, and some in the air over it
    rng = random.Random(8)
    for x, y, pose, left in ((10, 143, "walk", False), (36, 143, "rest", True), (62, 143, "walk", True),
                             (90, 143, "walk", False)):
        put_bee(art.im, x, y, pose, left, 0, rng.randrange(6), shadow=True)
    fliers(art.im, [(22, 122, False), (70, 112, True), (112, 96, False), (48, 84, True),
                    (150, 128, False), (612, 70, True), (160, 286, False)], 8)
    bed_bees(art.im, room, showing(bed, art.im) + showing(bed_back, art.im), seed=13)
    return art.im, q, C_SEARCH, None


# =============================================================================================
# Composing, and today
# =============================================================================================
def compose(built, name, found):
    art1x, q, search, after = built
    screen = backdrop()
    screen.alpha_composite(zoom(art1x, G))
    if after is not None:
        after(screen)
    scene1x = look.downsample(screen)
    draw_lens(screen, scene1x, q if found else search, found)
    hud(screen)
    return {"screen": screen, "queen": q, "art": art1x, "name": name, "found": found}


def clamp(box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    x0 = min(max(x0, 0), SCREEN[0] - w)
    y0 = min(max(y0, 0), SCREEN[1] - h)
    return (x0, y0, x0 + w, y0 + h)


CAPTIONS = {
    "A": "RULE CHANGE NEEDED (CLAUDE.md, The Beehive: 'No hands anywhere'). Held up: first person, "
         "the brood frame lifted by its lugs, each leather glove closed round one (thumb on top, "
         "fingers under); the forearms coming in from the window's lower corners, widening towards "
         "the eye, gauntlet most of the way and the sleeve taken down under the comb in value. The box below at the same eye level (its "
         "rim and painted face, bees on the rim), a meadow of small flowers behind it and the "
         "flower bed in front filling the foot.",
    "B": "The well, deeper: today's camera down into the open box, rebalanced. The frame 1.3x and "
         "centred under the plaque; beside it the next frame back, an upright face bounded by its "
         "own end bars and top bar, its cells smaller (further off) and stepped down their own "
         "ramps (honey stays amber), a glint on one honey cell in four or five; the frame behind "
         "that in the gaps; the side walls wood, the right lit and the left in shade. Two front "
         "bars (was seven) with a ridge of brace comb bar to bar, beads of honey on them, bees "
         "standing on them with shadows and three heads peering out of the gap. Picked.",
    "C": "On the rest: the frame stood on the uncap step's own pine rest, the box it came out of at "
         "the same scale running off the window's left edge (a frame is the box's inner width), "
         "bees coming up out of its open top; the rest's legs rooted by shadows falling down and "
         "right; small heads in the lawn between its legs and the beds along the foot, bees "
         "working them. No hands; the most garden of the three; the comb is the smallest.",
}
NAMES = {"A": "held up", "B": "the well, deeper", "C": "on the rest"}


def option(label, built, detail):
    """The found moment at real scale, beside it the searching still (half size), a 1:1 crop of
    her in that still (findable, not obvious), the glass at 3x, and one detail at 3x."""
    found = compose(built, label, True)
    search = compose(built, label, False)
    q = built[1]
    shown = found["screen"].copy()
    sshown = search["screen"].copy()
    lens_box = clamp((q[0] * G - 162, q[1] * G - 162, q[0] * G + 162, q[1] * G + 162))
    one_box = clamp((q[0] * G - 210, q[1] * G - 120, q[0] * G + 210, q[1] * G + 120))
    z_lens = look.crop_zoom(found["screen"], lens_box, 2, mark_on=shown)
    z_det = look.crop_zoom(found["screen"], clamp(detail[0]), detail[1], mark_on=shown)
    z_one = look.crop_zoom(search["screen"], one_box, 1, mark_on=sshown)
    half = sshown.resize((960, 540), Image.NEAREST)
    under = stack([panel(z_one, "1:1 while searching: she is in this crop, with her court"),
                   panel(z_lens, "2x: found: rays from behind the glass, the stepped halo, the stars"),
                   panel(z_det, detail[2])], "h", 12)
    left = stack([panel(shown, "real scale, 1920 x 1080: the moment she is found"), under], "v", 12)
    body = stack([left, panel(half, "searching (half size): the glass elsewhere, no payoff")], "h", 16)
    return look.option_block(label, NAMES[label], CAPTIONS[label], body,
                             recommended=(label == RECOMMEND))


def today():
    q = look.plate("queen")
    half = q.resize((960, 540), Image.NEAREST)
    z = look.crop_zoom(q, (600, 330, 840, 510), 3)
    return look.option_block("Today", "for comparison",
                             "The queen step as the game draws it: the frame small in the middle, "
                             "the next frame's face flat dark either side, seven bare bars over the "
                             "bottom 40%, 2-3 px bees.", stack([panel(half, "the plate at half "
                             "size"), panel(z, "3x: the comb")], "h", 16))


def bee_strip():
    """The bee and the queen this sheet draws (look variant R), at 8x and at 1:1 on the comb."""
    ims = []
    for pose, frames in (("fly", (0, 1, 2)), ("walk", (0, 1)), ("rest", (0, 3))):
        for f in frames:
            ims.append(zoom(look.bee(V, f, pose=pose), 8))
    ims.append(zoom(look.queen(V, 0), 8))
    ims.append(zoom(look.queen(V, 1, laying=True), 8))
    row = stack(ims, "h", 10, align="center")
    a = bh.Art(150, 64)
    bh.comb(a, 0, 0, 150, 64, lambda x, y, r: "brood" if r.random() < 0.65 else "honey",
            cell=bh.CELL_BIG, seed=3)
    rm = Room()
    qbees = queen_and_court(a.im, rm, (78, 32), False)
    draw_crowd(a.im, crowd(rm, (4, 4, 146, 60), 30, 2))
    draw_crowd(a.im, qbees)
    put_queen(a.im, 78, 32)
    at3 = zoom(a.im, G)
    return look.option_block(
        "Bee", "the bee and the queen on this sheet (look.py variant R)",
        "The bee sheet's A reworked after the review: the same coin colours on a 10 x 7 octagon, one "
        "band that wraps (lit on its top) between a dark tail tip and the head, the 2 x 2 eye in the "
        "head third with its glint top left and a pixel of face in front of it, wings as pale sky-blue "
        "leaves with their own outline, lifted in flight and lying on the back folded. The queen: "
        "18 x 7, nearly twice a worker's length, tapering, the hive's own QUEEN_GOLD amber with three "
        "dark bands, short wings so her bare bands show, and a coin-gold crown with a coral jewel and "
        "its own outline.",
        stack([panel(row, "8x: fly 0-2, walk 0-1, rest, blink; the queen walking and laying"),
               panel(at3, "game scale (3 screen px an art px): her and her court among workers"),
               panel(a.im, "1:1 art")], "h", 16, align="start"))


def main():
    a = option_a()
    b = option_b()
    c = option_c()
    opts = [
        option("A", a, ((250, 70, 490, 250), 3, "3x: the glove closed round the frame's lug")),
        option("B", b, ((1200, 820, 1620, 990), 2,
                        "2x: the front bars: a brace ridge, a bead of honey, peering heads, shadows")),
        option("C", c, ((0, 380, 420, 560), 2, "2x: the box at the frame's scale, bees coming up out of it")),
    ]
    extra = [panel(look.crop_zoom(compose(b, "B", False)["screen"], (1500, 150, 1700, 480), 3),
                   "B, 3x: the next frame back: end bar, stepped comb, one glint in four, the lit wall")]
    look.sheet("The queen: three ways to stage it (second round)", [today(), bee_strip()] + opts
               + [look.option_block("B+", "one more detail", "", stack(extra, "h", 12))], OUT_PATH,
               subtitle="Every option is drawn on the room's own lattice (3 screen px an art px, 640 x "
                        "360 art) over the backdrop sheet's clean view (no rubbish, ferries or dogs; its "
                        "0.6 veil; its flower bed wherever lawn shows), with look's round bee and queen "
                        "(variant R). Each is shown twice: searching (the glass elsewhere, no payoff) and "
                        "the moment she is found (gold rays fanning from behind the glass, stepped halo "
                        "rings, four-point stars round the rim, all solid on whole art px). The glass "
                        "magnifies twice about a cell corner, so its pixels are 6 screen px on the room's "
                        "3 px lattice. Pink boxes mark the zoom crops.",
               notes="Notes. (1) Hands: 'The Beehive' says 'No hands anywhere: the pointer holds every "
                     "tool'; A needs that rule changed and says so in its caption. (2) No crown is "
                     "dropped over her on the find: she wears her own, so the payoff is rays, halo and "
                     "stars. (3) Every bee is laid by its drawn silhouette, one px clear of every other "
                     "(rotated ones included), so comb shows between them: about 150-185 workers on the "
                     "frame, 20% fewer than the first round (today 330, each a third the size). (4) Her "
                     "court pushes out from her until it clears her. (5) Comb in the box steps down its "
                     "own ramps rather than under a veil, and the next frame's honey keeps a glint on one "
                     "cell in four or five (the comb's per-cell shine is taken back to honey there; the "
                     "lifted frame keeps build_hive's own comb as it is). (6) The glass, the payoff and "
                     "the HUD are the step's own; only LENS_R moves. Script: "
                     "tools/hive_look/queen_mockup.py.")
    print("wrote", OUT_PATH)
    return a, b, c


if __name__ == "__main__":
    main()

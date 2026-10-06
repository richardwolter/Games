"""Bake the lakebed: every rock, branch, water plant and shell lying on the bottom of the
lake, into one world-aligned map the water shader reads.

Offline, from the project root:
  PYTHONPATH=<psd-extract venv site-packages> python tools/build_lakebed.py
then reimport (`<exe> --path . --headless --import`).

Writes:
  assets/lakebed.png   the bed map, one texel per art pixel (2 world px), RGBA8:
                         R  material id (0 = nothing: the shader draws its own ground)
                         G  (step offset + 4) | (height above the root << 4)
                         B  growth rank: 0 is always there, 1..255 comes in with the lake's
                            clean share (plants and shells: life returns)
                         A  255 where anything is, 0 elsewhere
  assets/lakebed.json  the map's place in the world, and each material's five-step ramp
  tools/last_lakebed_sheet.png  a picture of the bed round the island through clean water,
                         shaded the way the shader shades it, for judging

The look was picked off tools/lakebed_mockup.py (2026-09-30, Richard). The bed is authored in
steps, not colours: a pixel is a material and an offset from that material's middle step, and
the shader mixes the step a fixed share towards the water by depth band. Rocks are the Forest
pack's own slices, read by brightness and sunk into the sand; branches and plants are drawn by
rule. The geometry mirrors Iso and water.gdshader, which are the same on every save, so the bed
is the same on every save too.
"""
import json, math, os, random
from PIL import Image, ImageDraw

OUT_PNG = os.path.join("assets", "lakebed.png")
OUT_JSON = os.path.join("assets", "lakebed.json")
SHEET_PNG = os.path.join("tools", "last_lakebed_sheet.png")
SEED = 1930

# ---- the world the map covers (Iso) ---------------------------------------------------

TILE_W, TILE_H = 64.0, 32.0
COLS = ROWS = 92
CENTRE = (46.0, 46.0)
RADIUS = (40.0, 34.0)
ISLAND_CENTRE = (46.0, 46.0)
ISLAND_RADIUS = (8.0, 6.8)
SHORE_LAP = 0.45                 # Lake.SHORE_LAP, as the shader folds it in
TEXEL = 2.0                      # world px per texel: one art pixel
ORIGIN = (-COLS * TILE_W * 0.5, 0.0)
SIZE = (int(COLS * TILE_W / TEXEL), int(ROWS * TILE_H / TEXEL))   # 2944 x 1472


def world_to_tile(x, y):
    a = x / (TILE_W * 0.5); b = y / (TILE_H * 0.5)
    return (b + a) * 0.5, (b - a) * 0.5


def shore_fraction(tx, ty):
    """water.gdshader's: the radius carries `shore_lap`."""
    dx = (tx - CENTRE[0]) / (RADIUS[0] + SHORE_LAP); dy = (ty - CENTRE[1]) / (RADIUS[1] + SHORE_LAP)
    r = math.hypot(dx, dy)
    if r < 1e-4: return 0.0
    a = math.atan2(dy, dx)
    return r / (1.0 + 0.09 * math.sin(a * 3.0) + 0.05 * math.sin(a * 5.0 + 1.3))


def island_fraction(tx, ty):
    rx = max(ISLAND_RADIUS[0] - SHORE_LAP, .5); ry = max(ISLAND_RADIUS[1] - SHORE_LAP, .5)
    dx = (tx - ISLAND_CENTRE[0]) / rx; dy = (ty - ISLAND_CENTRE[1]) / ry
    r = math.hypot(dx, dy)
    if r < 1e-4: return 0.0
    a = math.atan2(dy, dx)
    return r / (1.0 + 0.07 * math.sin(a * 3.0 + 0.7) + 0.035 * math.sin(a * 5.0 - 0.4)
                + 0.02 * math.sin(a * 7.0 + 2.1))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def texel_world(u, v):
    return ORIGIN[0] + (u + .5) * TEXEL, ORIGIN[1] + (v + .5) * TEXEL


def depth_uv(u, v):
    """The shader's `d`: 0 at the bank, 1 over the deepest water, shoaling up to the island."""
    tx, ty = world_to_tile(*texel_world(u, v))
    s = max(0.0, min(1.0, shore_fraction(tx, ty)))
    return math.sqrt(max(1 - s, 0)) * smoothstep(1.0, 2.6, island_fraction(tx, ty))


def in_water(u, v, inset=.03, isl_clear=1.12):
    tx, ty = world_to_tile(*texel_world(u, v))
    return shore_fraction(tx, ty) < 1 - inset and island_fraction(tx, ty) > isl_clear


# ---- the materials ---------------------------------------------------------------------

def c(r, g, b): return [round(r, 3), round(g, 3), round(b, 3)]
def ramp5(*cols): return [c(*k) for k in cols]


# id: name, ramp (darkest first). id 0 is the shader's own ground; `ground` here (1) is sand
# the builder lays over it (a drift round a rock, the shade under it), on the same ramp.
MATERIALS = [
    ("none", None),
    ("ground", ramp5((.42, .37, .27), (.56, .5, .37), (.7, .63, .47), (.84, .76, .58), (.94, .89, .74))),
    ("rock", ramp5((.2, .19, .18), (.33, .31, .29), (.47, .45, .41), (.6, .58, .53), (.74, .72, .66))),
    ("wood", ramp5((.22, .12, .08), (.36, .21, .13), (.5, .32, .2), (.64, .46, .31), (.82, .7, .52))),
    ("eelgrass", ramp5((.1, .2, .1), (.17, .32, .15), (.27, .45, .2), (.42, .58, .26), (.62, .74, .38))),
    ("weed", ramp5((.08, .22, .1), (.14, .34, .14), (.24, .48, .2), (.4, .62, .28), (.6, .78, .4))),
    ("horn", ramp5((.07, .16, .09), (.12, .26, .13), (.2, .36, .18), (.32, .48, .24), (.5, .62, .34))),
    ("pond", ramp5((.14, .15, .07), (.27, .3, .11), (.42, .45, .17), (.58, .57, .25), (.76, .66, .38))),
    ("chara", ramp5((.24, .3, .2), (.38, .46, .3), (.54, .62, .42), (.7, .76, .56), (.84, .88, .72))),
    ("shell", ramp5((.14, .12, .1), (.3, .24, .18), (.5, .42, .3), (.7, .6, .44), (.86, .78, .62))),
    ("moss", ramp5((.12, .24, .1), (.2, .34, .14), (.29, .44, .19), (.43, .55, .25), (.6, .7, .36))),
    ("mussel", ramp5((.1, .12, .17), (.19, .22, .3), (.31, .35, .45), (.49, .54, .62), (.72, .76, .8))),
]
MAT_ID = {name: i for i, (name, _) in enumerate(MATERIALS)}


# ---- small helpers ---------------------------------------------------------------------

def hash2(x, y, s=0):
    n = (int(x) * 374761393 + int(y) * 668265263 + int(s) * 1442695041) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return (n & 0xffff) / 65535.0


def vnoise(x, y, s):
    xi, yi = math.floor(x), math.floor(y); fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash2(xi, yi, s), hash2(xi + 1, yi, s)
    d, e = hash2(xi, yi + 1, s), hash2(xi + 1, yi + 1, s)
    return a + (b - a) * fx + (d - a) * fy + (a - b - d + e) * fx * fy


def fbm(x, y, s):
    return sum(vnoise(x * 2 ** o, y * 2 ** o, s + o) / 2 ** o for o in range(3)) / 1.75


def lum(q): return (0.3 * q[0] + 0.59 * q[1] + 0.11 * q[2]) / 255


def bbox(pix):
    xs = [k[0] for k in pix]; ys = [k[1] for k in pix]
    return min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1


# Every picture below is {(x, y): (offset, material, height)}; height is how far above its
# root a plant's pixel stands (for the shader's sway), 0 for everything else.


# ---- rocks: the Forest pack's slices, sunk into the sand ------------------------------

ROCK_FILES = ["assets/Forest Isometric Pack Free/Rocks/Slice %d.png" % i for i in range(1, 6)]


def rock_sprite(i):
    """Brightness ranked into four steps, the moss onto its own ramp. The pack's dark
    outline is its own lowest rank."""
    im = Image.open(ROCK_FILES[i]).convert("RGBA")
    im = im.crop(im.getbbox())
    px = {}
    for y in range(im.height):
        for x in range(im.width):
            q = im.getpixel((x, y))
            if q[3] > 128: px[(x, y)] = q

    def green(q): return q[1] > q[0] + 12 and q[1] > q[2] + 8
    stone = sorted(lum(q[:3]) for q in px.values() if not green(q))
    cuts = [stone[int(len(stone) * f)] for f in (.12, .4, .8)]
    out = {}
    for (x, y), q in px.items():
        l = lum(q[:3])
        off = -2 if l < cuts[0] else -1 if l < cuts[1] else 0 if l < cuts[2] else 1
        out[(x, y)] = (off, "moss" if green(q) else "rock", 0)
    return out


ROCKS = [rock_sprite(i) for i in range(len(ROCK_FILES))]


def sunk(pix, seed):
    """The picture with its foot buried: a wavy sand line two to four rows up it, a lit
    drift along the line spilling past the sides, a shaded row under the foot, and a few
    grains knocked loose."""
    foot, top = {}, {}
    for (x, y) in pix:
        foot[x] = max(foot.get(x, -1), y); top[x] = min(top.get(x, 99), y)
    out = {}
    for (x, y), v in pix.items():
        bury = 2 + round(fbm(x / 3.0, seed % 997, seed) * 3)
        bury = min(bury, (foot[x] - top[x]) // 2)
        line = foot[x] - bury
        if y > line + 1: out[(x, y)] = (0, "ground", 0)
        elif y == line + 1: out[(x, y)] = (1, "ground", 0)
        else: out[(x, y)] = v
    xs = sorted(foot)
    for side, x in ((-1, xs[0]), (1, xs[-1])):
        for k in (1, 2):
            out.setdefault((x + side * k, foot[x] - 2 + k), (1, "ground", 0))
    for x in xs[1:-1]:
        if hash2(x, seed, 3) > .25: out.setdefault((x, foot[x] + 1), (-1, "ground", 0))
    r = random.Random(seed)
    w = xs[-1] - xs[0] + 1
    for _ in range(3 + w // 5):
        gx, gy = r.randint(xs[0] - 3, xs[-1] + 2), foot[r.choice(xs)] + r.randint(-1, 3)
        out.setdefault((gx, gy), (r.choice((1, -1, -2)), "rock", 0))
    return out


# ---- branches ----------------------------------------------------------------------------

def branch(seed, length, angle, thick):
    """A fallen branch lying on the plane: a wandering limb tapering from `thick` rows, a
    twig or two, bark crevices and knots, a pale broken end, a dark outline, and a stretch
    of it buried under sand with a shaded row along its underside."""
    r = random.Random(seed)
    body = {}

    def limb(x, y, a, n, t0, t1, fork):
        for i in range(n * 2):
            a += r.gauss(0, .06)
            x += math.cos(a) * .5; y += math.sin(a) * .5
            t = t0 + (t1 - t0) * i / (n * 2)
            px, py = round(x), round(y * .5)
            rows = max(1, round(t))
            for k in range(rows):
                if rows == 1: off = 0
                elif k == 0: off = 1
                elif k == rows - 1 and rows > 2: off = -1
                else: off = 0
                body.setdefault((px, py + k), off)
            if fork and i == int(n * 2 * fork[0]):
                limb(x, y, a + fork[1], fork[2], max(1, t * .6), 1, None)

    side = r.choice((-1, 1))
    limb(0, 0, angle, length, thick, 1, (r.uniform(.3, .55), side * r.uniform(.6, .95), r.randint(5, 9)))
    if r.random() < .6:
        limb(0, 0, angle + r.uniform(-.1, .1), int(length * r.uniform(.5, .7)), thick * .8, 1,
             (r.uniform(.6, .8), -side * r.uniform(.5, .8), r.randint(3, 6)))
    for (x, y) in sorted(body):
        if body[(x, y)] == 0 and hash2(x, y, seed) > .7:
            body[(x, y)] = -2
            if hash2(x + 1, y, seed) > .5 and body.get((x + 1, y)) == 0: body[(x + 1, y)] = -2
    ca, sa = math.cos(angle), math.sin(angle) * .5
    body[min(body, key=lambda k: k[0] * ca + k[1] * sa)] = 2
    out = {k: (v, "wood", 0) for k, v in body.items()}
    for (x, y) in body:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in body: out[(x + dx, y + dy)] = (-2, "wood", 0)
    x0, y0, w, h = bbox(out)
    b0 = r.randint(x0 + w // 4, x0 + w // 2); b1 = b0 + r.randint(3, 5)
    foot = {}
    for (x, y) in out: foot[x] = max(foot.get(x, -99), y)
    for (x, y) in list(out):
        if b0 <= x <= b1 and y >= foot[x] - 2:
            out[(x, y)] = (1 if y == foot[x] - 2 else 0, "ground", 0)
    for x, fy in foot.items():
        if hash2(x, seed, 5) > .35: out.setdefault((x, fy + 1), (-1, "ground", 0))
    return out


# ---- water plants: standing up off the bed, side on; root at (0, 0) -------------------------

def _base(out, w, rng):
    for dx in range(-w, w + 1):
        out.setdefault((dx, 0), (1 if abs(dx) < w else 0, "ground", 0))
        if rng.random() > .3: out.setdefault((dx, 1), (-1, "ground", 0))


def _p(out, x, y, off, mat, keep=False):
    """A plant pixel at `y` rows above its root (y is negative)."""
    if keep: out.setdefault((x, y), (off, mat, min(15, -y)))
    else: out[(x, y)] = (off, mat, min(15, -y))


def eelgrass(seed):
    r = random.Random(seed); out = {}
    n = r.randint(5, 8)
    for b in range(n):
        x0 = r.uniform(-2, 2); h = r.randint(9, 17); bend = r.uniform(-4, 4)
        back = b < n // 2
        wide = 2 if (not back and r.random() < .5) else 1
        for y in range(h):
            t = y / h
            x = round(x0 + bend * t * t)
            for k in range(wide if t < .7 else 1):
                off = (-1 if back else 0)
                if wide == 2 and k == 0: off += 1
                if t > .85: off += 1
                _p(out, x + k, -1 - y, off, "eelgrass")
    _base(out, 2, r)
    return out


def waterweed(seed):
    r = random.Random(seed); out = {}
    for s in range(r.randint(3, 4)):
        x0 = r.randint(-3, 3); h = r.randint(7, 14); ph = r.uniform(0, 6); amp = r.uniform(.6, 1.6)
        for y in range(h):
            x = x0 + round(math.sin(y * .5 + ph) * amp)
            _p(out, x, -1 - y, -1, "weed")
            if y > 0:
                ln = 2 if y % 3 == 1 else 1
                for k in range(1, ln + 1):
                    _p(out, x - k, -1 - y - (k - 1), 1 if k == ln else 0, "weed", True)
                    _p(out, x + k, -1 - y - (k - 1), 0 if k == ln else -1, "weed", True)
        top = x0 + round(math.sin(h * .5 + ph) * amp)
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, 1)):
            _p(out, top + dx, -1 - h - dy, 1, "weed")
    _base(out, 3, r)
    return out


def hornwort(seed):
    r = random.Random(seed); out = {}
    for stem in range(2):
        h = r.randint(10, 15) if stem == 0 else r.randint(6, 9)
        lean = r.uniform(-2, 2); x0 = 0 if stem == 0 else r.choice((-3, 3))
        y = 0
        while y < h:
            t = y / h
            x = x0 + round(lean * t * t)
            _p(out, x, -1 - y, -1, "horn")
            if y > 0 and r.random() < .95:
                for sgn in (-1, 1):
                    reach = max(1, round((3.8 - 2.4 * t) * r.uniform(.8, 1.2)))
                    for k in range(1, reach + 1):
                        up = (k + 1) // 2 if r.random() < .7 else k // 2
                        tone = 1 if (k == reach and t > .45) else (0 if k == reach else -1)
                        _p(out, x + sgn * k, -1 - y - up, tone, "horn", True)
                    if reach >= 2 and r.random() < .5:
                        _p(out, x + sgn * reach, -2 - y - (reach + 1) // 2, 0, "horn", True)
            y += r.choice((1, 1, 2))
        _p(out, x0 + round(lean), -1 - h, 1, "horn")
    _base(out, 3, r)
    return out


def pondweed(seed):
    r = random.Random(seed); out = {}
    h = r.randint(12, 17); lean = r.uniform(-1.5, 1.5)
    stem = {}
    for y in range(h):
        x = round(lean * (y / h) ** 1.5 * 2)
        stem[y] = x
        _p(out, x, -1 - y, -1, "pond")
        if y < 4: _p(out, x + 1, -1 - y, -2, "pond")
    side = r.choice((-1, 1)); y = 3
    while y < h:
        x = stem[y]; side = -side
        ln = r.randint(5, 7)
        if r.random() < .2:
            for k in range(1, ln):
                _p(out, x + side * k, -1 - y - k // 2, -2, "pond")
        else:
            for k in range(1, ln + 1):
                u = k / ln
                half = 1 if .25 < u < .8 else 0
                cy = -1 - y - round(u * 2)
                _p(out, x + side * k, cy, -1 if half else 0, "pond")
                if half:
                    _p(out, x + side * k, cy - 1, 1, "pond")
                    _p(out, x + side * k, cy + 1, 0, "pond")
        y += r.randint(1, 3)
    _p(out, stem[h - 1], -1 - h, 1, "pond")
    _base(out, 2, r)
    return out


def stonewort(seed):
    r = random.Random(seed); out = {}
    for s in range(r.randint(7, 10)):
        x = r.uniform(-4, 4); a = r.uniform(-.9, .9); h = r.randint(4, 8)
        y = 0.0
        for i in range(h):
            a += r.gauss(0, .15)
            x += math.sin(a) * .9; y += math.cos(a) * .9
            _p(out, round(x), -1 - round(y), 0, "chara")
            if i % 2 == 1:
                for sgn in (-1, 1):
                    _p(out, round(x) + sgn, -2 - round(y), 1, "chara", True)
    for (x, y), v in list(out.items()):
        if (x, y - 1) in out and (x - 1, y) in out and (x + 1, y) in out: out[(x, y)] = (-1, "chara", v[2])
        elif (x, y - 1) not in out: out[(x, y)] = (1, "chara", v[2])
    _base(out, 4, r)
    return out


PLANTS = [eelgrass, waterweed, hornwort, pondweed, stonewort]


# ---- shells ------------------------------------------------------------------------------

# River snails, hand set: a coiled shell lit on its upper left, the whorl a step down, the
# pale foot and a feeler out front. Two poses, and each is mirrored at random.
SNAILS = [
    ["...oooo....",
     "..oLLSSo...",
     ".oLSDDSSo..",
     ".oSDLLDSo..",
     ".oSDSoDSo..",
     "..oDDSDoFFF",
     "...ooooF..F"],
    ["..oooo...",
     ".oLLSSo..",
     "oLSDDSSo.",
     "oSDLSDSo.",
     ".oDSDDoFF",
     "..ooooF.F"],
]
SNAIL_OFF = {"L": 1, "S": 0, "D": -1, "o": -2, "F": 2}


def snail(seed):
    r = random.Random(seed)
    rows = SNAILS[r.randrange(len(SNAILS))]
    flip = r.random() < .5
    out = {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                out[((len(row) - 1 - x) if flip else x, y)] = (SNAIL_OFF[ch], "shell", 0)
    return out


def mussels(seed):
    """A mussel bed: three to six blue-black shells lying every which way in a clump, each
    lit along its top, ringed dark, one or two half sunk in the sand."""
    r = random.Random(seed)
    out = {}
    for m in range(r.randint(3, 6)):
        cx, cy = r.randint(-6, 6), r.randint(-3, 3)
        long_ = r.choice(((2, 1), (3, 1), (1, 1)))
        shell_ = {}
        for i in range(-long_[0], long_[0] + 1):
            for j in range(-long_[1], long_[1] + 1):
                if (i / (long_[0] + .5)) ** 2 + (j / (long_[1] + .5)) ** 2 > 1:
                    continue
                off = 1 if j == -long_[1] else (-1 if j == long_[1] else 0)
                shell_[(cx + i, cy + j)] = (off, "mussel", 0)
        ring = {}
        for (x, y) in shell_:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in shell_: ring[(x + dx, y + dy)] = (-2, "mussel", 0)
        whole = {**shell_, **ring}
        # Each shell apart from the others, or the bed runs into one blob.
        if any((x + dx, y + dy) in out for (x, y) in whole for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        out.update(whole)
    if not out:
        out[(0, 0)] = (0, "mussel", 0)
    foot = {}
    for (x, y) in out: foot[x] = max(foot.get(x, -99), y)
    for x, fy in foot.items():
        if r.random() < .35:
            out[(x, fy)] = (1, "ground", 0)
    return out


def clam(seed):
    """A freshwater clam half in the sand: a pale ridged shell, its bottom rows under a lit
    drift, a dark hinge line."""
    r = random.Random(seed)
    w = r.choice((3, 4))
    out = {}
    for i in range(-w, w + 1):
        for j in range(-2, 2):
            if (i / (w + .5)) ** 2 + ((j + .5) / 2.2) ** 2 > 1:
                continue
            off = 1 if j == -2 else (0 if (i + j) % 2 else -1)
            out[(i, j)] = (off, "shell", 0)
    for (x, y) in list(out):
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            if (x + dx, y + dy) not in out: out[(x + dx, y + dy)] = (-2, "shell", 0)
    for i in range(-w - 1, w + 2):
        out[(i, 1)] = (1, "ground", 0)
        out.setdefault((i, 2), (-1, "ground", 0))
    return out


SHELL_MAKERS = [snail, snail, mussels, clam]


def shell(seed):
    return SHELL_MAKERS[random.Random(seed).randrange(len(SHELL_MAKERS))](seed)


# ---- laying it all out ------------------------------------------------------------------

BANDS = (.3, .58, .85)            # the shader's depth bands: past the last, only shapes show
# what, how many, and how the count is shared over the bands (shallow, mid, deeper, deep)
PLAN = [
    ("rock", 520, (.35, .35, .2, .1)),
    ("branch", 170, (.4, .4, .2, 0)),
    ("plant", 1500, (.5, .38, .12, 0)),
    ("shell", 520, (.55, .35, .1, 0)),
]


def band_of(d): return next((i for i, at in enumerate(BANDS) if d < at), 3)


def main():
    rng = random.Random(SEED)
    W, H = SIZE
    R = bytearray(W * H); G = bytearray(W * H); B = bytearray(W * H); A = bytearray(W * H)
    taken = bytearray(W * H)

    # Candidate spots per band: sampled on a coarse grid of the water, so placing by band
    # is a pick from a list rather than darts at a 4-million-texel map.
    by_band = [[], [], [], []]
    for v in range(0, H, 3):
        for u in range(0, W, 3):
            if in_water(u, v): by_band[band_of(depth_uv(u, v))].append((u, v))
    for lst in by_band: rng.shuffle(lst)

    def fits(pix, u0, v0):
        for (x, y) in pix:
            u, v = u0 + x, v0 + y
            if not (0 <= u < W and 0 <= v < H): return False
            if taken[v * W + u]: return False
        # the foot and both ends in the water
        x0, y0, w, h = bbox(pix)
        return in_water(u0 + x0, v0 + y0 + h - 1) and in_water(u0 + x0 + w - 1, v0 + y0 + h - 1) \
            and in_water(u0 + x0 + w // 2, v0 + y0)

    def put(pix, u0, v0, rank):
        for (x, y), (off, mat, height) in pix.items():
            i = (v0 + y) * W + u0 + x
            R[i] = MAT_ID[mat]; G[i] = (off + 4) | (min(height, 15) << 4)
            B[i] = rank if mat not in ("rock", "wood", "moss") else 0
            A[i] = 255
        for (x, y) in pix:                                  # and a pixel of room round it
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    u, v = u0 + x + dx, v0 + y + dy
                    if 0 <= u < W and 0 <= v < H: taken[v * W + u] = 1

    counts = {}
    for what, total, share in PLAN:
        placed = 0
        for band, part in enumerate(share):
            want = round(total * part)
            pool = by_band[band]
            k = 0
            while want > 0 and pool:
                u, v = pool.pop()
                k += 1
                if k > want * 40: break
                seed = rng.randrange(1 << 30)
                if what == "rock":
                    pix = sunk(ROCKS[rng.choice((0, 1, 2, 3, 4, 2, 3))], seed)
                elif what == "branch":
                    pix = branch(seed, rng.randint(14, 26), rng.uniform(-.6, .6) + (math.pi if rng.random() < .5 else 0),
                                 rng.choice((3, 3, 4)))
                elif what == "plant":
                    pix = rng.choice(PLANTS)(seed)
                else:
                    pix = shell(seed)
                x0, y0, w, h = bbox(pix)
                if not fits(pix, u - x0 - w // 2, v - y0 - h + 1): continue
                rank = 0 if what in ("rock", "branch") else rng.randint(1, 255)
                put(pix, u - x0 - w // 2, v - y0 - h + 1, rank)
                placed += 1; want -= 1
        counts[what] = placed

    img = Image.merge("RGBA", [Image.frombytes("L", SIZE, bytes(ch)) for ch in (R, G, B, A)])
    img.save(OUT_PNG, optimize=True)
    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump({
            "origin": list(ORIGIN), "texel": TEXEL, "size": list(SIZE), "bands": list(BANDS),
            "materials": [{"name": n, "ramp": rp} for n, rp in MATERIALS],
            "counts": counts,
        }, f, indent=1)
    print("wrote", OUT_PNG, SIZE, counts)
    sheet(img)


# ---- the review sheet: the shader's colouring, in Python, round the island ------------------

MIX = (.38, .52, .72)
WATER_STEP = (3, 2, 1)
CLEAN = [c(.173, .302, .431), c(.255, .42, .573), c(.353, .525, .678), c(.498, .655, .776), c(.769, .859, .91)]


def ground_off(u, v, d):
    off = 0
    if fbm(u / 22, v / 16, 5) > .62: off -= 1
    if d < .3 and math.sin((u * .35 - v * .9) * .6 + fbm(u / 25, v / 25, 17) * 4) > .9: off += 1
    return off


def sheet(img):
    """1:1 art pixels round the island's south-west, shown at 3x, as if every piece had
    grown and the water were clean."""
    u0, v0, w, h = SIZE[0] // 2 - 330, SIZE[1] // 2 - 30, 320, 190
    px = img.load()
    out = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            u, v = u0 + x, v0 + y
            wx, wy = texel_world(u, v)
            tx, ty = world_to_tile(wx, wy)
            if island_fraction(tx, ty) < 1 or shore_fraction(tx, ty) > 1:
                out.putpixel((x, y), (int(.91 * 255), int(.8 * 255), int(.59 * 255))); continue
            d = depth_uv(u, v)
            wave = math.sin(wx * .0035 + wy * .008)
            wstep = round(max(0, min(4, 3 - 3 * smoothstep(.15, .85, d) + wave * .5)))
            band = band_of(d)
            r_, g_, b_, a_ = px[u, v]
            if a_:
                mat, off = r_, (g_ & 15) - 4
            else:
                mat, off = 1, ground_off(u, v, d)
            if band < 3:
                ramp = MATERIALS[mat][1]
                col = ramp[max(0, min(4, 2 + off))]
                tw = CLEAN[max(0, min(4, WATER_STEP[band] + round(wave * .6)))]
                k = MIX[band]
                col = [col[i] * (1 - k) + tw[i] * k for i in range(3)]
            else:
                col = CLEAN[max(0, wstep - (1 if (a_ and off <= -1 and mat != 1) else 0))]
            out.putpixel((x, y), tuple(int(k * 255) for k in col))
    out.resize((w * 3, h * 3), Image.NEAREST).save(SHEET_PNG)
    print("wrote", SHEET_PNG)


if __name__ == "__main__":
    main()

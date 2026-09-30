"""Mockup sheet for the lakebed seen through clean water.

Offline, from the project root:
  PYTHONPATH=<psd-extract venv site-packages> python tools/lakebed_mockup.py
Writes tools/last_lakebed_mockup.png. Not a pipeline: treatments to judge before
anything is built in the game.

Every panel is the same bit of lake: the island's beach top left, depth growing
towards the bottom right, a dirty stretch along the right with rubbish on it, and
the clean water between showing the bed.
(ground, rocks, a log, plants, animals) and then put through the water, the way
the shader would: its brightness moves the water's own ramp position up or down,
the depth takes that away, and the result is rounded to a palette step.
"""
import json, math, random
from PIL import Image, ImageDraw

P = 3             # screen px per art px on the sheet
W, H = 220, 132   # panel size in art px


def c(r, g, b): return (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5))


# palette.tres
RAMP = {
    "clean": [c(.173, .302, .431), c(.255, .42, .573), c(.353, .525, .678), c(.498, .655, .776), c(.769, .859, .91)],
    "hazy": [c(.142, .271, .336), c(.208, .37, .442), c(.287, .463, .529), c(.419, .578, .613), c(.66, .76, .745)],
    "murky": [c(.11, .24, .24), c(.16, .32, .31), c(.22, .4, .38), c(.34, .5, .45), c(.55, .66, .58)],
    "foul": [c(.091, .21, .148), c(.127, .274, .189), c(.169, .338, .231), c(.284, .427, .296), c(.46, .548, .404)],
    "dirty": [c(.071, .18, .055), c(.094, .227, .067), c(.118, .275, .082), c(.227, .353, .141), c(.369, .435, .227)],
}
STATES = ["clean", "hazy", "murky", "foul", "dirty"]
SAND = c(.91, .804, .592); SAND_DK = c(.78, .66, .46)
GRASS = c(.427, .529, .251); GRASS_DK = c(.196, .341, .114)
FOAM = c(.933, .965, .984); OUT = (18, 14, 12)
WOOD = c(.541, .235, .141)


def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t + .5) for i in range(3))
def lum(col): return (0.3 * col[0] + 0.59 * col[1] + 0.11 * col[2]) / 255


def hash2(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xffffffff
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


# ---- the scene -----------------------------------------------------------

ISLE = (-26, -34)          # middle of the island, off the panel's corner
ISLE_R = (96, 64)          # its drawn water edge (2:1, the game's ellipses)
LAWN_IN = 0.72             # lawn inside this share of the edge


def ring(x, y):
    return math.hypot((x - ISLE[0]) / ISLE_R[0], (y - ISLE[1]) / ISLE_R[1])


def depth(x, y):
    """0 at the water's edge, 1 where the bed is lost."""
    return max(0.0, min(1.0, (ring(x, y) - 1) / 1.35))


def state_at(x, y, soft=0.0):
    """0 clean .. 4 dirty; the dirty stretch runs down the right."""
    s = (x - 150 + y * 0.35) / 11 + (fbm(x / 22, y / 22, 41) - .5) * 2.4
    return int(max(0, min(4, round(s))))



def step(ramp, i): return ramp[int(max(0, min(4, i)))]


class Stamp:
    """A little picture on the bed: rows of letters, each a step offset."""
    def __init__(self, rows, kind):
        self.rows, self.kind = rows, kind


STAMPS = {
    "snail": Stamp([".oo.", "oSDo", "oDSoo"], "shell"),
    "mussels": Stamp(["MM.M", ".MMM"], "shell"),
}
OFFSET = {"S": 1, "D": -1, "o": -2, "M": -2}


def raster(shapes, heading, S=4, squash=.5, size=48, scale=1.0):
    """Rasterise labelled shapes drawn in a body frame (x forward) at `heading`, laid on
    the plane and squashed to the 2:1 view. Each shape is (label, kind, points) for a
    polygon or (label, 'line', points, width). Drawn at S x, in order, and each pixel
    keeps the label that covers most of it, so later shapes win a tie."""
    ca, sa = math.cos(heading), math.sin(heading)
    im = Image.new("L", (size * S, size * S), 0)
    dr = ImageDraw.Draw(im)

    def tr(p):
        x, y = p[0] * scale, p[1] * scale
        z = p[2] if len(p) > 2 else 0
        return ((x * ca - y * sa) * S + size * S / 2, ((x * sa + y * ca) * squash - z) * S + size * S / 2)
    for i, sh in enumerate(shapes):
        if sh[1] == "line":
            dr.line([tr(p) for p in sh[2]], fill=i + 1, width=max(1, int(sh[3] * S * scale)))
        else:
            dr.polygon([tr(p) for p in sh[2]], fill=i + 1)
    out = {}
    for y in range(size):
        for x in range(size):
            count = {}
            for yy in range(S):
                for xx in range(S):
                    v = im.getpixel((x * S + xx, y * S + yy))
                    if v: count[v] = count.get(v, 0) + 1
            if not count: continue
            v, n = max(count.items(), key=lambda kv: (kv[1], kv[0]))
            if sum(count.values()) >= S * S * .4:
                out[(x - size // 2, y - size // 2)] = shapes[v - 1][0]
    return out


def ellipse(cx, cy, rx, ry, n=14):
    return [(cx + math.cos(2 * math.pi * i / n) * rx, cy + math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


# ---- crayfish: drawn flat on the plane, a pixel of height --------------------------

def crayfish(heading, seed):
    """{(x, y): (off, kind)}: carapace and rostrum, five tail segments and a fan,
    two claws on bent arms with red tips, walking legs and long antennae. Seen from
    above at the game's 2:1; a lit rim on the carapace, the segments' seams a step
    down, and a dark outline round all of it but the antennae and legs."""
    r = random.Random(seed)
    open_ = r.uniform(.25, .5)
    shapes = []
    for s in (-1, 1):                                            # antennae, legs first: under
        shapes.append(("feeler", "line", [(4.5, s * .5), (8, s * (2 + r.random())), (12, s * (3.5 + r.random() * 2))], .3))
        for k in range(3):
            lx = 1.2 - k * 1.3
            shapes.append(("leg", "line", [(lx, s * 1.4), (lx - .4, s * 2.8), (lx - 1.2, s * 3.6)], .45))
    for s in (-1, 1):
        shapes.append(("arm", "line", [(2.8, s * 1.3), (4.4, s * 2.9), (6.0, s * 3.4)], 1.1))
        claw = [(5.6, s * 2.6), (7.4, s * 2.2), (10.4, s * (2.4 - open_ * 1.4)), (10.8, s * 2.9),
                (10.6, s * 3.6), (9.0, s * 4.6), (6.6, s * 4.6), (5.4, s * 3.8)]
        shapes.append(("claw", "poly", claw))
        shapes.append(("gap", "line", [(8.2, s * 3.1), (10.8, s * 3.1)], .45))
    for k in range(5):                                           # the tail, segment by segment
        x0 = -1 - k * 1.25
        wid = 1.5 - k * .16
        shapes.append(("seg%d" % (k % 2), "poly", ellipse(x0 - .6, 0, .8, wid)))
    shapes.append(("fan", "poly", [(-7, 0), (-8.8, -2), (-9.4, -.8), (-9.4, .8), (-8.8, 2)]))
    shapes.append(("shell", "poly", ellipse(1.2, 0, 2.6, 1.7, 18)))
    shapes.append(("rostrum", "poly", [(3.4, -.6), (5.2, 0), (3.4, .6)]))
    lab = raster(shapes, heading, scale=1.1, squash=.78)
    cells = set(lab)
    out = {}
    for (x, y), l in lab.items():
        if l == "feeler": out[(x, y)] = (-1, "crayfish"); continue
        if l == "leg": out[(x, y)] = (-1, "crayfish"); continue
        edge_up = (x, y - 1) not in cells or lab.get((x, y - 1)) in ("feeler", "leg")
        if l == "claw": off, kind = (1 if edge_up else 0), "claw"
        elif l == "arm": off, kind = (1 if edge_up else 0), "crayfish"
        elif l == "gap": off, kind = -2, "claw"
        elif l == "shell": off, kind = (1 if edge_up else 0), "crayfish"
        elif l == "rostrum": off, kind = 1, "crayfish"
        elif l == "seg0": off, kind = 0, "crayfish"
        elif l == "seg1": off, kind = -1, "crayfish"
        else: off, kind = 0, "crayfish"
        out[(x, y)] = (off, kind)
    body = {k for k, v in lab.items() if v not in ("feeler", "leg", "gap")}
    for (x, y) in list(body):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in body: out[q] = (-2, "crayfish")
    for (x, y) in list(body):                                    # a pixel of height: the shade under it
        q = (x, y + 2)
        if q not in out: out[q] = (-1, "ground")
    return out


# ---- water plants: standing up off the bed, side on ---------------------------------

def _plant_base(out, cx, w, rng):
    """A little heap of sand the roots are in, and the shade under it."""
    for dx in range(-w, w + 1):
        out.setdefault((cx + dx, 0), (1 if abs(dx) < w else 0, "ground"))
        if rng.random() > .3: out.setdefault((cx + dx, 1), (-1, "ground"))


def eelgrass(seed):
    """Ribbon blades from one root, curving over as they rise; the back blades a
    step darker, a lit edge up the near ones, pale tips."""
    r = random.Random(seed)
    out = {}
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
                out[(x + k, -1 - y)] = (off, "eelgrass")
    _plant_base(out, 0, 2, r)
    return out


def waterweed(seed):
    """Elodea: three or four wavy stems, a small leaf off each side of every row but
    in alternating lengths so the stem reads as a string of whorls; leaves lit on
    the left, shaded on the right, a bright tuft at each tip."""
    r = random.Random(seed)
    out = {}
    for s in range(r.randint(3, 4)):
        x0 = r.randint(-3, 3); h = r.randint(7, 14); ph = r.uniform(0, 6); amp = r.uniform(.6, 1.6)
        for y in range(h):
            x = x0 + round(math.sin(y * .5 + ph) * amp)
            out[(x, -1 - y)] = (-1, "weed")
            if y > 0:
                ln = 2 if y % 3 == 1 else 1
                for k in range(1, ln + 1):
                    out.setdefault((x - k, -1 - y - (k - 1)), (1 if k == ln else 0, "weed"))
                    out.setdefault((x + k, -1 - y - (k - 1)), (0 if k == ln else -1, "weed"))
        top = x0 + round(math.sin(h * .5 + ph) * amp)
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, 1)):
            out[(top + dx, -1 - h - dy)] = (1, "weed")
    _plant_base(out, 0, 3, r)
    return out


def hornwort(seed):
    """Coontail: a leaning stem with whorls of forked leaves at uneven gaps, the
    leaves curling upward and of uneven length, bunched and dark at the foot and
    thinning to a pale tip. A second, shorter stem beside it."""
    r = random.Random(seed)
    out = {}
    for stem in range(2):
        h = r.randint(10, 15) if stem == 0 else r.randint(6, 9)
        lean = r.uniform(-2, 2); x0 = 0 if stem == 0 else r.choice((-3, 3))
        y = 0
        while y < h:
            t = y / h
            x = x0 + round(lean * t * t)
            out[(x, -1 - y)] = (-1, "horn")
            if y > 0 and r.random() < .95:
                for sgn in (-1, 1):
                    reach = max(1, round((3.8 - 2.4 * t) * r.uniform(.8, 1.2)))
                    for k in range(1, reach + 1):
                        up = (k + 1) // 2 if r.random() < .7 else k // 2
                        tone = 1 if (k == reach and t > .45) else (0 if k == reach else -1)
                        out.setdefault((x + sgn * k, -1 - y - up), (tone, "horn"))
                    if reach >= 2 and r.random() < .5:
                        out.setdefault((x + sgn * reach, -2 - y - (reach + 1) // 2), (0, "horn"))
            y += r.choice((1, 1, 2))
        out[(x0 + round(lean), -1 - h)] = (1, "horn")
    _plant_base(out, 0, 3, r)
    return out


def pondweed(seed):
    """Potamogeton: a stem thick at the foot, broad pointed leaves off it at uneven
    heights, olive with a red cast, each lit along its top edge with a dark midrib
    and the odd leaf turned edge-on as a dark line."""
    r = random.Random(seed)
    out = {}
    h = r.randint(12, 17); lean = r.uniform(-1.5, 1.5)
    stem = {}
    for y in range(h):
        x = round(lean * (y / h) ** 1.5 * 2)
        stem[y] = x
        out[(x, -1 - y)] = (-1, "pond")
        if y < 4: out[(x + 1, -1 - y)] = (-2, "pond")
    side = r.choice((-1, 1)); y = 3
    while y < h:
        x = stem[y]; side = -side
        ln = r.randint(5, 7)
        if r.random() < .2:                                      # edge-on
            for k in range(1, ln):
                out[(x + side * k, -1 - y - k // 2)] = (-2, "pond")
        else:
            for k in range(1, ln + 1):
                u = k / ln
                half = 1 if .25 < u < .8 else 0
                cy = -1 - y - round(u * 2)
                out[(x + side * k, cy)] = (-1 if half else 0, "pond")
                if half:
                    out[(x + side * k, cy - 1)] = (1, "pond")
                    out[(x + side * k, cy + 1)] = (0, "pond")
        y += r.randint(1, 3)
    out[(stem[h - 1], -1 - h)] = (1, "pond")
    _plant_base(out, 0, 2, r)
    return out


def stonewort(seed):
    """Chara: a low, wide mound of branching candelabra stems crusted pale, dark
    inside where the stems crowd, lit along the tops."""
    r = random.Random(seed)
    out = {}
    for s in range(r.randint(7, 10)):
        x = r.uniform(-4, 4); a = r.uniform(-.9, .9); h = r.randint(4, 8)
        y = 0.0
        for i in range(h):
            a += r.gauss(0, .15)
            x += math.sin(a) * .9; y += math.cos(a) * .9
            out[(round(x), -1 - round(y))] = (0, "chara")
            if i % 2 == 1:
                for sgn in (-1, 1):
                    out.setdefault((round(x) + sgn, -2 - round(y)), (1, "chara"))
    for (x, y) in list(out):
        if (x, y - 1) in out and (x - 1, y) in out and (x + 1, y) in out: out[(x, y)] = (-1, "chara")
        elif (x, y - 1) not in out: out[(x, y)] = (1, "chara")
    _plant_base(out, 0, 4, r)
    return out


PLANTS = {"eelgrass": eelgrass, "waterweed": waterweed, "hornwort": hornwort,
          "pondweed": pondweed, "stonewort": stonewort}


def lay(bed, x0, y0, pix):
    for (x, y), v in pix.items(): bed[(x0 + x, y0 + y)] = v


# ---- rocks: the Forest pack's slices, sunk into the sand ---------------------------

ROCK_FILES = ["assets/Forest Isometric Pack Free/Rocks/Slice %d.png" % i for i in range(1, 6)]


def rock_sprite(i):
    """(w, h, {(x, y): (off, kind)}): brightness ranked into four steps, moss onto the
    weed ramp. The pack's dark outline is its own lowest rank."""
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
        out[(x, y)] = (off, "plant" if green(q) else "rock")
    return im.width, im.height, out


ROCKS = [rock_sprite(i) for i in range(len(ROCK_FILES))]


def sink(bed, x0, y0, w, h, pix, seed):
    """Stamp a picture on the bed with its foot buried: a wavy sand line two to four
    rows up the picture, a lit drift along it spilling a pixel past the sides, a
    shaded row of ground under it and a few grains knocked loose."""
    foot, top = {}, {}
    for (x, y) in pix:
        foot[x] = max(foot.get(x, -1), y)
        top[x] = min(top.get(x, 99), y)
    for (x, y), v in pix.items():
        bury = 2 + round(fbm(x / 3.0, seed, seed) * 3)
        bury = min(bury, (foot[x] - top[x]) // 2)
        line = foot[x] - bury
        if y > line + 1: bed[(x0 + x, y0 + y)] = (0, "ground")
        elif y == line + 1: bed[(x0 + x, y0 + y)] = (1, "ground")
        else: bed[(x0 + x, y0 + y)] = v
    xs = sorted(foot)
    for side, x in ((-1, xs[0]), (1, xs[-1])):           # drift past the sides
        for k in (1, 2):
            bed.setdefault((x0 + x + side * k, y0 + foot[x] - 2 + k), (1, "ground"))
    for x in xs[1:-1]:                                   # the shaded row under the foot
        if hash2(x, seed, 3) > .25:
            bed.setdefault((x0 + x, y0 + foot[x] + 1), (-1, "ground"))
    r = random.Random(seed)
    for _ in range(3 + w // 5):                          # grains knocked loose
        gx, gy = r.randint(-3, w + 2), foot[r.choice(xs)] + r.randint(-1, 3)
        bed.setdefault((x0 + gx, y0 + gy), (r.choice((1, -1, -2)), "rock"))


# ---- branches: a limb that wanders, forks and cracks ----------------------------

def branch(seed, length, angle, thick):
    """A fallen branch lying on the plane, drawn by rule: a wandering limb tapering
    from `thick` rows, a twig or two, bark crevices and knots, a pale broken end,
    ringed with a dark outline."""
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
    for (x, y) in sorted(body):                          # crevices and knots in the bark
        if body[(x, y)] == 0 and hash2(x, y, seed) > .7:
            body[(x, y)] = -2
            if hash2(x + 1, y, seed) > .5 and body.get((x + 1, y)) == 0: body[(x + 1, y)] = -2
    ca, sa = math.cos(angle), math.sin(angle) * .5
    end = min(body, key=lambda k: k[0] * ca + k[1] * sa)
    body[end] = 2                                        # the broken end, pale inner wood
    out = {k: (v, "wood") for k, v in body.items()}
    for (x, y) in body:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in body: out[(x + dx, y + dy)] = (-2, "wood")
    xs = [k[0] for k in out]; ys = [k[1] for k in out]
    x0, y0 = min(xs), min(ys)
    return max(xs) - x0 + 1, max(ys) - y0 + 1, {(x - x0, y - y0): v for (x, y), v in out.items()}


def lay_branch(bed, x0, y0, spr, seed):
    """Lay a branch and bury a stretch of it: sand over a few columns, lit on top,
    with a shaded row along its underside."""
    w, h, pix = spr
    r = random.Random(seed)
    b0 = r.randint(w // 4, w // 2); b1 = b0 + r.randint(3, 5)
    foot = {}
    for (x, y) in pix: foot[x] = max(foot.get(x, -1), y)
    for (x, y), v in pix.items():
        if b0 <= x <= b1 and y >= foot[x] - 2:
            bed[(x0 + x, y0 + y)] = (1 if y == foot[x] - 2 else 0, "ground")
        else:
            bed[(x0 + x, y0 + y)] = v
    for x, fy in foot.items():
        if hash2(x, seed, 5) > .35: bed.setdefault((x0 + x, y0 + fy + 1), (-1, "ground"))


# ---- fish: small bodies in three dimensions, lit, seen at the game's view -----------

def ramp5(*cols): return [c(*k) for k in cols]


FIN_RED = ramp5((.3, .08, .04), (.55, .16, .07), (.8, .32, .12), (.9, .5, .24), (.96, .72, .45))
# name: length, width, height, tail, body ramp, fin ramp, pattern
SPECIES = {
    "minnow": (10, 2.8, 3.4, 3.0, ramp5((.14, .17, .13), (.3, .34, .24), (.5, .53, .38), (.7, .7, .55), (.88, .87, .76)), None, "stripe"),
    "roach": (13, 3.2, 4.6, 3.4, ramp5((.1, .14, .2), (.24, .32, .4), (.48, .56, .62), (.72, .77, .8), (.9, .92, .92)), FIN_RED, None),
    "perch": (14, 3.6, 5.0, 3.4, ramp5((.1, .16, .08), (.24, .34, .14), (.45, .52, .2), (.66, .68, .32), (.85, .82, .5)), FIN_RED, "bars"),
    "rudd": (13, 3.2, 4.8, 3.4, ramp5((.2, .14, .05), (.42, .3, .1), (.66, .5, .18), (.84, .7, .32), (.95, .87, .55)), FIN_RED, None),
    "tench": (17, 4.4, 5.2, 4.0, ramp5((.08, .12, .06), (.18, .26, .12), (.3, .4, .18), (.46, .54, .28), (.62, .68, .42)), None, None),
    "carp": (21, 5.6, 6.8, 5.0, ramp5((.18, .11, .06), (.38, .24, .12), (.58, .4, .2), (.75, .58, .32), (.9, .78, .52)), None, "scales"),
}
LIGHT = (-.45, -.35, .82)          # from the upper left and above, in plane coordinates


def _norm(v):
    m = math.sqrt(sum(k * k for k in v)) or 1
    return tuple(k / m for k in v)


def frange(a, b, s):
    v = a
    while v <= b + 1e-9:
        yield v; v += s


def fish_render(sp, heading):
    """(pixels, shadow): pixels is {(x, y): colour} before the water, shadow the flat
    footprint on the bed. The body is a run of elliptic sections, fatter towards the
    head; a forked tail standing up, a dorsal fin, two pectorals. Every surface point
    is projected to the screen with a depth buffer and lit by its normal, the back a
    step darker, then ringed in the ramp's darkest step."""
    L, Wd, Hh, F, body, fin, pat = SPECIES[sp]
    fin = fin or body
    ca, sa = math.cos(heading), math.sin(heading)
    zb, flat = {}, set()

    def put(x, y, z, n, part, t):
        X, Y = x * ca - y * sa, x * sa + y * ca
        key = (round(X), round(Y * .5 - z * .8))
        dep = Y * .87 + z * .5
        if key not in zb or dep > zb[key][0]:
            n = _norm(n)
            nx, ny = n[0] * ca - n[1] * sa, n[0] * sa + n[1] * ca
            lit = nx * LIGHT[0] + ny * LIGHT[1] + n[2] * LIGHT[2]
            zb[key] = (dep, lit, part, t, n[2])
        if part == "body" or part == "pec": flat.add((round(X), round(Y * .5)))

    def prof(t): return math.sqrt(max(0, 1 - t * t)) ** .9 * (.62 + .38 * (t + 1) / 2)
    for t in frange(-1, 1, .35 / L):
        xf = t * L / 2
        w, h = Wd / 2 * prof(t), Hh / 2 * prof(t)
        for a in frange(0, 2 * math.pi, .12):
            put(xf, w * math.cos(a), h * math.sin(a), (0, math.cos(a) / max(w, .3), math.sin(a) / max(h, .3)), "body", t)
    for u in frange(0, 1, .06):                                  # the tail, standing up, forked
        half = Hh * (.12 + .3 * u)
        notch = max(0, u - .5) * 1.4
        for v in frange(-1, 1, .08):
            if abs(v) < notch: continue
            put(-L / 2 - u * F, v * half * .35, v * half, (0, .7, .7), "fin", -1)
    x0, x1 = -.15 * L, .2 * L                                    # the dorsal, taller at its front
    for x in frange(x0, x1, .3):
        t = x / (L / 2)
        top = Hh / 2 * prof(t)
        rise = Hh * .22 * (x - x0) / (x1 - x0)
        for z in frange(top, top + rise, .3):
            put(x, 0, z, (0, .5, .9), "fin", t)
    for s in (-1, 1):                                            # pectorals
        for x in frange(.08 * L, .26 * L, .3):
            t = x / (L / 2)
            w = Wd / 2 * prof(t)
            for k in frange(0, Wd * .5, .3):
                put(x - k * .6, s * (w + k), -Hh * .1, (0, 0, 1), "pec", t)
    px = {}
    for key, (dep, lit, part, t, nz) in zb.items():
        if part == "body":
            i = 2 + round(lit * 2.1)
            if nz > .6: i -= 1
            if pat == "bars" and -.6 < t < .6 and math.sin(t * math.pi * 3.5) > .55 and nz > -.3: i -= 1
            if pat == "stripe" and abs(nz) < .22: i -= 1
            if pat == "scales" and i == 3 and (key[0] + 2 * key[1]) % 3 == 0: i -= 1
            px[key] = step(body, i)
        else:
            px[key] = step(fin, 2 + round(lit * 1.5))
    for key in list(px):
        if any((key[0] + dx, key[1] + dy) not in zb for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            part = zb[key][2]
            px[key] = body[0] if part == "body" else lerp(fin[0], body[0], .5)
    ex, ey = L * .36, Wd * .32                                   # the eye, on the side nearer us
    best = None
    for s in (-1, 1):
        X, Y = ex * ca - s * ey * sa, ex * sa + s * ey * ca
        z = Hh * .12
        if best is None or Y * .87 + z * .5 > best[0]:
            best = (Y * .87 + z * .5, (round(X), round(Y * .5 - z * .8)))
    if best[1] in px and zb[best[1]][2] == "body": px[best[1]] = (14, 16, 18)
    return px, flat


# ---- the bed of the main scene ------------------------------------------------

def bbox(pix):
    xs = [k[0] for k in pix]; ys = [k[1] for k in pix]
    return min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1


def build_bed():
    bed = {}
    r = random.Random(7)
    spots = []

    def spot(w, h, tries=60):
        for _ in range(tries):
            x, y = r.randrange(0, W - w), r.randrange(0, H - h)
            if ring(x, y) > 1.06 and ring(x + w, y + h) > 1.06 and depth(x, y) < .8 and \
                    all(abs(x - sx) > (w + sw) / 2 + 2 or abs(y - sy) > (h + sh) / 2 + 2 for sx, sy, sw, sh in spots):
                spots.append((x, y, w, h)); return x, y
        return None
    for i in range(5):
        spr = branch(40 + i, r.randint(14, 24), r.uniform(-.6, .6) + (math.pi if r.random() < .5 else 0), r.choice((3, 3, 4)))
        at = spot(spr[0], spr[1])
        if at: lay_branch(bed, at[0], at[1], spr, 40 + i)
    for i in range(14):
        w, h, pix = ROCKS[r.choice((0, 1, 2, 3, 4, 2, 3))]
        at = spot(w, h)
        if at: sink(bed, at[0], at[1], w, h, pix, 90 + i)
    names = list(PLANTS)
    for i in range(34):
        pix = PLANTS[names[i % len(names)]](200 + i)
        x0, y0, w, h = bbox(pix)
        at = spot(w, h, 25)
        if at: lay(bed, at[0] - x0, at[1] - y0, pix)
    for i in range(6):
        pix = crayfish(r.uniform(0, 2 * math.pi), 300 + i)
        x0, y0, w, h = bbox(pix)
        at = spot(w, h, 25)
        if at: lay(bed, at[0] - x0, at[1] - y0, pix)
    for name, count in (("snail", 7), ("mussels", 8)):
        st = STAMPS[name]
        for _ in range(count):
            at = spot(len(st.rows[0]), len(st.rows), 20)
            if not at: continue
            for ry, row in enumerate(st.rows):
                for rx, ch in enumerate(row):
                    if ch != ".": bed[(at[0] + rx, at[1] + ry)] = (OFFSET[ch], st.kind)
    return bed


BED = build_bed()
FISH = [("minnow", 44, 74, .4), ("minnow", 54, 70, .5), ("minnow", 49, 81, .35), ("minnow", 60, 77, .45),
        ("perch", 112, 62, 2.6), ("roach", 92, 98, -2.2), ("carp", 60, 106, -.3), ("rudd", 128, 86, 2.9),
        ("tench", 28, 118, .15)]


def fish_map(fish, drop=None):
    """What the fish cover in the water, and their shadows on the bed, which fall
    further down the screen the deeper the water under them."""
    top, shadow = {}, set()
    for sp, fx, fy, a in fish:
        px, flat = fish_render(sp, a)
        dd = depth(fx, fy)
        dx, dy = drop or (3 + round(dd * 6), 8 + round(dd * 12))
        for (x, y), col in px.items(): top[(fx + x, fy + y)] = col
        for (x, y) in flat: shadow.add((fx + x + dx, fy + y + dy))
    return top, shadow


# ---- the water over it -----------------------------------------------------------

MAT = {
    "ground": [c(.42, .37, .27), c(.56, .5, .37), c(.7, .63, .47), c(.84, .76, .58), c(.94, .89, .74)],
    "plant": [c(.12, .24, .1), c(.2, .34, .14), c(.29, .44, .19), c(.43, .55, .25), c(.6, .7, .36)],
    "eelgrass": ramp5((.1, .2, .1), (.17, .32, .15), (.27, .45, .2), (.42, .58, .26), (.62, .74, .38)),
    "weed": ramp5((.08, .22, .1), (.14, .34, .14), (.24, .48, .2), (.4, .62, .28), (.6, .78, .4)),
    "horn": ramp5((.07, .16, .09), (.12, .26, .13), (.2, .36, .18), (.32, .48, .24), (.5, .62, .34)),
    "pond": ramp5((.14, .15, .07), (.27, .3, .11), (.42, .45, .17), (.58, .57, .25), (.76, .66, .38)),
    "chara": ramp5((.24, .3, .2), (.38, .46, .3), (.54, .62, .42), (.7, .76, .56), (.84, .88, .72)),
    "rock": [c(.2, .19, .18), c(.33, .31, .29), c(.47, .45, .41), c(.6, .58, .53), c(.74, .72, .66)],
    "wood": [c(.22, .12, .08), c(.36, .21, .13), c(.5, .32, .2), c(.64, .46, .31), c(.82, .7, .52)],
    "crayfish": ramp5((.16, .08, .05), (.34, .18, .1), (.52, .3, .16), (.68, .44, .24), (.84, .62, .38)),
    "claw": ramp5((.3, .08, .04), (.52, .16, .08), (.74, .3, .14), (.86, .46, .22), (.94, .66, .4)),
    "shell": ramp5((.14, .12, .1), (.3, .24, .18), (.5, .42, .3), (.7, .6, .44), (.86, .78, .62)),
}
BAND_AT = (.3, .58, .85)
WATER_STEP = (3, 2, 1)
HAZY_MORE = .22
MIX = (.25, .45, .68)
FISH_MIX = (.12, .22, .36, .5)     # fish swim over the bed: less water between them and us


def bed_ground(x, y):
    off = 0
    if fbm(x / 22, y / 16, 5) > .62: off -= 1
    if depth(x, y) < .3:
        rip = math.sin((x * 0.35 - y * 0.9) * 0.6 + fbm(x / 25, y / 25, 17) * 4)
        if rip > .9: off += 1
    return off


def rubbish_sprites():
    try:
        sheet = Image.open("assets/lake_objects.png").convert("RGBA")
        pieces = json.load(open("assets/pieces.json"))["pieces"]
    except OSError:
        return []
    out = []
    for p in pieces:
        x, y, w, h = p["region"]
        if p.get("sheet") == "lake_objects" and w <= 18 and h <= 18:
            out.append(sheet.crop((x, y, x + w, y + h)))
    return out


SPRITES = rubbish_sprites()


def wave(x, y): return math.sin(x * 0.07 + y * 0.16 + math.sin(y * 0.05) * 2)
def caustic(x, y): return abs(fbm(x / 13, y / 9, 61) - fbm(x / 11, y / 9, 67)) < 0.016


def shade(x, y, bed, fish_top, fish_shadow, dirty=False, flat_depth=None, flat_state=None, quiet=False):
    d = depth(x, y) if flat_depth is None else flat_depth
    st = 4 if dirty else (state_at(x, y) if flat_state is None else flat_state)
    ramp = RAMP[STATES[st]]
    w = 2.6 - d * 2.0 + wave(x, y) * 0.35
    col = step(ramp, round(w))
    band = next((i for i, at in enumerate(BAND_AT) if d < at), 3)
    if st <= 1 and not dirty:
        off, kind = bed.get((x, y), (0 if quiet else bed_ground(x, y), "ground"))
        shadowed = (x, y) in fish_shadow
        if shadowed: off = min(off, 0) - 2
        if band < 3:
            s = 2 + off
            if band < 2 and not quiet and kind == "ground" and caustic(x, y): s += 1
            k = MIX[band] + (HAZY_MORE if st == 1 else 0)
            col = lerp(step(MAT[kind], s), step(ramp, WATER_STEP[band] + round(wave(x, y) * 0.6)), min(1, k))
        elif shadowed or (off <= -1 and kind != "ground"):
            col = step(ramp, round(w) - 1)
    if not dirty and (x, y) in fish_top:
        if st <= 1:
            toward = step(ramp, WATER_STEP[band] if band < 3 else round(w))
            col = lerp(fish_top[(x, y)], toward, FISH_MIX[band] + (HAZY_MORE if st == 1 else 0))
        elif st == 2:
            col = lerp(col, (5, 15, 20), .45)
    return col


def panel(dirty=False):
    img = Image.new("RGB", (W, H))
    top, shadow = fish_map(FISH)
    for y in range(H):
        for x in range(W):
            rr = ring(x, y)
            if rr < 1:
                img.putpixel((x, y), GRASS if rr < LAWN_IN else (SAND if rr < .97 else SAND_DK)); continue
            col = shade(x, y, BED, top, shadow, dirty)
            if rr < 1.035: col = FOAM if hash2(x // 2, y, 4) > .3 else col
            img.putpixel((x, y), col)
    rg = random.Random(3)
    for _ in range(46):
        x, y = rg.randrange(0, W - 12), rg.randrange(0, H - 12)
        if ring(x, y) < 1.08 or state_at(x + 5, y + 5) < 3 or not SPRITES: continue
        spr = rg.choice(SPRITES); img.paste(spr, (x, y), spr)
    return img


def parts():
    """The parts on shallow clean water, on plain sand: the five plants twice, four
    crayfish, the snails and mussels, and the six fish at three headings each."""
    bed, fishes = {}, []
    names = list(PLANTS)
    for i in range(10):
        lay(bed, 10 + i * 21, 24, PLANTS[names[i % 5]](500 + i))
    for i, a in enumerate((0.3, 2.5, -1.2, 1.4)):
        lay(bed, 18 + i * 34, 42, crayfish(a, 600 + i))
    for i, name in enumerate(("snail", "mussels", "snail", "mussels")):
        st = STAMPS[name]
        for ry, row in enumerate(st.rows):
            for rx, ch in enumerate(row):
                if ch != ".": bed[(160 + i * 14 + rx, 40 + ry)] = (OFFSET[ch], st.kind)
    for col, sp in enumerate(SPECIES):
        for row, a in enumerate((.3, 2.7, -1.3)):
            fishes.append((sp, 18 + col * 36, 66 + row * 22, a))
    top, shadow = {}, set()
    for sp, fx, fy, a in fishes:
        px, flat = fish_render(sp, a)
        for (x, y), cc in px.items(): top[(fx + x, fy + y)] = cc
        for (x, y) in flat: shadow.add((fx + x + 4, fy + y + 9))
    img = Image.new("RGB", (W, H))
    for y in range(H):
        for xx in range(W):
            img.putpixel((xx, y), shade(xx, y, bed, top, shadow, flat_depth=.2, flat_state=0, quiet=True))
    return img


main = panel()
part = parts()
panels = [
    ("Bed, strong hue: plants, crayfish, lit fish", main),
    ("Parts: plants x5, crayfish, snails, fish (minnow roach perch rudd tench carp)", part),
    ("2x shallows", main.crop((10, 30, 120, 96)).resize((W, H), Image.NEAREST)),
    ("Parts 2x: fish", part.crop((0, 56, 110, 122)).resize((W, H), Image.NEAREST)),
    ("Parts 2x: plants and crayfish", part.crop((0, 4, 110, 70)).resize((W, H), Image.NEAREST)),
    ("Parts 2x: fish, the rest", part.crop((110, 56, 220, 122)).resize((W, H), Image.NEAREST)),
]

cols, gap, lab = 2, 14, 22
rows = (len(panels) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (W * P + gap) + gap, rows * (H * P + lab + gap) + gap), (30, 30, 34))
dr = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(panels):
    x = gap + (i % cols) * (W * P + gap); y = gap + (i // cols) * (H * P + lab + gap)
    dr.text((x, y + 5), name, fill=(235, 235, 235))
    sheet.paste(im.resize((W * P, H * P), Image.NEAREST), (x, y + lab))
sheet.save("tools/last_lakebed_mockup.png"); print("wrote tools/last_lakebed_mockup.png", sheet.size)

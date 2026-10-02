"""Mockup for redrawing the cast net as pixel art (2026-10-02, /grill-me with Richard).

Offline only; nothing in the game reads it. Second pass, after Richard picked look A (diamond
mesh, 12 px cells, a dark pixel under each strand) and asked for a lighter brown and a much
more natural bend.

The net is a surface: plane radius rho 0..1 (crown to rim) and bearing theta. At rest it is a
low dome over the mouth's ellipse. Hauled, it is laid out again rather than warped as a
picture:

  - the crown leads towards the rope, lifted a little out of the water by the line
  - the rim purses into a teardrop that drags behind it, pinched hardest at the front where
    the bridle gathers it, so the strands from the crown to the front rim are short and the
    ones to the back are long: the cells stretch along the pull, as a net's do
  - the back of the bag sags and spreads with the load, and sways a little from side to side
  - the front of the rim tips up towards the crown

Strands are worked out in (rho, theta) with the cell held at a fixed size in world px, so a
wider net has more cells rather than bigger ones; the spoke count halves every time the
radius does, with a tuck ring over each seam. Each strand is drawn as a connected
one-pixel line, far side (where the surface folds over) first in a shaded tone.

    PYTHONPATH=<psd-extract venv site-packages> python tools/net_mockup.py

Writes tools/last_net_mockup.png.
"""

import json
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = "tools/last_net_mockup.png"


def rgb(r, g, b):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


# Cord: a lighter brown than the hand line (net.gd ROPE_CORE 140,97,54), Richard's ask.
CORD = (168, 124, 76)
CORD_LIT = (204, 162, 108)
CORD_BACK = (116, 80, 46)
SHADE = (44, 29, 17)
LEAD = [(30, 32, 38), (78, 82, 92), (138, 144, 156)]
GOLD = (255, 214, 89)
GOLD_LIT = (255, 240, 170)
GOLD_BACK = (186, 132, 40)
GOLD_SHADE = (70, 44, 10)

WATER_DIRTY = [rgb(0.071, 0.18, 0.055), rgb(0.094, 0.227, 0.067), rgb(0.118, 0.275, 0.082)]
WATER_CLEAN = [rgb(0.173, 0.302, 0.431), rgb(0.255, 0.42, 0.573), rgb(0.353, 0.525, 0.678)]

CELL = 12

# The haul's shape, as fractions of the open mouth's half-width W, at full haul.
LEAD_OUT = 0.35     # how far the crown runs ahead of where it lay
RIM_BACK = 0.2      # how far the middle of the bag falls behind
TIP_GAP = 0.1       # how far inside the bag's front tip the crown sits
REAR = 0.85         # the back half of the bag, as a share of the open mouth
PURSE_ACROSS = 0.32 # how much narrower the bag is across the pull
PINCH = 0.55        # extra narrowing towards the front, where the bridle gathers the rim
CROWN_LIFT = 0.1    # the crown lifted out of the water by the line
RIM_TIP = 0.08      # the front of the rim tipped up after it
SAG = 0.22          # the back of the bag sinking under a full load
SPREAD = 0.18       # and widening under it
MIN_GAP = 3.5       # screen px between neighbouring strands before the mesh is thinned
SWAY = 0.07         # the bag swinging side to side as it is dragged


# ---------------------------------------------------------------------------------------
# Borrowed art and the water.

def load_sprites():
    pieces = json.load(open("assets/pieces.json"))
    sheet = Image.open("assets/lake_objects.png").convert("RGBA")
    out = []
    for p in pieces["pieces"]:
        if p.get("sheet") != "lake_objects":
            continue
        x, y, w, h = p["region"]
        if 6 <= w <= 18 and 6 <= h <= 18:
            out.append(sheet.crop((x, y, x + w, y + h)))
    random.Random(4).shuffle(out)
    return out


def load_angler():
    d = json.load(open("assets/character.json"))
    sheet = Image.open("assets/character.png").convert("RGBA")
    x, y, w, h = d["poses"]["idle_east"][0]["region"]
    im = sheet.crop((x, y, x + w, y + h))
    return im.crop(im.getbbox())


def water(w, h, ramp, seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), ramp[1] + (255,))
    px = img.load()
    ph = rng.random() * 6
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            t = math.sin(x * 0.045 + y * 0.11 + ph) + 0.6 * math.sin(x * 0.013 - y * 0.07 + ph * 2)
            c = ramp[1 + (1 if t > 0.9 else 0) - (1 if t < -0.9 else 0)]
            for dy in range(2):
                for dx in range(2):
                    if x + dx < w and y + dy < h:
                        px[x + dx, y + dy] = c + (255,)
    return img


def scatter_rubbish(img, sprites, count, seed, keep_out=None):
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(count):
        s = sprites[rng.randrange(len(sprites))]
        x = rng.randrange(0, max(1, w - s.width))
        y = rng.randrange(0, max(1, h - s.height))
        if keep_out and keep_out(x + s.width / 2, y + s.height / 2):
            continue
        img.alpha_composite(s, (x, y))


# ---------------------------------------------------------------------------------------
# The net's shape.

def shape(W, H, *, pull=(-1.0, 0.0), haul=0.0, load=0.0, sway=0.0, squash=1.0,
          wobble=0.0, wob_phase=0.0):
    """(rho, theta) -> (screen x, screen y, depth key), relative to where the net lies."""
    ux, uy = pull
    n = math.hypot(ux, uy)
    ux, uy = ux / n, uy / n
    vx, vy = -uy, ux  # across the pull
    heading = math.atan2(uy, ux)

    def at(rho, theta):
        rho = np.asarray(rho, dtype=float)
        theta = np.asarray(theta, dtype=float)
        phi = theta - heading
        cf = np.cos(phi)  # 1 at the front of the rim (towards the rope), -1 at the back
        sf = np.sin(phi)
        front = np.clip(cf, 0, 1)
        back = np.clip(-cf, 0, 1)
        wob = 1.0 + wobble * np.sin(3 * theta + wob_phase) + wobble * 0.5 * np.sin(5 * theta - wob_phase)
        # The rim, laid out in pull coordinates (along, across).
        # The rim pulled into a pear: its front tip just ahead of the crown, its back half
        # dragging behind, narrowest where the bridle gathers it.
        mid = -RIM_BACK * haul
        reach_front = (1 - haul) + haul * (LEAD_OUT + RIM_BACK + TIP_GAP)
        reach_back = (1 - haul) + haul * REAR
        along_r = mid + cf * np.where(cf > 0, reach_front, reach_back) * wob
        across_r = ((1 - PURSE_ACROSS * haul) * (1 - PINCH * haul * np.power(front, 1.5))
                    * (1 + SPREAD * load * back) * sf * wob)
        # The crown, and every point between them: short strands to the front, long to the
        # back, which is what stretches the cells along the pull.
        crown_a = LEAD_OUT * haul
        s = np.power(rho, 1.0 + 0.35 * haul)
        a = crown_a + (along_r - crown_a) * s
        b = across_r * s
        # The bag swings: more the further back down it a point hangs.
        b = b + SWAY * haul * sway * np.power(rho, 2) * np.clip(-cf * 0.5 + 0.5, 0, 1)
        px = W * (a * ux + b * vx)
        py = W * (a * uy + b * vy)
        z = (H + CROWN_LIFT * W * haul) * np.power(np.clip(1 - rho, 0, 1), 1.4)
        z = z + RIM_TIP * W * haul * front * np.power(rho, 3)
        z = z - SAG * W * load * np.sin(np.pi * np.clip(rho, 0, 1)) * (0.35 + 0.65 * back)
        sx = px
        sy = py * 0.5 * squash - z
        return sx, sy, 2 * py + z

    return at


def strands(W, cell=CELL):
    """The diamond mesh as (rho, theta) polylines."""
    n_rim = max(8, int(round(2 * math.pi * W / cell / 4.0)) * 4)
    out = []
    lvl = 0
    hi = 1.0
    while True:
        lo = hi * 0.5
        n = n_rim // (2 ** lvl)
        last = n < 8 or hi * W < cell * 1.5
        if last:
            lo = 0.04
        rho = np.linspace(lo, hi, max(2, int((hi - lo) * W / 0.6)))
        for k in range(n):
            for sign in (1, -1):
                out.append((rho, 2 * math.pi * (k + sign * rho * W / cell) / n, k, n))
        if hi < 1.0:
            t = np.linspace(0, 2 * math.pi, max(24, int(2 * math.pi * W * hi / 0.6)))
            out.append((np.full_like(t, hi), t, 0, 0))
        if last:
            break
        hi = lo
        lvl += 1
    return out


def facing(at, rho, theta):
    """Whether the surface shows its near face here: the sign of its screen Jacobian against
    a flat net's. Where the bag folds over itself the sign flips."""
    e = 1e-3
    x1, y1, _ = at(rho + e, theta)
    x0, y0, _ = at(rho - e, theta)
    x3, y3, _ = at(rho, theta + e)
    x2, y2, _ = at(rho, theta - e)
    j = (x1 - x0) * (y3 - y2) - (y1 - y0) * (x3 - x2)
    return j > 0


def strand_gap(at, rho, theta, n):
    """The screen distance, across the strand, to its neighbour one step round the ring."""
    e = 1e-3
    x0, y0, _ = at(rho, theta)
    x1, y1, _ = at(np.minimum(rho + e, 1.0), theta + (theta[-1] - theta[0]) / max(rho[-1] - rho[0], 1e-6) * e)
    tx, ty = x1 - x0, y1 - y0
    dt = 2 * math.pi / n
    x2, y2, _ = at(rho, theta + dt)
    dx, dy = x2 - x0, y2 - y0
    return np.abs(tx * dy - ty * dx) / np.maximum(np.hypot(tx, ty), 1e-9)


def squeeze(at, rho, theta, W):
    """How much of its resting area the net keeps here, 1 lying flat. Where the bridle
    gathers it the cells crush together, and a strand drawn through every one of them is a
    solid wedge of cord."""
    e = 1e-3
    x1, y1, _ = at(rho + e, theta)
    x0, y0, _ = at(rho - e, theta)
    x3, y3, _ = at(rho, theta + e)
    x2, y2, _ = at(rho, theta - e)
    j = np.abs((x1 - x0) * (y3 - y2) - (y1 - y0) * (x3 - x2)) / (4 * e * e)
    return j / np.maximum(0.5 * rho * W * W, 1e-6)


def draw_net(img, cx, cy, W, at, *, catch=(), gold=False, beads=True, seed=1):
    core, lit_c, back_c, shade_c = (GOLD, GOLD_LIT, GOLD_BACK, GOLD_SHADE) if gold else (CORD, CORD_LIT, CORD_BACK, SHADE)
    w, h = img.size

    # The catch goes under the mesh, settled into the back of the bag.
    rng = random.Random(seed)
    placed = []
    for s in catch:
        th = math.pi + (rng.random() - 0.5) * 2.4
        r = 0.25 + 0.5 * math.sqrt(rng.random())
        # bearing measured off the pull: the shape works in absolute theta
        placed.append((r, th, s))
    for r, th, s in placed:
        sx, sy, _ = at(np.array([r]), np.array([th + at_heading(at)]))
        img.alpha_composite(s, (int(round(cx + sx[0] - s.width / 2)), int(round(cy + sy[0] - s.height * 0.8))))

    pieces = []
    for rr, tt, k, n in strands(W):
        sx, sy, key = at(rr, tt)
        face = facing(at, rr, tt)
        # Thin the mesh where it is crushed: the gap to the next strand of the same family,
        # measured on screen across the strand, and every other (every fourth...) strand
        # dropped until what is left stands MIN_GAP apart.
        if n:
            gap = strand_gap(at, rr, tt, n)
            every = np.ones_like(gap, dtype=int)
            for m in (2, 4, 8):
                every = np.where(gap * every < MIN_GAP, m, every)
            shown = (k % every) == 0
        else:
            shown = np.ones_like(rr, dtype=bool)
        state = np.where(shown, np.where(face, 1, 0), -1)
        i0 = 0
        for i in range(1, len(rr) + 1):
            if i == len(rr) or state[i] != state[i0]:
                seg = slice(i0, min(i + 1, len(rr)))
                pts = [(round(cx + x), round(cy + y)) for x, y in zip(sx[seg], sy[seg])]
                if state[i0] >= 0 and len(pts) >= 2:
                    pieces.append((float(np.mean(key[seg])), int(state[i0]), pts))
                i0 = i
    pieces.sort(key=lambda p: p[0])
    layer = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(layer)
    for _, tone, pts in pieces:
        ld.line(pts, fill=tone + 1, width=1)

    # The rim cord: two pixels deep, lit along its top.
    tr = np.linspace(0, 2 * math.pi, int(2 * math.pi * W / 0.4) + 1)
    rx, ry, _ = at(np.ones_like(tr), tr)
    pts = [(round(cx + x), round(cy + y)) for x, y in zip(rx, ry)]
    ld.line([(x, y + 1) for x, y in pts], fill=2, width=1)
    ld.line(pts, fill=3, width=1)

    grid = np.array(layer).astype(np.int16) - 1
    mask = grid >= 0
    ring = np.zeros_like(mask)
    ring[1:, :] |= mask[:-1, :]
    ring &= ~mask
    out = np.array(img)
    out[ring, 0:3] = shade_c
    out[ring, 3] = 255
    for t, c in ((0, back_c), (1, core), (2, lit_c)):
        m = grid == t
        out[m, 0:3] = c
        out[m, 3] = 255
    img.paste(Image.fromarray(out))

    dr = ImageDraw.Draw(img)
    kx, ky, _ = at(np.array([0.0]), np.array([0.0]))
    kx, ky = int(round(cx + kx[0])), int(round(cy + ky[0]))
    dr.rectangle((kx - 2, ky - 1, kx + 2, ky + 1), fill=shade_c)
    dr.rectangle((kx - 1, ky - 1, kx + 1, ky), fill=lit_c)

    if beads:
        n = max(6, int(2 * math.pi * W / 9))
        bt = np.linspace(0, 2 * math.pi, n, endpoint=False)
        bx, by, bk = at(np.ones_like(bt), bt)
        for i in np.argsort(bk):
            x = int(round(cx + bx[i]))
            y = int(round(cy + by[i])) + 1
            dr.rectangle((x - 2, y - 1, x + 2, y + 2), fill=SHADE)
            dr.rectangle((x - 1, y, x + 1, y + 1), fill=LEAD[1])
            dr.point((x + 1, y), fill=LEAD[2])
            dr.point((x - 1, y + 1), fill=LEAD[0])
    return kx, ky


_HEADINGS = {}


def at_heading(at):
    return _HEADINGS.get(id(at), 0.0)


def net_shape(W, H, **kw):
    at = shape(W, H, **kw)
    pull = kw.get("pull", (-1.0, 0.0))
    _HEADINGS[id(at)] = math.atan2(pull[1], pull[0])
    return at


def draw_bundle(img, cx, cy, size, seed=3):
    rng = random.Random(seed)
    w, h = img.size
    layer = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(layer)
    for k in range(5):
        a = size * (0.55 + 0.12 * k) * 0.5
        b = a * (0.5 + 0.1 * rng.random())
        ox = (rng.random() - 0.5) * size * 0.3
        oy = (rng.random() - 0.5) * size * 0.2
        tilt = (rng.random() - 0.5) * 0.6
        pts = []
        for t in np.linspace(0, 2 * math.pi, 120):
            x, y = a * math.cos(t), b * math.sin(t)
            pts.append((round(cx + ox + x * math.cos(tilt) - y * math.sin(tilt)),
                        round(cy + oy + x * math.sin(tilt) + y * math.cos(tilt))))
        ld.line(pts, fill=2 if k % 2 else 3, width=1)
    grid = np.array(layer).astype(np.int16) - 1
    mask = grid >= 0
    grow = mask.copy()
    grow[1:, :] |= mask[:-1, :]
    grow[:-1, :] |= mask[1:, :]
    grow[:, 1:] |= mask[:, :-1]
    grow[:, :-1] |= mask[:, 1:]
    out = np.array(img)
    out[grow & ~mask, 0:3] = SHADE
    out[grow & ~mask, 3] = 255
    for t, c in ((1, CORD), (2, CORD_LIT)):
        m = grid == t
        out[m, 0:3] = c
        out[m, 3] = 255
    img.paste(Image.fromarray(out))


def draw_rope(img, a, b, sag=8.0):
    dr = ImageDraw.Draw(img)
    pts = [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + sag * math.sin(math.pi * t))
           for t in (i / 40 for i in range(41))]
    dr.line(pts, fill=rgb(0.24, 0.15, 0.08), width=3)
    dr.line(pts, fill=rgb(0.55, 0.38, 0.21), width=1)


# ---------------------------------------------------------------------------------------
# The sheet.

def up(im, k):
    return im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)


def font(size):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", size)
    except OSError:
        return ImageFont.load_default(size)


def label(im, text):
    lab = Image.new("RGBA", (im.width, im.height + 26), (16, 16, 18, 255))
    lab.alpha_composite(im, (0, 26))
    ImageDraw.Draw(lab).text((6, 4), text, fill=(235, 230, 210), font=font(16))
    return lab


def main():
    sprites = load_sprites()
    angler = load_angler()
    rows = []
    W = 72
    H = W * 0.16

    def panel(Wn, ramp, seed, draw, k=2, pw=None, ph=None):
        pw = pw or int(2 * Wn + 60)
        ph = ph or int(Wn * 1.25 + 40)
        im = water(pw, ph, ramp, seed)
        cx, cy = pw / 2, ph * 0.55
        scatter_rubbish(im, sprites, int(pw * ph / 1100), seed,
                        keep_out=lambda x, y: ((x - cx) / (Wn + 10)) ** 2 + ((y - cy) / (Wn * 0.6 + 10)) ** 2 < 1)
        draw(im, cx, cy)
        return up(im, k)

    # Row 1: the pick, in the lighter brown.
    tiles = []
    for ramp, name, seed in ((WATER_DIRTY, "dirty", 11), (WATER_CLEAN, "clean", 12)):
        tiles.append(label(panel(W, ramp, seed, lambda im, cx, cy: draw_net(
            im, cx, cy, W, net_shape(W, H), catch=sprites[:5]), k=3),
            f"A, lighter brown, lying ({name}), 3x"))
    rows.append(tiles)

    # Row 2: hauled left, empty, haul 0 -> 1.
    tiles = []
    for haul in (0.0, 0.25, 0.5, 0.75, 1.0):
        tiles.append(label(panel(W, WATER_DIRTY, 21, lambda im, cx, cy, haul=haul: draw_net(
            im, cx, cy, W, net_shape(W, H, haul=haul))), f"empty, haul {haul:.2f}"))
    rows.append(tiles)

    # Row 3: the same with a load coming in.
    tiles = []
    for i, haul in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
        load = (i + 1) / 5
        tiles.append(label(panel(W, WATER_DIRTY, 22, lambda im, cx, cy, haul=haul, load=load, i=i: draw_net(
            im, cx, cy, W, net_shape(W, H, haul=haul, load=load, sway=math.sin(i * 1.7)),
            catch=sprites[:2 + 2 * i], seed=i)), f"loaded {load:.1f}, haul {haul:.2f}"))
    rows.append(tiles)

    # Row 4: pulled every way the angler can stand, haul 0.8, loaded.
    tiles = []
    for pull, name in (((-1, 0), "towards left"), ((-1, -0.6), "up-left"), ((0, -1), "up"),
                       ((0.3, 1), "down (towards camera)"), ((1, 0.4), "right")):
        tiles.append(label(panel(W, WATER_CLEAN, 31, lambda im, cx, cy, pull=pull: draw_net(
            im, cx, cy, W, net_shape(W, H, pull=pull, haul=0.8, load=0.7, sway=0.6),
            catch=sprites[:7], seed=3)), f"pulled {name}"))
    rows.append(tiles)

    # Row 5: a throw, bundle to flat.
    tiles = []
    for i, t in enumerate((0.0, 0.2, 0.4, 0.6, 0.8, 1.0)):
        def throw(im, cx, cy, t=t, i=i):
            if t < 0.15:
                draw_bundle(im, cx, cy - W * 0.35, 18)
                return
            e = 1 - (1 - (t - 0.15) / 0.85) ** 2
            Wt = W * (0.22 + 0.78 * e)
            Ht = Wt * (0.85 * (1 - e) + 0.16 * e)
            draw_net(im, cx, cy - W * 0.35 * (1 - e), Wt,
                     net_shape(Wt, Ht, squash=0.6 + 0.4 * e, wobble=0.14 * (1 - e), wob_phase=i * 0.9))
        tiles.append(label(panel(W, WATER_DIRTY, 40, throw), f"throw {i + 1}"))
    rows.append(tiles)

    # Row 6: in play at about game zoom (1.5 screen px an art px): angler, rope, a net
    # hauled towards him with a catch, gold for the lucky cast, and a big late-game net.
    tiles = []
    for gold, Wn, haul, name in ((False, 70, 0.7, "hauled, 1.5x"), (True, 70, 0.7, "lucky, 1.5x"),
                                 (False, 150, 0.6, "late-game width, 1.5x")):
        sw, sh = int(Wn * 2 + 220), int(Wn * 1.3 + 70)
        im = water(sw, sh, WATER_CLEAN if gold else WATER_DIRTY, 60 + Wn)
        nx, ny = sw - Wn - 30, sh * 0.55
        scatter_rubbish(im, sprites, int(sw * sh / 900), 61,
                        keep_out=lambda x, y: ((x - nx) / (Wn + 15)) ** 2 + ((y - ny) / (Wn * 0.6 + 15)) ** 2 < 1 or x < 60)
        ax, ay = 26, sh * 0.5
        im.alpha_composite(angler, (ax, int(ay - angler.height / 2)))
        hx, hy = ax + angler.width - 4, ay - 4
        pull = (hx - nx, (hy - ny) * 2)
        at = net_shape(Wn, Wn * 0.16, pull=pull, haul=haul, load=0.8, sway=0.5)
        kx, ky = draw_net(im, nx, ny, Wn, at, catch=sprites[5:5 + Wn // 8], gold=gold, seed=7)
        draw_rope(im, (hx, hy), (kx, ky - 3), sag=10)
        tiles.append(label(up(im, 1.5), name))
    rows.append(tiles)

    gap = 12
    widths = [sum(t.width for t in r) + gap * (len(r) - 1) for r in rows]
    heights = [max(t.height for t in r) for r in rows]
    sheet = Image.new("RGBA", (max(widths) + 2 * gap, sum(heights) + gap * (len(rows) + 1)), (10, 10, 12, 255))
    y = gap
    for r, hgt in zip(rows, heights):
        x = gap
        for t in r:
            sheet.alpha_composite(t, (x, y))
            x += t.width + gap
        y += hgt + gap
    sheet.convert("RGB").save(OUT)
    print(OUT, sheet.size)


if __name__ == "__main__":
    main()

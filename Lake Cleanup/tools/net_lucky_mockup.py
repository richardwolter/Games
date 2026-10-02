"""Mockup for the lucky cast's net (2026-10-02, /grill-me with Richard: "the luck net color
looks ugly... something to really make it pop and look beautiful").

Offline only. Decided before it was drawn: the mesh stays the ordinary tan cord, the gold is
on the accents (rim cord and lead beads), and the shine is the finds' own language, four-point
pixel stars and single-pixel sparks. A burst as the net lands (light running round the rim
both ways from the front, a burst of stars), then a glint sweeping the cord every ~1.5 s and a
few stars twinkling for the rest of the haul.

Rows, each a strip of moments: today's flat gold for reference, then three variants:
  A  gold rim and beads only
  B  A, with the gold creeping in from the rim over the outer cells
  C  B, with gold knots where the strands cross

Shares the shape and the mesh with tools/net_mockup.py (with the 2026-10-02 drag fix: no
crown lift, the dome capped).

    PYTHONPATH=<psd-extract venv site-packages> python tools/net_lucky_mockup.py

Writes tools/last_net_lucky_mockup.png.
"""

import math
import random

import numpy as np
from PIL import Image, ImageDraw

import net_mockup as nm

OUT = "tools/last_net_lucky_mockup.png"

# The game's net as it stands now: nothing lifts the crown, the rim does not tip.
nm.CROWN_LIFT = 0.0
nm.RIM_TIP = 0.0

CORD = nm.CORD
CORD_LIT = nm.CORD_LIT
CORD_BACK = nm.CORD_BACK
SHADE = nm.SHADE

# The finds' gold (LakeGrid.GLINT_TINT 255,214,89) as a ramp, deep to white.
GOLD_DEEP = (122, 76, 18)
GOLD_LOW = (196, 136, 34)
GOLD = (240, 190, 64)
GOLD_LIT = (255, 226, 128)
GOLD_PALE = (255, 244, 196)
WHITE = (255, 255, 255)
GOLD_SHADE = (70, 40, 8)

# The flat gold the game draws today.
TODAY = ((255, 214, 89), (255, 240, 170), (186, 132, 40), (70, 44, 10))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def lit(c, amount):
    """Brighten a cord colour towards the glint: tan goes pale gold, gold goes white."""
    if amount <= 0:
        return c
    if c in (GOLD, GOLD_LIT, GOLD_LOW):
        return mix(c, WHITE, amount)
    return mix(c, GOLD_PALE, amount)


def star(px, w, h, x, y, size):
    """A four-point star of whole pixels: a white middle, gold arms out to `size` px."""
    arm = int(round(size))
    if arm <= 0:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = GOLD_PALE + (255,)
        return
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(1, arm + 1):
            X, Y = x + dx * k, y + dy * k
            if 0 <= X < w and 0 <= Y < h:
                px[X, Y] = (GOLD_LIT if k < arm else GOLD) + (255,)
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = WHITE + (255,)
    if arm >= 2:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            X, Y = x + dx, y + dy
            if 0 <= X < w and 0 <= Y < h:
                px[X, Y] = GOLD_PALE + (255,)


def burst_at(theta, landed):
    """How lit the rim is at bearing `theta`, `landed` seconds after the splash: two heads of
    light running round from the front (theta = pi/2, the near side) both ways over the first
    0.4 s, each dragging a fading tail, the whole fading out by 0.75 s."""
    if landed is None or landed >= 0.75:
        return 0.0
    run = min(landed / 0.4, 1.0)
    gone = abs(((theta - math.pi / 2 + math.pi) % (2 * math.pi)) - math.pi)
    behind = run * math.pi - gone
    if not 0 <= behind < 1.2:
        return 0.0
    return (1.0 - behind / 1.2) * (1.0 - max(0.0, (landed - 0.4) / 0.35))


def draw_lucky(img, cx, cy, W, at, variant, landed, glint_t, catch=(), seed=1):
    """`landed` is seconds since the net hit the water (the burst), `glint_t` the glint's
    clock (None for no glint). `variant` is 'today', 'A', 'B' or 'C'."""
    w, h = img.size
    rng = random.Random(seed)

    for s in catch:
        th = rng.random() * 2 * math.pi
        r = 0.2 + 0.5 * math.sqrt(rng.random())
        sx, sy, _ = at(np.array([r]), np.array([th]))
        img.alpha_composite(s, (int(round(cx + sx[0] - s.width / 2)), int(round(cy + sy[0] - s.height * 0.8))))

    # kind: 0 none, 1 strand front, 2 strand back, 3 rim body, 4 rim top
    kind = Image.new("L", (w, h), 0)
    rho_l = Image.new("L", (w, h), 0)
    theta_l = Image.new("L", (w, h), 0)
    kd = ImageDraw.Draw(kind)
    rd = ImageDraw.Draw(rho_l)
    td = ImageDraw.Draw(theta_l)

    pieces = []
    for rr, tt, k, n in nm.strands(W):
        sx, sy, key = at(rr, tt)
        face = nm.facing(at, rr, tt)
        if n:
            gap = nm.strand_gap(at, rr, tt, n)
            every = np.ones_like(gap, dtype=int)
            for m in (2, 4, 8):
                every = np.where(gap * every < nm.MIN_GAP, m, every)
            shown = (k % every) == 0
        else:
            shown = np.ones_like(rr, dtype=bool)
        for i in range(len(rr) - 1):
            if not shown[i]:
                continue
            pieces.append((float(key[i]), 1 if face[i] else 2, float(rr[i]),
                           (round(cx + sx[i]), round(cy + sy[i])),
                           (round(cx + sx[i + 1]), round(cy + sy[i + 1]))))
    pieces.sort(key=lambda p: p[0])
    for _, tone, rho, a, b in pieces:
        kd.line([a, b], fill=tone)
        rd.line([a, b], fill=int(rho * 250))

    tr = np.linspace(0, 2 * math.pi, int(2 * math.pi * W / 0.4) + 1)
    rx, ry, _ = at(np.ones_like(tr), tr)
    for i in range(len(tr) - 1):
        a = (round(cx + rx[i]), round(cy + ry[i]))
        b = (round(cx + rx[i + 1]), round(cy + ry[i + 1]))
        th = int((tr[i] % (2 * math.pi)) / (2 * math.pi) * 250)
        kd.line([(a[0], a[1] + 1), (b[0], b[1] + 1)], fill=3)
        td.line([(a[0], a[1] + 1), (b[0], b[1] + 1)], fill=th)
        kd.line([a, b], fill=4)
        td.line([a, b], fill=th)

    K = np.array(kind)
    RHO = np.array(rho_l) / 250.0
    TH = np.array(theta_l) / 250.0 * 2 * math.pi
    mask = K > 0
    out = np.array(img)

    gold_rim = variant != "today"
    fade_cells = 1.6 if variant in ("B", "C") else 0.0

    # The shade under the cord.
    under = np.zeros_like(mask)
    under[1:, :] |= mask[:-1, :]
    under &= ~mask
    rim_above = np.zeros_like(mask)
    rim_above[1:, :] |= (K[:-1, :] >= 3)
    shade_c = TODAY[3] if variant == "today" else SHADE
    out[under, 0:3] = shade_c
    out[under & rim_above, 0:3] = GOLD_SHADE if gold_rim else shade_c
    out[under, 3] = 255

    # The glint: a band sweeping the net diagonally, across `glint_t` 0..1.
    ys, xs = np.nonzero(mask)
    band = np.zeros(len(xs))
    if glint_t is not None:
        d = ((xs - cx) * 0.85 + (ys - cy) * 0.55) / W
        centre = -1.4 + glint_t * 2.8
        band = np.clip(1.0 - np.abs(d - centre) / 0.24, 0.0, 1.0) ** 0.7

    # The burst: two heads of light running round the rim from the front (the near side,
    # theta = pi/2), both ways, over the first 0.4 s, each with a fading tail.
    run = min(landed / 0.4, 1.0) if landed is not None else None

    for i in range(len(xs)):
        x, y = xs[i], ys[i]
        kk = K[y, x]
        if variant == "today":
            c = (TODAY[0] if kk == 1 else TODAY[2]) if kk <= 2 else (TODAY[1] if kk == 4 else TODAY[0])
        elif kk >= 3:
            c = GOLD_LIT if kk == 4 else GOLD
        else:
            c = CORD if kk == 1 else CORD_BACK
            if fade_cells > 0:
                # Gold creeping in from the rim over the outer cells.
                depth = (1.0 - RHO[y, x]) * W / nm.CELL
                g = 1.0 - depth / fade_cells
                if g > 0:
                    c = mix(c, GOLD if kk == 1 else GOLD_LOW, g * 0.95)
        amount = 0.0
        if variant != "today":
            if kk >= 3:
                amount = burst_at(TH[y, x], landed)
            elif RHO[y, x] > 0.8:
                # The outer cells catch the burst too, less.
                sx_, sy_ = x - cx, (y - cy) * 2.0
                amount = 0.7 * burst_at(math.atan2(sy_, sx_), landed) * (RHO[y, x] - 0.8) / 0.2
        amount = max(amount, band[i] * (1.0 if kk >= 3 else 0.9))
        c = lit(c, amount)
        out[y, x, 0:3] = c
        out[y, x, 3] = 255

    img.paste(Image.fromarray(out))
    px = img.load()
    dr = ImageDraw.Draw(img)

    # Knots where the strands cross (C).
    if variant == "C":
        n_rim = max(8, int(round(2 * math.pi * W / nm.CELL / 4.0)) * 4)
        for kk in range(n_rim):
            for mm in range(n_rim):
                r = (kk - mm) / 2.0
                s = (kk + mm) / 2.0
                rho = r * nm.CELL / W
                if not (0.5 <= rho <= 0.97):
                    continue
                sx, sy, _ = at(np.array([rho]), np.array([2 * math.pi * s / n_rim]))
                x, y = int(round(cx + sx[0])), int(round(cy + sy[0]))
                if 0 <= x < w and 0 <= y < h and mask[y, x]:
                    depth = (1.0 - rho) * W / nm.CELL
                    if depth < 3.0:
                        px[x, y] = (GOLD_LIT if depth < 1.5 else GOLD) + (255,)

    # Beads.
    n = max(6, int(2 * math.pi * W / 9))
    bt = np.linspace(0, 2 * math.pi, n, endpoint=False)
    bx, by, bk = at(np.ones_like(bt), bt)
    bead = (GOLD_DEEP, GOLD_LOW, GOLD_LIT) if gold_rim else (nm.LEAD[0], nm.LEAD[1], nm.LEAD[2])
    if variant == "today":
        bead = (nm.LEAD[0], nm.LEAD[1], nm.LEAD[2])
    for i in np.argsort(bk):
        x = int(round(cx + bx[i]))
        y = int(round(cy + by[i])) + 1
        flash = burst_at(bt[i], landed) if variant != "today" else 0.0
        if glint_t is not None and variant != "today":
            d = ((x - cx) * 0.85 + (y - cy) * 0.55) / W
            flash = max(flash, max(0.0, 1.0 - abs(d - (-1.4 + glint_t * 2.8)) / 0.24))
        dr.rectangle((x - 2, y - 1, x + 2, y + 2), fill=GOLD_SHADE if gold_rim else SHADE)
        dr.rectangle((x - 1, y, x + 1, y + 1), fill=mix(bead[1], WHITE, flash) if gold_rim else bead[1])
        dr.point((x + 1, y), fill=mix(bead[2], WHITE, flash) if gold_rim else bead[2])
        dr.point((x - 1, y + 1), fill=mix(bead[0], GOLD_LIT, flash) if gold_rim else bead[0])

    if variant == "today":
        return

    # Stars. The burst: a ring of them along the rim, popping in over the first half second.
    srng = random.Random(seed * 7 + 3)
    if landed is not None and landed < 0.9:
        for i in range(14):
            th = 2 * math.pi * i / 14 + srng.random() * 0.3
            born = srng.random() * 0.35
            life = (landed - born) / 0.5
            if 0 <= life <= 1:
                push = 1.0 + 0.08 * life
                sx, sy, _ = at(np.array([push]), np.array([th]))
                star(px, w, h, int(round(cx + sx[0])), int(round(cy + sy[0])) - int(4 * life),
                     4.0 * math.sin(life * math.pi))
    # Sparks flung out off the rim as the light passes: single pixels flying outwards.
    if landed is not None and landed < 0.8:
        for i in range(26):
            th = srng.random() * 2 * math.pi
            gone = abs(((th - math.pi / 2 + math.pi) % (2 * math.pi)) - math.pi)
            born = gone / math.pi * 0.4
            life = (landed - born) / 0.4
            if 0 <= life <= 1:
                sx, sy, _ = at(np.array([1.0 + 0.25 * life]), np.array([th]))
                x, y = int(round(cx + sx[0])), int(round(cy + sy[0] - 6 * life))
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = (WHITE if life < 0.4 else GOLD_LIT) + (255,)
    # The twinkle: a few on the cord, each popping and fading.
    if glint_t is not None:
        for i in range(5):
            th = srng.random() * 2 * math.pi
            rho = 0.55 + 0.45 * srng.random()
            life = (glint_t * 1.7 + srng.random()) % 1.0
            sx, sy, _ = at(np.array([rho]), np.array([th]))
            star(px, w, h, int(round(cx + sx[0])), int(round(cy + sy[0])), 3.0 * math.sin(life * math.pi))


def main():
    sprites = nm.load_sprites()
    W = 72
    H = min(W * 0.16, 8.0)
    rows = []
    moments = [
        ("burst 0.08 s", 0.08, None, 0.0),
        ("burst 0.2 s", 0.2, None, 0.0),
        ("burst 0.4 s", 0.4, None, 0.0),
        ("glint", None, 0.35, 0.45),
        ("glint, later", None, 0.6, 0.6),
        ("hauled, glint", None, 0.5, 1.0),
    ]
    for variant, title in (("today", "Today: flat gold"),
                           ("A", "A  gold rim and beads"),
                           ("B", "B  gold creeping in from the rim"),
                           ("C", "C  B with gold knots")):
        tiles = []
        for name, landed, glint, haul in moments:
            pw, ph = int(2 * W + 70), int(W * 1.3 + 40)
            im = nm.water(pw, ph, nm.WATER_DIRTY, 51)
            cx, cy = pw / 2, ph * 0.55
            nm.scatter_rubbish(im, sprites, int(pw * ph / 1100), 51,
                               keep_out=lambda x, y: ((x - cx) / (W + 10)) ** 2 + ((y - cy) / (W * 0.6 + 10)) ** 2 < 1)
            at = nm.net_shape(W, H * (1 - haul), haul=haul, load=0.5 * haul, sway=0.4,
                              wobble=0.035 * haul)
            if variant == "today" and tiles:
                continue
            draw_lucky(im, cx, cy, W, at, variant, landed, glint if variant != "today" else None,
                       catch=sprites[:6], seed=4)
            label = name if variant != "today" else "lying"
            tiles.append(nm.label(nm.up(im, 3), f"{title} | {label}" if not tiles else label))
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


def film(variant, out, seconds=3.0, fps=15):
    """The variant moving: the landing burst, then the glint every 1.5 s, the net lying for
    the first second and hauled after it. An animated GIF at 3x."""
    sprites = nm.load_sprites()
    W = 72
    frames = []
    for f in range(int(seconds * fps)):
        t = f / fps
        haul = max(0.0, min(1.0, (t - 1.0) / 0.8)) * 0.8
        glint = ((t - 0.6) / 1.5) % 1.0 if t > 0.6 else None
        pw, ph = int(2 * W + 70), int(W * 1.3 + 40)
        im = nm.water(pw, ph, nm.WATER_DIRTY, 51)
        cx, cy = pw / 2, ph * 0.55
        nm.scatter_rubbish(im, sprites, int(pw * ph / 1100), 51,
                           keep_out=lambda x, y: ((x - cx) / (W + 10)) ** 2 + ((y - cy) / (W * 0.6 + 10)) ** 2 < 1)
        at = nm.net_shape(W, min(W * 0.16, 8.0) * (1 - haul), haul=haul, load=0.4 * haul,
                          sway=math.sin(t * 1.3), wobble=0.035 * haul, wob_phase=t * 5.0)
        draw_lucky(im, cx, cy, W, at, variant, t if t < 0.9 else None, glint, catch=sprites[:6], seed=4)
        frames.append(nm.up(im, 3).convert("P", palette=Image.ADAPTIVE, colors=255))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0)
    print(out)


if __name__ == "__main__":
    main()
    for v in ("A", "B", "C"):
        film(v, "tools/last_net_lucky_%s.gif" % v)

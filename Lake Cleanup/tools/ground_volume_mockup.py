"""Mockup: ways to give the lawn and the beach volume. Offline, picks only.

Draws one patch of island (lawn, beach, water) on the art-pixel grid in the game's own
colours, six ways, and writes tools/last_ground_volume_mockup.png. Nothing here is read by
the game. Run from the project root with PIL on the path.
"""
import math
import random
from PIL import Image, ImageDraw

W, H = 200, 120          # art pixels a panel
SHOW = 3                 # screen pixels an art pixel on the sheet

# The game's colours, read off tools/last_pump.png.
LAWN_LOW = (49, 85, 28)
LAWN_MID = (74, 106, 45)
LAWN_LIGHT = (107, 132, 62)
LAWN_HI = (138, 158, 78)
LAWN_DEEP = (34, 62, 22)
SAND = (228, 201, 148)
SAND_LIGHT = (240, 220, 172)
SAND_DOWN = (206, 177, 126)
SAND_DEEP = (180, 150, 104)
SAND_DAMP = (190, 163, 118)
SAND_SPECK = (227, 219, 158)
SOIL = (118, 84, 54)
SOIL_LOW = (90, 62, 40)
SOIL_DEEP = (64, 44, 30)
WATER = (57, 88, 35)
WATER_2 = (71, 107, 74)
FOAM = (196, 214, 196)
PEBBLE = (150, 136, 112)
PEBBLE_LIT = (196, 184, 158)
SHELL = (244, 232, 214)


def rng_hash(x, y, salt=0):
    h = (x * 374761393 + y * 668265263 + salt * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0


def value_noise(x, y, scale, salt):
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = rng_hash(ix, iy, salt)
    b = rng_hash(ix + 1, iy, salt)
    c = rng_hash(ix, iy + 1, salt)
    d = rng_hash(ix + 1, iy + 1, salt)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


# --- the patch's shape: lawn up and to the right, beach round it, water down-left ---------

CX, CY = 205, 2


def lawn_cov(x, y):
    """Art pixels inside the lawn's edge (positive on the lawn)."""
    dx, dy = (x - CX) / 150.0, (y - CY) / 78.0
    r = math.hypot(dx, dy)
    wob = (value_noise(x, y, 22, 3) - 0.5) * 9 + (value_noise(x, y, 8, 4) - 0.5) * 3
    return (1.0 - r) * 78.0 + wob


def beach_cov(x, y):
    dx, dy = (x - CX) / 196.0, (y - CY) / 101.0
    r = math.hypot(dx, dy)
    wob = (value_noise(x, y, 30, 7) - 0.5) * 6
    return (1.0 - r) * 101.0 + wob


def kind(x, y):
    if lawn_cov(x, y) > 0:
        return "lawn"
    if beach_cov(x, y) > 0:
        return "sand"
    return "water"


def make_kinds():
    return [[kind(x, y) for x in range(W)] for y in range(H)]


# --- what is under a pixel, before any option --------------------------------------------

def flat_blades(K, x, y, share=0.06, lean=0.2, seed=17):
    """The game's lawn as it is: mid green, low speckle, sparse 2-3 px blades, lit tip."""
    col = LAWN_LOW if rng_hash(x, y, 2) < 0.08 else LAWN_MID
    for k in range(3):
        for s in (-1, 0, 1):
            shift = s if k >= 2 else 0
            if k < 2 and s != 0:
                continue
            rx, ry = x - shift, y + k
            if rng_hash(rx, ry, seed) > share:
                continue
            ln = 0
            if rng_hash(rx, ry, 11) < lean:
                ln = -1 if rng_hash(ry, rx, 8) < 0.5 else 1
            if ln != shift:
                continue
            tall = 2 + int(rng_hash(rx, ry, 23) * 2)
            if k < tall:
                return LAWN_LIGHT if k == tall - 1 else LAWN_LOW
    return col


def fringe(K, x, y):
    """Blades hanging off the lawn's front edge over the sand, as now (depth 2)."""
    for k in (1, 2):
        if y - k >= 0 and K[y - k][x] == "lawn":
            if rng_hash(x, 99, 3) > 0.6:
                return None
            h = 1 + int(rng_hash(x, 99, 5) * 2)
            if k > h:
                return None
            return LAWN_LOW if k < h else LAWN_DEEP
    return None


def water_px(K, x, y):
    near = any(0 <= y - k < H and K[y - k][x] == "sand" for k in (1, 2)) or \
        any(0 <= x + k < W and K[y][x + k] == "sand" for k in (1, 2))
    if near:
        return FOAM
    return WATER_2 if value_noise(x, y, 14, 9) > 0.62 else WATER


# --- the options ---------------------------------------------------------------------------

def lawn_up(K, x, y, n):
    """How many pixels up to the lawn (1..n), or 0."""
    for k in range(1, n + 1):
        if y - k < 0:
            return 0
        if K[y - k][x] == "lawn":
            return k
        if K[y - k][x] != "sand":
            return 0
    return 0


BANK = 3


def raised_bank(K, x, y):
    """Sand pixels just under a lawn edge facing the camera: the turf's cut face."""
    d = lawn_up(K, x, y, BANK + 3)
    if d == 0:
        return None
    if d == 1:
        # The turf's overhanging lip: dark grass, ragged.
        return LAWN_DEEP if rng_hash(x, y, 41) < 0.7 else SOIL_LOW
    if d <= BANK:
        # Soil, with a root or a pebble here and there; darker towards the foot.
        r = rng_hash(x, y, 42)
        if r < 0.12:
            return SOIL_DEEP
        if r > 0.93:
            return (150, 120, 84)
        return SOIL if d < BANK else SOIL_LOW
    # The bank's shadow on the sand, thrown down and left.
    if d <= BANK + 2 and rng_hash(x, 7, 5) < 0.9:
        return SAND_DEEP if d == BANK + 1 else SAND_DOWN
    return None


def lawn_lip_lit(K, x, y):
    """Lawn pixels at the back edge (sand up-screen): a lit rim, as on a raised slab."""
    if y - 1 >= 0 and K[y - 1][x] == "sand":
        return LAWN_HI
    if x + 1 < W and K[y][x + 1] == "sand":
        return LAWN_LIGHT
    return None


def clumps(K, x, y):
    """Grass gathered into tufts: blades thick in a clump, a dark root row under it, its
    sunward (right) blades lit; sparse between."""
    best = None
    for k in range(5):
        for s in (-1, 0, 1):
            rx, ry = x - s, y + k
            dens = value_noise(rx, ry, 5, 31)
            share = 0.5 if dens > 0.6 else 0.035
            if rng_hash(rx, ry, 17) > share:
                continue
            ln = 0
            if k >= 2:
                lr = rng_hash(rx, ry, 11)
                ln = -1 if lr < 0.2 else (1 if lr > 0.8 else 0)
            if ln != s:
                continue
            tall = (3 + int(rng_hash(rx, ry, 23) * 3)) if dens > 0.6 else (2 + int(rng_hash(rx, ry, 23) * 2))
            if k < tall:
                sun = value_noise(rx + 2, ry, 5, 31) < dens  # the clump falls away to the right
                if k == tall - 1:
                    return LAWN_HI if sun else LAWN_LIGHT
                if k == 0:
                    return LAWN_DEEP
                return LAWN_LIGHT if (sun and k >= tall - 2) else LAWN_LOW
    # Bare ground between clumps; a shade pixel at a clump's foot (left and down of it).
    if value_noise(x + 1, y - 1, 5, 31) > 0.62 and value_noise(x, y, 5, 31) <= 0.6:
        return LAWN_LOW
    return LAWN_LOW if rng_hash(x, y, 2) < 0.06 else LAWN_MID


def height(x, y, scale, salt):
    return value_noise(x, y, scale, salt) * 0.7 + value_noise(x, y, scale * 0.45, salt + 1) * 0.3


def slope_light(x, y, scale, salt, amp):
    """Light off a height field, sun from the right and a little above."""
    gx = height(x + 1, y, scale, salt) - height(x - 1, y, scale, salt)
    gy = height(x, y + 1, scale, salt) - height(x, y - 1, scale, salt)
    return (gx * 1.0 - gy * 0.5) * amp


def rolling_lawn(K, x, y):
    l = slope_light(x, y, 26, 51, 30)
    base = flat_blades(K, x, y)
    if base != LAWN_MID and base != LAWN_LOW:
        return base
    if l > 0.55:
        return LAWN_LIGHT if base == LAWN_MID else LAWN_MID
    if l < -0.55:
        return LAWN_LOW if base == LAWN_MID else LAWN_DEEP
    return base


def dunes(K, x, y):
    l = slope_light(x, y, 30, 61, 26)
    if l > 0.6:
        return SAND_LIGHT
    if l < -0.6:
        return SAND_DOWN
    return SAND


def water_dist(K, x, y, n=10):
    for k in range(1, n + 1):
        for dx, dy in ((0, k), (-k, 0), (-k, k)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H and K[yy][xx] == "water":
                return k
    return n + 1


def lawn_dist(K, x, y, n=8):
    for k in range(1, n + 1):
        for dx, dy in ((0, -k), (k, 0), (k, -k)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H and K[yy][xx] == "lawn":
                return k
    return n + 1


def banded_sand(K, x, y, ripples=True):
    """Dry pale under the lawn, damp and darker by the water, wind ripples between,
    pebbles and shells sitting on it with their own shade."""
    wd = water_dist(K, x, y)
    ld = lawn_dist(K, x, y)
    # Pebbles and shells first: a lit top pixel over a body, a shade pixel left and down.
    if rng_hash(x, y + 1, 71) < 0.006:
        return PEBBLE_LIT
    if rng_hash(x, y, 71) < 0.006:
        return PEBBLE
    if rng_hash(x + 1, y - 1, 71) < 0.006:
        return SAND_DEEP
    if rng_hash(x, y, 73) < 0.003:
        return SHELL
    if wd <= 2:
        return SAND_DEEP
    if wd <= 5:
        return SAND_DAMP
    if ld <= 3:
        return SAND_LIGHT if rng_hash(x, y, 5) > 0.1 else SAND
    if ripples:
        # Ripples run along the shore: crests on a wavy line, dashed, lit above, shaded below.
        ph = (y * 0.9 + x * 0.25 + value_noise(x, y, 18, 81) * 9.0) / 4.0
        f = ph - math.floor(ph)
        dash = value_noise(x, y, 6, 83) > 0.38
        if dash and f < 0.18:
            return SAND_DOWN
        if dash and 0.18 <= f < 0.32:
            return SAND_LIGHT
    return SAND_SPECK if rng_hash(x, y, 6) < 0.02 else SAND


# --- panels ------------------------------------------------------------------------------

def render(K, opt):
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            k = K[y][x]
            c = None
            if k == "water":
                c = water_px(K, x, y)
            elif k == "lawn":
                if opt in ("A", "E"):
                    c = lawn_lip_lit(K, x, y)
                if c is None:
                    if opt in ("B", "E"):
                        c = clumps(K, x, y)
                    elif opt == "C":
                        c = rolling_lawn(K, x, y)
                    else:
                        c = flat_blades(K, x, y)
                    if opt == "E":
                        l = slope_light(x, y, 26, 51, 30)
                        if l > 0.7 and c == LAWN_MID:
                            c = LAWN_LIGHT
                        elif l < -0.7 and c == LAWN_MID:
                            c = LAWN_LOW
            else:
                if opt in ("A", "E"):
                    c = raised_bank(K, x, y)
                if c is None and opt in ("now", "B", "C", "D"):
                    c = fringe(K, x, y)
                if c is None:
                    if opt in ("D", "E"):
                        c = banded_sand(K, x, y)
                    elif opt == "C":
                        c = dunes(K, x, y)
                    else:
                        c = SAND_SPECK if rng_hash(x, y, 6) < 0.02 else SAND
            px[x, y] = c
    return img


def paste_box(img, at):
    try:
        box = Image.open("assets/Recycle_Box.png").convert("RGBA")
    except OSError:
        return
    img.paste(box, at, box)


PANELS = [
    ("now", "Now: flat lawn, flat sand"),
    ("A", "A  raised turf: soil bank + shadow"),
    ("B", "B  grass in clumps, lit sunward"),
    ("C", "C  rolling ground: lit mounds, dunes"),
    ("D", "D  sand in bands: damp, ripples, pebbles"),
    ("E", "E  A + B + D, light mounds"),
]


def main():
    K = make_kinds()
    cols, rows = 3, 2
    pad, title = 16, 22
    pw, ph = W * SHOW, H * SHOW
    sheet = Image.new("RGB", (pad + cols * (pw + pad), pad + rows * (ph + title + pad)), (30, 33, 36))
    draw = ImageDraw.Draw(sheet)
    for i, (opt, name) in enumerate(PANELS):
        img = render(K, opt)
        paste_box(img, (150, 40))
        cx = pad + (i % cols) * (pw + pad)
        cy = pad + (i // cols) * (ph + title + pad)
        draw.text((cx, cy), name, fill=(220, 220, 220))
        sheet.paste(img.resize((pw, ph), Image.NEAREST), (cx, cy + title))
    sheet.save("tools/last_ground_volume_mockup.png")
    print("wrote tools/last_ground_volume_mockup.png", sheet.size)


if False:
    main()


# --- second pass (Richard: B quieter, D's bands following the water line) ----------------

def distance_to(K, what):
    """Chamfer distance in art pixels from every pixel to the nearest pixel of `what`."""
    big = 1e9
    d = [[0.0 if K[y][x] == what else big for x in range(W)] for y in range(H)]
    for _ in range(2):
        for y in range(H):
            for x in range(W):
                for dx, dy, c in ((-1, 0, 1), (0, -1, 1), (-1, -1, 1.414), (1, -1, 1.414)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H and d[yy][xx] + c < d[y][x]:
                        d[y][x] = d[yy][xx] + c
        for y in range(H - 1, -1, -1):
            for x in range(W - 1, -1, -1):
                for dx, dy, c in ((1, 0, 1), (0, 1, 1), (1, 1, 1.414), (-1, 1, 1.414)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H and d[yy][xx] + c < d[y][x]:
                        d[y][x] = d[yy][xx] + c
    return d


def quiet_clumps(x, y, scale, cut, tip, root, inner, lean_odds, salt=31):
    """Clumps with knobs: how big (`scale`), how many (`cut`), how strong the light."""
    for k in range(5):
        for s in (-1, 0, 1):
            rx, ry = x - s, y + k
            dens = value_noise(rx, ry, scale, salt)
            share = 0.42 if dens > cut else 0.03
            if rng_hash(rx, ry, 17) > share:
                continue
            ln = 0
            if k >= 2:
                lr = rng_hash(rx, ry, 11)
                ln = -1 if lr < lean_odds else (1 if lr > 1 - lean_odds else 0)
            if ln != s:
                continue
            tall = (3 + int(rng_hash(rx, ry, 23) * 2)) if dens > cut else 2
            if k < tall:
                sun = value_noise(rx + 2, ry, scale, salt) < dens
                if k == tall - 1:
                    return tip if sun else LAWN_MID if tip == LAWN_LIGHT else LAWN_LIGHT
                if k == 0 and dens > cut:
                    return root
                return inner
    return LAWN_LOW if rng_hash(x, y, 2) < 0.05 else LAWN_MID


GRASS = {
    "B1": lambda x, y: quiet_clumps(x, y, 5, 0.70, LAWN_HI, LAWN_DEEP, LAWN_LOW, 0.2),
    "B2": lambda x, y: quiet_clumps(x, y, 5, 0.62, LAWN_LIGHT, LAWN_LOW, LAWN_LOW, 0.2),
    "B3": lambda x, y: quiet_clumps(x, y, 9, 0.66, LAWN_LIGHT, LAWN_DEEP, LAWN_LOW, 0.15),
}


def contour_sand(DW, DL, x, y, mode):
    """Bands laid along the shore: everything is a function of the distance to the water,
    wobbled a little so the lines are not drawn with a compass."""
    dw = DW[y][x] + (value_noise(x, y, 16, 91) - 0.5) * 2.5
    dl = DL[y][x]
    if rng_hash(x, y + 1, 71) < 0.004:
        return PEBBLE_LIT
    if rng_hash(x, y, 71) < 0.004:
        return PEBBLE
    if rng_hash(x + 1, y - 1, 71) < 0.004:
        return SAND_DEEP
    if dw < 2.5:
        return SAND_DEEP
    if dw < 6.0:
        return SAND_DAMP
    if mode == "tide" and 8.0 <= dw < 9.4:
        # The high-tide line: a dashed dark line of wrack, a pale shell in it now and then.
        r = value_noise(x, y, 4, 95)
        if r > 0.45:
            return SHELL if rng_hash(x, y, 97) < 0.06 else SAND_DOWN
    if dl < 3.5:
        return SAND_LIGHT if rng_hash(x, y, 5) > 0.08 else SAND
    if mode == "ripple" and dw >= 7.0:
        # Ripples parallel to the waterline, every 4 px, dashed, lit on their shore side.
        f = (dw / 4.0) % 1.0
        dash = value_noise(x, y, 7, 83) > 0.42
        if dash and f < 0.16:
            return SAND_DOWN
        if dash and f < 0.3:
            return SAND_LIGHT
    return SAND_SPECK if rng_hash(x, y, 6) < 0.02 else SAND


SANDS = ["bands", "ripple", "tide"]
SAND_NAMES = {
    "bands": "D1  bands only: damp, sand, dry",
    "ripple": "D2  + ripples along the shore",
    "tide": "D3  + a tide line of wrack",
}
GRASS_NAMES = {
    "B1": "B1  fewer clumps, same light",
    "B2": "B2  more clumps, softer light",
    "B3": "B3  bigger, sparser clumps",
}


def render2(K, DW, DL, grass, sand):
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            k = K[y][x]
            if k == "water":
                c = water_px(K, x, y)
            elif k == "lawn":
                c = GRASS[grass](x, y) if grass else flat_blades(K, x, y)
            else:
                c = fringe(K, x, y)
                if c is None:
                    c = contour_sand(DW, DL, x, y, sand) if sand else (
                        SAND_SPECK if rng_hash(x, y, 6) < 0.02 else SAND)
            px[x, y] = c
    return img


def main2():
    K = make_kinds()
    DW = distance_to(K, "water")
    DL = distance_to(K, "lawn")
    panels = [(g, None, GRASS_NAMES[g]) for g in GRASS] + [(None, s, SAND_NAMES[s]) for s in SANDS]
    cols, pad, title = 3, 16, 22
    pw, ph = W * SHOW, H * SHOW
    sheet = Image.new("RGB", (pad + cols * (pw + pad), pad + 2 * (ph + title + pad)), (30, 33, 36))
    draw = ImageDraw.Draw(sheet)
    for i, (g, s, name) in enumerate(panels):
        img = render2(K, DW, DL, g, s)
        paste_box(img, (150, 40))
        cx = pad + (i % cols) * (pw + pad)
        cy = pad + (i // cols) * (ph + title + pad)
        draw.text((cx, cy), name, fill=(220, 220, 220))
        sheet.paste(img.resize((pw, ph), Image.NEAREST), (cx, cy + title))
    sheet.save("tools/last_ground_volume_mockup2.png")
    print("wrote tools/last_ground_volume_mockup2.png", sheet.size)


# --- third pass (Richard: B1 with a lighter dark; tide line + fewer, natural ripples) -----

LAWN_SOFT = (60, 95, 36)   # between LAWN_LOW and LAWN_MID


GRASS3 = {
    "L1": lambda x, y: quiet_clumps(x, y, 5, 0.70, LAWN_HI, LAWN_LOW, LAWN_SOFT, 0.2),
    "L2": lambda x, y: quiet_clumps(x, y, 5, 0.70, LAWN_HI, LAWN_SOFT, LAWN_SOFT, 0.2),
}
GRASS3_NAMES = {"L1": "B1, roots low green, blades soft", "L2": "B1, roots and blades soft"}


def tide_line(dw, x, y):
    """A dashed line of wrack at one distance from the water, wandering, a shell now and then."""
    t = dw - 8.0 - (value_noise(x, y, 24, 99) - 0.5) * 3.0
    if 0.0 <= t < 1.3 and value_noise(x, y, 5, 95) > 0.4:
        if rng_hash(x, y, 97) < 0.07:
            return SHELL
        return SAND_DEEP if t < 0.7 else SAND_DOWN
    return None


def ripple(dw, x, y, mode):
    """Ripples along the shore, only where a field of them lies and broken into short marks."""
    if mode == "patch":
        field = value_noise(x, y, 22, 101) > 0.6
        gap = 4.0
    elif mode == "sparse":
        field = value_noise(x, y, 14, 103) > 0.66
        gap = 5.0
    else:  # "drift": fields, and the spacing itself wanders
        field = value_noise(x, y, 26, 105) > 0.58
        gap = 3.5 + value_noise(x, y, 30, 107) * 2.5
    if not field:
        return None
    w = dw + (value_noise(x, y, 9, 109) - 0.5) * 2.0
    f = (w / gap) % 1.0
    if value_noise(x, y, 4, 83) < 0.48:
        return None
    if f < 0.17:
        return SAND_DOWN
    if f < 0.3:
        return SAND_LIGHT
    return None


def sand3(DW, DL, x, y, mode):
    dw = DW[y][x] + (value_noise(x, y, 16, 91) - 0.5) * 2.5
    dl = DL[y][x]
    if rng_hash(x, y + 1, 71) < 0.004:
        return PEBBLE_LIT
    if rng_hash(x, y, 71) < 0.004:
        return PEBBLE
    if rng_hash(x + 1, y - 1, 71) < 0.004:
        return SAND_DEEP
    if dw < 2.5:
        return SAND_DEEP
    if dw < 6.0:
        return SAND_DAMP
    c = tide_line(DW[y][x], x, y)
    if c:
        return c
    if dl < 3.5:
        return SAND_LIGHT if rng_hash(x, y, 5) > 0.08 else SAND
    if dw >= 10.5:
        c = ripple(dw, x, y, mode)
        if c:
            return c
    return SAND_SPECK if rng_hash(x, y, 6) < 0.02 else SAND


SANDS3 = {"patch": "ripples in patches", "sparse": "sparse short marks", "drift": "patches, spacing wanders"}


def main3():
    K = make_kinds()
    DW = distance_to(K, "water")
    DL = distance_to(K, "lawn")
    cols, pad, title = 3, 16, 22
    pw, ph = W * SHOW, H * SHOW
    sheet = Image.new("RGB", (pad + cols * (pw + pad), pad + 2 * (ph + title + pad)), (30, 33, 36))
    draw = ImageDraw.Draw(sheet)
    i = 0
    for g in GRASS3:
        for s in SANDS3:
            img = Image.new("RGB", (W, H))
            px = img.load()
            for y in range(H):
                for x in range(W):
                    k = K[y][x]
                    if k == "water":
                        c = water_px(K, x, y)
                    elif k == "lawn":
                        c = GRASS3[g](x, y)
                    else:
                        c = fringe(K, x, y) or sand3(DW, DL, x, y, s)
                    px[x, y] = c
            paste_box(img, (150, 40))
            cx = pad + (i % cols) * (pw + pad)
            cy = pad + (i // cols) * (ph + title + pad)
            draw.text((cx, cy), "%d%s  grass: %s  |  sand: tide line + %s" % (i // cols + 1, "abc"[i % cols], GRASS3_NAMES[g], SANDS3[s]), fill=(220, 220, 220))
            sheet.paste(img.resize((pw, ph), Image.NEAREST), (cx, cy + title))
            i += 1
    sheet.save("tools/last_ground_volume_mockup3.png")
    print("wrote tools/last_ground_volume_mockup3.png", sheet.size)


if __name__ == "__main__":
    import sys
    if "--three" in sys.argv:
        main3()
    elif "--two" in sys.argv:
        main2()
    else:
        main()

#!/usr/bin/env python
"""Draw the beehive sidequest's art: the hive on the island, and the pieces of the hive room.

The look was picked off tools/hive_mockup.py (2026-09-29, `/grill-me` with Richard), and the
drawing moved here out of it so the game and the mockup are drawn by the same functions; the
mockup imports them back and renders pixel for pixel what it did before. Built from rules,
like the pump, the piers and the nozzle: shapes on whole painted pixels, the game's near-black
outline (OUT, the hut's and the box's) round everything opaque. Richard may polish the PNGs
after ("rules first, polish after"); the json holds while the rects do.

Output:
  assets/hive.png, hive.json            the island sheet (docs/hive/contract.md 3.1)
  assets/hive_room.png, hive_room.json  the room's pieces and their anchors (3.2)
  tools/last_hive_sheet.png             every island frame at 6x on grass, parts laid together
  tools/last_hive_room_sheet.png        every room piece at 2x with its anchors marked

**The island sprite is two parts on one canvas.** The hive and its jar shelf are one picture
in the mockup, but the game shades, hems and fills them apart: the shelf's posts stand well up
the picture from the hive's feet, so one `ground` cannot serve both, and the jars change while
the hive does not. So every frame is the whole canvas, cropped the same, and a shelf frame laid
under a hive frame is exactly the mockup's one sprite (the builder checks every pairing). The
pixels are dealt out of the inked whole, not inked apart: inked apart, the hive's outline would
run across the shelf behind it, which the approved picture does not have. So a hive frame drawn
with no shelf under it has a gap in its outline where the shelf meets it; it is never drawn so.

Run from the project root:
  <psd-extract venv python> tools/build_hive.py

Reimport afterwards, as every builder here needs:
  <godot> --path . --headless --import
"""
import json
import math
import os
import random
import re

from PIL import Image, ImageChops, ImageDraw


def _palette():
    pal = {}
    for line in open("resources/palette.tres"):
        m = re.match(r"(\w+) = Color\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", line)
        if m:
            pal[m.group(1)] = tuple(int(round(float(m.group(i)) * 255)) for i in (2, 3, 4)) + (255,)
    return pal


PAL = _palette()

# --- colours -------------------------------------------------------------------------------
OUT = (24, 18, 17, 255)            # the hut's and the box's near-black outline
HONEY_DEEP = (150, 72, 12, 255)
HONEY_MID = (206, 120, 22, 255)
HONEY = (238, 164, 38, 255)
HONEY_LIGHT = (252, 204, 84, 255)
HONEY_SHINE = (255, 242, 190, 255)
WAX = (246, 226, 164, 255)
WAX_LIT = (255, 246, 214, 255)
WAX_SHADE = (218, 186, 116, 255)
WAX_WALL = (190, 150, 84, 255)
BROOD = (214, 170, 108, 255)
BROOD_LIT = (234, 198, 142, 255)
BROOD_SHADE = (178, 134, 78, 255)
POLLEN = [(236, 146, 40, 255), (248, 206, 70, 255), (214, 96, 54, 255), (176, 192, 74, 255),
          (242, 176, 60, 255)]
CELL_EMPTY = (118, 74, 34, 255)
CELL_DEEP = (84, 50, 22, 255)
BEE_GOLD = (244, 184, 40, 255)
BEE_STRIPE = (44, 30, 20, 255)
BEE_THORAX = (116, 76, 40, 255)
BEE_HEAD = (34, 24, 18, 255)
WING = (226, 240, 250, 210)
WING_EDGE = (255, 255, 255, 235)
PINE = (226, 190, 132, 255)
PINE_LIT = (244, 216, 166, 255)
PINE_SHADE = (190, 148, 94, 255)
PINE_DEEP = (148, 106, 62, 255)
DARK_WOOD = (120, 84, 56, 255)
DARK_WOOD_LO = (90, 60, 40, 255)
DARK_WOOD_HI = (150, 110, 76, 255)
TRIM = (248, 244, 232, 255)
TRIM_SHADE = (208, 200, 184, 255)
ROOF = {"lit": (246, 140, 104, 255), "base": (220, 98, 72, 255),
        "shade": (180, 68, 52, 255), "deep": (136, 46, 38, 255)}
ROOF_OLD = {"lit": (168, 124, 110, 255), "base": (146, 104, 92, 255),
            "shade": (118, 84, 76, 255), "deep": (90, 64, 58, 255)}
PAINTS = {
    "butter": ((255, 238, 170, 255), (248, 214, 118, 255), (214, 170, 80, 255), (168, 122, 54, 255)),
    "mint": ((208, 242, 222, 255), (156, 214, 184, 255), (112, 172, 146, 255), (74, 128, 106, 255)),
    "sky": ((206, 230, 248, 255), (150, 190, 228, 255), (108, 150, 198, 255), (72, 106, 152, 255)),
    "rose": ((255, 214, 216, 255), (242, 170, 178, 255), (206, 124, 136, 255), (156, 84, 98, 255)),
}
WEATHERED = ((184, 176, 158, 255), (150, 142, 126, 255), (118, 110, 98, 255), (86, 80, 72, 255))
STEEL = {"hi": (240, 246, 250, 255), "lit": (214, 224, 232, 255), "base": (172, 186, 198, 255),
         "shade": (126, 140, 156, 255), "deep": (84, 96, 112, 255)}
BRASS = {"lit": (252, 222, 128, 255), "base": (216, 166, 62, 255), "shade": (160, 112, 38, 255),
         "deep": (108, 72, 24, 255)}
LEATHER = {"lit": (186, 120, 76, 255), "base": (150, 88, 54, 255), "shade": (110, 60, 36, 255)}
ENAMEL = {"lit": (236, 250, 242, 255), "base": (200, 232, 216, 255), "shade": (150, 196, 176, 255),
          "deep": (104, 150, 132, 255)}
GINGHAM_RED = (214, 62, 66, 255)
GINGHAM_PINK = (238, 156, 156, 255)
GINGHAM_WHITE = (252, 246, 238, 255)
BLOSSOM = ((255, 226, 234, 255), (248, 186, 204, 255), (228, 132, 162, 255))
LEAF = ((170, 212, 100, 255), (124, 178, 72, 255), (84, 136, 52, 255), (58, 98, 40, 255))
BARK = ((150, 108, 76, 255), (116, 80, 54, 255), (84, 56, 38, 255))
SMOKE = ((250, 252, 252, 255), (222, 228, 232, 255), (184, 192, 200, 255))
# The boards' paper and the menus' oak (Style.PAPER / PAPER_INK / PAPER_HEAD, FRAME*).
PAPER = (234, 219, 184, 255)
PAPER_EDGE = (199, 179, 138, 255)
PAPER_INK = (50, 36, 28, 255)
PAPER_HEAD = (115, 40, 26, 255)
NOTE_OUTER = (60, 42, 30, 255)
FRAME = (158, 117, 92, 255)
FRAME_LIT = (181, 140, 115, 255)
FRAME_LOW = (140, 84, 64, 255)
FRAME_DEEP = (66, 43, 28, 255)
RIBBON_INK = (240, 217, 191, 255)
GOLD = (255, 204, 77, 255)
SAFE = (112, 199, 107, 255)
CREAM = (245, 232, 200, 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def fade(c, alpha):
    return c[:3] + (int(alpha),)


# --- drawing on whole art pixels -----------------------------------------------------------
class Art:
    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), fill)
        self.d = ImageDraw.Draw(self.im)

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if c[3] >= 255:
            self.im.putpixel((x, y), c)
            return
        b = self.im.getpixel((x, y))
        if b[3] == 0:
            self.im.putpixel((x, y), c)
            return
        t = c[3] / 255.0
        self.im.putpixel((x, y), tuple(int(b[i] * (1 - t) + c[i] * t) for i in range(3)) + (max(b[3], c[3]),))

    def rect(self, x, y, w, h, c):
        if w > 0 and h > 0:
            self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)

    def poly(self, pts, c):
        self.d.polygon([(round(x), round(y)) for x, y in pts], fill=c)

    def ell(self, x, y, w, h, c):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)

    def line(self, pts, c, w=1):
        self.d.line([(round(x), round(y)) for x, y in pts], fill=c, width=w)

    def paste(self, im, x, y):
        self.im.alpha_composite(im, (int(round(x)), int(round(y))))

    def fill_by(self, pts, fn):
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).polygon([(round(x), round(y)) for x, y in pts], fill=255)
        bb = m.getbbox()
        if not bb:
            return
        mp = m.load()
        for y in range(bb[1], bb[3]):
            for x in range(bb[0], bb[2]):
                if mp[x, y]:
                    c = fn(x, y)
                    if c:
                        self.px(x, y, c)


def inked(im, col=OUT):
    """The game's one-pixel outline round everything opaque: one pixel bigger all round."""
    w, h = im.size
    body = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    body.paste(im, (1, 1))
    a = body.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = a
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown = ImageChops.lighter(grown, ImageChops.offset(a, dx, dy))
    ring = ImageChops.subtract(grown, a)
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (w + 2, h + 2), col), (0, 0), ring)
    out.alpha_composite(body)
    return out


def sprite(rows, key):
    im = Image.new("RGBA", (max(len(r) for r in rows), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in key:
                im.putpixel((x, y), key[ch])
    return im


def big(im, s):
    return im.resize((im.width * s, im.height * s), Image.NEAREST)


# --- bees ----------------------------------------------------------------------------------
BEE_KEY = {"g": BEE_GOLD, "k": BEE_STRIPE, "t": BEE_THORAX, "h": BEE_HEAD, "e": TRIM}
BEE_BODY = ["gkgktth", ".gkgtt."]
# The queen: a long, tapering abdomen, a broad thorax with the year's white dot, three rows.
QUEEN_BODY = ["..kgkgk.....", ".gkgkgkgtt..", "gkgkgkgkteth", ".gkgkgkgtt..", "..kgkgk....."]


def bee(facing_left=False, queen=False, turn=0, wings_up=True):
    """A bee at the room's grain: a striped body inked, pale wings over the thorax."""
    body = inked(sprite(QUEEN_BODY if queen else BEE_BODY, BEE_KEY))
    im = Image.new("RGBA", (body.width, body.height + 2), (0, 0, 0, 0))
    im.alpha_composite(body, (0, 2))
    thorax = 5 if not queen else 10
    rows = [(0, [thorax - 1, thorax]), (1, [thorax - 2, thorax - 1, thorax])] if wings_up else \
        [(1, [thorax - 3, thorax - 2, thorax - 1]), (2, [thorax - 3, thorax - 2])]
    for y, xs in rows:
        for x in xs:
            im.putpixel((x, y), WING_EDGE if y == 0 else WING)
    if facing_left:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    for _ in range(turn % 4):
        im = im.transpose(Image.ROTATE_90)
    return im



def bee_mass(half_at, tall, seed, count):
    """A clump of bees: a dark core, then real bee sprites piled over it, so the edge is
    bodies and the surface is stripes and wings rather than a texture."""
    rng = random.Random(seed)
    wide = int(max(half_at(k / 20) for k in range(21))) + 10
    a = Art(wide * 2, tall + 14)
    cx = wide
    for y in range(tall):
        hw = half_at(y / tall)
        for x in range(int(cx - hw) + 3, int(cx + hw) - 2):
            a.px(x, y + 5, HONEY_DEEP if (x + y) % 3 else BEE_STRIPE)
    bees = []
    for _ in range(count):
        t = rng.random()
        hw = half_at(t)
        bees.append((t * tall, cx + rng.uniform(-hw, hw) - 4, rng.random() < 0.5,
                     rng.choice([0, 0, 0, 1, 3]), rng.random() < 0.18))
    for y, x, left, turn, up in sorted(bees):
        a.paste(bee(facing_left=left, turn=turn, wings_up=up), x, y)
    return a.im


def glove(flip=False):
    """A beekeeper's leather gauntlet, its fingers hooked over whatever it is holding."""
    L = {"lit": (252, 234, 178, 255), "base": (236, 206, 136, 255), "shade": (200, 164, 96, 255)}
    C = {"lit": (252, 252, 246, 255), "base": (234, 234, 224, 255), "shade": (196, 196, 184, 255)}
    a = Art(30, 42)
    # the white canvas gauntlet, flaring down the arm, an elastic band round its top
    a.poly([(7, 18), (22, 18), (28, 41), (1, 41)], C["base"])
    a.poly([(1, 41), (7, 18), (11, 18), (8, 41)], C["shade"])
    a.poly([(20, 18), (22, 18), (28, 41), (24, 41)], C["lit"])
    a.rect(5, 22, 20, 2, C["shade"])
    a.rect(4, 27, 22, 1, C["shade"])
    # the leather hand: a rounded back, four fingers curled over whatever it holds, a thumb
    a.ell(5, 6, 20, 16, L["base"])
    a.ell(5, 12, 6, 9, L["shade"])
    for k in range(4):
        a.ell(5 + k * 5, 0, 6, 10, L["lit"] if k >= 2 else L["base"])
    for k in range(3):
        a.rect(10 + k * 5, 3, 1, 5, L["shade"])
    a.ell(21, 9, 8, 8, L["shade"])
    a.rect(11, 10, 9, 1, L["lit"])
    im = inked(a.im)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


# --- the payoffs every step shares -----------------------------------------------------------
def star(a, x, y, arm=2, col=GOLD, tip=HONEY_SHINE):
    """The finds' four-point star on whole art pixels: the game's one mark for 'got it'."""
    for k in range(-arm, arm + 1):
        c = col if abs(k) < arm else tip
        a.px(x + k, y, c)
        a.px(x, y + k, c)
    a.px(x, y, TRIM)


def drip(a, x, y, length, wide=2):
    """A slow run of honey with a bead gathering at its foot, lit on its right."""
    for k in range(length):
        a.rect(x, y + k, wide, 1, HONEY)
        a.px(x + wide - 1, y + k, HONEY_LIGHT)
    a.rect(x - 1, y + length, wide + 2, 3, HONEY)
    a.rect(x - 1, y + length + 2, wide + 2, 1, HONEY_MID)
    a.px(x + wide, y + length, HONEY_SHINE)


def crown():
    """A little gold crown: the queen, wherever she is."""
    rows = ["g...g...g", "gg.gsg.gg", "ggggggggg", "gRgglggRg", "ddddddddd"]
    return inked(sprite(rows, {"g": GOLD, "s": HONEY_SHINE, "R": (214, 62, 66, 255),
                               "l": (120, 190, 240, 255), "d": HONEY_MID}))


# --- the hive on the island (isometric, lit from the right like every painted asset) -------
ISLAND_W, ISLAND_H = 44, 40
DARK_GLASS = (70, 50, 34, 255)      # an empty honey window: the dark of the box behind the glass


def island_hive(paint, state, jars=0, window=None, drip=False):
    """The hive and its honey rack as one sprite. state: 'weathered' (an old empty box),
    'colony', 'full'. The rack stands behind the hive's shaded side: an open-fronted cupboard in
    the hive's own paint under a strip of its roof. A harvest is a row of three jars, the top
    shelf filling first.

    `window` "dark" leaves a colony's honey window empty (the game draws the level over it);
    left alone it shows the mockup's half-full row. `drip` runs honey off the landing board onto
    the stand, the full hive's overflow. Both are off by default so the mockup is unchanged."""
    im = inked(_island_raw(paint, state, jars, window, drip))
    if state == "weathered":
        _cobweb(im)
    return im


def _cobweb(im):
    """A cobweb on the shelf's top corner, laid over the ink where nothing else is."""
    for x, y in ((1, 8), (2, 9), (1, 10), (0, 9)):
        if im.getpixel((x, y))[3] == 0:
            im.putpixel((x, y), (235, 235, 235, 150))


def _island_raw(paint, state, jars=0, window=None, drip=False, shelf=True, hive=True):
    """The island sprite before inking, on its ISLAND_W x ISLAND_H canvas: the shelf, the hive,
    or both. Every stroke of either part is opaque and the shelf is drawn wholly before the
    hive, so the two drawn apart and laid one over the other are exactly the two drawn
    together. The rng belongs to the hive's strokes alone, so leaving the shelf out does not
    move a flake or a shingle."""
    a = Art(ISLAND_W, ISLAND_H)
    lit, base, shade, deep = paint
    old = state == "weathered"
    roof = ROOF_OLD if old else ROOF
    rng = random.Random(7)
    # the jar shelf: two pine planks on four posts, up and to the left of the hive so the hive
    # stands in front of its end. Open, no walls: the jars are the point. Six to a plank.
    Lr, Hr = (2, 17), 12
    Br = (Lr[0] + 18, Lr[1] + 9)
    dep = (2, -1)

    def at(p, k, back=False):
        return (p[0] + (dep[0] if back else 0), p[1] - k + (dep[1] if back else 0))

    def front_y(x, k):
        return Lr[1] - k + (x - Lr[0]) // 2

    for p_ in (Lr, Br) if shelf else ():
        bx, by = at(p_, 0, back=True)
        a.rect(bx, by - Hr, 1, Hr + 1, DARK_WOOD_LO)
    for k in (2, 9) if shelf else ():
        a.poly([at(Lr, k), at(Br, k), at(Br, k, True), at(Lr, k, True)], PINE_LIT if not old else PINE_SHADE)
        for x in range(Lr[0], Br[0] + 1):
            a.px(x, front_y(x, k), PINE if not old else PINE_SHADE)
            a.px(x, front_y(x, k) + 1, PINE_DEEP)
    for j in range(jars if shelf else 0):
        k = 9 if j < 6 else 2
        x = Lr[0] + 2 + (j % 6) * 3
        y = front_y(x, k) - 1
        a.rect(x, y - 2, 2, 3, HONEY)
        a.px(x + 1, y - 2, HONEY_SHINE)
        a.px(x, y, HONEY_MID)
        a.rect(x, y - 3, 2, 1, GINGHAM_RED)
    for p_ in (Lr, Br) if shelf else ():
        a.rect(p_[0], p_[1] - Hr, 1, Hr + 3, DARK_WOOD)
    if not hive:
        return a.im
    # the hive: a stand, then two faces, the lit one on the right
    cx, yT, H = ISLAND_CX, ISLAND_YT, ISLAND_WALL
    c = yT + 4 + H
    sl, sr, sb, st = (cx - 10, c), (cx + 10, c), (cx, c + 5), (cx, c - 5)
    a.poly([sl, st, sr, sb], PINE_SHADE if old else PINE_LIT)
    a.poly([sl, sb, (sb[0], sb[1] + 2), (sl[0], sl[1] + 2)], DARK_WOOD_LO)
    a.poly([sb, sr, (sr[0], sr[1] + 2), (sb[0], sb[1] + 2)], DARK_WOOD)
    for lx, ly in ((sl[0] + 1, sl[1] + 2), (sb[0], sb[1] + 2), (sr[0] - 1, sr[1] + 2)):
        a.rect(lx, ly, 1, 3, DARK_WOOD_LO)
    L, B, R = (cx - 8, yT + 4), (cx, yT + 8), (cx + 8, yT + 4)
    a.poly([L, B, (B[0], B[1] + H), (L[0], L[1] + H)], shade)
    a.poly([B, R, (R[0], R[1] + H), (B[0], B[1] + H)], base)
    for y in range(B[1], B[1] + H):
        a.px(cx, y, lit)
    for k in (4, 8):
        for x in range(cx - 8, cx):
            a.px(x, yT + 4 + k + (x - (cx - 8)) // 2, deep)
        for x in range(cx, cx + 8):
            y = yT + 8 + k - (x - cx) // 2
            a.px(x, y, deep)
            a.px(x, y - 1, lit)
    if old:
        # grey boards with flakes of the blue it had
        for _ in range(26):
            x = rng.randint(cx - 7, cx + 7)
            y = rng.randint(yT + 6, yT + 4 + H + 2)
            a.px(x, y, PAINTS["sky"][2 if x < cx else 1])
    for x in range(cx + 2, cx + 7):
        y = B[1] + H - 1 - (x - cx) // 2
        a.px(x, y, (40, 26, 18, 255))
        a.px(x, y + 1, PINE_LIT if not old else PINE_SHADE)
    if drip:
        # the overflow: a run off the lip of the landing board onto the stand, a bead at its foot
        dx = ISLAND_DRIP_X
        lip = B[1] + H - (dx - cx) // 2
        a.px(dx, lip + 1, HONEY)
        a.px(dx, lip + 2, HONEY)
        a.px(dx, lip + 3, HONEY_LIGHT)
    if not old:
        for x in range(cx + 2, cx + 7):
            for k in range(-1, 3):
                y = yT + 8 + k + 1 - (x - cx) // 2
                edge = x in (cx + 2, cx + 6) or k in (-1, 2)
                if edge:
                    a.px(x, y, TRIM)
                else:
                    if state == "full":
                        a.px(x, y, HONEY_LIGHT)
                    elif window == "dark":
                        a.px(x, y, DARK_GLASS)
                    else:
                        a.px(x, y, HONEY if k == 1 else DARK_GLASS)
        if state == "full":
            a.px(cx + 4, yT + 8 - 1, HONEY_SHINE)
    # the roof: a gable, ridge along the shaded face like the hut's, the gable end lit
    rL, rT, rR, rB = (cx - 10, yT + 5), (cx, yT), (cx + 10, yT + 5), (cx, yT + 10)
    h = 7
    A = ((rL[0] + rT[0]) / 2, (rL[1] + rT[1]) / 2 - h)
    Bp = ((rB[0] + rR[0]) / 2, (rB[1] + rR[1]) / 2 - h)

    def shingle(x, y):
        d = y - (A[1] + 0.5 * (x - A[0]))
        if d < 1:
            return roof["lit"]
        if old and rng.random() < 0.08:
            return roof["deep"]
        return roof["shade"] if int(d) % 3 == 0 else roof["base"]

    a.fill_by([rL, rB, Bp, A], shingle)
    a.poly([rB, rR, Bp], lit)
    for x in range(int(rB[0]), int(Bp[0]) + 1):
        a.px(x, rB[1] - (x - rB[0]) * 1.9 - 0.5, TRIM)
    a.px((rB[0] + rR[0] + Bp[0]) / 3, (rB[1] + rR[1] + Bp[1]) / 3, (60, 40, 28, 255))
    return a.im


# The island hive's measures, in painted px before inking. The builder works the json's
# anchors out of these, so moving the hive on its canvas moves them with it.
ISLAND_CX, ISLAND_YT, ISLAND_WALL = 30, 9, 12
ISLAND_DRIP_X = ISLAND_CX + 5


def island_swarm():
    rows = ["..ggg..", ".gkgkg.", "gkgkgkg", "ggkgkgk", "kgkgkgg", ".gkgkg.", "..gkg..", "..kg...", "...g..."]
    return inked(sprite(rows, {"g": BEE_GOLD, "k": HONEY_DEEP}))


def ready_mark():
    rows = ["..ooo..", ".ohhho.", "ohhshho", "ohhhhho", "ohhhhdo", ".ohhdo.", "..ooo.."]
    return inked(sprite(rows, {"o": GOLD, "h": HONEY_LIGHT, "s": HONEY_SHINE, "d": HONEY}), TRIM)


# --- the hive on the island at the hut's grain (2026-10-01, `/grill-me` with Richard) -------
# The same design as the 2.0 island hive above (pale-blue boxes, red gable roof, grey and
# flaking when abandoned, an open shelf of honey jars behind it), drawn at one world px an art
# px with twice the pixels, so `Hive.ART_SCALE` is 1.0 and every coordinate the json records
# doubled. The shelf is the hut's oak (`build_shed_v2.WALL`); the jars wear gingham lids. The
# functions above stay as the record `tools/hive_mockup.py` draws from.
from build_shed_v2 import WALL as _OAK

HD_W, HD_H = ISLAND_W * 2, ISLAND_H * 2
HD_CX, HD_YT, HD_WALL = ISLAND_CX * 2, ISLAND_YT * 2, ISLAND_WALL * 2
HD_LR, HD_HR, HD_DEP = (4, 34), 24, (4, -2)
HD_BR = (HD_LR[0] + 36, HD_LR[1] + 18)
HD_PLANKS = (4, 18)
HD_JAR_PITCH = 5


def oak(t, old=False):
    c = _OAK[max(0, min(6, t))]
    if old:
        c = tuple(int(c[i] * 0.55 + g * 0.45) for i, g in enumerate((128, 124, 116)))
    return tuple(c) + (255,)


def jar_hd(a, x, y):
    """A honey jar standing on row y: four wide, a glass shoulder, a gingham lid."""
    for yy in range(y - 4, y + 1):
        for i, c in enumerate((HONEY_MID, HONEY, HONEY_LIGHT, HONEY_MID)):
            a.px(x + i, yy, c)
    for i in range(4):
        a.px(x + i, y, HONEY_DEEP)
    a.px(x + 2, y - 3, HONEY_SHINE)
    a.px(x + 2, y - 2, HONEY_SHINE)
    a.px(x + 1, y - 4, mix(HONEY_LIGHT, WAX_LIT, 0.5))
    for i in range(4):
        a.px(x + i, y - 5, GINGHAM_WHITE if i % 2 else GINGHAM_RED)
        a.px(x + i, y - 6, GINGHAM_RED if i % 2 else GINGHAM_WHITE)


def island_hive_hd(paint, state, jars=0, window=None, drip=False):
    im = inked(_island_raw_hd(paint, state, jars, window, drip))
    if state == "weathered":
        _cobweb_hd(im)
    return im


def _cobweb_hd(im):
    """A cobweb in the shelf's top corner, pale threads where nothing else is drawn."""
    ax, ay = 2, 13
    pts = set()
    for r in range(1, 8):
        pts.update({(ax + r, ay), (ax, ay + r), (ax + r - r // 3, ay + r // 2 + r // 3)})
    for r in (3, 6):
        for k in range(r + 1):
            pts.add((ax + k, ay + r - k))
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height and im.getpixel((x, y))[3] == 0:
            im.putpixel((x, y), (235, 235, 230, 120))


def _island_raw_hd(paint, state, jars=0, window=None, drip=False, shelf=True, hive=True):
    a = Art(HD_W, HD_H)
    lit, base, shade, deep = paint
    old = state == "weathered"
    roof = ROOF_OLD if old else ROOF
    rng = random.Random(7)
    Lr, Hr, dep, Br = HD_LR, HD_HR, HD_DEP, HD_BR

    def at(p, k, back=False):
        return (p[0] + (dep[0] if back else 0), p[1] - k + (dep[1] if back else 0))

    def front_y(x, k):
        return Lr[1] - k + (x - Lr[0]) // 2

    if shelf:
        for p_ in (Lr, Br):
            bx, by = at(p_, 0, back=True)
            a.rect(bx, by - Hr, 2, Hr + 1, oak(1, old))
        for k in HD_PLANKS:
            a.fill_by([at(Lr, k), at(Br, k), at(Br, k, True), at(Lr, k, True)],
                      lambda x, y: oak(5 if (x * 3 + y) % 7 else 4, old))
            for x in range(Lr[0], Br[0] + 2):
                y = front_y(x, k)
                a.px(x, y, oak(4, old))
                a.px(x, y + 1, oak(3 if x % 9 else 2, old))
                a.px(x, y + 2, oak(1, old))
        for j in range(jars):
            k = HD_PLANKS[1] if j < 6 else HD_PLANKS[0]
            x = Lr[0] + 4 + (j % 6) * HD_JAR_PITCH
            jar_hd(a, x, front_y(x + 1, k) - 1)
        for p_ in (Lr, Br):
            a.rect(p_[0], p_[1] - Hr, 1, Hr + 4, oak(2, old))
            a.rect(p_[0] + 1, p_[1] - Hr, 1, Hr + 4, oak(3, old))
            a.px(p_[0] + 1, p_[1] - Hr, oak(5, old))
    if not hive:
        return a.im

    cx, yT, H = HD_CX, HD_YT, HD_WALL
    c = yT + 8 + H
    sl, sr, sb, st = (cx - 20, c), (cx + 20, c), (cx, c + 10), (cx, c - 10)
    a.fill_by([sl, st, sr, sb], lambda x, y: oak(4 if int(y - (x - cx) * 0.5) % 4 else 3, old))
    a.poly([sl, sb, (sb[0], sb[1] + 4), (sl[0], sl[1] + 4)], oak(1, old))
    a.poly([sb, sr, (sr[0], sr[1] + 4), (sb[0], sb[1] + 4)], oak(2, old))
    for x in range(sl[0], sr[0] + 1):
        a.px(x, sb[1] - abs(x - cx) // 2, oak(5, old))
    for lx, ly in ((sl[0] + 2, sl[1] + 4), (sb[0] - 1, sb[1] + 4), (sr[0] - 3, sr[1] + 4)):
        a.rect(lx, ly, 1, 5, oak(0, old))
        a.rect(lx + 1, ly, 1, 5, oak(2, old))

    L, B, R = (cx - 16, yT + 8), (cx, yT + 16), (cx + 16, yT + 8)
    grain_l = mix(shade, deep, 0.3)
    grain_r = mix(base, shade, 0.35)
    a.fill_by([L, B, (B[0], B[1] + H), (L[0], L[1] + H)],
              lambda x, y: grain_l if (y - (x - L[0]) // 2) % 3 == 0 and (x + y) % 5 else shade)
    a.fill_by([B, R, (R[0], R[1] + H), (B[0], B[1] + H)],
              lambda x, y: grain_r if (y + (x - cx) // 2) % 3 == 0 and (x * 2 + y) % 5 else base)
    for y in range(B[1], B[1] + H):
        a.px(cx, y, lit)
        a.px(cx - 1, y, mix(shade, lit, 0.25))
    half = H // 2
    for x in range(cx - 16, cx):
        y = yT + 8 + (x - (cx - 16)) // 2
        a.px(x, y + half, deep)
        a.px(x, y + half - 1, mix(shade, lit, 0.3))
        a.px(x, y, mix(shade, lit, 0.4))
    for x in range(cx, cx + 17):
        y = yT + 16 - (x - cx) // 2
        a.px(x, y + half, deep)
        a.px(x, y + half - 1, lit)
        a.px(x, y, lit)
    # handholds: a dark slot with a lit lip under it, one a box on the shaded face
    for k in (5, 5 + half):
        for x in range(cx - 12, cx - 5):
            y = yT + 8 + k + (x - (cx - 16)) // 2
            a.px(x, y, deep)
            a.px(x, y + 1, mix(shade, lit, 0.45))
    for x in range(cx + 9, cx + 15):
        y = yT + 16 + half + 4 - (x - cx) // 2
        a.px(x, y, deep)
        a.px(x, y + 1, lit)
    if old:
        # grey boards with flakes of the blue it had, and a split down one board
        for _ in range(9):
            # patches of the old paint hanging on, a few pixels each, not a sprinkle
            x0 = rng.randint(cx - 14, cx + 13)
            y0 = rng.randint(yT + 12, yT + 8 + H)
            for _ in range(rng.randint(2, 5)):
                x, y = x0 + rng.randint(0, 2), y0 + rng.randint(0, 1)
                a.px(x, y, PAINTS["sky"][2 if x < cx else 1])
        for k in range(6):
            a.px(cx + 5 + (k % 2), yT + 20 + k, deep)
    # the entrance: a dark slot along the foot of the lit face, the landing board under it
    for x in range(cx + 4, cx + 14):
        y = B[1] + H - 1 - (x - cx) // 2
        a.px(x, y - 1, (40, 26, 18, 255))
        a.px(x, y, (40, 26, 18, 255))
        a.px(x, y + 1, oak(5, old))
        a.px(x, y + 2, oak(3, old))
    if drip:
        dx = cx + 10
        lip = B[1] + H - (dx - cx) // 2
        for k in range(2, 7):
            a.px(dx, lip + k, HONEY)
            a.px(dx + 1, lip + k, HONEY_LIGHT if k < 5 else HONEY)
        a.rect(dx - 1, lip + 7, 3, 2, HONEY)
        a.px(dx + 1, lip + 7, HONEY_SHINE)
    if not old:
        for x in range(cx + 4, cx + 14):
            for k in range(-2, 6):
                y = yT + 16 + k + 2 - (x - cx) // 2
                edge = x in (cx + 4, cx + 13) or k in (-2, 5)
                if edge:
                    a.px(x, y, TRIM if (x == cx + 4 or k == -2) else TRIM_SHADE)
                elif x == cx + 9:
                    a.px(x, y, TRIM_SHADE)
                elif state == "full":
                    a.px(x, y, HONEY_LIGHT if k < 3 else HONEY)
                elif window == "dark":
                    a.px(x, y, DARK_GLASS)
                else:
                    a.px(x, y, HONEY if k >= 2 else DARK_GLASS)
        if state == "full":
            a.px(cx + 6, yT + 16, HONEY_SHINE)
            a.px(cx + 11, yT + 13, HONEY_SHINE)
    # the roof: a gable, ridge along the shaded face like the hut's, the gable end lit
    rL, rT, rR, rB = (cx - 20, yT + 10), (cx, yT), (cx + 20, yT + 10), (cx, yT + 20)
    h = 14
    A = ((rL[0] + rT[0]) / 2, (rL[1] + rT[1]) / 2 - h)
    Bp = ((rB[0] + rR[0]) / 2, (rB[1] + rR[1]) / 2 - h)

    def shingle(x, y):
        d = y - (A[1] + 0.5 * (x - A[0]))
        if d < 2:
            return roof["lit"] if d < 1 else roof["base"]
        row, pr = int((d - 2) // 4), (d - 2) % 4
        if old and rng.random() < 0.07:
            return roof["deep"]
        if pr < 1:
            return roof["shade"]
        if int(x + (row % 2) * 3) % 6 == 0:
            return roof["shade"]
        if pr < 2:
            return roof["lit"]
        return roof["base"]

    a.fill_by([rL, rB, Bp, A], shingle)
    for x in range(int(rL[0]), int(rB[0]) + 1):
        a.px(x, rL[1] + (x - rL[0]) * 0.5, roof["deep"])
    a.fill_by([rB, rR, Bp], lambda x, y: mix(lit, base, 0.35) if int(y + (x - cx) * 0.5) % 3 == 0 else lit)
    for x in range(int(rB[0]), int(Bp[0]) + 1):
        y = rB[1] - (x - rB[0]) * 1.9 - 0.5
        a.px(x, y, TRIM)
        a.px(x + 1, y, TRIM_SHADE)
    vx = (rB[0] + rR[0] + Bp[0]) / 3
    vy = (rB[1] + rR[1] + Bp[1]) / 3
    a.rect(vx - 1, vy - 1, 2, 2, (60, 40, 28, 255))
    return a.im


def island_swarm_hd():
    """The swarm hanging off the shrub: a cone of bees, gold and dark in bands, wings catching
    the light, its top middle where it hangs."""
    w, h = 17, 21
    a = Art(w, h)
    rng = random.Random(3)
    for y in range(h):
        f = (y + 1) / (h + 1)
        half = 7.5 * (math.sin(math.pi * min(1.0, f * 1.25)) ** 0.7) if f < 0.8 else 7.5 * (1 - f) * 2.5
        for x in range(w):
            dx = x - w // 2
            if abs(dx) > half:
                continue
            band = (x + 2 * y + (y // 3)) % 4
            c = BEE_GOLD if band < 2 else BEE_STRIPE if band == 2 else HONEY_DEEP
            if dx > half * 0.4 and c == BEE_GOLD:
                c = HONEY_LIGHT
            a.px(x, y, c)
            if rng.random() < 0.06:
                a.px(x, y, WING_EDGE)
    return inked(a.im)


def ready_mark_hd():
    return big(ready_mark(), 2)


def _island_geometry_hd():
    cx, yT, H = HD_CX, HD_YT, HD_WALL
    c = yT + 8 + H
    ink = 1
    foot = (cx + ink, c + 8 + ink)
    mid = (foot[0] + 0.5, foot[1] + 0.5)
    ground = [(mid[0] - 20, mid[1]), (mid[0], mid[1] - 10), (mid[0] + 20, mid[1]), (mid[0], mid[1] + 10)]
    for p in (HD_LR, HD_BR):
        ground.append((p[0] + ink + 0.5, p[1] + 3 + ink + 0.5))
        ground.append((p[0] + HD_DEP[0] + ink + 0.5, p[1] + HD_DEP[1] + ink + 0.5))
    tiles = [_to_tiles(x - mid[0], y - mid[1]) for x, y in ground]
    lo = (min(t[0] for t in tiles), min(t[1] for t in tiles))
    hi = (max(t[0] for t in tiles), max(t[1] for t in tiles))
    centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)
    half = ((hi[0] - lo[0]) / 2, (hi[1] - lo[1]) / 2)
    empty = island_hive_hd(ISLAND_PAINT, "colony", window="dark")
    full = island_hive_hd(ISLAND_PAINT, "full")
    seen = {}
    for y in range(empty.height):
        for x in range(empty.width):
            if empty.getpixel((x, y)) != full.getpixel((x, y)):
                seen.setdefault(x, []).append(y)
    cols = [[x, min(ys), max(ys) - min(ys) + 1] for x, ys in sorted(seen.items())]
    ex = cx + 8
    entrance = (ex + ink, yT + 16 + H - (ex - cx) // 2 + ink)
    return {"foot": foot, "centre": centre, "half": half, "window_cols": cols, "entrance": entrance}


# --- room pieces ---------------------------------------------------------------------------
def room_hive(paint, window=0.6, lid=True, open_top=False):
    """The hive front-on, as the room stands it: stand, three flared lifts, a gable roof."""
    lit, base, shade, deep = paint
    W, Hh = 172, 214
    a = Art(W, Hh)
    cx = W // 2
    LH = 36
    top = 64 if lid else 20
    # legs and stand
    for x0, h, col in ((cx - 42, 18, DARK_WOOD_LO), (cx + 36, 18, DARK_WOOD_LO)):
        a.rect(x0, top + 3 * LH + 8, 6, h, col)
    for x0 in (cx - 58, cx + 50):
        a.rect(x0, top + 3 * LH + 8, 8, 26, DARK_WOOD)
        a.rect(x0 + 6, top + 3 * LH + 8, 2, 26, DARK_WOOD_HI)
    a.rect(cx - 68, top + 3 * LH, 136, 9, DARK_WOOD)
    a.rect(cx - 68, top + 3 * LH, 136, 2, DARK_WOOD_HI)
    a.poly([(cx - 30, top + 3 * LH - 1), (cx + 30, top + 3 * LH - 1), (cx + 40, top + 3 * LH + 12),
            (cx - 40, top + 3 * LH + 12)], PINE)
    a.rect(cx - 34, top + 3 * LH + 7, 68, 2, PINE_LIT)
    # the lifts, each flared at its foot, the lit side on the right
    for i in range(3):
        y0 = top + i * LH

        def lift(x, y, y0=y0):
            f = (x - (cx - 64)) / 128.0
            c = base
            if f < 0.16:
                c = shade
            elif f > 0.8:
                c = lit
            dy = y - y0
            if dy < 3:
                return deep if dy < 2 else shade
            if dy >= LH - 2:
                return lit
            if dy % 12 == 0:
                return shade if f < 0.8 else base
            return c

        a.fill_by([(cx - 58, y0), (cx + 58, y0), (cx + 63, y0 + LH), (cx - 63, y0 + LH)], lift)
        rng = random.Random(i * 13)
        for _ in range(9):
            x = rng.randint(cx - 54, cx + 50)
            a.rect(x, y0 + rng.randint(5, LH - 5), rng.randint(3, 8), 1, fade(shade, 150))
    # the entrance slot
    a.rect(cx - 22, top + 3 * LH - 7, 44, 5, (40, 26, 18, 255))
    a.rect(cx - 22, top + 3 * LH - 7, 44, 1, (70, 48, 30, 255))
    # the honey window in the middle lift
    wy = top + LH + 9
    a.rect(cx - 18, wy, 36, 20, TRIM)
    a.rect(cx - 18, wy + 18, 36, 2, TRIM_SHADE)
    fill_to = wy + 3 + int(14 * (1 - window))
    for y in range(wy + 3, wy + 17):
        for x in range(cx - 15, cx + 15):
            if y >= fill_to:
                hexy = ((x + (y // 3) % 2 * 2) % 4 == 0) or (y % 3 == 0)
                c = HONEY_MID if hexy else (HONEY if y > fill_to + 3 else HONEY_LIGHT)
            else:
                c = (70, 52, 38, 255)
            a.px(x, y, c)
    for k in range(4):
        a.px(cx + 8 + k, wy + 4 + k, fade(HONEY_SHINE, 200))
    a.rect(cx - 1, wy + 3, 2, 14, TRIM)
    if lid:
        # eave board, then the pediment and the two roof planes
        a.rect(cx - 72, top - 8, 144, 8, TRIM)
        a.rect(cx - 72, top - 2, 144, 2, TRIM_SHADE)
        a.poly([(cx - 64, top - 8), (cx, top - 50), (cx + 64, top - 8)], lit)

        def plane(side):
            def fn(x, y):
                edge_y = top - 62 + abs(x - cx) * (54 / 80.0)
                d = y - edge_y
                if d < 1.5:
                    return ROOF["lit"] if side > 0 else ROOF["base"]
                row = int(d / 4)
                along = abs(x - cx) + (row % 2) * 4
                if int(d) % 4 == 3 or along % 8 == 0:
                    return ROOF["deep"] if side < 0 else ROOF["shade"]
                return ROOF["base"] if side < 0 else ROOF["lit"] if d < 4 else ROOF["base"]
            return fn

        a.fill_by([(cx - 82, top - 6), (cx, top - 62), (cx, top - 50), (cx - 66, top - 7)], plane(-1))
        a.fill_by([(cx + 82, top - 6), (cx, top - 62), (cx, top - 50), (cx + 66, top - 7)], plane(1))
        a.rect(cx - 3, top - 64, 6, 4, ROOF["lit"])
        # a honey hex painted on the pediment
        hx, hy = cx - 7, top - 34
        hexa = ["..xxxx..", ".xhhhhx.", "xhhshhhx", "xhhhhhhx", "xhhhhdhx", ".xhhddx.", "..xxxx.."]
        a.paste(sprite(hexa, {"x": HONEY_MID, "h": HONEY_LIGHT, "s": HONEY_SHINE, "d": HONEY}), hx, hy)
    if open_top:
        a.rect(cx - 58, top - 6, 116, 6, (60, 40, 26, 255))
        for k in range(10):
            a.rect(cx - 54 + k * 11, top - 7, 6, 7, PINE if k % 2 else PINE_LIT)
    return inked(a.im), (cx, top + 3 * LH - 5)


def smoker(squeeze=0.0):
    """The smoker. `squeeze` 0..1 closes the bellows: the outer board swings in towards the
    can about its hinge, the leather between them folding up (2026-10-04, Richard: the back of
    the smoker should move when it puffs)."""
    a = Art(112, 104)
    ox, oy = 104 - 18 * squeeze, 34 + 7 * squeeze
    # the bellows first, behind the can: two boards hinged at the foot, open in a V, the
    # leather between them pleated
    hinge = (70, 96)

    def pleats(x, y):
        ang = math.atan2(hinge[1] - y, x - hinge[0])
        return LEATHER["lit"] if int(ang * 26) % 2 == 0 else LEATHER["shade"]

    a.fill_by([(70, 40), (ox - 8, oy), (78, 96), (70, 96)], pleats)
    a.poly([(64, 38), (71, 38), (71, 98), (64, 98)], DARK_WOOD)
    a.rect(64, 38, 2, 60, DARK_WOOD_HI)
    a.poly([(72, 98), (79, 98), (ox, oy), (ox - 7, oy - 3)], DARK_WOOD_HI)
    a.poly([(76, 98), (79, 98), (ox, oy), (ox - 3, oy - 1)], PINE_SHADE)
    a.rect(69, 94, 6, 5, BRASS["shade"])
    # the can, round and steel, with its perforated guard
    def can(x, y):
        f = (x - 30) / 34.0
        if y < 44:
            return STEEL["lit"] if y < 42 else STEEL["base"]
        if y > 94:
            return STEEL["deep"]
        if f < 0.12:
            return STEEL["deep"]
        if f < 0.3:
            return STEEL["shade"]
        if f < 0.58:
            return STEEL["base"]
        if f < 0.7:
            return STEEL["lit"]
        if f < 0.78:
            return STEEL["hi"]
        return STEEL["base"] if f < 0.92 else STEEL["shade"]

    a.fill_by([(30, 40), (64, 40), (64, 98), (30, 98)], can)
    for y in range(60, 92, 5):
        for x in range(34 + (y // 5) % 2 * 2, 62, 5):
            a.rect(x, y, 2, 2, STEEL["deep"])
    a.rect(29, 57, 36, 1, STEEL["shade"])
    a.rect(29, 92, 36, 2, STEEL["shade"])
    # the lid, a cone, and a brass spout bent towards the hive
    a.fill_by([(30, 41), (64, 41), (54, 26), (40, 26)],
              lambda x, y: STEEL["lit"] if x > 50 else STEEL["base"] if x > 38 else STEEL["shade"])
    a.poly([(40, 28), (50, 24), (30, 14), (18, 16), (16, 22), (26, 24)], BRASS["base"])
    a.poly([(38, 24), (48, 22), (28, 14), (20, 15)], BRASS["lit"])
    a.rect(14, 16, 5, 7, BRASS["shade"])
    a.rect(14, 18, 2, 3, (40, 26, 18, 255))
    a.rect(64, 60, 10, 4, LEATHER["base"])
    return inked(a.im)


def puff(a, x, y, r, seed, alpha=235):
    """A cloud of smoke, whole pixels, dissolving at the rim the way the foam does."""
    rng = random.Random(seed)
    for yy in range(int(y - r), int(y + r) + 1):
        for xx in range(int(x - r), int(x + r) + 1):
            q = math.hypot(xx - x, (yy - y) * 1.15) / r
            if q > 1:
                continue
            if q > 0.72 and rng.random() < (q - 0.72) * 3.2:
                continue
            lx = (xx - x) / r
            ly = (yy - y) / r
            tone = SMOKE[0] if lx + ly < -0.35 else SMOKE[1] if lx + ly < 0.45 else SMOKE[2]
            a.px(xx, yy, fade(tone, alpha * (1.0 - max(0, q - 0.5) * 0.6)))


CELL_SMALL = ([".xxx.", "xxxxx", "xxxxx", ".xxx."], (6, 5, 3))
# Pointy hexes with straight side walls; each row tucks its tips into the row above's.
CELL_BIG = (["...x...", ".xxxxx.", "xxxxxxx", "xxxxxxx", "xxxxxxx", "xxxxxxx", ".xxxxx.", "...x..."],
            (8, 7, 4))


def comb(a, x0, y0, x1, y1, kind_of, cell=CELL_SMALL, wall=WAX_WALL, seed=5):
    """Honeycomb on whole pixels, each cell coloured by kind. A cap (wax, brood, pollen) is a
    dome lit top-left; an open cell (honey, empty) is a hole, in shadow under its top-left
    wall, the honey in it glowing bottom-right where the light comes through."""
    pattern, (dx, dy, off) = cell
    inside = {(x, y) for y, r in enumerate(pattern) for x, c in enumerate(r) if c == "x"}
    cw, ch = len(pattern[0]), len(pattern)
    rng = random.Random(seed)
    a.rect(x0, y0, x1 - x0, y1 - y0, wall)

    def put(px, py, c):
        if x0 <= px < x1 and y0 <= py < y1:
            a.px(px, py, c)

    for r in range(-1, (y1 - y0) // dy + 2):
        for q in range(-1, (x1 - x0) // dx + 2):
            cx0 = x0 + q * dx + (off if r % 2 else 0)
            cy0 = y0 + r * dy
            kind = kind_of(cx0 + cw // 2, cy0 + ch // 2, rng)
            if kind == "pollen":
                p = rng.choice(POLLEN)
                tones = (p, mix(p, (255, 255, 255), 0.4), mix(p, (0, 0, 0), 0.28))
            else:
                tones = {
                    "wax": (WAX, WAX_LIT, WAX_SHADE),
                    "brood": (BROOD, BROOD_LIT, BROOD_SHADE),
                    "honey": (HONEY, HONEY_MID, HONEY_LIGHT),
                    "fresh": (HONEY_LIGHT, HONEY, HONEY_SHINE),
                    "empty": (CELL_EMPTY, CELL_DEEP, CELL_EMPTY),
                    "larva": (CELL_EMPTY, CELL_DEEP, CELL_EMPTY),
                }[kind]
            fill, tl, br = tones
            for xx, yy in inside:
                c = fill
                # a small light on the upper-left rim, a shade along the lower-right one
                if (xx, yy - 1) not in inside and xx <= cw // 2:
                    c = tl
                elif (xx - 1, yy) not in inside and yy < ch // 2:
                    c = tl
                elif (xx, yy + 1) not in inside or ((xx + 1, yy) not in inside and yy >= ch // 2):
                    c = br
                put(cx0 + xx, cy0 + yy, c)
            mx, my = cx0 + cw // 2, cy0 + ch // 2
            if kind == "honey":
                put(mx - 1, my - 1, HONEY_SHINE)
            elif kind == "fresh":
                put(mx - 1, my - 1, TRIM)
                if cw > 5:
                    put(mx, my - 1, HONEY_SHINE)
            elif kind == "larva":
                for p_ in ((mx - 1, my), (mx - 1, my - 1), (mx, my - 1), (mx + 1, my)):
                    put(*p_, TRIM)
            elif kind == "wax" and cw > 5:
                put(mx, my, WAX_SHADE)


def frame_wood(a, x0, y0, w, h):
    """A hive frame's pine: a top bar with its ears, side bars, a bottom bar."""
    a.rect(x0 - 12, y0, w + 24, 9, PINE)
    a.rect(x0 - 12, y0, w + 24, 2, PINE_LIT)
    a.rect(x0 - 12, y0 + 7, w + 24, 2, PINE_SHADE)
    a.rect(x0, y0, 7, h, PINE)
    a.rect(x0, y0, 2, h, PINE_LIT)
    a.rect(x0 + w - 7, y0, 7, h, PINE_SHADE)
    a.rect(x0 + w - 7, y0, 2, h, PINE)
    a.rect(x0, y0 + h - 6, w, 6, PINE)
    a.rect(x0, y0 + h - 2, w, 2, PINE_DEEP)


def brood_frame(w, h, seed=5, uncap_to=None, cell=CELL_SMALL):
    """A frame of comb: capped honey arching over the top, a ring of pollen, brood inside.
    With uncap_to it is a honey frame cut open down to that row, the last of it fresh.

    uncap_to above the comb (-1) is a frame capped all over, and past its foot (a huge number)
    one cut open all over. Either way the cells are laid from the comb's own top row, so the
    two faces of one frame line up cell for cell; the cut is held inside the comb for the
    drawing, while which cells are fresh still reads the row asked for."""
    a = Art(w + 26, h + 2)
    fx0, fy0 = 13, 0
    frame_wood(a, fx0, fy0, w, h)
    ix0, iy0, ix1, iy1 = fx0 + 7, fy0 + 9, fx0 + w - 7, fy0 + h - 6
    mx, my = (ix0 + ix1) / 2, (iy0 + iy1) / 2 + 8
    rx, ry = (ix1 - ix0) / 2, (iy1 - iy0) / 2

    def kind_of(x, y, rng):
        if uncap_to is not None:
            if y >= uncap_to:
                return "wax"
            return "fresh" if y >= uncap_to - 22 else "honey"
        q = math.hypot((x - mx) / rx, (y - my) / ry) + rng.uniform(-0.05, 0.05)
        if q < 0.55:
            return "larva" if rng.random() < 0.05 else "empty" if rng.random() < 0.04 else "brood"
        if q < 0.74:
            return "pollen" if rng.random() < 0.85 else "empty"
        if y > my + ry * 0.35:
            return "empty" if rng.random() < 0.5 else "pollen"
        return "honey" if rng.random() < 0.22 else "wax"

    if uncap_to is None:
        comb(a, ix0, iy0, ix1, iy1, kind_of, cell=cell, seed=seed)
    else:
        # the cut face keeps its pale wax walls round pools of honey; below, the caps
        cut = min(max(uncap_to, iy0), iy1)
        comb(a, ix0, iy0, ix1, cut, kind_of, cell=cell, wall=WAX, seed=seed)
        comb(a, ix0, cut, ix1, iy1, kind_of, cell=cell, seed=seed)
    return inked(a.im)


def hot_knife(length):
    a = Art(length + 70, 22)
    a.rect(0, 8, length, 6, STEEL["base"])
    a.rect(0, 8, length, 2, STEEL["hi"])
    a.rect(0, 12, length, 1, STEEL["shade"])
    a.rect(0, 13, length, 1, (255, 120, 60, 255))
    a.poly([(0, 8), (6, 8), (0, 14)], (0, 0, 0, 0))
    a.rect(length, 6, 8, 10, BRASS["base"])
    a.rect(length, 6, 8, 2, BRASS["lit"])
    a.rect(length + 8, 5, 34, 12, DARK_WOOD)
    a.rect(length + 8, 5, 34, 3, DARK_WOOD_HI)
    a.rect(length + 8, 14, 34, 3, DARK_WOOD_LO)
    for k in range(4):
        a.rect(length + 13 + k * 8, 8, 1, 6, DARK_WOOD_LO)
    return inked(a.im)


def wax_sheet(length, body=True):
    """The capping as it comes away in one piece: a wavy sheet riding the top of the blade,
    dimpled with the cells it was cut from, a gloss along its crown, and at the knife's tip
    rolled over the edge in a curl. Without its body it is the curl alone, on the same canvas,
    so the anchor where it meets the blade is the same point."""
    a = Art(length + 34, 56)
    foot = 38
    for x in range(length if body else 0):
        t = x / (length - 1)
        # a rolled log of wax, fat and wavy, easing thinner towards the handle
        lift = int(11 + 3 * math.sin(t * math.pi * 3 + 0.5) + 2 * math.sin(t * math.pi * 7) - t * 4)
        top = foot - lift
        for y in range(top, foot + 1):
            d = (y - top) / max(1, lift)
            c = WAX_LIT if d < 0.18 else WAX if d < 0.6 else WAX_SHADE if d < 0.85 else WAX_WALL
            if (x + ((y - top) // 3) % 2 * 2) % 5 == 0 and (y - top) % 3 == 1 and 0.2 < d < 0.8:
                c = WAX_SHADE
            if y == top + 1 and (x // 6) % 3 != 2:
                c = (255, 253, 240, 255)
            a.px(x + 22, y, c)
        if x % 23 == 7:
            a.rect(x + 22, foot - lift + 2, 2, 2, HONEY_LIGHT)
    # the curl at the knife's tip, rolled right over the edge
    cx, cy = 18, foot - 2
    for k in range(180):
        ang = -math.pi * 0.35 + k / 179 * math.pi * 2.0
        for rr in range(6):
            x = cx + math.cos(ang) * (13 - rr)
            y = cy + math.sin(ang) * (12 - rr)
            up_ = -math.sin(ang)
            c = WAX_LIT if up_ > 0.55 and rr < 2 else WAX if up_ > -0.3 else WAX_SHADE
            a.px(x, y, c)
    a.rect(cx - 2, cy + 12, 2, 6, HONEY)
    a.rect(cx - 3, cy + 18, 4, 3, HONEY)
    a.px(cx - 1, cy + 18, HONEY_SHINE)
    return inked(a.im), (23, foot + 1)


def extractor(crank=True, stream=True, bucket_honey=True):
    """The honey extractor: a steel drum on legs, the comb spun to a blur inside it, a brass
    gear box and crank on top, a gate at its foot over an enamel bucket. For the game the crank
    arm and its knob come off (the step turns them), and the stream and the honey in the
    bucket (the step pours them)."""
    a = Art(210, 262)
    x0, x1 = 24, 186
    top, bottom = 76, 198

    def drum(x, y):
        f = (x - x0) / (x1 - x0)
        for edge, col in ((0.07, STEEL["deep"]), (0.22, STEEL["shade"]), (0.5, STEEL["base"]),
                          (0.62, STEEL["lit"]), (0.7, STEEL["hi"]), (0.9, STEEL["base"])):
            if f < edge:
                return col
        return STEEL["shade"]

    # legs
    for lx in (x0 + 8, x1 - 18):
        a.rect(lx, bottom, 10, 58, STEEL["shade"])
        a.rect(lx, bottom, 3, 58, STEEL["lit"])
        a.rect(lx - 2, bottom + 56, 14, 3, STEEL["deep"])
    a.fill_by([(x0, top), (x1, top), (x1, bottom), (x0, bottom)], drum)
    a.ell(x0, bottom - 12, x1 - x0, 24, STEEL["shade"])
    a.fill_by([(x0, bottom - 12), (x1, bottom - 12), (x1, bottom), (x0, bottom)], drum)
    for sy in (top + 44, top + 98):
        a.rect(x0, sy, x1 - x0, 2, STEEL["deep"])
        a.rect(x0, sy + 2, x1 - x0, 1, STEEL["hi"])
        for rx in range(x0 + 6, x1, 14):
            a.px(rx, sy - 3, STEEL["deep"])
    # the open top: rim, the inner wall with honey flung up it, frames spun to a blur
    a.ell(x0, top - 16, x1 - x0, 32, STEEL["lit"])
    a.ell(x0 + 4, top - 13, x1 - x0 - 8, 26, (52, 44, 40, 255))
    rng = random.Random(3)
    for _ in range(46):
        ang = rng.uniform(math.pi * 1.05, math.pi * 1.95)
        rx, ry = (x1 - x0 - 12) / 2, 11
        x = (x0 + x1) / 2 + math.cos(ang) * rx
        y = top + math.sin(ang) * ry + 1
        a.rect(x, y, 2, rng.randint(2, 6), HONEY if rng.random() < 0.7 else HONEY_LIGHT)
    for k, (rx, ry, col) in enumerate(((58, 8, (150, 160, 170, 180)), (44, 6, (200, 210, 216, 200)),
                                       (30, 4, (240, 244, 246, 210)))):
        for s in range(60):
            ang = math.pi * (0.1 + 0.8 * s / 60)
            a.px((x0 + x1) / 2 + math.cos(ang) * rx, top + math.sin(ang) * ry + 2, col)
            a.px((x0 + x1) / 2 - math.cos(ang) * rx, top - math.sin(ang) * ry + 2, col)
    # the crank: a bar across, a brass gear box, the arm and its wooden knob
    mid = (x0 + x1) // 2
    a.rect(x0 + 10, top - 4, x1 - x0 - 20, 5, STEEL["base"])
    a.rect(x0 + 10, top - 4, x1 - x0 - 20, 1, STEEL["hi"])
    a.rect(mid - 12, top - 28, 24, 24, BRASS["base"])
    a.rect(mid - 12, top - 28, 24, 3, BRASS["lit"])
    a.rect(mid + 8, top - 25, 4, 21, BRASS["shade"])
    for k in range(5):
        a.rect(mid - 10 + k * 5, top - 32, 3, 4, BRASS["base"])
    a.rect(mid - 3, top - 44, 6, 16, STEEL["base"])
    if crank:
        a.poly([(mid - 2, top - 44), (mid + 3, top - 46), (mid + 52, top - 62), (mid + 50, top - 57)],
               STEEL["lit"])
        a.paste(_knob_raw(), mid + 46, top - 76)
    # the honey gate, a stream, and the bucket
    a.rect(mid - 8, bottom + 2, 16, 12, BRASS["base"])
    a.rect(mid - 8, bottom + 2, 16, 3, BRASS["lit"])
    a.rect(mid + 6, bottom - 6, 4, 10, BRASS["shade"])
    if stream:
        a.rect(mid - 3, bottom + 14, 6, 16, HONEY)
        a.rect(mid + 1, bottom + 14, 2, 16, HONEY_LIGHT)
    b0 = bottom + 26
    a.poly([(mid - 30, b0), (mid + 30, b0), (mid + 26, b0 + 30), (mid - 26, b0 + 30)], ENAMEL["base"])
    a.rect(mid - 30, b0, 60, 4, ENAMEL["lit"])
    if bucket_honey:
        a.rect(mid - 26, b0 + 4, 52, 4, HONEY)
        a.rect(mid - 26, b0 + 4, 52, 1, HONEY_LIGHT)
    a.rect(mid + 12, b0 + 8, 8, 20, ENAMEL["lit"])
    a.rect(mid - 28, b0 + 8, 5, 20, ENAMEL["shade"])
    # the shaft's top, and the arm's reach from it: the knob turns round an ellipse there
    return inked(a.im), (mid + 1, top - 62, 51)


def _knob_raw():
    """The crank's wooden knob, uninked: an upright peg, lit down its left."""
    a = Art(8, 18)
    a.rect(0, 0, 8, 18, DARK_WOOD)
    a.rect(0, 0, 3, 18, DARK_WOOD_HI)
    return a.im


def knob():
    return inked(_knob_raw())


def jar(fill=0.0, lid=False, label=False, stream=False, seed=0):
    """A glass jar: pale glass, a highlight down the lit side, honey to `fill`."""
    w, h = 44, 58
    a = Art(w, h + 14)
    top = 14
    body = [(4, top + 8), (w - 4, top + 8), (w - 1, top + 14), (w - 1, top + h - 4), (w - 5, top + h),
            (5, top + h), (1, top + h - 4), (1, top + 14)]
    a.poly(body, (214, 234, 240, 90))
    a.rect(8, top + 1, w - 16, 8, (214, 234, 240, 120))
    a.rect(8, top + 3, w - 16, 1, (160, 186, 196, 160))
    a.rect(8, top + 6, w - 16, 1, (160, 186, 196, 160))
    if fill > 0:
        surface = int(top + h - 3 - (h - 16) * fill)

        def honey(x, y):
            if y < surface:
                return None
            if y == surface:
                return HONEY_SHINE if 6 < x < w - 8 else HONEY_LIGHT
            f = (y - surface) / max(1, (top + h - surface))
            c = HONEY_LIGHT if f < 0.15 else HONEY if f < 0.6 else HONEY_MID
            return HONEY_MID if x < 5 else c

        a.fill_by(body, honey)
    a.rect(w - 9, top + 16, 3, h - 24, (255, 255, 255, 170))
    a.rect(6, top + 18, 1, 10, (255, 255, 255, 120))
    if label:
        a.rect(8, top + 26, w - 16, 18, CREAM)
        a.rect(8, top + 26, w - 16, 2, GINGHAM_RED)
        a.rect(8, top + 42, w - 16, 2, GINGHAM_RED)
        hexa = ["..xx..", ".xhhx.", "xhshhx", "xhhhhx", ".xhhx.", "..xx.."]
        a.paste(sprite(hexa, {"x": HONEY_MID, "h": HONEY, "s": HONEY_SHINE}), w // 2 - 3, top + 31)
    if lid:
        cloth = Art(w + 8, 18)
        for y in range(18):
            for x in range(w + 8):
                if y > 10 and (x < 2 + (y - 10) or x > w + 5 - (y - 10)):
                    continue
                on = ((x // 3) % 2) + ((y // 3) % 2)
                cloth.px(x, y, GINGHAM_RED if on == 2 else GINGHAM_PINK if on == 1 else GINGHAM_WHITE)
        cloth.rect(4, 11, w, 2, (120, 70, 40, 255))
        a.paste(cloth.im, -4, top - 12)
    im = inked(a.im)
    return im


def branch_with_swarm(cluster=1.0, swarm=True):
    """A flowering bough reaching in from the left, the swarm hanging off it as a beard of
    bees. Without the swarm it is the bare bough, and the second value is where the swarm's
    top would hang (the top middle of the clump, in the inked picture)."""
    a = Art(360, 180)
    rng = random.Random(8)
    # the bough, from off the left edge, thinning
    pts = [(-10, 30), (60, 26), (130, 34), (200, 30), (262, 40), (300, 36)]
    for i in range(len(pts) - 1):
        (xa, ya), (xb, yb) = pts[i], pts[i + 1]
        thick = 9 - i * 1.3
        for s in range(40):
            t = s / 40
            x, y = xa + (xb - xa) * t, ya + (yb - ya) * t
            a.rect(x, y - thick / 2, 3, thick, BARK[1])
            a.rect(x, y - thick / 2, 3, 2, BARK[0])
            a.rect(x, y + thick / 2 - 2, 3, 2, BARK[2])
    for tx, ty, dx, dy in ((80, 28, 20, -18), (150, 34, 18, 20), (220, 32, 22, -16), (120, 30, -10, 22)):
        a.line([(tx, ty), (tx + dx, ty + dy)], BARK[1], 3)
    # leaves and blossom along it
    for _ in range(70):
        x = rng.randint(0, 300)
        y = 32 + rng.randint(-26, 22)
        if rng.random() < 0.55:
            a.ell(x, y, 8, 5, LEAF[1])
            a.ell(x + 1, y, 5, 2, LEAF[0])
            a.rect(x + 2, y + 3, 5, 1, LEAF[2])
        else:
            for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2), (-1, -1), (1, 1)):
                a.rect(x + dx, y + dy, 2, 2, BLOSSOM[1] if dy <= 0 else BLOSSOM[2])
            a.rect(x - 1, y - 1, 2, 2, BLOSSOM[0])
            a.px(x, y, HONEY_LIGHT)
    im = inked(a.im)
    # the swarm: a hanging beard of bees
    cx, cy = 236, 42
    if not swarm:
        return im, (cx + 1, cy - 2)
    tall = int(92 * cluster)

    def half(t):
        return 28 * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t * 1.2))) * (1 - t ** 2.4) + 2

    mass = bee_mass(half, tall, 31, int(300 * cluster))
    im.alpha_composite(mass, (cx - mass.width // 2 + 1, cy - 2))
    return im, (cx, cy + tall)


def catch_box(paint, rng=None):
    """The open brood box the swarm is shaken into, front-on: its lid off, the top bars
    showing, an entrance hole in its front. Handed an rng it has bees on its bars, as the
    mockup's catch step shows it; the game lays its own bees over a bare box."""
    box = Art(140, 80)
    lit, base, shade, deep = paint
    box.poly([(10, 14), (118, 14), (130, 4), (22, 4)], (60, 40, 26, 255))
    for k in range(10):
        box.poly([(14 + k * 11, 13), (19 + k * 11, 13), (30 + k * 11, 5), (25 + k * 11, 5)],
                 PINE if k % 2 else PINE_LIT)
    box.rect(10, 14, 108, 56, base)
    box.rect(10, 14, 18, 56, shade)
    box.rect(10, 14, 108, 3, lit)
    box.rect(10, 66, 108, 4, deep)
    box.poly([(118, 14), (130, 4), (130, 60), (118, 70)], lit)
    box.ell(50, 34, 30, 8, deep)
    box.ell(52, 35, 26, 5, (60, 40, 26, 255))
    if rng is not None:
        for k in range(16):
            b = bee(facing_left=k % 2 == 0, turn=k % 3)
            box.paste(b, 18 + (k * 17) % 98, rng.randint(0, 10))
    return inked(box.im)


# The bottling bucket stands on a table of dark wood; these are where its pieces go from the
# table's `(bx, by)`, the bucket's top-left, as the pour step lays them out.
BOTTLING_BUCKET_AT = (-2, 0)
BOTTLING_GATE_AT = (38, 84)
BOTTLING_STREAM_AT = (12, 20)       # where the honey leaves the gate, in the gate's own picture


def bottling_stand(a, bx, by):
    """The bottling table: two legs and a top, uninked, straight onto `a`."""
    a.rect(bx - 6, by + 78, 6, 150, DARK_WOOD)
    a.rect(bx + 100, by + 78, 6, 150, DARK_WOOD)
    a.rect(bx - 16, by + 76, 132, 8, DARK_WOOD_HI)
    a.rect(bx - 16, by + 82, 132, 3, DARK_WOOD_LO)


def bottling_bucket():
    """The enamel bottling bucket, its label, lit down one side."""
    bucket = Art(104, 84)
    bucket.poly([(2, 4), (102, 4), (94, 76), (10, 76)], ENAMEL["base"])
    bucket.rect(2, 4, 100, 5, ENAMEL["lit"])
    bucket.fill_by([(2, 4), (102, 4), (94, 76), (10, 76)],
                   lambda x, y: ENAMEL["shade"] if x < 16 else ENAMEL["lit"] if 70 < x < 82 else None)
    bucket.rect(40, 30, 24, 16, CREAM)
    bucket.rect(40, 30, 24, 2, GINGHAM_RED)
    return inked(bucket.im)


def bottling_gate():
    """The brass honey gate under the bucket, its spout pointing down."""
    gate = Art(24, 20)
    gate.rect(4, 0, 16, 12, BRASS["base"])
    gate.rect(4, 0, 16, 3, BRASS["lit"])
    gate.rect(8, 12, 8, 6, BRASS["shade"])
    return inked(gate.im)


def bottling():
    """The pour step's bucket, label and gate on their table, as one piece. The table is inked
    here, where the mockup left it bare on the lawn: every room piece wears the outline.
    Returns the picture and where the honey leaves the gate."""
    bx, by = 16, 0                   # the table's left end is the picture's left edge
    table = Art(132, 228)
    bottling_stand(table, bx, by)
    im = inked(table.im)
    # the table's ink put everything one pixel in; the bucket and gate follow it
    im.alpha_composite(bottling_bucket(), (bx + BOTTLING_BUCKET_AT[0] + 1, by + BOTTLING_BUCKET_AT[1] + 1))
    gx, gy = bx + BOTTLING_GATE_AT[0] + 1, by + BOTTLING_GATE_AT[1] + 1
    im.alpha_composite(bottling_gate(), (gx, gy))
    return im, (gx + BOTTLING_STREAM_AT[0], gy + BOTTLING_STREAM_AT[1])


PIP_WIDTHS = [6, 8, 10, 12, 14, 14, 14, 14, 14, 12, 10, 8, 6]


def pip(state):
    """One comb cell of the step plank: "done" (filled with honey), "now" (lit, a gold ring
    inside the ink) or "todo" (bare wax)."""
    cell = Art(14, 13)
    for y, wdt in enumerate(PIP_WIDTHS):
        for x in range(7 - wdt // 2, 7 + wdt // 2):
            if state == "done":
                c = HONEY_LIGHT if y < 4 else HONEY if y < 10 else HONEY_MID
                if (x, y) in ((5, 3), (6, 2)):
                    c = HONEY_SHINE
            elif state == "now":
                c = HONEY_SHINE if y < 3 else HONEY_LIGHT
            else:
                c = WAX if y < 9 else WAX_SHADE
            cell.px(x, y, c)
    if state == "now":
        return inked(inked(cell.im, GOLD), OUT)
    return inked(cell.im, OUT)


# --- the second pass's pieces (2026-09-30, off tools/hive_mockup2.py) ----------------------
# The smoke's four greys, lit to shaded, and the jar's glass: a thin blue-grey edge rather
# than the near-black, a faint tint, white highlight streaks.
SMOKE_T = ((252, 252, 250, 255), (224, 230, 234, 255), (188, 196, 206, 255), (150, 158, 172, 255))
GLASS_EDGE = (92, 124, 138, 255)
GLASS = (206, 232, 238, 70)
GLASS_HI = (255, 255, 255, 200)
# The jar's canvas and body (jar2): 34 x 44 glass on a 38 x 56 canvas, the neck 10 down.
JAR2_W, JAR2_H, JAR2_TOP = 34, 44, 10


def uncap_rest(fw, fh, fx=40, fy=12):
    """The wooden uncapping rest: two splayed plank legs, a cross bar, notches the frame's ears
    sit in, the pine of the hive's frames (mockup2 `rest`). Drawn for a frame whose picture's
    top left is (fx, fy) on its own canvas and whose comb is fw x fh; returns the picture, that
    top left (where the frame goes) and the row the legs stand on, all inked."""
    a = Art(fw + 140, fh + 110)
    top = fy + 4
    foot = fy + fh + 70
    for side in (-1, 1):
        x_top = fx + (4 if side < 0 else fw + 16)
        x_foot = x_top + side * 26
        a.poly([(x_top, top), (x_top + 10, top), (x_foot + 10, foot), (x_foot, foot)], PINE)
        a.poly([(x_top, top), (x_top + 3, top), (x_foot + 3, foot), (x_foot, foot)], PINE_LIT)
        a.poly([(x_top + 8, top), (x_top + 10, top), (x_foot + 10, foot), (x_foot + 8, foot)], PINE_SHADE)
        a.rect(x_top - 3, top - 4, 16, 6, PINE_DEEP)
        a.rect(x_top - 3, top - 4, 16, 2, PINE)
    bar = fy + fh + 30
    a.rect(fx - 20, bar, fw + 66, 7, PINE)
    a.rect(fx - 20, bar, fw + 66, 2, PINE_LIT)
    a.rect(fx - 20, bar + 5, fw + 66, 2, PINE_SHADE)
    for x in (fx - 12, fx + fw + 40):
        a.rect(x, bar + 2, 2, 2, DARK_WOOD_LO)
    return inked(a.im), (fx + 1, fy + 1), foot + 1


# The queen, 15 by 5 (2026-10-04, Richard: first "a bit bigger", 18 by 7, then "can be
# smaller"; was 14 by 5): a long tapering abdomen in a richer orange gold, a broad thorax, her
# wings folded short over her back.
QUEEN_GOLD = (236, 150, 30, 255)
QUEEN_LIT = (252, 196, 72, 255)
QUEEN_KEY = dict(BEE_KEY, q=QUEEN_GOLD, l=QUEEN_LIT)
# Per row: the abdomen's span and the thorax's (inclusive columns), and whether the head
# shows. Banded down its length, two gold to one dark, the top band lit.
_QUEEN_WIDE = 15
_QUEEN_SHAPE = [((2, 7), None, False), ((1, 9), (10, 12), False), ((0, 9), (10, 12), True),
                ((1, 9), (10, 12), False), ((2, 7), None, False)]


def _queen_rows():
    rows = []
    for y, (abd, thorax, head) in enumerate(_QUEEN_SHAPE):
        row = ["."] * _QUEEN_WIDE
        for x in range(abd[0], abd[1] + 1):
            dark = x % 3 == 2
            row[x] = "k" if dark else ("l" if y <= 1 else "q")
        if thorax:
            for x in range(thorax[0], thorax[1] + 1):
                row[x] = "t"
        if head:
            row[_QUEEN_WIDE - 2] = row[_QUEEN_WIDE - 1] = "h"
        rows.append("".join(row))
    return rows


QUEEN_LONG = _queen_rows()
# How many columns from her tail the abdomen dips when she lays.
QUEEN_TAIL = 6


def queen_long(laying=False):
    """The queen as the third pass has her: half as long again as a worker, no dot, her wings
    folded. `laying` dips the tail of her abdomen a pixel, as if into a cell: the step shows it
    in beats while she stops."""
    rows = list(QUEEN_LONG)
    body = sprite(rows, QUEEN_KEY)
    if laying:
        dipped = Image.new("RGBA", (body.width, body.height + 1), (0, 0, 0, 0))
        dipped.alpha_composite(body.crop((QUEEN_TAIL, 0, body.width, body.height)), (QUEEN_TAIL, 0))
        dipped.alpha_composite(body.crop((0, 0, QUEEN_TAIL, body.height)), (0, 1))
        body = dipped
    else:
        padded = Image.new("RGBA", (body.width, body.height + 1), (0, 0, 0, 0))
        padded.alpha_composite(body, (0, 0))
        body = padded
    body = inked(body)
    im = Image.new("RGBA", (body.width, body.height + 1), (0, 0, 0, 0))
    im.alpha_composite(body, (0, 1))
    for x in (8, 9, 10, 11):
        im.putpixel((x, 2), WING)
    for x in (9, 10):
        im.putpixel((x, 1), WING_EDGE)
    return im


def _jar2_body():
    w, h, top = JAR2_W, JAR2_H, JAR2_TOP
    return [(5, top + 4), (w - 5, top + 4), (w - 1, top + 9), (w - 1, top + h - 3), (w - 4, top + h),
            (4, top + h), (1, top + h - 3), (1, top + 9)]


def jar2_parts():
    """The jar in four layers on one 38 x 56 canvas, so they stack: the glass's tint behind
    (`back`), the edge and highlights in front (`front`), a small gingham lid and the label.
    The honey is drawn between back and front at run time, with its meniscus."""
    w, h, top = JAR2_W, JAR2_H, JAR2_TOP
    body = _jar2_body()
    back = Art(w + 4, h + 12)
    back.poly(body, GLASS)
    back.rect(6, top, w - 12, 5, (206, 232, 238, 110))
    front = Art(w + 4, h + 12)
    front.rect(6, top + 1, w - 12, 1, fade(GLASS_EDGE, 140))
    front.rect(6, top + 3, w - 12, 1, fade(GLASS_EDGE, 140))
    front.line(body + [body[0]], GLASS_EDGE)
    front.rect(w - 8, top + 12, 2, h - 20, GLASS_HI)
    front.rect(w - 5, top + 14, 1, 8, fade(GLASS_HI, 150))
    front.rect(5, top + 14, 1, 6, fade(GLASS_HI, 120))
    label = Art(w + 4, h + 12)
    label.rect(8, top + 20, w - 16, 12, CREAM)
    label.rect(8, top + 20, w - 16, 1, GINGHAM_RED)
    label.rect(8, top + 31, w - 16, 1, GINGHAM_RED)
    hexa = [".xx.", "xhsx", "xhhx", ".xx."]
    label.paste(sprite(hexa, {"x": HONEY_MID, "h": HONEY, "s": HONEY_SHINE}), w // 2 - 2, top + 24)
    lid = Art(w + 4, h + 12)
    cloth = Art(w - 6, 8)
    for y in range(8):
        for x in range(w - 6):
            if y > 4 and (x < y - 4 or x > w - 7 - (y - 4)):
                continue
            on = ((x // 2) % 2) + ((y // 2) % 2)
            cloth.px(x, y, GINGHAM_RED if on == 2 else GINGHAM_PINK if on == 1 else GINGHAM_WHITE)
    cloth.rect(2, 5, w - 10, 1, (120, 70, 40, 255))
    lid.paste(inked(cloth.im), 2, top - 6)
    return {"back": back.im, "front": front.im, "label": label.im, "lid": lid.im}


def honey_bucket_bare():
    """The enamel bucket seen from a little above, its mouth empty (mockup2 `honey_bucket`
    with no honey): the step fills the mouth at run time. Returns the picture and the mouth's
    middle and half size, inked."""
    art = Art(110, 96)
    art.poly([(2, 10), (106, 10), (98, 90), (10, 90)], ENAMEL["base"])
    art.fill_by([(2, 10), (106, 10), (98, 90), (10, 90)],
                lambda x, y: ENAMEL["shade"] if x < 18 else ENAMEL["lit"] if 72 < x < 84 else None)
    art.ell(1, 2, 106, 18, ENAMEL["lit"])
    art.ell(4, 4, 100, 14, ENAMEL["shade"])
    art.ell(6, 5, 96, 12, ENAMEL["deep"])
    return inked(art.im), (54 + 1, 11 + 1), (48, 6)


def bucket_front(im, mouth, half):
    """The bucket's front wall alone, to draw over what falls into it: every pixel of the
    picture below the mouth's middle row, less the mouth's inside. A stream or a heap of honey
    lower than the brim is then hidden behind the near wall, as it would be."""
    out = im.copy()
    px = out.load()
    mx, my = mouth
    hx, hy = half
    for y in range(out.height):
        for x in range(out.width):
            if y <= my:
                px[x, y] = (0, 0, 0, 0)
                continue
            dx = (x + 0.5 - mx) / hx
            dy = (y + 0.5 - my) / hy
            if dx * dx + dy * dy < 1.0:
                px[x, y] = (0, 0, 0, 0)
    return out


# The open hive the queen is looked for in (2026-10-04, Richard: "should feel like I'm looking
# inside the bee hive box, not a hanging rack"): seen down into at a tilt, the whole room's
# grid (640 x 360). Rows of frame top bars run across it, the box's walls round them, and the
# middle frame is the step's own `frame_brood`, tipped back so its comb face shows between its
# neighbours. Two layers: `well_back` (the inside, the back wall, the bars behind the frame)
# drawn under the frame, `well_front` (the bars in front of it and the near wall) over it.
WELL_W, WELL_H = 640, 360
WELL_BACK_Y = 14           # the back wall's top edge, inside
WELL_SIDES = ((92, 548), (30, 610))   # the inside's left and right at the back and at y 360
WELL_FRAME_FOOT = 222      # where the bars in front of the tipped frame begin
WELL_BARS_BACK = ((26, 3), (34, 4))
WELL_BARS_FRONT = ((222, 10), (237, 12), (254, 14), (274, 16), (297, 18), (323, 20), (349, 12))
# The comb of the next frame back, glimpsed either side of the tipped one, darkened this much.
WELL_BEYOND_DARK = 0.32
WELL_DARK = (40, 26, 16, 255)
WELL_DEEPER = (28, 18, 12, 255)


def _well_x(y):
    t = (y - WELL_BACK_Y) / float(WELL_H - WELL_BACK_Y)
    (l0, r0), (l1, r1) = WELL_SIDES
    return l0 + (l1 - l0) * t, r0 + (r1 - r0) * t


def _well_bar(a, y, h, rng):
    """A frame's top bar from wall to wall at row `y`, `h` tall: pine, lit along its top,
    shaded under, with propolis smudges and a burr of wax here and there."""
    l, r = _well_x(y + h)
    l, r = int(l) + 2, int(r) - 2
    a.rect(l, y, r - l, h, PINE)
    a.rect(l, y, r - l, max(1, h // 4), PINE_LIT)
    a.rect(l, y + h - max(1, h // 4), r - l, max(1, h // 4), PINE_SHADE)
    for k in range(int((r - l) / 26)):
        x = rng.randint(l + 4, r - 10)
        a.rect(x, y + rng.randint(1, max(1, h - 2)), rng.randint(3, 7), 1, PINE_DEEP)
        if rng.random() < 0.35:
            a.rect(x + 2, y - 1, rng.randint(2, 4), 2, WAX_SHADE)
    # The ends sit in the wall's rebate: a dark notch each side.
    a.rect(l - 2, y, 2, h, PINE_DEEP)
    a.rect(r, y, 2, h, PINE_DEEP)
    return l, r


def _well_gap(a, y0, y1, rng):
    """The dark between two bars, with the tops of the combs under them glimpsed: a broken
    row of honey and brood far down."""
    for y in range(y0, y1):
        l, r = _well_x(y)
        a.rect(int(l), y, int(r - l), 1, WELL_DEEPER if y > y0 + 2 else WELL_DARK)
    if y1 - y0 >= 4:
        y = y0 + 1
        l, r = _well_x(y)
        x = int(l) + 3
        while x < int(r) - 3:
            col = rng.choice((HONEY_DEEP, CELL_DEEP, CELL_EMPTY, BROOD_SHADE))
            a.rect(x, y, rng.randint(2, 5), 1, col)
            x += rng.randint(3, 8)


def _well_walls(a, y0, y1, paint):
    """The box's side walls from row y0 to y1: the inner face in shade, the raw top edge, the
    painted outside beyond it."""
    lit, base, shade, deep = paint
    for y in range(y0, y1):
        l, r = _well_x(y)
        l, r = int(l), int(r)
        wall = 6 + int(10 * (y / WELL_H))
        a.rect(l - wall - 6, y, 6, 1, base)
        a.rect(l - wall, y, wall, 1, PINE_LIT if y % 9 else PINE)
        a.rect(l, y, 3, 1, PINE_DEEP)
        a.rect(r - 3, y, 3, 1, PINE_DEEP)
        a.rect(r, y, wall, 1, PINE)
        a.rect(r + wall, y, 6, 1, shade)


def hive_well(paint):
    """The open hive from above at a tilt, in its two layers (see `WELL_*`). Returns the back
    and the front, inked, and the bars as `(left, right, top, tall)` on the grid."""
    rng = random.Random(77)
    lit, base, shade, deep = paint
    back = Art(WELL_W, WELL_H)
    # the inside, darkest at the bottom of the box
    for y in range(WELL_BACK_Y, WELL_H):
        l, r = _well_x(y)
        back.rect(int(l), y, int(r - l), 1, WELL_DEEPER if y > 60 else WELL_DARK)
    # the back wall: its inner face, its raw top edge, the painted back beyond
    l0, r0 = _well_x(WELL_BACK_Y)
    back.rect(int(l0) - 16, 0, int(r0 - l0) + 32, 6, base)
    back.rect(int(l0) - 16, 0, int(r0 - l0) + 32, 2, lit)
    back.rect(int(l0) - 16, 6, int(r0 - l0) + 32, WELL_BACK_Y - 6, PINE)
    back.rect(int(l0) - 16, 6, int(r0 - l0) + 32, 2, PINE_LIT)
    back.rect(int(l0), WELL_BACK_Y, int(r0 - l0), 10, DARK_WOOD_LO)
    back.rect(int(l0), WELL_BACK_Y + 9, int(r0 - l0), 1, WELL_DARK)
    # Beyond the tipped frame, down in the box: the next frame's comb, dim.
    l1, r1 = _well_x(WELL_FRAME_FOOT)
    beyond = Art(WELL_W, WELL_H)
    comb(beyond, int(l1), 40, int(r1), WELL_FRAME_FOOT,
         lambda x, y, r: r.choice(("honey", "wax", "brood", "empty", "brood")), seed=31)
    for y in range(40, WELL_FRAME_FOOT):
        l, r = _well_x(y)
        for x in range(int(l), int(r)):
            c = beyond.im.getpixel((x, y))
            if c[3]:
                back.px(x, y, tuple(int(v * WELL_BEYOND_DARK) for v in c[:3]) + (255,))
    _well_walls(back, WELL_BACK_Y, WELL_H, paint)
    bars = []
    prev = WELL_BACK_Y + 10
    for y, h in WELL_BARS_BACK:
        _well_gap(back, prev, y, rng)
        l, r = _well_bar(back, y, h, rng)
        bars.append((l, r, y, h))
        prev = y + h
    _well_gap(back, prev, prev + 6, rng)
    front = Art(WELL_W, WELL_H)
    prev = WELL_FRAME_FOOT
    for y, h in WELL_BARS_FRONT:
        if y > prev:
            _well_gap(front, prev, y, rng)
        l, r = _well_bar(front, y, h, rng)
        bars.append((l, r, y, h))
        prev = y + h
    _well_gap(front, prev, WELL_H, rng)
    _well_walls(front, WELL_FRAME_FOOT, WELL_H, paint)
    return inked(back.im), inked(front.im), bars


def bottling_table():
    """The pour step's table alone (bottling_stand, inked): the bucket and the gate are their
    own pieces now, since the bucket's level and the gate's lever move."""
    table = Art(132, 228)
    bottling_stand(table, 16, 0)
    return inked(table.im)


def billow(r, seed):
    """A billow of smoke (mockup2 `soft_puff`): a few overlapping lobes lit top-left in the four
    greys, its rim broken into a checker of whole pixels rather than faded. Not inked: smoke in
    the mockup wears no outline."""
    rng = random.Random(seed)
    size = int(r * 3.8) + 4
    a = Art(size, size)
    x = y = size / 2
    lobes = [(x, y, r)] + [(x + rng.uniform(-0.7, 0.7) * r, y + rng.uniform(-0.6, 0.3) * r,
                            r * rng.uniform(0.45, 0.75)) for _ in range(4)]
    for yy in range(size):
        for xx in range(size):
            best = 9
            for lx, ly, lr in lobes:
                best = min(best, math.hypot(xx - lx, (yy - ly) * 1.1) / lr)
            if best > 1:
                continue
            if best > 0.82 and (xx + yy) % 2:
                continue
            lit = ((xx - x) + (yy - y) * 1.2) / (r * 1.4) + best * 0.3
            tone = SMOKE_T[0] if lit < -0.45 else SMOKE_T[1] if lit < 0.15 else SMOKE_T[2] if lit < 0.6 else SMOKE_T[3]
            al = 235 * (0.72 if best > 0.82 else 1.0)
            a.px(xx, yy, tone[:3] + (int(al),))
    return a.im, {"c": [int(x), int(y)]}


# === baking ================================================================================
ASSET_ISLAND = os.path.join("assets", "hive.png")
CONTRACT_ISLAND = os.path.join("assets", "hive.json")
ASSET_ROOM = os.path.join("assets", "hive_room.png")
CONTRACT_ROOM = os.path.join("assets", "hive_room.json")
SHEET_ISLAND = os.path.join("tools", "last_hive_sheet.png")
SHEET_ROOM = os.path.join("tools", "last_hive_room_sheet.png")

ISLAND_PAINT = PAINTS["sky"]        # Richard's pick off the mockup
JARS_SHOWN = (0, 3, 6, 9, 12)       # three a harvest, four harvests at most
JARS_MOST = JARS_SHOWN[-1]
TILE_PX = (32, 16)                  # half a tile in painted px: a tile is 64 x 32 at 1x world
# Where the flowering shrub the swarm hangs on stands, in tiles from the hive's tile: up the
# screen and to the left of the shelf's far end, as the mockup has it, pulled in towards the
# island's middle so it keeps to the lawn: at (-2.4, -0.9) it stood a few pixels out on the
# beach (checked with `Iso.on_lawn` in Godot, 2026-09-30), so it came in a fifth of a tile.
SHRUB_TILE = (-2.2, -0.9)
# The swarm hangs off the shrub's right side, its top middle this far from the shrub's foot
# (the bottom middle of its picture) — the mockup's own arrangement of the two.
SWARM_OFF_SHRUB = (16, -10)
# The ready mark over the roof: its middle pixel, on the inked canvas, where the mockup put it.
READY_AT = (62, -16)


def _alpha_at(im, x, y):
    return im.getpixel((x, y))[3] if 0 <= x < im.width and 0 <= y < im.height else 0


def _hive_mask(paint, state, drip=False):
    """Which pixels of the inked island canvas are the hive's: everything the hive's own
    strokes cover, and the outline ring round it wherever no shelf stroke is (the shelf with
    the most jars, so the answer holds whatever the shelf holds)."""
    hive = _island_raw_hd(paint, state, drip=drip, shelf=False)
    shelf = _island_raw_hd(paint, state, JARS_MOST, hive=False)
    w, h = HD_W + 2, HD_H + 2
    own = {(x, y) for y in range(h) for x in range(w) if _alpha_at(hive, x - 1, y - 1) > 0}
    shelf_px = {(x, y) for y in range(h) for x in range(w) if _alpha_at(shelf, x - 1, y - 1) > 0}
    ring = set()
    for x, y in own:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in own and p not in shelf_px and 0 <= p[0] < w and 0 <= p[1] < h:
                ring.add(p)
    return own | ring


def _split(whole, mask):
    """The inked whole dealt into (shelf, hive) by the hive's mask."""
    shelf, hive = whole.copy(), Image.new("RGBA", whole.size, (0, 0, 0, 0))
    for x, y in mask:
        hive.putpixel((x, y), whole.getpixel((x, y)))
        shelf.putpixel((x, y), (0, 0, 0, 0))
    return shelf, hive


def _same(a, b):
    return a.size == b.size and ImageChops.difference(a, b).getbbox() is None


def _lowest_rows(im):
    """Per column, the lowest row with alpha over half (Shade.sweep's own test), or -1."""
    out = []
    for x in range(im.width):
        row = -1
        for y in range(im.height - 1, -1, -1):
            if im.getpixel((x, y))[3] > 127:
                row = y
                break
        out.append(row)
    return out


def _ground(im):
    """A part's `ground` on its frame (contract 3.1): the share of the frame's height under
    the highest row the part stands on, plus a pixel. Every column the part touches the
    ground with is then inside Shade.sweep's band (a band that covers only the deepest row
    would cast the hive's front leg alone, and none of the shelf but its near post), and
    what stands up above that row is what the shadow is dragged off."""
    rows = [r for r in _lowest_rows(im) if r >= 0]
    return round((im.height - min(rows) + 1) / im.height, 4)


def _to_tiles(dx, dy):
    """Painted px from the foot to tiles from the hive's tile: the inverse of
    tile (tx, ty) -> painted ((tx - ty) * 16, (tx + ty) * 8)."""
    return ((dx / TILE_PX[0] + dy / TILE_PX[1]) / 2, (dy / TILE_PX[1] - dx / TILE_PX[0]) / 2)


def _to_painted(tx, ty):
    return ((tx - ty) * TILE_PX[0], (tx + ty) * TILE_PX[1])


def _island_geometry():
    """The island sprite's measures on the inked canvas, all read off the constants the
    drawing uses. Pixel coordinates are pixel indices; a point that is a pixel's middle is
    that index plus half."""
    cx, yT, H = ISLAND_CX, ISLAND_YT, ISLAND_WALL
    c = yT + 4 + H                      # the stand's top diamond's middle row, raw
    ink = 1                             # inking puts everything one pixel in
    # The stand's legs end at rows c + 4 (left and right) and c + 9 (front): the legs' feet
    # are a diamond whose middle is (cx, c + 4). That pixel is the foot.
    foot = (cx + ink, c + 4 + ink)
    mid = (foot[0] + 0.5, foot[1] + 0.5)
    # The ground under the stand: its top diamond (half 10 across, 5 down) at the feet's row.
    ground = [(mid[0] - 10, mid[1]), (mid[0], mid[1] - 5), (mid[0] + 10, mid[1]), (mid[0], mid[1] + 5)]
    # The shelf's four posts, where they meet the ground (raw post feet, as drawn).
    lr = (2, 17)
    br = (lr[0] + 18, lr[1] + 9)
    dep = (2, -1)
    for p in (lr, br):
        ground.append((p[0] + ink + 0.5, p[1] + 2 + ink + 0.5))                    # front posts
        ground.append((p[0] + dep[0] + ink + 0.5, p[1] + dep[1] + ink + 0.5))      # back posts
    tiles = [_to_tiles(x - mid[0], y - mid[1]) for x, y in ground]
    lo = (min(t[0] for t in tiles), min(t[1] for t in tiles))
    hi = (max(t[0] for t in tiles), max(t[1] for t in tiles))
    centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)
    half = ((hi[0] - lo[0]) / 2, (hi[1] - lo[1]) / 2)
    # The honey window: drawn as a slanted pane three pixels across and two down in white
    # trim, but the gable end of the roof is laid over its top row afterwards, so what shows
    # of the pane in the approved picture is two pixels, a step apart. Measured, not assumed:
    # the pixels an empty window and a full one differ in are the pane that can be seen.
    # Listed column by column, each its top row and height, so the game fills exactly those.
    empty = island_hive(ISLAND_PAINT, "colony", window="dark")
    full = island_hive(ISLAND_PAINT, "full")
    seen = {}
    for y in range(empty.height):
        for x in range(empty.width):
            if empty.getpixel((x, y)) != full.getpixel((x, y)):
                seen.setdefault(x, []).append(y)
    cols = [[x, min(ys), max(ys) - min(ys) + 1] for x, ys in sorted(seen.items())]
    # The entrance: the middle of the landing board's lip, under the dark slot.
    ex = cx + 4
    entrance = (ex + ink, yT + 8 + H - (ex - cx) // 2 + ink)
    return {"foot": foot, "centre": centre, "half": half, "window_cols": cols, "entrance": entrance}


def build_island():
    """The island sheet: eight frames of one size, the swarm and the ready mark."""
    geo = _island_geometry_hd()
    old, sky = WEATHERED, ISLAND_PAINT
    mask_old, mask_new = _hive_mask(old, "weathered"), _hive_mask(sky, "colony")
    shelf_old, hive_old = _split(island_hive_hd(old, "weathered"), mask_old)
    parts = {"hive_weathered": hive_old,
             "hive_colony": _split(island_hive_hd(sky, "colony", window="dark"), mask_new)[1],
             "hive_full": _split(island_hive_hd(sky, "full", drip=True), _hive_mask(sky, "full", True))[1],
             "shelf_weathered": shelf_old}
    for j in JARS_SHOWN:
        parts["shelf_%d" % j] = _split(island_hive_hd(sky, "colony", j, window="dark"), mask_new)[0]
    # Every pairing the game draws lays back into the mockup's one sprite.
    checks = [("shelf_weathered", "hive_weathered", island_hive_hd(old, "weathered"))]
    for j in JARS_SHOWN:
        checks.append(("shelf_%d" % j, "hive_colony", island_hive_hd(sky, "colony", j, window="dark")))
        checks.append(("shelf_%d" % j, "hive_full", island_hive_hd(sky, "full", j, drip=True)))
    for s, h, whole in checks:
        laid = parts[s].copy()
        laid.alpha_composite(parts[h])
        assert _same(laid, whole), "%s under %s is not the whole sprite" % (s, h)

    # One crop for all of them: the union of what is drawn, a pixel of margin round it.
    boxes = [im.getbbox() for im in parts.values()]
    x0 = min(b[0] for b in boxes) - 1
    y0 = min(b[1] for b in boxes) - 1
    x1 = max(b[2] for b in boxes) + 1
    y1 = max(b[3] for b in boxes) + 1
    fw, fh = x1 - x0, y1 - y0
    frames = {k: v.crop((x0, y0, x1, y1)) for k, v in parts.items()}

    def local(p):
        return [p[0] - x0, p[1] - y0]

    swarm, ready = island_swarm_hd(), ready_mark_hd()
    order = ["hive_weathered", "hive_colony", "hive_full", "shelf_weathered"] + ["shelf_%d" % j for j in JARS_SHOWN]
    per_row = 4
    rows = (len(order) + per_row - 1) // per_row
    sw = per_row * (fw + 1) + 1
    sh = rows * (fh + 1) + 1 + max(swarm.height, ready.height) + 1
    sheet = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    rects = {}
    for i, name in enumerate(order):
        x, y = 1 + (i % per_row) * (fw + 1), 1 + (i // per_row) * (fh + 1)
        sheet.alpha_composite(frames[name], (x, y))
        rects[name] = [x, y, fw, fh]
    ty = 1 + rows * (fh + 1)
    sheet.alpha_composite(swarm, (1, ty))
    sheet.alpha_composite(ready, (2 + swarm.width, ty))
    sheet.save(ASSET_ISLAND)

    foot = local(geo["foot"])
    cols = [[c[0] - x0, c[1] - y0, c[2]] for c in geo["window_cols"]]
    wx0, wy0 = min(c[0] for c in cols), min(c[1] for c in cols)
    wx1, wy1 = max(c[0] + 1 for c in cols), max(c[1] + c[2] for c in cols)
    shrub = _to_painted(*SHRUB_TILE)
    shrub_at = [int(round(shrub[0])), int(round(shrub[1]))]
    swarm_at = [shrub_at[0] + SWARM_OFF_SHRUB[0], shrub_at[1] + SWARM_OFF_SHRUB[1]]
    contract = {
        "size": [fw, fh],
        "foot": foot,
        "ground_hive": _ground(frames["hive_colony"]),
        "ground_shelf": _ground(frames["shelf_0"]),
        "frames": rects,
        "window": [wx0, wy0, wx1 - wx0, wy1 - wy0],
        "window_cols": cols,
        "entrance": local(geo["entrance"]),
        "ready_at": local(READY_AT),
        "ready": [2 + swarm.width, ty, ready.width, ready.height],
        "swarm": [1, ty, swarm.width, swarm.height],
        "swarm_at": swarm_at,
        "shrub_at": shrub_at,
        "shrub_tile": list(SHRUB_TILE),
        "foot_tiles": {"centre": [round(v, 4) for v in geo["centre"]],
                       "half": [round(v, 4) for v in geo["half"]]},
    }
    with open(CONTRACT_ISLAND, "w", newline="\n") as f:
        json.dump(contract, f, indent=1)
        f.write("\n")
    return frames, contract


# --- the room ------------------------------------------------------------------------------
def _crop(im, anchors, box=None):
    """A piece cut to what is drawn (or to `box`), its anchors moved with it."""
    box = box or im.getbbox()
    return im.crop(box), {k: [v[0] - box[0], v[1] - box[1]] for k, v in anchors.items()}


def _feet(im, x):
    """The ground line a piece stands on: under its lowest drawn row, at `x`."""
    return [x, im.getbbox()[3]]


def _middle(im):
    return [im.width // 2, im.height // 2]


def _puff_piece(r, seed):
    """A puff of smoke on its own canvas, as the smoke step draws them, dissolving at the rim.
    Not inked: smoke in the mockup wears no outline."""
    size = 2 * r + 5
    a = Art(size, size)
    puff(a, r + 2, r + 2, r, seed)
    return a.im, {"c": [r + 2, r + 2]}


def room_pieces():
    """Every room piece, cropped, with its anchors in painted px inside it (contract 3.2).
    Anchors are written in the inked, uncropped picture's pixels (the drawing's own numbers
    plus the pixel the ink adds) and moved with the crop."""
    sky = PAINTS["sky"]
    out = {}
    cx = 86 + 1                         # room_hive's middle, inked
    im, ent = room_hive(sky, window=0.35)
    out["hive_front"] = _crop(im, {"entrance": [ent[0] + 1, ent[1] + 1], "roof": [cx, 0 + 1],
                                   "feet": _feet(im, cx)})
    im, _ = room_hive(sky, lid=False, open_top=True)
    out["hive_open"] = _crop(im, {"top": [cx, 20 - 7 + 1], "feet": _feet(im, cx)})
    im = catch_box(sky)
    out["box"] = _crop(im, {"mouth": [71, 10], "feet": _feet(im, 65)})
    im, hang = branch_with_swarm(swarm=False)
    out["branch"] = _crop(im, {"hang": list(hang), "grip": [151, 34]})
    out["smoker"] = _crop(smoker(), {"nozzle": [15, 19], "bellows": [80, 66]})
    out["smoker_half"] = _crop(smoker(0.5), {"nozzle": [15, 19], "bellows": [80, 66]})
    out["smoker_shut"] = _crop(smoker(1.0), {"nozzle": [15, 19], "bellows": [80, 66]})

    # The three frames share one geometry, so one crop: the comb's rows line up across them.
    frames = {"frame_brood": brood_frame(300, 180, seed=9, cell=CELL_BIG),
              "frame_capped": brood_frame(300, 180, seed=12, uncap_to=-1, cell=CELL_BIG),
              "frame_open": brood_frame(300, 180, seed=12, uncap_to=10 ** 6, cell=CELL_BIG)}
    fbox = frames["frame_brood"].getbbox()
    for im in frames.values():
        assert im.getbbox() == fbox
    # the comb, inked: brood_frame's ix0, iy0 and its size, for a 300 x 180 frame
    inner = (13 + 7 + 1, 9 + 1, 300 - 14, 180 - 15)
    glove_grip = [16, 9]                # where the frame's ear sits under the glove's fingers
    fw = frames["frame_brood"].width
    # the ears the gloves hold, where the mockup's queen step lays the gloves on the frame
    ears = {"ear_l": [glove_grip[0] - 6, glove_grip[1] - 4],
            "ear_r": [fw - 26 + (31 - glove_grip[0]), glove_grip[1] - 4]}
    for name, im in frames.items():
        out[name] = _crop(im, dict(ears, inner_tl=[inner[0], inner[1]],
                                   inner_br=[inner[0] + inner[2], inner[1] + inner[3]]), fbox)
    comb_inner = [inner[0] - fbox[0], inner[1] - fbox[1], inner[2], inner[3]]

    length = 294
    out["knife"] = _crop(hot_knife(length), {"blade_l": [8, 9], "blade_r": [length, 9],
                                             "handle": [length + 26, 12]})
    im, root = wax_sheet(length, body=False)
    out["wax_curl"] = _crop(im, {"root": list(root)})

    im, _ = extractor(crank=False, stream=False, bucket_honey=False)
    mid, top, bottom = 105, 76, 198
    out["extractor"] = _crop(im, {"shaft": [mid + 1, top - 43], "orbit": [mid + 1, top - 62],
                                  "gate": [mid + 1, bottom + 15], "rim_c": [mid + 1, top + 1],
                                  "bucket": [mid + 1, bottom + 27]})
    out["knob"] = _crop(knob(), {"pin": [5, 16]})
    im, gate = bottling()
    out["bottling"] = _crop(im, {"gate": list(gate)})

    im = jar(fill=0.0)
    out["jar_glass"] = _crop(im, {"inner_tl": [2, 28], "inner_br": [44, 73], "neck": [23, 16]})
    im = jar(fill=0.86, lid=True, label=True)
    out["jar_full"] = _crop(im, {"feet": _feet(im, 23)})
    out["glove_l"] = _crop(glove(), {"grip": list(glove_grip)})
    out["glove_r"] = _crop(glove(flip=True), {"grip": [31 - glove_grip[0], glove_grip[1]]})
    im = crown()
    out["crown"] = _crop(im, {"c": _middle(im)})
    for name, im in (("bee_r", bee()), ("bee_r_rest", bee(wings_up=False)),
                     ("bee_u", bee(turn=1, wings_up=False)), ("bee_d", bee(turn=3, wings_up=False))):
        out[name] = _crop(im, {"c": _middle(im)}, (0, 0, im.width, im.height))
    im = bee(queen=True, wings_up=False)
    dot = next([x, y] for y in range(im.height) for x in range(im.width) if im.getpixel((x, y)) == TRIM)
    out["queen_r"] = _crop(im, {"c": _middle(im), "dot": dot}, (0, 0, im.width, im.height))
    for state in ("done", "now", "todo"):
        im = pip(state)
        out["pip_" + state] = _crop(im, {"c": _middle(im)}, (0, 0, im.width, im.height))
    for name, r, seed in (("puff_s", 5, 1), ("puff_m", 10, 2), ("puff_l", 15, 3)):
        im, anchors = _puff_piece(r, seed)
        out[name] = _crop(im, anchors, (0, 0, im.width, im.height))

    # The second pass (tools/hive_mockup2.py): the rest the frame stands in, the long queen,
    # the jar in layers, the bucket, the table and gate apart, and the smoke's billows.
    im, tl, foot = uncap_rest(300, 180)
    out["rest"] = _crop(im, {"frame_tl": list(tl), "feet": [tl[0] + 150, foot]})
    im = queen_long()
    out["queen_long"] = _crop(im, {"c": _middle(im)}, (0, 0, im.width, im.height))
    lay = queen_long(laying=True)
    out["queen_lay"] = _crop(lay, {"c": _middle(im)}, (0, 0, lay.width, lay.height))
    body = [JAR2_W // 2 + 2, JAR2_TOP + JAR2_H + 1]
    for part, im in jar2_parts().items():
        out["jar2_" + part] = _crop(im, {"feet": body, "tl": [0, 0]}, (0, 0, im.width, im.height))
    im, mouth, half = honey_bucket_bare()
    out["bucket"] = _crop(im, {"mouth": list(mouth), "half": list(half), "feet": _feet(im, 55)},
                          (0, 0, im.width, im.height))
    front = bucket_front(im, mouth, (half[0] + 2, half[1] + 1))
    out["bucket_front"] = _crop(front, {"mouth": list(mouth), "feet": _feet(im, 55)},
                                (0, 0, im.width, im.height))
    back, fore, bars = hive_well(PAINTS["sky"])
    marks = {"tl": [1, 1]}
    for k, (l, r, y, h) in enumerate(bars):
        marks["bar%d_l" % k] = [l + 1, y + 1]
        marks["bar%d_r" % k] = [r + 1, y + 1 + h]
    out["well_back"] = _crop(back, marks, (0, 0, back.width, back.height))
    out["well_front"] = _crop(fore, marks, (0, 0, fore.width, fore.height))
    im = bottling_table()
    out["table"] = _crop(im, {"top": [16 + 50 + 1, 76 + 1]})
    im = bottling_gate()
    out["gate"] = _crop(im, {"spout": [12 + 1, 19], "pivot": [12 + 1, 3]}, (0, 0, im.width, im.height))
    for k, (r, seed) in enumerate(((5, 11), (8, 12), (11, 13), (14, 14), (18, 15), (22, 16))):
        im, anchors = billow(r, seed)
        out["billow_%d" % k] = _crop(im, anchors, (0, 0, im.width, im.height))
    return out, comb_inner


def _pack(pieces, wide):
    """Shelf-pack the pieces, tallest first, a pixel of air round each."""
    order = sorted(pieces, key=lambda k: (-pieces[k][0].height, k))
    x = y = 1
    row = 0
    at = {}
    for k in order:
        im = pieces[k][0]
        if x + im.width + 1 > wide:
            x, y = 1, y + row + 1
            row = 0
        at[k] = (x, y)
        x += im.width + 1
        row = max(row, im.height)
    return at, y + row + 1


ROOM_SHEET_WIDE = 1024
# Anchors that are points in the air rather than on the piece: the extractor's `orbit`, the
# middle of the circle the knob turns on, stands where the arm lifts the knob to, over the
# gear box, and so above the piece now the arm is the step's to draw.
IN_THE_AIR = {"orbit"}


def build_room():
    pieces, comb_inner = room_pieces()
    for name, (im, anchors) in pieces.items():
        for a, p in anchors.items():
            if a in IN_THE_AIR:
                continue
            assert -1 <= p[0] <= im.width and -1 <= p[1] <= im.height, (name, a, p, im.size)
    at, tall = _pack(pieces, ROOM_SHEET_WIDE)
    sheet = Image.new("RGBA", (ROOM_SHEET_WIDE, tall), (0, 0, 0, 0))
    contract = {"pieces": {}}
    for name in sorted(pieces):
        im, anchors = pieces[name]
        x, y = at[name]
        sheet.alpha_composite(im, (x, y))
        contract["pieces"][name] = {"rect": [x, y, im.width, im.height], "anchors": anchors}
    dx, dy, off = CELL_BIG[1]
    contract["comb"] = {"inner": comb_inner, "pitch": [dx, dy], "offset": off,
                        "cell": [len(CELL_BIG[0][0]), len(CELL_BIG[0])]}
    sheet.save(ASSET_ROOM)
    with open(CONTRACT_ROOM, "w", newline="\n") as f:
        json.dump(contract, f, indent=1)
        f.write("\n")
    return pieces, contract


# --- contact sheets --------------------------------------------------------------------------
GRASS = (58, 86, 36, 255)           # the mockup's lawn tile
MARK = (255, 60, 200, 255)
LABEL = (240, 230, 200, 255)


def _dot(d, x, y, s, col=MARK):
    d.rectangle([x - 1, y - 1, x + s, y + s], outline=(0, 0, 0, 255), fill=col)


def _cut(path, rect):
    x, y, w, h = rect
    return Image.open(path).convert("RGBA").crop((x, y, x + w, y + h))


def island_contact(frames, contract):
    """Every frame alone at 6x on grass; then each pairing the game draws, the foot (magenta),
    the entrance (blue) and the window (yellow) marked; then the whole scene round the foot
    with the shrub, the swarm, the ready mark and the footprint's diamond."""
    z = 6
    fw, fh = contract["size"]
    gap = 12
    names = list(frames)
    pairs = [("shelf_weathered", "hive_weathered", "weathered")] + \
            [("shelf_%d" % j, "hive_colony", "colony, %d jars" % j) for j in JARS_SHOWN] + \
            [("shelf_3", "hive_full", "full, 3 jars"), ("shelf_12", "hive_full", "full, 12 jars")]
    per = 4
    cw, ch = fw * z + gap, fh * z + gap + 14
    top_rows = (len(names) + per - 1) // per
    pair_rows = (len(pairs) + per - 1) // per
    scene_w, scene_h = 110, 80
    W = max(per * cw, scene_w * z) + gap
    H = (top_rows + pair_rows) * ch + scene_h * z + gap * 3 + 14
    sheet = Image.new("RGBA", (W, H), (22, 34, 32, 255))
    d = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        x, y = gap + (i % per) * cw, gap + (i // per) * ch
        tile = Image.new("RGBA", (fw, fh), GRASS)
        tile.alpha_composite(frames[name])
        sheet.alpha_composite(big(tile, z), (x, y))
        d.text((x, y + fh * z + 1), name, fill=LABEL)
    oy = gap + top_rows * ch
    foot = contract["foot"]
    for i, (s, h, label) in enumerate(pairs):
        x, y = gap + (i % per) * cw, oy + (i // per) * ch
        tile = Image.new("RGBA", (fw, fh), GRASS)
        tile.alpha_composite(frames[s])
        tile.alpha_composite(frames[h])
        sheet.alpha_composite(big(tile, z), (x, y))
        _dot(d, x + foot[0] * z, y + foot[1] * z, z - 1)
        e = contract["entrance"]
        _dot(d, x + e[0] * z, y + e[1] * z, z - 1, (80, 220, 255, 255))
        wx, wy, ww, wh = contract["window"]
        d.rectangle([x + wx * z, y + wy * z, x + (wx + ww) * z - 1, y + (wy + wh) * z - 1], outline=(255, 255, 0, 255))
        d.text((x, y + fh * z + 1), label, fill=LABEL)
    sy = oy + pair_rows * ch + gap + 14
    scene = Image.new("RGBA", (scene_w, scene_h), GRASS)
    fx, fy = 70, 52                     # where the foot lands in the scene
    ox, oy2 = fx - foot[0], fy - foot[1]
    flora = json.load(open("assets/flora.json"))["shrub_flowering"]["full"]
    shrub = _cut("assets/flora.png", flora)
    sa = contract["shrub_at"]
    scene.alpha_composite(shrub, (fx + sa[0] - flora[2] // 2, fy + sa[1] - flora[3]))
    swarm = _cut(ASSET_ISLAND, contract["swarm"])
    wa = contract["swarm_at"]
    scene.alpha_composite(swarm, (fx + wa[0] - swarm.width // 2, fy + wa[1]))
    scene.alpha_composite(frames["shelf_0"], (ox, oy2))
    scene.alpha_composite(frames["hive_full"], (ox, oy2))
    mark = _cut(ASSET_ISLAND, contract["ready"])
    ra = contract["ready_at"]
    scene.alpha_composite(mark, (ox + ra[0] - mark.width // 2, oy2 + ra[1] - mark.height // 2))
    sheet.alpha_composite(big(scene, z), (gap, sy))
    c, hf = contract["foot_tiles"]["centre"], contract["foot_tiles"]["half"]
    pts = []
    for tx, ty in ((c[0] - hf[0], c[1] - hf[1]), (c[0] + hf[0], c[1] - hf[1]),
                   (c[0] + hf[0], c[1] + hf[1]), (c[0] - hf[0], c[1] + hf[1])):
        px, py = _to_painted(tx, ty)
        pts.append((gap + (fx + 0.5 + px) * z, sy + (fy + 0.5 + py) * z))
    d.line(pts + [pts[0]], fill=MARK, width=2)
    d.text((gap, sy - 14), "scene: shelf_0 under hive_full, the shrub and swarm, the ready mark; "
           "the footprint in magenta", fill=LABEL)
    sheet.save(SHEET_ISLAND)


def room_contact(pieces):
    """Every room piece at 2x, its anchors marked with a cross and named."""
    z = 2
    gap = 16
    wide = 2400
    order = sorted(pieces, key=lambda k: (-pieces[k][0].height, k))
    x = y = gap
    row = 0
    places = []
    for k in order:
        im = pieces[k][0]
        w, h = max(im.width * z, 90), im.height * z + 16
        if x + w + gap > wide:
            x, y, row = gap, y + row + gap, 0
        places.append((k, x, y))
        x += w + gap
        row = max(row, h)
    sheet = Image.new("RGBA", (wide, y + row + gap), (70, 96, 52, 255))
    d = ImageDraw.Draw(sheet)
    for k, x, y in places:
        im, anchors = pieces[k]
        sheet.alpha_composite(big(im, z), (x, y + 14))
        d.rectangle([x - 1, y + 13, x + im.width * z, y + 14 + im.height * z], outline=(30, 40, 30, 255))
        d.text((x, y), k, fill=LABEL)
        for a, p in anchors.items():
            px, py = x + p[0] * z, y + 14 + p[1] * z
            d.line([px - 4, py, px + 5, py], fill=MARK)
            d.line([px, py - 4, px, py + 5], fill=MARK)
            d.text((px + 4, py + 2), a, fill=MARK)
    sheet.save(SHEET_ROOM)


def main():
    frames, contract = build_island()
    pieces, _ = build_room()
    island_contact(frames, contract)
    room_contact(pieces)
    print(ASSET_ISLAND, CONTRACT_ISLAND, ASSET_ROOM, CONTRACT_ROOM, SHEET_ISLAND, SHEET_ROOM)


if __name__ == "__main__":
    main()

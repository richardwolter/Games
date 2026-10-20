#!/usr/bin/env python
"""The honey sheet (2026-10-16, the hive overhaul): the honey boost on the lake.

Writes tools/hive_look/last_honey.png. Richard's decisions (grilled 2026-10-16): a jar of honey
is eaten from a HUD jar plate shown only while jars are held; for 15 s every piece the net
catches pays +50% at once as amber honey coins; the net's rim and beads go amber and drip;
bees orbit the angler and thin as the time runs out. The sheet shows:

  0  the recommended picks together on a real store still, at real scale
  1  the HUD jar plate, three placements and styles, idle (3 jars) and mid-window
  2  the net in honey time beside the lucky cast's gold net
  3  cute mini bees orbiting the angler at full, half and nearly-out time
  4  the honey coin flying from the net to the purse, three designs
  5  the first-jar cue card in the CueCard look, three themes

OFFLINE MOCKUPS ONLY: nothing here is read by the game. Every plate is a real capture and every
thing drawn on it sits on that plate's own lattice:
  - the HUD (plates, coins, cards) on the 1280x720 canvas, 1.5 screen px a canvas px, phase 0:
    screen px s is canvas px floor(2s / 3) (measured off the camera button's pixel edges);
  - the lake on the store stills (net, drips, bees) at the play stop, 1 world px a canvas px,
    on the camera's own phase (measured off the angler: 02 is (2, 2), 05 is (0, 1));
  - the lake on last_hive_honey.png at 2 screen px a world px (look.LAKE_GRAIN).
The HUD wood is the game's own: `border` is a port of Style._build_border off
assets/ui/meter/Meter_Border.png, bites and all (Godot's hash ported too: a 56x56 frame comes out
pixel for pixel the camera button's). Text is Bungee drawn at screen resolution, as Godot draws it.

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/honey_mockup.py [section ...]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
import honey_net as hn  # noqa: E402
from look import zoom, panel, stack, flow  # noqa: E402

bh = look.bh
OUT_PATH = os.path.join(look.HERE, "last_honey.png")
SHEET_WIDE = 2440
ROOT = look.ROOT

# =============================================================================================
# Colours. The HUD's own (scripts/style.gd), the hive's honey (build_hive), the cue card's.
# =============================================================================================
def c8(r, g, b, a=255):
    return (r, g, b, a)


def cf(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


SEAM = cf(0.13, 0.09, 0.06)
WOOD = cf(0.47, 0.33, 0.21)
WOOD_LIT = cf(0.62, 0.45, 0.29)
INK = cf(0.97, 0.94, 0.86)
INK_DIM = cf(0.74, 0.69, 0.60)
BOARD = cf(0.10, 0.20, 0.20)
BUTTON_FACE = cf(0.22, 0.40, 0.38)
BUTTON_SUNK = cf(0.11, 0.24, 0.24)
BOARD_INK = cf(0.85, 0.91, 0.94)
BOX_HOLLOW = cf(0.28, 0.09, 0.09)
GOLD_UI = cf(1.00, 0.80, 0.30)
RIBBON_INK = cf(0.94, 0.85, 0.75)
SHADE_TXT = (0, 0, 0, 140)
OUTLINE = look.OUT
HONEY_DEEP, HONEY_MID, HONEY, HONEY_LIGHT, HONEY_SHINE = (
    bh.HONEY_DEEP, bh.HONEY_MID, bh.HONEY, bh.HONEY_LIGHT, bh.HONEY_SHINE)
GLASS_EDGE = bh.GLASS_EDGE
GING_R, GING_P, GING_W = bh.GINGHAM_RED, bh.GINGHAM_PINK, bh.GINGHAM_WHITE
TIE = (120, 70, 40, 255)
# The jar plate's face: the comb's own browns, the hive's honey a long way down towards the
# outline (mixes of in-game swatches, nothing invented).
COMB_FACE = look.mix(HONEY_DEEP, OUTLINE, 0.52)
COMB_CELL = look.mix(HONEY_DEEP, OUTLINE, 0.38)
COMB_SUNK = look.mix(HONEY_DEEP, OUTLINE, 0.74)
# The card (scripts/cue_card.gd)
PAPER = cf(0.918, 0.859, 0.722)
PAPER_EDGE = cf(0.780, 0.702, 0.541)
PAPER_INK = cf(0.196, 0.141, 0.110)
CARD_OUTER = cf(0.235, 0.165, 0.118)

FONT = os.path.join(ROOT, "assets/Bungee-Regular.ttf")

# =============================================================================================
# The lattice: a 1x layer laid on a 1.5x plate on its measured phase.
# =============================================================================================
PAD = 4


class Layer:
    """A one-pixel-per-canvas-px (or world-px) RGBA layer over a whole 1920x1080 plate shown at
    1.5 screen px a px. `phase` is the screen px where the lattice starts (mod 3): screen px s
    is layer px floor(2 (s - phase) / 3)."""

    def __init__(self, phase=(0, 0), screen=(1920, 1080)):
        self.phase = phase
        self.screen_size = screen
        self.w = screen[0] * 2 // 3 + 2 * PAD
        self.h = screen[1] * 2 // 3 + 2 * PAD
        self.im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def paste(self, im, xy):
        self.im.alpha_composite(im, (int(xy[0]) + PAD, int(xy[1]) + PAD))

    def rect(self, x, y, w, h, col):
        if w > 0 and h > 0:
            layer = Image.new("RGBA", (int(w), int(h)), col)
            self.im.alpha_composite(layer, (int(x) + PAD, int(y) + PAD))

    def px(self, x, y, col):
        x, y = int(x) + PAD, int(y) + PAD
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(col) == 4 and col[3] < 255:
                b = self.im.getpixel((x, y))
                t = col[3] / 255.0
                if b[3] == 0:
                    self.im.putpixel((x, y), col)
                else:
                    self.im.putpixel((x, y), tuple(int(b[i] * (1 - t) + col[i] * t) for i in range(3))
                                     + (max(b[3], col[3]),))
            else:
                self.im.putpixel((x, y), col[:3] + (255,))

    def screen(self):
        a = np.array(self.im)
        sx = (2 * (np.arange(self.screen_size[0]) - self.phase[0])) // 3 + PAD
        sy = (2 * (np.arange(self.screen_size[1]) - self.phase[1])) // 3 + PAD
        return Image.fromarray(a[sy][:, sx].copy())


def onto(plate, layer, mask=None):
    """Lay a layer on a plate (in place); `mask` (screen-size bool array) keeps the layer off
    whatever it marks (the angler, for a bee behind him)."""
    s = layer.screen()
    if mask is not None:
        a = np.array(s)
        a[mask, 3] = 0
        s = Image.fromarray(a)
    plate.alpha_composite(s)
    return plate


def to_screen(xy, phase=(0, 0)):
    """A layer px -> its first screen px."""
    return (int(math.ceil(1.5 * xy[0])) + phase[0], int(math.ceil(1.5 * xy[1])) + phase[1])


def ticks(im, box, col=(255, 70, 160, 255), arm=10, gap=3):
    """Mark a zoom's area with four corner ticks just outside it, so nothing of what is judged
    at real scale is crossed by a line."""
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    x0, y0, x1, y1 = x0 - gap, y0 - gap, x1 + gap - 1, y1 + gap - 1
    for (x, y, sx, sy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        d.line([(x, y), (x + sx * arm, y)], fill=col, width=2)
        d.line([(x, y), (x, y + sy * arm)], fill=col, width=2)
    return im


# =============================================================================================
# Text at screen resolution: Bungee at the canvas size x 1.5, the HUD's shadow a canvas px down
# and right (Style.write: SHADE (0, 0, 0, 0.55) under pale ink, none under dark).
# =============================================================================================
_fonts = {}


def bungee(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size)
    return _fonts[size]


def text_width(s, size_c):
    return bungee(size_c * 1.5 * 4).getlength(s) / 6.0


def stext(plate, s, size_c, at_c, ink, align="left", within=None, shade=True):
    """Write `s` on a 1920x1080 plate: `at_c` is the baseline's left end in canvas px (Style.write's
    `at`); with `within` (x, y, w, h canvas) the line is centred in it across. Returns the canvas
    width it took."""
    S = 4
    f = bungee(size_c * 1.5 * S)
    wide = f.getlength(s)
    x = at_c[0] * 1.5
    if within is not None:
        if align == "center":
            x = (within[0] + (within[2] - wide / S / 1.5) * 0.5) * 1.5
        elif align == "right":
            x = (within[0] + within[2]) * 1.5 - wide / S
    y = at_c[1] * 1.5
    asc, desc = f.getmetrics()
    pad = 6 * S
    tmp = Image.new("RGBA", (int(wide) + pad * 2, asc + desc + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    lum = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2]
    if shade and lum > 0.3 * 255:
        d.text((pad + 1.5 * S, pad + asc + 1.5 * S), s, font=f, fill=SHADE_TXT, anchor="ls")
    d.text((pad, pad + asc), s, font=f, fill=ink, anchor="ls")
    small = tmp.resize((tmp.width // S, tmp.height // S), Image.BOX)
    plate.alpha_composite(small, (int(round(x - pad / S)), int(round(y - (pad + asc) / S))))
    return wide / S / 1.5


# =============================================================================================
# The HUD wood: Style._build_border, ported.
# =============================================================================================
_ART = Image.open(os.path.join(ROOT, "assets/ui/meter/Meter_Border.png")).convert("RGBA")
WALL, TOP, FOOT = 15, 16, 14
_CORNER_TOP = (256, 24, WALL, TOP)
_CORNER_FOOT = (256, 59, WALL, FOOT)
_TOP_RUN = (142, 24, 110, TOP)
_FOOT_RUN = (106, 59, 95, FOOT)
_SEAM_LINE = (66, 43, 28, 255)
_M64 = (1 << 64) - 1


def ghash(v):
    """Godot's hash() of an int (hash_one_uint64), so the bites land where the game's do."""
    v &= _M64
    v = ((~v) + (v << 18)) & _M64
    v ^= v >> 31
    v = (v * 21) & _M64
    v ^= v >> 11
    v = (v + (v << 6)) & _M64
    v ^= v >> 22
    return v & 0xFFFFFFFF


def _cut(im, b):
    x, y, w, h = b
    return im.crop((x, y, x + w, y + h))


def _run(piece, length):
    out = Image.new("RGBA", (max(length, 1), piece.height), (0, 0, 0, 0))
    back = piece.transpose(Image.FLIP_LEFT_RIGHT)
    at, turn = 0, False
    while at < length:
        take = min(piece.width, length - at)
        src = back if turn else piece
        start = src.width - take if turn else 0
        out.paste(src.crop((start, 0, start + take, piece.height)), (at, 0))
        at += take
        turn = not turn
    return out


def _rint(x):
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


_frames = {}


def border(w, h):
    """The meter's built border at w x h canvas px (Style._build_border), RGBA."""
    if (w, h) in _frames:
        return _frames[(w, h)]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rn, down = w - WALL * 2, h - TOP - FOOT
    if rn > 0:
        out.paste(_run(_cut(_ART, _TOP_RUN), rn), (WALL, 0))
        out.paste(_run(_cut(_ART, _FOOT_RUN), rn), (WALL, h - FOOT))
    if down > 0:
        stile = _run(_cut(_ART, _FOOT_RUN), down).transpose(Image.ROTATE_270)
        right = Image.new("RGBA", (WALL, down), (0, 0, 0, 0))
        right.paste(stile, (WALL - stile.width, 0))
        a = np.array(right)
        for x in range(WALL):
            if a[:, x, 3].max() == 0:
                for k in range(1, WALL):
                    src = [xx for xx in (x - k, x + k) if 0 <= xx < WALL and a[:, xx, 3].max() > 0]
                    if src:
                        a[:, x] = a[:, src[0]]
                        break
        right = Image.fromarray(a)
        out.paste(right.transpose(Image.FLIP_LEFT_RIGHT), (0, TOP))
        out.paste(right, (w - WALL, TOP))
    tr, fr = _cut(_ART, _CORNER_TOP), _cut(_ART, _CORNER_FOOT)
    out.paste(tr.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    out.paste(tr, (w - WALL, 0))
    out.paste(fr.transpose(Image.FLIP_LEFT_RIGHT), (0, h - FOOT))
    out.paste(fr, (w - WALL, h - FOOT))
    px = out.load()

    def line(x0, y0, ww, hh):
        for y in range(y0, y0 + hh):
            for x in range(x0, x0 + ww):
                if 0 <= x < w and 0 <= y < h and px[x, y][3] > 127:
                    px[x, y] = _SEAM_LINE
    if w - WALL * 2 >= 10:
        for x in (WALL - 1, w - WALL):
            line(x, 0, 1, TOP)
            line(x, h - FOOT, 1, FOOT)
    for y in (TOP, h - FOOT - 1):
        line(0, y, WALL, 1)
        line(w - WALL, y, WALL, 1)
    seed = w * 31 + h * 17
    for edge in range(4):
        along = w if edge < 2 else h
        room = along - (WALL + 5) * 2 - 10
        if room <= 0:
            continue
        count = max(int(along / 46.0), 1)
        for i in range(count):
            hh = ghash(seed * 97 + edge * 13 + i)
            wide = 7 + hh % 4
            deep = 3 + (hh // 11) % 3
            step = room / count
            at = WALL + 5 + int(step * (i + 0.15 + 0.7 * ((hh // 131) % 100) / 100.0))
            _bite(px, w, h, edge, at, wide, deep)
    _frames[(w, h)] = out
    return out


def _bite(px, w, h, edge, at, wide, deep):
    middle = at + wide * 0.5
    gone = []
    for step in range(deep):
        share = 1.0 - 0.8 * step / max(deep - 1, 1)
        span = max(_rint(wide * share), 1)
        frm = _rint(middle - span * 0.5)
        for i in range(span):
            s = [(frm + i, step), (frm + i, h - 1 - step), (step, frm + i), (w - 1 - step, frm + i)][edge]
            if 0 <= s[0] < w and 0 <= s[1] < h:
                px[s] = (0, 0, 0, 0)
                gone.append(s)
    for steps in (((1, 0), (-1, 0), (0, 1), (0, -1)), ((1, 1), (-1, 1), (1, -1), (-1, -1))):
        for s in gone:
            for d in steps:
                n = (s[0] + d[0], s[1] + d[1])
                if 0 <= n[0] < w and 0 <= n[1] < h and px[n][3] > 127:
                    px[n] = (0, 0, 0, 255)


def face_of(box):
    x, y, w, h = box
    return (x + WALL, y + TOP, w - WALL * 2, h - TOP - FOOT)


def board(layer, box, fill):
    """HudButtons.board: the face filled two px in under the wood, then the built border.
    Returns the face."""
    x, y, w, h = box
    f = face_of(box)
    layer.rect(f[0] - 2, f[1] - 2, f[2] + 4, f[3] + 4, fill)
    layer.paste(border(w, h), (x, y))
    return f


def sunk(layer, box, face):
    """HudButtons.sunk: a panel pressed into the wood."""
    x, y, w, h = box
    layer.rect(x - 1, y - 1, w + 2, h + 2, SEAM)
    layer.rect(x, y, w, h, face)
    layer.rect(x, y, w, 1, SEAM)


def comb_face(layer, f, fill=COMB_FACE, cell=COMB_CELL):
    """The jar plate's face: the comb's brown with a faint honeycomb pressed into it, hex
    cells 6 wide on rows 4 apart, whole pixels."""
    x0, y0, w, h = f
    layer.rect(x0 - 2, y0 - 2, w + 4, h + 4, fill)
    hexa = [".xx.", "x..x", "x..x", ".xx."]
    for r in range(-1, h // 4 + 2):
        for c in range(-1, w // 6 + 2):
            ox = x0 + c * 6 + (3 if r % 2 else 0)
            oy = y0 + r * 4 - 1
            for j, row in enumerate(hexa):
                for i, ch in enumerate(row):
                    xx, yy = ox + i, oy + j
                    if ch == "x" and x0 <= xx < x0 + w and y0 <= yy < y0 + h:
                        layer.px(xx, yy, cell)


# =============================================================================================
# The jar, at one canvas px a pixel (the HUD's grain): glass edge, honey, gingham lid, lit
# from the top left as the coin on the money plate is.
# =============================================================================================
JAR_KEY = {"O": OUTLINE, "R": GING_R, "P": GING_P, "W": GING_W, "t": TIE, "E": GLASS_EDGE,
           "g": (255, 255, 255, 255), "s": HONEY_SHINE, "L": HONEY_LIGHT, "H": HONEY, "M": HONEY_MID,
           "D": HONEY_DEEP, "b": look.SW["bark_lit"], "B": look.SW["bark"]}
JAR_LID = [
    "...OOOOOOO...",
    "..ORWRWRWRO..",
    ".ORWRWRWRWRO.",
    ".OPRPRPRPRPO.",
    "..OtttttttO..",
]
JAR_BODY = [
    "..OELLLLLEO..",
    ".OEsLLLLLLEO.",
    "OEgsLLLLLHHEO",
    "OEgLHHHHHHHEO",
    "OEgHHHHHHHMEO",
    "OEHHHHHHHHMEO",
    "OEHHHHHHHMMEO",
    "OEHHHHHHHMMEO",
    "OEMHHHHHMMDEO",
    ".OEMMMMMMDEO.",
    "..OOOOOOOOO..",
]
EMPTY_GLASS = (206, 232, 238, 70)


CREAM = bh.CREAM


def jar_art(W=15, H=15, fill=1.0, lid=True, dipper=False, label=True):
    """The bottling jar (build_hive jar2_parts) by rule at one px a pixel: a glass body W wide
    and H tall with rounded shoulders, a 1-px blue-grey glass edge, honey to `fill` (its top row
    the shine), a white streak down the lit left side, a cream label with the red rules and a
    honeycomb hex, a gingham cloth lid tied with string. Open (`lid` False) it shows an empty
    mouth, and `dipper` stands a wooden honey dipper in it. Inked with the game's outline."""
    neck = W - 4
    lid_h = 4 if lid else 0
    top = lid_h + 2                     # body's first row
    Wc, Hc = W + 4, top + H + 1
    a = bh.Art(Wc, Hc)
    ox = 2
    # the body: shoulders cut one px at the first and last rows
    rows = []
    for y in range(H):
        cut = 1 if y in (0, H - 1) else 0
        rows.append((ox + cut, ox + W - 1 - cut))
    honey_top, honey_bot = 1, H - 1
    surface = int(round(honey_bot - (honey_bot - honey_top) * fill))
    for y, (x0, x1) in enumerate(rows):
        yy = top + y
        for x in range(x0, x1 + 1):
            edge = x == x0 or x == x1
            if edge:
                a.px(x, yy, GLASS_EDGE)
                continue
            if y < surface or y == 0:
                a.px(x, yy, EMPTY_GLASS if y < surface else GLASS_EDGE)
                continue
            rel = (x - x0) / max(1, (x1 - x0))
            if y == surface:
                c = HONEY_SHINE if 0.25 < rel < 0.7 else HONEY_LIGHT
            elif y == H - 1 or y == H - 2 and rel > 0.6:
                c = HONEY_DEEP if rel > 0.55 else HONEY_MID
            elif rel > 0.72:
                c = HONEY_MID
            elif rel < 0.22:
                c = HONEY_LIGHT
            else:
                c = HONEY
            a.px(x, yy, c)
    # the neck: two rows of glass narrower than the body
    for y in range(2):
        yy = top - 2 + y
        for x in range(ox + 2, ox + W - 2):
            edge = x in (ox + 2, ox + W - 3)
            a.px(x, yy, GLASS_EDGE if edge else (EMPTY_GLASS if not lid or fill < 0.98 else HONEY_LIGHT))
    # the glass's streak down the lit side
    for y in range(2, min(H - 3, 2 + max(3, H // 3))):
        a.px(ox + 2, top + y, (255, 255, 255, 230))
    if label and H >= 12:
        ly = top + H // 2 - 2
        lw = W - 6
        lx = ox + 3
        a.rect(lx, ly, lw, 5, CREAM)
        a.rect(lx, ly, lw, 1, GING_R)
        a.rect(lx, ly + 4, lw, 1, GING_R)
        hx = lx + lw // 2 - 1
        for (dx, dy), c in {(0, 1): HONEY_MID, (1, 1): HONEY, (0, 2): HONEY, (1, 2): HONEY_MID}.items():
            a.px(hx + dx, ly + dy, c)
    if lid:
        # the cloth: one row wider than the neck each side, red and white checks, a pink row,
        # tied with brown string
        for y in range(3):
            for x in range(ox + 1, ox + W - 1):
                if y == 0 and x in (ox + 1, ox + W - 2):
                    continue
                on = (x + y) % 2
                a.px(x, y + 1, (GING_R if on else GING_W) if y < 2 else (GING_P if on else GING_R))
        for x in range(ox + 2, ox + W - 2):
            a.px(x, 4, TIE)
    im = bh.inked(a.im)
    if not lid:
        # the open mouth: a lit lip of glass across the neck's top row
        px = im.load()
        for x in range(ox + 3, ox + W - 1):
            if px[x, 1][3]:
                px[x, 1] = GLASS_EDGE if x in (ox + 3, ox + W - 2) else (214, 234, 240, 255)
    if dipper and not lid:
        # a wooden honey dipper standing in the jar, leaning out of the mouth to the right: two
        # px of wood, seen dimly through the empty glass and lost in the honey, whole above
        # the mouth
        up = 5
        stick = Image.new("RGBA", (im.width + 2, im.height + up), (0, 0, 0, 0))
        x0, y0 = W - 3, im.height - 4 + up
        for i in range(im.height + up - 2):
            x = x0 - 0 + int(round(i * 0.42))
            y = y0 - i
            if y < 1:
                break
            for dx in (0, 1):
                stick.putpixel((min(x + dx, stick.width - 2), y),
                               look.SW["bark_lit"] if dx == 0 else look.SW["bark"])
        stick = bh.inked(stick)
        out = Image.new("RGBA", stick.size, (0, 0, 0, 0))
        out.alpha_composite(stick)
        out.alpha_composite(im, (1, 1 + up))
        im = out.crop(out.getbbox())
    return im


def jar_closed(dim=False):
    im = look.grid(JAR_LID + JAR_BODY, JAR_KEY)
    return look.tinted(im, (60, 40, 30, 255), 0.5) if dim else im


def jar_open(fill=1.0, dipper=True):
    """The jar with its lid off and a wooden dipper standing in it, honey `fill` of the way up:
    the jar is the window's own hourglass."""
    body = [list(r) for r in JAR_BODY]
    rows = len(body)
    top, bottom = 1, rows - 2           # honey rows run 1..rows-2
    surface = int(round(bottom - (bottom - top) * fill))
    for y in range(rows):
        for x, ch in enumerate(body[y]):
            if ch in "sLHMDg" and y < surface:
                body[y][x] = "e"
            elif ch in "sLHMD" and y == surface:
                body[y][x] = "s" if 3 <= x <= 8 else "L"
    rim = ["..OOOOOOOOO..", ".OEeeeeeeeEO."]
    key = dict(JAR_KEY)
    key["e"] = EMPTY_GLASS
    im = look.grid(["." * 13] * 4 + rim + ["".join(r) for r in body[1:]], key)
    if dipper:
        # the dipper: a wooden stick leaning out of the mouth to the right, a honey knob
        # buried in the jar under the surface
        stick = [(9, 0), (9, 1), (8, 2), (8, 3), (7, 4), (7, 5)]
        for x, y in stick:
            im.putpixel((x, y), look.SW["bark_lit"] if y < 3 else look.SW["bark"])
        for x, y in stick:
            for dx, dy in ((1, 0), (-1, 0), (0, -1)):
                p = (x + dx, y + dy)
                if 0 <= p[0] < im.width and 0 <= p[1] < im.height and im.getpixel(p)[3] == 0:
                    im.putpixel(p, OUTLINE)
        # a honey drip down the outside of the stick, over the rim
        im.putpixel((10, 2), HONEY_LIGHT)
        im.putpixel((10, 3), HONEY)
    return im


def ring_drain(layer, cx, cy, r_out, thick, share, lit=HONEY_LIGHT, mid=HONEY, groove=SEAM,
               edge=OUTLINE):
    """A pixel ring round (cx, cy), `thick` px wide inside r_out, its lit arc `share` of the
    way round clockwise from twelve o'clock; the drained arc a dark groove. A one-px dark rim
    outside and in. The leading pixel of the lit arc is the shine."""
    for y in range(int(cy - r_out - 2), int(cy + r_out + 3)):
        for x in range(int(cx - r_out - 2), int(cx + r_out + 3)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r_out - thick <= r < r_out:
                a = (math.atan2(dx, -dy) / math.tau) % 1.0
                if a < share:
                    near_end = share - a < 0.045 and share < 0.999
                    col = HONEY_SHINE if near_end else (lit if dy < 0.5 else mid)
                else:
                    col = groove
                layer.px(x, y, col)
            elif r_out <= r < r_out + 1 or r_out - thick - 1 <= r < r_out - thick:
                layer.px(x, y, edge)


def dial(layer, cx, cy, r_out, share, jar, thick=2, well=COMB_SUNK):
    """A round hole sunk in the face, the jar standing in it, the ring draining round it."""
    inner = r_out - thick - 1
    for y in range(int(cy - inner - 1), int(cy + inner + 2)):
        for x in range(int(cx - inner - 1), int(cx + inner + 2)):
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) < inner:
                layer.px(x, y, well)
    ring_drain(layer, cx, cy, r_out, thick, share)
    b = jar.getbbox()
    jw, jh = b[2] - b[0], b[3] - b[1]
    layer.paste(jar.crop(b), (int(round(cx - jw / 2.0)), int(round(cy - jh / 2.0 + 0.5))))


CHIP = 22            # the key's box, one size for both devices (the D-pad glyph at 2 screen px
                     # a pack px is 32 screen px, 21 canvas px: it fills the same box)


def key_chip(layer, plate, x, y, letter="H", side=CHIP):
    """ShedRoom._draw_key: WOOD at 0.85 over what is under it, an INK_DIM rim, the key in INK.
    The letter goes on the plate at screen resolution (it is text)."""
    layer.rect(x, y, side, side, WOOD[:3] + (217,))
    for i in range(side):
        layer.px(x + i, y, INK_DIM)
        layer.px(x + i, y + side - 1, INK_DIM)
        layer.px(x, y + i, INK_DIM)
        layer.px(x + side - 1, y + i, INK_DIM)
    size = 15 if side >= 22 else 13
    return ("text", letter, size, (x, y + side * 0.5 + size * 0.36), INK, (x, y, side, side))


_glyphs = {}


def glyph(name):
    if name not in _glyphs:
        _glyphs[name] = Image.open(os.path.join(ROOT, "assets/ui/prompts/%s.png" % name)).convert("RGBA")
    return _glyphs[name]


def glyph_on_plate(plate, name, centre_c, px=2):
    """A lone pad glyph at whole screen px (Glyphs.draw_centred at inline_px(TEXT_BODY) = 2 screen
    px a pack px at 1080p), centred on a canvas point."""
    g = glyph(name)
    big = g.resize((g.width * px, g.height * px), Image.NEAREST)
    sx = int(round(centre_c[0] * 1.5 - big.width / 2.0))
    sy = int(round(centre_c[1] * 1.5 - big.height / 2.0))
    plate.alpha_composite(big, (sx, sy))


# =============================================================================================
# 1. The jar plate, three ways. Every box is in canvas px; the plate is 02_big_cast (HUD on,
# mid-run: Waiting 46, $3870). The column on the left is Waiting (20, 18, 206, 54) and money
# (20, 82, 206, 56), matched pixel for pixel against `border`.
# =============================================================================================
STOCK_BOX = (20, 18, 206, 54)
MONEY_BOX = (20, 82, 206, 56)
GAP = 10
IDLE = {"jars": 3, "share": None}
MID = {"jars": 2, "share": 0.5}


def board_comb(layer, box):
    f = face_of(box)
    comb_face(layer, f)
    layer.paste(border(box[2], box[3]), (box[0], box[1]))
    return f


def write_jobs(plate, jobs):
    for j in jobs:
        if j is None:
            continue
        if j[0] == "text":
            _, s, size, at, ink, within = j
            stext(plate, s, size, at, ink, align="center", within=within)
        elif j[0] == "label":
            _, s_, size, at, ink = j
            stext(plate, s_, size, at, ink)
        elif j[0] == "glyph":
            _, name, centre = j
            glyph_on_plate(plate, name, centre)


def count_job(s, panel_box, size=20):
    x, y, w, h = panel_box
    return ("text", s, size, (x, y + h * 0.5 + size * 0.35), HONEY_LIGHT, panel_box)


def chip_or_glyph(layer, x, y, pad_mode, side=CHIP):
    """The key, in one box whatever the device: the wood chip with H, or (pad) the D-pad up
    glyph alone in the same box, centred (Glyphs.lone: a chip holding a lone glyph draws the
    glyph only). The plate's layout never moves between devices."""
    if pad_mode:
        return ("glyph", "dpad_up", (x + side * 0.5, y + side * 0.5))
    return key_chip(layer, None, x, y, side=side)


# --- A: the medallion slab, a third slab under the purse ------------------------------------
# The money plate's grammar: the picture (the medallion), the figure on its sunk panel, the key.
# No word (the jar says it, and it is one string fewer in eight languages); the slab is only as
# long as those three need, its left edge on the column's.
A_MEDAL = 20          # the medallion's radius over the slab's left end, wood and all
A_PANEL = 44          # the count's sunk panel: wide enough for "12"
A_BOX = (20, MONEY_BOX[1] + MONEY_BOX[3] + GAP, 1 + 2 * A_MEDAL + 5 + A_PANEL + 7 + CHIP + 5 + WALL, 56)
COMB_CELL_DIM = look.mix(COMB_FACE, COMB_CELL, 0.5)     # the comb pressed in a step fainter
MEDAL_IN = look.mix(HONEY_DEEP, OUTLINE, 0.6)            # the medallion's well, a step up


def jar_state(state, W=14):
    """One jar for both states: lidded and full at idle; running, the same body with its lid
    off and the dipper in it, the honey level the time left."""
    if state["share"] is None:
        return jar_art(W, W, label=False)
    return jar_art(W, W, state["share"], lid=False, dipper=True, label=False)


def draw_A(plate, state):
    L = Layer()
    f = face_of(A_BOX)
    comb_face(L, f, cell=COMB_CELL_DIM)
    L.paste(border(A_BOX[2], A_BOX[3]), (A_BOX[0], A_BOX[1]))
    cx, cy = A_BOX[0] + A_MEDAL + 1, A_BOX[1] + A_BOX[3] // 2
    for y in range(cy - A_MEDAL - 1, cy + A_MEDAL + 2):
        for x in range(cx - A_MEDAL - 1, cx + A_MEDAL + 2):
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r < A_MEDAL + 1:
                L.px(x, y, OUTLINE if r >= A_MEDAL else COMB_FACE)
    # idle: the ring is an empty groove (nothing is running); the gold arc only while a window
    # runs, draining clockwise
    share = 0.0 if state["share"] is None else state["share"]
    dial(L, cx, cy, A_MEDAL - 1, share, jar_state(state), thick=3, well=MEDAL_IN)
    jobs = []
    px0 = cx + A_MEDAL + 5
    pnl = (px0, f[1] + 2, A_PANEL, f[3] - 4)
    sunk(L, pnl, COMB_SUNK)
    jobs.append(count_job("%d" % state["jars"], pnl))
    chip_x = pnl[0] + pnl[2] + 7
    jobs.append(chip_or_glyph(L, chip_x, A_BOX[1] + (A_BOX[3] - CHIP) // 2,
                              state.get("pad", state["share"] is not None)))
    onto(plate, L)
    write_jobs(plate, jobs)
    return plate


# --- B: a picture button in the top-right row, left of Decorate -----------------------------
B_BOX = (1012 - 120 - GAP, 18, 120, 100)


def style_plate(L, box, face, c=2):
    """Style.plate: a flat plate with its corners clipped c px."""
    x, y, w, h = box
    for yy in range(h):
        for xx in range(w):
            cut = c - min(yy, h - 1 - yy)
            if cut > 0 and (xx < cut or xx >= w - cut):
                continue
            L.px(x + xx, y + yy, face)


def label_plate(L, face, text):
    box = (face[0] + 4, face[1] + face[3] - 14 - 3, face[2] - 8, 14)
    style_plate(L, box, BUTTON_SUNK)
    h = 11
    return ("text", text, h, (box[0], box[1] + 7 + h * 0.35), INK, box)


def badge(L, face, text):
    wide = int(text_width("99", 12)) + 10
    box = (face[0] + face[2] - 3 - wide, face[1] + 3, wide, 15)
    style_plate(L, box, BUTTON_SUNK)
    return ("text", text, 12, (box[0], box[1] + (15 + 12 * 0.62) * 0.5), BOARD_INK, box)


def shelf(L, x0, y, w):
    """A short plank shelf in the frame's wood: lit top row, body, dark foot, outlined."""
    L.rect(x0 - 1, y - 1, w + 2, 6, OUTLINE)
    L.rect(x0, y, w, 3, WOOD)
    L.rect(x0, y, w, 1, WOOD_LIT)
    L.rect(x0, y + 3, w, 1, SEAM)


def draw_B(plate, state):
    L = Layer()
    f = board_comb(L, B_BOX)
    jobs = []
    room_h = f[3] - 14 - 4
    shelf_y = f[1] + room_h - 4
    jar = jar_art(14, 14)
    jb = jar.getbbox()
    jw, jh = jb[2] - jb[0], jb[3] - jb[1]
    shelf(L, f[0] + 6, shelf_y, f[2] - 12)
    bees = [((f[0] + 30, f[1] + 12), 0, False), ((f[0] + 58, f[1] + 16), 4, True)]
    if state["share"] is None:
        n = state["jars"]
        span = n * jw + (n - 1) * 2
        x = f[0] + (f[2] - span) // 2
        for i in range(n):
            L.paste(jar.crop(jb), (x + i * (jw + 2), shelf_y - jh))
    else:
        cx, cy = f[0] + f[2] // 2, f[1] + 26
        L.paste(jar.crop(jb), (f[0] + 7, shelf_y - jh))
        if state["jars"] > 1:
            L.paste(jar.crop(jb), (f[0] + f[2] - 7 - jw, shelf_y - jh))
        R = 18
        for y in range(cy - R - 1, cy + R + 2):
            for x in range(cx - R - 1, cx + R + 2):
                r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if r < R + 1:
                    L.px(x, y, OUTLINE if r >= R else COMB_FACE)
        dial(L, cx, cy, R - 1, state["share"],
             jar_art(12, 12, state["share"], lid=False, dipper=True, label=False), thick=3)
        bees = [((f[0] + 18, f[1] + 30), 2, False), ((f[0] + 72, f[1] + 30), 5, True)]
    for (bx, by), fr, left in bees:
        b = look.mini_round("A", fr, facing_left=left)
        ax, ay = look.mini_round_anchor("A", "fly", left, fr)
        L.paste(b, (bx - ax, by - ay))
    jobs.append(label_plate(L, f, "HONEY"))
    jobs.append(badge(L, f, "%d" % state["jars"]))
    if state["share"] is None:
        jobs.append(key_chip(L, None, f[0] + 3, f[1] + 3, side=18))
    else:
        jobs.append(("glyph", "dpad_up", (f[0] + 12, f[1] + 12)))
    onto(plate, L)
    write_jobs(plate, jobs)
    return plate


# --- C: a corner key beside the camera and the gear -----------------------------------------
CAM_BOX = (1140, 644, 56, 56)
C_BOX = (CAM_BOX[0] - 56 - GAP, CAM_BOX[1], 56, 56)


def frame_drain(L, f, share):
    """A drain running round the inside of a square face, clockwise from the top middle: the
    outer row of the face in honey, the row inside it a shade down; drained, a groove."""
    x0, y0, w, h = f
    mid = x0 + w // 2
    path = [(x, y0) for x in range(mid, x0 + w)]
    path += [(x0 + w - 1, y) for y in range(y0 + 1, y0 + h)]
    path += [(x, y0 + h - 1) for x in range(x0 + w - 2, x0 - 1, -1)]
    path += [(x0, y) for y in range(y0 + h - 2, y0 - 1, -1)]
    path += [(x, y0) for x in range(x0 + 1, mid)]
    lit = int(round(len(path) * share))
    for i, (x, y) in enumerate(path):
        on = i < lit
        col = (HONEY_SHINE if i == lit - 1 and share < 0.999 else HONEY_LIGHT) if on else SEAM
        L.px(x, y, col)
        ix = x + (1 if x == x0 else -1 if x == x0 + w - 1 else 0)
        iy = y + (1 if y == y0 else -1 if y == y0 + h - 1 else 0)
        L.px(ix, iy, HONEY if on else COMB_SUNK)


def draw_C(plate, state):
    L = Layer()
    f = board_comb(L, C_BOX)
    share = 0.0 if state["share"] is None else state["share"]
    frame_drain(L, f, share)
    jar = (jar_art(12, 12, label=False) if state["share"] is None
           else jar_art(12, 12, state["share"], lid=False, dipper=True, label=False))
    jb = jar.getbbox()
    jw, jh = jb[2] - jb[0], jb[3] - jb[1]
    L.paste(jar.crop(jb), (f[0] + (f[2] - jw) // 2, f[1] + (f[3] - jh) // 2 + 1))
    jobs = []
    bw = int(text_width("99", 12)) + 10
    bbox = (C_BOX[0] + C_BOX[2] - bw + 2, C_BOX[1] - 6, bw, 15)
    style_plate(L, bbox, BUTTON_SUNK)
    jobs.append(("text", "%d" % state["jars"], 12, (bbox[0], bbox[1] + (15 + 12 * 0.62) * 0.5),
                 BOARD_INK, bbox))
    jobs.append(chip_or_glyph(L, C_BOX[0] + 8, C_BOX[1] - CHIP - 2, state["share"] is not None))
    onto(plate, L)
    write_jobs(plate, jobs)
    return plate


PLATE_SPEC = [
    ("A", "Third slab", draw_A, (0, 0, 520, 330), (14, 210, 300, 320), True,
     "Under the purse, in the money plate's own wood and its grammar: the picture, the figure on "
     "its sunk panel, the key, and no word (the jar says it, and it is one string fewer in eight "
     "languages); only as long as those three need, its left edge on the column's. The jar stands "
     "in a medallion over the slab's left end (the pollution meter's circle over a bar, in "
     "small). One jar in both states: lidded and full while it waits, its ring an empty dark "
     "groove (nothing is running); eaten, the same jar with its lid off and a dipper in it, its "
     "honey the time left, and the ring's gold arc draining clockwise. The key sits in one "
     "22 px box on both devices: the house's wood chip with H, or the D-pad glyph alone in the "
     "same box (Glyphs.lone), so the plate never moves. The honey coins land in the purse right "
     "above it."),
    ("B", "Picture button", draw_B, (1240, 0, 1920, 230), (1312, 18, 1520, 186), False,
     "A third picture button in the top-right row (120 x 100, left of Decorate): the jars held "
     "standing on a shelf one by one, HONEY on the foot plate, the count on the Upgrades badge. "
     "Eating lifts a jar off the shelf into a draining dial. The prettiest and the biggest, "
     "but the row grows and shrinks with the jars, and it sits with the boards you open rather "
     "than with the money it pays."),
    ("C", "Corner key", draw_C, (1340, 860, 1920, 1080), (1580, 920, 1820, 1066), False,
     "A 56 x 56 key beside the camera and the gear (their frame, pixel for pixel): the jar "
     "alone on the face, the drain running round the inside of the wood, the count on a badge "
     "over the corner, the key hanging over the top. The quietest; it reads as a setting, and "
     "it is the farthest thing on screen from the purse it pays into."),
]


def plates_section():
    base = look.plate("big_cast")
    opts = []
    for label, name, fn, crop, zb, rec, cap in PLATE_SPEC:
        idle = fn(base.copy(), IDLE)
        mid = fn(base.copy(), MID)
        body = flow([panel(idle.crop(crop), "idle: 3 jars, keyboard (real scale)"),
                     panel(mid.crop(crop), "mid-window: 2 jars, half the time left, pad (real scale)"),
                     panel(look.crop_zoom(idle, zb, 3), "3x: idle"),
                     panel(look.crop_zoom(mid, zb, 3), "3x: mid-window (the D-pad up glyph)")],
                    SHEET_WIDE, 14)
        opts.append(look.option_block("1" + label, name, cap, body, recommended=rec, width=SHEET_WIDE))
    return opts


# =============================================================================================
# 2. The net in honey time. 05_gold_double is a lucky double cast: the upper net is the lucky one,
# gold (the game's capture), the lower one the plain copy. In honey time the copy is honeyed
# (NetShape: honey only where the gold is not), so the plate is exactly the moment to judge: the
# lower net's rim and beads are recoloured pixel by pixel (honey_recolor) and drips hung off its
# near-side beads; the gold net beside it is untouched.
# =============================================================================================
import honey_recolor as hrc  # noqa: E402
import honey_parts as hp  # noqa: E402

NET05_BOX = (800, 455, 1320, 760)       # the plain net, screen px (the gold net's beads are gold)
NET05_PHASE = (0, 1)                    # 05's lake lattice
NET05_CROP = (770, 236, 1320, 772)      # both nets
NET05_ZH = (960, 684, 1130, 770)        # the honey net's near rim, for the zoom
NET05_ZG = (1150, 250, 1270, 324)       # the gold net's far rim, for the zoom


def world_of(s, phase):
    return (int(math.floor(2 * (s[0] - phase[0]) / 3.0)), int(math.floor(2 * (s[1] - phase[1]) / 3.0)))


def near_beads(masks, box, keep_share=0.35):
    """The beads on the near half of a recoloured net: (screen x, screen y under it, clump),
    left to right."""
    x0, y0, x1, y1 = box
    sub = masks["bead"][y0:y1, x0:x1]
    beads = hp.beads_of(sub, 3)
    if not beads:
        return []
    cy = sum(b[1] for b in beads) / len(beads)
    bot = max(b[1] for b in beads)
    cut = cy + (bot - cy) * keep_share
    out = [(b[0] + x0, b[5] + y0 + 1, (b[2] + x0, b[3] + y0, b[4] + x0, b[5] + y0))
           for b in beads if b[1] >= cut]
    return sorted(out)


# a drip's stage per near bead, by its index: most beads are dry, a few are mid-drip
DRIP_PLAN = [None, 2, None, None, 0, None, 3, None, None, 1, None, 4, None, None, 2, None,
             5, None, None, 0, None, 3, None, None, 1, None, 2, None, None, 4]


def hang_drips(plate, beads, ramp, phase, plan=DRIP_PLAN, ring_alpha=0.62, seed=3, long=False,
               drop_at=0):
    """Hang drips (and the rings and amber dots of the ones that have gone in) off near beads.
    `drop_at` moves every drip's anchor down that many world px (under a swollen bead)."""
    L = Layer(phase)
    rings = Layer(phase)
    for i, (sx, sy, _) in enumerate(beads):
        st = plan[i % len(plan)]
        if st is None:
            continue
        wx, wy = world_of((sx, sy), phase)
        wy += drop_at
        if long and st == 2:
            st = 3
        im, off = hp.drip(st, ramp)
        L.paste(im, (wx + off[0], wy + off[1]))
        if st >= 4 or (i % 7 == 5):
            # a drop already gone in: a ring a few px below the rim and an amber dot sinking
            land = (wx, wy + 9 + (i % 3))
            size = "SML"[(i + seed) % 3]
            r, mid = hp.ring(size, seed + i, alpha=ring_alpha * (1.0 - 0.25 * "SML".index(size)))
            rings.paste(r, (land[0] - mid[0], land[1] - mid[1]))
            if size == "S":
                L.px(land[0] - 1, land[1], ramp["mid"])
                L.px(land[0], land[1], ramp["low"])
            elif size == "M":
                L.px(land[0], land[1], ramp["low"])
    onto(plate, rings)
    onto(plate, L)


def drop_beads(plate, beads, ramp, phase):
    """Option B: every near bead swollen into a hanging honey drop, its top on the bead's top."""
    L = Layer(phase)
    for sx, sy, b in beads:
        wx, wy = world_of((sx, b[1]), phase)
        L.paste(hp.drop_bead(ramp), (wx - 1, wy))
    onto(plate, L)


# The teardrop drips (second review): only a few hang at once, staggered along the near rim and
# only where open water is under them, each at its own stage; the plops ring the water a few px
# below and leave a honey blob floating.
TEAR_PLAN = ["hang", "stretch", "plop", "fall", "hang"]


def pick_spread(beads, n):
    """`n` beads spread evenly along the rim (left to right)."""
    if len(beads) <= n:
        return list(beads)
    step = (len(beads) - 1) / float(n - 1)
    return [beads[int(round(i * step))] for i in range(n)]


def hang_tears(plate, beads, ramp, phase, plan=TEAR_PLAN, seed=3):
    """Hang teardrop drips off `beads` (already chosen) by `plan`, plops below them."""
    L = Layer(phase)
    rings = Layer(phase)
    for i, (sx, sy, _) in enumerate(beads):
        st = plan[i % len(plan)]
        if st is None:
            continue
        wx, wy = world_of((sx, sy), phase)
        if st == "plop":
            # the drop has gone in: a stub on the bead, the ring and the blob below it
            L.px(wx, wy, ramp["mid"])
            size = "M"
            im, mid = hp.plop(size, seed + i, ramp)
            rings.paste(im, (wx - mid[0], wy + 13 - mid[1]))
            continue
        im, off = hp.tear_drip(st, ramp)
        L.paste(im, (wx + off[0], wy + off[1]))
    onto(plate, rings)
    onto(plate, L)


def tears_on(plate, masks, box, ramp, phase, n=5, keep_share=0.5, plan=TEAR_PLAN):
    beads = open_below(near_beads(masks, box, keep_share=keep_share), masks)
    hang_tears(plate, pick_spread(beads, n), ramp, phase, plan=plan)


def tear_life(ramp, bg=(40, 80, 77, 255), scale=6, soak=False):
    """One teardrop's life at `scale`x on clean water, then its plop."""
    frames, labels = [], []
    for st, lab in (("hang", "hangs"), ("stretch", "stretches"), ("fall", "lets go, falls")):
        c = Image.new("RGBA", (16, 26), bg)
        top = 1
        if soak:
            mesh = ["..x....x....x...", ".x.x..x.x..x.x..", "x...xx...xx...xx"]
            for r, row in enumerate(mesh):
                for i, ch in enumerate(row):
                    if ch == "x":
                        c.putpixel((i, r), ramp["low"] if r == 2 else MESH_TAN)
            top = 3
        cord = look.grid(["llllllllllllllll", "mmmmmmmmmmmmmmmm", "mmmmmmmmmmmmmmmm"],
                         {"l": ramp["lit"], "m": ramp["mid"]})
        c.alpha_composite(cord, (0, top))
        bead = look.grid(["lll", "mmm", "ddd"], {"l": ramp["lit"], "m": ramp["low"], "d": ramp["deep"]})
        c.alpha_composite(bead, (7, top))
        im, off = hp.tear_drip(st, ramp)
        c.alpha_composite(im, (8 + off[0], top + 3 + off[1]))
        frames.append(c)
        labels.append(lab)
    for k, (size, lab) in enumerate((("S", "plop"), ("M", "ring spreads"), ("L", "blob lingers"))):
        c = Image.new("RGBA", (28, 18), bg)
        im, mid = hp.plop(size, 11 + k, ramp, dot=True)
        c.alpha_composite(im, (14 - mid[0], 10 - mid[1]))
        frames.append(c)
        labels.append(lab)
    ims = [panel(zoom(f, scale), lab) for f, lab in zip(frames, labels)]
    return stack(ims, "h", 8)


MESH_TAN = (150, 112, 70, 255)      # the mesh's cord as captured (05_gold_double), for 2C's strip


def drip_life(ramp, opts=None, bg=(40, 80, 77, 255), scale=6):
    """The drip's life at `scale`x on clean water: forming, hanging, falling, the ring spreading.
    Option B's bead is the swollen drop the drips hang from; option C's strip shows the mesh
    above the rim soaked a cell deep."""
    opts = opts or {}
    frames = []
    labels = ["sags", "forms", "hangs", "stretches", "lets go", "falls", "ring S", "ring M",
              "ring L"]
    tall = 24 if opts.get("drops") else 20
    for st in range(6):
        c = Image.new("RGBA", (16, tall), bg)
        top = 1
        if opts.get("soak"):
            # a cell of mesh over the rim: diamonds of cord, honeyed in the row next to the rim
            mesh = ["..x....x....x...", ".x.x..x.x..x.x..", "x...xx...xx...xx"]
            for r, row in enumerate(mesh):
                for i, ch in enumerate(row):
                    if ch == "x":
                        c.putpixel((i, r), ramp["low"] if r == 2 else MESH_TAN)
            top = 3
        cord = look.grid(["llllllllllllllll", "mmmmmmmmmmmmmmmm", "mmmmmmmmmmmmmmmm"],
                         {"l": ramp["lit"], "m": ramp["mid"]})
        c.alpha_composite(cord, (0, top))
        if opts.get("drops"):
            # the swollen bead: a plump drop hanging under the cord, the drip off its point
            c.alpha_composite(hp.drop_bead(ramp), (7, top + 2))
            foot = top + 2 + 5
        else:
            bead = look.grid(["lll", "mmm", "ddd"], {"l": ramp["lit"], "m": ramp["low"], "d": ramp["deep"]})
            c.alpha_composite(bead, (7, top))
            foot = top + 3
        im, off = hp.drip(st, ramp)
        c.alpha_composite(im, (8 + off[0], foot + off[1]))
        frames.append(c)
    for k, size in enumerate("SML"):
        c = Image.new("RGBA", (28, 18), bg)
        r, mid = hp.ring(size, 11 + k, alpha=0.62 * (1.0 - 0.25 * k))
        c.alpha_composite(r, (14 - mid[0], 10 - mid[1]))
        if k < 2:
            c.putpixel((14, 10), ramp["low"])
        frames.append(c)
    ims = [panel(zoom(f, scale), lab) for f, lab in zip(frames, labels)]
    return stack(ims, "h", 8)


NET_SPEC = [
    ("A", "Amber cord, drops that plop", hp.RAMP_HIVE, dict(), True,
     "The rim cord and its beads in the jar's own honey a step down (HONEY_MID with a HONEY lit "
     "row, beads HONEY_DEEP to HONEY): orange where the lucky rim is yellow; the mesh stays tan, "
     "no stars, no glint. At most five drips at once, spread along the near rim and only where "
     "open water is under it, each at its own stage: a 3x4 teardrop with a lit pixel, ringed in "
     "the outline like every sprite, hanging on a 1 px thread, stretching, letting go; one that "
     "has gone in leaves a whole foam ring (the splash's 2 px cells, bright enough for murky "
     "water) round a honey blob that floats a moment. One honey everywhere: rim, jar, coin. It "
     "reads apart from gold by hue and by moving down where the gold glints across."),
    ("B", "Honey-drop beads", hp.RAMP_GAME, dict(drops=True, long=True), False,
     "NetShape's AMBER_* as built (redder, darker), and every near-side bead swollen into a plump "
     "honey drop (3x5, a shine pixel) with long threads stretching off more of them. The most "
     "honey-like outline and the furthest hue from gold, but busy, and its red amber is a "
     "different honey from the jar's and the coin's."),
    ("C", "Soaked net", hp.RAMP_HIVE, dict(soak=22), False,
     "A's rim and teardrops, and the honey soaking a cell into the mesh from the rim in three hard "
     "steps. The loudest at a glance, but it is the lucky net's own pattern (gold creeping in "
     "from the rim) in another colour, so the two nets share a shape and only the hue tells "
     "them apart."),
]


def net_variant(ramp, opts):
    base = look.plate("gold_double")
    if opts.get("soak"):
        masks = hrc.recolour(base, NET05_BOX, ramp, soak=opts["soak"], soak_ramp=ramp)
    else:
        masks = hrc.recolour(base, NET05_BOX, ramp)
    beads = near_beads(masks, NET05_BOX)
    if opts.get("drops"):
        drop_beads(base, beads, ramp, NET05_PHASE)
        plan = [None, 3, None, 2, 3, None, 1, 3, None, 4, 2, None, 3, 5, None, 2]
        hang_drips(base, beads, ramp, NET05_PHASE, plan=plan, long=True, drop_at=3)
    else:
        tears_on(base, masks, NET05_BOX, ramp, NET05_PHASE)
    return base


# The two nets' left ends: the same stretch of rim, at the same angle, over the same clean
# shallow water on the plate's left, so gold and honey are judged like for like.
NET05_SEG_G = (772, 318, 892, 392)      # the lucky (gold) net's left end, screen px
NET05_SEG_H = (805, 524, 925, 598)      # the copy (honey) net's left end


def net_section():
    opts = []
    today = look.plate("gold_double")
    for label, name, ramp, o, rec, cap in NET_SPEC:
        im = net_variant(ramp, o)
        shown = im.copy()
        zh = look.crop_zoom(im, NET05_ZH, 4)
        ticks(shown, NET05_ZH)
        zg = look.crop_zoom(today, NET05_SEG_G, 4)
        zgh = look.crop_zoom(im, NET05_SEG_H, 4)
        ticks(shown, NET05_SEG_G)
        ticks(shown, NET05_SEG_H)
        life = (drip_life(ramp, o) if o.get("drops") else tear_life(ramp, soak=bool(o.get("soak"))))
        body = flow([panel(shown.crop(NET05_CROP), "real scale: lucky gold (top) and honey (bottom)"),
                     stack([panel(zg, "4x: the lucky net's left end (gold, as captured)"),
                            panel(zgh, "4x: the honey net's left end, same angle and water")], "v", 10),
                     panel(zh, "4x: the honey net's near rim and its drips"),
                     panel(life, "6x: one drip's life, then its plop")],
                    SHEET_WIDE, 14)
        opts.append(look.option_block("2" + label, name, cap, body, recommended=rec, width=SHEET_WIDE))
    return [callout_net()] + opts


def callout_net():
    today = look.plate("gold_double")
    mine = look.plate("gold_double")
    hrc.recolour(mine, NET05_BOX, hp.RAMP_HIVE)
    built = look.plate("gold_double")
    hrc.recolour(built, NET05_BOX, hp.RAMP_GAME)
    row = stack([panel(look.crop_zoom(today, NET05_SEG_G, 4), "lucky gold (as captured)"),
                 panel(look.crop_zoom(built, NET05_SEG_H, 4), "built: NetShape.AMBER_*"),
                 panel(look.crop_zoom(mine, NET05_SEG_H, 4), "this sheet (2A): the hive's honey")], "h", 14)
    return callout(
        "Differs from the code already built (Vigilance rule): Richard decides which is authoritative",
        "The other workflow has already built the honey net into the game (scripts/net_shape.gd: "
        "AMBER_DEEP / LOW / AMBER / LIT / SHADE, redder and darker than the jar's honey, and "
        "AMBER_RIM_HALF 1.5). 2A recommends the hive's own honey instead (one honey for rim, jar, "
        "coin and drips); 2B is the built ramp. The same stretch of rim, gold and both honeys, 4x:",
        row)


# =============================================================================================
# 3. Bees round the angler in honey time, thinning as the window runs out. Plate 02_big_cast:
# the angler mid-haul on the beach, the lake at the play stop (1 world px a canvas px, the
# lattice's phase (2, 2), measured off the angler). The bees are the lake's mini bee (look's
# variant A), one art px a world px; a bee behind him is hidden by his own pixels.
# =============================================================================================
ANGLER02_BOX = (934, 590, 1004, 666)    # his outline, hat to boots, basket and all
ANGLER02_FEET = (963, 657)              # screen px under his boots
LAKE02_PHASE = (2, 2)
BEE02_CROP = (800, 500, 1130, 720)
STATES = [("full", "just eaten: 15 s left"), ("half", "half the time left"),
          ("out", "nearly out: 2 s left")]

ORBIT_SPEC = [
    ("A", "Waist ring", "A", False,
     "One tilted ring of bees round his middle, evenly spaced and wheeling round together; behind "
     "him they pass under his own pixels. Thinning opens gaps in the ring, so the ring itself is "
     "a clock. Tidy and readable, but it turns like a UI ring rather than a swarm."),
    ("B", "Crown of bees", "B", False,
     "A small quick ring over his hat, a crown of bees between the hat and the count over his "
     "head; the last one settles on the brim. Cute and the clearest in a crowd, but it sits in the "
     "one strip of screen the haul count needs."),
    ("C", "Buzzing escort", "C", True,
     "Every bee on a loop of its own: its own radius, height, speed, way round and tilt, so they "
     "cross, overtake and dip like real bees round a jar, eight spread round him at the start, "
     "every one kept at least 3 art px clear of his outline (a bee on his silhouette reads as "
     "something stuck to him). Thinning lets the low loops go first, so the half-time four ride "
     "at hat and chest height, and the last bee circles off the side of his hat, wings up. The "
     "bee is the lake's round bee (a 6x5 oval in the outline, two bands, a 2x2 eye with its "
     "glint, two pale wing dabs off its back): its loop is under the plates. The most alive, and "
     "it stays off his face and off the count."),
]


CLEAR = 3        # every bee stays this many art (world) px clear of the angler's own pixels


def _clear_spot(mask_grown, b, at, centre, phase, most=40):
    """Push a bee placed at world `at` straight away from `centre` until none of its pixels
    lands on the (grown) angler mask. Returns the world spot."""
    a = np.array(b)[..., 3] > 0
    ys, xs = np.nonzero(a)
    dx, dy = at[0] - centre[0], at[1] - centre[1]
    n = math.hypot(dx, dy) or 1.0
    ux, uy = dx / n, dy / n
    for k in range(most):
        x, y = at[0] + ux * k, at[1] + uy * k
        hit = False
        for py, px in zip(ys, xs):
            sx, sy = to_screen((int(round(x)) + px, int(round(y)) + py), phase)
            for ox in (0, 1):
                for oy in (0, 1):
                    yy, xx = sy + oy, sx + ox
                    if 0 <= yy < mask_grown.shape[0] and 0 <= xx < mask_grown.shape[1] and mask_grown[yy, xx]:
                        hit = True
                        break
                if hit:
                    break
            if hit:
                break
        if not hit:
            return (int(round(x)), int(round(y)))
    return (int(round(at[0])), int(round(at[1])))


def bee_layers(plate, opt, state, t=hp.SHOW_T, feet=ANGLER02_FEET, phase=LAKE02_PHASE,
               box=ANGLER02_BOX, mask=None):
    """Lay the orbit's bees on `plate` round the angler whose feet stand on screen px `feet`,
    every one at least CLEAR art px off his silhouette."""
    n = hp.COUNTS[state]
    pts = hp.ORBITS[opt](n, t)
    if mask is None:
        mask = hp.angler_mask(plate, box)
    grown = hrc.dilate(mask, int(round(CLEAR * 1.5)))
    fw = world_of(feet, phase)
    centre = (fw[0], fw[1] - 22)
    back, front = Layer(phase), Layer(phase)
    for k, (x, y, behind, left, i) in enumerate(pts):
        frame = int(t * 12 + i * 2) % 6
        b = look.mini_round("A", frame, facing_left=left, pose="fly")
        ax, ay = look.mini_round_anchor("A", "fly", left, frame)
        if state == "out":
            # the last bee: off the side of his hat (A, C), wings up, or sat on the brim (B)
            behind = False
            if opt == "B":
                b = look.mini_round("A", 0, facing_left=True, pose="rest")
                ax, ay = look.mini_round_anchor("A", "rest", True, 0)
                x, y = -9, -31
            else:
                b = look.mini_round("A", 0, facing_left=True, pose="fly")
                ax, ay = look.mini_round_anchor("A", "fly", True, 0)
                x, y = 22, -38
        if behind:
            b = look.tinted(b, look.OUT, 0.18)
        at = (fw[0] + int(round(x)) - ax, fw[1] + int(round(y)) - ay)
        if not (state == "out" and opt == "B"):
            at = _clear_spot(grown, b, at, (centre[0] - ax, centre[1] - ay), phase)
        (back if behind else front).paste(b, at)
    onto(plate, back, mask=mask)
    onto(plate, front)
    return plate


def bee_strip():
    """The round mini bee's loop: the fly frames (wings up / mid / down, the bob on 3-5) and the
    rest pose, at 6x on clean water and on sand, and at real scale (1.5 screen px a px)."""
    big = []
    for bg, lab in (((40, 80, 77, 255), "on water"), ((214, 186, 132, 255), "on sand")):
        row = []
        for f in range(6):
            c = Image.new("RGBA", (14, 13), bg)
            c.alpha_composite(look.mini_round("A", f), (1, 1))
            row.append(panel(zoom(c, 6), "fly %d" % f if bg[0] == 40 else None))
        c = Image.new("RGBA", (14, 13), bg)
        c.alpha_composite(look.mini_round("A", 0, pose="rest"), (1, 1))
        row.append(panel(zoom(c, 6), "rest" if bg[0] == 40 else None))
        big.append(stack(row, "h", 6))
    # real scale: the loop laid side by side on a 1.5x lattice
    L = Layer(screen=(300, 30))
    L.rect(-PAD, -PAD, 300, 40, (40, 80, 77, 255))
    for f in range(6):
        L.paste(look.mini_round("A", f), (2 + f * 14, 3))
    L.paste(look.mini_round("A", 0, pose="rest"), (2 + 6 * 14, 3))
    real = L.screen()
    return stack(big + [panel(real, "real scale (1.5 screen px an art px)")], "v", 8)


def bees_section():
    opts = []
    base = look.plate("big_cast")
    mask = hp.angler_mask(base, ANGLER02_BOX)
    for label, name, key, rec, cap in ORBIT_SPEC:
        reals, zooms = [], []
        for state, words in STATES:
            im = bee_layers(base.copy(), key, state, mask=mask)
            shown = im.copy()
            z = look.crop_zoom(im, (892, 540, 1036, 672), 4)
            ticks(shown, (892, 540, 1036, 672))
            reals.append(panel(shown.crop(BEE02_CROP), "real scale: " + words))
            zooms.append(panel(z, "4x: " + words))
        rows = [stack(reals, "h", 14), stack(zooms, "h", 14)]
        if rec:
            rows.append(panel(bee_strip(), "the lake's round bee: its fly loop and its rest pose"))
        body = stack(rows, "v", 14)
        opts.append(look.option_block("3" + label, name, cap, body, recommended=rec, width=SHEET_WIDE))
    return opts


# =============================================================================================
# 4. The honey coin: the honey's share of a catch paid at once, flying from the net to the purse
# on CoinFly's own arc (eased, ARC 56 canvas px over the straight line, 0.5 s), in the HUD's
# pixels (1 canvas px a pixel, 1.5 screen px). Plate 02_big_cast, a sweep's coins in the air
# at once. Drawn at one size the whole way, whole pixels (CoinFly scales its coin 12 -> 22 px,
# which no pixel art survives).
# =============================================================================================
COIN_FROM = (640, 236)        # the net's mouth on 02, canvas px
COIN_TO = (47, 110)           # the money plate's own coin (HudSkin.coin_centre), canvas px
COIN_ARC = 56.0
COIN_TS = (0.06, 0.22, 0.38, 0.54, 0.70, 0.86)
COIN_CROP = (0, 40, 1060, 480)


def arc_at(t, frm=COIN_FROM, to=COIN_TO, arc=COIN_ARC):
    e = 1.0 - (1.0 - t) * (1.0 - t)
    return (frm[0] + (to[0] - frm[0]) * e, frm[1] + (to[1] - frm[1]) * e - math.sin(t * math.pi) * arc)


def _coin_frame_of(turn):
    """CoinFly's turn (1 face .. 0 edge) to the sheet's frames 0..4."""
    return int(round((1.0 - turn) * 4))


def _drop_px(L, x, y, k, fade):
    """A trail drop: 2x3 then 2x2 then 1x1, the honey's mid with a lit top pixel."""
    a = int(255 * fade)
    mid = bh.HONEY_MID[:3] + (a,)
    lit = bh.HONEY_LIGHT[:3] + (a,)
    if k == 1:
        L.rect(x, y, 2, 3, mid)
        L.rect(x, y, 2, 1, lit)
    elif k == 2:
        L.rect(x, y, 2, 2, mid)
        L.px(x, y, lit)
    else:
        L.px(x, y, mid)


def coins_A(L, t, frm=COIN_FROM, to=COIN_TO):
    """The honey coin (struck by rule: a thick deep rim, an amber face, a comb cell for its
    stamp), spinning as it flies, a drop clinging to its trailing rim on the face frames, and
    three 2x2 drops trailing on the arc, fading in three hard steps."""
    for k in (3, 2, 1):
        back = t - 0.06 * k
        if back <= 0:
            continue
        x, y = arc_at(back, frm, to)
        d = hp.trail_drop(k - 1)
        L.paste(d, (int(round(x)) + 4 * k - 2, int(round(y + 3 * k)) - 2))
    x, y = arc_at(t, frm, to)
    turn = abs(math.cos(t * math.tau * 1.0))
    f = 0 if t > 0.9 else _coin_frame_of(turn)
    im = hp.honey_coin2(f)
    L.paste(im, (int(round(x)) - 12, int(round(y)) - 10))


def coins_B(L, t, frm=COIN_FROM, to=COIN_TO):
    """A drop of honey: round as it leaves, long along the arc in the air (turned whole quarter
    turns only), squashed as it lands; small drops thrown off behind."""
    x, y = arc_at(t, frm, to)
    x2, y2 = arc_at(min(t + 0.02, 1.0), frm, to)
    if t < 0.16:
        im = hp.honey_drop("round")
    elif t > 0.9:
        im = hp.honey_drop("squash")
    else:
        im = hp.honey_drop("long")
        if abs(x2 - x) > abs(y2 - y):
            im = look.turned(im, 1 if x2 < x else 3)   # its point trails behind
            im = look.flip(im) if False else im
    for k in (2, 1):
        back = t - 0.06 * k
        if back <= 0:
            continue
        bx, by = arc_at(back, frm, to)
        _drop_px(L, int(round(bx)), int(round(by + 3 * k)), k + 1, 1.0 - k / 3.0)
    L.paste(im, (int(round(x)) - im.width // 2, int(round(y)) - im.height // 2))


def coins_C(L, t, frm=COIN_FROM, to=COIN_TO, idx=0):
    """A bee bringing the coin home: the lake's own round bee (look.mini_round, side on, its
    wings flicking), a tiny honey coin hugged under it, bobbing a pixel off the arc."""
    x, y = arc_at(t, frm, to)
    y += round(1.5 * math.sin(t * 40 + idx))
    f = int(t * 30 + idx * 2) % 6
    im, mid = hp.courier(f, facing_left=True)
    L.paste(im, (int(round(x)) - mid[0], int(round(y)) - mid[1]))


COIN_SPEC = [
    ("A", "Honey coin", coins_A, True,
     "A coin of its own, struck by rule on the gold coin's nine widths: a thick HONEY_DEEP rim "
     "(lit on its top-left half), an amber face with a pale crescent and a shine pixel, and a "
     "comb cell for its stamp where the money's coin has the recycle arrows. It spins as the gold "
     "one does; a drop clings to its trailing (lower-right) rim on the face frames and is gone "
     "edge-on; three 2x2 drops trail on the arc, fading in three hard steps. Money by its shape, "
     "honey by its rim, stamp and drip, and apart from the purse's yellow coin side by side."),
    ("B", "Honey drop", coins_B, False,
     "No coin at all: a fat drop of honey (13 px, a shine pixel) that leaves round, stretches "
     "along the arc and lands squashed on the purse. The prettiest in flight, but it does not "
     "say money, and a stream of them reads as the purse being glazed rather than paid."),
    ("C", "Bee courier", coins_C, False,
     "The lake's own round bee flies each payment home, a tiny honey coin slung under it, "
     "bobbing off the arc. "
     "The cutest and it says where the money comes from, but twelve bees crossing the screen "
     "every sweep is a swarm on the HUD, and a bee has to fly back off it again."),
]


def coin_strip(key):
    bg = (40, 80, 77, 255)
    ims = []
    if key == "A":
        for f in range(9):
            ims.append(hp.honey_coin2(f))
        g = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        g.alpha_composite(hp.coin_frames()[0], (1, 0))
        ims.append(g)
        ims += [hp.trail_drop(k) for k in range(3)]
        labels = ["face"] + [""] * 3 + ["edge"] + [""] * 3 + ["back", "the purse's gold", "trail", "", ""]
    elif key == "B":
        ims = [hp.honey_drop("round"), hp.honey_drop("long"),
               look.turned(hp.honey_drop("long"), 1), hp.honey_drop("squash")]
        labels = ["leaves", "falls", "flies", "lands"]
    else:
        ims = [hp.courier(f)[0] for f in range(6)] + [hp.tiny_coin()]
        labels = ["wings up", "mid", "down", "bob", "", "", "the coin"]
    out = []
    for im, lab in zip(ims, labels):
        c = Image.new("RGBA", (im.width + 4, max(26, im.height + 4)), bg)
        c.alpha_composite(im, (2, (c.height - im.height) // 2))
        out.append(panel(zoom(c, 5), lab or " "))
    return stack(out, "h", 6)


def purse_pair():
    """The honey coin beside the purse's own gold coin at real scale (1.5 screen px a canvas px)
    and 4x: face, a quarter turn, edge-on, on the money plate's dark panel."""
    L = Layer(screen=(240, 48))
    L.rect(-PAD, -PAD, 240, 60, BOARD)
    for i, f in enumerate((0, 2, 4)):
        g = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        g.alpha_composite(hp.coin_frames()[f], (1, 0))
        L.paste(g, (4 + i * 26, 4))
        L.paste(hp.honey_coin2(f), (84 + i * 26, 4))
    real = L.screen()
    return stack([panel(real, "real scale: gold (left three), honey (right three)"),
                  panel(zoom(real, 3), "3x")], "v", 6)


def coins_on(plate, fn, ts=COIN_TS):
    L = Layer()
    for i, t in enumerate(ts):
        if fn is coins_C:
            fn(L, t, idx=i)
        else:
            fn(L, t)
    onto(plate, L)
    return plate


def coins_section():
    opts = []
    for label, name, fn, rec, cap in COIN_SPEC:
        im = coins_on(honeyed02(), fn)
        shown = im.copy()
        mid = [int(round(v * 1.5)) for v in arc_at(0.38)]
        zb1 = (mid[0] - 70, mid[1] - 50, mid[0] + 70, mid[1] + 50)
        z1 = look.crop_zoom(im, zb1, 4)
        z2 = look.crop_zoom(im, (24, 120, 210, 260), 3)
        ticks(shown, zb1)
        ticks(shown, (24, 120, 210, 260))
        parts = [panel(shown.crop(COIN_CROP), "real scale: a sweep's coins in the air, net (honeyed) to purse"),
                 stack([panel(z1, "4x: in the air"), panel(z2, "3x: arriving at the purse")], "v", 10),
                 panel(coin_strip(label), "5x: the frames")]
        if label == "A":
            parts.append(panel(purse_pair(), "against the purse's coin"))
        body = flow(parts, SHEET_WIDE, 14)
        opts.append(look.option_block("4" + label, name, cap, body, recommended=rec, width=SHEET_WIDE))
    return opts


# =============================================================================================
# 5. The first jar's hint: CueCard as a hint (scripts/cue_card.gd: TAB_HINT 34, PAD_HINT (10, 8),
# WIDE_HINT 236, TEXT_SMALL 13, CELL_HINT 2, lines evened out, the arrow off the plate's right
# edge because it is a top-left target), beside the jar plate (1A, idle, 3 jars), on 02. The
# card is drawn on the HUD's canvas pixels; the words are Bungee at screen resolution.
# =============================================================================================
CARD_TEXT = "Eat a *jar of honey*: your catch pays *50% more* for 15 seconds."
TAB_HINT = 34
PAD_HINT = (10, 8)
WIDE_HINT = 236
CARD_PX = 13
CELL_HINT = 2
CARD_RIM = 2
ARROW_GAP = 6
CARD_GAP = 14


def gcol(r, g, b):
    return cf(r, g, b)


def lightened(c, t):
    return tuple(int(round(c[i] + (255 - c[i]) * t)) for i in range(3)) + (255,)


def darkened(c, t):
    return tuple(int(round(c[i] * (1 - t))) for i in range(3)) + (255,)


THEMES = {
    "honey": {"band": cf(0.86, 0.50, 0.10), "mark": cf(1.0, 0.72, 0.36), "ink": cf(0.36, 0.14, 0.0),
              "icon": "jar"},
    "honey_jar": {"band": cf(0.78, 0.40, 0.06), "mark": cf(1.0, 0.70, 0.30), "ink": cf(0.34, 0.13, 0.0),
                  "icon": "jar_heap"},
    # the game's own honey_jar theme as built (cue_card.gd), for the side-by-side
    "honey_jar_built": {"band": cf(0.78, 0.40, 0.06), "mark": cf(1.0, 0.70, 0.30),
                        "ink": cf(0.34, 0.13, 0.0), "icon": "jar_open"},
    "honey_big": {"band": cf(0.86, 0.50, 0.10), "mark": cf(1.0, 0.72, 0.36), "ink": cf(0.36, 0.14, 0.0),
                  "icon": "jar_heap"},
    "comb": {"band": cf(0.90, 0.62, 0.14), "mark": cf(1.0, 0.78, 0.36), "ink": cf(0.34, 0.15, 0.0),
             "icon": "bee", "comb": True},
}
ICON_ROWS = {
    "jar": [".kkkkkkk.", ".kwpwpwk.", "kkkkkkkkk", "kpyyyyypk", "kpyoyyypk", "kpyyyyypk",
            "kpyyyoypk", "kpyyyyypk", ".kkkkkkk."],
    # The open jar, redrawn for this sheet: CueCard's jar_open runs its spill down the jar's
    # right side and back into the outline, which at a 2 px cell reads as a mug's handle. Here
    # the jar keeps the closed jar's silhouette and the honey is heaped up through its mouth,
    # a shine on the heap, the lid lifted off it.
    "jar_open": ["..kkkkk..", ".kyywyyk.", "kkyyyyykk", "kpyyyyypk", "kpyoyyypk", "kpyyyyypk",
                 "kpyyyoypk", "kpyyyyypk", ".kkkkkkk."],
    "jar_lid": [".kkkkkkk.", ".kwpwpwk."],
}


# The open jar redrawn off the bottling jar (build_hive jar2_parts): pale glass sides (lit left,
# blue-grey right), the glass empty at the top, amber honey in the bottom two thirds seen
# through it, a dome of honey heaped up out of the mouth with one shine pixel, one run down the
# front over the empty glass, and the gingham lid tilted and off to the right at the top of its
# hop. One icon px a cell (CELL_HINT canvas px).
JAR_ICON_KEY = {"O": cf(0.08, 0.06, 0.06), "G": bh.GLASS_EDGE, "g": (214, 234, 240, 255),
                "e": look.mix(bh.GLASS_EDGE, (255, 255, 255, 255), 0.45), "s": HONEY_SHINE,
                "L": HONEY_LIGHT, "H": HONEY, "M": HONEY_MID, "D": HONEY_DEEP,
                "R": GING_R, "W": GING_W, "P": GING_P, "t": TIE}
JAR_ICON_LID = ["......OOOO",
                "....OORWRO",
                "...ORWRWRO",
                "..OPRPRPOO",
                "..OttttO..",
                "..OOOOO..."]
JAR_ICON_BODY = ["...OOOOO...",
                 "..OsLLLHO..",
                 ".OLHHHHHMO.",
                 "OOgeeeeLeOO",
                 "OgeeeeeLeGO",
                 "OgeeeeeLMGO",
                 "OgLHHHHLMGO",
                 "OgLHHHHHMGO",
                 "OgLHHHHHMGO",
                 "OGMHHHHMDGO",
                 ".OGGGGGGGO.",
                 "..OOOOOOO.."]


def jar_icon(pop=2):
    """The open jar with its lid `pop` icon px over the top of the heap (2 at the top of the
    hop, 0 resting tilted on the heap). RGBA at one px a cell."""
    im = Image.new("RGBA", (13, 14 + len(JAR_ICON_LID)), (0, 0, 0, 0))
    top = len(JAR_ICON_LID)
    look.grid(JAR_ICON_BODY, JAR_ICON_KEY, 0, top + 2, into=im)
    look.grid(JAR_ICON_LID, JAR_ICON_KEY, 1 + (1 if pop else 0), 3 - pop, into=im)
    return im.crop(im.getbbox())


def letter_ink(ch, band):
    return {"k": cf(0.08, 0.06, 0.06), "w": cf(0.97, 0.97, 0.94), "p": PAPER, "y": cf(0.98, 0.78, 0.22),
            "o": cf(0.80, 0.50, 0.08), "d": darkened(band, 0.45), "l": lightened(band, 0.45)}[ch]


def draw_rows(L, rows, mid, cell, band):
    tall = len(rows)
    wide = max(len(r) for r in rows)
    ox = int(round(mid[0] - wide * cell * 0.5))
    oy = int(round(mid[1] - tall * cell * 0.5))
    for r, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            L.rect(ox + i * cell, oy + r * cell, cell, cell, letter_ink(ch, band))


def tokens(text):
    """CueCard.lay_out's units: words, `*marked*` runs inked, punctuation kept on its word."""
    out = []
    for word in text.split(" "):
        segs = []
        buf, marked = "", False
        for ch in word:
            if ch == "*":
                if buf:
                    segs.append((buf, marked))
                buf, marked = "", not marked
            else:
                buf += ch
        if buf:
            segs.append((buf, marked))
        out.append(segs)
    return out


def _carry_marks(text):
    # a marked run spanning words: carry the mark across spaces
    out, on = [], False
    for word in text.split(" "):
        w = ("*" if on and not word.startswith("*") else "") + word
        n = word.count("*")
        if n % 2 == 1:
            on = not on
        if on and not w.endswith("*"):
            w = w + "*"
        out.append(w)
    return " ".join(out)


def lay_out(text, px, wide):
    rows, row, row_w = [], [], 0.0
    space = text_width(" ", px)
    for segs in tokens(_carry_marks(text)):
        whole = sum(text_width(s, px) for s, _ in segs)
        lead = space if row else 0.0
        if row and row_w + lead + whole > wide:
            rows.append(row)
            row, row_w, lead = [], 0.0, 0.0
        for k, (s, m) in enumerate(segs):
            row.append({"text": s, "marked": m, "space": k == 0 and lead > 0})
        row_w += lead + whole
    if row:
        rows.append(row)
    return rows


def row_wide(row, px):
    return sum((text_width(" ", px) if u["space"] else 0) + text_width(u["text"], px) for u in row)


def swipe(L, box, ink, which):
    x, y, w, h = box
    for r in range(int(h // 2)):
        hsh = ((which * 73856093) ^ (r * 19349663) ^ 0x5bd1e995) & 0xFFFF
        left = (hsh % 3) - 1
        right = ((hsh >> 3) % 4) - 1
        x0 = x + left
        x1 = x + w + right
        L.rect(int(round(x0)), int(round(y + r * 2)), int(round(x1 - x0)), 2, ink)


def comb_tab(L, strip, band, clear):
    """Theme C's tab: a honeycomb pressed into the band (the swarm's stripes rule, in hexes)."""
    x0, y0, w, h = strip
    dark = darkened(band, 0.30)
    hexa = [".xx.", "x..x", "x..x", ".xx."]
    for r in range(-1, h // 4 + 2):
        for c in range(-1, w // 6 + 2):
            ox = x0 + c * 6 + (3 if r % 2 else 0)
            oy = y0 + r * 4
            for j, row in enumerate(hexa):
                for i, ch in enumerate(row):
                    xx, yy = ox + i, oy + j
                    if ch == "x" and x0 <= xx < x0 + w and y0 <= yy < y0 + h:
                        if not (clear[0] <= xx < clear[0] + clear[2] and clear[1] <= yy < clear[1] + clear[3]):
                            L.px(xx, yy, dark)


def _strand(L, x, top, reach, k, snap=False):
    """One honey strand from the card's top edge `top` up `reach` canvas px: 3 px wide at the
    foot (lit, honey, mid), 2 px over its middle, 1 px at the top, in hard steps, wobbling a px
    as it climbs, a 5x2 blob where it meets the card (it spreads into the rim). `snap`: parted
    two thirds of the way up, a bead hanging off the lower piece."""
    lit, mid, shade = HONEY_LIGHT, HONEY, HONEY_MID
    gap = (int(reach * 0.62), int(reach * 0.62) + 5) if snap else None
    for d in range(1, reach + 1):
        y = top - d
        if gap and gap[0] <= d < gap[1]:
            continue
        share = d / float(reach)
        wob = 1 if (0.4 < share < 0.75) == (k % 2 == 0) else 0   # one gentle kink
        if share < 0.45:
            L.px(x - 1 + wob, y, lit)
            L.px(x + wob, y, mid)
            L.px(x + 1 + wob, y, shade)
        elif share < 0.8:
            L.px(x + wob, y, lit)
            L.px(x + 1 + wob, y, shade)
        else:
            L.px(x + wob, y, mid)
    # the blob where it meets the card, over the rim
    L.rect(x - 2, top - 1, 5, 3, mid)
    L.rect(x - 1, top - 1, 3, 1, lit)
    if snap:
        # the lower piece ends in a bead, hanging
        by = top - gap[0] + 1
        L.rect(x - 1, by, 3, 3, mid)
        L.px(x - 1, by, lit)
        L.px(x + 1, by + 2, shade)


def cue_hint(plate, theme, target, text=CARD_TEXT, t=2.0, pose=(0, 0), fx=None, pop=0, fx_t=0.33,
             below=False, chip=False, big_icon=False):
    """Draw the hint card beside `target` (canvas box) on `plate` (or under it, the arrow
    pointing up, with `below`); returns its canvas box."""
    look_ = THEMES[theme]
    px = CARD_PX
    rows = lay_out(text, px, WIDE_HINT)
    if len(rows) > 1:
        narrow = WIDE_HINT
        while narrow > 80 and len(lay_out(text, px, narrow - 8)) == len(rows):
            narrow -= 8
        rows = lay_out(text, px, narrow)
    asc, desc = bungee(px * 100).getmetrics()
    ascent = asc / 100.0
    line_tall = round((asc + desc) / 100.0) + 2
    widest = max(row_wide(r, px) for r in rows)
    text_h = line_tall * len(rows) - 2
    tab = TAB_HINT
    cw = round(tab + PAD_HINT[0] * 2 + min(widest, WIDE_HINT))
    ch = round(max(text_h + PAD_HINT[1] * 2, tab))
    if chip:
        ch = max(ch, 62)
    tx, ty, tw, th = target
    if below:
        cx = int(tx) + pose[0]
        cy = int(ty + th + 16 * 2 + 30) + pose[1]       # the jar's lid clears the arrow
    else:
        reach = 16 * 2 + ARROW_GAP + CARD_GAP * 0.5
        cx = int(round(tx + tw + reach)) + pose[0]
        cy = int(round(ty + th * 0.5 - ch * 0.5)) + pose[1]
        cy = max(8, cy)
    L = Layer()
    band = look_["band"]
    L.rect(cx - CARD_RIM - 1, cy - CARD_RIM - 1, cw + 2 * (CARD_RIM + 1), ch + 2 * (CARD_RIM + 1), CARD_OUTER)
    L.rect(cx, cy, cw, ch, PAPER)
    L.rect(cx, cy, cw, 2, PAPER_EDGE); L.rect(cx, cy + ch - 2, cw, 2, PAPER_EDGE)
    L.rect(cx, cy, 2, ch, PAPER_EDGE); L.rect(cx + cw - 2, cy, 2, ch, PAPER_EDGE)
    strip = (cx, cy, tab, ch)
    L.rect(*strip, band)
    mid = (cx + tab * 0.5 - 1, cy + ch * 0.5)
    if look_.get("comb"):
        clear = (int(mid[0] - 11), int(mid[1] - 10), 22, 20)
        comb_tab(L, strip, band, clear)
    L.rect(cx, cy, tab, 2, lightened(band, 0.3))
    L.rect(cx + tab - 2, cy, 2, ch, darkened(band, 0.35))
    icon = look_["icon"]
    jobs = []
    late = []
    if icon == "jar":
        draw_rows(L, ICON_ROWS["jar"], mid, CELL_HINT, band)
    elif icon == "jar_open":
        body = ICON_ROWS["jar_open"]
        draw_rows(L, body, (mid[0], mid[1] + CELL_HINT), CELL_HINT, band)
        draw_rows(L, ICON_ROWS["jar_lid"],
                  (mid[0], mid[1] + (1.0 - (len(body) + 2) * 0.5 - pop) * CELL_HINT), CELL_HINT, band)
    elif icon == "jar_heap":
        im = jar_icon(pop)
        cell = CELL_HINT + (1 if big_icon else 0)
        big = im.resize((im.width * cell, im.height * cell), Image.NEAREST)
        if big_icon:
            # the jar breaks out of the tab: its lid and heap stand over the card's top edge
            # (drawn after the card's rim so it is in front of it), the key's chip under it
            late.append((big, (int(round(cx + tab * 0.5 - big.width * 0.5)), cy - 26)))
        else:
            L.paste(big, (int(round(mid[0] - big.width * 0.5)), int(round(mid[1] - big.height * 0.5))))
    elif icon == "bee":
        b = look.bee("A", 0, facing_left=False, pose="fly")
        b2 = b.resize((b.width * 2, b.height * 2), Image.NEAREST)
        ax, ay = look.bee_anchor("A", "fly", False, 0)
        L.paste(b2, (int(round(mid[0] - ax * 2)), int(round(mid[1] - ay * 2))))
    for im, at in late:
        L.paste(im, at)
    if chip:
        jobs.append(key_chip(L, None, int(cx + (tab - 20) // 2), cy + ch - 20 - 3, side=20))
    # the words
    inner = (cx + tab + PAD_HINT[0], cy, cw - tab - PAD_HINT[0] * 2, ch)
    y0 = inner[1] + (inner[3] - text_h) * 0.5
    which = 0
    for r, row in enumerate(rows):
        span = row_wide(row, px)
        x = math.floor(inner[0] + (inner[2] - span) * 0.5)
        base = math.floor(y0 + r * line_tall + ascent)
        at = x
        for u in row:
            if u["space"]:
                at += text_width(" ", px)
            w = text_width(u["text"], px)
            if u["marked"]:
                swipe(L, (at - 2, base - ascent * 0.48, w + 4, ascent * 0.48 + 3), look_["mark"], which)
                which += 1
            jobs.append(("label", u["text"], px, (at, base), look_["ink"] if u["marked"] else PAPER_INK))
            at += w
    # the arrow: the prompt's up arrow at 2x, pointing up at the plate's foot (below) or turned
    # to point left at its right edge
    arrow = glyph("arrow_up")
    if below:
        a2 = arrow.resize((32, 32), Image.NEAREST)
        L.paste(a2, (int(round(tx + A_MEDAL + 1 - 16)), int(round(ty + th + ARROW_GAP - 6))))
    else:
        a2 = arrow.resize((32, 32), Image.NEAREST).rotate(90, expand=True)
        tip = (tx + tw + ARROW_GAP, ty + th * 0.5)
        L.paste(a2, (int(round(tip[0])), int(round(tip[1] - 16))))
    if fx == "drip":
        # a teardrop gathering under the card's foot as it lands, on a thread
        foot = (int(cx + cw * 0.5 + cw * 0.21), cy + ch + CARD_RIM + 1)
        L.rect(foot[0], foot[1], 1, 3, HONEY)
        drop = hp.tear(hp.RAMP_HIVE)
        drop = drop.resize((drop.width * 2, drop.height * 2), Image.NEAREST)
        L.paste(drop, (foot[0] - 4, foot[1] + 2))
    elif fx == "ooze":
        # CueCard's ooze `fx_t` s into the entrance: the strands the card was lowered on, from
        # its top edge up out of sight; every one touches the card, the right one has snapped
        top = cy - CARD_RIM - 1
        for i in range(3):
            x = int(math.floor(cx + cw * 0.5 + (i - 1) * cw * 0.5 * 0.55))
            reach_ = int(round(64 * (0.75 + 0.12 * i)))
            _strand(L, x, top, reach_, i, snap=(i == 2))
    elif fx == "ooze_built":
        # the game's ooze as built (CueCard._draw_fx): straight strands 4 then 2 px wide
        top = cy - CARD_RIM - 1
        amber = cf(0.92, 0.56, 0.10, 0.95)
        for i in range(3):
            x = int(math.floor(cx + cw * 0.5 + (i - 1) * cw * 0.5 * 0.55))
            k = min(max(fx_t / (1.3 * (0.8 + 0.15 * i)), 0.0), 1.0)
            if k < 0.6:
                reach_ = int(round(70 * (1.0 - k / 0.6) * (0.75 + 0.12 * i)))
                thick = 4 if k < 0.25 else 2
                L.rect(x - thick // 2, top - reach_, thick, reach_, amber)
    elif fx == "buzz":
        for i in range(3):
            ang = 1.1 * (6 + i) + i * 2.1
            bx = cx + cw * 0.5 + math.cos(ang) * (cw * 0.5 + 14)
            by = cy + ch * 0.5 + math.sin(ang * 1.7) * (ch * 0.5 + 8)
            f = i * 2 % 6
            b = look.bee("A", f, facing_left=math.cos(ang) > 0, pose="fly")
            ax, ay = look.bee_anchor("A", "fly", math.cos(ang) > 0, f)
            L.paste(b, (int(bx) - ax, int(by) - ay))
    onto(plate, L)
    for j in jobs:
        if j[0] == "text":
            _, s_, size, at, ink, within = j
            stext(plate, s_, size, at, ink, align="center", within=within)
        else:
            stext(plate, j[1], j[2], j[3], j[4], shade=False)
    return (cx, cy, cw, ch)


CARD_SPEC = [
    # label, name, theme, fx, recommended, caption, layout
    ("A", "Hung under the plate", "honey_big", "drip", False,
     "A different shape of card: hung under the jar plate with the arrow pointing up at the "
     "medallion, the open jar drawn big and breaking out of the tab's top edge over the card's "
     "rim, the key's chip on the tab under it (so the card itself says which key eats), a "
     "teardrop gathering under the card's foot as it lands. The loudest of the three and it "
     "teaches the key; but it covers the lake under the HUD column, and a card below a target "
     "is not CueCard's rule for the top-left (beside, arrow pointing left).",
     dict(below=True, chip=True, big_icon=True)),
    ("B", "The open jar", "honey_jar", "ooze", True,
     "The game's honey_jar theme (deeper amber band, the ooze entrance), with the jar redrawn "
     "off the bottling jar: pale glass sides, the glass empty at the top and honey in its lower "
     "two thirds, a dome of honey heaped out of the mouth with one shine pixel and one run down "
     "the front, the gingham lid tilted off to the right at the top of its hop (every 1.6 s). The "
     "card is lowered on three strands of honey, each tapering in hard steps (3, 2, 1 px) as it "
     "climbs, wobbling a px, spreading into a blob where it meets the rim; the right one has "
     "snapped and hangs a bead. In the honey's family, plainly its own card, and the open jar "
     "says eat.", dict()),
    ("C", "Bee and comb", "comb", "buzz", False,
     "The honey band with a comb pressed into it (the swarm card's stripes, in hexes), the cute "
     "bee itself as the icon, wings beating, and three bees darting round the card as it buzzes "
     "in. The most charming, but it is the swarm card's language, so the player reads bees, not "
     "a jar to eat.", dict()),
]
JAR_TARGET = A_BOX


def cards_section():
    opts = []
    for label, name, theme, fx, rec, cap, lay in CARD_SPEC:
        base = draw_A(look.plate("big_cast"), IDLE)
        settled = base.copy()
        # settled: the lid resting tilted on the heap (it hops 2 icon px every 1.6 s)
        box = cue_hint(settled, theme, JAR_TARGET, pop=0, **lay)
        coming = base.copy()
        # coming in a third of a second into its entrance: ooze and drip lower it from above
        # (ooze: 64 px * e^(-5.5 t) = 10 px up), buzz slides it in from the right
        pose = (0, -10) if fx in ("drip", "ooze") else (12, 0)
        cue_hint(coming, theme, JAR_TARGET, pose=pose, fx=fx, **lay)
        shown = settled.copy()
        x0 = min(A_BOX[0], box[0]) - 6
        zb = (int(x0 * 1.5), int((min(A_BOX[1], box[1]) - 20) * 1.5),
              int((box[0] + box[2] + 12) * 1.5), int((box[1] + box[3] + 16) * 1.5))
        z = look.crop_zoom(settled, zb, 3)
        ticks(shown, zb)
        zc = look.crop_zoom(coming, (int((box[0] - 30) * 1.5), int((box[1] - 80) * 1.5),
                                     int((box[0] + box[2] + 30) * 1.5), int((box[1] + box[3] + 44) * 1.5)), 2)
        icon_z = None
        if THEMES[theme]["icon"] == "jar_heap":
            ic = jar_icon(3)
            bg = Image.new("RGBA", (ic.width + 4, ic.height + 4), THEMES[theme]["band"])
            bg.alpha_composite(ic, (2, 2))
            ic0 = jar_icon(0)
            bg0 = Image.new("RGBA", (ic0.width + 4, ic.height + 4), THEMES[theme]["band"])
            bg0.alpha_composite(ic0, (2, 2 + ic.height - ic0.height))
            icon_z = panel(stack([zoom(bg0, 8), zoom(bg, 8)], "h", 8), "8x: the icon, lid down and at the top of its hop")
        where = "under" if lay.get("below") else "beside"
        foot = min(1080, int((box[1] + box[3] + 24) * 1.5))
        parts = [panel(shown.crop((0, 0, 1000, max(470, foot))), "real scale: settled %s the jar plate" % where),
                 panel(z, "3x: settled"),
                 panel(zc, "2x: coming in (its flourish)")]
        if icon_z is not None:
            parts.append(icon_z)
        body = flow(parts, SHEET_WIDE, 14)
        opts.append(look.option_block("5" + label, name, cap, body, recommended=rec, width=SHEET_WIDE))
    return [callout_cards()] + opts


CALL_INK = (255, 214, 150, 255)


def callout(title, words, body=None):
    """A boxed note at the head of a section: what differs from the code already built."""
    t = look.text_block(title, SHEET_WIDE - 60, 22, "label", CALL_INK)
    w = look.text_block(words, SHEET_WIDE - 60, 18, "text", look.INK)
    inner = stack([t, w] + ([body] if body is not None else []), "v", 10)
    pad = 16
    out = Image.new("RGBA", (SHEET_WIDE, inner.height + pad * 2), (58, 40, 26, 255))
    d = ImageDraw.Draw(out)
    d.rectangle((0, 0, 9, out.height - 1), fill=(232, 150, 40, 255))
    d.rectangle((0, 0, out.width - 1, out.height - 1), outline=(232, 150, 40, 255), width=2)
    out.alpha_composite(inner, (30, pad))
    return out


def callout_cards():
    base = draw_A(look.plate("big_cast"), IDLE)
    built = base.copy()
    box = cue_hint(built, "honey_jar_built", JAR_TARGET, pop=0)
    built_c = base.copy()
    cue_hint(built_c, "honey_jar_built", JAR_TARGET, pose=(0, -10), fx="ooze_built")
    mine = base.copy()
    cue_hint(mine, "honey_jar", JAR_TARGET, pop=0)
    mine_c = base.copy()
    cue_hint(mine_c, "honey_jar", JAR_TARGET, pose=(0, -10), fx="ooze")
    zb = (int((box[0] - 4) * 1.5), int((box[1] - 6) * 1.5), int((box[0] + 60) * 1.5),
          int((box[1] + box[3] + 6) * 1.5))
    zbc = (int((box[0] - 10) * 1.5), int((box[1] - 80) * 1.5), int((box[0] + box[2] + 10) * 1.5),
           int((box[1] + box[3] * 0.4) * 1.5))
    row = stack([panel(look.crop_zoom(built, zb, 4), "built: jar_open"),
                 panel(look.crop_zoom(mine, zb, 4), "this sheet: the jar redrawn"),
                 panel(look.crop_zoom(built_c, zbc, 1), "built: the ooze (1x)"),
                 panel(look.crop_zoom(mine_c, zbc, 1), "this sheet: the ooze tapered (1x)")], "h", 14)
    return callout(
        "Differs from the code already built (Vigilance rule): Richard decides which is authoritative",
        "The other workflow has already built the honey_jar card into the game (scripts/cue_card.gd: "
        "the jar_open icon, its spill down the jar's right side, and the ooze as straight 4 px / 2 px "
        "strands). 5B keeps that theme's band, inks and entrance but redraws the icon and the "
        "strands. Side by side, at the card's real size (zoomed):", row)


# =============================================================================================
# 0. The recommended picks together on one store still (02_big_cast, mid-haul, half the honey
# window gone): the jar plate (1A) draining, the net honeyed with drips (2A), the bees round the
# angler (3C), the honey coins flying from the net to the purse (4A). The first-jar hint (5B)
# comes earlier, before the first jar is eaten, so it is shown on its own in section 5.
# =============================================================================================
NET02_BOX = (760, 250, 1160, 486)
NET02_PHASE = (1, 0)
NOW = {"jars": 2, "share": 0.55, "pad": False}


def open_below(beads, masks, most=0.2, reach=18):
    """The beads with open water under them: mid-haul the bag sags below its near rim, and a drop
    falling over the mesh is lost in it, so the drips hang where the net leaves the water clear."""
    net = masks["net"]
    out = []
    for b in beads:
        sx, sy = int(b[0]), int(b[1])
        col = net[sy + 2:sy + reach, sx - 1:sx + 2]
        if col.size and col.mean() <= most:
            out.append(b)
    return out


TOGETHER_DRIPS = [3, 2, 4, 1, 3, 5, 2]


def honeyed02():
    """02_big_cast in honey time: the net's rim and beads in 2A's honey, five teardrops off its
    near rim over open water."""
    im = look.plate("big_cast")
    masks = hrc.recolour(im, NET02_BOX, hp.RAMP_HIVE)
    tears_on(im, masks, NET02_BOX, hp.RAMP_HIVE, NET02_PHASE, n=5, keep_share=0.5)
    return im


def together():
    im = honeyed02()
    mask = hp.angler_mask(look.plate("big_cast"), ANGLER02_BOX)
    bee_layers(im, "C", "full", mask=mask)
    draw_A(im, NOW)
    coins_on(im, coins_A, ts=(0.10, 0.27, 0.44, 0.61, 0.78, 0.93))
    return im


def together_section():
    im = together()
    shown = im.copy()
    boxes = [((10, 10, 360, 320), 2, "2x: the jar plate, half the window gone, honey coins arriving"),
             ((800, 400, 1160, 520), 3, "3x: the net's near rim, honeyed, dripping"),
             ((892, 540, 1036, 672), 3, "3x: the bees round him")]
    zs = []
    for box, k, cap in boxes:
        zs.append((look.crop_zoom(im, box, k), cap))
        ticks(shown, box)
    body = stack([panel(im, "real scale: the whole window (1920 x 1080), the recommended picks at once"),
                  panel(shown, "the same, the zooms' areas ticked"),
                  flow([panel(z, cap) for z, cap in zs], SHEET_WIDE, 14)], "v", 14)
    return [look.option_block("0", "Honey time, all at once",
                              "The picks below laid on one capture: 1A the third slab draining under "
                              "the purse, 2A the honeyed net dripping into the lake, 3C the bees "
                              "escorting the angler, 4A the honey coins on their way to the purse. "
                              "Everything else on the plate is the game as captured.",
                              body, recommended=False, width=SHEET_WIDE)]


SECTIONS = {"all": together_section, "plates": plates_section, "net": net_section,
            "bees": bees_section, "coins": coins_section, "cards": cards_section}
HEADS = {
    "all": ("0  Together", "the recommended picks on one capture"),
    "plates": ("1  The jar plate", "where the jars live on the HUD, idle and with the window running"),
    "net": ("2  The net in honey time", "beside the lucky cast's gold net, on the capture of a lucky double cast"),
    "bees": ("3  Bees round the angler", "full, half and nearly out"),
    "coins": ("4  The honey coin", "the honey's share of a catch, flying from the net to the purse"),
    "cards": ("5  The first jar's hint", "CueCard, honey-themed, beside the jar plate"),
}
SUBTITLE = (
    "Richard's decisions (grilled 2026-10-16): a jar of honey is eaten from a HUD jar plate shown "
    "only while jars are held; for 15 s every piece the net catches pays +50% at once as amber "
    "honey coins; the net's rim cord and lead beads go amber and drip; bees orbit the angler, "
    "thinning as the time runs out. Every plate is a real capture (the store stills 02_big_cast and "
    "05_gold_double), and everything drawn on one sits on that plate's own lattice: the HUD at one "
    "canvas px a pixel (1.5 screen px), the lake at one world px a pixel (1.5 screen px). Pink "
    "corner ticks mark where a zoom was cut (outside the thing judged). Recommended picks are tagged.")
NOTES = (
    "Colours: the hive's honey (build_hive HONEY_DEEP..HONEY_SHINE) is the one honey: the net's rim "
    "(2A), the jar on the plate, the coin (4A, struck by rule: a HONEY_DEEP rim, an amber face, a "
    "comb-cell stamp) and the drips; deep and shade tones are that honey mixed towards the outline "
    "(24, 18, 17). The HUD's wood is Style._build_border ported (Meter_Border.png, its bites and "
    "Godot's hash); the card's colours are CueCard's own (THEMES); every lake bee is look.py's "
    "round mini bee (look.mini_round, added for this review: a 6x5 oval in the outline; the older "
    "look.mini_bee is unchanged and other sheets still draw it), the card's bee is look.bee. Rings "
    "on the water are the splash foam's 2 world px cells. Option 2B's ramp is NetShape's AMBER_* "
    "as built. Script: tools/hive_look/honey_mockup.py (helpers honey_parts.py, honey_recolor.py, "
    "honey_net.py, look.py); run it from the project root with the psd-extract site-packages on "
    "PYTHONPATH; `python tools/hive_look/honey_mockup.py net` builds one section.")


def section_head(title, sub):
    return look.stack([look.text_block(title, SHEET_WIDE, 34, "label", look.INK),
                       look.text_block(sub, SHEET_WIDE, 20, "text", look.INK_SOFT)], "v", 2)


def main(which):
    blocks = []
    for k in which:
        if len(which) > 1 and k != "all":
            blocks.append(section_head(*HEADS[k]))
        blocks += SECTIONS[k]()
    look.sheet("Honey time: the boost on the lake", blocks, OUT_PATH, subtitle=SUBTITLE, notes=NOTES)
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main(sys.argv[1:] or list(SECTIONS))

#!/usr/bin/env python
"""The island sheet (2026-10-16, the hive overhaul): the hive on the island's lawn, 1.4x, with
its jars legible one by one. Three arrangements: A the honey hutch (a roofed sky-blue cabinet
behind-left, three shelves of four; recommended), B the honey table (front-left, a 4 x 3 lattice
on its top), C jars in the stand (the hive's stand a cupboard, three a shelf on each seen face).
Four states each (weathered and empty, the swarm on its shrub, colony busy, honey ready) and a
jar ladder of 0 / 3 / 6 / 12.

OFFLINE MOCKUP ONLY. Writes tools/hive_look/last_island.png. Nothing here is read by the game.

Every scene is drawn on the real capture (tools/last_hive_busy.png, the 720x480 island crop:
two plate px a world px, lattice on even px from (0, 0)) after the old hive, its shelf, the
shrub, the swarm, the old bees and the pigeon are taken off it and the lawn and sand laid back
(`clean_plate`). Everything new is drawn at ONE world px an art px (the hut's, the angler's,
the pack plants' grain), inked in the game's (24,18,17), day-tinted like the capture, its
shadow swept down-left off its own silhouette in the land ink measured off the capture, and
blown up 2x nearest onto the plate's lattice.

The bees are look.py's (variant A, the coin bee): `look.mini_bee` and `look.mini_swarm` on the
island. The hive keeps its sky-blue paint (build_hive PAINTS["sky"]) and coral roof (ROOF).

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/island_mockup.py
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
from look import zoom, panel, stack, flow  # noqa: E402

bh = look.bh
G = look.ISLAND_GRAIN            # 2 plate px a world px
OUT = look.OUT
SW = look.SW
BEE = "A"                        # the picked bee (look.py, "coin")
OUT_PATH = os.path.join(look.HERE, "last_island.png")
RECOMMEND = "A"
SHEET_WIDE = 2760

# =============================================================================================
# The plate: the busy capture with the old hive taken off
# =============================================================================================
BASE = "busy"
OLD_PIC_AT = (278, 176)          # plate px of the old picture's top-left (matched pixel for pixel)
OLD_FOOT = (398, 280)            # plate px of its foot (the node's origin)
# The lawn's top edge against the sand, plate px, measured column by column off the capture
# (where nothing stands on it) and joined straight under the old shrub.
EDGE = [(150, 262), (180, 240), (200, 228), (220, 212), (240, 200), (260, 188), (280, 184),
        (360, 160), (380, 156), (400, 152), (420, 144), (440, 140), (460, 136), (500, 128),
        (540, 120), (600, 108)]
LAWN_SRC = (360, 330, 500, 440)  # clean, unshaded lawn to lay back
NEAR_EDGE = 14                   # plate px under the edge still copied along the edge
ALONG = 120                      # plate px the near-edge copy is taken from, along the edge
PIGEON = (362, 80, 414, 122)
SHRUB_OLD = (282, 126, 352, 188)
SWARM_OLD = (320, 154, 372, 212)
ANGLER_BOX = (444, 196, 514, 324)

LAWN_SUN = [(74, 106, 45), (49, 85, 28), (60, 95, 36), (107, 133, 63), (168, 186, 102)]
LAND_INK = (13, 20, 23)          # the shadow's ink on the lawn, solved off the capture
LAND_A = 0.36                    # ... and how far it mixes: (74,106,45) -> (52,75,37)
LAWN_SHADE = [tuple(int(round(c * (1 - LAND_A) + i * LAND_A)) for c, i in zip(p, LAND_INK))
              for p in LAWN_SUN]
DAY = (217 / 220, 96 / 98, 70 / 72)   # the capture's day tint (the hive roof's coral measured)


def edge_y(x):
    pts = EDGE
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return pts[-1][1]


def _lawnish(p):
    t = tuple(int(v) for v in p[:3])
    return any(sum(abs(t[i] - q[i]) for i in range(3)) < 8 for q in LAWN_SUN + LAWN_SHADE)


def angler_mask(a):
    """The angler's own pixels in the capture: anything in his box that is not lawn."""
    m = np.zeros(a.shape[:2], bool)
    x0, y0, x1, y1 = ANGLER_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not _lawnish(a[y, x]):
                m[y, x] = True
    return m


def _old_picture_mask(shape):
    j = json.load(open(os.path.join(look.ROOT, "assets/hive.json")))
    sheet = Image.open(os.path.join(look.ROOT, "assets/hive.png")).convert("RGBA")
    w, h = j["size"]
    acc = Image.new("L", (w, h), 0)
    for name, (x, y, fw, fh) in j["frames"].items():
        acc = Image.fromarray(np.maximum(np.array(acc), np.array(
            sheet.crop((x, y, x + fw, y + fh)).getchannel("A"))))
    big = acc.resize((w * G, h * G), Image.NEAREST).point(lambda v: 255 if v > 0 else 0)
    full = Image.new("L", (shape[1], shape[0]), 0)
    full.paste(big, OLD_PIC_AT)
    full = full.filter(ImageFilter.MaxFilter(13))
    return np.array(full) > 0


def clean_plate(name=BASE):
    """The capture with the old hive, shelf, shrub, swarm, bees and pigeon taken off, the lawn and
    the sand laid back on the plate's own lattice."""
    base = look.plate(name)
    a = np.array(base)
    ang = angler_mask(a)
    m = _old_picture_mask(a.shape)
    # the old shadows: shaded lawn round and under the old picture
    shade_cls = np.zeros(a.shape[:2], bool)
    for y in range(170, 336):
        for x in range(262, 452):
            t = tuple(int(v) for v in a[y, x, :3])
            if any(sum(abs(t[i] - q[i]) for i in range(3)) < 8 for q in LAWN_SHADE):
                shade_cls[y, x] = True
    shade_img = Image.fromarray((shade_cls * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    m |= np.array(shade_img) > 0
    for x0, y0, x1, y1 in (SHRUB_OLD, SWARM_OLD, PIGEON):
        m[y0:y1, x0:x1] = True
    m &= ~ang
    src = a.copy()
    out = a.copy()
    H, W = m.shape
    for y in range(0, H, G):
        for x in range(0, W, G):
            if not m[y:y + G, x:x + G].any():
                continue
            ey = edge_y(x)
            if y < ey + NEAR_EDGE:
                sx = x + ALONG
                sy = y + int(round((edge_y(sx) - ey) / G)) * G
                k = 0
                while (sy < 0 or sy >= H or m[sy, sx]) and k < 6:
                    sx += 2 * G
                    sy = y + int(round((edge_y(sx) - ey) / G)) * G
                    k += 1
            else:
                lx0, ly0, lx1, ly1 = LAWN_SRC
                sx = lx0 + (x - lx0) % (lx1 - lx0)
                sy = ly0 + (y - ly0) % (ly1 - ly0)
            out[y:y + G, x:x + G] = src[sy:sy + G, sx:sx + G]
    img = Image.fromarray(out)
    bee_old = {(242, 201, 70), (45, 32, 15), (244, 184, 40)}
    _clean_cells(img, bee_old, ang)
    return img


def _clean_cells(img, colours, keep):
    """Today's island bees off the plate: a cell of a bee colour (or the pale wing over it) takes
    its nearest clean neighbour in its own row."""
    a = np.array(img)
    H, W = a.shape[:2]
    rows, cols = H // G, W // G
    cells = a[G // 2::G, G // 2::G, :3].astype(int)
    bad = np.zeros((rows, cols), bool)
    for r in range(rows):
        for c in range(cols):
            if keep[r * G, c * G]:
                continue
            p = tuple(cells[r, c])
            if any(sum(abs(p[i] - q[i]) for i in range(3)) < 12 for q in colours):
                bad[r, c] = True
    for r in range(rows):
        for c in range(cols):
            if not bad[r, c]:
                continue
            for k in range(1, 8):
                q = None
                for cc in (c - k, c + k):
                    if 0 <= cc < cols and not bad[r, cc] and not keep[r * G, cc * G]:
                        q = cells[r, cc]
                        break
                if q is not None:
                    a[r * G:(r + 1) * G, c * G:(c + 1) * G, :3] = q
                    break
    img.paste(Image.fromarray(a))
    return img


# =============================================================================================
# Colours: every one already in the game's art
# =============================================================================================
SKY = bh.PAINTS["sky"]           # the hive's paint, lit / base / shade / deep (assets/hive.png)
GREY = bh.WEATHERED              # the weathered hive's boards
ROOF, ROOF_OLD = bh.ROOF, bh.ROOF_OLD
TRIM, TRIM_SHADE = bh.TRIM, bh.TRIM_SHADE
SLOT = (40, 26, 18, 255)         # the entrance slot (build_hive)
DARK_GLASS = bh.DARK_GLASS
H_DEEP, H_MID, H_, H_LIGHT, H_SHINE = (bh.HONEY_DEEP, bh.HONEY_MID, bh.HONEY, bh.HONEY_LIGHT,
                                       bh.HONEY_SHINE)
LEAF, BARK, BLOSSOM = bh.LEAF, bh.BARK, bh.BLOSSOM
VENT = (60, 40, 28, 255)
WEB = (235, 235, 230, 255)
mix = look.mix


def oak(t, old=False):
    return bh.oak(t, old)


def paint_of(old):
    return GREY if old else SKY


# =============================================================================================
# The jar: the room's bottling jar in miniature, 7x9 with its outline. A gingham lid (the room
# jar's own red and white, build_hive GINGHAM_*), a straight honey body lit from the right with
# a shine at its shoulder, the cream label band. Squarer than a cap on a stalk: the first cut,
# a coral cloth wider than the body, read as a row of mushrooms. One a slot, a pixel apart.
# =============================================================================================
JAR = [
    ".OOOOO.",
    "OwrwrwO",
    "OrwrwrO",
    ".OOOOO.",
    "OMHHLSO",
    "OMCCCLO",
    "OMHHHLO",
    "ODMMMHO",
    ".OOOOO.",
]
JAR_KEY = {"O": OUT, "w": bh.GINGHAM_WHITE, "r": bh.GINGHAM_RED, "H": H_, "L": H_LIGHT,
           "S": H_SHINE, "D": H_DEEP, "M": H_MID, "C": bh.CREAM}
JAR_W, JAR_H = 7, 9
JAR_PITCH = 8


def jar(shade=0.0):
    im = look.grid(JAR, JAR_KEY)
    return look.tinted(im, OUT, shade) if shade else im


# =============================================================================================
# The hive, 1.4x: the room's hive seen from the island (flared lifts, a stand, a coral gable
# roof with cream trim), corner-on, the lit face on the right.
# =============================================================================================
class Hive14:
    """Geometry of the 1.4x island hive in its own canvas, before inking. Walls +-22 (was 16),
    stand and eaves +-28 (was 20), ridge 20 high (was 14), walls 34 (was 24)."""

    def __init__(self, lifts=(18, 8, 8), stand="legs", cx=31, yt=15):
        self.cx, self.yt, self.lifts = cx, yt, lifts
        self.stand = stand
        self.H = sum(lifts)
        self.c = yt + 11 + self.H                   # the walls' foot at the side corners
        self.box = 26 if stand == "shelves" else 4  # the stand's own height under its top
        self.legs = 3 if stand == "shelves" else 6
        self.origin = (cx, self.c + self.box + self.legs)   # ground under the footprint's middle
        self.w = 2 * cx + 2
        self.h = self.c + 14 + self.box + self.legs + 1
        self.rL, self.rT = (cx - 28, yt + 14), (cx, yt)
        self.rR, self.rB = (cx + 28, yt + 14), (cx, yt + 28)
        self.A = (cx - 14, yt - 13)
        self.Bp = (cx + 14, yt + 1)

    def wall_top(self, x):
        cx = self.cx
        d = (x - cx) if x >= cx else (cx - x)
        return self.yt + 22 - d // 2

    def lift_of(self, r):
        a0 = 0
        for i, n in enumerate(self.lifts):
            if r < a0 + n:
                return i, a0, a0 + n
            a0 += n
        return len(self.lifts) - 1, a0 - self.lifts[-1], a0

    def entrance(self):
        """The landing board's middle, in the inked picture (+1 for the ink)."""
        x = self.cx + 11
        return (x + 1, self.wall_top(x) + self.H + 1)

    def board(self, d):
        """The landing board's top row d columns past the front corner, in the inked picture."""
        x = self.cx + d
        return (x + 1, self.wall_top(x) + self.H - 1 + 1)

    def slot_top(self, d):
        x = self.cx + d
        return self.wall_top(x) + self.H - 3 + 1

    def ledge(self):
        """The stand's top just in front of the walls' front corner (inked picture)."""
        return (self.cx + 1, self.c + 12 + 1)

    def ready_at(self):
        """Where the ready mark's middle hangs, over the ridge, in the inked picture."""
        return ((self.A[0] + self.Bp[0]) // 2 + 1, self.A[1] - 8 + 1)


def _bounds(lifts):
    out, a0 = [], 0
    for n in lifts:
        out.append((a0, a0 + n))
        a0 += n
    return out


def _shingles(a, poly, roof, old, rng, A):
    def shingle(x, y):
        d = y - (A[1] + 0.5 * (x - A[0]))
        if d < 2:
            return roof["lit"]
        if d < 3:
            return roof["base"]
        row, pr = int((d - 3) // 4), (d - 3) % 4
        if old and rng.random() < 0.06:
            return roof["deep"]
        if pr < 1:
            return roof["shade"]
        if int(x + (row % 2) * 3) % 6 == 0:
            return roof["shade"]
        if pr < 2:
            return roof["lit"]
        return roof["base"]
    a.fill_by(poly, shingle)


SLOT_FROM, SLOT_TO = 4, 18         # the entrance slot's columns off the hive's front corner


def draw_hive(state="colony", share=0.5, stand="legs", jars=0, drip=False, drip_long=5):
    """The 1.4x island hive at one world px an art px, inked. state: 'weathered' (the old empty
    box), 'colony' (honey window at `share`), 'full'. stand 'legs' (a stand on legs, like
    today) or 'shelves' (option C: the stand is a painted cupboard, two shelves on each seen
    face, three jars a shelf). Returns (image, geometry)."""
    old = state == "weathered"
    lifts = (18, 8) if stand == "shelves" else (18, 8, 8)
    g = Hive14(lifts=lifts, stand=stand)
    a = bh.Art(g.w, g.h)
    lit, base, shade, deep = paint_of(old)
    roof = ROOF_OLD if old else ROOF
    rng = random.Random(11)
    cx, yt, c, H = g.cx, g.yt, g.c, g.H

    # --- the stand ---------------------------------------------------------------------------
    st, sl, sb, sr = (cx, c - 14), (cx - 28, c), (cx, c + 14), (cx + 28, c)
    if stand == "shelves":
        _shelf_stand(a, g, jars, old)
    else:
        a.poly([sl, sb, (sb[0], sb[1] + 4), (sl[0], sl[1] + 4)], oak(1, old))
        a.poly([sb, sr, (sr[0], sr[1] + 4), (sb[0], sb[1] + 4)], oak(3, old))
        for lx, ly in ((sl[0] + 2, sl[1] + 4), (sb[0] - 1, sb[1] + 4), (sr[0] - 3, sr[1] + 4)):
            a.rect(lx, ly, 1, g.legs, oak(0, old))
            a.rect(lx + 1, ly, 1, g.legs, oak(2, old))
    a.fill_by([sl, st, sr, sb], lambda x, y: oak(4 if int(y - (x - cx) * 0.5) % 4 else 3, old))
    for x in range(sl[0], sr[0] + 1):
        a.px(x, sb[1] - abs(x - cx) // 2, oak(5, old))

    # --- the walls: flared lifts -------------------------------------------------------------
    for x in range(cx - 23, cx + 24):
        left = x < cx
        body = shade if left else base
        grain = mix(shade, deep, 0.3) if left else mix(base, shade, 0.35)
        top = g.wall_top(x)
        for r in range(H):
            i, a0, b0 = g.lift_of(r)
            wide = abs(x - cx) >= 23
            if wide and r < b0 - 2:
                continue
            if r == b0 - 1:
                col = deep
            elif r == b0 - 2:
                col = mix(shade, lit, 0.45) if left else lit
            elif r == a0 and i > 0:
                col = mix(body, deep, 0.5)
            elif x == cx:
                col = lit
            elif x == cx - 1:
                col = mix(shade, lit, 0.25)
            elif (r - a0) % 4 == 3 and (x * 3 + r) % 7:
                col = grain
            else:
                col = body
            a.px(x, top + r, col)
    # handholds: a dark slot with a lit lip in the middle of every lift, but where the window is
    for i, (a0, b0) in enumerate(_bounds(g.lifts)):
        k = a0 + (b0 - a0) // 2 - 1
        for x in range(cx - 15, cx - 8):
            y = g.wall_top(x) + k
            a.px(x, y, deep)
            a.px(x, y + 1, mix(shade, lit, 0.45))
        if i == 0 or (i == len(g.lifts) - 1 and len(g.lifts) > 2):
            continue                         # the window's lift, and the entrance's
        for x in range(cx + 9, cx + 16):
            y = g.wall_top(x) + k
            a.px(x, y, deep)
            a.px(x, y + 1, lit)
    # the entrance slot along the foot of the lit face, the landing board under it: a lit lip
    # row (the board's front edge catching the sun), then the board's top and its shaded front.
    # The slot runs SLOT_FROM..SLOT_TO; nothing is drawn standing in its middle.
    for x in range(cx + SLOT_FROM - 1, cx + SLOT_TO + 2):
        y = g.wall_top(x) + H
        inside = cx + SLOT_FROM <= x <= cx + SLOT_TO
        if inside:
            a.px(x, y - 3, SLOT)
            a.px(x, y - 2, SLOT)
        a.px(x, y - 1, mix(oak(6, old), TRIM, 0.55) if not old else GREY[0])
        a.px(x, y, oak(5, old))
        a.px(x, y + 1, oak(4, old))
        a.px(x, y + 2, oak(2, old))
        a.px(x, y + 3, oak(1, old))
    _window(a, g, state, share, old)
    if drip:
        dx = cx + 13
        lip = g.wall_top(dx) + H + 3
        for k in range(1, drip_long + 1):
            a.px(dx, lip + k, H_)
            a.px(dx + 1, lip + k, H_LIGHT if k < drip_long - 1 else H_)
        a.rect(dx - 1, lip + drip_long + 1, 3, 2, H_)
        a.px(dx + 1, lip + drip_long + 1, H_SHINE)
    if old:
        _weather_walls(a, g, rng)

    # --- the roof ----------------------------------------------------------------------------
    rL, rR, rB, A, Bp = g.rL, g.rR, g.rB, g.A, g.Bp
    _shingles(a, [rL, rB, Bp, A], roof, old, rng, A)
    # the eave: the roof's deep edge and a cream fascia under it (the room hive's trim)
    for x in range(rL[0], rB[0] + 1):
        y = rL[1] + (x - rL[0]) * 0.5
        a.px(x, y, roof["deep"])
        a.px(x, y + 1, TRIM_SHADE if not old else GREY[1])
    # the gable end, lit, in boards, with a heart cut in it (the hut's shutters' heart)
    a.fill_by([rB, rR, Bp],
              lambda x, y: mix(lit, base, 0.4) if int(y + (x - cx) * 0.5) % 3 == 0 else lit)
    for x in range(int(rB[0]), int(Bp[0]) + 1):
        y = rB[1] - (x - rB[0]) * (rB[1] - Bp[1]) / (Bp[0] - rB[0]) - 0.5
        a.px(x, y, TRIM if not old else GREY[0])
        a.px(x + 1, y, TRIM_SHADE if not old else GREY[1])
    hx, hy = cx + 14, yt + 11
    for dx, dy in ((0, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
        a.px(hx - 1 + dx, hy + dy, VENT)
    if old:
        _weather_roof(a, g, rng)
    im = bh.inked(a.im)
    if old:
        _cobweb(im, (g.rL[0] + 4, g.rL[1] + 4))
    return im, g


WIN_FROM = 8                       # the honey window's first column off the front corner
WIN_LEVELS = 4                     # honey rises in four stepped levels of two rows


def win_level(state, share):
    if state == "weathered":
        return 0
    if state == "full":
        return WIN_LEVELS
    return max(1, min(WIN_LEVELS - 1, int(round(share * WIN_LEVELS))))


def _comb(c, r):
    """A faint honeycomb behind the glass: a hex lattice in 4 x 6 cells (face columns, rows)."""
    band, rr = divmod(r, 3)
    cc = (c + band * 2) % 4
    return (rr == 0 and cc in (1, 2)) or (rr != 0 and cc == 0)


def _window(a, g, state, share, old):
    """The honey window: a tall inked pane on the top lift's lit face, 8 x 11 with its frame
    (ink, cream trim lit top-left and shaded bottom-right, a 4 x 8 pane). Behind the glass a
    faint comb; honey rises from the foot in WIN_LEVELS steps of two rows, its top row a pale
    meniscus, so the level IS the progress bar. Full, a white glint at the top corner. Rows are
    counted down the face (each column dropped by the face's slope), so it sits in the wall."""
    cx = g.cx
    x0 = cx + WIN_FROM
    top_r = 6                      # the gable hides the lift's first six rows
    rows = 8
    level = win_level(state, share)
    filled = level * 2
    for c in range(8):
        x = x0 + c
        wt = g.wall_top(x)
        for k in range(rows + 4):
            r = top_r + k
            if k == 0 or k == rows + 3 or c in (0, 7):
                col = OUT
            elif k == 1 or c == 1:
                col = TRIM if not old else GREY[0]
            elif k == rows + 2 or c == 6:
                col = TRIM_SHADE if not old else GREY[1]
            else:
                kk = k - 2                         # 0 at the pane's top
                cc = c - 2
                depth = rows - 1 - kk              # 0 at the pane's foot
                if depth < filled:
                    if depth == filled - 1:
                        col = H_SHINE if level == WIN_LEVELS else H_LIGHT
                    else:
                        col = H_MID if _comb(cc, kk) else (H_ if depth > 1 else H_MID)
                else:
                    col = mix(DARK_GLASS, H_DEEP, 0.45) if _comb(cc, kk) else DARK_GLASS
                    if old:
                        col = mix(col, GREY[3], 0.5)
            a.px(x, wt + r, col)
    if level == WIN_LEVELS:              # the glint: a pane full of honey catching the sun
        a.px(x0 + 5, g.wall_top(x0 + 5) + top_r + 3, SW["foam_light"])
        a.px(x0 + 4, g.wall_top(x0 + 4) + top_r + 2, SW["foam_light"])
    elif not old:                        # an empty pane still catches a little light
        a.px(x0 + 5, g.wall_top(x0 + 5) + top_r + 2, mix(DARK_GLASS, TRIM, 0.45))


def _on(a, x, y, c):
    """Paint only on what is already drawn: weathering never leaks off the picture."""
    x, y = int(round(x)), int(round(y))
    if 0 <= x < a.w and 0 <= y < a.h and a.im.getpixel((x, y))[3]:
        a.px(x, y, c)


CHIPS = ([(0, 0), (1, 0)], [(0, 0), (1, 0), (0, 1), (1, 1)], [(0, 0), (1, 0), (2, 0)],
         [(0, 0), (1, 0), (1, 1)], [(0, 0), (0, 1), (1, 1), (2, 1)], [(0, 0), (1, 0), (2, 0), (1, 1)])


def chip_patches(rng, n, xs, rows, at, paint, lit=None):
    """Old paint hanging on in 2-4 px patches (not single specks): n patches, each a shape from
    CHIPS at a column from `xs` and a row from `rows` (seams and edges), drawn through
    `at(x, r, colour)`. The patch's top-left pixel takes `lit` if given."""
    for _ in range(n):
        x0, r0 = rng.choice(xs), rng.choice(rows)
        for k, (dx, dy) in enumerate(rng.choice(CHIPS)):
            at(x0 + dx, r0 + dy, lit if (lit and k == 0) else paint)


def _weather_walls(a, g, rng):
    cx = g.cx
    seams = []
    for a0, b0 in _bounds(g.lifts):
        seams += [a0, a0 + 1, b0 - 3, b0 - 2]
        seams += [r for r in range(a0 + 3, b0 - 3) if (r - a0) % 4 == 2]
    seams = [r for r in seams if r >= 6]
    on = lambda x, r, c: _on(a, x, g.wall_top(x) + r, c)
    chip_patches(rng, 11, list(range(cx - 21, cx - 2)), seams, on, SKY[2], SKY[1])
    chip_patches(rng, 10, [x for x in range(cx + 2, cx + 20)
                           if not (cx + WIN_FROM - 1 <= x <= cx + WIN_FROM + 8)], seams, on,
                 SKY[1], SKY[0])
    for k in range(7):                       # a split down one board
        x = cx + 4 + (k % 2)
        a.px(x, g.wall_top(x) + 20 + k, GREY[3])
    for x in range(cx - 13, cx - 7):         # a board gone at the foot of the shaded face
        y = g.wall_top(x) + g.H - 6
        a.px(x, y, OUT)
        a.px(x, y + 1, OUT)
    for x in range(cx - 27, cx + 27):        # moss up the stand's edge
        if rng.random() < 0.3:
            y = g.c + 14 - abs(x - cx) // 2 + rng.randint(-1, 0)
            _on(a, x, y, LEAF[2] if rng.random() < 0.6 else LEAF[3])


def _weather_roof(a, g, rng):
    A = g.A
    for _ in range(8):                       # moss on the shingles
        x0 = rng.randint(g.cx - 22, g.cx + 8)
        y0 = int(A[1] + 0.5 * (x0 - A[0])) + rng.randint(5, 18)
        for _ in range(rng.randint(3, 7)):
            x, y = x0 + rng.randint(-1, 2), y0 + rng.randint(0, 1)
            _on(a, x, y, LEAF[3] if rng.random() < 0.5 else LEAF[2])
    x0 = g.cx - 8                            # a shingle gone
    y0 = int(A[1] + 0.5 * (x0 - A[0])) + 10
    for dx in range(3):
        a.px(x0 + dx, y0, OUT)
        a.px(x0 + dx, y0 + 1, ROOF_OLD["deep"])


def _cobweb(im, at):
    ax, ay = at
    pts = set()
    for r in range(1, 7):
        pts.update({(ax + r, ay), (ax, ay + r), (ax + r - r // 3, ay + r // 2 + r // 3)})
    for r in (3, 6):
        for k in range(r + 1):
            pts.add((ax + k, ay + r - k))
    for x, y in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            p = im.getpixel((x, y))
            if p[3]:
                im.putpixel((x, y), mix(p, WEB, 0.55))


# --- option C: the stand is a painted cupboard, the jars under the hive ----------------------
C_LEVELS = ((2, 12), (14, 24))     # each shelf's open rows under the stand's top edge


def c_slots(g):
    """Option C's twelve jar slots in fill order: the lit face's top shelf, the shaded face's top
    shelf, then the two bottom shelves. (left column, last row, shaded) before inking."""
    cx, c = g.cx, g.c
    out = []
    for lv in (0, 1):
        bottom = C_LEVELS[lv][1]
        for face in ("R", "L"):
            for j in range(3):
                if face == "R":
                    x0 = cx + 3 + 8 * j
                    xc = x0 + 3
                    y = c + 14 - (xc - cx) // 2 + bottom - 1
                else:
                    x0 = cx - 26 + 8 * j
                    xc = x0 + 3
                    y = c + (xc - (cx - 28)) // 2 + bottom - 1
                out.append((x0, y, face == "L"))
    return out


def _shelf_stand(a, g, jars, old):
    cx, c = g.cx, g.c
    lit, base, shade, deep = paint_of(old)
    S = g.box
    inside_l = mix(oak(0, old), OUT, 0.25)
    inside_r = oak(1, old)
    edges = (0, C_LEVELS[0][1], C_LEVELS[1][1])
    for face in ("L", "R"):
        xs = range(cx - 28, cx) if face == "L" else range(cx, cx + 29)
        for x in xs:
            top = c + (x - (cx - 28)) // 2 if face == "L" else c + 14 - (x - cx) // 2
            post = x in (cx - 28, cx - 27, cx - 1, cx, cx + 27, cx + 28)
            for r in range(S):
                rail = r < 2 or C_LEVELS[0][1] <= r < C_LEVELS[1][0] or r >= C_LEVELS[1][1]
                if post or rail:
                    if face == "L":
                        col = mix(shade, lit, 0.3) if (r in edges and not post) else shade
                        if x == cx - 1:
                            col = mix(shade, lit, 0.25)
                    else:
                        col = lit if (r in edges and not post) else base
                        if x == cx:
                            col = lit
                else:
                    lv = 0 if r < C_LEVELS[0][1] else 1
                    col = inside_l if face == "L" else inside_r
                    if r - C_LEVELS[lv][0] < 2:
                        col = mix(col, OUT, 0.35)
                a.px(x, top + r, col)
    for lx, ly in ((cx - 27, c + S), (cx - 1, c + 14 + S), (cx + 26, c + S)):
        a.rect(lx, ly, 1, g.legs, oak(0, old))
        a.rect(lx + 1, ly, 1, g.legs, oak(2, old))
    if old:
        # a sagging shelf: nothing kept here for years
        for x in range(cx + 6, cx + 20):
            y = c + 14 - (x - cx) // 2 + C_LEVELS[0][1] + (1 if cx + 10 < x < cx + 17 else 0)
            a.px(x, y, mix(GREY[2], OUT, 0.2))
        return
    slots = c_slots(g)
    for k in range(min(jars, len(slots))):
        x0, y, shaded = slots[k]
        a.paste(jar(0.12 if shaded else 0.0), x0, y - JAR_H + 1)


# =============================================================================================
# Option A: the honey hutch, a little painted cabinet of its own behind-left of the hive, its
# open front facing down-right (the lit side, towards the hut and the angler). Three shelves of
# four. Second pass (the review read the first as a barred cage): the back is the paint's deep
# blue in boards, so the amber jars stand out on it; each shelf is a two-px oak board with a
# lit lip and the jars stand on it; square corner posts; a low oak hood, not the hive's coral,
# so the coral stays the hive's; a plinth, not legs. About 0.6 of the hive's height at the
# corner, and set 11 art px clear of the hive's eave.
# =============================================================================================
CB_FRONT, CB_DEPTH = 36, 8
CB_RAIL = 3                           # the top rail's rows
CB_LEVEL = 12                         # a shelf: one row of air, a jar's nine, two of board
CB_SHELVES, CB_PER = 3, 4
CB_PLINTH = 2
CB_BODY = CB_RAIL + CB_SHELVES * CB_LEVEL + CB_PLINTH     # 41
CB_HOOD = 3                           # the hood's rise to the back


def cupboard(jars=0, old=False):
    """Option A at one world px an art px, inked. Returns (image, origin): origin is the ground
    under the front-left post."""
    lit, base, shade, deep = paint_of(old)
    fx = CB_DEPTH + 3                         # the front's left column
    w = fx + CB_FRONT + 4
    top0 = CB_FRONT // 2 + CB_DEPTH // 2 + CB_HOOD + 7
    h = top0 + CB_BODY + 2
    a = bh.Art(w, h)
    rng = random.Random(5)
    back = mix(deep, OUT, 0.15) if not old else GREY[3]
    seam = mix(deep, OUT, 0.45) if not old else mix(GREY[3], OUT, 0.35)
    under = mix(deep, OUT, 0.4) if not old else mix(GREY[3], OUT, 0.3)

    def front_top(x):
        return top0 - (x - fx) // 2

    def side_top(x):                          # the left side, rising to the back
        return top0 - (fx - x + 1) // 2

    # the side panel, facing down-left (in the shade), boards running along it
    for x in range(fx - CB_DEPTH, fx):
        for r in range(CB_BODY):
            col = shade if (r % 5) else mix(shade, deep, 0.45)
            if x == fx - CB_DEPTH:
                col = mix(shade, deep, 0.35)
            if r >= CB_BODY - CB_PLINTH:
                col = oak(1 if r == CB_BODY - 1 else 2, old)
            a.px(x, side_top(x) + r, col)
    # the front: posts, rail, the back boards, the shelves, the plinth
    for x in range(fx, fx + CB_FRONT):
        c = x - fx
        for r in range(CB_BODY):
            if r >= CB_BODY - CB_PLINTH:
                col = oak(2 if r == CB_BODY - 1 else 3, old)
            elif c < 2 or c >= CB_FRONT - 2:      # the corner posts
                col = (lit if c == 0 else base) if c < 2 else (base if c == CB_FRONT - 2 else
                                                               mix(base, shade, 0.6))
            elif r < CB_RAIL:                       # the top rail
                col = (lit, base, mix(base, shade, 0.5))[r]
            else:
                rr = (r - CB_RAIL) % CB_LEVEL
                if rr == CB_LEVEL - 2:
                    col = oak(6, old)               # the shelf's lit lip
                elif rr == CB_LEVEL - 1:
                    col = oak(3, old)               # its front edge
                elif rr < 2:
                    col = under                     # the shadow under the board above
                else:
                    col = seam if (c - 2) % 8 == 7 else back
            a.px(x, front_top(x) + r, col)
    # the hood: a low lean-to of oak shingles over the top, overhanging a px at the front and
    # the side, rising CB_HOOD to the back; a two-row oak fascia along its front edge
    F0 = (fx - 2, top0 - 1)
    F1 = (fx + CB_FRONT + 1, top0 - (CB_FRONT + 3) // 2 - 1)
    off = (-CB_DEPTH - 2, -(CB_DEPTH + 2) // 2 - CB_HOOD)
    B0 = (F0[0] + off[0], F0[1] + off[1])
    B1 = (F1[0] + off[0], F1[1] + off[1])

    def shingle(x, y):
        d = (F0[1] + (x - F0[0]) * (F1[1] - F0[1]) / (F1[0] - F0[0])) - y   # rows up from the front
        if old and rng.random() < 0.07:
            return oak(1, old)
        row = int(d // 2)
        if int(d) % 2 == 0 and d > 0.5:
            return oak(3, old)
        return oak(5 if (int(x + row * 3) % 5) else 4, old)
    a.fill_by([F0, F1, B1, B0], shingle)
    for x in range(F0[0], F1[0] + 1):
        y = F0[1] + (x - F0[0]) * (F1[1] - F0[1]) / (F1[0] - F0[0])
        a.px(x, y, oak(6, old))
        a.px(x, y + 1, oak(2, old))
        a.px(x, y + 2, oak(1, old))
    for k in range(B0[0], F0[0] + 1):           # the hood's end, in the shade
        t = (k - B0[0]) / max(1, F0[0] - B0[0])
        y = B0[1] + (F0[1] - B0[1]) * t
        a.px(k, y + 1, oak(1, old))
        a.px(k, y + 2, oak(0, old))
    # jars, the top shelf first, each standing on its board's lip
    for k in range(min(jars, CB_SHELVES * CB_PER)):
        lv, j = k // CB_PER, k % CB_PER
        x0 = fx + 2 + 8 * j
        xc = x0 + 3
        last = front_top(xc) + CB_RAIL + lv * CB_LEVEL + CB_LEVEL - 3
        a.paste(jar(), x0, last - JAR_H + 1)
    if old:
        for x in range(fx + 9, fx + 24):        # the second shelf's board, split and sagging
            y = front_top(x) + CB_RAIL + CB_LEVEL + CB_LEVEL - 2 + (1 if fx + 13 < x < fx + 20 else 0)
            a.px(x, y, mix(GREY[2], OUT, 0.3))
            a.px(x, y + 1, mix(GREY[3], OUT, 0.3))
        on_f = lambda x, r, c: _on(a, x, front_top(x) + r, c)
        on_s = lambda x, r, c: _on(a, x, side_top(x) + r, c)
        chip_patches(rng, 5, [fx, fx + CB_FRONT - 3], list(range(4, CB_BODY - 6)), on_f, SKY[1],
                     SKY[0])
        chip_patches(rng, 4, list(range(fx + 3, fx + CB_FRONT - 5)), [0, 1], on_f, SKY[1], SKY[0])
        chip_patches(rng, 9, list(range(fx - CB_DEPTH, fx - 2)), [r for r in range(2, CB_BODY - 4)
                                                                 if r % 5 in (0, 1)], on_s, SKY[2],
                     SKY[1])
    im = bh.inked(a.im)
    if old:
        _cobweb(im, (fx + 3, front_top(fx + 3) + CB_RAIL + 1))
    origin = (fx + 1, front_top(fx) + CB_BODY + 1)
    return im, origin


# =============================================================================================
# Option B: the honey table, low, front-left of the hive: an oak top on sky-blue legs, the jars
# in two rows of six along its long side, the back row on a riser four px tall. Second pass (the
# review measured the first, a 4 x 3 lattice, at only 4 px a step back for a 9 px jar: the lids
# hid the bodies behind): a jar in the back row stands 8 along and 8 higher than the front one
# it follows, so it sits over the gap between two front jars with four px of riser showing
# under it. Every lid and every body is clear of every other.
# =============================================================================================
U = (1.0, 0.5)                      # along a tile edge, down-right on screen
V = (1.0, -0.5)                     # the other edge, back (up-right on screen)
TB_LONG, TB_DEEP, TB_LEGS, TB_TOP = 52, 18, 9, 2
TB_ROW = 6                          # jars a row
TB_RISE, TB_RISER_FROM = 4, 9       # the riser's height and where it starts, back from the front


def _pt(p, along=0.0, back=0.0, up=0.0):
    return (p[0] + along * U[0] + back * V[0], p[1] + along * U[1] + back * V[1] - up)


def iso_box(a, p, L, D, H, top, front, end):
    """A box standing on point p (its front-left bottom corner): L along U, D back along V, H
    tall. Draws the front face (facing down-left), the right end (facing down-right) and the
    top; each colour is a colour or a fn(x, y). Returns the top's front-left corner."""
    F0, F1 = p, _pt(p, L)
    B1 = _pt(p, L, D)
    B0 = _pt(p, 0, D)
    up = lambda q: (q[0], q[1] - H)
    fn = lambda c: c if callable(c) else (lambda x, y, c=c: c)
    a.fill_by([up(F0), up(F1), F1, F0], fn(front))
    a.fill_by([up(F1), up(B1), B1, F1], fn(end))
    a.fill_by([up(F0), up(F1), up(B1), up(B0)], fn(top))
    return up(F0)


def bench_slots():
    """The twelve slots in fill order, the front row first: (along, back, raised)."""
    out = [(4.5 + 8 * i, 4.5, False) for i in range(TB_ROW)]
    out += [(8.5 + 8 * i, 12.5, True) for i in range(TB_ROW)]
    return out


def bench(jars=0, old=False):
    """Option B at one world px an art px, inked. Returns (image, origin): origin is the ground
    under the table's front-left leg."""
    lit, base, shade, deep = paint_of(old)
    w = TB_LONG + TB_DEEP + 6
    h = int(TB_LONG * 0.5 + TB_DEEP * 0.5 + TB_LEGS + TB_TOP + TB_RISE + JAR_H + 10)
    a = bh.Art(w, h)
    rng = random.Random(9)
    P = (2, int(TB_DEEP * 0.5 + TB_LEGS + TB_TOP + TB_RISE + JAR_H + 6))   # front-left, ground
    for along, back in ((1, 1), (TB_LONG - 2, 1), (TB_LONG - 2, TB_DEEP - 2)):
        q = _pt(P, along, back)
        a.rect(round(q[0]) - 1, round(q[1]) - TB_LEGS, 1, TB_LEGS + 1, shade)
        a.rect(round(q[0]), round(q[1]) - TB_LEGS, 1, TB_LEGS + 1, base if back < 2 else shade)
    top_at = _pt(P, 0, 0, TB_LEGS)
    iso_box(a, (top_at[0], top_at[1] + 2), TB_LONG, TB_DEEP, 3, base,
            lambda x, y: shade, lambda x, y: base)

    def plank(x, y, at):
        d = (at[1] + (x - at[0]) * 0.5) - y
        if d < 1.0:
            return oak(6, old)
        return oak(3, old) if int(d) % 4 == 3 else oak(5 if int(x * 0.7 + d) % 9 else 4, old)
    iso_box(a, top_at, TB_LONG, TB_DEEP, TB_TOP,
            lambda x, y: plank(x, y, (top_at[0], top_at[1] - TB_TOP)),
            lambda x, y: oak(2, old), lambda x, y: oak(4, old))
    surface = _pt(top_at, 0, 0, TB_TOP)
    # the riser: a plank box along the back half of the top
    rp = _pt(surface, 0, TB_RISER_FROM)
    iso_box(a, rp, TB_LONG, TB_DEEP - TB_RISER_FROM, TB_RISE,
            lambda x, y: plank(x, y, (rp[0], rp[1] - TB_RISE)),
            lambda x, y: oak(3, old) if int(y) % 2 else oak(2, old), lambda x, y: oak(4, old))
    rsurf = _pt(rp, 0, 0, TB_RISE)
    for x in range(int(round(rp[0])), int(round(_pt(rp, TB_LONG)[0])) + 1):   # the riser's lip
        a.px(x, rp[1] - TB_RISE + (x - rp[0]) * 0.5, oak(6, old))
    if old:
        for k in range(8):                      # a plank gone from the top
            q = _pt(surface, 9 + k, 5)
            a.px(q[0], q[1], OUT)
            a.px(q[0], q[1] + 1, mix(OUT, oak(1, True), 0.4))
        on = lambda x, r, c: _on(a, x, r, c)
        legs = []
        for along, back in ((1, 1), (TB_LONG - 2, 1)):
            q = _pt(P, along, back)
            legs.append(int(round(q[0])))
        chip_patches(rng, 6, legs, [int(_pt(P, 1, 1)[1]) - k for k in range(2, TB_LEGS)], on,
                     SKY[1], SKY[0])
    slots = bench_slots()[:min(jars, 2 * TB_ROW)]
    for along, back, raised in sorted(slots, key=lambda t: (not t[2], t[0])):
        q = _pt(rsurf if raised else surface, along, back - (TB_RISER_FROM if raised else 0))
        a.paste(jar(), round(q[0]) - JAR_W // 2, round(q[1]) - JAR_H + 1)
    im = bh.inked(a.im)
    return im, (P[0] + 1, P[1] + 1)


# =============================================================================================
# The swarm's tree: a young flowering tree (a trunk, the pack's round bush as its crown, blossom
# on its lit side) and, in the swarm state, a bough out under the crown's right edge with the
# swarm hanging from it as ONE teardrop. Second pass: the first hung five outlined bee tiles off
# a low bush 8 px over the lawn; now the bough is about 33 px up, the mass's tip about 12 px off
# the lawn, and its shadow lies on the lawn well apart from the tree's.
# =============================================================================================
def flora_piece(name):
    j = json.load(open(os.path.join(look.ROOT, "assets/flora.json")))[name]
    x, y, w, h = j["full"]
    sheet = Image.open(os.path.join(look.ROOT, "assets/flora.png")).convert("RGBA")
    return sheet.crop((x, y, x + w, y + h))


TRUNK = 30                       # the crown's foot over the lawn at the trunk, art px
BOUGH = [(2, 29), (8, 31), (14, 32), (20, 31), (26, 29), (31, 28)]  # (x off the trunk, height)
SWARM_ALONG = 20                 # where the swarm hangs on the bough, px right of the trunk
SWARM_W, SWARM_H = 17, 22        # the hanging mass inside its outline, art px
# The faces that look out of the mass's edge: (row under its top, side 'L'/'R')
SWARM_FACES = [(5, "R"), (11, "L"), (15, "R")]


def _swarm_half(t):
    """Half width (share of the widest) down the mass: narrow where it wraps the bough, widest
    a third down, tapering to a blunt point."""
    if t < 0.32:
        return 0.45 + 0.55 * math.sin(math.pi / 2 * t / 0.32)
    return max(0.08, 1.0 - 0.9 * ((t - 0.32) / 0.68) ** 1.5)


def swarm_mass(seed=5):
    """The swarm as it hangs: one lumpy teardrop at one world px an art px with a single outer
    outline. Its edge is a run of small bulges (bodies), its inside a speckle of bodies packed
    in staggered bricks (each a lit back, a dark band and a darker gap under it) over a ramp
    lit from the top-right, the light stepping through a 2 x 2 ordered dither. Three faces (the
    round mini bee's 2 x 2 eye, its glint and cheek) look out of the edge; folded wings catch
    the light on the upper rim and two slivers stand off it. Returns (image, (x, y)): the image
    and its top middle."""
    K = look.key(BEE)
    rng = random.Random(seed)
    W, H = SWARM_W, SWARM_H
    cw, ch = W + 10, H + 8
    ox, oy = 5, 3
    cx = ox + (W - 1) / 2.0
    halves = []
    mask = np.zeros((ch, cw), bool)
    for y in range(H):
        t = (y + 0.5) / H
        hw = max(0.8, (W / 2.0 - 1.2) * _swarm_half(t))
        halves.append(hw)
        for x in range(cw):
            if abs(x - cx) <= hw - 0.25:
                mask[oy + y, x] = True
    # bulges along the edge: a body's round back every three rows on each side
    for y in range(5, H - 3, 3):
        for side in (-1, 1):
            bx = cx + side * (halves[y] - 0.3)
            by = oy + y + rng.choice((0, 1))
            r = rng.choice((1.6, 1.9, 2.2))
            for yy in range(int(by - 3), int(by + 4)):
                for xx in range(int(bx - 3), int(bx + 4)):
                    if 0 <= yy < ch and 0 <= xx < cw and (xx - bx) ** 2 + (yy - by) ** 2 <= r * r:
                        if oy <= yy < oy + H:
                            mask[yy, xx] = True
    bayer = ((0, 2), (3, 1))
    ramp = (K["D"], K["S"], K["G"], K["L"])
    a = np.zeros((ch, cw, 4), np.uint8)
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        u = (x - cx) / (W / 2.0)
        v = (y - oy) / H
        light = 0.5 * u - 0.8 * v + 0.32
        k = light * 2.2 + 0.9 + bayer[y % 2][x % 2] / 4.0
        a[y, x] = ramp[max(0, min(3, int(k)))]
    # the bodies: bricks 4 wide, 3 tall, every other row of bricks offset by 2, a px of jitter
    for row in range(-1, H // 3 + 2):
        y0 = oy + row * 3 + 1
        off = 2 if row % 2 else 0
        for col in range(-1, W // 4 + 2):
            x0 = ox + col * 4 + off + rng.choice((0, 0, 1))
            band_x = x0 + rng.choice((1, 2))
            for (dx, dy, key) in ((band_x - x0, 0, "K"), (band_x - x0, 1, "k"),
                                  (0, 2, "D"), (1, 2, "D")):
                x, y = x0 + dx, y0 + dy
                if 0 <= x < cw and 0 <= y < ch and mask[y, x]:
                    c = K[key]
                    if key == "D" and (x - cx) > W * 0.25 and (y - oy) < H * 0.5:
                        c = K["S"]
                    a[y, x] = c
    m = look.ring(Image.fromarray(a, "RGBA"))      # ONE outline round the whole mass
    px = m.load()
    for row, side in SWARM_FACES:
        y = oy + row
        row_xs = [x for x in range(cw) if mask[y, x]]
        if not row_xs:
            continue
        if side == "R":
            ex = row_xs[-1] - 1
            pts = ((ex, y, "E"), (ex + 1, y, "w"), (ex, y + 1, "E"), (ex + 1, y + 1, "E"),
                   (ex + 1, y + 2, "c"), (ex - 1, y, "G"), (ex - 1, y + 1, "G"),
                   (ex, y - 1, "L"), (ex + 1, y - 1, "L"))
        else:
            ex = row_xs[0]
            pts = ((ex + 1, y, "E"), (ex, y, "w"), (ex + 1, y + 1, "E"), (ex, y + 1, "E"),
                   (ex, y + 2, "c"), (ex + 2, y, "S"), (ex + 2, y + 1, "S"),
                   (ex, y - 1, "G"), (ex + 1, y - 1, "G"))
        for x, yy, c_ in pts:
            if 0 <= x < cw and 0 <= yy < ch and mask[yy, x]:
                px[x, yy] = K[c_]
    for row in (1, 2, 6):                           # folded wings in the light on the rim
        row_xs = [x for x in range(cw) if mask[oy + row, x]]
        if row_xs:
            px[row_xs[-1] - 2, oy + row] = K["W"]
    for x, y in ((int(cx) + 4, oy - 2), (int(cx) + 5, oy - 2), (int(cx) - 5, oy - 1),
                 (int(cx) - 6, oy - 2)):
        if 0 <= x < cw and 0 <= y < ch and px[x, y][3] == 0:
            px[x, y] = K["V"] if x < cx else K["W"]
    return m, (int(round(cx)), oy)


# The tree's crown (2026-10-19, Richard: the pack bush on a three-pixel trunk read as "a bush
# on a stick"): a broad dome of leaf clumps drawn by rule, each clump lit on its upper right
# (the game's light) and shaded down-left, a dark seam where a nearer clump overlaps a farther
# one, speckled leaves, one outline round the whole. (x, y, r) off the crown's middle, back
# clumps first; the lowest clumps are the nearest.
CROWN_CLUMPS = [
    (-4, -15, 8), (8, -14, 8), (-15, -8, 8), (17, -7, 7), (1, -9, 11), (-19, 1, 7),
    (20, 1, 7), (-11, 0, 10), (11, -1, 10), (0, 2, 11), (-15, 7, 7), (14, 7, 7), (-5, 9, 8),
    (6, 9, 8),
]
CROWN_W, CROWN_H = 56, 42
CROWN_MID = (28, 23)             # the middle of the clumps on the crown's canvas
LIGHT = (0.6, -0.8)              # where the light comes from, on the picture: up and right


def _leaf_hash(x, y):
    h = (x * 374761393 + y * 668265263) & 0x7fffffff
    h = ((h ^ (h >> 13)) * 1103515245) & 0x7fffffff
    return (h % 1009) / 1009.0


def _crown(blossom=True):
    W, H = CROWN_W, CROWN_H
    mx, my = CROWN_MID
    a = np.zeros((H, W, 4), np.uint8)
    owner = np.full((H, W), -1, np.int32)
    for k, (cx, cy, r) in enumerate(CROWN_CLUMPS):
        for y in range(H):
            for x in range(W):
                dx, dy = x + 0.5 - (mx + cx), y + 0.5 - (my + cy)
                # A little wobble on the rim so a clump is leafy, not a disc.
                wob = 0.9 + 0.2 * _leaf_hash(x // 2 + k * 7, y // 2)
                if dx * dx + dy * dy <= (r * wob) ** 2:
                    owner[y, x] = k
    for y in range(H):
        for x in range(W):
            k = owner[y, x]
            if k < 0:
                continue
            cx, cy, r = CROWN_CLUMPS[k]
            nx, ny = (x + 0.5 - (mx + cx)) / r, (y + 0.5 - (my + cy)) / r
            lit = nx * LIGHT[0] + ny * LIGHT[1]
            # The whole crown darkens to its lower left as well as each clump.
            whole = ((x - mx) * LIGHT[0] / (W * 0.5) + (y - my) * LIGHT[1] / (H * 0.5)) * 0.35
            v = lit * 0.75 + whole
            n = _leaf_hash(x, y)
            if n < 0.14:
                v -= 0.35
            elif n > 0.9:
                v += 0.3
            step = 0 if v > 0.5 else (1 if v > 0.0 else (2 if v > -0.45 else 3))
            # A seam where this clump lies over one behind it: its own rim, a step darker.
            if math.hypot(nx, ny) > 0.82:
                for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    xx, yy = x + ox, y + oy
                    if 0 <= xx < W and 0 <= yy < H and owner[yy, xx] >= 0 and owner[yy, xx] < k:
                        step = min(step + 1, 3)
                        break
            a[y, x] = LEAF[step]
    c = Image.fromarray(a, "RGBA").copy()
    if blossom:
        rng = random.Random(4)
        px = c.load()
        spots = tries = 0
        while spots < 22 and tries < 2000:
            tries += 1
            x, y = rng.randint(mx - 6, W - 4), rng.randint(2, H - 10)
            if all(px[x + dx, y + dy][3] for dx in (-1, 0, 1, 2) for dy in (-1, 0, 1, 2))                     and px[x, y][:3] in (LEAF[0][:3], LEAF[1][:3]):
                px[x, y + 1] = BLOSSOM[1]
                px[x + 1, y + 1] = BLOSSOM[2]
                if rng.random() < 0.6:
                    px[x, y] = BLOSSOM[0]
                spots += 1
        spots = tries = 0
        while spots < 7 and tries < 2000:           # a few in the shade too, darker
            tries += 1
            x, y = rng.randint(3, mx + 4), rng.randint(6, H - 6)
            if all(px[x + dx, y + dy][3] for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = BLOSSOM[2]
                spots += 1
    return c


def _trunk_px(t, tx, ground):
    """A young trunk: flared at the foot, tapering up to a fork, leaning a touch, bark lit on its
    right; two limbs off the fork up into the crown and a twig, all in the bark's three steps."""
    fork = TRUNK - 4
    for r in range(fork + 1):
        y = ground - r
        half = 2.6 - 1.2 * (r / fork) + (1.6 if r < 2 else (0.8 if r < 4 else 0.0))
        lean = round(1.2 * math.sin(r / 11.0))
        x0, x1 = int(round(tx - half + lean)), int(round(tx + half + lean))
        for x in range(x0, x1 + 1):
            u = (x - x0) / max(x1 - x0, 1)
            c = BARK[2] if u < 0.3 else (BARK[1] if u < 0.72 else BARK[0])
            if r % 6 == 2 and 0.3 <= u < 0.72 and x1 - x0 >= 3:
                c = BARK[2]                              # a crack in the bark
            t.px(x, y, c)
    top = ground - fork
    lean = round(1.2 * math.sin(fork / 11.0))
    for (dx, dy, wide) in ((-11, -15, 2), (10, -16, 2), (1, -18, 1), (-17, -9, 1)):
        n = max(abs(dx), abs(dy))
        for i in range(n + 1):
            f = i / n
            x = tx + lean + dx * f
            y = top - 1 + dy * f
            w = wide if f < 0.6 else 1
            for k in range(w):
                t.px(int(round(x)) + k, int(round(y)), BARK[1] if k == 0 else BARK[0])


def _bough_px(a, tx, ground):
    """The bough out of the trunk under the crown's right edge, sagging under the swarm: two px
    of bark (lit top, deep under) inked above and below, one px at its tip, a sprig of leaves."""
    pts = [(tx + x, ground - hgt) for x, hgt in BOUGH]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for x in range(x0, x1):
            y = int(round(y0 + (y1 - y0) * (x - x0) / (x1 - x0)))
            thick = 2 if x < tx + 18 else 1
            a.px(x, y - 1, OUT)
            a.px(x, y, BARK[0])
            if thick == 2:
                a.px(x, y + 1, BARK[2])
            a.px(x, y + thick, OUT)
    ex, ey = pts[-1]
    for dx, dy, c in ((0, -1, LEAF[1]), (1, -1, LEAF[0]), (1, 0, LEAF[2]), (2, 0, LEAF[1]),
                      (1, 1, LEAF[2])):
        a.px(ex + dx, ey + dy, c)
    for dx, dy in ((0, -2), (1, -2), (2, -1), (3, 0), (2, 1), (1, 2), (0, 1), (-1, -1)):
        x, y = ex + dx, ey + dy
        if 0 <= x < a.w and 0 <= y < a.h and a.im.getpixel((x, y))[3] == 0:
            a.px(x, y, OUT)


def shrub(blossom=True, swarm=False):
    """The young tree, blossoming, with a bough and the swarm (swarm state). Returns (image,
    foot, hang, standing, aloft): foot the trunk's bottom middle; hang where the swarm's top
    middle goes; standing the trunk and its limbs, which sweep their shadow as a column; aloft
    the parts in the air (crown, bough, swarm), which cast theirs off the ground under them
    (`shade_of`)."""
    crown = _crown(blossom)
    cwid, chei = crown.size
    w = cwid + 14
    ground = TRUNK + chei - 8
    h = ground + 2
    tx = CROWN_MID[0]                     # the trunk's middle column, under the crown's middle
    a = bh.Art(w, h)
    trunk = bh.Art(w, h)
    _trunk_px(trunk, tx, ground)
    trunk_im = bh.inked(trunk.im).crop((1, 1, w + 1, h + 1))
    a.paste(crown, 0, ground - TRUNK - chei + 8)
    a_im = bh.inked(a.im).crop((1, 1, w + 1, h + 1))
    a = bh.Art(w, h)
    a.im = a_im
    a.d = ImageDraw.Draw(a.im)
    if swarm:
        _bough_px(a, tx, ground)
    aloft = a.im.copy()
    hang = (tx + SWARM_ALONG, ground - BOUGH[3][1] + 1)
    if swarm:
        m, (mx, my) = swarm_mass()
        aloft.alpha_composite(m, (hang[0] - mx, hang[1] - my))
    full = trunk_im.copy()
    full.alpha_composite(aloft)
    return full, (tx, ground), hang, trunk_im, aloft


# =============================================================================================
# The ready mark, at the hive's own grain: a honey drop with a glint inside its ring, two of
# the finds' four-point stars inked so they hold on pale sand. Shown only while the angler is
# out of the hive's reach (in reach the game shows the wooden key chip instead).
# =============================================================================================
DROP = [
    ".....O.....",
    "....OLO....",
    "....OHO....",
    "...OHLHO...",
    "...OHHLO...",
    "..OMHHLHO..",
    "..OMHHHLO..",
    ".OMHHHHwLO.",
    ".OMHHHHLSO.",
    "OMMHHHHHLSO",
    "OMMHHHHHHLO",
    "OMMHHHHHHLO",
    ".ODMHHHHMO.",
    "..ODDMMMO..",
    "...OOOOO...",
]


def _ink_star(arm):
    """The finds' four-point star in whole pixels, ringed: a pale heart, gold arms."""
    n = 2 * arm + 1
    im = Image.new("RGBA", (n + 2, n + 2), (0, 0, 0, 0))
    c = arm + 1
    im.putpixel((c, c), SW["coin_pale"])
    for k in range(1, arm + 1):
        col = SW["coin"] if k < arm else SW["coin_shade"]
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            im.putpixel((c + dx, c + dy), col)
    return look.ring(im)


def ready_mark():
    k = {"O": OUT, "L": H_LIGHT, "H": H_, "M": H_MID, "S": H_SHINE, "D": H_DEEP,
         "w": SW["foam_light"]}
    drop = look.grid(DROP, k)
    im = Image.new("RGBA", (drop.width + 16, drop.height + 6), (0, 0, 0, 0))
    im.alpha_composite(drop, (8, 3))
    im.alpha_composite(_ink_star(2), (0, 3))
    im.alpha_composite(_ink_star(1), (drop.width + 11, 11))
    return im, (8 + drop.width // 2, 3 + drop.height // 2)


# =============================================================================================
# Shadows and the day: what makes a new piece sit on the capture
# =============================================================================================
SUN_LEAN, SUN_DROP = 0.55, 0.35         # a pixel h art px up throws its shadow h*LEAN left, h*DROP down:
                                 # measured off the old hive's shadow on the capture
GROUND_BAND = 18                 # a column casts when it reaches within this of the deepest row


def sweep(im):
    """Shade.sweep's rule on a front-on picture at 1x: every column that reaches the ground casts
    its whole height, swept down-left along the sun. Returns (mask 'L', (ox, oy)): the mask's
    top-left in the picture's own pixels."""
    a = np.array(im.getchannel("A")) > 40
    H, W = a.shape
    cols = [x for x in range(W) if a[:, x].any()]
    if not cols:
        return Image.new("L", (1, 1), 0), (0, 0)
    deepest = max(int(np.nonzero(a[:, x])[0].max()) for x in cols)
    pad_l, pad_b = int(SUN_LEAN * H) + 3, int(SUN_DROP * H) + 3
    mask = Image.new("L", (W + pad_l, H + pad_b), 0)
    d = ImageDraw.Draw(mask)
    for x in cols:
        ys = np.nonzero(a[:, x])[0]
        g = int(ys.max())
        if g < deepest - GROUND_BAND:
            continue
        h = g - int(ys.min())
        x0 = x + pad_l
        d.polygon([(x0, g), (x0 + 1, g), (x0 + 1 - SUN_LEAN * h, g + SUN_DROP * h),
                   (x0 - SUN_LEAN * h, g + SUN_DROP * h)], fill=255)
    return mask, (-pad_l, 0)


def shade_of(standing, aloft, ground):
    """Shadows for a picture with parts in the air: `standing` sweeps as Shade.sweep does; every
    pixel of `aloft` at height h over the ground row `ground` falls h*LEAN left and h*DROP down of
    the ground point under it (Shade.drop), so a hanging swarm's shadow lies apart from it on the
    lawn. Returns (mask 'L', (ox, oy)) like `sweep`, on the same padded canvas."""
    m, off = sweep(standing)
    H = standing.height
    pad_l = int(SUN_LEAN * H) + 3
    if m.size == (1, 1):
        m = Image.new("L", (standing.width + pad_l, H + int(SUN_DROP * H) + 3), 0)
        off = (-pad_l, 0)
    px = m.load()
    al = np.array(aloft.getchannel("A")) > 40
    for y, x in zip(*np.nonzero(al)):
        h = ground - int(y)
        if h < 0:
            continue
        for dx in (0, 1):
            sx = int(round(x - SUN_LEAN * h)) - off[0] + dx
            sy = int(round(ground + SUN_DROP * h)) - off[1]
            if 0 <= sx < m.width and 0 <= sy < m.height:
                px[sx, sy] = 255
    return m, off


def day_mul(im):
    a = np.array(im).astype(float)
    a[..., 0] *= DAY[0]
    a[..., 1] *= DAY[1]
    a[..., 2] *= DAY[2]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def _corner(at, anchor):
    return (look.snap(at[0], G) - anchor[0] * G, look.snap(at[1], G) - anchor[1] * G)


BEE_BLOT_A = 1 - (1 - LAND_A) ** 2   # the land ink twice over
BEE_BLOT = 4                     # a flying bee's shadow: 4 px wide, two rows (3 x 1 when high)


def compose(base, items, bees=(), angler_front=True, bee_shades=()):
    """Every item a dict: im (1x RGBA), at (plate px of `anchor`), anchor (px in im), shadow,
    z (sort key, plate y). Shadows first, all on the ground in the land ink (the flying bees'
    blots among them, so a piece standing over one covers it); then the pieces back to front;
    then the bees in the air. Returns a new plate."""
    out = base.copy()
    shade = Image.new("L", out.size, 0)
    blots = Image.new("L", out.size, 0)
    sd = ImageDraw.Draw(blots)
    for (x, y), wide in bee_shades:
        # a rounded blot: `wide` art px, under a row two narrower (4 x 2 low, 3 x 1 high)
        x0, y0 = look.snap(x - wide * G / 2.0, G), look.snap(y, G)
        sd.rectangle([x0, y0, x0 + wide * G - 1, y0 + G - 1], fill=255)
        if wide >= 4:
            sd.rectangle([x0 + G, y0 - G, x0 + (wide - 1) * G - 1, y0 - 1], fill=255)
    for it in items:
        if not it.get("shadow", True):
            continue
        m, (ox, oy) = it["shade"] if "shade" in it else sweep(it["im"])
        big = m.resize((m.width * G, m.height * G), Image.NEAREST)
        x, y = _corner(it["at"], (it["anchor"][0] - ox, it["anchor"][1] - oy))
        layer = Image.new("L", out.size, 0)
        layer.paste(big, (int(x), int(y)))
        shade = Image.fromarray(np.maximum(np.array(shade), np.array(layer)))
    a = np.array(out).astype(float)
    s = (np.array(shade) > 0)[..., None]
    ink = np.array(LAND_INK, float)
    a[..., :3] = np.where(s, a[..., :3] * (1 - LAND_A) + ink * LAND_A, a[..., :3])
    # the bees' blots: the same ink laid twice (BEE_BLOT_A), or a 4 px blot is lost in the
    # lawn's own dark speckle, which is the land ink's single pass already
    bm = (np.array(blots) > 0)[..., None]
    a[..., :3] = np.where(bm, a[..., :3] * (1 - BEE_BLOT_A) + ink * BEE_BLOT_A, a[..., :3])
    out = Image.fromarray(np.clip(np.round(a), 0, 255).astype(np.uint8))
    for it in sorted(items, key=lambda t: t["z"]):
        look.place(out, day_mul(it["im"]), it["at"], G, anchor=it["anchor"])
    if angler_front:
        src = np.array(base)
        m = angler_mask(np.array(look.plate(BASE)))
        a = np.array(out)
        a[m] = src[m]
        out = Image.fromarray(a)
    for im, at, anchor in bees:
        look.place(out, day_mul(im), at, G, anchor=anchor)
    return out


# =============================================================================================
# The scenes: one plate, four states, three arrangements
# =============================================================================================
STATES = ("empty", "swarm", "busy", "ready")
STATE_JARS = {"empty": 0, "swarm": 0, "busy": 6, "ready": 12}
BEDS = [("shrub_flowering_white", (386, 402)), ("patch", (428, 414)),
        ("shrub_flowering", (478, 406))]
LAYOUT = {
    # hive: plate px of the ground under its footprint's middle. piece: plate px of the extra
    # piece's origin. shrub: the swarm tree's foot. bed: flower beds (name, foot).
    "A": {"hive": (376, 282), "piece": (214, 300), "shrub": (302, 412), "bed": BEDS,
          "bulge": 34},
    "B": {"hive": (384, 276), "piece": (222, 322), "shrub": (230, 246), "bed": BEDS,
          "bulge": 30},
    "C": {"hive": (378, 280), "piece": None, "shrub": (230, 246), "bed": BEDS, "bulge": 0},
}
ANGLER_AWAY = (522, 424)          # the ready panel's angler: out of the hive's reach (1.5 tiles)
_CLEAN = {}


def base_plate(away=False):
    """The cleaned capture; `away` also takes the angler and his shadow off it."""
    if "plain" not in _CLEAN:
        _CLEAN["plain"] = clean_plate(BASE)
    if away and "away" not in _CLEAN:
        _CLEAN["away"] = _without_angler(_CLEAN["plain"])
    return _CLEAN["away" if away else "plain"].copy()


def _without_angler(img):
    """The angler and the shaded lawn round his feet laid back to lawn (LAWN_SRC, on the
    plate's lattice), so he can stand somewhere else."""
    a = np.array(img)
    m = angler_mask(np.array(look.plate(BASE)))
    x0, y0, x1, y1 = ANGLER_BOX
    for y in range(y0, y1 + 12):
        for x in range(x0 - 12, x1 + 4):
            t = tuple(int(v) for v in a[y, x, :3])
            if any(sum(abs(t[i] - q[i]) for i in range(3)) < 8 for q in LAWN_SHADE):
                m[y, x] = True
    lx0, ly0, lx1, ly1 = LAWN_SRC
    out = a.copy()
    for y in range(y0 - 4, y1 + 12, G):
        for x in range(x0 - 12, x1 + 4, G):
            if m[y:y + G, x:x + G].any():
                sx = lx0 + (x - lx0) % (lx1 - lx0)
                sy = ly0 + (y - ly0) % (ly1 - ly0)
                out[y:y + G, x:x + G] = a[sy:sy + G, sx:sx + G]
    return Image.fromarray(out)


def angler_item(at):
    """Today's angler cut off the capture (one world px an art px: every second plate px),
    standing at `at`, his shadow swept like every other piece's."""
    a = np.array(look.plate(BASE))
    m = angler_mask(a)
    x0, y0, x1, y1 = ANGLER_BOX
    sub = a[y0:y1:G, x0:x1:G].copy()
    mm = m[y0:y1:G, x0:x1:G]
    sub[..., 3] = np.where(mm, 255, 0)
    sub[~mm] = 0
    im = Image.fromarray(sub, "RGBA")
    im = im.crop(im.getbbox())
    # his shadow is the capture's (lawn shade), so his picture is undone by the day tint here
    inv = np.array(im).astype(float)
    inv[..., 0] /= DAY[0]
    inv[..., 1] /= DAY[1]
    inv[..., 2] /= DAY[2]
    im = Image.fromarray(np.clip(np.round(inv), 0, 255).astype(np.uint8), "RGBA")
    return {"im": im, "at": at, "anchor": (im.width // 2, im.height - 1), "z": at[1]}


def hive_item(opt, state, jars):
    old = state in ("empty", "swarm")
    st = "weathered" if old else ("full" if state == "ready" else "colony")
    im, g = draw_hive(st, 0.5, stand="shelves" if opt == "C" else "legs", jars=jars,
                      drip=state == "ready", drip_long=1 if opt == "C" else 5)
    anchor = (g.origin[0] + 1, g.origin[1] + 1)
    at = LAYOUT[opt]["hive"]
    return {"im": im, "at": at, "anchor": anchor, "z": at[1], "g": g}


def plate_of(item, xy):
    """A pixel of an item's picture -> plate px (its top-left)."""
    cx, cy = _corner(item["at"], item["anchor"])
    return (cx + xy[0] * G, cy + xy[1] * G)


def piece_item(opt, state, jars):
    old = state in ("empty", "swarm")
    if opt == "A":
        im, origin = cupboard(jars, old)
    elif opt == "B":
        im, origin = bench(jars, old)
    else:
        return None
    at = LAYOUT[opt]["piece"]
    return {"im": im, "at": at, "anchor": origin, "z": at[1] - (40 if opt == "A" else 0)}


# --- the bees on the island: look.mini_round, the round lake bee ------------------------------
def mini(frame, left, pose, at):
    im = look.mini_round(BEE, frame, facing_left=left, pose=pose)
    return (im, at, look.mini_round_anchor(BEE, pose, left, frame))


def flyer(frame, left, at, alt):
    """A flying bee drawn at `at` (plate px of its body's middle), `alt` art px over the ground
    under it. Returns (bee, shade): the shade is a land-ink blot at that ground point moved by
    Shade.drop(alt) (0.55 left and 0.35 down a px of height, as the hive's own shadow), 3 x 1,
    2 x 1 once the bee is high."""
    b = mini(frame, left, "fly", at)
    gx, gy = at[0], at[1] + alt * G
    return b, ((gx - SUN_LEAN * alt * G, gy + SUN_DROP * alt * G), BEE_BLOT if alt < 22 else 3)


def emerging(hive, d, frame):
    """A bee walking out of the entrance slot `d` columns past the hive's front corner: it
    stands on the board's lit lip, its back half still inside (clipped above the slot's top
    row, where the wall is). Returns a bee tuple anchored on its canvas's top-left."""
    g = hive["g"]
    bx, by = g.board(d)
    st = g.slot_top(d)
    im = look.mini_round(BEE, frame, facing_left=False, pose="rest")
    px0, py0 = bx - 6, by - 1 - 10
    a = np.array(im)
    for c in range(a.shape[1]):
        if c < 6:
            for r in range(a.shape[0]):
                if py0 + r < st:
                    a[r, c] = 0
    return (Image.fromarray(a, "RGBA"), plate_of(hive, (px0, py0)), (0, 0))


def commuters(opt, hive, frame=0):
    """The colony at work, its stream reading at a glance: at the door a bee walking out of the
    slot and one resting on the stand's ledge (the slot's middle left clear); three in the air
    round the door; a stream out to the flower bed, low over it at the end, two working its
    blooms; two coming home high from over the hut. Every flyer throws its blot. Returns
    (bees, shades)."""
    g = hive["g"]
    ex, ey = plate_of(hive, g.entrance())
    lx, ly = plate_of(hive, g.ledge())
    board_alt = 12
    jars_at_door = opt == "C"       # C's jars are in the stand: nothing may stand or pass there
    bees = [emerging(hive, 16, frame)]
    if not jars_at_door:
        bees.append(mini(frame + 3, True, "rest", (lx - 4, ly - 6)))
    shades = []

    def fly(f, left, at, alt):
        b, sh = flyer(f, left, at, alt)
        bees.append(b)
        shades.append(sh)
    fly(frame + 1, False, (ex + 26, ey - 46), board_alt + 23)     # over the door, in the gap
    bed = dict(LAYOUT[opt]["bed"])["patch"]
    if not jars_at_door:
        fly(frame + 4, False, (ex - 54, ey + 24), 6)                # coming in low, left
        fly(frame + 2, False, (ex + 30, ey + 12), board_alt - 5)    # just off the board
        # the stream to the bed: ground under it from the door to the bed, bulging right
        g0 = (ex, ey + board_alt * G)
        g1 = (bed[0] - 4, bed[1] - 6)
        bulge = LAYOUT[opt]["bulge"]
        for t, alt, f in ((0.36, 18, 3), (0.7, 12, 5)):
            gx = g0[0] + (g1[0] - g0[0]) * t + bulge * math.sin(math.pi * t)
            gy = g0[1] + (g1[1] - g0[1]) * t
            nx = g0[0] + (g1[0] - g0[0]) * (t + 0.05) + bulge * math.sin(math.pi * (t + 0.05))
            fly(f, nx < gx, (gx, gy - alt * G), alt)
    else:
        # C: the stream has to leave the door upwards, over the gable, and come down onto the
        # bed from above, clear of the jars in the stand
        fly(frame + 2, False, (ex + 22, ey - 22), board_alt + 11)
        fly(frame + 5, False, (ex + 70, ey - 26), 30)
        fly(frame + 3, True, (ex + 108, ey - 4), 34)
        fly(frame + 1, True, (bed[0] + 18, bed[1] - 44), 14)
    bees.append(mini(frame + 2, True, "rest", (bed[0] - 26, bed[1] - 24)))
    bees.append(mini(frame + 5, False, "rest", (bed[0] + 26, bed[1] - 14)))
    # coming home high, from over the hut
    fly(frame + 2, True, (ex + 74, ey - 112), 36)
    fly(frame + 5, True, (ex + 50, ey - 68), 27)
    return bees, shades


PETALS = (                        # (petal, lit petal): pink blossom, cream, pale coin yellow
    (BLOSSOM[1], BLOSSOM[0]), (bh.CREAM, SW["coin_pale"]), (SW["coin_lit"], SW["coin_pale"]),
    (BLOSSOM[2], BLOSSOM[1]))


def flower_patch(seed=3, w=44, h=18, heads=26):
    """A dense patch of bright flowers for the bees to work, at one world px an art px: leafy
    tufts in the leaf ramp under heads of five pixels (a coin-gold heart, four petals, the top
    right one lit), pink, cream and pale yellow. Pale enough to read on the lawn at real scale,
    where the pack's beds read as weeds. Returns an image whose bottom middle is its foot."""
    rng = random.Random(seed)
    a = bh.Art(w, h)
    cx, cy = w / 2.0, h - 7.0
    for _ in range(80):                                   # the leaves
        x, y = rng.uniform(1, w - 2), rng.uniform(4, h - 1)
        if ((x - cx) / (w / 2.0)) ** 2 + ((y - cy) / 6.6) ** 2 > 1.0:
            continue
        a.px(x, y, LEAF[3])
        a.px(x, y - 1, LEAF[2])
        a.px(x + (1 if rng.random() < 0.5 else -1), y - 1, LEAF[1] if x > cx else LEAF[2])
    spots = []
    tries = 0
    while len(spots) < heads and tries < 2000:
        tries += 1
        x, y = rng.randint(2, w - 3), rng.randint(2, h - 5)
        if ((x - cx) / (w / 2.0 - 1.5)) ** 2 + ((y - cy + 2) / 6.4) ** 2 > 1.0:
            continue
        if all(abs(x - u) + abs(y - v) >= 4 for u, v in spots):
            spots.append((x, y))
    for x, y in sorted(spots, key=lambda t: t[1]):
        petal, lit = PETALS[rng.randrange(len(PETALS))]
        a.px(x, y + 2, LEAF[3])                            # the stem
        for dx, dy in ((-1, 0), (0, 1), (1, 0), (0, -1)):
            a.px(x + dx, y + dy, petal)
        a.px(x + 1, y - 1, lit) if rng.random() < 0.0 else None
        a.px(x, y - 1, lit)
        a.px(x + 1, y, lit)
        a.px(x, y, SW["coin_shade"])
    return a.im


def bed_items(opt):
    out = []
    for name, at in LAYOUT[opt]["bed"]:
        im = flower_patch() if name == "patch" else flora_piece(name)
        out.append({"im": im, "at": at, "anchor": (im.width // 2, im.height - 1), "z": at[1]})
    return out


def shrub_item(opt, swarm=False, blossom=True):
    im, foot, hang, standing, aloft = shrub(blossom=blossom, swarm=swarm)
    at = LAYOUT[opt]["shrub"]
    return {"im": im, "at": at, "anchor": foot, "z": at[1], "hang": hang,
            "shade": shade_of(standing, aloft, foot[1])}


def swarm_bees(tree, hive, frame=0):
    """The swarm's loose bees, flying round the hanging mass, and two scouts at the empty hive's
    door: every one with its blot on the lawn."""
    hx, hy = plate_of(tree, tree["hang"])
    foot_y = tree["at"][1]
    bees, shades = [], []
    for k, (dx, dy, left) in enumerate(((-30, 22, True), (44, 12, False), (30, 60, True))):
        at = (hx + dx, hy + dy)
        b, sh = flyer(frame + 2 * k, left, at, (foot_y - at[1]) / G)
        bees.append(b)
        shades.append(sh)
    g = hive["g"]
    ex, ey = plate_of(hive, g.entrance())
    for f, left, at, alt in ((frame + 1, True, (ex + 24, ey - 14), 19),
                             (frame + 4, False, (ex - 26, ey - 44), 34)):
        b, sh = flyer(f, left, at, alt)
        bees.append(b)
        shades.append(sh)
    return bees, shades


def ready_overlay(hive, frame=0):
    g = hive["g"]
    rx, ry = plate_of(hive, g.ready_at())
    im, mid = ready_mark()
    bob = (0, -2, -2, 0, 2, 2)[frame % 6]
    return [(im, (rx, ry - 8 + bob), mid)]


def scene(opt, state, jars=None, frame=0, with_bees=True, away=None):
    """The plate with option `opt`'s hive and jars in `state`. Returns (plate, hive item,
    bees). The ready state moves the angler out of the hive's reach (`away`): in reach the
    game shows the key chip, not the ready mark."""
    jars = STATE_JARS[state] if jars is None else jars
    away = (state == "ready") if away is None else away
    hive = hive_item(opt, state, jars)
    items = [hive]
    piece = piece_item(opt, state, jars)
    if piece:
        items.append(piece)
    tree = shrub_item(opt, swarm=state == "swarm", blossom=state != "empty")
    items.append(tree)
    if away:
        items.append(angler_item(ANGLER_AWAY))
    bees, shades = [], []
    if state == "swarm":
        bees, shades = swarm_bees(tree, hive, frame)
    if state in ("busy", "ready"):
        items += bed_items(opt)
        bees, shades = commuters(opt, hive, frame)
    if state == "ready":
        bees += ready_overlay(hive, frame)
    if not with_bees:
        bees, shades = [], []
    out = compose(base_plate(away), items, bees, angler_front=not away, bee_shades=shades)
    return out, hive, bees


# =============================================================================================
# The sheet
# =============================================================================================
CROP = (150, 64, 714, 440)          # plate px: the hive, its jars, the angler and the hut's corner
BOTTOM_THIRD = CROP[1] + (CROP[3] - CROP[1]) * 2 // 3
LADDER_BOX = (132, 150)             # plate px, every ladder crop the same size (shown 3x)
DETAIL_BOX = (110, 150)             # plate px, the entrance / swarm / ready crops (shown 3x)
STATE_TITLES = {
    "empty": "weathered and empty (0 jars)",
    "swarm": "the swarm on its tree (0 jars)",
    "busy": "colony busy, window half full (6 jars)",
    "ready": "honey ready, window full + mark (12 jars, angler out of reach)",
}
OPTIONS = {
    "A": ("HONEY HUTCH",
          "A small cabinet in the hive's sky blue behind-left of it, 11 art px clear of its "
          "eave: three oak shelves of four on a deep-blue back, a low oak hood (the coral stays "
          "the hive's), about 0.6 of the hive's height; the count reads in rows of four."),
    "B": ("HONEY TABLE",
          "A low oak table on sky-blue legs front-left of the hive: two rows of six along it, "
          "the back row on a 4 px riser, each back jar over the gap between two front ones with "
          "riser showing under it, so every lid and body is clear; low, but long."),
    "C": ("JARS IN THE STAND",
          "Compact: the stand is a painted cupboard, two shelves on each seen face, three jars "
          "a shelf. One object and nothing new on the lawn, but it costs the hive a lift (two "
          "lifts, not three, so it stands shorter) and the jars sit at the door, so the bees' "
          "stream has to leave it upwards, over the gable, and come down onto the bed."),
}


def _even(b):
    return (b[0] // 2 * 2, b[1] // 2 * 2, (b[2] + 1) // 2 * 2, (b[3] + 1) // 2 * 2)


def centred(c, size):
    x0 = int(round(c[0] - size[0] / 2.0)) // 2 * 2
    y0 = int(round(c[1] - size[1] / 2.0)) // 2 * 2
    return (x0, y0, x0 + size[0], y0 + size[1])


def jar_centre(opt):
    """The middle of what differs between 0 and 12 jars."""
    a = np.array(scene(opt, "busy", 0, with_bees=False, away=False)[0]).astype(int)
    b = np.array(scene(opt, "busy", 12, with_bees=False, away=False)[0]).astype(int)
    ys, xs = np.nonzero(np.abs(a - b).sum(2) > 0)
    return ((xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0)


def hive_size():
    """(width, height) of the new hive's picture and of today's, art px."""
    im, _ = draw_hive("colony", 0.5)
    bb = im.getbbox()
    j = json.load(open(os.path.join(look.ROOT, "assets/hive.json")))
    sheet = Image.open(os.path.join(look.ROOT, "assets/hive.png")).convert("RGBA")
    x, y, w, h = j["frames"]["hive_colony"]
    ob = sheet.crop((x, y, x + w, y + h)).getbbox()
    return (bb[2] - bb[0], bb[3] - bb[1]), (ob[2] - ob[0], ob[3] - ob[1])


def today_row(width):
    ims = [panel(look.plate(name).crop(CROP), "today: " + name) for name in STATES]
    (nw, nh), (ow, oh) = hive_size()
    note = look.text_block(
        "Today's island hive is %d x %d art px, a head over the angler (44 tall), its jars on two "
        "fence rails behind it. The new hive is %d x %d (%.2fx, %.2fx) at the island art's grain: "
        "one world px an art px, two plate px here, like the hut, the angler and the pack plants."
        % (ow, oh, nw, nh, nw / ow, nh / oh), 1800, 18, "text", look.INK)
    return stack([flow(ims, width, 12), note], "v", 10)


def bottom_count(bees):
    return sum(1 for im, at, anchor in bees if at[1] > BOTTOM_THIRD and im.width <= 16)


def locator(img, boxes):
    """The busy scene at half size (one px an art px) with the zoom crops marked: the marks
    live here, never on the real-scale panels."""
    c = img.crop(CROP)
    small = c.resize((c.width // 2, c.height // 2), Image.NEAREST)
    d = ImageDraw.Draw(small)
    for name, b in boxes:
        x0, y0 = (b[0] - CROP[0]) // 2, (b[1] - CROP[1]) // 2
        x1, y1 = (b[2] - CROP[0]) // 2, (b[3] - CROP[1]) // 2
        d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=look.MARK, width=1)
        d.text((x0 + 2, y0 + 1), name, font=look.font(11, "bold"), fill=look.MARK)
    return small


def option(opt, width):
    plates = {st: scene(opt, st) for st in STATES}
    jc = jar_centre(opt)
    jb = centred(jc, LADDER_BOX)
    ladder = []
    for n in (0, 3, 6, 12):
        im = scene(opt, "busy", n)[0]
        ladder.append(panel(look.crop_zoom(im, jb, 3), "3x: %d jars, bees in" % n))
    im, hive, bees = plates["busy"]
    ex, ey = plate_of(hive, hive["g"].entrance())
    eb = centred((ex + 12, ey - 4), DETAIL_BOX)
    det = [panel(look.crop_zoom(im, eb, 3), "3x: the door, slot clear, stream out")]
    sim, _, _ = plates["swarm"]
    tree = shrub_item(opt, swarm=True)
    hx, hy = plate_of(tree, tree["hang"])
    sb = centred((hx - 10, hy + 42), DETAIL_BOX)
    det.append(panel(look.crop_zoom(sim, sb, 3), "3x: the swarm, its shadow apart"))
    rim, rhive, _ = plates["ready"]
    g = rhive["g"]
    rx, ry = plate_of(rhive, g.ready_at())
    wx, wy = plate_of(rhive, (g.cx + WIN_FROM + 8, g.wall_top(g.cx + WIN_FROM + 8) + 18))
    rb = centred(((rx + wx) / 2.0 + 4, (ry - 32 + wy + 22) / 2.0), DETAIL_BOX)
    det.append(panel(look.crop_zoom(rim, rb, 3), "3x: the ready mark, the full window"))
    loc = locator(im, [("jars", jb), ("door", eb), ("swarm", sb), ("ready", rb)])
    states = [panel(plates[st][0].crop(CROP), "real scale: " + STATE_TITLES[st])
              for st in STATES]
    row1 = stack(states + [panel(loc, "where the crops are")], "h", 12)
    row2 = stack(ladder + det, "h", 12)
    body = stack([row1, row2], "v", 14)
    name, cap = OPTIONS[opt]
    print(opt, "bees in the bottom third (busy, ready):", bottom_count(plates["busy"][2]),
          bottom_count(plates["ready"][2]))
    return look.option_block(opt, name, cap, body, recommended=opt == RECOMMEND, width=width)


SUBTITLE = (
    "Richard's brief (2026-10-16): the island hive grows about 1.4x, keeps its sky-blue paint, and "
    "its jars show what the player holds, one by one, up to twelve. Every scene is drawn on the real "
    "capture (tools/last_hive_busy.png with the old hive, shelf, shrub and bees taken off and the "
    "lawn laid back) at its measured grain, 2 plate px an art px; every sprite is inked in "
    "(24,18,17), day-tinted like the capture, and throws its shadow down-left in the land ink. The "
    "bees are look.mini_round, the round lake bee. Real-scale panels are clean: the crops are "
    "marked on the small map at the end of each option's first row.")
NOTES = (
    "Second pass, off the art director's review: the bees are the round lake bee (look.mini_round, "
    "shared with the honey sheet) and every flyer is up in the air with its blot on the lawn "
    "(Shade.drop: 0.55 left, 0.35 down a px of height), at most three in the bottom third; one "
    "stream from the slot to a bright bed and two coming home high; the slot's middle stays "
    "clear, one bee walks out of it, one rests on the stand's ledge; the honey window is a tall "
    "inked pane whose honey rises in four steps under a pale meniscus (a glint when full); the "
    "swarm is one lumpy teardrop with a single outline on a bough 33 px up a young tree, its "
    "shadow apart from the tree's; weathered paint hangs on in 2-4 px patches along the seams; "
    "the ready mark's drop keeps its ring and its stars are inked; the ready panel's angler "
    "stands out of reach (in reach the game shows the key chip). Colours: build_hive's paint, "
    "roof, trim and weathered ramps, the oak and honey ramps, the room jar's gingham and label, "
    "the pack plants (flora.png), look.SW for the bees and stars. Script: "
    "tools/hive_look/island_mockup.py, module tools/hive_look/look.py.")


def main():
    width = SHEET_WIDE
    today = stack([look.text_block("TODAY", 400, 26, "label"), today_row(width)], "v", 8)
    opts = [today] + [option(o, width) for o in "ABC"]
    look.sheet("THE ISLAND HIVE: 1.4X, JARS ONE BY ONE", opts, OUT_PATH, subtitle=SUBTITLE,
               notes=NOTES)
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

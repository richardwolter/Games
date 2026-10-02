#!/usr/bin/env python
"""The hive room, second pass (2026-09-30, Richard's redesign off the first mockup).

    PYTHONPATH=<psd-extract venv site-packages> python tools/hive_mockup2.py

Writes tools/last_hive_mockup2.png (a contact sheet) and every frame full size as
tools/last_hive_mockup2_<name>.png. A picture to judge; nothing in the game reads it.

What changed against tools/hive_mockup.py: no hands anywhere (the cursor holds the tools),
catch is dragging clumps out of the air into the box, smoke is three rings over the swarm,
the queen hides in a crowd on a frame stood in a wooden rest, uncap pours into the bucket,
and the crank is gone: the pour is a turned handle over a gate. Five steps, not six.

Drawing helpers come from build_hive.py and hive_mockup.py, both untouched.
"""
import math
import random

from PIL import Image, ImageDraw, ImageFont

import hive_mockup as hm
from build_hive import (
    Art, BEE_GOLD, BEE_KEY, BEE_STRIPE, BRASS, CELL_BIG, CREAM, DARK_WOOD, DARK_WOOD_HI,
    DARK_WOOD_LO, ENAMEL, FRAME_DEEP, GINGHAM_PINK, GINGHAM_RED, GINGHAM_WHITE, GOLD, HONEY,
    HONEY_DEEP, HONEY_LIGHT, HONEY_MID, HONEY_SHINE, NOTE_OUTER, OUT, PAINTS, PAPER, PAPER_EDGE,
    PAPER_HEAD, PAPER_INK, PINE, PINE_DEEP, PINE_LIT, PINE_SHADE, SAFE, STEEL, TRIM, WING,
    WING_EDGE, bee, bee_mass, big, bottling, brood_frame, catch_box, fade, hot_knife, inked,
    mix, room_hive, smoker, sprite, star, wax_sheet)

RW, RH, RS = hm.RW, hm.RH, hm.RS
FONT = hm.FONT
OUT_SHEET = "tools/last_hive_mockup2.png"
STEPS = ["Catch", "Smoke", "Queen", "Uncap", "Pour"]

CURSOR = Image.open("assets/cursor.png").convert("RGBA")
CURSOR = CURSOR.resize((CURSOR.width // 2, CURSOR.height // 2), Image.NEAREST)   # 2x -> art grid
TIP = (1, 1)                                       # Pad.CURSOR_TIP over the baked scale

SMOKE_T = ((252, 252, 250), (224, 230, 234), (188, 196, 206), (150, 158, 172))
GLASS_EDGE = (92, 124, 138, 255)
GLASS = (206, 232, 238, 70)
GLASS_HI = (255, 255, 255, 200)


def cursor(a, x, y):
    """The game's wooden arrow, its tip on (x, y)."""
    a.paste(CURSOR, x - TIP[0], y - TIP[1])


# --- the room frame, with the five steps ----------------------------------------------------
class Room(hm.Room):
    def __init__(self, step, card, head, state="clean", count=None):
        super().__init__(step, card, head, state=state)
        self.count = count

    def finish(self):
        hm.STEPS = STEPS
        if self.count:
            self.card_words = self.card_words + "   " + self.count
        return super().finish()


def cloud_bees(a, cx, cy, rx, ry, n, seed, trail=True):
    """A loose cloud of flying bees, thick in the middle, each with a whisk of wing blur
    behind it the way it is heading."""
    rng = random.Random(seed)
    for _ in range(n):
        r = abs(rng.gauss(0, 0.5))
        ang = rng.uniform(0, math.tau)
        x = cx + math.cos(ang) * rx * r
        y = cy + math.sin(ang) * ry * r
        left = rng.random() < 0.5
        if trail:
            for k in range(1, 4):
                a.px(x + (9 + k if left else -k), y + 3 + rng.choice([0, 0, 1]), fade(TRIM, 110 - k * 30))
        a.paste(bee(facing_left=left, wings_up=rng.random() < 0.5), x, y)


def blob_clump(tall, seed, count):
    return bee_mass(lambda t: tall * 0.42 * math.sin(math.pi * (0.06 + 0.88 * t)) + 3, tall, seed, count)


# --- smoke that curls ------------------------------------------------------------------------
def soft_puff(a, x, y, r, seed, alpha=1.0):
    """A billow: a few overlapping lobes, lit top-left in four tones, its rim broken into a
    checker of whole pixels rather than faded, so it stays pixel art."""
    rng = random.Random(seed)
    lobes = [(x, y, r)] + [(x + rng.uniform(-0.7, 0.7) * r, y + rng.uniform(-0.6, 0.3) * r,
                            r * rng.uniform(0.45, 0.75)) for _ in range(4)]
    x0, x1 = int(x - r * 1.8), int(x + r * 1.8)
    y0, y1 = int(y - r * 1.8), int(y + r * 1.4)
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            best = 9
            for lx, ly, lr in lobes:
                best = min(best, math.hypot(xx - lx, (yy - ly) * 1.1) / lr)
            if best > 1:
                continue
            if best > 0.82 and (xx + yy) % 2:
                continue
            # light from the top left, over the whole billow
            lit = ((xx - x) + (yy - y) * 1.2) / (r * 1.4) + best * 0.3
            tone = SMOKE_T[0] if lit < -0.45 else SMOKE_T[1] if lit < 0.15 else SMOKE_T[2] if lit < 0.6 else SMOKE_T[3]
            al = 235 * alpha * (0.72 if best > 0.82 else 1.0)
            a.px(xx, yy, tone + (int(al),))


def smoke_path(a, start, end, seed, n=11):
    """Smoke from the nozzle to a ring: billows growing and thinning along a curl, older
    wisps drifting up off it."""
    rng = random.Random(seed)
    sx, sy = start
    ex, ey = end
    for k in range(n):
        t = k / (n - 1)
        x = sx + (ex - sx) * t + math.sin(t * math.pi * 2.2) * 10 * t
        y = sy + (ey - sy) * t - math.sin(t * math.pi) * 18 + math.cos(t * math.pi * 3) * 5
        soft_puff(a, x, y, 5 + t * 14, seed + k, 0.95 - t * 0.3)
    # curls: a pale spiral line peeling off the top of the stream
    for c in range(3):
        t = 0.3 + c * 0.25
        cx = sx + (ex - sx) * t
        cy = sy + (ey - sy) * t - math.sin(t * math.pi) * 18 - 14 - c * 3
        for s in range(40):
            ang = s / 40 * math.tau * 1.3
            rr = 3 + s * 0.18
            a.px(cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.8, SMOKE_T[1] + (170 - s * 3,))
    # older puffs, drifting up and away
    for k in range(5):
        x = sx + (ex - sx) * rng.uniform(0.2, 0.9) + rng.randint(-10, 10)
        y = min(sy, ey) - 50 - k * 14
        soft_puff(a, x, y, rng.randint(5, 9), seed + 50 + k, 0.35 - k * 0.04)


def ring(a, cx, cy, rx, ry, state, t=0.0):
    """A target over the swarm. todo: a faint dashed ring. now: gold, doubled, glowing. done:
    a green filled ring with a star."""
    if state == "now":
        halo = Art(RW, RH)
        for g in range(6, 0, -1):
            halo.ell(cx - rx - g * 2, cy - ry - g, (rx + g * 2) * 2, (ry + g) * 2, fade(GOLD, 14))
        a.paste(halo.im, 0, 0)
    for s in range(120):
        ang = s / 120 * math.tau
        x, y = cx + math.cos(ang) * rx, cy + math.sin(ang) * ry
        if state == "todo":
            if s % 6 < 3:
                a.rect(x, y, 2, 2, fade(CREAM, 170))
        elif state == "now":
            a.rect(x - 1, y - 1, 3, 3, OUT)
            a.rect(x, y, 2, 2, GOLD if s % 10 else HONEY_SHINE)
        else:
            a.rect(x - 1, y - 1, 3, 3, OUT)
            a.rect(x, y, 2, 2, SAFE)
    if state == "now":
        # the fill: a sweep of gold round the ring, a third of the way round
        for s in range(40):
            ang = -math.pi / 2 + s / 120 * math.tau
            for w in range(3):
                a.px(cx + math.cos(ang) * (rx - 4 - w), cy + math.sin(ang) * (ry - 3 - w), HONEY_LIGHT)
    if state == "done":
        star(a, cx + rx - 2, cy - ry + 2, 3)
        star(a, cx - rx + 4, cy - ry - 2, 2)


# --- 1  catch --------------------------------------------------------------------------------
def room_catch():
    r = Room(0, "the swarm into the box", "Drag")
    a = r.a
    rng = random.Random(21)
    # the box, open, glowing: the bees already in hum over its bars
    glow = Art(RW, RH)
    for w_, h_, al in ((240, 80, 26), (170, 56, 34), (120, 36, 44)):
        glow.ell(318 - w_ // 2, 254 - h_ // 2, w_, h_, fade(HONEY_LIGHT, al))
    a.paste(glow.im, 0, 0)
    a.ell(236, 300, 170, 16, (20, 30, 16, 110))
    box = catch_box(PAINTS["sky"], rng)
    a.paste(box, 244, 234)
    # the three clumps already caught: a mound of bees in the mouth
    # three clumps in: the box three fifths full, a heap of bees over its bars
    inside = bee_mass(lambda t: 52 * math.sin(math.pi * (0.04 + 0.92 * t)) ** 0.5 + 3, 24, 7, 260)
    a.paste(inside, 316 - inside.width // 2, 214)
    # its fill gauge on the front: five comb cells, three full of bees
    for k in range(5):
        cx_ = 278 + k * 18
        a.rect(cx_ - 1, 283, 14, 12, OUT)
        a.rect(cx_, 284, 12, 10, HONEY if k < 3 else (60, 40, 26, 255))
        if k < 3:
            a.rect(cx_ + 2, 286, 8, 2, BEE_STRIPE)
            a.rect(cx_ + 2, 290, 8, 2, BEE_STRIPE)
            a.rect(cx_, 284, 12, 1, HONEY_LIGHT)
    cloud_bees(a, 318, 236, 50, 14, 20, 3)
    # the swarm, still in the air: two drifting clouds, a clump in each
    for cx, cy, seed, n in ((130, 110, 11, 90), (512, 90, 12, 110)):
        cl = blob_clump(30, seed, 90)
        a.paste(cl, cx - cl.width // 2, cy - 10)
        cloud_bees(a, cx, cy, 70, 44, n, seed + 100)
    # the clump in hand: pulled down towards the box, bees streaming off behind it
    hx, hy = 356, 176
    trail = Art(RW, RH)
    for k in range(1, 7):
        t = k / 7
        tx, ty = hx + 90 * t, hy - 70 * t + math.sin(t * 3) * 8
        trail.ell(tx - 14 + k, ty - 6, 28 - k * 2, 16 - k, fade(HONEY_LIGHT, 70 - k * 9))
    a.paste(trail.im, 0, 0)
    cloud_bees(a, hx + 50, hy - 36, 40, 22, 28, 77)
    for k, al in ((3, 60), (2, 100), (1, 150)):
        g = blob_clump(34, 5, 120)
        g.putalpha(g.getchannel("A").point(lambda v, al=al: v * al // 255))
        a.paste(g, hx - g.width // 2 + 26 * k, hy - 18 - 20 * k)
    held = blob_clump(34, 5, 120)
    a.paste(held, hx - held.width // 2, hy - 18)
    for k in range(4):
        star(a, hx - 30 + k * 20, hy - 20 + (k % 2) * 36, 1 + k % 2, col=HONEY_LIGHT)
    cursor(a, hx + 6, hy + 2)
    # where to let go: a dashed arrow down into the box
    for k in range(6):
        a.rect(hx - 20 - k * 3, hy + 30 + k * 5, 2, 3, fade(GOLD, 200))
    hm.near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


# --- 2  smoke --------------------------------------------------------------------------------
def room_smoke():
    r = Room(1, "the rings until the bees settle", "Smoke")
    a = r.a
    hive, entrance = room_hive(PAINTS["sky"], window=0.35)
    hx, hy = 150, 96
    a.ell(hx + 10, hy + 196, 160, 18, (20, 30, 16, 110))
    a.paste(hive, hx, hy)
    ex, ey = hx + entrance[0], hy + entrance[1]
    # the swarm hangs over the hive's face, thick
    mass = bee_mass(lambda t: 58 * (0.55 + 0.45 * math.sin(math.pi * min(1, t * 1.1))) * (1 - t ** 3) + 4, 100, 41, 420)
    a.paste(mass, hx + 86 - mass.width // 2, hy + 24)
    cloud_bees(a, hx + 86, hy + 60, 110, 70, 90, 9)
    # three rings: left done, middle now, right to come
    rings = [(hx + 52, hy + 70, "done"), (hx + 112, hy + 58, "now"), (hx + 92, hy + 118, "todo")]
    # under the done ring the bees have gone quiet and walk in a file to the entrance
    calm = Art(RW, RH)
    calm.ell(rings[0][0] - 26, rings[0][1] - 18, 52, 36, (60, 40, 26, 90))
    a.paste(calm.im, 0, 0)
    for k in range(9):
        a.paste(bee(facing_left=False, turn=1 if k % 3 == 0 else 0, wings_up=False),
                rings[0][0] - 20 + (k % 3) * 12, rings[0][1] - 12 + (k // 3) * 9)
    for k in range(12):
        t = k / 11
        a.paste(bee(facing_left=False, wings_up=False), rings[0][0] - 6 + (ex - 30 - rings[0][0]) * t * 0 + k * 6 - 4,
                rings[0][1] + 22 + (ey - rings[0][1] - 22) * t)
    for k in range(7):
        a.paste(bee(facing_left=k % 2 == 1, wings_up=False), ex - 40 + k * 11, ey + 3 + (k % 2))
    for x_, y_, st in rings:
        ring(a, x_, y_, 24, 17, st)
    # near the lit ring, bees slowing: wings folded, a sleepy 'z' of haze
    for k in range(10):
        ang = k / 10 * math.tau
        a.paste(bee(facing_left=math.cos(ang) > 0, wings_up=False),
                rings[1][0] + math.cos(ang) * 16 - 4, rings[1][1] + math.sin(ang) * 10 - 3)
    # the smoker, held free by the cursor on its bellows
    sm = smoker()
    sx, sy = 352, 168
    tip = (sx + 15, sy + 19)
    smoke = Art(RW, RH)
    smoke_path(smoke, tip, (rings[1][0] + 6, rings[1][1]), 5, n=16)
    a.paste(sm, sx, sy)
    a.paste(smoke.im, 0, 0)
    # a pump: the bellows squeezed, three short press lines
    for k in range(3):
        a.rect(sx + 100 + k * 3, sy + 44 + k * 6, 6, 1, fade(TRIM, 200))
    cursor(a, sx + 92, sy + 50)
    hm.near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


# --- the uncapping rest ----------------------------------------------------------------------
def rest(a, fx, fy, fw, fh):
    """A wooden uncapping rest: two splayed plank legs, a cross bar, notches the frame's ears
    sit in. The pine of the hive's frames."""
    art = Art(RW, RH)
    top = fy + 4
    foot = min(fy + fh + 70, 300)
    for side in (-1, 1):
        x_top = fx + (4 if side < 0 else fw + 16)
        x_foot = x_top + side * 26
        art.poly([(x_top, top), (x_top + 10, top), (x_foot + 10, foot), (x_foot, foot)], PINE)
        art.poly([(x_top, top), (x_top + 3, top), (x_foot + 3, foot), (x_foot, foot)], PINE_LIT)
        art.poly([(x_top + 8, top), (x_top + 10, top), (x_foot + 10, foot), (x_foot + 8, foot)], PINE_SHADE)
        art.rect(x_top - 3, top - 4, 16, 6, PINE_DEEP)
        art.rect(x_top - 3, top - 4, 16, 2, PINE)
    bar = fy + fh + 30
    art.rect(fx - 20, bar, fw + 66, 7, PINE)
    art.rect(fx - 20, bar, fw + 66, 2, PINE_LIT)
    art.rect(fx - 20, bar + 5, fw + 66, 2, PINE_SHADE)
    for x in (fx - 12, fx + fw + 40):
        art.rect(x, bar + 2, 2, 2, DARK_WOOD_LO)
    a.ell(fx - 40, foot - 6, fw + 106, 12, (20, 30, 16, 100))
    a.paste(inked(art.im.crop((0, 0, RW, RH))), -1, -1)


# --- 3  queen --------------------------------------------------------------------------------
QUEEN_LONG = ["...kgkgkg.....", ".gkgkgkgkgtt..", "gkgkgkgkgktth.", ".gkgkgkgkgtt..", "...kgkgkg....."]


def queen_bee():
    body = inked(sprite(QUEEN_LONG, BEE_KEY))
    im = Image.new("RGBA", (body.width, body.height + 1), (0, 0, 0, 0))
    im.alpha_composite(body, (0, 1))
    for x in (9, 10, 11):
        im.putpixel((x, 1), WING)
    return im


def room_queen():
    r = Room(2, "the queen", "Find")
    a = r.a
    fw, fh = 300, 176
    frame = brood_frame(fw, fh, seed=9, cell=CELL_BIG)
    fx, fy = RW // 2 - frame.width // 2, 44
    rest(a, fx, fy, fw, fh)
    a.paste(frame, fx, fy)
    rng = random.Random(4)
    qx, qy = fx + 13 + int(fw * 0.63), fy + int(fh * 0.58)
    spots = []
    tries = 0
    while len(spots) < 330 and tries < 40000:
        tries += 1
        x = rng.randint(fx + 22, fx + fw - 4)
        y = rng.randint(fy + 12, fy + fh - 12)
        if abs(x - qx) < 9 and abs(y - qy) < 5:
            continue
        if any(abs(x - px_) < 7 and abs(y - py_) < 4 for px_, py_ in spots):
            continue
        spots.append((x, y))
    for x, y in sorted(spots, key=lambda p: p[1]):
        a.paste(bee(facing_left=rng.random() < 0.5, turn=rng.choice([0, 0, 0, 1, 3]),
                    wings_up=rng.random() < 0.2), x - 4, y - 3)
    q = queen_bee()
    a.paste(q, qx - q.width // 2, qy - q.height // 2)
    # two bees half over her, so she has to be looked for
    a.paste(bee(facing_left=True, wings_up=False), qx + 2, qy - 5)
    hm.lens(a, qx - 10, qy - 4, radius=30)
    cursor(a, qx - 10 + 21 + 26, qy - 4 + 21 + 26)
    hm.near_flowers(a, [(150, 280, 490, 380)])
    return r.finish()


# --- honey that runs -------------------------------------------------------------------------
def curtain(a, x, y0, y1, w0, w1, seed, bead=True):
    """A glossy sheet of honey: thick, wobbling at its edges, dark down its left, a bright
    gloss streak a third of the way in, a fat bead gathering at its foot."""
    rng = random.Random(seed)
    ph = rng.uniform(0, 6)
    for y in range(int(y0), int(y1)):
        t = (y - y0) / max(1, y1 - y0)
        w = max(2, w0 + (w1 - w0) * t ** 0.8 + math.sin(y * 0.21 + ph) * 1.3)
        cx = x + math.sin(y * 0.06 + ph) * 1.5
        l, rr = int(round(cx - w / 2)), int(round(cx + w / 2))
        for xx in range(l, rr + 1):
            f = (xx - l) / max(1, rr - l)
            c = HONEY_DEEP if xx in (l, rr) else HONEY_MID if f < 0.2 else HONEY_SHINE if 0.3 < f < 0.4 else \
                HONEY_LIGHT if f < 0.55 else HONEY if f < 0.85 else HONEY_MID
            a.px(xx, y, c)
    if bead:
        bw = max(4, w1 + 3)
        by = y1 - 1
        a.ell(x - bw / 2 - 1, by - 1, bw + 2, bw + 3, HONEY_DEEP)
        a.ell(x - bw / 2, by, bw, bw + 1, HONEY)
        a.ell(x - bw / 2 + 1, by + 1, bw * 0.55, bw * 0.5, HONEY_LIGHT)
        a.px(x - bw / 4 + 1, by + 2, HONEY_SHINE)
        a.px(x - bw / 4 + 2, by + 2, HONEY_SHINE)


def honey_bucket(a, bx, by, level, landings=()):
    """The enamel bucket seen from a little above: its mouth an ellipse of honey with a
    gloss, coils where ropes land, a lip of enamel round it."""
    art = Art(110, 96)
    art.poly([(2, 10), (106, 10), (98, 90), (10, 90)], ENAMEL["base"])
    art.fill_by([(2, 10), (106, 10), (98, 90), (10, 90)],
                lambda x, y: ENAMEL["shade"] if x < 18 else ENAMEL["lit"] if 72 < x < 84 else None)
    art.rect(42, 40, 26, 16, CREAM)
    art.rect(42, 40, 26, 2, GINGHAM_RED)
    art.ell(1, 2, 106, 18, ENAMEL["lit"])
    art.ell(4, 4, 100, 14, ENAMEL["shade"])
    art.ell(6, 5 + (1 - level) * 3, 96, 12 - (1 - level) * 3, HONEY_MID)
    art.ell(8, 6 + (1 - level) * 3, 92, 9 - (1 - level) * 3, HONEY)
    art.rect(20, 8, 34, 1, HONEY_LIGHT)
    art.rect(26, 9, 14, 1, HONEY_SHINE)
    art.rect(70, 12, 18, 1, HONEY_LIGHT)
    im = inked(art.im)
    a.paste(im, bx, by)
    for lx in landings:
        for k, (w, dy) in enumerate(((16, 0), (11, -3), (6, -5))):
            a.d.ellipse([bx + lx - w // 2, by + 9 + dy, bx + lx + w // 2, by + 14 + dy],
                        outline=HONEY_LIGHT if k % 2 else HONEY_SHINE, width=1)
        a.px(bx + lx - 2, by + 5, HONEY_SHINE)


# --- 4  uncap --------------------------------------------------------------------------------
def room_uncap():
    r = Room(3, "the hot knife down the comb", "Slide")
    a = r.a
    fw, fh, cut = 300, 150, 84
    frame = brood_frame(fw, fh, seed=12, uncap_to=cut, cell=CELL_BIG)
    fx, fy = RW // 2 - frame.width // 2, 34
    bx, by = 452, 262
    gx0, gy0, gx1, gy1 = fx - 12, fy + fh + 10, fx + fw + 42, fy + fh + 44

    def gut(x):
        return gy0 + (x - gx0) * (gy1 - gy0) / (gx1 - gx0)
    rest(a, fx, fy, fw, fh)
    a.paste(frame, fx, fy)
    rng = random.Random(6)
    # the open face weeps: short runs down the cut cells
    for _ in range(9):
        x = rng.randint(fx + 30, fx + fw - 10)
        curtain(a, x, rng.randint(fy + 12, fy + cut - 30), fy + cut - rng.randint(4, 14), 3, 2, rng.random() * 99)
    # curtains off the blade's hot edge, down the capped face, off the frame, into the bucket
    ky = fy + cut - 8
    # the gutter's back wall and the honey running down inside it
    for x in range(gx0, gx1 + 1):
        y = gut(x)
        a.rect(x, y - 6, 1, 6, STEEL["deep"])
        a.rect(x, y - 4, 1, 4, HONEY_MID)
        a.px(x, y - 4, HONEY_LIGHT if (x // 5) % 4 else HONEY_SHINE)
    landings = [gx1 + 6 - bx]
    for k, (x, w0, w1) in enumerate(((fx + 70, 12, 8), (fx + 112, 18, 12), (fx + 150, 22, 14),
                                     (fx + 186, 14, 10), (fx + 224, 10, 7), (fx + 262, 8, 6))):
        curtain(a, x, ky + 14, gut(x) - 2, w0, w1, 40 + k, bead=False)
        for w in range(w1 + 6):         # where it lands, a fat splash of honey across the trough
            a.px(x - (w1 + 6) // 2 + w, gut(x) - 5, HONEY_LIGHT)
    # the gutter: tin, lit along its lip, running down to the right over the bucket
    art = Art(RW, RH)
    for x in range(gx0, gx1 + 1):
        y = gut(x)
        art.rect(x, y - 2, 1, 7, STEEL["base"])
        art.px(x, y - 2, STEEL["hi"])
        art.px(x, y - 1, STEEL["lit"])
        art.rect(x, y + 3, 1, 2, STEEL["shade"])
    art.rect(gx0 - 2, gut(gx0) - 7, 3, 12, STEEL["shade"])
    a.paste(inked(art.im.crop((0, 0, RW, RH))), -1, -1)
    # the honey rides down the gutter fatter than the tin: a rounded, glossy body bulging
    # over the rim, swelling where each curtain feeds it, spilling over the lip in places
    feeds = [fx + 70, fx + 112, fx + 150, fx + 186, fx + 224, fx + 262]
    for x in range(gx0 + 4, gx1 + 6):
        y = gut(x)
        swell = sum(4 * math.exp(-((x - f) / 14) ** 2) for f in feeds)
        tall = 5 + (x - gx0) / (gx1 - gx0) * 3 + swell + math.sin(x * 0.11) * 1.2
        top = y - 3 - tall
        foot = y + 2
        for yy in range(int(top), int(foot) + 1):
            d = (yy - top) / max(1, foot - top)
            c = HONEY_DEEP if yy == int(foot) else HONEY_SHINE if d < 0.14 else HONEY_LIGHT if d < 0.32 else                 HONEY if d < 0.7 else HONEY_MID
            a.px(x, yy, c)
        a.px(x, int(top) - 1, HONEY_DEEP)
        if int(x) % 9 in (0, 1, 2) and swell < 1:
            a.px(x, int(top) + 1, (255, 255, 244, 255))
    for k, x in enumerate((fx + 40, fx + 131, fx + 205, fx + 243, fx + 296)):
        curtain(a, x, int(gut(x)) + 2, int(gut(x)) + 8 + k % 3 * 5, 7, 3, 60 + k)
    # off the low end, a heavy rope: fat where it leaves, necking thin, a bead about to go,
    # and a thread from it down to the pool
    ex, ey = gx1 + 5, gut(gx1) + 1
    bead_y = by - 6
    for y in range(int(ey), bead_y):
        t = (y - ey) / max(1, bead_y - ey)
        w = 14 - 11 * math.sin(min(1, t * 1.15) * math.pi / 2) + 5 * max(0, t - 0.8) / 0.2
        l, rr = int(ex - w / 2), int(ex + w / 2)
        for xx in range(l, rr + 1):
            f = (xx - l) / max(1, rr - l)
            a.px(xx, y, HONEY_DEEP if xx in (l, rr) else HONEY_MID if f < 0.22 else
                 HONEY_SHINE if 0.28 < f < 0.45 else HONEY_LIGHT if f < 0.6 else HONEY)
    a.ell(ex - 7, bead_y - 3, 15, 14, HONEY_DEEP)
    a.ell(ex - 6, bead_y - 2, 13, 12, HONEY)
    a.ell(ex - 4, bead_y - 1, 6, 5, HONEY_LIGHT)
    a.rect(ex - 3, bead_y, 2, 2, HONEY_SHINE)
    a.rect(ex, bead_y + 10, 2, by + 12 - bead_y - 10, HONEY_MID)
    # the knife mid-slide, the capping lifting off it in one sheet, the cursor on its grip
    ghost = Art(RW, RH)
    for k, al in enumerate((110, 60, 30)):
        ghost.rect(fx + 20, ky - 8 - k * 6, fw - 16, 3, fade(STEEL["hi"], al))
    a.paste(ghost.im, 0, 0)
    blade = fw - 40
    kx = fx + 30
    a.paste(hot_knife(blade), kx, ky)
    sheet, (sx, sy) = wax_sheet(blade - 60)
    a.paste(sheet, kx + 1 - sx + 4, ky + 8 - sy)
    for _ in range(9):
        star(a, rng.randint(fx + 30, fx + fw - 30), rng.randint(ky - 18, ky - 6), rng.choice([1, 2, 3]))
    honey_bucket(a, bx, by, 0.7, landings)
    cursor(a, kx + blade + 22, ky + 10)
    hm.air_bees(a, 5, (fx, fy - 20, fx + fw, fy + 6), 13)
    hm.near_flowers(a, [(150, 250, 490, 380), (430, 220, 600, 380)])
    return r.finish()


# --- jars ------------------------------------------------------------------------------------
def jar2(fill=0.0, lid=False, label=False):
    """A glass jar: a thin blue-grey outline rather than the near-black, a faint tint, two
    highlight streaks, honey with a meniscus climbing the glass, a small gingham lid."""
    w, h = 34, 44
    a = Art(w + 4, h + 12)
    top = 10
    body = [(5, top + 4), (w - 5, top + 4), (w - 1, top + 9), (w - 1, top + h - 3), (w - 4, top + h),
            (4, top + h), (1, top + h - 3), (1, top + 9)]
    a.poly(body, GLASS)
    # the neck
    a.rect(6, top, w - 12, 5, (206, 232, 238, 110))
    a.rect(6, top + 1, w - 12, 1, fade(GLASS_EDGE, 140))
    a.rect(6, top + 3, w - 12, 1, fade(GLASS_EDGE, 140))
    if fill > 0:
        surface = int(top + h - 2 - (h - 12) * fill)

        def honey(x, y):
            climb = 2 if x in (2, w - 2) else 1 if x in (3, w - 3) else 0
            if y < surface - climb:
                return None
            if y <= surface - climb + 1:
                return HONEY_SHINE if 8 < x < w - 10 else HONEY_LIGHT
            f = (y - surface) / max(1, (top + h - surface))
            c = HONEY_LIGHT if f < 0.12 else HONEY if f < 0.55 else HONEY_MID
            return HONEY_MID if x < 5 else HONEY_DEEP if y >= top + h - 1 else c

        a.fill_by(body, honey)
    # outline in the glass's own colour
    a.line(body + [body[0]], GLASS_EDGE)
    a.rect(w - 8, top + 12, 2, h - 20, GLASS_HI)
    a.rect(w - 5, top + 14, 1, 8, fade(GLASS_HI, 150))
    a.rect(5, top + 14, 1, 6, fade(GLASS_HI, 120))
    if label:
        a.rect(8, top + 20, w - 16, 12, CREAM)
        a.rect(8, top + 20, w - 16, 1, GINGHAM_RED)
        a.rect(8, top + 31, w - 16, 1, GINGHAM_RED)
        hexa = [".xx.", "xhsx", "xhhx", ".xx."]
        a.paste(sprite(hexa, {"x": HONEY_MID, "h": HONEY, "s": HONEY_SHINE}), w // 2 - 2, top + 24)
    if lid:
        cloth = Art(w - 6, 8)
        for y in range(8):
            for x in range(w - 6):
                if y > 4 and (x < y - 4 or x > w - 7 - (y - 4)):
                    continue
                on = ((x // 2) % 2) + ((y // 2) % 2)
                cloth.px(x, y, GINGHAM_RED if on == 2 else GINGHAM_PINK if on == 1 else GINGHAM_WHITE)
        cloth.rect(2, 5, w - 10, 1, (120, 70, 40, 255))
        a.paste(inked(cloth.im), 2, top - 6)
    return a.im


# --- 5  pour ---------------------------------------------------------------------------------
def wheel(a, cx, cy, r, turn):
    """A brass handwheel, four spokes, turned `turn` radians, a wooden knob on its rim."""
    art = Art(RW, RH)
    for s in range(200):
        ang = s / 200 * math.tau
        for w in range(3):
            c = BRASS["lit"] if math.sin(ang + 2.3) > 0.3 else BRASS["shade"] if math.sin(ang + 2.3) < -0.4 else BRASS["base"]
            art.px(cx + math.cos(ang) * (r - w), cy + math.sin(ang) * (r - w), c)
    for k in range(4):
        ang = turn + k * math.pi / 2
        for d in range(r - 2):
            art.rect(cx + math.cos(ang) * d, cy + math.sin(ang) * d, 2, 2, BRASS["base"])
    art.ell(cx - 3, cy - 3, 7, 7, BRASS["lit"])
    kx, ky = cx + math.cos(turn) * r, cy + math.sin(turn) * r
    art.rect(kx - 3, ky - 3, 6, 6, DARK_WOOD)
    art.rect(kx - 3, ky - 3, 2, 6, DARK_WOOD_HI)
    a.paste(inked(art.im.crop((0, 0, RW, RH))), -1, -1)
    return kx, ky


def pointer_arrow(a, tipx, tipy):
    """A fat gold arrow from up-left, its point on the nozzle."""
    art = Art(RW, RH)
    ang = math.atan2(1, 1.4)
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    L, head, shaft, hw = 46, 16, 6, 13

    def P(u, v):
        return (tipx - ux * u + nx * v, tipy - uy * u + ny * v)

    art.poly([P(0, 0), P(head, hw), P(head, shaft), P(L, shaft), P(L, -shaft), P(head, -shaft), P(head, -hw)], GOLD)
    art.poly([P(2, 0), P(head, -hw + 3), P(head, -shaft), P(L - 2, -shaft), P(L - 2, -shaft + 3), P(head - 2, -shaft + 3)], HONEY_SHINE)
    a.paste(inked(art.im.crop((0, 0, RW, RH))), -1, -1)


def room_pour():
    r = Room(4, "the lever to pour, back at the line", "Turn")
    a = r.a
    stand, (sx0, sy0) = bottling()
    bx, by = RW // 2 - sx0, 40
    a.ell(bx - 10, by + 222, 150, 12, (20, 30, 16, 100))
    a.paste(stand, bx, by)
    gx, gy = bx + sx0, by + sy0          # where the honey leaves the gate
    # the handle over the gate, a third turned; a curved arrow saying which way
    # the gate's own lever, a brass flag on its pivot, turned sideways: open
    lv = Art(RW, RH)
    px_, py_ = gx + 1, gy - 12
    lv.ell(px_ - 4, py_ - 4, 9, 9, BRASS["shade"])
    lv.rect(px_, py_ - 3, 26, 6, BRASS["base"])
    lv.rect(px_, py_ - 3, 26, 2, BRASS["lit"])
    lv.rect(px_ + 20, py_ - 5, 10, 10, DARK_WOOD)
    lv.rect(px_ + 20, py_ - 5, 3, 10, DARK_WOOD_HI)
    lv.ell(px_ - 2, py_ - 2, 5, 5, BRASS["lit"])
    # where it rests shut: a faint ghost standing up
    ghost = Art(RW, RH)
    ghost.rect(px_ - 3, py_ - 26, 6, 24, fade(BRASS["lit"], 70))
    a.paste(ghost.im, 0, 0)
    a.paste(inked(lv.im.crop((0, 0, RW, RH))), -1, -1)
    for k in range(6):                   # the swing, a dotted quarter arc
        ang = -math.pi / 2 + k / 5 * math.pi / 2
        a.rect(px_ + math.cos(ang) * 32, py_ + math.sin(ang) * 32, 2, 2, fade(CREAM, 110 + k * 20))
    cursor(a, px_ + 25, py_ + 1)
    # the jar under the gate, filling
    j = jar2(fill=0.55)
    jx, jy = gx - j.width // 2, 230
    surface = jy + 10 + 44 - 2 - int(32 * 0.55)
    line_y = jy + 10 + 44 - 2 - int(32 * 0.88)
    halo = Art(RW, RH)
    halo.rect(jx - 8, line_y - 2, j.width + 16, 5, fade(GOLD, 60))
    a.paste(halo.im, 0, 0)
    a.paste(j, jx, jy)
    # the stream: thick, glossy, narrowing, then folding on itself where it lands
    for y in range(gy, surface - 3):
        t = (y - gy) / max(1, surface - gy)
        wide = int(12 - 5 * t ** 0.6)
        wob = round(math.sin(y * 0.2) * 0.8 * t)
        for x in range(wide):
            f = x / max(1, wide - 1)
            c = HONEY_DEEP if x in (0, wide - 1) else HONEY_MID if f < 0.25 else HONEY_SHINE if 0.3 < f < 0.5 else HONEY_LIGHT if f < 0.7 else HONEY
            a.px(gx - wide // 2 + x + wob, y, c)
    for k, (w, dy) in enumerate(((16, 0), (12, -3), (8, -6), (5, -8))):
        a.d.ellipse([gx - w // 2, surface - 3 + dy, gx + w // 2, surface + 2 + dy], outline=HONEY_DEEP, width=1)
        a.d.ellipse([gx - w // 2 + 1, surface - 3 + dy, gx + w // 2 - 1, surface + 1 + dy],
                    outline=HONEY_LIGHT if k % 2 else HONEY, width=1)
    a.px(gx - 2, surface - 8, HONEY_SHINE)
    for x in range(jx - 6, jx + j.width + 6, 4):
        a.rect(x, line_y, 2, 1, GOLD)
    # the row: an empty jar waiting on the left, a filled and lidded one done on the right
    a.paste(jar2(fill=0.0), gx - 120, jy)
    board = (gx + 70, jy + 56)
    a.rect(board[0] - 6, board[1], 110, 6, DARK_WOOD_HI)
    a.rect(board[0] - 6, board[1] + 5, 110, 3, DARK_WOOD_LO)
    a.paste(jar2(fill=0.88, lid=True, label=True), board[0], board[1] - 55)
    a.paste(jar2(fill=0.88, lid=True, label=True), board[0] + 46, board[1] - 55)
    for sx_, sy_, arm in ((board[0] + 42, board[1] - 50, 3), (board[0] + 84, board[1] - 44, 2),
                          (board[0] + 64, board[1] - 62, 2)):
        star(a, sx_, sy_, arm)
    hm.air_bees(a, 3, (RW // 2 - 90, 150, RW // 2 + 90, 200), 29)
    hm.near_flowers(a, [(150, 250, 490, 380)])
    return r.finish()


# --- 6  the ready card on the island -------------------------------------------------------
def ready_frame():
    lake = Image.open("tools/last_pump.png").convert("RGBA")
    # the probe's frame is 520 wide: shown whole at 2x, centred, the sides the sheet's own dark
    world = big(lake, 2)
    world.alpha_composite(hm.island_panel("full"), (0, 80))
    im = Image.new("RGBA", (1280, 720), hm.SHEET_BG)
    im.alpha_composite(world, ((1280 - world.width) // 2, 0))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 36)
    words = "The honey is ready!"
    tw = d.textlength(words, font=f)
    cw, ch = int(tw) + 100, 84
    cx, cy = 640, 628
    d.rectangle([cx - cw // 2 + 4, cy - ch // 2 + 6, cx + cw // 2 + 4, cy + ch // 2 + 6], fill=(0, 0, 0, 90))
    d.rectangle([cx - cw // 2 - 3, cy - ch // 2 - 3, cx + cw // 2 + 3, cy + ch // 2 + 3], fill=NOTE_OUTER)
    d.rectangle([cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2], fill=PAPER)
    d.rectangle([cx - cw // 2, cy + ch // 2 - 4, cx + cw // 2, cy + ch // 2], fill=PAPER_EDGE)
    d.text((cx, cy - 2), words, font=f, fill=PAPER_INK, anchor="mm")
    return im


# --- the sheet -------------------------------------------------------------------------------
FRAMES = [("catch", room_catch, "1  Catch", "Drag each clump out of the air into the box; 3 of 5 in."),
          ("smoke", room_smoke, "2  Smoke", "The smoker in the cursor; three rings, one done, one lit."),
          ("queen", room_queen, "3  Queen", "A frame in a wooden rest, ~190 bees; she is a longer bee."),
          ("uncap", room_uncap, "4  Uncap", "The knife slides; honey curtains fall into the bucket."),
          ("pour", room_pour, "5  Pour", "Turn the handle over the gate; filled, filling, empty."),
          ("ready", ready_frame, "Ready", "The island hive, full, and the moment's paper card.")]


def main():
    scale = 2                      # frames at half size on the sheet
    fw, fh = 1280 // scale, 720 // scale
    gap, head = 30, 70
    cols = 2
    rows = (len(FRAMES) + 1) // cols
    W = gap + cols * (fw + gap)
    H = 110 + rows * (fh + head + gap)
    sheet = Image.new("RGBA", (W, H), hm.SHEET_BG)
    d = ImageDraw.Draw(sheet)
    hm.heading(d, gap, 24, "THE HIVE ROOM  -  SECOND PASS", 34)
    hm.honey_rule(d, gap + 6, 84, W - gap * 2 - 12)
    written = []
    for i, (name, make, title, sub) in enumerate(FRAMES):
        im = make()
        path = "tools/last_hive_mockup2_%s.png" % name
        im.convert("RGB").save(path)
        written.append(path)
        x = gap + (i % cols) * (fw + gap)
        y = 110 + (i // cols) * (fh + head + gap)
        hm.heading(d, x, y, title, 22, CREAM)
        hm.note(d, x, y + 32, sub, 14, (190, 200, 186, 255))
        sheet.alpha_composite(im.resize((fw, fh), Image.LANCZOS), (x, y + head - 8))
        d.rectangle([x - 2, y + head - 10, x + fw + 1, y + head - 8 + fh + 1], outline=NOTE_OUTER, width=2)
    sheet.convert("RGB").save(OUT_SHEET)
    print(OUT_SHEET, *written)


if __name__ == "__main__":
    main()

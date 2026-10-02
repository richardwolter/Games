#!/usr/bin/env python
"""The beehive sidequest, drawn before any of it is built (2026-09-29, `/grill-me` with
Richard): the hive on the island in its four states, and the hive room's six minigames.

    <psd-extract venv python> tools/hive_mockup.py

Writes tools/last_hive_mockup_island.png and tools/last_hive_mockup_room.png. A static picture
to pick from; nothing in the game reads it. Shapes are drawn on whole art pixels and blown up
nearest, the words set in Bungee at the blown-up size, the way the boards draw them.

The island panels are drawn over tools/last_pump.png, a real frame of the island from
tools/shot_pump.tscn (one world pixel to one; an art pixel is two). The room's backdrop is
rebuilt from the wash room's own strips (assets/wash_bank.png, wash_lawn.png,
wash_clouds.png) on its 640x360 art grid, so it is the same view the pump gives.

The hive, the bees and every room piece are drawn by tools/build_hive.py, which bakes them for
the game; this file only lays them out into the two pictures. It renders pixel for pixel what
it did when the drawing still lived here (checked when the drawing moved, 2026-09-30).
"""
import json
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFont

from build_hive import (
    Art, BEE_GOLD, BEE_STRIPE, BOTTLING_BUCKET_AT, BOTTLING_GATE_AT, BRASS, CELL_BIG, CREAM,
    DARK_WOOD, DARK_WOOD_HI, DARK_WOOD_LO, FRAME, FRAME_DEEP, FRAME_LIT, FRAME_LOW, GINGHAM_RED,
    GOLD, HONEY, HONEY_LIGHT, HONEY_MID, HONEY_SHINE, NOTE_OUTER, OUT, PAINTS, PAL, PAPER,
    PAPER_EDGE, PAPER_HEAD, PAPER_INK, PINE, PINE_DEEP, PINE_LIT, RIBBON_INK, STEEL, TRIM, WAX_LIT,
    WAX_SHADE, WEATHERED, WING_EDGE, bee, bee_mass, big, bottling_bucket, bottling_gate,
    bottling_stand, branch_with_swarm, brood_frame, catch_box, crown, drip, extractor, fade, glove,
    hot_knife, inked, island_hive, island_swarm, jar, mix, pip, puff, ready_mark, room_hive,
    smoker, star, wax_sheet)

FONT = "assets/Bungee-Regular.ttf"
OUT_ISLAND = "tools/last_hive_mockup_island.png"
OUT_ROOM = "tools/last_hive_mockup_room.png"

SHEET_BG = (22, 34, 32, 255)


def darken(im, box, k):
    region = im.crop(box)
    tone = Image.new("RGBA", region.size, (int(255 * k), int(255 * k), int(255 * k), 255))
    im.paste(ImageChops.multiply(region, tone), box[:2])


FLORA = Image.open("assets/flora.png").convert("RGBA")
FLORA_RECTS = {k: v["full"] for k, v in json.load(open("assets/flora.json")).items()}


def flora(name):
    x, y, w, h = FLORA_RECTS[name]
    return FLORA.crop((x, y, x + w, y + h))


PROMPT_MOUSE = Image.open("assets/ui/prompts/mouse_click.png").convert("RGBA")
PROMPT_RT = Image.open("assets/ui/prompts/pad_rt.png").convert("RGBA")


def speck_bee(a, x, y, rng):
    """A bee at the island's grain, on a world-pixel canvas: two art pixels and a wing."""
    x, y = x // 2 * 2, y // 2 * 2
    a.rect(x, y, 2, 2, BEE_GOLD)
    a.rect(x + 2, y, 2, 2, BEE_STRIPE)
    a.rect(x + (0 if rng.random() < 0.5 else 2), y - 2, 2, 2, fade(WING_EDGE, 220))


def sparkles(a, box, n, seed):
    rng = random.Random(seed)
    for _ in range(n):
        star(a, rng.randint(box[0], box[2]), rng.randint(box[1], box[3]), rng.choice([1, 2, 2, 3]))


def island_panel(state, paint="sky"):
    world = Art(330, 280)
    world.paste(Image.open("tools/last_pump.png").convert("RGBA").crop((0, 40, 330, 320)), 0, 0)
    rng = random.Random(11 + len(state))
    grown = {"new": 0, "swarm": 9, "colony": 18, "full": 26}[state]
    spots = [("flower_yellow", 12, 232), ("tulip_pink", 104, 168), ("daisies", 70, 214),
             ("flower_blue", 20, 250), ("clover_pink", 128, 214), ("flower_pink", 296, 206),
             ("patch_yellow", 112, 244), ("flower_violet", 36, 238), ("tulip_red", 90, 180),
             ("patch_white", 300, 236), ("flower_red", 6, 262), ("clover_white", 56, 250),
             ("flower_orange", 312, 172), ("tulip_yellow", 124, 152), ("patch_red", 20, 116),
             ("flower_white", 58, 118), ("daisies", 276, 256), ("flower_blue", 104, 262),
             ("tulip_red", 36, 130), ("flower_pink", 108, 206), ("clover_pink", 80, 244),
             ("tulip_yellow", 64, 262), ("patch_blue", 88, 270), ("flower_yellow", 290, 186),
             ("tulip_pink", 60, 130), ("flower_orange", 128, 186)]
    flowers = []
    for name, x, y in spots[:grown]:
        f = flora(name)
        world.paste(big(f, 2), x, y - f.height * 2)
        flowers.append((x + f.width, y - f.height * 2 + 4))
    if state != "new":
        world.paste(big(flora("shrub_flowering"), 2), 0, 92)
    hive = island_hive(PAINTS[paint] if state in ("colony", "full") else WEATHERED,
                       {"new": "weathered", "swarm": "weathered", "colony": "colony", "full": "full"}[state],
                       jars=3 if state == "full" else 0)
    hx, hy = 10, 126
    world.paste(big(hive, 2), hx, hy)
    entrance = (hx + 70, hy + 56)
    bees = Art(330, 280)
    if state == "swarm":
        world.paste(big(island_swarm(), 2), 22, 106)
        for _ in range(12):
            speck_bee(bees, rng.randint(14, 54), rng.randint(96, 134), rng)
    if state in ("colony", "full"):
        # bees on their way to the flowers and back: faint dotted runs
        for fx, fy in flowers[::2]:
            ctrl = ((entrance[0] + fx) / 2 + rng.randint(-20, 20), min(entrance[1], fy) - 24)
            steps = 18
            for k in range(steps):
                t = k / steps
                x = (1 - t) ** 2 * entrance[0] + 2 * (1 - t) * t * ctrl[0] + t * t * fx
                y = (1 - t) ** 2 * entrance[1] + 2 * (1 - t) * t * ctrl[1] + t * t * fy
                if k % 3 == 0:
                    bees.rect(round(x) // 2 * 2, round(y) // 2 * 2, 2, 2, fade(HONEY_LIGHT, 170))
            t = rng.uniform(0.3, 0.8)
            x = (1 - t) ** 2 * entrance[0] + 2 * (1 - t) * t * ctrl[0] + t * t * fx
            y = (1 - t) ** 2 * entrance[1] + 2 * (1 - t) * t * ctrl[1] + t * t * fy
            speck_bee(bees, round(x), round(y), rng)
        for k in range(6 if state == "full" else 3):
            speck_bee(bees, entrance[0] - 4 + k * 4, entrance[1] + (k % 2) * 2, rng)
    world.paste(bees.im, 0, 0)
    if state == "full":
        glow = Art(330, 280)
        glow.ell(hx + 48, hy - 30, 30, 30, fade(GOLD, 60))
        glow.ell(hx + 52, hy - 26, 22, 22, fade(GOLD, 70))
        world.paste(glow.im, 0, 0)
        world.paste(big(ready_mark(), 2), hx + 54, hy - 24)
        world.rect(entrance[0] + 4, entrance[1] + 4, 2, 4, HONEY)
        world.rect(entrance[0] + 4, entrance[1] + 8, 2, 2, HONEY_LIGHT)
    return big(world.im, 2)


# --- the room: the view from the hive -------------------------------------------------------
RW, RH, RS = 640, 360, 2


def backdrop(state="clean", veil=0.82, sun=0.42, bank_off=150):
    a = Art(RW, RH, (0, 0, 0, 255))
    bank = Image.open("assets/wash_bank.png").convert("RGBA")
    lawn = Image.open("assets/wash_lawn.png").convert("RGBA")
    clouds = Image.open("assets/wash_clouds.png").convert("RGBA")
    contract = json.load(open("assets/wash_backdrop.json"))
    horizon = int(RH * 0.52)
    lake_top = horizon - 44
    bank_top = lake_top - bank.height
    open_sky = max(bank_top + int(bank.height * 0.12), 10)
    hi = mix(PAL["sky_morning_high"], PAL["sky_noon_high"], min(sun / 0.5, 1))
    lo = mix(PAL["sky_morning_low"], PAL["sky_noon_low"], min(sun / 0.5, 1))
    for k in range(5):
        y0 = open_sky * k // 5
        y1 = lake_top if k == 4 else open_sky * (k + 1) // 5
        a.rect(0, y0, RW, y1 - y0, mix(hi, lo, k / 4))
    for kind, i, x, y in (("far_clouds", 0, 150, 12), ("far_clouds", 2, 520, 8), ("clouds", 0, 20, 1),
                          ("clouds", 3, 300, 3), ("clouds", 1, 520, 0), ("wisps", 0, 430, 22)):
        bx, by, bw, bh = contract[kind][i]
        a.paste(clouds.crop((bx, by, bx + bw, by + bh)), x, y)
    ramp = [PAL["water_" + state + s] for s in ("_deep", "_mid", "", "_shallow", "_light")]
    bands = [[0.08, 3], [0.12, 2], [0.18, 1], [0.28, 0], [0.18, 1], [0.10, 2], [0.06, 3]]
    y = lake_top
    rows = []
    for k, (share, step) in enumerate(bands):
        tall = round(44 * share) if k < len(bands) - 1 else horizon - y
        a.rect(0, y, RW, tall, ramp[step])
        rows.append((y, y + tall, step))
        y += tall
    rng = random.Random(4177)
    for _ in range(80):
        sy = rng.randint(lake_top + 1, horizon - 2)
        step = next(s for y0, y1, s in rows if y0 <= sy < y1)
        a.rect(rng.randint(-20, RW), sy, rng.randint(5, 30), 1, ramp[min(step + 1, 4)])
    a.rect(0, lake_top, RW, 1, PAL["foam"])
    for x in range(0, RW, 28):
        a.rect(x, horizon - 1 + (1 if (x // 28) % 3 == 0 else 0), 28, 1, PAL["foam"])
    strip = Image.new("RGBA", (RW, bank.height))
    strip.paste(bank.crop((bank_off, 0, min(bank_off + RW, bank.width), bank.height)), (0, 0))
    if bank_off + RW > bank.width:
        strip.paste(bank.crop((0, 0, bank_off + RW - bank.width, bank.height)), (bank.width - bank_off, 0))
    a.paste(strip, 0, bank_top)
    a.paste(lawn.crop((0, 0, RW, min(lawn.height, RH - horizon))), 0, horizon)
    # the far lawn's own flowers, under the veil
    fr = random.Random(23)
    names = ["flower_yellow", "flower_white", "clover_pink", "daisies", "tulip_pink", "flower_blue",
             "flower_violet", "clover_white", "patch_yellow", "flower_orange"]
    for _ in range(46):
        f = flora(fr.choice(names))
        x, y = fr.randint(0, RW - 12), fr.randint(horizon + 14, 290)
        a.paste(f, x, y - f.height)
    darken(a.im, (0, bank_top, RW, RH), veil)
    return a


def near_flowers(a, keep_clear):
    """Big flowers along the near edge: two art pixels to one, the lawn's own near grain."""
    rng = random.Random(97)
    names = ["tulip_red", "tulip_yellow", "tulip_pink", "flower_pink", "flower_blue", "daisies",
             "flower_yellow", "flower_orange", "clover_pink", "shrub_flowering", "flower_white"]
    for _ in range(34):
        f = big(flora(rng.choice(names)), 2)
        x = rng.choice([rng.randint(-10, 150), rng.randint(470, RW - 10)])
        y = rng.randint(300, RH + 10)
        if any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in keep_clear):
            continue
        a.paste(f, x, y - f.height)


def room_rack(paint, jars=0):
    """The jar shelf beside the hive, front-on: two pine planks on four posts, open, six jars
    to a plank, three to a harvest."""
    a = Art(110, 92)
    for x in (4, 98):
        a.rect(x, 4, 8, 88, DARK_WOOD)
        a.rect(x + 6, 4, 2, 88, DARK_WOOD_HI)
    for x in (12, 90):
        a.rect(x, 0, 6, 80, DARK_WOOD_LO)
    for k, y in enumerate((30, 70)):
        a.rect(0, y, 110, 7, PINE)
        a.rect(0, y, 110, 2, PINE_LIT)
        a.rect(0, y + 7, 110, 2, PINE_DEEP)
        for jj in range(max(0, min(6, jars - k * 6))):
            jx = 10 + jj * 16
            a.rect(jx, y - 14, 11, 14, HONEY)
            a.rect(jx + 8, y - 12, 2, 8, HONEY_SHINE)
            a.rect(jx - 1, y - 18, 13, 4, GINGHAM_RED)
    return inked(a.im)


PIP_SPACING = 42


def pips_art(a, current, names):
    """The steps as a row of comb cells on an oak plank over the room, each filling with
    honey as it is done."""
    n = len(names)
    pw = PIP_SPACING * n + 8
    px0 = RW // 2 - pw // 2
    a.rect(px0 - 1, 1, pw + 2, 38, FRAME_DEEP)
    a.rect(px0, 2, pw, 36, FRAME)
    a.rect(px0, 2, pw, 2, FRAME_LIT)
    a.rect(px0, 35, pw, 3, FRAME_LOW)
    rng = random.Random(2)
    for _ in range(26):
        a.rect(px0 + rng.randint(2, pw - 12), rng.randint(6, 33), rng.randint(4, 12), 1, FRAME_LOW)
    for x in (px0 - 1, px0 + pw):
        a.px(x, 1, (0, 0, 0, 0))
        a.px(x, 38, (0, 0, 0, 0))
    centres = []
    for i in range(n):
        cx = RW // 2 + int((i - (n - 1) / 2) * PIP_SPACING)
        if i == current:
            a.paste(pip("now"), cx - 9, 6)
        else:
            a.paste(pip("done" if i < current else "todo"), cx - 8, 7)
        if i < n - 1:
            a.rect(cx + 9, 13, PIP_SPACING - 18, 1, HONEY_LIGHT if i < current else FRAME_LOW)
        centres.append(cx)
    return centres


def card_art(a, x, y, w, h):
    a.rect(x + 1, y + 2, w, h, (0, 0, 0, 90))
    a.rect(x - 1, y - 1, w + 2, h + 2, NOTE_OUTER)
    a.rect(x, y, w, h, PAPER)
    a.rect(x, y + h - 2, w, 2, PAPER_EDGE)


def close_art(a):
    x, y = RW - 30, 6
    a.rect(x - 1, y - 1, 24, 18, FRAME_DEEP)
    a.rect(x, y, 22, 16, FRAME)
    a.rect(x, y, 22, 2, FRAME_LIT)
    a.rect(x, y + 14, 22, 2, FRAME_LOW)
    for k in range(8):
        a.rect(x + 7 + k, y + 4 + k, 2, 1, RIBBON_INK)
        a.rect(x + 14 - k, y + 4 + k, 2, 1, RIBBON_INK)


STEPS = ["Catch", "Smoke", "Queen", "Uncap", "Crank", "Pour"]


class Room:
    """One frame of the hive room: art on the 640x360 grid, words over it at 2x."""

    def __init__(self, step, card_words, head_words, pad=False, state="clean"):
        self.a = backdrop(state)
        self.step = step
        self.card_words = card_words
        self.head_words = head_words
        self.pad = pad

    def finish(self):
        a = self.a
        centres = pips_art(a, self.step, STEPS)
        f = ImageFont.truetype(FONT, 20)
        probe = ImageDraw.Draw(Image.new("RGB", (4, 4)))
        text_w = probe.textlength(self.head_words + " " + self.card_words, font=f) / RS
        cw = int(text_w) + 38
        cx0 = RW // 2 - cw // 2
        card_art(a, cx0, 318, cw, 28)
        a.paste(PROMPT_RT if self.pad else PROMPT_MOUSE, cx0 + 6, 324)
        close_art(a)
        im = big(a.im, RS)
        d = ImageDraw.Draw(im)
        small = ImageFont.truetype(FONT, 14)
        for i, (cx, name) in enumerate(zip(centres, STEPS)):
            col = GOLD if i == self.step else RIBBON_INK if i < self.step else (206, 170, 150, 255)
            d.text((cx * RS + 1, 23 * RS + 2), name.upper(), font=small, fill=FRAME_DEEP, anchor="ma")
            d.text((cx * RS, 23 * RS), name.upper(), font=small, fill=col, anchor="ma")
        x = (cx0 + 28) * RS
        y = 332 * RS
        d.text((x, y), self.head_words, font=f, fill=PAPER_HEAD, anchor="lm")
        x += d.textlength(self.head_words + " ", font=f)
        d.text((x, y), self.card_words, font=f, fill=PAPER_INK, anchor="lm")
        return im


def air_bees(a, n, box, seed, lefty=0.5):
    rng = random.Random(seed)
    for _ in range(n):
        x = rng.randint(box[0], box[2])
        y = rng.randint(box[1], box[3])
        b = bee(facing_left=rng.random() < lefty, wings_up=rng.random() < 0.5)
        a.paste(b, x, y)
        side = 1 if rng.random() < 0.5 else -1
        a.px(x - 2 * side + (9 if side < 0 else 0), y + 3, fade(TRIM, 120))


def room_catch():
    r = Room(0, "the branch over the box", "Shake")
    a = r.a
    bough, tip = branch_with_swarm(0.7)
    a.paste(bough, -4, 40)
    rng = random.Random(21)
    # warm light round the box: the queen is in it
    glow = Art(RW, RH)
    for w_, h_, al in ((220, 70, 34), (160, 50, 44), (110, 34, 54)):
        glow.ell(260 - w_ // 2, 238 - h_ // 2, w_, h_, fade(HONEY_LIGHT, al))
    a.paste(glow.im, 0, 0)
    box = catch_box(PAINTS["sky"], rng)
    a.ell(186, 296, 150, 18, (20, 30, 16, 110))
    a.paste(box, 190, 232)
    # the clump mid-fall, a stream of bees pouring after it into the box
    clump = bee_mass(lambda t: 20 * math.sin(math.pi * (0.08 + 0.84 * t)) + 3, 34, 44, 110)
    a.paste(clump, 236 - clump.width // 2, 168)
    for k in range(4):
        a.rect(218 + k * 12, 146 - (k % 2) * 4, 1, 14, fade(TRIM, 170))
    for k in range(18):
        a.paste(bee(facing_left=k % 2 == 0, turn=rng.choice([0, 1, 3])), 222 + rng.randint(0, 30), 210 + k * 2)
    # the queen is in: a crown twinkles over the box
    a.paste(big(crown(), 2), 300, 206)
    for sx, sy, arm in ((296, 204, 2), (326, 202, 3), (318, 226, 1), (290, 222, 1)):
        star(a, sx, sy, arm)
    air_bees(a, 26, (150, 60, 400, 250), 5)
    for k in range(3):
        for s in range(8):
            ang = -0.9 + s * 0.12
            rad = 18 + k * 6
            a.px(302 + math.cos(ang) * rad, 72 + math.sin(ang) * rad, fade(TRIM, 200 - k * 50))
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


def room_smoke():
    r = Room(1, "the smoker, the bees settle", "Puff")
    a = r.a
    a.ell(50, 296, 116, 10, (20, 30, 16, 90))
    a.paste(room_rack(PAINTS["sky"]), 52, 208)
    hive, entrance = room_hive(PAINTS["sky"], window=0.35)
    hx, hy = 140, 96
    a.ell(hx + 10, hy + 196, 160, 18, (20, 30, 16, 110))
    a.paste(hive, hx, hy)
    ex, ey = hx + entrance[0], hy + entrance[1]
    sm = smoker()
    sx, sy = 392, 206
    tip = (sx + 15, sy + 19)
    smoke = Art(RW, RH)
    for k in range(7):
        t = k / 6
        x = tip[0] + (ex + 36 - tip[0]) * t
        y = tip[1] + (ey - 4 - tip[1]) * t - math.sin(t * math.pi) * 22
        puff(smoke, x, y, 5 + t * 15, k, 235 - t * 60)
    # a ring of air off the nozzle with each pump
    for s in range(40):
        ang = s / 40 * math.tau
        smoke.px(tip[0] - 4 + math.cos(ang) * 9, tip[1] + math.sin(ang) * 6, fade(TRIM, 150))
    a.paste(sm, sx, sy)
    a.paste(smoke.im, 0, 0)
    for k in range(6):
        a.paste(bee(facing_left=k % 2 == 0), ex - 30 + k * 11, ey + 3 + (k % 2))
    air_bees(a, 7, (hx + 10, hy + 20, hx + 170, hy + 170), 9)
    hum = Art(RW, RH)
    for k, alpha in enumerate((240, 170, 90)):
        for s in range(18):
            x = hx + 34 + k * 36 + s
            y = hy + 4 - (k == 1) * 6 + (3 if (s // 3) % 2 else 0)
            hum.rect(x, y + 1, 1, 2, fade(OUT, alpha * 0.5))
            hum.rect(x, y, 1, 2, fade(HONEY_SHINE, alpha))
    a.paste(hum.im, 0, 0)
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


def lens(a, cx, cy, radius=33, zoom=2):
    """A brass-rimmed magnifying glass over (cx, cy): the comb under it at twice the size,
    a sheen on the glass, a wooden handle down to the right, and a gold halo for 'found'."""
    src = a.im.crop((cx - radius // zoom - 1, cy - radius // zoom - 1,
                     cx + radius // zoom + 1, cy + radius // zoom + 1))
    src = src.resize((src.width * zoom, src.height * zoom), Image.NEAREST)
    mask = Image.new("L", src.size, 0)
    ImageDraw.Draw(mask).ellipse([src.width // 2 - radius, src.height // 2 - radius,
                                  src.width // 2 + radius, src.height // 2 + radius], fill=255)
    halo = Art(RW, RH)
    for y in range(cy - radius - 12, cy + radius + 13):
        for x in range(cx - radius - 12, cx + radius + 13):
            q = math.hypot(x - cx, y - cy)
            if radius + 4 < q < radius + 10:
                halo.px(x, y, fade(GOLD, 90 * (1 - (q - radius - 4) / 6)))
    a.paste(halo.im, 0, 0)
    # the handle first, so the rim sits over its collar
    ux, uy = math.cos(math.pi / 4), math.sin(math.pi / 4)
    for k in range(radius + 2, radius + 40):
        for w_ in range(-5, 6):
            x = cx + ux * k - uy * w_
            y = cy + uy * k + ux * w_
            if abs(w_) == 5:
                c = OUT
            elif k < radius + 10:
                c = BRASS["lit"] if w_ < -1 else BRASS["base"] if w_ < 3 else BRASS["shade"]
            else:
                c = DARK_WOOD_HI if w_ < -1 else DARK_WOOD if w_ < 3 else DARK_WOOD_LO
            a.px(x, y, c)
    for w_ in range(-5, 6):
        a.px(cx + ux * (radius + 40) - uy * w_, cy + uy * (radius + 40) + ux * w_, OUT)
    glass = Image.new("RGBA", src.size, (0, 0, 0, 0))
    glass.paste(src, (0, 0), mask)
    a.paste(glass, cx - src.width // 2, cy - src.height // 2)
    for y in range(cy - radius - 6, cy + radius + 7):
        for x in range(cx - radius - 6, cx + radius + 7):
            q = math.hypot(x - cx, y - cy)
            lean = (-(x - cx) - (y - cy)) / max(q, 1)
            if radius - 0.5 < q <= radius + 0.5 or radius + 4.5 < q <= radius + 5.5:
                a.px(x, y, OUT)
            elif radius + 0.5 < q <= radius + 4.5:
                a.px(x, y, BRASS["lit"] if lean > 0.45 else BRASS["shade"] if lean < -0.45 else BRASS["base"])
            elif radius - 9 < q < radius - 5 and lean > 0.8:
                a.px(x, y, fade(TRIM, 120))
    a.px(cx - radius // 2, cy - radius // 2 - 4, fade(TRIM, 200))


def room_queen():
    r = Room(2, "the queen, she wears a white dot", "Find")
    a = r.a
    hive, _ = room_hive(PAINTS["sky"], lid=False, open_top=True)
    a.ell(-40, 286, 170, 12, (20, 30, 16, 80))
    a.paste(hive, -52, 124)
    fw, fh = 300, 180
    frame = brood_frame(fw, fh, seed=9, cell=CELL_BIG)
    fx, fy = RW // 2 - frame.width // 2, 50
    a.paste(frame, fx, fy)
    rng = random.Random(4)
    qx, qy = fx + 13 + int(fw * 0.66), fy + int(fh * 0.56)
    placed = []
    while len(placed) < 30:
        x = rng.randint(fx + 30, fx + fw - 14)
        y = rng.randint(fy + 22, fy + fh - 18)
        if math.hypot(x - qx, (y - qy) * 1.4) < 34:
            continue
        if any(abs(x - px_) < 12 and abs(y - py_) < 7 for px_, py_ in placed):
            continue
        placed.append((x, y))
        a.paste(bee(facing_left=rng.random() < 0.5, turn=rng.choice([0, 0, 1, 3]), wings_up=False), x - 4, y - 3)
    # her court: a ring of bees all facing in
    for k in range(10):
        ang = k / 10 * math.tau
        x = qx + math.cos(ang) * 19
        y = qy + math.sin(ang) * 12
        if abs(math.cos(ang)) > 0.55:
            b = bee(facing_left=math.cos(ang) > 0, wings_up=False)
        else:
            b = bee(turn=3 if math.sin(ang) < 0 else 1, wings_up=False)
        a.paste(b, x - b.width // 2, y - b.height // 2)
    q = bee(queen=True, wings_up=False)
    a.paste(q, qx - q.width // 2, qy - q.height // 2)
    lens(a, qx, qy)
    a.paste(big(crown(), 2), qx - 11, qy - 33 - 30)
    for sx, sy, arm in ((qx - 30, qy - 40, 2), (qx + 30, qy - 42, 3), (qx + 44, qy - 8, 2),
                        (qx - 46, qy - 4, 1), (qx - 24, qy + 42, 1)):
        star(a, sx, sy, arm)
    a.paste(glove(), fx - 6, fy - 4)
    a.paste(glove(flip=True), fx + frame.width - 26, fy - 4)
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


def room_uncap():
    r = Room(3, "the hot knife down the comb", "Draw")
    a = r.a
    fw, fh, cut = 300, 180, 96
    frame = brood_frame(fw, fh, seed=12, uncap_to=cut, cell=CELL_BIG)
    fx, fy = RW // 2 - frame.width // 2 - 16, 44
    a.paste(frame, fx, fy)
    rng = random.Random(6)
    # runs of honey down the open face, slow, with beads at their feet
    for _ in range(7):
        x = rng.randint(fx + 30, fx + fw - 12)
        drip(a, x, rng.randint(fy + 14, fy + 40), rng.randint(8, 26))
    # the glide: faint copies of the blade's edge where it was a moment ago
    ghost = Art(RW, RH)
    for k, al in enumerate((110, 70, 38)):
        yk = fy + cut - 20 - k * 7
        ghost.rect(fx + 20, yk, fw - 10, 4, fade(STEEL["hi"], al))
        ghost.rect(fx + 20, yk + 4, fw - 10, 1, fade((255, 150, 96, 255), al))
    a.paste(ghost.im, 0, 0)
    # the fresh cut glints
    for _ in range(10):
        star(a, rng.randint(fx + 30, fx + fw - 10), rng.randint(fy + cut - 26, fy + cut - 14), rng.choice([1, 2, 2, 3]))
    kx, ky = fx + 18, fy + cut - 8
    a.paste(hot_knife(fw - 6), kx, ky)
    sheet, (sx, sy) = wax_sheet(fw - 50)
    a.paste(sheet, kx + 1 - sx + 4, ky + 8 - sy)
    # honey running off the hot edge, beads gathering under it
    for k, ln in enumerate((10, 18, 7, 24, 13, 16)):
        drip(a, fx + 60 + k * 40, ky + 16, ln)
    shimmer = Art(RW, RH)
    for k in range(46):
        x = fx + 30 + k * 6 + rng.randint(-2, 2)
        shimmer.px(x, ky + 17 + (k % 3), fade((255, 150, 96, 255), 150))
    a.paste(shimmer.im, 0, 0)
    a.paste(glove(flip=True), fx + fw + 44, ky - 6)
    a.paste(glove(), fx - 6, fy - 4)
    # the capping tray: a pool of honey with the cappings heaped in it
    ty = fy + fh + 16
    a.rect(fx + 22, ty - 1, fw - 6, 16, OUT)
    a.rect(fx + 23, ty, fw - 8, 14, STEEL["base"])
    a.rect(fx + 23, ty, fw - 8, 3, STEEL["hi"])
    a.rect(fx + 27, ty + 3, fw - 16, 6, HONEY)
    a.rect(fx + 27, ty + 3, fw - 16, 1, HONEY_LIGHT)
    for k in range(3):
        a.rect(fx + 80 + k * 70, ty + 5, 14, 1, HONEY_SHINE)
    for k in range(22):
        wx = fx + 30 + rng.randint(0, fw - 40)
        a.rect(wx, ty + rng.randint(0, 4), rng.randint(3, 7), 2, WAX_LIT if k % 3 else WAX_SHADE)
    air_bees(a, 5, (fx, fy - 20, fx + fw, fy + 10), 13)
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


def room_crank():
    r = Room(4, "the crank in steady circles", "Turn")
    a = r.a
    ex, (sx, sy, reach) = extractor()
    x0, y0 = RW // 2 - ex.width // 2, 44
    a.ell(x0 + 24, y0 + 250, 170, 14, (20, 30, 16, 110))
    cx, cy = x0 + sx, y0 + sy
    rx, ry = reach, 13

    def path(near):
        g = Art(RW, RH)
        for s in range(160):
            ang = s / 160 * math.tau
            if (math.sin(ang) > 0) != near or s % 8 >= 5:
                continue
            g.rect(cx + math.cos(ang) * rx - 1, cy + math.sin(ang) * ry - 1, 4, 4, (0, 0, 0, 110))
        for s in range(160):
            ang = s / 160 * math.tau
            if (math.sin(ang) > 0) != near or s % 8 >= 5:
                continue
            g.rect(cx + math.cos(ang) * rx, cy + math.sin(ang) * ry, 2, 2, GOLD)
        return g.im

    a.paste(path(False), 0, 0)
    a.paste(ex, x0, y0)
    a.paste(path(True), 0, 0)
    # the beat: a notch at each quarter of the path, the one the knob is heading for lit
    for k, ang in enumerate((0, math.pi / 2, math.pi, math.pi * 1.5)):
        nx, ny = round(cx + math.cos(ang) * rx), round(cy + math.sin(ang) * ry)
        size = 4 if k == 1 else 2
        for dy_ in range(-size, size + 1):
            w_ = size - abs(dy_)
            a.rect(nx - w_ - 1, ny + dy_, 2 * w_ + 3, 1, OUT)
        for dy_ in range(-size + 1, size):
            w_ = size - 1 - abs(dy_)
            a.rect(nx - w_, ny + dy_, 2 * w_ + 1, 1, HONEY_SHINE if k == 1 else GOLD)
        if k == 1:
            for sx_, sy_ in ((nx - 10, ny - 4), (nx + 10, ny - 3), (nx + 2, ny + 9)):
                star(a, sx_, sy_, 1)
    ax, ay = cx - 16, cy + ry
    for k in range(5):
        a.rect(ax + k, ay - 4 + k, 2, 9 - 2 * k, HONEY_SHINE)
    for k, ang in enumerate((0.55, 1.1)):
        ghost = Art(12, 22)
        ghost.rect(2, 2, 8, 18, fade(DARK_WOOD_HI, 150 - k * 60))
        a.paste(ghost.im, cx + math.cos(ang) * rx - 5, cy + math.sin(ang) * ry - 16)
    # honey flung up off the spinning comb, over the rim
    rng = random.Random(8)
    rim_y = y0 + 76 - 16
    for side in (-1, 1):
        for k in range(7):
            t = k / 6
            x = cx + side * (44 + t * 46)
            y = rim_y - math.sin(t * math.pi) * 20 + t * 8
            a.rect(x, y, 2, 2, HONEY if k % 2 else HONEY_LIGHT)
            if k % 3 == 0:
                a.px(x + 1, y, HONEY_SHINE)
    for side in (-1, 1):
        for k in range(3):
            bx = cx + side * (92 + k * 6)
            for s in range(8):
                a.rect(bx + side * (s // 3), y0 + 110 + k * 18 + s * 2, 2, 2, fade(TRIM, 190 - k * 50))
    air_bees(a, 4, (x0 - 60, y0 + 20, x0 + 240, y0 + 80), 17)
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


def room_pour():
    r = Room(5, "to pour, let go at the line", "Hold")
    a = r.a
    bx, by = RW // 2 - 50, 42
    bottling_stand(a, bx, by)
    a.paste(bottling_bucket(), bx + BOTTLING_BUCKET_AT[0], by + BOTTLING_BUCKET_AT[1])
    gx, gy = bx + BOTTLING_GATE_AT[0], by + BOTTLING_GATE_AT[1]
    a.paste(bottling_gate(), gx, gy)
    j = jar(fill=0.62)
    jx, jy = RW // 2 - j.width // 2, 214
    surface = jy + 14 + 58 - 3 - int(42 * 0.62)
    # the line to stop at, glowing now the honey is near it
    line_y = jy + 14 + 58 - 3 - int(42 * 0.86)
    halo = Art(RW, RH)
    halo.rect(jx - 10, line_y - 2, j.width + 20, 5, fade(GOLD, 60))
    a.paste(halo.im, 0, 0)
    for y in range(gy + 20, surface + 1):
        wob = round(math.sin(y * 0.18) * 1.2)
        wide = 6 if y < gy + 40 else 5 if y < surface - 30 else 4
        for x in range(-wide // 2, wide - wide // 2):
            c = HONEY_MID if x == -wide // 2 else HONEY_LIGHT if x == wide - wide // 2 - 1 else HONEY
            a.px(RW // 2 + x + wob, y, c)
    a.paste(j, jx, jy)
    # the ribbon folding on itself where it lands, a coil sinking into the rest
    coil = Art(40, 16)
    for k, (ox, oy, w_) in enumerate(((10, 8, 20), (13, 5, 14), (16, 2, 8))):
        coil.d.ellipse([ox, oy, ox + w_, oy + 6], outline=HONEY_LIGHT if k % 2 else HONEY, width=2)
    coil.px(18, 3, HONEY_SHINE)
    a.paste(coil.im, RW // 2 - 20, surface - 10)
    for x in range(jx - 8, jx + j.width + 8, 4):
        a.rect(x, line_y, 2, 1, GOLD)
    for k in range(4):
        a.rect(jx - 12 + k, line_y - 3 + k, 1, 7 - 2 * k, GOLD)
        a.rect(jx + j.width + 11 - k, line_y - 3 + k, 1, 7 - 2 * k, GOLD)
    board = (RW // 2 + 60, 290)
    a.rect(board[0] - 6, board[1], 150, 8, DARK_WOOD_HI)
    a.rect(board[0] - 6, board[1] + 6, 150, 3, DARK_WOOD_LO)
    a.paste(jar(fill=0.86, lid=True, label=True), board[0], board[1] - 72)
    a.paste(jar(fill=0.86, lid=True, label=True), board[0] + 50, board[1] - 72)
    # the jar just lidded: a pop of stars off it
    for sx_, sy_, arm in ((board[0] + 46, board[1] - 70, 3), (board[0] + 100, board[1] - 64, 2),
                          (board[0] + 74, board[1] - 84, 2), (board[0] + 96, board[1] - 30, 1)):
        star(a, sx_, sy_, arm)
    a.paste(jar(fill=0.0), RW // 2 - 150, 222)
    air_bees(a, 3, (RW // 2 - 90, 150, RW // 2 + 90, 200), 29)
    near_flowers(a, [(180, 280, 470, 380)])
    return r.finish()


# --- the sheets ----------------------------------------------------------------------------
def heading(d, x, y, text, size=30, col=GOLD):
    f = ImageFont.truetype(FONT, size)
    d.text((x + 2, y + 2), text, font=f, fill=(0, 0, 0, 160))
    d.text((x, y), text, font=f, fill=col)


def note(d, x, y, text, size=17, col=CREAM):
    d.text((x, y), text, font=ImageFont.truetype(FONT, size), fill=col)


def honey_rule(d, x, y, length):
    for k in range(0, length, 18):
        d.regular_polygon((x + k, y, 6), 6, rotation=30, fill=HONEY if (k // 18) % 3 else HONEY_LIGHT)


def island_sheet():
    gap = 40
    pw, ph = 660, 560
    side = 560
    W = gap * 4 + pw * 2 + side
    H = 150 + (ph + 70) * 2 + gap
    sheet = Image.new("RGBA", (W, H), SHEET_BG)
    d = ImageDraw.Draw(sheet)
    heading(d, gap, 28, "THE HIVE  -  ON THE ISLAND", 40)
    note(d, gap, 84, "Left of the hut on screen, the free lawn. Drawn over a real frame of the island (tools/last_pump.png).",
         16, (200, 210, 196, 255))
    honey_rule(d, gap + 6, 124, W - gap * 2 - 12)
    panels = [("new", "A  New game: an old, empty hive", "Grey boards, flakes of old blue; the jar shelf behind it, bare."),
              ("swarm", "B  Mid-run: the swarm arrives", "Island flowers in, a swarm on the shrub. The moment glides here."),
              ("colony", "C  The colony", "Its blue back. Bees fly out to the island's flowers and back."),
              ("full", "D  Hive full", "Honey in the window, the ready mark; a harvest's jars on the shelf.")]
    for i, (state, title, sub) in enumerate(panels):
        x = gap + (i % 2) * (pw + gap)
        y = 150 + (i // 2) * (ph + 70)
        heading(d, x, y, title, 22, CREAM)
        note(d, x, y + 30, sub, 14, (190, 200, 186, 255))
        sheet.alpha_composite(island_panel(state), (x, y + 56))
        d.rectangle([x - 2, y + 54, x + pw + 1, y + 56 + ph + 1], outline=NOTE_OUTER, width=2)
        if state == "swarm":
            cx, cy, cw, ch = x + pw // 2, y + 56 + ph - 64, 460, 50
            d.rectangle([cx - cw // 2 - 3, cy - ch // 2 - 3, cx + cw // 2 + 3, cy + ch // 2 + 3], fill=NOTE_OUTER)
            d.rectangle([cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2], fill=PAPER)
            d.rectangle([cx - cw // 2, cy + ch // 2 - 4, cx + cw // 2, cy + ch // 2], fill=PAPER_EDGE)
            d.text((cx, cy), "A swarm has come to the hive!", font=ImageFont.truetype(FONT, 21), fill=PAPER_INK, anchor="mm")
    sx = gap * 3 + pw * 2
    heading(d, sx, 150, "SKY BLUE, PICKED", 22, CREAM)
    note(d, sx, 180, "The paint comes back when the colony", 14, (190, 200, 186, 255))
    note(d, sx, 198, "moves in, like a washed find.", 14, (190, 200, 186, 255))
    tile = Image.new("RGBA", (520, 300), (58, 86, 36, 255))
    ImageDraw.Draw(tile).rectangle([0, 210, 520, 300], fill=(70, 100, 40, 255))
    tile.alpha_composite(big(island_hive(WEATHERED, "weathered"), 5), (6, 40))
    tile.alpha_composite(big(island_hive(PAINTS["sky"], "colony"), 5), (290, 40))
    ImageDraw.Draw(tile).polygon([(238, 140), (268, 156), (238, 172)], fill=GOLD)
    sheet.alpha_composite(tile, (sx, 226))
    d.rectangle([sx - 2, 224, sx + 521, 226 + 301], outline=NOTE_OUTER, width=2)
    jy = 226 + 300 + 40
    heading(d, sx, jy, "THE JAR SHELF", 22, CREAM)
    note(d, sx, jy + 30, "One sprite with the hive: two planks behind its shaded side.", 14, (190, 200, 186, 255))
    note(d, sx, jy + 48, "A row of three jars a harvest; scenery, never an item.", 14, (190, 200, 186, 255))
    for k, (jars, label) in enumerate(((3, "1 HARVEST"), (6, "2"), (12, "4"))):
        tile = Image.new("RGBA", (160, 170), (58, 86, 36, 255))
        tile.alpha_composite(big(island_hive(PAINTS["sky"], "colony", jars=jars), 3), (12, 10))
        tx = sx + k * 180
        sheet.alpha_composite(tile, (tx, jy + 82))
        d.rectangle([tx - 2, jy + 80, tx + 161, jy + 82 + 171], outline=NOTE_OUTER, width=2)
        note(d, tx + 8, jy + 82 + 146, label, 15, CREAM)
    return sheet


def room_sheet():
    gap = 40
    fw, fh = RW * RS, RH * RS
    W = gap * 3 + fw * 2
    H = 190 + (fh + 90) * 3 + gap
    sheet = Image.new("RGBA", (W, H), SHEET_BG)
    d = ImageDraw.Draw(sheet)
    heading(d, gap, 28, "THE HIVE ROOM  -  FIRST HARVEST", 40)
    note(d, gap, 84, "Every step lands on a payoff: a sparkle, a settle, a sound, never a fail state. "
         "The view is the wash room's own backdrop, veiled less (0.82 against 0.66).", 16, (200, 210, 196, 255))
    note(d, gap, 110, "Later harvests show two cells in the row, Uncap and Pour, about 15-20 s. "
         "Hints are paper cards; the mouse prompt swaps for RT in pad mode.", 16, (200, 210, 196, 255))
    honey_rule(d, gap + 6, 156, W - gap * 2 - 12)
    frames = [(room_catch, "1  Catch the swarm", "Flick the branch: the clump drops, the rest pour after it; a crown twinkles when she's in."),
              (room_smoke, "2  Smoke", "Pump the bellows: puffs drift in, the hum over the roof dies down. The jar shelf stands behind it."),
              (room_queen, "3  Find the queen", "A lens over the comb, twice the size under it; her court faces her. Found: gold halo, a crown."),
              (room_uncap, "4  Uncap", "One smooth stroke: the capping lifts as a sheet, the fresh cut glints, honey runs slow off the blade."),
              (room_crank, "5  Crank", "Steady circles, speed capped. Proposal: the notches pulse on the song's beat, no penalty off it."),
              (room_pour, "6  Pour", "Honey coils in the jar, the line glows as it nears, the lid pops on with a burst of stars.")]
    for i, (make, title, sub) in enumerate(frames):
        x = gap + (i % 2) * (fw + gap)
        y = 190 + (i // 2) * (fh + 90)
        heading(d, x, y, title, 26, CREAM)
        note(d, x, y + 36, sub, 16, (190, 200, 186, 255))
        sheet.alpha_composite(make(), (x, y + 66))
        d.rectangle([x - 2, y + 64, x + fw + 1, y + 66 + fh + 1], outline=NOTE_OUTER, width=2)
    return sheet


def main():
    island_sheet().convert("RGB").save(OUT_ISLAND)
    room_sheet().convert("RGB").save(OUT_ROOM)
    print(OUT_ISLAND, OUT_ROOM)


if __name__ == "__main__":
    main()

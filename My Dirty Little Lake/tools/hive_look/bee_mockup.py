#!/usr/bin/env python
"""The bee sheet (2026-10-16, the hive overhaul's foundation): three cute bees, A / B / C.

Writes tools/hive_look/last_bee.png. For each variant: every frame at 8x and at 1x; the bee
at real scale flying over the catch step's sky and a swarm clump of 40 hanging there; walking
on the queen step's comb with the queen among them; the mini bee at real scale on the island
by the hive and a flower bed; 4x zoom crops of the details beside each. A "today" strip on top
shows the same places as they are now, at the same scales.

Run from the project root:
    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/hive_look/bee_mockup.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402
from look import ROOM_GRAIN, ISLAND_GRAIN, zoom, place, panel, stack, flow  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT_PATH = os.path.join(look.HERE, "last_bee.png")
RECOMMEND = "A"
SHEET_WIDE = 2440

CAPTIONS = {
    "A": "Coin gold (the coin's own ramp), two soft brown bands, a 2x2 eye mid-face with a "
         "top-left glint, a coral cheek, one curled feeler, small paddle wings. 10x7 with its "
         "outline, the brief's size. Picked: the brightest, yellowest gold on every ground here "
         "(sky, comb, lawn, the blue hive), so the bee never sinks into honey-coloured comb or "
         "reads as brown scribble; the brown bands keep it soft and round rather than waspish; "
         "the clump stays a warm ball of faces.",
    "B": "Honey (the hive's honey ramp), chubby 11x8, near-black bands, a cream fluff collar, a "
         "tall 2x3 eye high on the face, big round wings, no feeler. The strongest contrast "
         "(classic yellow and black) and the cutest silhouette, but a size over the brief, "
         "closer to today's brown-gold, and its big wings make the clump white.",
    "C": "Lemon (the finds' pale gold), a dark tail and one thin band, a big round 3x3 eye low "
         "on the face, two feelers, long swept wings. 10x7. Alone it is the most chibi; in a "
         "clump and on the comb the big dark eyes merge into a dark mass.",
}

SKY_BG = (161, 203, 229, 255)        # the catch step's sky, measured


# --- frames ----------------------------------------------------------------------------------
def frames_panel(v):
    fly = [look.bee(v, f, pose="fly") for f in range(6)]
    walk = [look.bee(v, f, pose="walk") for f in range(2)]
    rest = [look.bee(v, 0, pose="rest"), look.bee(v, 3, pose="rest")]
    turn = [look.bee(v, 0, pose="walk", turn=1), look.bee(v, 1, pose="walk", turn=3)]
    queen = [look.queen(v, 0), look.queen(v, 1), look.queen(v, 0, laying=True)]
    mini = [look.mini_bee(v, f) for f in range(3)] + [look.mini_bee(v, 0, pose="rest")]

    def strip(ims, s, gap=1):
        row = [zoom(Image.alpha_composite(Image.new("RGBA", i.size, SKY_BG), i), s) for i in ims]
        return stack(row, "h", gap * s)

    names = ("fly 0-5 (wings up / mid / down, bob up on 3-5)", "walk 0-1",
             "rest, blink", "crawling up / down")
    big = [panel(strip(fly, 8), names[0]), panel(strip(walk, 8), names[1]),
           panel(strip(rest, 8), names[2]), panel(strip(turn, 8), names[3]),
           panel(strip(queen, 8), "queen: walk 0-1, laying"),
           panel(strip(mini, 8), "mini bee: fly 0-2, rest")]
    ones = stack([strip(fly, 1), strip(walk, 1), strip(rest, 1), strip(turn, 1),
                  strip(queen, 1), strip(mini, 1)], "h", 6)
    return flow(big + [panel(ones, "all of it at 1x")], SHEET_WIDE, 14)


# --- the catch step's sky: flying bees and the clump of 40 -----------------------------------
SKY_CROP = (60, 112, 900, 472)
CLUMP_BOX = (88, 68)
CLUMP_AT = (420, 268)                # plate px, the clump's middle
FLYERS = [  # (plate x, y, frame, facing_left)
    (150, 168, 0, False), (262, 380, 4, True), (668, 160, 1, True), (790, 300, 2, False),
    (720, 420, 3, True), (200, 280, 5, False),
]


def sky_panel(v):
    base = look.plate("catch")
    look.clean_bees(base, (0, 100, 1920, 480))
    for x, y, f, left in FLYERS:
        b = look.bee(v, f, facing_left=left, pose="fly")
        place(base, b, (x, y), ROOM_GRAIN, anchor=look.bee_anchor(v, "fly", left, f))
    clump = look.swarm(v, 40, seed=7, box=CLUMP_BOX, frame=0)
    place(base, clump, CLUMP_AT, ROOM_GRAIN, anchor=(CLUMP_BOX[0] // 2, CLUMP_BOX[1] // 2))
    shown = base.crop(SKY_CROP)
    lone = (FLYERS[2][0] - 48, FLYERS[2][1] - 42, FLYERS[2][0] + 54, FLYERS[2][1] + 34)
    cl = (CLUMP_AT[0] - 138, CLUMP_AT[1] - 108, CLUMP_AT[0] + 138, CLUMP_AT[1] + 108)
    marked = shown.copy()
    off = (SKY_CROP[0], SKY_CROP[1])
    z1 = look.crop_zoom(base, lone, 4, None)
    z2 = look.crop_zoom(base, cl, 3, None)
    d = ImageDraw.Draw(marked)
    for bx in (lone, cl):
        d.rectangle([bx[0] - off[0] - 2, bx[1] - off[1] - 2, bx[2] - off[0] + 1, bx[3] - off[1] + 1],
                    outline=look.MARK, width=2)
    return [panel(marked, "real scale: the catch sky, 40 in a clump and six flying (3 px an art px)"),
            panel(z1, "4x: one flying"),
            panel(z2, "3x: the clump of 40")]


# --- the queen step's comb ------------------------------------------------------------------
COMB_CROP = (552, 168, 1092, 492)
QUEEN_AT = (812, 336)


def comb_panel(v):
    base = look.plate("queen")
    look.restore_comb(base)
    rng = random.Random(11)
    spots = []
    qx, qy = QUEEN_AT
    tries = 0
    while len(spots) < 30 and tries < 5000:
        tries += 1
        x = rng.uniform(COMB_CROP[0] + 6, COMB_CROP[2] - 30)
        y = rng.uniform(COMB_CROP[1] + 6, COMB_CROP[3] - 24)
        if abs(x - qx) < 78 and abs(y - qy) < 40:
            continue
        if all(abs(x - a) > 30 or abs(y - b) > 24 for a, b in spots):
            spots.append((x, y))
    for i, (x, y) in enumerate(sorted(spots, key=lambda p: p[1])):
        r = rng.random()
        turn = 0 if r < 0.6 else (1 if r < 0.8 else 3)
        left = rng.random() < 0.5
        pose = "walk" if rng.random() < 0.85 else "rest"
        f = rng.randrange(4)
        b = look.bee(v, f, facing_left=left, pose=pose, turn=turn)
        place(base, b, (x, y), ROOM_GRAIN)
    q = look.queen(v, 0, facing_left=True)
    place(base, q, QUEEN_AT, ROOM_GRAIN, anchor=look.queen_anchor(v, facing_left=True))
    shown = base.crop(COMB_CROP)
    zb = (qx - 78, qy - 56, qx + 78, qy + 50)
    marked = shown.copy()
    ImageDraw.Draw(marked).rectangle([zb[0] - COMB_CROP[0] - 2, zb[1] - COMB_CROP[1] - 2,
                                      zb[2] - COMB_CROP[0] + 1, zb[3] - COMB_CROP[1] + 1],
                                     outline=look.MARK, width=2)
    return [panel(marked, "real scale: the brood comb, 30 workers and the queen"),
            panel(look.crop_zoom(base, zb, 4), "4x: the queen among them")]


# --- the island: mini bees by the hive and a flower bed --------------------------------------
ISL_CROP = (250, 128, 520, 334)
ISLAND_OLD = {(242, 201, 70), (45, 32, 15)}


def clean_island(base):
    import numpy as np
    a = np.array(base)
    g = ISLAND_GRAIN
    rows, cols = a.shape[0] // g, a.shape[1] // g
    cells = a[g // 2::g, g // 2::g, :3].astype(int)
    for r in range(rows):
        for c in range(cols):
            p = tuple(cells[r, c])
            if any(sum(abs(p[i] - q[i]) for i in range(3)) < 10 for q in ISLAND_OLD):
                for k in range(1, 8):
                    q = None
                    for cc in (c - k, c + k):
                        if 0 <= cc < cols:
                            t = tuple(cells[r, cc])
                            if not any(sum(abs(t[i] - o[i]) for i in range(3)) < 10 for o in ISLAND_OLD):
                                q = t
                                break
                    if q:
                        a[r * g:(r + 1) * g, c * g:(c + 1) * g, :3] = q
                        break
    base.paste(Image.fromarray(a))
    return base


def flora_piece(name):
    import json
    j = json.load(open(os.path.join(look.ROOT, "assets/flora.json")))[name]
    x, y, w, h = j["full"]
    sheet = Image.open(os.path.join(look.ROOT, "assets/flora.png")).convert("RGBA")
    return sheet.crop((x, y, x + w, y + h))


def day_mul(im, mul):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3]:
                px[x, y] = (int(p[0] * mul[0]), int(p[1] * mul[1]), int(p[2] * mul[2]), p[3])
    return out


# the island crop's day tint, measured off the hive roof (ROOF base 220,98,72 -> 217,96,70)
ISLAND_MUL = (217 / 220, 96 / 98, 70 / 72)
BED = [("pk_bed_0", (256, 284)), ("pk_bed_1", (300, 300)), ("pk_flower_5", (344, 300)),
       ("pk_flower_1", (458, 310))]
MINIS = [  # (plate x, y, frame, facing_left, pose)
    (272, 280, 0, False, "fly"), (296, 276, 4, True, "fly"), (322, 300, 0, False, "rest"),
    (342, 290, 2, True, "fly"), (408, 262, 1, True, "fly"), (424, 246, 3, False, "fly"),
    (372, 236, 5, True, "fly"), (474, 304, 1, True, "fly"),
]


def island_panel(v):
    base = clean_island(look.plate("busy"))
    for name, at in BED:
        im = day_mul(flora_piece(name), ISLAND_MUL)
        place(base, im, at, ISLAND_GRAIN)
    for x, y, f, left, pose in MINIS:
        im = day_mul(look.mini_bee(v, f, facing_left=left, pose=pose), ISLAND_MUL)
        place(base, im, (x, y), ISLAND_GRAIN, anchor=look.mini_anchor(v, pose, left, f))
    shown = base.crop(ISL_CROP)
    zb = (252, 252, 362, 330)
    zh = (360, 214, 470, 278)
    marked = shown.copy()
    d = ImageDraw.Draw(marked)
    for b in (zb, zh):
        d.rectangle([b[0] - ISL_CROP[0] - 2, b[1] - ISL_CROP[1] - 2, b[2] - ISL_CROP[0] + 1,
                     b[3] - ISL_CROP[1] + 1], outline=look.MARK, width=2)
    return [panel(marked, "real scale: the island crop (2 px an art px)"),
            panel(look.crop_zoom(base, zb, 3), "3x (6 px an art px): at the flower bed"),
            panel(look.crop_zoom(base, zh, 3), "3x: at the hive")]


# --- today -----------------------------------------------------------------------------------
def today_strip():
    catch = look.plate("catch")
    queen = look.plate("queen")
    busy = look.plate("busy")
    p = [panel(catch.crop((1500, 230, 1860, 450)), "today: the clump, real scale"),
         panel(zoom(catch.crop((1140, 140, 1230, 200)), 4), "today: a flying bee, 4x"),
         panel(zoom(queen.crop((640, 380, 760, 470)), 4), "today: workers on the comb, 4x"),
         panel(zoom(busy.crop((360, 210, 450, 270)), 4), "today: the island's bees, 4x")]
    return flow(p, SHEET_WIDE, 14)


def main():
    options = []
    for v in look.VARIANTS:
        body = flow([frames_panel(v)] + sky_panel(v) + comb_panel(v) + island_panel(v),
                    SHEET_WIDE, 16)
        options.append(look.option_block(v, look.VARIANT_NAMES[v], CAPTIONS[v], body,
                                         recommended=(v == RECOMMEND), width=SHEET_WIDE))
    today = look.option_block("Today", "for comparison",
                              "The same places as the game draws them now, at the same scales.",
                              today_strip(), width=SHEET_WIDE)
    look.sheet("The bee: three cute bees", [today] + options, OUT_PATH,
               subtitle="Richard's brief (2026-10-16): a round striped body about 9x7, one big "
                        "dark eye with a white glint, flickering pale wings, a little bob. Every "
                        "plate is a real capture; every bee is drawn at that plate's own grain "
                        "(room 3 px, island 2 px an art px). Pink boxes mark the zoom crops.",
               notes="Colours: every bee colour is an in-game swatch (look.SW): the coin's ramp, "
                     "the finds' gold, the hive's honey, the hive's roof coral for the cheek and "
                     "the jewel, the palette's foam and clean water for the wings, the game's "
                     "outline (24,18,17). Script: tools/hive_look/bee_mockup.py, module "
                     "tools/hive_look/look.py.")
    print("wrote", OUT_PATH)


if __name__ == "__main__":
    main()

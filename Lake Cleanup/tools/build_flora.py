#!/usr/bin/env python
"""Draws the flora sheet: the flowers, reeds, lily pads, shrubs and beach grass that grow
back as the lake comes clean (scripts/flora.gd), plus a sprout frame for each so a plant can
be seen arriving rather than switched on.

Painted pixel art at one painted pixel to one, drawn by the game at 2 (Lake.ART_PIXEL), off
the palette's own swatches (palette.tres) so a flower stands beside the pack's grass without
being from another game. Colourful on purpose: a patch of red and yellow on green is what
"nature coming back" looks like at the far zoom, and every petal colour here is a palette
swatch lifted or a pair of them mixed.

Writes assets/flora.png and assets/flora.json:
  {"<name>": {"full": [x, y, w, h], "sprout": [x, y, w, h], "kind": "lawn|beach|water"}}

Run from the project root, then reimport:
  <psd-extract venv python> tools/build_flora.py
  <godot> --path . --headless --import

Richard may hand-polish assets/flora.png afterwards; the json still holds unless a rectangle
moves. A re-run overwrites both.
"""
from __future__ import annotations

import json
import os
import random

from PIL import Image, ImageDraw

OUT_PNG = os.path.join("assets", "flora.png")
OUT_JSON = os.path.join("assets", "flora.json")
SHEET_PNG = os.path.join("tools", "last_flora_sheet.png")


def rgb(r: float, g: float, b: float) -> tuple[int, int, int, int]:
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def mix(a, b, t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def lift(c, k: float):
    return tuple(min(255, round(c[i] * k)) for i in range(3)) + (255,)


# palette.tres
GRASS_LIGHT = rgb(0.427, 0.529, 0.251)
GRASS_DARK = rgb(0.196, 0.341, 0.114)
LEAF = rgb(0.294, 0.424, 0.18)
SAND = rgb(0.91, 0.804, 0.592)
WOOD = rgb(0.541, 0.235, 0.141)
FOAM = rgb(0.933, 0.965, 0.984)
WATER_LIGHT = rgb(0.769, 0.859, 0.91)
WATER_SHALLOW = rgb(0.498, 0.655, 0.776)
DIRTY_LIGHT = rgb(0.369, 0.435, 0.227)

# Petals: each is a swatch lifted or two swatches mixed, so a re-tuned palette re-tunes these.
RED = lift(WOOD, 1.55)
ORANGE = mix(WOOD, SAND, 0.45)
YELLOW = mix(SAND, lift(DIRTY_LIGHT, 1.6), 0.35)
PINK = mix(lift(WOOD, 1.5), FOAM, 0.55)
WHITE = FOAM
BLUE = mix(WATER_SHALLOW, FOAM, 0.35)
VIOLET = mix(mix(WOOD, WATER_SHALLOW, 0.5), FOAM, 0.3)
STEM = GRASS_DARK
STEM_LIT = LEAF
PALE_GRASS = mix(GRASS_LIGHT, SAND, 0.45)
OUTLINE = mix(GRASS_DARK, (0, 0, 0, 255), 0.45)
PAD = mix(GRASS_LIGHT, LEAF, 0.4)
PAD_LIT = mix(GRASS_LIGHT, WATER_LIGHT, 0.25)
BERRY = RED

rng = random.Random(20260916)


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def flower(petal, size: int = 2, stem: int = 4, leaves: bool = True) -> Image.Image:
    """A stem with a blob of petals on it: size 1 is a single-pixel head, 2 a plus, 3 a ring."""
    w = 5 + 2 * (size - 1)
    h = stem + 1 + 2 * size
    img = canvas(w, h)
    cx = w // 2
    top = h - stem - 1
    for y in range(top, h):
        put(img, cx, y, STEM if y > top else STEM_LIT)
    if leaves and stem >= 3:
        put(img, cx - 1, h - 2, STEM_LIT)
        put(img, cx + 1, h - 3, STEM_LIT)
    hy = top - size + 1
    core = mix(petal, YELLOW, 0.6) if petal != YELLOW else mix(petal, WOOD, 0.3)
    if size == 1:
        put(img, cx, top, petal)
        put(img, cx, top - 1, lift(petal, 1.15))
    elif size == 2:
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            put(img, cx + dx, hy + dy, petal)
        put(img, cx, hy, core)
        put(img, cx - 1, hy - 1, lift(petal, 1.2))
    else:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if abs(dx) + abs(dy) <= 3 and not (abs(dx) == 2 and abs(dy) == 2):
                    put(img, cx + dx, hy + dy, petal)
        put(img, cx, hy, core)
        put(img, cx - 1, hy - 1, lift(petal, 1.2))
        put(img, cx + 1, hy + 1, mix(petal, OUTLINE, 0.3))
    return img


def cluster(petal, count: int = 3) -> Image.Image:
    """Several small flowers in a tuft of grass, for the lawn: a patch, not a stem."""
    w, h = 11, 8
    img = canvas(w, h)
    for i in range(6):
        x = 1 + rng.randrange(w - 2)
        blade = STEM if i % 2 else STEM_LIT
        for y in range(h - 1 - rng.randrange(2, 4), h):
            put(img, x, y, blade)
    spots = rng.sample(range(1, w - 1), count)
    for i, x in enumerate(spots):
        y = 1 + rng.randrange(3)
        c = petal if i % 2 == 0 else lift(petal, 1.15)
        put(img, x, y, c)
        put(img, x, y + 1, STEM_LIT)
    return img


def reed() -> Image.Image:
    w, h = 7, 17
    img = canvas(w, h)
    for i, (x, tall, lean) in enumerate(((3, 16, 0), (1, 11, 1), (5, 13, -1))):
        c = STEM if i == 0 else STEM_LIT
        for y in range(h - tall, h):
            dx = lean if y < h - tall + 4 else 0
            put(img, x + dx, y, c)
    # The seed head, brown.
    for y in range(1, 5):
        put(img, 3, y, WOOD)
    put(img, 3, 0, mix(WOOD, OUTLINE, 0.4))
    put(img, 2, 2, mix(WOOD, SAND, 0.3))
    return img


def lily(bloom) -> Image.Image:
    w, h = 13, 8
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.ellipse((0, 1, w - 1, h - 1), fill=PAD, outline=OUTLINE)
    # The notch every pad has, cut towards the middle from the near edge.
    for y in range(4, h):
        put(img, 6, y, (0, 0, 0, 0))
    put(img, 6, 4, OUTLINE)
    put(img, 5, 5, OUTLINE)
    put(img, 7, 5, OUTLINE)
    for x in range(3, 9):
        put(img, x, 2, PAD_LIT)
    if bloom is not None:
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            put(img, 4 + dx, 2 + dy, bloom)
        put(img, 4, 1, lift(bloom, 1.2))
        put(img, 4, 2, mix(bloom, YELLOW, 0.5))
    return img


def shrub(berries: bool) -> Image.Image:
    w, h = 15, 12
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.ellipse((1, 2, w - 2, h - 1), fill=GRASS_DARK, outline=OUTLINE)
    d.ellipse((3, 0, w - 4, h - 4), fill=LEAF, outline=OUTLINE)
    d.ellipse((5, 1, w - 6, h - 6), fill=GRASS_LIGHT)
    for _ in range(6):
        put(img, 2 + rng.randrange(w - 4), 3 + rng.randrange(h - 5), GRASS_DARK)
    if berries:
        for _ in range(5):
            put(img, 3 + rng.randrange(w - 6), 2 + rng.randrange(h - 5), BERRY)
    # A shadow row under the mound, so it sits on the ground rather than floating.
    for x in range(3, w - 3):
        put(img, x, h - 1, OUTLINE)
    return img


def beach_grass() -> Image.Image:
    w, h = 9, 8
    img = canvas(w, h)
    for i, (x, tall, lean) in enumerate(((4, 7, 0), (2, 5, -1), (6, 6, 1), (1, 3, 0), (7, 4, 0))):
        c = PALE_GRASS if i % 2 == 0 else mix(PALE_GRASS, GRASS_LIGHT, 0.5)
        for y in range(h - tall, h):
            dx = lean if y < h - tall + 2 else 0
            put(img, x + dx, y, c)
    return img


def sprout(kind: str) -> Image.Image:
    """What every plant looks like the moment it arrives: two blades, or a bud on the water."""
    if kind == "water":
        img = canvas(5, 3)
        for x in range(1, 4):
            put(img, x, 1, PAD)
        put(img, 2, 0, PAD_LIT)
        return img
    img = canvas(3, 4)
    put(img, 1, 1, STEM_LIT)
    put(img, 1, 2, STEM)
    put(img, 1, 3, STEM)
    put(img, 0, 0, STEM_LIT)
    put(img, 2, 1, STEM_LIT)
    return img


PLANTS = [
    ("flower_red", flower(RED, 2), "lawn"),
    ("flower_yellow", flower(YELLOW, 2, 3), "lawn"),
    ("flower_white", flower(WHITE, 2, 4), "lawn"),
    ("flower_blue", flower(BLUE, 3, 4), "lawn"),
    ("flower_pink", flower(PINK, 3, 5), "lawn"),
    ("flower_violet", flower(VIOLET, 1, 3), "lawn"),
    ("patch_red", cluster(RED), "lawn"),
    ("patch_yellow", cluster(YELLOW, 4), "lawn"),
    ("patch_white", cluster(WHITE), "lawn"),
    ("patch_blue", cluster(BLUE, 4), "lawn"),
    ("shrub", shrub(False), "lawn"),
    ("shrub_berries", shrub(True), "lawn"),
    ("reed", reed(), "beach"),
    ("beach_grass", beach_grass(), "beach"),
    ("beach_flower", flower(ORANGE, 2, 3, leaves=False), "beach"),
    ("beach_flower_white", flower(WHITE, 1, 2, leaves=False), "beach"),
    ("lily", lily(None), "water"),
    ("lily_pink", lily(PINK), "water"),
    ("lily_white", lily(WHITE), "water"),
]


def pack() -> None:
    gutter = 1
    sprouts = {kind: sprout(kind) for kind in ("lawn", "beach", "water")}
    x, y, shelf = gutter, gutter, 0
    wide = 160
    places: dict[str, dict] = {}
    items: list[tuple[str, Image.Image]] = [(n, im) for n, im, _ in PLANTS]
    items += [("sprout_" + k, im) for k, im in sprouts.items()]
    spots: dict[str, tuple[int, int]] = {}
    for name, im in items:
        if x + im.width + gutter > wide:
            x = gutter
            y += shelf + gutter
            shelf = 0
        spots[name] = (x, y)
        x += im.width + gutter
        shelf = max(shelf, im.height)
    tall = y + shelf + gutter
    sheet = canvas(wide, tall)
    for name, im in items:
        sheet.alpha_composite(im, spots[name])
    for name, im, kind in PLANTS:
        sp = sprouts[kind]
        places[name] = {
            "full": [*spots[name], im.width, im.height],
            "sprout": [*spots["sprout_" + kind], sp.width, sp.height],
            "kind": kind,
        }
    sheet.save(OUT_PNG)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(places, f, indent=1)
    # A contact sheet at 4x on the lawn's green, to judge the shapes by eye.
    big = Image.new("RGBA", (wide * 4, tall * 4), GRASS_LIGHT)
    big.alpha_composite(sheet.resize((wide * 4, tall * 4), Image.NEAREST))
    big.save(SHEET_PNG)
    print(f"wrote {OUT_PNG} {wide}x{tall}, {len(PLANTS)} plants, contact sheet {SHEET_PNG}")


if __name__ == "__main__":
    pack()

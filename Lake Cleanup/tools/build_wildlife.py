#!/usr/bin/env python
"""Draws the wildlife sheets that come back to the lake as it is cleaned (scripts/wildlife.gd):
the frogs, recoloured off the Pixel Frog pack onto the palette, and the turtles, ducks,
ducklings and the frog's swimming shadow, built here by rule.

Everything is at one painted pixel to one and drawn by the game at 2 (Lake.ART_PIXEL), off
palette.tres swatches lifted or mixed, and outlined the pack's way (a dark ring on the
drawing's own edge) so a rule-built duck stands beside a pack frog without being from
another game.

Writes:
  assets/wildlife/frog_green.png, frog_brown.png  the pack's top half, halved to cells
      16x16 (the pack is drawn at twice the game's grain; at the game's 2 a whole frog
      stood as tall as the angler),
      8 rows (S, SE, E, NE, N, NW, W, SW) x 16 columns (idle 0-2, croak 3-6, jump 7-10,
      hop 11-15), recoloured
  assets/wildlife/critters.png + critters.json    turtles, ducks, ducklings, swim shadows:
      {"<name>": [x, y, w, h]}, every picture facing LEFT (the game mirrors for right),
      its foot the middle of its bottom row
  tools/last_wildlife_sheet.png                   contact sheet at 4x

Run from the project root, then reimport:
  <psd-extract venv python> tools/build_wildlife.py
  <godot> --path . --headless --import
"""
from __future__ import annotations

import json
import math
import os

from PIL import Image, ImageDraw

SRC = os.path.join("art_source", "frog_spritesheets", "frog_spritesheets")
OUT_DIR = os.path.join("assets", "wildlife")
SHEET_PNG = os.path.join("tools", "last_wildlife_sheet.png")


def rgb(r: float, g: float, b: float):
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def mix(a, b, t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def lift(c, k: float):
    return tuple(max(0, min(255, round(c[i] * k))) for i in range(3)) + (255,)


# palette.tres
GRASS_LIGHT = rgb(0.427, 0.529, 0.251)
GRASS_DARK = rgb(0.196, 0.341, 0.114)
LEAF = rgb(0.294, 0.424, 0.18)
SAND = rgb(0.91, 0.804, 0.592)
WOOD = rgb(0.541, 0.235, 0.141)
FOAM = rgb(0.933, 0.965, 0.984)
WATER_CLEAN = rgb(0.353, 0.525, 0.678)
WATER_DEEP = rgb(0.173, 0.302, 0.431)
WATER_LIGHT = rgb(0.769, 0.859, 0.91)
DIRTY_LIGHT = rgb(0.369, 0.435, 0.227)
BLACK = (0, 0, 0, 255)

YELLOW = mix(SAND, lift(DIRTY_LIGHT, 1.6), 0.35)
ORANGE = mix(WOOD, SAND, 0.45)
OUTLINE = mix(GRASS_DARK, BLACK, 0.55)
OUTLINE_BROWN = mix(WOOD, BLACK, 0.62)

# The frogs: the pack's ramp, darkest to lightest (black and white left alone), laid onto
# these. Brighter than the lawn on purpose, or a green frog on grass is a hole in it.
FROG_RAMPS = {
    "green": [mix(GRASS_DARK, BLACK, 0.3), GRASS_DARK, lift(LEAF, 1.35), lift(GRASS_LIGHT, 1.3),
              mix(lift(GRASS_LIGHT, 1.35), SAND, 0.45), mix(SAND, FOAM, 0.5)],
    "brown": [mix(WOOD, BLACK, 0.45), lift(WOOD, 0.8), mix(WOOD, SAND, 0.3), mix(WOOD, SAND, 0.52),
              mix(WOOD, SAND, 0.7), mix(SAND, FOAM, 0.4)],
}


def luma(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def recolour_frog(colour: str) -> Image.Image:
    src = Image.open(os.path.join(SRC, f"frog_{colour}_spritesheet.png")).convert("RGBA").crop((0, 0, 512, 256))
    # Buckets of near-equal colours: the pack carries 245/254/255 alphas of one swatch.
    found: dict[tuple, list] = {}
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            key = (r // 12, g // 12, b // 12)
            found.setdefault(key, []).append((r, g, b))
    keys = sorted(found, key=lambda k: luma([v * 12 for v in k]))
    middle = [k for k in keys if not (max(k) <= 1 or min(k) >= 20)]
    ramp = FROG_RAMPS[colour]
    table = {}
    for i, k in enumerate(middle):
        t = i / max(len(middle) - 1, 1) * (len(ramp) - 1)
        lo = int(t)
        hi = min(lo + 1, len(ramp) - 1)
        table[k] = mix(ramp[lo], ramp[hi], t - lo)
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    po = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            key = (r // 12, g // 12, b // 12)
            if max(key) <= 1:
                po[x, y] = OUTLINE if colour == "green" else OUTLINE_BROWN
            elif min(key) >= 20:
                po[x, y] = FOAM
            else:
                po[x, y] = table[key]
    return halve(out)


def halve(img: Image.Image) -> Image.Image:
    """Half size, each pixel the commonest opaque colour of its 2x2 block, and empty unless
    at least two of the four are filled — so the outline stays a line rather than a stipple."""
    from collections import Counter
    out = Image.new("RGBA", (img.width // 2, img.height // 2), (0, 0, 0, 0))
    p = img.load()
    for y in range(out.height):
        for x in range(out.width):
            block = [p[2 * x + i, 2 * y + j] for i in (0, 1) for j in (0, 1)]
            filled = [c for c in block if c[3] > 0]
            if len(filled) < 2:
                continue
            out.putpixel((x, y), Counter(filled).most_common(1)[0][0])
    return out


# ---- rule-built critters ----------------------------------------------------------------

def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def outline(img: Image.Image, ink) -> Image.Image:
    """The pack's dark ring: every filled pixel touching an empty one (edge-on) is inked."""
    src = img.copy()
    p = src.load()
    q = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if p[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= img.width or ny >= img.height or p[nx, ny][3] == 0:
                    q[x, y] = ink
                    break
    return img


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


# Turtle: a domed shell, a head that pokes out ahead (left), stubby legs.
SHELL = mix(LEAF, WOOD, 0.35)
SHELL_LIT = mix(lift(LEAF, 1.3), SAND, 0.25)
SHELL_PLATE = mix(SHELL, BLACK, 0.3)
SKIN = mix(GRASS_LIGHT, SAND, 0.35)
SKIN_DARK = mix(SKIN, GRASS_DARK, 0.45)


# Where the two seen legs stand in each walk frame: (front x, back x). Frame 0 is the pose a
# resting turtle holds; the walk steps the front leg forward, back to rest, then the back
# leg back, back to rest — one leg at a time, never both.
TURTLE_STRIDE = [(3, 8), (2, 8), (3, 8), (3, 9)]


def turtle(pose: str, step: int = 0, head_up: bool = False) -> Image.Image:
    """Side on, facing left: a domed shell on four stubby legs (two seen), the head held
    ahead. `step` is a frame of TURTLE_STRIDE when walking; sitting and tucked stand on frame
    0, so at rest nothing moves but the head. `head_up` lifts the head a painted pixel, the
    slow nod the game plays at rest and on the walk."""
    w, h = 12, 7
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    swim = pose == "swim"
    top = 1 if not swim else 2
    bottom = h - 3 if not swim else h - 1
    hy = (2 if not swim else 3) - (1 if head_up else 0)
    if pose != "tuck":
        d.rectangle((0, hy - 1, 3, hy + 1), fill=SKIN)
        # The neck stays joined to the shell when the head is up.
        d.rectangle((2, hy, 4, hy + 2), fill=SKIN)
    d.ellipse((3, top, w - 2, bottom + 3), fill=SHELL)
    d.rectangle((3, bottom + 1, w - 2, bottom + 3), fill=(0, 0, 0, 0))
    if not swim:
        put(img, w - 2, bottom, SKIN_DARK)
    img = outline(img, OUTLINE)
    for px_ in (5, 7, 9):
        for y in range(top + 2, bottom + 1):
            if img.getpixel((px_, y))[3] and img.getpixel((px_, y)) != OUTLINE:
                put(img, px_, y, SHELL_PLATE)
    for x in range(5, 9):
        if img.getpixel((x, top + 1))[3] and img.getpixel((x, top + 1)) != OUTLINE:
            put(img, x, top + 1, SHELL_LIT)
    if pose != "tuck":
        put(img, 1, hy, OUTLINE)
    if swim:
        # Flippers just breaking the surface either side, paddling by turns.
        fx = (2, 10) if step == 0 else (3, 9)
        for x in fx:
            put(img, x, h - 1, SKIN_DARK)
        return img
    # Legs under the shell's rim, after the ring so the ring does not eat them: two pixels
    # wide, a dark foot under each.
    front, back = TURTLE_STRIDE[step if pose == "walk" else 0]
    for lx in (front, back):
        for y in range(bottom + 1, bottom + 3):
            put(img, lx, y, SKIN)
            put(img, lx + 1, y, SKIN_DARK)
        put(img, lx, bottom + 2, OUTLINE)
        put(img, lx + 1, bottom + 2, OUTLINE)
    return img


# Ducks: a drake (green head, grey body) and a hen (mottled brown).
DRAKE = {
    "head": mix(lift(GRASS_DARK, 1.2), WATER_DEEP, 0.35), "head_lit": mix(lift(LEAF, 1.4), WATER_CLEAN, 0.3),
    "collar": FOAM, "breast": mix(WOOD, SAND, 0.2), "body": mix(SAND, FOAM, 0.35),
    "body_dark": mix(mix(SAND, FOAM, 0.35), WATER_DEEP, 0.3), "tail": mix(WATER_DEEP, BLACK, 0.4),
    "bill": YELLOW, "wing": mix(SAND, WATER_DEEP, 0.4), "spec": lift(WATER_CLEAN, 1.2),
}
HEN = {
    "head": mix(WOOD, SAND, 0.5), "head_lit": mix(WOOD, SAND, 0.7), "collar": None,
    "breast": mix(WOOD, SAND, 0.45), "body": mix(WOOD, SAND, 0.55), "body_dark": mix(WOOD, SAND, 0.3),
    "tail": mix(WOOD, BLACK, 0.3), "bill": ORANGE, "wing": mix(WOOD, SAND, 0.38), "spec": lift(WATER_CLEAN, 1.2),
}


def duck(kind: dict, pose: str) -> Image.Image:
    """Side on, facing left. Poses: swim0, swim1, dabble, fly0 (wings up), fly1, fly2 (down)."""
    w, h = 14, 11
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    fly = pose.startswith("fly")
    base = h - 1 if not fly else h - 3
    if pose == "dabble":
        d.ellipse((3, base - 4, 10, base), fill=kind["body"])
        d.polygon([(9, base - 3), (11, base - 6), (10, base - 1)], fill=kind["tail"])
        d.ellipse((2, base - 2, 5, base), fill=kind["breast"])
        return outline(img, OUTLINE)
    bob = 1 if pose == "swim1" else 0
    d.ellipse((3, base - 4 + bob, 12, base), fill=kind["body"])
    d.ellipse((3, base - 3 + bob, 6, base), fill=kind["breast"])
    d.polygon([(10, base - 3 + bob), (13, base - 5 + bob), (12, base - 1)], fill=kind["tail"])
    hy = base - 8 + bob if not fly else base - 6
    d.rectangle((3, hy + 2, 4, base - 3), fill=kind["head"] if kind["collar"] else kind["breast"])
    d.ellipse((1, hy, 5, hy + 3), fill=kind["head"])
    d.line((0, hy + 1, 0, hy + 2), fill=kind["bill"])
    if fly:
        wing = {"fly0": [(6, base - 3), (9, base - 3), (7, base - 9)],
                "fly1": [(5, base - 3), (10, base - 3), (11, base - 6)],
                "fly2": [(6, base - 2), (9, base - 2), (8, base + 2)]}[pose]
        d.polygon(wing, fill=kind["wing"])
    img = outline(img, OUTLINE)
    if kind["collar"]:
        for x in (3, 4):
            if img.getpixel((x, hy + 4))[3] and img.getpixel((x, hy + 4)) != OUTLINE:
                put(img, x, hy + 4, kind["collar"])
    put(img, 2, hy + 1, OUTLINE)
    put(img, 3, hy + 1, kind["head_lit"])
    if not fly:
        for x in range(7, 10):
            put(img, x, base - 2 + bob, kind["spec"])
        for x in range(6, 10):
            put(img, x, base - 3 + bob, kind["body_dark"])
    return img


DUCKLING = mix(YELLOW, SAND, 0.3)
DUCKLING_DARK = mix(WOOD, SAND, 0.45)


def duckling(pose: str) -> Image.Image:
    w, h = 7, 6
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    fly = pose.startswith("fly")
    base = h - 1 if not fly else h - 2
    bob = 1 if pose == "swim1" else 0
    d.ellipse((2, base - 2 + bob, 6, base), fill=DUCKLING)
    d.ellipse((1, base - 4 + bob, 3, base - 2 + bob), fill=DUCKLING)
    put(img, 0, base - 3 + bob, ORANGE)
    if fly:
        wy = base - 4 if pose == "fly0" else base - 1
        d.line((4, base - 2, 5, wy), fill=DUCKLING_DARK)
    img = outline(img, OUTLINE)
    put(img, 0, base - 3 + bob, ORANGE)
    put(img, 4, base - 1 + bob, DUCKLING_DARK)
    return img


def frog_swim(heading: float, frame: int) -> Image.Image:
    """The frog under the water seen from above: a silhouette, white, tinted at runtime.
    Built on the plane and squashed 2:1, heading in radians on the plane (0 = screen right).
    Frame 0 legs tucked, 1 kicking out, 2 stretched."""
    w, h = 11, 7
    img = canvas(w, h)
    ch, sh = math.cos(heading), math.sin(heading)
    kick = (0.0, 2.2, 4.0)[frame]
    spread = (3.0, 4.0, 2.2)[frame]

    def inside(u: float, v: float) -> bool:
        # u along the heading, v across it; frog body centred on 0.
        if (u / 4.6) ** 2 + (v / 3.2) ** 2 <= 1.0:
            return True
        if ((u - 4.0) / 2.2) ** 2 + (v / 2.2) ** 2 <= 1.0:
            return True
        for s in (-1.0, 1.0):
            # Back legs: a thigh out, a shin trailing back by the kick.
            if abs(v - s * spread) <= 1.25 and -4.5 - kick <= u <= -1.5:
                return True
            # Front legs: short stubs.
            if abs(v - s * 3.0) <= 1.1 and 0.8 <= u <= 2.8:
                return True
        return False

    for y in range(h):
        for x in range(w):
            px_ = (x + 0.5 - w / 2) * 1.35
            py_ = (y + 0.5 - h / 2) * 2.7
            u = px_ * ch + py_ * sh
            v = -px_ * sh + py_ * ch
            if inside(u, v):
                img.putpixel((x, y), (255, 255, 255, 255))
    return img


def pack() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    frogs = {}
    for colour in ("green", "brown"):
        frogs[colour] = recolour_frog(colour)
        frogs[colour].save(os.path.join(OUT_DIR, f"frog_{colour}.png"))
    items: list[tuple[str, Image.Image]] = []
    for up in (False, True):
        tag = "_up" if up else ""
        items.append((f"turtle_sit{tag}", turtle("sit", 0, up)))
        for step in range(len(TURTLE_STRIDE)):
            items.append((f"turtle_walk{step}{tag}", turtle("walk", step, up)))
    items.append(("turtle_tuck", turtle("tuck")))
    for step in (0, 1):
        items.append((f"turtle_swim{step}", turtle("swim", step)))
    for name, kind in (("drake", DRAKE), ("hen", HEN)):
        for pose in ("swim0", "swim1", "dabble", "fly0", "fly1", "fly2"):
            items.append((f"{name}_{pose}", duck(kind, pose)))
    for pose in ("swim0", "swim1", "fly0", "fly1"):
        items.append((f"duckling_{pose}", duckling(pose)))
    for k in range(8):
        for f in range(3):
            items.append((f"frogswim_{k}_{f}", frog_swim(k * math.tau / 8.0, f)))
    gutter, wide = 1, 160
    x, y, shelf = gutter, gutter, 0
    spots = {}
    for name, im in items:
        if x + im.width + gutter > wide:
            x, y, shelf = gutter, y + shelf + gutter, 0
        spots[name] = (x, y)
        x += im.width + gutter
        shelf = max(shelf, im.height)
    tall = y + shelf + gutter
    sheet = canvas(wide, tall)
    table = {}
    for name, im in items:
        sheet.alpha_composite(im, spots[name])
        table[name] = [*spots[name], im.width, im.height]
    sheet.save(os.path.join(OUT_DIR, "critters.png"))
    with open(os.path.join(OUT_DIR, "critters.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(table, f, indent=1)
    # Contact sheet: the critters on water and on sand, and a strip of each frog.
    big = Image.new("RGBA", (wide * 4, tall * 4 + 2 * 256 * 2), WATER_CLEAN)
    sand = Image.new("RGBA", (wide * 4, tall * 2), SAND)
    big.alpha_composite(sand, (0, tall * 2))
    big.alpha_composite(sheet.resize((wide * 4, tall * 4), Image.NEAREST))
    for i, colour in enumerate(("green", "brown")):
        strip = Image.new("RGBA", (256, 128), mix(GRASS_LIGHT, SAND, 0.5))
        strip.alpha_composite(frogs[colour])
        big.alpha_composite(strip.resize((1024, 512), Image.NEAREST).crop((0, 0, wide * 4, 512)), (0, tall * 4 + i * 512))
    big.save(SHEET_PNG)
    print(f"wrote {OUT_DIR}: frogs, critters {wide}x{tall} ({len(items)} pictures); contact {SHEET_PNG}")


if __name__ == "__main__":
    pack()

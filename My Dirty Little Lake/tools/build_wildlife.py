#!/usr/bin/env python
"""Draws the wildlife sheets that come back to the lake as it is cleaned (scripts/wildlife.gd):
the frogs, recoloured off the Pixel Frog pack onto the palette, the ducks, ducklings and
the frog's swimming shadow, built here by rule, and the pack animals (see FAUNA).

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
      its foot the middle of its bottom row; and the songbirds, `bird_<species>_<anim><n>`
      (Kelano Studio's Wild Birds, art_source/birds, halved and mirrored, see `songbird`)
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



# The land animals (2026-10-05, `/grill-me` with Richard): bought packs in art_source/Fauna,
# cut whole into one picture a frame, every one facing LEFT (the sheet's rule), at their own
# painted grain. Attack, death, howl, jump, hurt, kick and stomp rows are left out.
#   Bunnies (Toffeecraft): Brown2Color, BunnyBlack, WhiteBunny; idle 12 and run 8, 32 cells.
#   Snakes (Carysaurus): SnakeBlue, SnakeCorn; a 7-frame slither, 32 cells.
#   Fox (Original) and wolf (Metal) (LapizWCG): idle row 0 and run row 1, 32 cells.
#   Capybara (Rainloaf): no grid, so every drawing is found on the sheet by its outline and
#       set on its feet; side walk, front walk, back walk, idle, sit, run, stand (from lying).
#   Peacock (folded 36x38 cells, open 32): walk side / front / back, folded and tail open.
# Each group of frames shares one crop centred on the first frame's feet (`_stood`), so the
# game's foot, the middle of the bottom row, is where the animal stands in every frame.
FAUNA = os.path.join("art_source", "Fauna")
BUNNY_COATS = {"brown": "Brown2Color", "black": "BunnyBlack", "white": "WhiteBunny"}
SNAKE_COATS = {"blue": "SnakeBlue", "corn": "SnakeCorn"}
CANID_SHEETS = {
    "fox": os.path.join("Wolf&Fox_by_LapizWCG", "MiniFox", "MiniFox [Original].png"),
    "wolf": os.path.join("Wolf&Fox_by_LapizWCG", "MiniWolf", "MiniWolf [Metal].png"),
}
# (sheet row, frames) by animation; the fox's and the wolf's own rows.
CANID_ROWS = {"fox": {"idle": (0, 4), "run": (1, 4)}, "wolf": {"idle": (0, 4), "run": (1, 6)}}
# The capybara's rows on its sheet: the top of each band in px, and the view it is.
CAPY_ROWS = {
    "walk": (89, "side"), "fwalk": (123, "front"), "bwalk": (155, "back"),
    "idle": (192, "side"), "sit": (225, "side"), "run": (257, "side"), "stand": (289, "side"),
}
CAPY_BAND = 24
# The peacock: its two sheets, their cell, frames down a column, and which column is which
# view (each column is a direction, each row a walking frame; "side" is the one facing left).
PEACOCK = {
    "fold": ("Peacock-folded-tail-Sheet.png", (36, 38), 4, {"front": 0, "back": 2, "side": 3}),
    "open": ("Peacock-walk-Sheet.png", (32, 32), 3, {"front": 1, "back": 2, "side": 3}),
}


def _cells(sheet: Image.Image, cell: tuple[int, int], row: int, count: int, col0: int = 0,
        down: bool = False) -> list[Image.Image]:
    """`count` cells of a grid sheet, along a row (or down a column when `down`)."""
    w, h = cell
    out = []
    for k in range(count):
        cx, cy = (col0, row + k) if down else (col0 + k, row)
        out.append(sheet.crop((cx * w, cy * h, (cx + 1) * w, (cy + 1) * h)))
    return out


def _foot_x(img: Image.Image) -> int:
    """The middle of the lowest opaque row: where the animal stands."""
    p = img.load()
    for y in range(img.height - 1, -1, -1):
        xs = [x for x in range(img.width) if p[x, y][3] > 0]
        if xs:
            return (xs[0] + xs[-1] + 1) // 2
    return img.width // 2


def _stood(frames: list[Image.Image]) -> list[Image.Image]:
    """One crop for a group of frames, centred on the first frame's feet and as tall as the
    tallest, its bottom row the ground."""
    anchor = _foot_x(frames[0])
    left, top, right, bottom = 10 ** 6, 10 ** 6, -1, -1
    for im in frames:
        b = im.getbbox()
        if b is None:
            continue
        left, top, right, bottom = min(left, b[0]), min(top, b[1]), max(right, b[2]), max(bottom, b[3])
    half = max(anchor - left, right - anchor)
    out = []
    for im in frames:
        cell = Image.new("RGBA", (half * 2, bottom - top), (0, 0, 0, 0))
        cell.alpha_composite(im.crop((anchor - half, top, anchor + half, bottom)))
        out.append(cell)
    return out


def _left(frames: list[Image.Image]) -> list[Image.Image]:
    return [im.transpose(Image.FLIP_LEFT_RIGHT) for im in frames]


# The turtle (2026-10-05, Richard bought the TurtlePaid pack; supersedes the rule-built
# turtle): five of its sheets, 32 cells, side on, mirrored to face left, all on one crop.
# Attack, Die, Hurt, Jump and LieDown are not used.
TURTLE_SRC = os.path.join(FAUNA, "TurtlePaid", "TurtlePaid")
TURTLE_ANIMS = {"idle": "Idle", "sit": "Sit", "sleep": "Sleep", "hide": "Hide", "walk": "Walking"}


def turtles() -> list[tuple[str, Image.Image]]:
    names, frames = [], []
    for anim, file in TURTLE_ANIMS.items():
        sheet = Image.open(os.path.join(TURTLE_SRC, f"{file}.png")).convert("RGBA")
        for k, im in enumerate(_left(_cells(sheet, (32, 32), 0, sheet.width // 32))):
            names.append(f"turtle_{anim}{k}")
            frames.append(im)
    return list(zip(names, _stood(frames)))


def bunnies() -> list[tuple[str, Image.Image]]:
    out = []
    for coat, folder in BUNNY_COATS.items():
        root = os.path.join(FAUNA, "AllBunniesFree", "AllBunniesFree", folder)
        idle = Image.open(os.path.join(root, "Idle.png")).convert("RGBA")
        run = Image.open(os.path.join(root, "Running.png")).convert("RGBA")
        n_idle = idle.width // 32
        frames = _stood(_left(_cells(idle, (32, 32), 0, n_idle)) + _left(_cells(run, (32, 32), 0, run.width // 32)))
        for k, im in enumerate(frames):
            name = f"bunny_{coat}_idle{k}" if k < n_idle else f"bunny_{coat}_run{k - n_idle}"
            out.append((name, im))
    return out


# The snakes are drawn 15% smaller than painted (Richard, 2026-10-05: "make snakes smaller, at
# least 15%"), picked off tools/last_snake_sizes.png: box-filtered, alpha cut at
# SNAKE_ALPHA_CUT, every pixel snapped back to the picture's own colours. Nearest dropped
# whole rows of the thin body and broke its bands.
SNAKE_SHRINK = 0.85
SNAKE_ALPHA_CUT = 110


def _shrink(img: Image.Image, share: float) -> Image.Image:
    """Pixel art made smaller without dropping its lines: averaged down, cut hard at the
    alpha, and each colour put back onto the nearest colour the picture already had."""
    w, h = round(img.width * share), round(img.height * share)
    pal = list({c for c in img.getdata() if c[3] > 0})
    out = img.resize((w, h), Image.BOX)
    p = out.load()
    for y in range(h):
        for x in range(w):
            c = p[x, y]
            if c[3] <= SNAKE_ALPHA_CUT:
                p[x, y] = (0, 0, 0, 0)
                continue
            p[x, y] = min(pal, key=lambda q: (q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 + (q[2] - c[2]) ** 2)
    return out


def snakes() -> list[tuple[str, Image.Image]]:
    out = []
    for coat, stem in SNAKE_COATS.items():
        sheet = Image.open(os.path.join(FAUNA, "PixelSnakes_Free_Carysaurus", "PixelSnakes_Free_Carysaurus",
            f"{stem}-Walk.png")).convert("RGBA")
        cells = [_shrink(im, SNAKE_SHRINK) for im in _left(_cells(sheet, (32, 32), 0, sheet.width // 32))]
        for k, im in enumerate(_stood(cells)):
            out.append((f"snake_{coat}_{k}", im))
    return out


def canids() -> list[tuple[str, Image.Image]]:
    out = []
    for kind, path in CANID_SHEETS.items():
        sheet = Image.open(os.path.join(FAUNA, path)).convert("RGBA")
        names, frames = [], []
        for anim, (row, count) in CANID_ROWS[kind].items():
            for k, im in enumerate(_left(_cells(sheet, (32, 32), row, count))):
                names.append(f"{kind}_{anim}{k}")
                frames.append(im)
        out.extend(zip(names, _stood(frames)))
    return out


def _capy_sheet() -> Image.Image:
    """The capybara's sheet with its flat background taken out."""
    sheet = Image.open(os.path.join(FAUNA, "mini capy.png")).convert("RGBA")
    bg = sheet.getpixel((0, 0))
    p = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            if p[x, y][:3] == bg[:3]:
                p[x, y] = (0, 0, 0, 0)
    return sheet


def _drawings(sheet: Image.Image, top: int, band: int) -> list[Image.Image]:
    """Every drawing in a band of the sheet, left to right: columns of the band holding ink,
    split where a column holds none."""
    strip = sheet.crop((0, top - 2, sheet.width, top + band))
    p = strip.load()
    inked = [any(p[x, y][3] > 0 for y in range(strip.height)) for x in range(strip.width)]
    out, x = [], 0
    while x < strip.width:
        if not inked[x]:
            x += 1
            continue
        start = x
        while x < strip.width and inked[x]:
            x += 1
        piece = strip.crop((start, 0, x, strip.height))
        if piece.getbbox() and (x - start) > 4:
            out.append(piece)
    return out


def capybara() -> list[tuple[str, Image.Image]]:
    sheet = _capy_sheet()
    by_view: dict[str, list[tuple[str, Image.Image]]] = {}
    for anim, (top, view) in CAPY_ROWS.items():
        for k, d in enumerate(_drawings(sheet, top, CAPY_BAND)):
            # Set on its feet in a 32 cell: bottom row the ground, feet in the middle.
            d = d.crop(d.getbbox())
            cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            cell.alpha_composite(d, (16 - _foot_x(d), 32 - d.height))
            by_view.setdefault(view, []).append((f"capy_{anim}{k}", cell))
    out = []
    for view, pairs in by_view.items():
        out.extend(zip([n for n, _ in pairs], _stood([im for _, im in pairs])))
    return out


def peacock() -> list[tuple[str, Image.Image]]:
    out = []
    for mode, (file, cell, count, cols) in PEACOCK.items():
        sheet = Image.open(os.path.join(FAUNA, file)).convert("RGBA")
        for view, col in cols.items():
            for k, im in enumerate(_stood(_cells(sheet, cell, 0, count, col, down=True))):
                out.append((f"peacock_{mode}_{view}{k}", im))
    return out


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


def frog_dive(heading: float, frame: int, colour: str) -> Image.Image:
    """The frog under clean water, seen through it (2026-09-30, the lakebed pass): the same
    shape as `frog_swim` and on the same canvas, so the silhouette is its shadow on the bed,
    but in its own colours: a lighter stripe down the back, darker legs, two dark eyes on the
    head, ringed in the ramp's darkest step. The game mixes it towards the water by depth."""
    w, h = 11, 7
    img = canvas(w, h)
    ramp = FROG_RAMPS[colour]
    ch, sh = math.cos(heading), math.sin(heading)
    kick = (0.0, 2.2, 4.0)[frame]
    spread = (3.0, 4.0, 2.2)[frame]

    def part(u: float, v: float) -> str:
        if ((u - 4.0) / 2.2) ** 2 + (v / 2.2) ** 2 <= 1.0:
            return "eye" if u > 4.2 and abs(abs(v) - 1.2) < 0.7 else "head"
        if (u / 4.6) ** 2 + (v / 3.2) ** 2 <= 1.0:
            return "stripe" if abs(v) < 0.9 else "body"
        for s_ in (-1.0, 1.0):
            if abs(v - s_ * spread) <= 1.25 and -4.5 - kick <= u <= -1.5:
                return "leg"
            if abs(v - s_ * 3.0) <= 1.1 and 0.8 <= u <= 2.8:
                return "leg"
        return ""

    tone = {"head": ramp[3], "body": ramp[2], "stripe": ramp[4], "leg": ramp[1], "eye": ramp[0]}
    for y in range(h):
        for x in range(w):
            px_ = (x + 0.5 - w / 2) * 1.35
            py_ = (y + 0.5 - h / 2) * 2.7
            u = px_ * ch + py_ * sh
            v = -px_ * sh + py_ * ch
            k = part(u, v)
            if k:
                img.putpixel((x, y), tone[k])
    eyes = [(x, y) for y in range(h) for x in range(w) if img.getpixel((x, y)) == tone["eye"]]
    outline(img, ramp[0])
    for x, y in eyes:
        img.putpixel((x, y), BLACK)
    return img


# The crayfish on the lakebed (2026-09-30, the lakebed pass, off tools/lakebed_mockup.py): a
# rust-brown body and red-orange claws, each a five-step ramp, darkest first.
CRAY_RAMP = [(41, 20, 13, 255), (87, 46, 26, 255), (133, 77, 41, 255), (173, 112, 61, 255), (214, 158, 97, 255)]
CLAW_RAMP = [(77, 20, 10, 255), (133, 41, 20, 255), (189, 77, 36, 255), (219, 117, 56, 255), (240, 168, 102, 255)]


def _raster(shapes, heading: float, squash: float, scale: float, size: int = 48, s_: int = 4) -> dict:
    """Labelled shapes drawn in a body frame (x forward) at `heading`, laid on the plane and
    squashed; each pixel takes the label covering most of it, if at least 40% is covered."""
    from PIL import ImageDraw
    ca, sa = math.cos(heading), math.sin(heading)
    im = Image.new("L", (size * s_, size * s_), 0)
    dr = ImageDraw.Draw(im)

    def tr(p):
        x, y = p[0] * scale, p[1] * scale
        return ((x * ca - y * sa) * s_ + size * s_ / 2, (x * sa + y * ca) * squash * s_ + size * s_ / 2)
    for i, sh in enumerate(shapes):
        if sh[1] == "line":
            dr.line([tr(p) for p in sh[2]], fill=i + 1, width=max(1, int(sh[3] * s_ * scale)))
        else:
            dr.polygon([tr(p) for p in sh[2]], fill=i + 1)
    px = im.load()
    out = {}
    for y in range(size):
        for x in range(size):
            count = {}
            for yy in range(s_):
                for xx in range(s_):
                    v = px[x * s_ + xx, y * s_ + yy]
                    if v: count[v] = count.get(v, 0) + 1
            if count and sum(count.values()) >= s_ * s_ * .4:
                v = max(count.items(), key=lambda kv: (kv[1], kv[0]))[0]
                out[(x - size // 2, y - size // 2)] = shapes[v - 1][0]
    return out


def _ellipse(cx, cy, rx, ry, n=14):
    return [(cx + math.cos(2 * math.pi * i / n) * rx, cy + math.sin(2 * math.pi * i / n) * ry) for i in range(n)]


def crayfish(heading: float, frame: int, size: float = 1.1) -> Image.Image:
    """Seen from above at the game's view, squashed a little less than the plane (0.78) so the
    claws read: carapace and rostrum, five tail segments and a fan, two claws on bent arms with
    a dark gap in each pincer, walking legs and long feelers. Frame 1 has the claws open wider
    and the legs a step on. A lit rim on the carapace and claws, alternate tail segments a step
    down, a dark ring round all but the legs and feelers."""
    open_ = (.25, .45)[frame]
    step = (0.0, .45)[frame]
    shapes = []
    for s_ in (-1, 1):
        shapes.append(("feeler", "line", [(4.5, s_ * .5), (8, s_ * 2.4), (12, s_ * 4.2)], .3))
        for k in range(3):
            lx = 1.2 - k * 1.3 + (step if k % 2 == (0 if s_ > 0 else 1) else -step)
            shapes.append(("leg", "line", [(lx, s_ * 1.4), (lx - .4, s_ * 2.8), (lx - 1.2, s_ * 3.6)], .45))
    for s_ in (-1, 1):
        shapes.append(("arm", "line", [(2.8, s_ * 1.3), (4.4, s_ * 2.9), (6.0, s_ * 3.4)], 1.1))
        shapes.append(("claw", "poly", [(5.6, s_ * 2.6), (7.4, s_ * 2.2), (10.4, s_ * (2.4 - open_ * 1.4)),
                                        (10.8, s_ * 2.9), (10.6, s_ * 3.6), (9.0, s_ * 4.6), (6.6, s_ * 4.6),
                                        (5.4, s_ * 3.8)]))
        shapes.append(("gap", "line", [(8.2, s_ * 3.1), (10.8, s_ * 3.1)], .45))
    for k in range(5):
        shapes.append(("seg%d" % (k % 2), "poly", _ellipse(-1 - k * 1.25 - .6, 0, .8, 1.5 - k * .16)))
    shapes.append(("fan", "poly", [(-7, 0), (-8.8, -2), (-9.4, -.8), (-9.4, .8), (-8.8, 2)]))
    shapes.append(("shell", "poly", _ellipse(1.2, 0, 2.6, 1.7, 18)))
    shapes.append(("rostrum", "poly", [(3.4, -.6), (5.2, 0), (3.4, .6)]))
    lab = _raster(shapes, heading, .78, size)
    cells = set(lab)
    body = {k for k, v in lab.items() if v not in ("feeler", "leg", "gap")}
    xs = [k[0] for k in lab] + [k[0] + 1 for k in body] + [k[0] - 1 for k in body]
    ys = [k[1] for k in lab] + [k[1] + 1 for k in body] + [k[1] - 1 for k in body]
    w, h = 26, 20
    img = canvas(w, h)

    def put_(x, y, c):
        put(img, x + w // 2, y + h // 2, c)
    for (x, y), l in lab.items():
        up = (x, y - 1) not in cells or lab.get((x, y - 1)) in ("feeler", "leg")
        if l in ("feeler", "leg"): c = CRAY_RAMP[1]
        elif l == "claw": c = CLAW_RAMP[3 if up else 2]
        elif l == "gap": c = CLAW_RAMP[0]
        elif l in ("arm", "shell"): c = CRAY_RAMP[3 if up else 2]
        elif l == "rostrum": c = CRAY_RAMP[3]
        elif l == "seg1": c = CRAY_RAMP[1]
        else: c = CRAY_RAMP[2]
        put_(x, y, c)
    for (x, y) in body:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in body:
                put_(q[0], q[1], CRAY_RAMP[0])
    # The legs and feelers, one pixel wide: too thin for the coverage cut, so drawn as lines
    # of whole pixels between their projected joints, under the body.
    ca, sa = math.cos(heading), math.sin(heading)
    for sh in shapes:
        if sh[0] not in ("feeler", "leg"):
            continue
        pts = [((p[0] * ca - p[1] * sa) * size, (p[0] * sa + p[1] * ca) * .78 * size) for p in sh[2]]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(n + 1):
                q = (round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n))
                if q not in body and (q[0] + 1, q[1]) not in body or q not in body and sh[0] == "feeler":
                    if img.getpixel((min(max(q[0] + w // 2, 0), w - 1), min(max(q[1] + h // 2, 0), h - 1)))[3] == 0:
                        put_(q[0], q[1], CRAY_RAMP[1] if sh[0] == "leg" else CRAY_RAMP[2])
    return img


# ---- songbirds ----------------------------------------------------------------------------
# Kelano Studio's Wild Birds pack (bought, art_source/birds/<species>/<species>_<anim>.png):
# 32 px cells, side on, facing right, painted with their own dark outline. Halved like the
# frogs (the pack is drawn at twice the game's grain) and mirrored to face LEFT like every
# other critter. The cockatoo and the parrot are in the folder and never read, by decision.

BIRDS_SRC = os.path.join("art_source", "birds")
BIRD_SPECIES = ("sparrow", "tit", "bluebird", "cardinal")
BIRD_ANIMS = {"fly": 4, "idle": 5, "peck": 5, "walk": 5}
BIRD_CELL = 32
# A block whose darkest pixel is under this luma counts as carrying the painted outline.
BIRD_INK = 70.0


def halve_inked(img: Image.Image) -> Image.Image:
    """`halve`, then every pixel on the halved picture's own edge takes the darkest pixel of
    its 2x2 block if that one is outline-dark: the commonest colour of an edge block is often
    the fill, and the painted outline came out broken."""
    out = halve(img)
    p = img.load()
    q = out.load()
    src = out.copy().load()
    for y in range(out.height):
        for x in range(out.width):
            if src[x, y][3] == 0:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= out.width or ny >= out.height or src[nx, ny][3] == 0:
                    edge = True
                    break
            if not edge:
                continue
            block = [p[2 * x + i, 2 * y + j] for i in (0, 1) for j in (0, 1)]
            dark = min((c for c in block if c[3] > 0), key=luma)
            if luma(dark) < BIRD_INK:
                q[x, y] = dark
    return out


def songbird(species: str) -> list[tuple[str, Image.Image]]:
    """Every frame of one species as `bird_<species>_<anim><n>`, halved, mirrored to face left.
    The ground poses (idle, peck, walk) share one crop and the flight its own, so a bird does
    not shift between frames: its foot is the middle of the shared crop's bottom row."""
    frames: dict[str, list[Image.Image]] = {}
    for anim, count in BIRD_ANIMS.items():
        sheet = Image.open(os.path.join(BIRDS_SRC, species, f"{species}_{anim}.png")).convert("RGBA")
        frames[anim] = [
            halve_inked(sheet.crop((k * BIRD_CELL, 0, (k + 1) * BIRD_CELL, BIRD_CELL)).transpose(Image.FLIP_LEFT_RIGHT))
            for k in range(count)
        ]
    out: list[tuple[str, Image.Image]] = []
    for group in (("idle", "peck", "walk"), ("fly",)):
        box = None
        for anim in group:
            for im in frames[anim]:
                b = im.getbbox()
                if b is None:
                    continue
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        for anim in group:
            for k, im in enumerate(frames[anim]):
                out.append((f"bird_{species}_{anim}{k}", im.crop(box)))
    return out


def pack() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    frogs = {}
    for colour in ("green", "brown"):
        frogs[colour] = recolour_frog(colour)
        frogs[colour].save(os.path.join(OUT_DIR, f"frog_{colour}.png"))
    items: list[tuple[str, Image.Image]] = []
    items.extend(turtles())
    for name, kind in (("drake", DRAKE), ("hen", HEN)):
        for pose in ("swim0", "swim1", "dabble", "fly0", "fly1", "fly2"):
            items.append((f"{name}_{pose}", duck(kind, pose)))
    for pose in ("swim0", "swim1", "fly0", "fly1"):
        items.append((f"duckling_{pose}", duckling(pose)))
    items.extend(bunnies())
    items.extend(snakes())
    items.extend(canids())
    items.extend(capybara())
    items.extend(peacock())
    for k in range(8):
        for f in range(2):
            items.append((f"crayfish_{k}_{f}", crayfish(k * math.tau / 8.0, f)))
    for k in range(8):
        for f in range(3):
            items.append((f"frogswim_{k}_{f}", frog_swim(k * math.tau / 8.0, f)))
            for colour in ("green", "brown"):
                items.append((f"frogdive_{colour}_{k}_{f}", frog_dive(k * math.tau / 8.0, f, colour)))
    for species in BIRD_SPECIES:
        items.extend(songbird(species))
    gutter, wide = 1, 512
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

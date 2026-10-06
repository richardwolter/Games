"""Steam's achievement icons, built by rule from the game's own art (2026-10-06).

Each of the nine is a 64 x 64 picture: the game icon's rounded water square (murky bottom-left,
clean top-right, stepped diagonal, flat palette swatches) with one of the game's own sprites
standing on it at a whole-pixel scale, its shadow under it in the water's dark. The locked
twin is the same picture greyed and dimmed, which is what Steam shows until it is earned.

Rules first, picked off the contact sheet; Richard may change any subject below.

Writes (with --write), into Marketing/My Dirty Little Lake/steam/achievements/:
  <API_NAME>.png          the unlocked icon, 64 x 64
  <API_NAME>_locked.png   the locked one
Always writes tools/last_achievement_icons.png: every icon at 1x and x4, both states.

Run from the project root:
  PYTHONPATH=<psd-extract venv site-packages> python tools/build_achievement_icons.py [--write]
"""

import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "..", "Marketing", "My Dirty Little Lake", "steam", "achievements")

SIZE = 64
GRID = 2            # the backing is drawn on a 32 px grid, two screen px a cell
ROUND = 4           # corner cut, in grid cells
FIT = 50            # the most a subject may take, either way, before it drops a scale step
LOCK_DIM = 0.55     # how dark the locked twin is, after the grey


def palette():
    out = {}
    with open(os.path.join(ROOT, "resources", "palette.tres"), encoding="utf-8") as f:
        for line in f:
            if "= Color(" not in line:
                continue
            name, rest = line.split("=", 1)
            nums = rest.strip()[len("Color("):-1].split(",")
            out[name.strip()] = tuple(round(float(n) * 255) for n in nums[:3]) + (255,)
    return out


PAL = palette()


def image(rel):
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")


def crop(img, region):
    x, y, w, h = region
    return img.crop((x, y, x + w, y + h))


def trimmed(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def piece(name, view=0):
    """A find's restored picture, as the shed shows it."""
    with open(os.path.join(ROOT, "assets", "pieces.json"), encoding="utf-8") as f:
        cat = json.load(f)
    entry = next(e for e in cat["pieces"] if e["name"] == name)
    sheet = cat["sheets"][entry["alt_sheet"]]["file"].replace("res://", "")
    return trimmed(crop(image(sheet), entry["alt_views"][view]))


def critter(name):
    with open(os.path.join(ROOT, "assets", "wildlife", "critters.json"), encoding="utf-8") as f:
        regions = json.load(f)
    regions = regions.get("regions", regions)
    return trimmed(crop(image("assets/wildlife/critters.png"), regions[name]))


def hive_part(name):
    with open(os.path.join(ROOT, "assets", "hive_room.json"), encoding="utf-8") as f:
        parts = json.load(f)["pieces"]
    region = parts[name]
    if isinstance(region, dict):
        region = region.get("region", region.get("rect"))
    return trimmed(crop(image("assets/hive_room.png"), region))


def plant(name):
    with open(os.path.join(ROOT, "assets", "flora.json"), encoding="utf-8") as f:
        region = json.load(f)[name]["full"]
    return trimmed(crop(image("assets/flora.png"), region))


def honey_jar():
    """The bottling step's jar, laid as the step lays it: back glass, honey, front glass,
    label, lid. The honey is the glass's inside from a third down, in the jar's amber."""
    back = hive_part("jar2_back")
    jar = Image.new("RGBA", back.size)
    jar.alpha_composite(back)
    honey = (226, 150, 34, 255)
    honey_lit = (246, 194, 72, 255)
    top = back.height // 3
    for y in range(top, back.height):
        row = [x for x in range(back.width) if back.getpixel((x, y))[3]]
        if len(row) < 5:
            continue
        for x in range(row[0] + 2, row[-1] - 1):
            jar.putpixel((x, y), honey_lit if y == top or x == row[0] + 3 else honey)
    for part in ("jar2_front", "jar2_label", "jar2_lid"):
        jar.alpha_composite(hive_part(part))
    return trimmed(jar)


def dog(breed, row="sit", frame=0, face_right=True):
    with open(os.path.join(ROOT, "assets", "dogs", "dog_%s.json" % breed), encoding="utf-8") as f:
        seq = json.load(f)["sequences"][row]
    art = trimmed(crop(image("assets/dogs/dog_%s.png" % breed), seq[frame]["region"]))
    return art.transpose(Image.FLIP_LEFT_RIGHT) if face_right else art


def coin(frame=0):
    with open(os.path.join(ROOT, "assets", "coin.json"), encoding="utf-8") as f:
        w, h = json.load(f)["frame"]
    return trimmed(image("assets/coin.png").crop((frame * w, 0, frame * w + w, h)))


def rubbish(names):
    with open(os.path.join(ROOT, "assets", "pieces.json"), encoding="utf-8") as f:
        cat = json.load(f)
    sheet = image("assets/lake_objects.png")
    out = []
    for name in names:
        entry = next((e for e in cat["pieces"] if e["name"] == name), None)
        if entry is not None:
            out.append(trimmed(crop(sheet, entry["region"])))
    return out


def scale_of(art, most=FIT):
    return max(1, min(most // max(art.width, 1), most // max(art.height, 1)))


def up(art, k):
    return art.resize((art.width * k, art.height * k), Image.NEAREST)


# The backing --------------------------------------------------------------------------------

def mask():
    cells = SIZE // GRID
    keep = [[True] * cells for _ in range(cells)]
    for y in range(cells):
        for x in range(cells):
            cx = min(max(x + 0.5, ROUND), cells - ROUND)
            cy = min(max(y + 0.5, ROUND), cells - ROUND)
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > ROUND * ROUND:
                keep[y][x] = False
    return keep


MASK = mask()


def backing():
    """The game icon's water: clean over the stepped diagonal, murky under it, a lit band
    across the clean half and a deeper one under the murky, all on the 32 px grid."""
    cells = SIZE // GRID
    img = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(img)
    for y in range(cells):
        for x in range(cells):
            if not MASK[y][x]:
                continue
            if x > y:
                c = PAL["water_clean_light"] if x - y > 14 and (x + 2 * y) % 13 == 0 and (x * 7 + y) % 3 == 0 else PAL["water_clean"]
            else:
                c = PAL["water_dirty_deep"] if y - x > 14 and (2 * x + y) % 13 == 0 and (x + 5 * y) % 3 == 0 else PAL["water_dirty"]
            d.rectangle((x * GRID, y * GRID, x * GRID + GRID - 1, y * GRID + GRID - 1), fill=c)
    return img


def shade_under(img, cx, foot, wide):
    """A flat shadow in the deep water's ink, on the grid, under a subject's foot."""
    ink = PAL["water_dirty_deep"][:3] + (150,)
    layer = Image.new("RGBA", img.size)
    d = ImageDraw.Draw(layer)
    half = max(2, wide // 2)
    for y in range(-3, 4):
        for x in range(-half, half + 1):
            if (x / half) ** 2 + (y / 3.5) ** 2 <= 1.0:
                px, py = cx + x, foot + y
                gx, gy = px // GRID, py // GRID
                if 0 <= gx < len(MASK) and 0 <= gy < len(MASK) and MASK[gy][gx]:
                    d.point((px, py), fill=ink)
    img.alpha_composite(layer)


def stand(img, art, cx, foot, shadow=True):
    """Put art with its feet on (cx, foot), cut by the backing's corners."""
    x0 = cx - art.width // 2
    y0 = foot - art.height
    if shadow:
        shade_under(img, cx, foot, int(art.width * 0.8))
    layer = Image.new("RGBA", img.size)
    layer.paste(art, (x0, y0), art)
    for y in range(SIZE):
        for x in range(SIZE):
            if not MASK[y // GRID][x // GRID]:
                layer.putpixel((x, y), (0, 0, 0, 0))
    img.alpha_composite(layer)


# Rule-built marks ---------------------------------------------------------------------------

INK = (24, 18, 17, 255)
GOLD = (246, 196, 72, 255)
GOLD_DEEP = (196, 132, 40, 255)
WHITE = (250, 246, 232, 255)


def star(d, cx, cy, arm, colour=GOLD):
    """The finds' four-point star in whole pixels."""
    d.point((cx, cy), fill=WHITE)
    for k in range(1, arm + 1):
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            d.point((cx + dx, cy + dy), fill=colour)


def arrow_up(scale=2):
    """The HUD's green block arrow, ringed in black, drawn on a coarse grid."""
    rows = [
        "....##....",
        "...####...",
        "..######..",
        ".########.",
        "##########",
        "...####...",
        "...####...",
        "...####...",
        "...####...",
        "...####...",
    ]
    # The aim ring's green: the pack's grass_light lifted, as `CastNet.AIM_OK` is.
    green = tuple(min(255, int(v * 1.52)) for v in PAL["grass_light"][:3]) + (255,)
    w, h = len(rows[0]), len(rows)
    art = Image.new("RGBA", ((w + 2) * scale, (h + 2) * scale))
    d = ImageDraw.Draw(art)

    def on(x, y):
        return 0 <= y < h and 0 <= x < w and rows[y][x] == "#"
    for y in range(-1, h + 1):
        for x in range(-1, w + 1):
            if on(x, y):
                c = green
            elif any(on(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                c = INK
            else:
                continue
            gx, gy = (x + 1) * scale, (y + 1) * scale
            d.rectangle((gx, gy, gx + scale - 1, gy + scale - 1), fill=c)
    # A lit edge down the shaft's left and along the head's top-left.
    lit = tuple(min(255, int(v * 1.25)) for v in green[:3]) + (255,)
    for y in range(h):
        for x in range(w):
            if on(x, y) and not on(x - 1, y):
                gx, gy = (x + 1) * scale, (y + 1) * scale
                d.rectangle((gx, gy, gx + scale - 1, gy + scale - 1), fill=lit)
    return art


def funnel():
    """A waterspout on the 32 px grid: grey bands narrowing to a foot, a cloud on top."""
    cells_w, cells_h = 22, 24
    art = Image.new("RGBA", (cells_w * GRID, cells_h * GRID))
    d = ImageDraw.Draw(art)
    greys = [(150, 160, 168, 255), (118, 128, 138, 255), (182, 190, 196, 255)]

    def cell(x, y, c):
        d.rectangle((x * GRID, y * GRID, x * GRID + GRID - 1, y * GRID + GRID - 1), fill=c)
    mid = cells_w / 2.0
    for y in range(cells_h):
        t = y / (cells_h - 1)
        half = 10.5 * (1 - t) ** 1.6 + 1.2
        lean = 2.2 * (1 - t) - 1.0 * t
        for x in range(cells_w):
            off = x + 0.5 - (mid + lean)
            if abs(off) <= half:
                band = (y + int((off + 20) * 0.5)) % 3
                edge = abs(off) > half - 1.0
                cell(x, y, INK if edge else greys[band])
    return art


def notes():
    """Two quavers in black, on the grid, for the record player."""
    rows = [
        "......####",
        "....######",
        "....##..##",
        "....#....#",
        "....#....#",
        "..###..###",
        ".####.####",
        ".###..###.",
    ]
    art = Image.new("RGBA", (len(rows[0]) * GRID, len(rows) * GRID))
    d = ImageDraw.Draw(art)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                d.rectangle((x * GRID, y * GRID, x * GRID + GRID - 1, y * GRID + GRID - 1), fill=INK)
    return art


def heart():
    rows = [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
    art = Image.new("RGBA", (len(rows[0]) * GRID, len(rows) * GRID))
    d = ImageDraw.Draw(art)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                c = (232, 84, 96, 255) if not (x == 1 and y == 1) else WHITE
                d.rectangle((x * GRID, y * GRID, x * GRID + GRID - 1, y * GRID + GRID - 1), fill=c)
    return art


# The nine -----------------------------------------------------------------------------------

def decoraholic():
    img = backing()
    chair = piece("decor_pk_armchair")
    k = scale_of(chair, 40)
    stand(img, up(chair, k), 26, 54)
    vase = piece("decor_pk_flower_vase")
    stand(img, up(vase, max(1, k - 1 if vase.height * k > 34 else k)), 49, 52)
    d = ImageDraw.Draw(img)
    star(d, 50, 12, 3)
    star(d, 12, 16, 2)
    return img


def friend_of_nature():
    img = backing()
    for name, x, y in (("open_pads_pink", 14, 58), ("lily_pink", 52, 40), ("pk_flower_3", 50, 59),
                       ("pk_flower_7", 10, 44)):
        art = plant(name)
        stand(img, up(art, 2 if art.width <= 13 else 1), x, y, shadow=False)
    bird = critter("peacock_open_front0")
    stand(img, up(bird, 1) if bird.height > 30 else up(bird, 2), 32, 54)
    return img


def best_pals():
    img = backing()
    yellow = dog("22", face_right=True)
    orange = dog("02", face_right=False)
    k = scale_of(yellow, 30)
    stand(img, up(yellow, k), 18, 56)
    stand(img, up(orange, k), 46, 56)
    h = heart()
    img.alpha_composite(h, (32 - h.width // 2, 8))
    return img


def great_net():
    img = backing()
    names = ["plastic_bottle1", "metal_can1", "rubber_ball", "wood_chair", "metal_kettle",
             "plastic_cup2", "plastic_bottle3", "wood_chair2", "metal_kettle2"]
    pieces = rubbish(names)
    spots = [(20, 54), (32, 56), (44, 54), (26, 46), (38, 46), (32, 38), (16, 44), (48, 44), (32, 30)]
    for art, (x, y) in zip(pieces, spots):
        stand(img, up(art, 2 if max(art.width, art.height) <= 12 else 1), x, y, shadow=y >= 50)
    d = ImageDraw.Draw(img)
    star(d, 10, 12, 2)
    star(d, 54, 10, 3)
    return img


def maximalist():
    img = backing()
    a = arrow_up(3)
    stand(img, a, 32, 58)
    d = ImageDraw.Draw(img)
    star(d, 12, 14, 3)
    star(d, 52, 18, 2)
    star(d, 50, 44, 2)
    return img


def twistered():
    img = backing()
    f = funnel()
    stand(img, f, 30, 60)
    for art, (x, y) in zip(rubbish(["plastic_bottle1", "metal_can1", "rubber_ball"]),
                           [(10, 30), (54, 22), (50, 46)]):
        stand(img, art, x, y, shadow=False)
    return img


def honeymaker():
    img = backing()
    jar = honey_jar()
    stand(img, up(jar, scale_of(jar, 56)), 30, 60)
    bee = hive_part("bee_r")
    img.alpha_composite(up(bee, 2), (42, 10))
    return img


def island_dj():
    img = backing()
    player = piece("decor_vynil_player", 1)
    stand(img, up(player, scale_of(player, 46)), 28, 58)
    n = notes()
    img.alpha_composite(n, (40, 6))
    return img


def cheapskate():
    img = backing()
    c = coin(0)
    k = max(1, 34 // max(c.width, 1))
    big = up(c, k)
    for i in range(4):
        stand(img, big, 32, 58 - i * (big.height // 4 + 1), shadow=(i == 0))
    d = ImageDraw.Draw(img)
    star(d, 12, 14, 3)
    star(d, 52, 12, 2)
    return img


ICONS = [
    ("DECORAHOLIC", decoraholic),
    ("FRIEND_OF_NATURE", friend_of_nature),
    ("BEST_PALS", best_pals),
    ("GREAT_NET", great_net),
    ("MAXIMALIST", maximalist),
    ("TWISTERED", twistered),
    ("HONEYMAKER", honeymaker),
    ("ISLAND_DJ", island_dj),
    ("CHEAPSKATE", cheapskate),
]


def locked(img):
    out = Image.new("RGBA", img.size)
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            v = int((0.3 * r + 0.59 * g + 0.11 * b) * LOCK_DIM)
            out.putpixel((x, y), (v, v, v, a))
    return out


def flat(img, bg=(0, 0, 0)):
    """Steam's icons are JPG-friendly: the cut corners go to black, not to nothing."""
    out = Image.new("RGBA", img.size, bg + (255,))
    out.alpha_composite(img)
    return out.convert("RGB")


def main():
    write = "--write" in sys.argv
    built = [(name, make()) for name, make in ICONS]
    zoom = 4
    pad = 10
    cell = SIZE * zoom + pad
    sheet = Image.new("RGB", (pad + len(built) * cell, pad + 2 * (cell + SIZE + pad)), (40, 40, 44))
    for i, (name, img) in enumerate(built):
        for row, pic in enumerate((img, locked(img))):
            top = pad + row * (cell + SIZE + pad)
            sheet.paste(flat(pic.resize((SIZE * zoom, SIZE * zoom), Image.NEAREST)), (pad + i * cell, top))
            sheet.paste(flat(pic), (pad + i * cell, top + SIZE * zoom + 4))
        if write:
            os.makedirs(OUT, exist_ok=True)
            flat(img).save(os.path.join(OUT, name + ".png"))
            flat(locked(img)).save(os.path.join(OUT, name + "_locked.png"))
    sheet.save(os.path.join(ROOT, "tools", "last_achievement_icons.png"))
    print("sheet tools/last_achievement_icons.png", "written to " + OUT if write else "")


if __name__ == "__main__":
    main()

"""The wildlife shrink, side by side (2026-10-06, /grill-me with Richard): for each animal,
what is drawn now, a rebake (the art resampled smaller offline, whole pixels at its grain),
and draw scale alone (the same art drawn smaller, fractional pixels). Crayfish also get a
rule redraw, the builder's own shapes laid out smaller. Shown at 1.5 screen px a world px
(1080p, zoom 1) and at 3 (zoomed in). Writes tools/last_shrink_sheet.png.

Run from the project root with base python and the psd-extract site-packages on PYTHONPATH.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import build_wildlife as bw  # noqa: E402

OUT = os.path.join("tools", "last_shrink_sheet.png")
SAND = bw.SAND
GRASS = bw.mix(bw.GRASS_LIGHT, bw.GRASS_DARK, 0.4)
WATER = bw.mix(bw.WATER_CLEAN, bw.SAND, 0.25)


def frog_cells(colour: str) -> list[Image.Image]:
    sheet = bw.recolour_frog(colour)
    picks = [(0, 0), (1, 0), (2, 2), (4, 3)]
    return [sheet.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)) for c, r in picks]


def drawn(img: Image.Image, world_per_px: float, screen: float) -> Image.Image:
    """`img` drawn at `world_per_px` world px a painted px, seen at `screen` screen px a world
    px, nearest: what the GPU does with a fractional scale."""
    w = max(1, round(img.width * world_per_px * screen))
    h = max(1, round(img.height * world_per_px * screen))
    return img.resize((w, h), Image.NEAREST)


def build() -> None:
    bunny = [im for n, im in bw.bunnies() if n.startswith("bunny_brown_")][::3][:5]
    snake_raw = []
    for stem in ("SnakeBlue",):
        sheet = Image.open(os.path.join(bw.FAUNA, "PixelSnakes_Free_Carysaurus", "PixelSnakes_Free_Carysaurus",
            f"{stem}-Walk.png")).convert("RGBA")
        snake_raw = bw._left(bw._cells(sheet, (32, 32), 0, sheet.width // 32))[:4:2]
    snake_now = [bw._shrink(im, bw.SNAKE_SHRINK) for im in snake_raw]
    cray_now = [bw.crayfish(k * math.tau / 8.0, 0) for k in (0, 1, 2)]
    frog_now = frog_cells("green")
    dive_now = [bw.frog_dive(k * math.tau / 8.0, 1, "green") for k in (0, 2)]
    # (name, ground, world px a painted px now, how much smaller, rows: label -> (images, world px a px))
    animals = [
        ("Bunny / 1.5", SAND, 1.0, 1.5, {
            "now": (bunny, 1.0),
            "rebake": ([bw._shrink(im, 1 / 1.5) for im in bunny], 1.0),
            "draw scale": (bunny, 1 / 1.5)}),
        ("Snake / 1.5", GRASS, 1.0, 1.5, {
            "now": (snake_now, 1.0),
            "rebake": ([bw._shrink(im, bw.SNAKE_SHRINK / 1.5) for im in snake_raw], 1.0),
            "draw scale": (snake_now, 1 / 1.5)}),
        ("Crayfish / 1.5", WATER, 2.0, 1.5, {
            "now": (cray_now, 2.0),
            "rebake": ([bw._shrink(im, 1 / 1.5) for im in cray_now], 2.0),
            "rule redraw": ([bw.crayfish(k * math.tau / 8.0, 0, 1.1 / 1.5) for k in (0, 1, 2)], 2.0),
            "draw scale": (cray_now, 2.0 / 1.5)}),
        ("Frog / 1.2", SAND, 2.0, 1.2, {
            "now": (frog_now, 2.0),
            "rebake": ([bw._shrink(im, 13 / 16) for im in frog_now], 2.0),
            "draw scale": (frog_now, 2.0 / 1.2)}),
        ("Frog swimming / 1.2", WATER, 2.0, 1.2, {
            "now": (dive_now, 2.0),
            "rebake": ([bw._shrink(im, 1 / 1.2) for im in dive_now], 2.0),
            "draw scale": (dive_now, 2.0 / 1.2)}),
    ]
    pad, label_w = 16, 150
    blocks = []
    for title, ground, _now, _by, rows in animals:
        lines = []
        for label, (imgs, wpp) in rows.items():
            cells = []
            for screen in (1.5, 3.0):
                for im in imgs:
                    cells.append(drawn(im, wpp, screen))
                cells.append(None)
            lines.append((label, cells))
        blocks.append((title, ground, lines))
    width = 0
    height = 0
    for title, ground, lines in blocks:
        height += 28
        for label, cells in lines:
            w = label_w + sum((c.width + pad) if c else 40 for c in cells)
            width = max(width, w)
            height += max(c.height for c in cells if c) + pad
        height += pad
    sheet = Image.new("RGBA", (width + pad, height + pad), (40, 40, 44, 255))
    d = ImageDraw.Draw(sheet)
    y = pad
    for title, ground, lines in blocks:
        d.text((pad, y), title + "    (left half: 1080p zoom 1, right half: zoomed in)", fill=(255, 255, 255, 255))
        y += 28
        for label, cells in lines:
            tall = max(c.height for c in cells if c)
            d.rectangle((label_w - 8, y - 6, width, y + tall + 6), fill=ground)
            d.text((pad, y + tall // 2 - 6), label, fill=(255, 230, 160, 255))
            x = label_w
            for c in cells:
                if c is None:
                    x += 40
                    continue
                sheet.alpha_composite(c, (x, y + tall - c.height))
                x += c.width + pad
            y += tall + pad
        y += pad
    sheet.save(OUT)
    print("wrote", OUT, sheet.size)


if __name__ == "__main__":
    build()

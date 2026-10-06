#!/usr/bin/env python
"""Remaps the pollution meter's two water sheets onto the lake's own ramps.

The painted sheets (kept in art_source/meter/) were a teal gradient and a bright caustic
blue that are nowhere in the palette. Each pixel keeps its brightness *rank* within its
sheet and takes the colour at that rank along the ramp read from resources/palette.tres:
murky sheet -> water_dirty_*, clean sheet -> water_clean_*. Interpolated between the
ramp's steps, by decision, so the painted gradients and caustics survive; alpha untouched.

Run with the psd-extract venv python from the project root, then reimport.
Writes assets/ui/meter/{Murky,Clean}_Water.png and tools/last_meter_recolor.png.
"""
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "meter"
OUT = ROOT / "assets" / "ui" / "meter"
PALETTE = ROOT / "resources" / "palette.tres"
STEPS = ["deep", "mid", "", "shallow", "light"]
SHEETS = {"Murky_Water.png": "water_dirty", "Clean_Water.png": "water_clean"}
# How much of the ramp a sheet spans: the painting's darkest pixel lands at the first
# number along the ramp and its lightest at the second. The light step is a sparkle on the
# lake, not a body colour, so the body of a strip stops short of it.
SPAN = {"water_dirty": (0.0, 0.85), "water_clean": (0.1, 0.9)}


def ramp_of(name):
    text = PALETTE.read_text()
    out = []
    for step in STEPS:
        key = name + ("_" + step if step else "")
        found = re.search(r"^%s = Color\(([^)]*)\)" % key, text, re.M)
        out.append([float(v) for v in found.group(1).split(",")[:3]])
    return out


def along(ramp, t):
    at = min(max(t, 0.0), 1.0) * (len(ramp) - 1)
    low = min(int(at), len(ramp) - 2)
    mix = at - low
    return tuple(round(255 * (ramp[low][c] * (1 - mix) + ramp[low + 1][c] * mix)) for c in range(3))


def remap(image, ramp, span):
    pixels = image.load()
    lumas = sorted(
        0.299 * r + 0.587 * g + 0.114 * b
        for r, g, b, a in image.getdata() if a > 0
    )
    count = len(lumas)
    # Rank by brightness: first index of each luma in the sorted list.
    rank = {}
    for index, luma in enumerate(lumas):
        rank.setdefault(luma, index)
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            t = rank[0.299 * r + 0.587 * g + 0.114 * b] / max(count - 1, 1)
            pixels[x, y] = along(ramp, span[0] + (span[1] - span[0]) * t) + (a,)
    return image


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (290 * 2 * 3, 94 * 2 * 3), (255, 0, 255, 255))
    for row, (name, ramp_name) in enumerate(SHEETS.items()):
        kept = SOURCE / name
        if not kept.exists():
            shutil.copy(OUT / name, kept)
        before = Image.open(kept).convert("RGBA")
        after = remap(before.copy(), ramp_of(ramp_name), SPAN[ramp_name])
        after.save(OUT / name)
        for col, picture in enumerate((before, after)):
            big = picture.resize((picture.width * 3, picture.height * 3), Image.NEAREST)
            sheet.paste(big, (col * 290 * 3, row * 94 * 3), big)
        print(name, "->", ramp_name)
    sheet.save(ROOT / "tools" / "last_meter_recolor.png")


if __name__ == "__main__":
    main()

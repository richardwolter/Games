"""Measure Spotify's mark against the name beside it, frame by frame.

    python tools/check_mark_jitter.py        (psd-extract venv python, project root)

Run `tools/shot_ending.tscn` first: it saves six consecutive frames as
`tools/last_ending_jitter_<frame>.png`. This finds, in each, the topmost row of the
mark's green and the topmost row of the cream writing to the right of it, and prints
both and the gap between them.

The gap is the whole point. Both should climb by the same whole pixel every frame; a gap
that changes from frame to frame is the mark shivering against the word, which is what the
font's subpixel positioning did to it before the two were locked to one rounded row.
"""

import glob
import os
import re
import sys

from PIL import Image

# Spotify's green, and the cream Style.INK is written in, as 0-255.
GREEN = (30, 215, 96)
GREEN_NEAR = 60
INK_LEAST = (235, 228, 208)


def top_of(pixels, wide, tall, box, hit):
    left, top, right, bottom = box
    for y in range(max(0, top), min(tall, bottom)):
        for x in range(max(0, left), min(wide, right)):
            if hit(pixels[x, y][:3]):
                return y
    return -1


def is_green(rgb):
    return sum(abs(a - b) for a, b in zip(rgb, GREEN)) < GREEN_NEAR


def is_ink(rgb):
    return all(v >= floor for v, floor in zip(rgb, INK_LEAST))


def main():
    shots = sorted(
        glob.glob("tools/last_ending_jitter_*.png"),
        key=lambda p: int(re.search(r"_(\d+)\.png$", p).group(1)),
    )
    if not shots:
        sys.exit("no frames: run tools/shot_ending.tscn first")
    gaps = []
    for path in shots:
        image = Image.open(path).convert("RGB")
        pixels = image.load()
        wide, tall = image.size
        mark = top_of(pixels, wide, tall, (0, 0, wide, tall), is_green)
        if mark < 0:
            print("%-40s no mark on screen" % os.path.basename(path))
            continue
        # The name sits to the right of the mark, on its own rows.
        left = 0
        for x in range(wide):
            if is_green(pixels[x, mark][:3]):
                left = x
                break
        word = top_of(
            pixels, wide, tall,
            (left + 40, mark - 12, left + 300, mark + 34), is_ink,
        )
        gaps.append(word - mark)
        print("%-40s mark %4d  word %4d  gap %3d" % (os.path.basename(path), mark, word, word - mark))
    if gaps:
        spread = max(gaps) - min(gaps)
        print("\ngap spread across %d frames: %d px" % (len(gaps), spread))
        print("locked" if spread == 0 else "JITTERING")


if __name__ == "__main__":
    main()

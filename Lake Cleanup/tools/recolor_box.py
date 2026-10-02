#!/usr/bin/env python
"""Bring the recycle box's wood onto the hut's (2026-10-01, `/grill-me` with Richard).

The box was painted in its own greyed red-browns, darker than the hut's walls and redder
inside. Every wood pixel is remapped onto the hut's wall ramp (`build_shed_v2.WALL`) by
brightness, through a straight fit that lands the box's shaded (left) face on the hut's front
wall and its lit (right) face on the hut's gable, which are the same two faces lit the same
way. The outline and the blue recycle mark are left as painted.

Reads `art_source/recycle_box_v1.png` (the box as it was, kept so a re-run never compounds)
and writes `assets/Recycle_Box.png`.

**The piers take the same colour map, not a rebuild.** Their boxes and decks are the box's
exact colours (`tools/build_piers.py` pastes the box and paints the deck in its tones), so
every pixel of `art_source/piers_v1.png` (the sheet as it was) that is exactly one of the
box's wood colours is swapped for what that colour became, and `assets/piers.png` is written.
Re-running `build_piers.py` instead would also re-carve the four emblems off the rubbish as
it is now (the 0_mem0ry pack replaced the bottle, chair, extinguisher and duck they were cut
from), which nobody has picked. Reimport after.

Run from the project root, with the psd-extract venv's site-packages on PYTHONPATH:
  python tools/recolor_box.py
"""
import colorsys
import os
import shutil

from PIL import Image

from build_shed_v2 import WALL, mix

SOURCE = os.path.join("art_source", "recycle_box_v1.png")
OUT = os.path.join("assets", "Recycle_Box.png")
HUT = os.path.join("assets", "shed_tidied.png")
PIERS_SOURCE = os.path.join("art_source", "piers_v1.png")
PIERS_OUT = os.path.join("assets", "piers.png")
OUTLINE = (24, 18, 17)
## Columns of the box picture on each face (its near corner is the middle column), and the
## rows of its outer walls, under the mouth and over the foot.
LEFT, RIGHT, ROWS = range(2, 15), range(17, 30), range(14, 30)
## Where the darks bottom out (about the outline's brightness) and how hard they are pressed
## towards it.
DARK_FLOOR = 22.0
DARK_BITE = 1.6


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def ramp(t):
    t = max(0.0, min(6.0, t))
    k = min(int(t), 5)
    return mix(WALL[k], WALL[k + 1], t - k)


def ramp_at(target):
    """The ramp position whose brightness is `target`, by bisection (the ramp only rises)."""
    lo, hi = 0.0, 6.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if luma(ramp(mid)) < target:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def is_wood(c):
    if c[:3] == OUTLINE:
        return False
    h, s, _ = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return not (0.45 < h < 0.7 and s > 0.25)     # the blue mark


def face_mean(im, cols, rows):
    px = im.load()
    vals = [luma(px[x, y]) for y in rows for x in cols if px[x, y][3] > 0 and is_wood(px[x, y])]
    return sum(vals) / len(vals)


def hut_means():
    """The hut's front wall and gable brightness, sampled from the middle of each face."""
    im = Image.open(HUT).convert("RGBA")
    px = im.load()
    front = [luma(px[x, y]) for y in range(92, 118) for x in range(60, 80) if px[x, y][3] > 0]
    gable = [luma(px[x, y]) for y in range(95, 120) for x in range(95, 130) if px[x, y][3] > 0]
    return sum(front) / len(front), sum(gable) / len(gable)


def main():
    if not os.path.exists(SOURCE):
        shutil.copyfile(OUT, SOURCE)
    im = Image.open(SOURCE).convert("RGBA")
    box_l, box_r = face_mean(im, LEFT, ROWS), face_mean(im, RIGHT, ROWS)
    hut_f, hut_g = hut_means()
    gain = (hut_g - hut_f) / (box_r - box_l)
    px = im.load()
    swap = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0 or not is_wood(c):
                continue
            l = luma(c)
            if l >= box_l:
                target = hut_f + (l - box_l) * gain
            else:
                # under the shaded face (the inside of the box, the deep seams) the darks are
                # stretched down to the outline's own level rather than lifted with the faces,
                # or the box's mouth loses the shadow that makes it a hole
                f = max(0.0, (l - DARK_FLOOR) / (box_l - DARK_FLOOR))
                target = DARK_FLOOR + (hut_f - DARK_FLOOR) * f ** DARK_BITE
            new = tuple(ramp(ramp_at(target)))
            swap[c[:3]] = new
            px[x, y] = new + (c[3],)
    im.save(OUT)
    recolor_piers(swap)
    print("box faces %.0f / %.0f -> hut %.0f / %.0f (gain %.2f)" % (box_l, box_r, hut_f, hut_g, gain))


def recolor_piers(swap):
    if not os.path.exists(PIERS_SOURCE):
        return
    im = Image.open(PIERS_SOURCE).convert("RGBA")
    px = im.load()
    changed = 0
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] > 0 and c[:3] in swap:
                px[x, y] = swap[c[:3]] + (c[3],)
                changed += 1
    im.save(PIERS_OUT)
    print("piers: %d pixels swapped" % changed)


if __name__ == "__main__":
    main()

"""The word on the record's label, turned (2026-10-10, /grill-me with Richard).

The record player's menu (scripts/record_menu.gd) turns its record in 16 steps. NUVEN is printed
straight across the label, so it turns with it, and a word five pixels tall breaks up when it is
turned to an odd angle on the pixel grid. This bakes the word at the first four steps
(0, 22.5, 45 and 67.5 degrees). The other twelve steps are these turned by whole right angles,
which is exact, and the menu does that itself.

Every letter is turned on its own with RotSprite (scaled up 8x with Scale2x, turned, sampled back
down at every art pixel's middle), shifted by the fraction of a pixel that came out cleanest
(PHASES). A letter that still breaks is drawn by hand (DRAWN).

Writes assets/record_label.png: four cells of SIDE x SIDE, the disc's middle at each cell's middle,
white where the word is, clear elsewhere. The menu colours it and drops its shadow straight down
the screen. Writes tools/last_record_label.png, a close-up of the four steps on the label with a
coordinate grid, for judging and drawing fixes. Reimport after a re-run.

    PYTHONPATH=".../psd-extract/.venv/Lib/site-packages" python tools/build_record_label.py
    ... python tools/build_record_label.py --search   # print the cleanest phases
"""
import itertools
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

LABEL_R = 16
HOLE_R = 31 * 0.12
SIDE = LABEL_R * 2 + 1
MID = LABEL_R
STEPS = 4
UP = 8
# The word's middle row stands DY art px above the hole: a whole number, so every row of the
# five-tall word lands on an art pixel's middle at step 0.
DY = 8

FONT = {
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "U": ["#..#", "#..#", "#..#", "#..#", ".##."],
    "V": ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
    "E": ["####", "#...", "###.", "#...", "####"],
}
WORD = "NUVEN"

# RotSprite's answer swings a lot with where a letter falls between art pixels, so each letter is
# turned on its own and shifted, in its own frame, by the fraction of a pixel that came out
# cleanest (`python tools/build_record_label.py --search` prints the picks: eighths of a pixel,
# scored on staying one piece, keeping its pixel count, matching the letter's true coverage and
# not touching the letter before it). A letter moves less than half a pixel off its place.
PHASES = {
    0: [(0.0, 0.0)] * 5,
    1: [(-0.5, -0.25), (-0.375, -0.5), (-0.25, 0.125), (-0.125, -0.125), (-0.375, -0.5)],
    2: [(-0.375, -0.125), (0.0, -0.375), (0.375, -0.5), (0.375, 0.375), (0.25, 0.125)],
    3: [(-0.5, 0.25), (-0.125, -0.5), (0.125, -0.25), (-0.5, -0.125), (-0.25, -0.5)],
}

# Hand fixes: a letter RotSprite still leaves broken is drawn again by hand, as art pixels off
# the disc's middle (y down), by step and by its place in the word. Each is the letter's own
# strokes turned and laid one pixel wide, the stems kept the same length.
DRAWN = {
    # Step 1's first N: RotSprite ran the diagonal down beside the left stem into a 2x2 blob.
    (1, 0): [(-8, -14), (-8, -13), (-8, -12), (-9, -11), (-9, -10),
             (-7, -12), (-6, -11),
             (-5, -13), (-5, -12), (-6, -10), (-6, -9)],
    # Step 2's first N: read as a K. Two 45-degree stems three pixels apart, the diagonal
    # straight down between their tops and feet.
    (2, 0): [(-1, -16), (-2, -15), (-3, -14), (-4, -13),
             (-1, -15), (-1, -14), (-1, -13), (-1, -12),
             (1, -14), (0, -13), (-2, -11)],
}

# For the close-up only: the menu's own label colours.
RED, RED_LO, RED_HI = (178, 48, 44), (112, 26, 26), (214, 92, 70)
CREAM, OUT = (240, 232, 210), (8, 8, 8)


def glyph(ch):
    return np.array([[c == "#" for c in r] for r in FONT[ch]], dtype=bool)


def scale2x(a):
    h, w = a.shape
    p = np.pad(a, 1)
    B, D, F, H = p[0:h, 1:w + 1], p[1:h + 1, 0:w], p[1:h + 1, 2:w + 2], p[2:h + 2, 1:w + 1]
    e0 = np.where((D == B) & (B != F) & (D != H), D, a)
    e1 = np.where((B == F) & (B != D) & (F != H), F, a)
    e2 = np.where((D == H) & (D != B) & (H != F), D, a)
    e3 = np.where((H == F) & (D != H) & (B != F), F, a)
    out = np.zeros((h * 2, w * 2), dtype=bool)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    return out


_BIG = {}


def big_of(ch):
    """The letter scaled up UP x with Scale2x, one pixel of padding round it first."""
    if ch not in _BIG:
        a = np.pad(glyph(ch), 1)
        for _ in range(3):
            a = scale2x(a)
        _BIG[ch] = a
    return _BIG[ch]


def centres():
    """[(letter, its middle across the word in label px)], the word centred on the hole."""
    total = sum(len(FONT[c][0]) for c in WORD) + len(WORD) - 1
    x = 0
    out = []
    for ch in WORD:
        w = len(FONT[ch][0])
        out.append((ch, x + w / 2.0 - total / 2.0))
        x += w + 1
    return out


def letter_ink(ch, cx, step, phase, coverage=False):
    """Art pixels (x, y) off the disc's middle where this letter is ink at this step: every art
    pixel's middle turned back by the record's turn and looked up in the RotSprite picture.
    With `coverage`, also {pixel: share of it the upright letter truly covers}, for scoring."""
    a = glyph(ch)
    h, w = a.shape
    big = big_of(ch)
    bh, bw = big.shape
    theta = step / 16.0 * math.tau
    c, s = math.cos(-theta), math.sin(-theta)
    out = set()
    cov = {}
    for y in range(-LABEL_R, LABEL_R + 1):
        for x in range(-LABEL_R, LABEL_R + 1):
            lx, ly = x * c - y * s, x * s + y * c
            u = (lx - cx - phase[0]) * UP + bw / 2.0
            v = (ly + DY - phase[1]) * UP + bh / 2.0
            if not (-UP <= u < bw + UP and -UP <= v < bh + UP):
                continue
            iu, iv = int(math.floor(u)), int(math.floor(v))
            if 0 <= iu < bw and 0 <= iv < bh and big[iv, iu]:
                out.add((x, y))
            if coverage:
                n = 0
                for j in range(4):
                    for i in range(4):
                        sx, sy = x - 0.5 + (i + 0.5) / 4, y - 0.5 + (j + 0.5) / 4
                        qx, qy = sx * c - sy * s, sx * s + sy * c
                        gx = math.floor(qx - cx - phase[0] + w / 2.0)
                        gy = math.floor(qy + DY - phase[1] + h / 2.0)
                        if 0 <= gx < w and 0 <= gy < h and a[gy, gx]:
                            n += 1
                if n:
                    cov[(x, y)] = n / 16.0
    return (out, cov) if coverage else out


def ink_at(step):
    """Every letter's ink at this step: RotSprite at its pinned phase, or drawn by hand."""
    out = set()
    for i, ((ch, cx), ph) in enumerate(zip(centres(), PHASES[step])):
        drawn = DRAWN.get((step, i))
        out |= set(drawn) if drawn is not None else letter_ink(ch, cx, step, ph)
    return out


def _pieces(px):
    px = set(px)
    seen = set()
    n = 0
    for p in px:
        if p in seen:
            continue
        n += 1
        todo = [p]
        seen.add(p)
        while todo:
            x, y = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in px and q not in seen:
                        seen.add(q)
                        todo.append(q)
    return n


def search():
    """Print the cleanest phase for every letter at every step (what PHASES pins)."""
    vals = [i / 8.0 for i in range(-4, 4)]
    for step in range(1, STEPS):
        done = set()
        picks = []
        for ch, cx in centres():
            best = None
            for ph in itertools.product(vals, vals):
                ink, cov = letter_ink(ch, cx, step, ph, True)
                miss = sum(1 for p in ink if cov.get(p, 0) < 0.25)
                miss += sum(1 for p, v in cov.items() if v > 0.6 and p not in ink)
                score = (_pieces(ink) - 1) * 20 + abs(len(ink) - int(glyph(ch).sum())) * 2 + miss * 3
                if any((x + dx, y + dy) in done for (x, y) in ink
                       for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    score += 50
                if best is None or score < best[0]:
                    best = (score, ph, ink)
            picks.append(best[1])
            done |= best[2]
        print(step, picks)


def label_colour(x, y):
    q = math.hypot(x, y)
    if q <= HOLE_R:
        return OUT
    if q <= HOLE_R + 1.6:
        return RED_HI
    if q > LABEL_R - 1.0:
        return RED_LO
    return RED


def main():
    strip = Image.new("RGBA", (SIDE * STEPS, SIDE), (0, 0, 0, 0))
    sp = strip.load()
    cells = [ink_at(k) for k in range(STEPS)]
    for k, c in enumerate(cells):
        for (x, y) in c:
            if abs(x) <= LABEL_R and abs(y) <= LABEL_R:
                sp[k * SIDE + x + MID, y + MID] = (255, 255, 255, 255)
    strip.save("assets/record_label.png")

    # Close-up with a coordinate grid, for drawing fixes.
    z = 26
    pad = 40
    sheet = Image.new("RGB", (STEPS * (SIDE * z + pad) + pad, SIDE * z + pad * 2), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for k, c in enumerate(cells):
        ox = pad + k * (SIDE * z + pad)
        d.text((ox, 8), "step %d/16" % k, fill=(220, 220, 220))
        for y in range(-LABEL_R, LABEL_R + 1):
            for x in range(-LABEL_R, LABEL_R + 1):
                if math.hypot(x, y) > LABEL_R + 0.3:
                    col = (14, 14, 14)
                else:
                    col = label_colour(x, y)
                    if (x, y) in c and math.hypot(x, y) > HOLE_R:
                        col = CREAM
                    elif (x, y - 1) in c and math.hypot(x, y) > HOLE_R:
                        col = RED_LO
                px, py = ox + (x + MID) * z, pad + (y + MID) * z
                d.rectangle([px, py, px + z - 1, py + z - 1], fill=col)
                if y == -LABEL_R:
                    d.text((px + 2, pad - 12), str(x), fill=(150, 150, 150))
        for y in range(-LABEL_R, LABEL_R + 1):
            d.text((ox - 24, pad + (y + MID) * z + 4), str(y), fill=(150, 150, 150))
    sheet.save("tools/last_record_label.png")


if __name__ == "__main__":
    if "--search" in sys.argv:
        search()
    else:
        main()

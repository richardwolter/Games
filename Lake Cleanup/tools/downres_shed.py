#!/usr/bin/env python
"""Bring the hut down to the game's pixel.

The shed was painted at 130x127 and drawn at 1.1 world px per painted pixel; everything
else on the lake — the rubbish, the angler, the water — is drawn at 2.0, and the recycle
box at 2.5. Beside the box the hut read as a higher-resolution picture pasted on. This
resamples it to 103x101, drawn at 1.4 world px per painted pixel (`Iso.SHED_TALL` 141.4) —
coarser than it was, finer than the box, the grain Richard settled on after seeing 2.0, 1.6
and 1.4 side by side (2026-09-12).

A blind resample loses the detail — the window becomes a smudge, the door handle vanishes,
the thatch strokes alias into speckle, the plank seams average away. So this is a resample
**by class** with rules for the details, and then Richard polishes the result by hand in his
painter ("rules first, polish after"). From the moment the output has been hand-touched it
is the painted source, and a re-cut of the hut means redoing the polish.

Rules:
  * Every source pixel is classified the way tools/recolor_shed.py classifies it — wall,
    roof, fascia, window, grey hardware — and each target pixel takes the class that covers
    most of its footprint and the mean colour of *that class* inside it, so the roof never
    bleeds into the wall at the eaves and the outline does not grey out.
  * Alpha is thresholded: a pixel is there or it is not.
  * Colours are snapped per class to a few tones (WALL_TONES, ROOF_TONES, ...), which is
    what makes it read drawn rather than shrunk.
  * Seams: source pixels in the darkest SEAM_SHARE of the wall are seam ink; a target pixel
    whose footprint is SEAM_COVER seam or more is inked in the wall's darkest tone, so the
    plank lines survive as one-pixel lines.
  * Roof speckle: after snapping, a roof pixel none of whose four neighbours share its tone
    takes their commonest tone.
  * Window: redrawn as a fixed diamond (WINDOW_ARM) at the centre of where the window was,
    and the ring of its old frame — classed thatch by hue, but nowhere near the roof — is
    put back to wall: a thatch pixel with fewer than two thatch neighbours is not roof.
  * Handle: redrawn as HANDLE_TALL grey pixels at the centre of where the hardware was.
  * Fascia: any target pixel with FASCIA_COVER of fascia under it is fascia, in the fascia's
    lightest tone, so the line along the roof's edge stays continuous.

Input:   art_source/shed_tan.png    the hut as tools/slice_shed.gd cut it, 130x127
Output:  art_source/shed_101.png    the hut at its new grain, before the recolour

Then tools/recolor_shed.py reads shed_101.png and writes assets/shed.png.

Run from the project root with the psd-extract venv python:
  python tools/downres_shed.py [--mask out.png]
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import recolor_shed  # noqa: E402  (the classifier, so both scripts agree on what is wall)

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "shed_tan.png"
OUT = ROOT / "art_source" / "shed_101.png"

## The target height, in painted pixels. 101, drawn at 1.4 world px per painted pixel
## (Iso.SHED_TALL 141.4): tried at 2.0 (73 tall, one art pixel each — the grain matched the
## rubbish but the seams and thatch went to mush), 1.6, and 1.4, and Richard picked 1.4 as
## the coarsest that still holds the drawing (2026-09-12). Not an art-pixel multiple, so the
## hut draws faintly uneven on the screen grid, as its 1.1 original did; accepted.
TALL = 101

## Tones per class after snapping.
WALL_TONES = 7
ROOF_TONES = 5
FASCIA_TONES = 2

## Seams: the darkest share of the wall's pixels, and how much of a target pixel's footprint
## must be seam for it to be inked.
SEAM_SHARE = 0.12
SEAM_COVER = 0.4

## The fascia's share of a footprint that makes the pixel fascia.
FASCIA_COVER = 0.3

## The redrawn window: a diamond of this arm length (2 = 13 pixels, three wide at the middle).
WINDOW_ARM = 2
## The redrawn handle: this many grey pixels stacked.
HANDLE_TALL = 2
HANDLE_INK = (150, 145, 141)


def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def snap(pixels, tones):
    """Quantise a list of (x, y, rgb) to `tones` colours; returns {(x, y): rgb}."""
    if not pixels:
        return {}
    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata([p[2] for p in pixels])
    q = strip.quantize(colors=min(tones, len(pixels)), method=Image.Quantize.MEDIANCUT,
                       dither=Image.Dither.NONE).convert("RGB")
    got = list(q.getdata())
    return {(p[0], p[1]): got[i] for i, p in enumerate(pixels)}


def main():
    mask_out = None
    if "--mask" in sys.argv:
        mask_out = Path(sys.argv[sys.argv.index("--mask") + 1])
    # Trials: --tall N --out path renders another grain somewhere else without touching
    # the pipeline's file.
    tall = TALL
    out_path = OUT
    if "--tall" in sys.argv:
        tall = int(sys.argv[sys.argv.index("--tall") + 1])
    if "--out" in sys.argv:
        out_path = Path(sys.argv[sys.argv.index("--out") + 1])
    src = Image.open(SOURCE).convert("RGBA")
    sw, sh = src.size
    spx = src.load()
    kind = recolor_shed.classify(src)
    tw = int(round(sw * tall / float(sh)))
    th = tall

    # Seam ink in the source: the darkest share of the wall.
    walls = sorted(luma(spx[x, y]) for y in range(sh) for x in range(sw) if kind[y][x] == "w")
    seam_cut = walls[int(len(walls) * SEAM_SHARE)] if walls else 0.0

    # Per target pixel: coverage by class, mean colour by class, seam coverage.
    out_kind = [[" "] * tw for _ in range(th)]
    out_rgb = {}
    seam_hits = [[0.0] * tw for _ in range(th)]
    fascia_hits = [[0.0] * tw for _ in range(th)]
    window_pts = []
    handle_pts = []
    for ty in range(th):
        for tx in range(tw):
            x0, x1 = tx * sw / tw, (tx + 1) * sw / tw
            y0, y1 = ty * sh / th, (ty + 1) * sh / th
            cover = {}
            sums = {}
            total = 0.0
            opaque = 0.0
            for sy in range(int(y0), min(int(y1) + 1, sh)):
                wy = max(0.0, min(y1, sy + 1) - max(y0, sy))
                if wy <= 0.0:
                    continue
                for sx in range(int(x0), min(int(x1) + 1, sw)):
                    wx = max(0.0, min(x1, sx + 1) - max(x0, sx))
                    if wx <= 0.0:
                        continue
                    wgt = wx * wy
                    total += wgt
                    k = kind[sy][sx]
                    if k == " ":
                        continue
                    opaque += wgt
                    cover[k] = cover.get(k, 0.0) + wgt
                    r, g, b, a = spx[sx, sy]
                    s = sums.setdefault(k, [0.0, 0.0, 0.0])
                    s[0] += r * wgt
                    s[1] += g * wgt
                    s[2] += b * wgt
                    if k == "w" and luma((r, g, b)) <= seam_cut:
                        seam_hits[ty][tx] += wgt
                    if k == "f":
                        fascia_hits[ty][tx] += wgt
                    if k == "y":
                        window_pts.append((tx, ty))
                    if k == "g":
                        handle_pts.append((tx, ty))
            if total <= 0.0 or opaque / total < 0.5:
                continue
            k = max(cover, key=cover.get)
            # The window and the hardware are redrawn, not resampled: what was under them
            # becomes wall.
            if k in ("y", "g"):
                rest = {kk: v for kk, v in cover.items() if kk not in ("y", "g")}
                k = max(rest, key=rest.get) if rest else "w"
                if k not in sums:
                    # Nothing but window or hardware under it: paint it as wall in the
                    # wall's mean, worked out after the loop.
                    sums[k] = None
                    cover[k] = 1.0
            if fascia_hits[ty][tx] / total >= FASCIA_COVER:
                k = "f"
            out_kind[ty][tx] = k
            s = sums.get(k)
            c = cover[k]
            out_rgb[(tx, ty)] = None if s is None else (
                int(round(s[0] / c)), int(round(s[1] / c)), int(round(s[2] / c)))
    # Cells that were all window or hardware take the wall's mean.
    wall_cells = [v for v in out_rgb.values() if v is not None]
    mean_wall = tuple(int(round(sum(v[i] for v in wall_cells) / len(wall_cells))) for i in range(3))
    for key, v in out_rgb.items():
        if v is None:
            out_rgb[key] = mean_wall

    # Snap per class.
    snapped = {}
    for k, tones in (("w", WALL_TONES), ("r", ROOF_TONES), ("f", FASCIA_TONES)):
        pts = [(x, y, out_rgb[(x, y)]) for y in range(th) for x in range(tw) if out_kind[y][x] == k]
        snapped.update(snap(pts, tones))
    for key in out_rgb:
        if key not in snapped:
            snapped[key] = out_rgb[key]

    # Seams: ink in the wall's darkest tone.
    wall_tones = sorted({snapped[(x, y)] for y in range(th) for x in range(tw) if out_kind[y][x] == "w"}, key=luma)
    if wall_tones:
        darkest = wall_tones[0]
        for y in range(th):
            for x in range(tw):
                if out_kind[y][x] == "w" and seam_hits[y][x] >= SEAM_COVER * (sw / tw) * (sh / th):
                    snapped[(x, y)] = darkest

    # Fascia: the lightest fascia tone, one line.
    fascia_tones = sorted({snapped[(x, y)] for y in range(th) for x in range(tw) if out_kind[y][x] == "f"}, key=luma)
    if fascia_tones:
        for y in range(th):
            for x in range(tw):
                if out_kind[y][x] == "f":
                    snapped[(x, y)] = fascia_tones[-1]

    # Roof off the roof: a pixel classed thatch with fewer than two thatch neighbours is not
    # roof at all but the old window frame's ring, whose hue fell in the thatch's range. It
    # becomes wall in the wall's mean.
    for y in range(th):
        for x in range(tw):
            if out_kind[y][x] != "r":
                continue
            beside = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                         if 0 <= x + dx < tw and 0 <= y + dy < th and out_kind[y + dy][x + dx] == "r")
            if beside < 2:
                out_kind[y][x] = "w"
                snapped[(x, y)] = mean_wall
    # Roof speckle: a lone tone takes its neighbours' commonest.
    for y in range(th):
        for x in range(tw):
            if out_kind[y][x] != "r":
                continue
            around = [snapped[(x + dx, y + dy)] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                      if 0 <= x + dx < tw and 0 <= y + dy < th and out_kind[y + dy][x + dx] == "r"]
            if around and snapped[(x, y)] not in around:
                snapped[(x, y)] = max(set(around), key=around.count)

    # The window and the handle, redrawn.
    if window_pts:
        cx = int(round(sum(p[0] for p in window_pts) / len(window_pts)))
        cy = int(round(sum(p[1] for p in window_pts) / len(window_pts)))
        yellow = (240, 209, 83)
        for dy in range(-WINDOW_ARM, WINDOW_ARM + 1):
            for dx in range(-WINDOW_ARM, WINDOW_ARM + 1):
                if abs(dx) + abs(dy) <= WINDOW_ARM and 0 <= cx + dx < tw and 0 <= cy + dy < th:
                    out_kind[cy + dy][cx + dx] = "y"
                    snapped[(cx + dx, cy + dy)] = yellow
    if handle_pts:
        cx = int(round(sum(p[0] for p in handle_pts) / len(handle_pts)))
        cy = int(round(sum(p[1] for p in handle_pts) / len(handle_pts)))
        for dy in range(HANDLE_TALL):
            yy = cy - HANDLE_TALL // 2 + dy
            if 0 <= yy < th:
                out_kind[yy][cx] = "g"
                snapped[(cx, yy)] = HANDLE_INK

    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    op = out.load()
    for y in range(th):
        for x in range(tw):
            if out_kind[y][x] != " ":
                r, g, b = snapped[(x, y)]
                op[x, y] = (r, g, b, 255)
    out.save(out_path)
    counts = {}
    for row in out_kind:
        for k in row:
            counts[k] = counts.get(k, 0) + 1
    print("wrote %s (%dx%d): %s" % (out_path, tw, th, counts))

    if mask_out is not None:
        tint = {" ": (255, 0, 255), "w": (255, 128, 0), "f": (255, 0, 0),
                "r": (0, 160, 0), "y": (255, 255, 0), "g": (200, 200, 200)}
        mask = Image.new("RGB", (tw, th))
        mp = mask.load()
        for y in range(th):
            for x in range(tw):
                mp[x, y] = tint[out_kind[y][x]]
        mask.resize((tw * 8, th * 8), Image.NEAREST).save(mask_out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""The pour sheet's backdrop: today's room plate with nothing of today's pour step left on it.

OFFLINE MOCKUPS ONLY (2026-10-16). Imported by pour_mockup.py; nothing in the game reads it.

Worked at the plate's full resolution, because the far bank is drawn finer than the room's
3-px lattice (one canvas px a painted px, FAR_PIXEL) and a 1x round trip would coarsen it.

- **Below the sky the backdrop is static** (the wash room's bank, beach and lawn strips do not
  scroll), so a cell hidden by today's table, bucket, jars or dog on the pour plate is taken
  from another room plate where it shows (catch, smoke, uncap, each with its own objects boxed
  out), pixel for pixel at the same place.
- **What no plate shows** (a little lawn under today's things) is lifted from the same rows a
  little way along, in 3-px-aligned blocks: the lawn and the beach are row noise.
- **The lake band's floating rubbish is the same on every plate**, so it comes off by colour: a
  pixel that is not one of its row's water colours takes the nearest water pixel of its row.
- **The sky** keeps the pour plate's own clouds; every cloud the old bucket overlapped, and the
  bucket, go back to the plain sky steps, and anything small in the sky (bees, pigeons) goes.

Richard's call (2026-10-16): the hive room's backdrop has no rubbish, no ferries and no dogs."""
import os
import sys
from collections import Counter, deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402

G = look.ROOM_GRAIN
W, H = look.ROOM_GRID            # art grid
SW_, SH_ = W * G, H * G          # screen
SKY_TO = 120                     # art rows above this are sky (the treeline starts at 120)
FOOT = (150, 163)                # the treeline's foot: rubbish pokes up into it here and there
BAND = (163, 199)                # the far beach strip, the lake band and the near shore's foam
NEAR_FOAM = 196                  # from here down the pale foam colour is the shore's, not a collar

SKY_STEPS = [(127, 183, 226), (136, 188, 227), (144, 193, 228), (152, 198, 229),
             (161, 203, 230), (169, 208, 231), (177, 213, 232), (186, 218, 233)]
OLD_BUCKET = (262, 54, 380, SKY_TO)   # art: clouds touching this go with the old bucket

# What each plate has standing on the backdrop, art px (x0, y0, x1, y1), generous.
OBJECTS = {
    "pour": [(244, 48, 394, 312), (182, 232, 234, 296), (292, 232, 344, 296),
             (386, 226, 440, 296), (378, 280, 548, 304), (64, 192, 194, 282),
             (230, 284, 406, 314)],
    "done": [(244, 48, 394, 312), (34, 206, 180, 282), (376, 176, 572, 304),
             (230, 284, 406, 314)],
    "catch": [(254, 198, 398, 314), (500, 176, 576, 232), (446, 120, 502, 172),
              (498, 76, 606, 150), (350, 126, 424, 194)],
    "smoke": [(148, 86, 312, 318), (324, 166, 426, 278), (234, 98, 338, 178),
              (498, 176, 576, 232), (398, 120, 458, 172)],
    "uncap": [(126, 30, 518, 298), (446, 278, 572, 360)],
}
ORDER = ("pour", "done", "catch", "smoke", "uncap")

NEVER = {tuple(c[:3]) for c in (look.bh.BEE_GOLD, look.bh.BEE_STRIPE, look.bh.BEE_THORAX,
                                look.bh.BEE_HEAD, look.bh.DARK_WOOD, look.bh.DARK_WOOD_LO,
                                look.bh.DARK_WOOD_HI, look.OUT)}

_full_cache = {}


def _full(name):
    if name not in _full_cache:
        _full_cache[name] = np.array(look.plate(name))[:, :, :3].astype(np.int16)
    return _full_cache[name]


def _mask(boxes):
    """Art boxes -> a screen-px mask."""
    m = np.zeros((SH_, SW_), bool)
    for x0, y0, x1, y1 in boxes:
        m[max(0, y0) * G:min(H, y1) * G, max(0, x0) * G:min(W, x1) * G] = True
    return m


def _components(bad):
    """8-connected components of a boolean art grid: a list of lists of (y, x)."""
    h, w = bad.shape
    seen = np.zeros_like(bad)
    out = []
    for y in range(h):
        for x in range(w):
            if not bad[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            comp = []
            while q:
                cy, cx = q.popleft()
                comp.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and bad[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            out.append(comp)
    return out


def _sky(full):
    """The sky, on the 3-px lattice: today's bucket, every cloud it overlapped, and every small
    thing in the air (bees, pigeons) back to the plain dithered sky steps."""
    cells = full[G // 2:SKY_TO * G:G, G // 2::G].copy()      # art rows 0..SKY_TO-1
    steps = set(SKY_STEPS)
    block = full[:SKY_TO * G].reshape(SKY_TO, G, W, G, 3)
    uniform = (block == block[:, :1, :, :1, :]).all(axis=(1, 3, 4))
    is_sky = np.array([[tuple(int(v) for v in c) in steps for c in row] for row in cells]) & uniform
    comps = _components(~is_sky)
    x0, y0, x1, y1 = OLD_BUCKET
    clear = np.zeros_like(is_sky)
    for comp in comps:
        ys = [p[0] for p in comp]
        xs = [p[1] for p in comp]
        touches = any(x0 <= x < x1 and y0 <= y < y1 for y, x in comp)
        brown = sum(1 for y, x in comp if cells[y, x][0] > cells[y, x][2] + 12 or max(cells[y, x]) < 90)
        small = len(comp) < 90
        if touches or small or brown > len(comp) * 0.25:
            for y, x in comp:
                clear[y, x] = True
        else:
            # a big cloud with a bird or bee on it: just the brown/dark cells
            for y, x in comp:
                c = cells[y, x]
                if c[0] > c[2] + 12 or max(c) < 90:
                    clear[y, x] = True
    for y in range(SKY_TO):
        for x in range(W):
            if not clear[y, x]:
                continue
            fill = None
            for k in range(2, 400, 2):
                for xx in (x - k, x + k):
                    if 0 <= xx < W and is_sky[y, xx] and not clear[y, xx]:
                        fill = cells[y, xx]
                        break
                if fill is not None:
                    break
            if fill is None:
                fill = np.array(SKY_STEPS[min(7, y * 8 // SKY_TO)])
            full[y * G:(y + 1) * G, x * G:(x + 1) * G] = fill


def _sky_cells(full):
    """Off-lattice things in the sky (a pigeon drawn at the far bank's finer grain over a cloud):
    every sky cell whose nine pixels disagree, or that holds a dark or brown pixel, becomes its
    own most common clean colour."""
    for y in range(SKY_TO):
        for x in range(W):
            blk = full[y * G:(y + 1) * G, x * G:(x + 1) * G].reshape(-1, 3)
            dirty = (blk.max(axis=1) < 90) | (blk[:, 0] > blk[:, 2] + 12)
            if not dirty.any() and (blk == blk[0]).all():
                continue
            clean = [tuple(int(v) for v in c) for c, d in zip(blk, dirty) if not d]
            if clean:
                fill = Counter(clean).most_common(1)[0][0]
            else:
                fill = tuple(int(v) for v in full[y * G + 1, (x - 2) * G + 1]) if x >= 2 else SKY_STEPS[0]
            full[y * G:(y + 1) * G, x * G:(x + 1) * G] = fill


def _row_fill(full, y, bad):
    """Pixels of screen row y marked bad take the nearest good pixel of the row."""
    good = np.nonzero(~bad)[0]
    if len(good) == 0:
        return
    for x in np.nonzero(bad)[0]:
        j = np.searchsorted(good, x)
        cand = [good[k] for k in (j - 1, j) if 0 <= k < len(good)]
        src = min(cand, key=lambda g: abs(int(g) - int(x)))
        full[y, x] = full[y, src]


def _band(full):
    """The far beach strip and the lake band without their rubbish, row by row: the colours
    that cover a row (its water, its streaks, the far sand) stay, anything else (a piece, its
    foam collar, its ink) takes the nearest kept pixel of its row."""
    rub = Counter()
    for sy in range(BAND[0] * G, BAND[1] * G + G):
        row = full[sy]
        cnt = Counter(tuple(int(v) for v in c) for c in row)
        keep = set()
        art_y = sy // G
        for c, n in cnt.items():
            if n < 18 * G or c in NEVER or max(c) < 12 or c == (53, 53, 53):
                continue
            if art_y >= 166 and not (c[1] > c[0] + 4) and not (art_y >= NEAR_FOAM):
                continue                  # the water is green; a yellow sign or white bag is not
            if c == (166, 170, 140) and art_y < NEAR_FOAM:
                continue                  # the foam collars round the pieces
            keep.add(c)
        bad = np.array([tuple(int(v) for v in c) not in keep for c in row])
        for x in np.nonzero(bad)[0]:
            rub[tuple(int(v) for v in row[x])] += 1
        _row_fill(full, sy, bad)
    return set(rub)


def _foot(full):
    """Rubbish tall enough to stand up into the treeline's foot and the far beach strip: every
    piece there is ringed in the outline or painted in neutral greys, which the trees, the bank
    and the sand never use; those pixels take the nearest other pixel of their row."""
    for sy in range(FOOT[0] * G, 167 * G):
        row = full[sy]
        r, g, b = row[:, 0], row[:, 1], row[:, 2]
        grey = (np.abs(r - g) <= 3) & (np.abs(g - b) <= 3)
        ink = (r == 24) & (g == 18) & (b == 17)
        _row_fill(full, sy, grey | ink)


OLD_BEE = {tuple(c[:3]) for c in (look.bh.BEE_GOLD, look.bh.BEE_STRIPE, look.bh.BEE_THORAX,
                                  look.bh.BEE_HEAD, look.bh.QUEEN_GOLD, look.bh.QUEEN_LIT)}


def _bees(full, y0, y1):
    """Today's bees over the trees (on the room's lattice): every cell of a bee colour, and the
    pale wing cells just over one, take the 3 x 3 block two cells along its row that is not a
    bee, so the trees' finer texture comes with it."""
    rows = range(y0, y1)
    cells = full[G // 2::G, G // 2::G]
    bad = np.zeros((H, W), bool)
    for y in rows:
        for x in range(W):
            if tuple(int(v) for v in cells[y, x]) in OLD_BEE:
                bad[y, x] = True
    core = bad.copy()
    for y in rows:
        for x in range(W):
            c = cells[y, x]
            if not bad[y, x] and tuple(int(v) for v in c) == look.OUT[:3] and                     core[max(0, y - 2):y + 3, max(0, x - 2):x + 3].any():
                bad[y, x] = True
    for y in rows:
        for x in range(W):
            c = cells[y, x]
            if not bad[y, x] and c[0] > 170 and c[1] > 180 and c[2] > 180 and bad[y:y + 4, max(0, x - 2):x + 3].any():
                bad[y, x] = True
    for y in rows:
        for x in np.nonzero(bad[y])[0]:
            for k in range(2, 40):
                xx = x - k if (k % 2 == 0) else x + k
                if 0 <= xx < W and not bad[y, xx]:
                    full[y * G:(y + 1) * G, x * G:(x + 1) * G] = full[y * G:(y + 1) * G, xx * G:(xx + 1) * G]
                    break


def _fill_holes(full, hole):
    """Holes nothing showed, in bands of 6 art rows: each run of hole columns is lifted from the
    same rows dx along (dx a whole number of art px), the dx with a clean source and the least
    seam."""
    ah = hole[G // 2::G, G // 2::G]
    ys, xs = np.nonzero(ah)
    if len(ys) == 0:
        return
    for top in range(int(ys.min()), int(ys.max()) + 1, 6):
        band = ah[top:top + 6]
        cols = np.nonzero(band.any(axis=0))[0]
        if len(cols) == 0:
            continue
        runs, start = [], cols[0]
        for i in range(1, len(cols) + 1):
            if i == len(cols) or cols[i] != cols[i - 1] + 1:
                runs.append((start, cols[i - 1] + 1))
                if i < len(cols):
                    start = cols[i]
        for c0, c1 in runs:
            best = None
            for dx in range(-c0, W - c1):
                if abs(dx) < (c1 - c0) + 4:
                    continue
                if ah[top:top + 6, c0 + dx:c1 + dx].any():
                    continue
                cost = abs(dx) // 30
                for y in range(top, min(top + 6, H)):
                    sy = y * G + 1
                    if c0 > 0 and not ah[y, c0 - 1]:
                        cost += int(np.abs(full[sy, (c0 - 1) * G + 1] - full[sy, (c0 + dx - 1) * G + 1]).sum())
                    if c1 < W and not ah[y, c1]:
                        cost += int(np.abs(full[sy, c1 * G + 1] - full[sy, (c1 + dx) * G + 1]).sum())
                if best is None or cost < best[0]:
                    best = (cost, dx)
            if best is None:
                continue
            dx = best[1] * G
            for y in range(top, min(top + 6, H)):
                for x in range(c0, c1):
                    if ah[y, x]:
                        full[y * G:(y + 1) * G, x * G:(x + 1) * G] = \
                            full[y * G:(y + 1) * G, x * G + dx:(x + 1) * G + dx]
            ah[top:top + 6, c0:c1] = False


def clean(base="pour"):
    """The cleaned backdrop at full resolution (1920 x 1080 RGBA)."""
    full = _full(base).copy()
    hole = _mask(OBJECTS[base])
    hole[:SKY_TO * G] = False
    for n in ORDER:
        if n == base:
            continue
        take = hole & ~_mask(OBJECTS[n])
        full[take] = _full(n)[take]
        hole &= ~take
    _sky(full)
    _sky_cells(full)
    _band(full)
    _foot(full)
    _bees(full, SKY_TO, BAND[0])
    hole[:BAND[1] * G + G] = False
    _fill_holes(full, hole)
    rgba = np.dstack([full.astype(np.uint8), np.full((SH_, SW_), 255, np.uint8)])
    return Image.fromarray(rgba, "RGBA")


# The plates' interface, pasted back over everything at full resolution: the step board, the
# close cross and the hint card (screen px).
UI = {
    "pour": [(816, 0, 1104, 120), (1824, 16, 1898, 68), (566, 946, 1354, 1046)],
    "done": [(816, 0, 1104, 120), (1824, 16, 1898, 68), (572, 948, 1350, 1044)],
}


def with_ui(full, name):
    src = look.plate(name)
    for box in UI[name]:
        full.paste(src.crop(box), box[:2])
    return full


if __name__ == "__main__":
    out = clean()
    out.save(os.path.join(look.HERE, "scratch_pour", "clean_full_raw.png"))
    with_ui(out.copy(), "pour").save(os.path.join(look.HERE, "scratch_pour", "clean_full.png"))
    print("ok")

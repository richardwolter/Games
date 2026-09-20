#!/usr/bin/env python
"""Cut the console sheet into 20 sprites, and derive a grimy view of each.

Input:
  art_source/consoles_sprites.webp   a 5x4 grid of 192px cells on a checkerboard grey,
                                     by @PIXEL_SALVAJE (the Blue Boat's artist)

Output:
  assets/consoles.png                every console, packed, clean
  assets/consoles_dirty.png          the same, grimed
  assets/consoles.json               sheets + one entry per console
  tools/last_consoles_sheet.png      contact sheet, clean over dirty, for the eye

Run from the project root:
  <psd-extract venv python> tools/build_consoles.py

The grimy view is generated rather than painted (Richard, 2026-09-19): a console is a find
like the furniture, and the furniture carries two paintings, but this sheet is one view per
console. So the lake's picture is made from the shelf's, the way the wash stand already
makes its grime from the restored view.
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "consoles_sprites.webp"
CLEAN_PNG = ROOT / "assets" / "consoles.png"
DIRTY_PNG = ROOT / "assets" / "consoles_dirty.png"
BOOK = ROOT / "assets" / "consoles.json"
CONTACT = ROOT / "tools" / "last_consoles_sheet.png"

COLS = 5
ROWS = 4

## The two greys of the checkerboard, measured off the file.
##
## The source is a lossy webp, so neither colour is flat: each wobbles a few parts either
## way. NEAR is how far a pixel may sit from one of them and still be background.
BACKS = ((109, 117, 123), (101, 107, 114))
NEAR = 14

## The baked drop shadow, measured off the file, and cleared with the background.
##
## The sheet paints every console standing on a flat shadow. A find floats on the lake and
## stands on a shelf we draw ourselves, so a shadow baked into the picture would be a
## second shadow in both places -- the call `tools/build_boat_sheet.py` made for the hull,
## for the same reason.
SHADOW = (62, 63, 72)
SHADOW_NEAR = 26

## The least pixels an island may have and still be part of a console.
##
## Four cells draw the controller as its own island with no cable joining it, so a
## largest-island rule loses the controller; the sheet's `@PIXEL_SALVAJE` watermark is the
## only thing that has to be left behind. The two are nowhere near each other in size -- a
## detached controller is about 2500 pixels and the biggest letter stroke is 161 -- so the
## count is what tells them apart, where distance cannot.
LEAST_ISLAND = 300

## A gutter between packed sprites. build_decor.py's reasoning, and its number.
PAD = 2

## The grime, all of it by eye on the contact sheet.
##
## A console lying in the lake is under the same water as everything else, so it goes the
## way the water goes: towards the filth's green, darker, with the colour drained out of
## it. SPECK is muck stuck to it, laid in whole pixels off a fixed roll so a console's
## grime is its own and never moves between runs.
## A dark console soaks harder than a light one, by decision: half the sheet is black
## plastic, and a grime that only darkens turns those into silhouettes -- the PS4, the
## Series X and the Mega Drive read as one black box each on the first pass. Lifting the
## dark end towards the muck instead keeps the drawing and still says the thing has been
## in the water.
GRIME = (86, 104, 64)
GRIME_SOAK = 0.34
GRIME_SOAK_DARK = 0.42
GRIME_DARK = 0.92
GRIME_DRAIN = 0.45
SPECK_ODDS = 0.13
SPECK_TONES = (((64, 78, 46), 0.55), ((48, 60, 36), 0.4), ((112, 126, 84), 0.35))


def keyed(cell):
    """The cell with its checkerboard cleared to nothing."""
    out = cell.convert("RGBA")
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            for br, bg, bb in BACKS + (SHADOW,):
                near = SHADOW_NEAR if (br, bg, bb) == SHADOW else NEAR
                if abs(r - br) + abs(g - bg) + abs(b - bb) <= near:
                    px[x, y] = (0, 0, 0, 0)
                    break
    return out


def islands(im):
    """Every run of touching opaque pixels, as [x0, y0, x1, y1, count] boxes."""
    from collections import deque

    w, h = im.size
    a = im.split()[3].load()
    seen = bytearray(w * h)
    out = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or a[sx, sy] == 0:
                continue
            q = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            x0 = x1 = sx
            y0 = y1 = sy
            n = 0
            while q:
                cx, cy = q.popleft()
                n += 1
                x0, x1 = min(x0, cx), max(x1, cx)
                y0, y1 = min(y0, cy), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            if not seen[ny * w + nx] and a[nx, ny] > 0:
                                seen[ny * w + nx] = 1
                                q.append((nx, ny))
            out.append([x0, y0, x1 + 1, y1 + 1, n])
    return out


def despeck(im):
    """Crop to the console and its controller, leaving the watermark behind."""
    found = [b for b in islands(im) if b[4] >= LEAST_ISLAND]
    if not found:
        return None, 0
    x0 = min(b[0] for b in found)
    y0 = min(b[1] for b in found)
    x1 = max(b[2] for b in found)
    y1 = max(b[3] for b in found)
    out = im.crop((x0, y0, x1, y1))
    ## Anything under the bar is webp noise or a letter of the watermark, and both would
    ## otherwise ride along inside the box the kept islands make.
    px = out.load()
    small = [b for b in islands(im) if b[4] < LEAST_ISLAND]
    for b in small:
        for y in range(b[1], b[3]):
            for x in range(b[0], b[2]):
                if x0 <= x < x1 and y0 <= y < y1:
                    px[x - x0, y - y0] = (0, 0, 0, 0)
    return out, len(small)


def roll(seed):
    """A small fixed generator, so a console's speckle is the same every build."""
    state = seed & 0xFFFFFFFF

    def nxt():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / float(0x7FFFFFFF)

    return nxt


def grimed(im, seed):
    """The lake's view of a console: soaked green, darkened, drained, and specked."""
    out = im.copy()
    px = out.load()
    w, h = out.size
    nxt = roll(seed)
    gr, gg, gb = GRIME
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            grey = (r * 0.3 + g * 0.59 + b * 0.11)
            r = r + (grey - r) * GRIME_DRAIN
            g = g + (grey - g) * GRIME_DRAIN
            b = b + (grey - b) * GRIME_DRAIN
            soak = GRIME_SOAK + (1.0 - grey / 255.0) * GRIME_SOAK_DARK
            r = (r + (gr - r) * soak) * GRIME_DARK
            g = (g + (gg - g) * soak) * GRIME_DARK
            b = (b + (gb - b) * soak) * GRIME_DARK
            if nxt() < SPECK_ODDS:
                (sr, sg, sb), k = SPECK_TONES[int(nxt() * len(SPECK_TONES)) % len(SPECK_TONES)]
                r = r + (sr - r) * k
                g = g + (sg - g) * k
                b = b + (sb - b) * k
            px[x, y] = (int(max(0, min(255, r))), int(max(0, min(255, g))),
                        int(max(0, min(255, b))), a)
    return out


def pack(sprites):
    """Shelf packer, tallest first. build_decor.py's, and its reasoning."""
    order = sorted(sprites.items(), key=lambda kv: -kv[1].height)
    width = max(im.width for _, im in order) + PAD * 2
    width = max(width, 256)
    x = y = PAD
    row_high = 0
    spots = {}
    for key, im in order:
        if x + im.width + PAD > width:
            x = PAD
            y += row_high + PAD
            row_high = 0
        spots[key] = [x, y, im.width, im.height]
        x += im.width + PAD
        row_high = max(row_high, im.height)
    height = y + row_high + PAD
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for key, im in order:
        sheet.paste(im, (spots[key][0], spots[key][1]), im)
    return sheet, spots


def contact(clean, dirty, order):
    """Both views of every console, in the sheet's own reading order."""
    wide = max(im.width for im in clean.values())
    tall = max(im.height for im in clean.values())
    cell_w, cell_h = wide + 8, tall + 8
    out = Image.new("RGBA", (cell_w * COLS, cell_h * ROWS * 2), (24, 26, 30, 255))
    for i, key in enumerate(order):
        col, row = i % COLS, i // COLS
        for half, book in ((0, clean), (1, dirty)):
            im = book[key]
            x = col * cell_w + (cell_w - im.width) // 2
            y = (row + half * ROWS) * cell_h + (cell_h - im.height) // 2
            out.paste(im, (x, y), im)
    return out


def main():
    if not SOURCE.exists():
        sys.exit("no console sheet at %s" % SOURCE)
    sheet = Image.open(SOURCE).convert("RGBA")
    cell_w = sheet.width // COLS
    cell_h = sheet.height // ROWS
    if cell_w * COLS != sheet.width or cell_h * ROWS != sheet.height:
        sys.exit("sheet %dx%d is not a whole %dx%d grid"
                 % (sheet.width, sheet.height, COLS, ROWS))

    clean = {}
    dirty = {}
    order = []
    print("cell %dx%d" % (cell_w, cell_h))
    for row in range(ROWS):
        for col in range(COLS):
            key = "console_%02d" % (row * COLS + col + 1)
            box = (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
            cut, strays = despeck(keyed(sheet.crop(box)))
            if cut is None:
                sys.exit("cell %s came out empty" % key)
            clean[key] = cut
            dirty[key] = grimed(cut, row * COLS + col + 1)
            order.append(key)
            print("  %s  %dx%d  dropped %d" % (key, cut.width, cut.height, strays))

    clean_sheet, clean_spots = pack(clean)
    dirty_sheet, dirty_spots = pack(dirty)
    clean_sheet.save(CLEAN_PNG)
    dirty_sheet.save(DIRTY_PNG)
    contact(clean, dirty, order).save(CONTACT)

    book = {
        "sheets": {
            "consoles": {"file": "res://assets/consoles.png"},
            "consoles_dirty": {"file": "res://assets/consoles_dirty.png"},
        },
        "consoles": [
            {
                "name": key,
                "title": key.replace("_", " ").title(),
                "region": clean_spots[key],
                "dirty_region": dirty_spots[key],
            }
            for key in order
        ],
    }
    BOOK.write_text(json.dumps(book, indent=1), encoding="utf-8")
    print("clean sheet %dx%d, dirty %dx%d" % (clean_sheet.width, clean_sheet.height,
                                              dirty_sheet.width, dirty_sheet.height))
    print("wrote %s" % BOOK)


if __name__ == "__main__":
    main()

"""Cuts the two CHARGE! plates out of their sheet and cleans them up.

    python tools/make_charge_button.py

    art_source/Charge_Button.png  ->  art/ui/charge.png
                                      art/ui/charge_used.png

The sheet holds both states side by side on white: the lit plate with the
flaming exhaust, and the dark one that reads CHARGE! USED.

THE BACKGROUND IS KEYED BY FLOOD FILL FROM THE EDGES, not by a white test. The
flame's core is very nearly white, and a colour key punches it straight out,
leaving the fire with a hole in it. Nothing inside the plate's frame can be
reached from outside it, so a fill that starts at the border cannot touch the
artwork however pale it gets.

THE TWO PLATES ARE CUT TO THE SAME WINDOW, placed against each plate's own frame
rather than trimmed to its own contents. They do not have the same silhouette —
the lit one has flame overhanging the top right and a pipe elbow below the
bottom edge — so trimming each to its own bounds and handing both to one button
would make the plate jump in size and position at the moment it is spent. Cut to
a shared window keyed off the frame, only the artwork changes.

There is also a WATERMARK on the used plate, a four-point sparkle over its
bottom-right corner. It is painted out with the plate's own bottom-left corner,
mirrored: the corners are the same drawing — bevel, rivet, rusted border — so
the donor matches the destination exactly, which no amount of smudging or
copying flat stone over it would.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pnglite import read_png, write_png

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "art_source" / "Charge_Button.png"
OUT_DIR = ROOT / "art" / "ui"

## Each plate's frame, measured off the sheet: the right edge and the top of the
## stone border, in sheet pixels. The window below is placed against these, so
## the frame lands in the same place in both outputs.
##
## The right edge rather than the left because it is the clean one on both
## plates: a pipe stub sticks out of each plate's left side and lands at a
## different x on each.
PLATES = {
    "charge": {"right": 671, "top": 101, "left": 131},
    "charge_used": {"right": 1362, "top": 102, "left": 807},
}

## The window, as offsets back from the frame's right edge and up from its top.
## Roomy on the right and the bottom, which is where the lit plate's flame and
## pipe elbow reach past the frame.
WINDOW_LEFT = 600
WINDOW_RIGHT = 70
WINDOW_TOP = 30
WINDOW_BOTTOM = 600

## The sparkle on the used plate, in sheet pixels, with a little margin. Only
## the part over the plate matters — the rest of it sits on the background and
## is keyed away with it.
WATERMARK = (1314, 566, 1362, 630)
## How far the patch is faded in at its edges, so the donor does not arrive with
## a visible rectangle around it.
FEATHER = 5

## How close to the background a pixel must be for the flood to continue through
## it, per channel. The sheet is flat white, so this only has to cope with the
## soft edge around the artwork.
TOLERANCE = 26


def crop(width: int, height: int, pixels: bytearray, box) -> tuple[int, int, bytearray]:
    x0, y0, x1, y1 = box
    out_width, out_height = x1 - x0, y1 - y0
    out = bytearray(out_width * out_height * 4)
    for y in range(out_height):
        src = ((y0 + y) * width + x0) * 4
        dst = y * out_width * 4
        out[dst:dst + out_width * 4] = pixels[src:src + out_width * 4]
    return out_width, out_height, out


def key_out(width: int, height: int, pixels: bytearray) -> None:
    """Floods the white sheet away from the border inwards, in place."""
    seen = bytearray(width * height)
    stack: list[tuple[int, int]] = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))

    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        index = y * width + x
        if seen[index]:
            continue
        at = index * 4
        if min(pixels[at], pixels[at + 1], pixels[at + 2]) < 255 - TOLERANCE:
            continue
        seen[index] = 1
        pixels[at + 3] = 0
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))


def paint_out_watermark(width: int, pixels: bytearray, plate: dict) -> None:
    """Covers the sparkle with the mirror of the plate's other bottom corner."""
    x0, y0, x1, y1 = WATERMARK
    axis = plate["left"] + plate["right"]
    for y in range(y0, y1):
        for x in range(x0, x1):
            donor = axis - x
            # Faded in from the edges of the patch, so the join is a gradient
            # rather than a rectangle.
            edge = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
            blend = min(1.0, edge / float(FEATHER))
            at = (y * width + x) * 4
            from_at = (y * width + donor) * 4
            for c in range(4):
                pixels[at + c] = int(round(
                    pixels[at + c] * (1.0 - blend) + pixels[from_at + c] * blend
                ))


def main() -> None:
    width, height, pixels = read_png(SHEET)
    paint_out_watermark(width, pixels, PLATES["charge_used"])

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, plate in PLATES.items():
        box = (
            plate["right"] - WINDOW_LEFT, plate["top"] - WINDOW_TOP,
            plate["right"] + WINDOW_RIGHT, plate["top"] + WINDOW_BOTTOM,
        )
        cut_width, cut_height, cut = crop(width, height, pixels, box)
        key_out(cut_width, cut_height, cut)
        out = OUT_DIR / ("%s.png" % name)
        write_png(out, cut_width, cut_height, cut)
        kept = sum(1 for i in range(3, len(cut), 4) if cut[i] > 0)
        print("%s  %dx%d  %d%% opaque" % (
            out.relative_to(ROOT), cut_width, cut_height,
            round(100.0 * kept / (cut_width * cut_height))
        ))


if __name__ == "__main__":
    main()

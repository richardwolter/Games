"""Cuts the exhaust-pipe flame out of its video and packs it into one sheet.

    python tools/make_exhaust_flame.py

    art_source/Fire_sprite_exhaust_pipe.mp4  ->  art/exhaust_flame.png

The source is a 10-second 1280x720 clip of a pixel-art exhaust stack lighting up,
burning, smoking and going out. It is a screen recording, not an asset: it has a
vignette, a watermark in the bottom right, and TWO takes with a hard cut between
them at frame 36. Only the second take is used — it is the complete one, and the
first is at a different zoom, so mixing them would make the pipe jump size
mid-animation.

Three things have to happen to turn it into a sprite, and each is why a step
here exists:

  CROP     to the pipe, which also throws the watermark and most of the vignette
           away. The pipe runs off the bottom of the frame in the source and is
           left that way — it is mounted into the truck's bodywork, so the base
           is never seen.
  KEY      the background out by FLOOD FILL FROM THE EDGES with a neighbour-
           relative tolerance, not by matching a colour. The background is a grey
           gradient with a dark vignette around it, so no single key colour
           exists; but every step of it is small, while the pixel-art outline is
           a cliff. A fill that can only cross small steps walks the whole
           background and stops dead at the artwork — including at the smoke,
           which is nearly the same grey as the background it sits on and would
           be eaten by any colour test that could also remove the vignette.
  DOWNSCALE afterwards, in premultiplied alpha. Scaling first and keying second
           leaves a grey fringe all round the flame, because the scaler has
           already blended background into every edge pixel.

Frames are picked, not taken wholesale: 24 fps of pixel-art fire is more frames
than the animation needs and every one of them is a cell in the sheet.
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pnglite import read_png, write_png

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "Fire_sprite_exhaust_pipe.mp4"
OUT = ROOT / "art" / "exhaust_flame.png"

## The window on the source frame: x, y, width, height in source pixels. Wide
## enough for the sparks that fly off the top of the flame, and clear of the
## watermark at x ~1080.
CROP = (440, 32, 420, 688)
## Worked at half the source size and then halved again. The source is pixel art
## drawn at roughly 8 screen pixels per art pixel, so a quarter-size sprite is
## still about two real pixels per drawn one.
WORK_SCALE = 2
CELL_SCALE = 2

## Which source frames become cells, and in what order — three runs, and the
## resting pipe is simply the last cell of the tail rather than a cell of its own.
## The clip's actual last frame is not used: the recording washes out at the very
## end and the pipe there is a paler grey than the pipe everywhere else.
##
## Ignition is quick and stays quick — the flame is at full size within a third
## of a second of the button, because that is when the boost actually starts.
## The burn is a middle stretch chosen for being calm; the flame gusts around
## frame 200 and a loop taken from there pulses. The tail is the one run that has
## to be complete: it carries the flame dying, the smoke, and the empty pipe.
IGNITE = list(range(36, 44, 2))
BURN = list(range(72, 120, 3))
OUT_RUN = list(range(206, 236, 3))

## Cells per row in the finished sheet.
COLUMNS = 8

## How different two touching pixels may be, per channel, for the flood to treat
## them as the same background. Big enough to cross the gradient and the vignette,
## small enough that the drawn outline stops it.
TOLERANCE = 10
## What the background can be at all: at least this bright, and no more coloured
## than this. The sheet sits around 200 and the artwork's outlines around 20.
BACKGROUND_FLOOR = 140
NEUTRAL = 30


def frames() -> list[int]:
    return IGNITE + BURN + OUT_RUN


def extract(into: pathlib.Path) -> list[tuple[int, int, bytearray]]:
    """Pulls every wanted frame out of the clip, cropped and half-sized."""
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is not on PATH")
    x, y, width, height = CROP
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(SOURCE),
            "-vf", "crop=%d:%d:%d:%d,scale=%d:%d" % (
                width, height, x, y, width // WORK_SCALE, height // WORK_SCALE
            ),
            # RGBA out of a clip that has no alpha, so there is an alpha channel
            # to key into rather than one to add later.
            "-pix_fmt", "rgba",
            "-vsync", "0", "-y", str(into / "f%04d.png"),
        ],
        check=True,
    )
    # ffmpeg numbers its output from 1, so a source frame is one file later.
    return [read_png(into / ("f%04d.png" % (n + 1))) for n in frames()]


def key_out(width: int, height: int, pixels: bytearray) -> None:
    """Floods the background away from the border inwards, in place.

    Nothing enclosed by the artwork's outline can be reached from the border, so
    the flame, the pipe and the smoke are all safe however close their colour is
    to the sheet behind them.
    """
    seen = bytearray(width * height)
    stack: list[tuple[int, int, int, int, int]] = []
    # Seeded from three sides only. THE PIPE RUNS OFF THE BOTTOM OF THE FRAME, so
    # a seed on the bottom row starts inside the pipe rather than on the
    # background — and since the pipe is all one dark colour, the flood then eats
    # the whole stack from the inside and carries on up into everything the pipe
    # was enclosing. The background below the pipe is still reached from the
    # sides, so nothing is left behind by dropping that edge.
    for x in range(width):
        stack.append((x, 0, -1, -1, -1))
    for y in range(height):
        stack.append((0, y, -1, -1, -1))
        stack.append((width - 1, y, -1, -1, -1))

    while stack:
        x, y, pr, pg, pb = stack.pop()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        index = y * width + x
        if seen[index]:
            continue
        at = index * 4
        r, g, b = pixels[at], pixels[at + 1], pixels[at + 2]
        # Compared against the pixel the flood arrived from, not against a key
        # colour: that is what lets it cross a gradient without also crossing an
        # edge. Seeds have no predecessor and are always taken.
        if pr >= 0 and (abs(r - pr) > TOLERANCE or abs(g - pg) > TOLERANCE
                        or abs(b - pb) > TOLERANCE):
            continue
        # And a floor on what the background can possibly be: pale, and near
        # enough to neutral. The step test alone was not enough — h264 softens
        # the edge between the pale sheet and the near-black pipe differently on
        # different frames, and on some of them the softening is gentle enough
        # for the flood to walk down it and eat the whole stack from the outside
        # in. Nothing in the artwork is both this pale and this grey except the
        # smoke, which the flood cannot reach: it is drawn with an outline.
        if max(r, g, b) < BACKGROUND_FLOOR or max(r, g, b) - min(r, g, b) > NEUTRAL:
            continue
        seen[index] = 1
        pixels[at + 3] = 0
        stack.append((x + 1, y, r, g, b))
        stack.append((x - 1, y, r, g, b))
        stack.append((x, y + 1, r, g, b))
        stack.append((x, y - 1, r, g, b))


def halve(width: int, height: int, pixels: bytearray) -> tuple[int, int, bytearray]:
    """Box-filters 2x2 down to 1, in premultiplied alpha.

    Premultiplied because half of each edge pixel's 2x2 block is keyed-out
    background whose RGB is still grey. Averaging the colours straight would mix
    that grey back in and ring the flame with it; weighting by alpha means a
    transparent pixel contributes nothing but its transparency.
    """
    out_width, out_height = width // CELL_SCALE, height // CELL_SCALE
    out = bytearray(out_width * out_height * 4)
    for y in range(out_height):
        for x in range(out_width):
            r = g = b = a = 0
            for dy in range(CELL_SCALE):
                for dx in range(CELL_SCALE):
                    at = ((y * CELL_SCALE + dy) * width + x * CELL_SCALE + dx) * 4
                    alpha = pixels[at + 3]
                    r += pixels[at] * alpha
                    g += pixels[at + 1] * alpha
                    b += pixels[at + 2] * alpha
                    a += alpha
            index = (y * out_width + x) * 4
            if a > 0:
                out[index] = r // a
                out[index + 1] = g // a
                out[index + 2] = b // a
            out[index + 3] = a // (CELL_SCALE * CELL_SCALE)
    return out_width, out_height, out


def main() -> None:
    with tempfile.TemporaryDirectory() as work:
        shots = extract(pathlib.Path(work))

    cells = []
    for width, height, pixels in shots:
        key_out(width, height, pixels)
        cells.append(halve(width, height, pixels))

    cell_width, cell_height = cells[0][0], cells[0][1]
    rows = (len(cells) + COLUMNS - 1) // COLUMNS
    sheet_width, sheet_height = cell_width * COLUMNS, cell_height * rows
    sheet = bytearray(sheet_width * sheet_height * 4)
    for i, (width, height, pixels) in enumerate(cells):
        ox, oy = (i % COLUMNS) * cell_width, (i // COLUMNS) * cell_height
        for y in range(height):
            src = y * width * 4
            dst = ((oy + y) * sheet_width + ox) * 4
            sheet[dst:dst + width * 4] = pixels[src:src + width * 4]

    write_png(OUT, sheet_width, sheet_height, sheet)
    print("%s  %dx%d  cell %dx%d  %d columns" % (
        OUT.relative_to(ROOT), sheet_width, sheet_height,
        cell_width, cell_height, COLUMNS
    ))
    print("cells: ignite %d, burn %d, out %d  (total %d; idle is the last one)" % (
        len(IGNITE), len(BURN), len(OUT_RUN), len(cells)
    ))


if __name__ == "__main__":
    main()

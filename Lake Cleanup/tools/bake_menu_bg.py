"""Bakes the main menu's background out of a frame filmed by `tools/shot_menu_bg.tscn`.

The lake as the game draws it is the whole picture edge to edge, and the menu stands its
logo and its plank stack on the left of it in cream and oak. So the left of the frame is
taken down under a soft ramp and the whole thing under a mild vignette — the capsules' own
recipe (darken, vignette, a halo under the logo), baked here rather than drawn in Godot by
decision (2026-09-16): one file, nothing at runtime.

One-off. Re-run it by hand after re-filming:

    python tools/bake_menu_bg.py tools/menu_bg/01.png assets/menu_lake.png

Needs Pillow and numpy (the logo venv has both).
"""

import sys

import numpy as np
from PIL import Image

# What is left of the picture everywhere, before the ramp and the vignette.
DARKEN = 0.86
# The left band the logo and the planks stand on: how much is left at the very left edge,
# and how far across the frame the ramp has finished. Smoothstepped, so there is no line.
LEFT_KEEP = 0.52
LEFT_TO = 0.62
# The vignette: how much is left in the corners, and where it starts biting (as a fraction
# of the half-diagonal).
EDGE_KEEP = 0.70
EDGE_FROM = 0.55
# A little warmth taken out of the shadow, so the darkened soup goes blue-green rather than
# muddy grey: what is left of each channel inside the darkening.
TINT = (0.94, 1.0, 1.02)


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def bake(src, dst):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    a = np.asarray(im).astype(np.float32) / 255.0

    xs = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :]
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]

    # The left band: full darkening at the edge, none past LEFT_TO.
    left = LEFT_KEEP + (1.0 - LEFT_KEEP) * smoothstep(xs / LEFT_TO)

    # The vignette, measured off the middle on the frame's own aspect.
    dx = (xs - 0.5) * 2.0
    dy = (ys - 0.5) * 2.0 * (h / float(w))
    r = np.sqrt(dx * dx + dy * dy) / np.sqrt(1.0 + (h / float(w)) ** 2)
    edge = 1.0 - (1.0 - EDGE_KEEP) * smoothstep((r - EDGE_FROM) / (1.0 - EDGE_FROM))

    gain = (DARKEN * left * edge)[:, :, None] * np.asarray(TINT, dtype=np.float32)[None, None, :]
    out = np.clip(a * gain, 0.0, 1.0)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8)).save(dst)
    print("%s -> %s  %dx%d" % (src, dst, w, h))


if __name__ == "__main__":
    bake(sys.argv[1] if len(sys.argv) > 1 else "tools/menu_bg/01.png",
         sys.argv[2] if len(sys.argv) > 2 else "assets/menu_lake.png")

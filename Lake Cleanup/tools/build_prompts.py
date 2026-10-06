"""Cut the input prompts out of Kenney's Input Prompts Pixel (CC0,
art_source/kenney_inputPromptsPixel16x/). Writes assets/ui/prompts/*.png at the pack's own
16 px; the game scales them. Reimport after a re-run.

The keyboard and mouse tiles are Richard's picks off tools/last_prompt_contact.png. The pad
tiles (2026-10-06, issue #33) are the button glyphs `Glyphs` draws for each pad family:
`xb_*` the Xbox legends, `ps_*` the PlayStation ones, and the unprefixed pad tiles (the
sticks and the D-pad) shared by both, since both pads print the same thing there.

**The pack's PlayStation face buttons are cut in two**: the symbol's right half sits in the
next tile along (561/562 triangle, 563/564 circle, 565/566 square, 567/568 cross), at the
same place in its tile. A pair is laid one over the other here, which puts the whole symbol
back on its disc. Run with the psd-extract venv's site-packages on PYTHONPATH."""
import os
from PIL import Image
SHEET = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
OUT = "assets/ui/prompts"
T, COLS = 16, 34
PICKS = {
    "mouse_idle": 76, "mouse_click": 77,
    "key_w": 358, "key_a": 392, "key_s": 393, "key_d": 394, "key_z": 427, "key_q": 357,
    "stick": 246, "stick_dirs": 253, "arrow_up": 604,
    # Both families: the sticks pressed in, and the D-pad's four arms.
    "ls": 254, "rs": 322,
    "dpad_up": 35, "dpad_down": 37, "dpad_left": 36, "dpad_right": 38,
    # Xbox.
    "xb_a": 4, "xb_b": 5, "xb_x": 6, "xb_y": 7,
    "xb_view": 616, "xb_menu": 617, "xb_share": 618,
    "xb_lb": 587, "xb_rb": 588, "xb_lt": 589, "xb_rt": 590,
    # PlayStation, but the four faces (below).
    "ps_create": 618, "ps_options": 768, "ps_touchpad": 702,
    "ps_l1": 665, "ps_r1": 666, "ps_l2": 663, "ps_r2": 664,
}
## A face button and the tile holding the other half of its symbol.
HALVES = {
    "ps_triangle": (561, 562), "ps_circle": (563, 564),
    "ps_square": (565, 566), "ps_cross": (567, 568),
}
## Tiles no longer written: the Xbox-only pad prompts the glyphs replaced.
RETIRED = ["pad_a", "pad_rt"]


def tile(sheet, n):
    r, c = divmod(n, COLS)
    return sheet.crop((c * T, r * T, c * T + T, r * T + T))


os.makedirs(OUT, exist_ok=True)
sheet = Image.open(SHEET).convert("RGBA")
for name, n in PICKS.items():
    tile(sheet, n).save(f"{OUT}/{name}.png")
for name, (disc, rest) in HALVES.items():
    whole = tile(sheet, disc)
    whole.alpha_composite(tile(sheet, rest))
    whole.save(f"{OUT}/{name}.png")
for name in RETIRED:
    for path in (f"{OUT}/{name}.png", f"{OUT}/{name}.png.import"):
        if os.path.exists(path):
            os.remove(path)
print(len(PICKS) + len(HALVES), "prompts")

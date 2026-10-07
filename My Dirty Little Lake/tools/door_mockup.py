"""Mockup sheet for the letter's "Start cleaning" door ornaments (2026-10-07, /grill-me).

Lays pack plants, lake rubbish and a strip of water round the door on the real last card
(`tools/last_letter_card_*.png` from `tools/shot_letter.tscn`), three compositions stacked.
Offline, base python + PIL. Writes tools/last_door_mockup.png.
"""
import json
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
S = 3  # window px per art px (2 design px at the 1.5 stretch)

card = sorted(ROOT.glob("tools/last_letter_card_deco*.png"))[0]
base = Image.open(card).convert("RGBA")
flora = Image.open(ROOT / "assets/flora.png").convert("RGBA")
fj = json.load(open(ROOT / "assets/flora.json"))
lake = Image.open(ROOT / "assets/lake_objects.png").convert("RGBA")
pieces = {p["name"]: p for p in json.load(open(ROOT / "assets/pieces.json"))["pieces"]}

DOOR = (815, 746, 1106, 817)  # the plank in window px on the 1920x1080 capture
CROP = (560, 640, 1360, 860)


def c(rgb):
    return tuple(int(v * 255) for v in rgb) + (255,)


CLEAN = [c((0.173, 0.302, 0.431)), c((0.255, 0.42, 0.573)), c((0.353, 0.525, 0.678)),
         c((0.498, 0.655, 0.776)), c((0.769, 0.859, 0.91))]
MURKY = [c((0.071, 0.18, 0.055)), c((0.094, 0.227, 0.067)), c((0.118, 0.275, 0.082)),
         c((0.227, 0.353, 0.141)), c((0.369, 0.435, 0.227))]
FOAM = c((0.933, 0.965, 0.984))


def sprite(sheet, rect, scale=S, flip=False):
    x, y, w, h = rect
    im = sheet.crop((x, y, x + w, y + h))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im.resize((w * scale, h * scale), Image.NEAREST)


def plant(name, flip=False, scale=S):
    return sprite(flora, fj[name]["full"], scale, flip)


def junk(name, flip=False, cut=1.0):
    im = sprite(lake, pieces[name]["region"], S, flip)
    if cut < 1.0:
        im = im.crop((0, 0, im.width, int(im.height * cut) // S * S))
    return im


def put(canvas, im, foot_x, foot_y):
    """Stand a picture with its bottom middle on a point, snapped to the art grid."""
    x = int(foot_x - im.width / 2) // S * S
    y = int(foot_y - im.height) // S * S
    canvas.alpha_composite(im, (x, y))


def pond(canvas, x0, x1, top, bottom, ramp, split=None):
    """A strip of water in whole art pixels, rounded at the ends, lit along the top."""
    rows = (bottom - top) // S
    for r in range(rows):
        y = top + r * S
        # The ends round off over the top and bottom rows.
        edge = min(r, rows - 1 - r)
        inset = max(0, 3 - edge) * 2 * S
        for x in range(x0 + inset, x1 - inset, S):
            use = ramp if split is None or x < split else CLEAN
            shade = use[3] if r == 0 else use[2] if r < rows * 0.45 else use[1] if r < rows - 1 else use[0]
            # A stripe or two of the next step up, the band rule.
            if 0 < r < rows - 1 and ((x // S + r * 3) % 23 == 0):
                shade = use[3]
            canvas.paste(shade, (x, y, x + S, y + S))
    # A torn foam lip along the top.
    for x in range(x0 + 6 * S, x1 - 6 * S, S):
        if (x // S * 7) % 5 != 0:
            canvas.paste(FOAM, (x, top, x + S, top + S))


def restore_plank(canvas):
    canvas.alpha_composite(base.crop(DOOR), (DOOR[0], DOOR[1]))


def variant_a():
    im = base.copy()
    pond(im, 700, 1222, 793, 838, CLEAN)
    restore_plank(im)
    put(im, plant("pk_pad_0"), 742, 834)
    put(im, plant("lily_pink"), 1168, 836)
    put(im, junk("metal_can1", cut=0.7), 790, 830)
    put(im, junk("plastic_bottle1", cut=0.7), 1132, 832)
    put(im, plant("pk_reed_7"), 718, 808)
    put(im, plant("pk_reed_2", flip=True), 1204, 808)
    put(im, plant("pk_reed_14"), 772, 810)
    put(im, plant("pk_reed_3", flip=True), 1150, 810)
    return im


def variant_b():
    im = base.copy()
    pond(im, 760, 1162, 808, 835, CLEAN)
    restore_plank(im)
    # Growing out of the plank's ends, over its corners.
    put(im, plant("pk_leafy_b"), 812, 824)
    put(im, plant("pk_leafy_b", flip=True), 1110, 824)
    put(im, plant("pk_flower_4"), 846, 826)
    put(im, plant("pk_flower_5"), 1076, 826)
    # Rubbish wedged on the top corners.
    put(im, junk("metal_can2"), 830, 752)
    put(im, junk("rubber_ball"), 1090, 752)
    put(im, plant("pk_pad_0"), 1140, 836)
    return im


def variant_c():
    im = base.copy()
    # Before and after: murky water with rubbish on the left, clean with lilies on the right.
    pond(im, 690, 1232, 793, 838, MURKY, split=961)
    restore_plank(im)
    put(im, junk("rubber_tire1", cut=0.6), 742, 836)
    put(im, junk("metal_can3", cut=0.7), 800, 832)
    put(im, junk("plastic_bottle2", cut=0.7), 690 + 30, 820)
    put(im, plant("pk_pad_1"), 1130, 836)
    put(im, plant("lily_white"), 1182, 834)
    put(im, plant("pk_reed_7", flip=True), 1214, 808)
    put(im, plant("pk_reed_14", flip=True), 1160, 812)
    put(im, junk("plastic_bottle3"), 700, 806)
    return im


def main():
    panels = [variant_a(), variant_b(), variant_c()]
    crops = [p.crop(CROP) for p in panels]
    w = crops[0].width
    sheet = Image.new("RGBA", (w, sum(cr.height for cr in crops) + 16 * 4), (40, 30, 30, 255))
    y = 16
    for cr in crops:
        sheet.alpha_composite(cr, (0, y))
        y += cr.height + 16
    out = ROOT / "tools/last_door_mockup.png"
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    sys.exit(main())

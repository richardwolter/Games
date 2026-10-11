"""East's cast in west's trousers and boots (2026-10-11, Richard).

East's cast strip drew its trousers in a paler blue ramp than every other strip and its feet as
one- or two-pixel nubs. This moves the trouser blues onto the three tones west wears (the
basket's own box is left alone, it holds a catch in those blues), turns the legs' white and grey
glints into trouser light or, on an edge, outline, and stands a boot on every foot: west idle's
front and back boots, each cut from its own box in west's frame, outlined again and mirrored to
point east. Where both feet show the one behind wears the smaller back boot. In the stride
(`LUNGE`) the front boot is set forward onto the back boot's sole row; in the last frame, where
the back foot swings out behind (`KICK`), the back boot goes under the end of the trouser leg
rather than on the old nub at its heel.

The painted original is kept beside the strip as `casting_east_orig.png` the first time and is
what every run reads.

  PYTHONPATH=<psd-extract site-packages> python tools/build_cast_east.py [--out PATH]

Then re-slice (`tools/slice_character.gd`), `tools/build_grips.py`, and reimport.
"""
import os
import shutil
import sys
from PIL import Image
from build_idle_frames import (
    CLEAR, DIR, OUTLINE, SIDES, SKIN, WICKER, cells_of, foot, outline, parts, solid, trim,
)

# East's trouser blues onto the tones west's trousers are drawn in, by brightness: west is
# mostly its light and dark, so east's main tone and its highlights go light.
RAMP = {
    (189, 197, 214): (95, 120, 142),
    (130, 143, 158): (95, 120, 142),
    (108, 135, 151): (95, 120, 142),
    (95, 120, 142): (76, 95, 126),
    (92, 105, 122): (62, 76, 108),
}
TROUSER_TONES = {(95, 120, 142), (76, 95, 126), (62, 76, 108)}
# The old shoe nubs' browns, and how close (pixels across) two pieces of one foot lie.
SHOE = {(106, 53, 54), (93, 46, 40)}
FOOT_GAP = 1
# The stride's frames, where the front foot is planted `FRONT_FORWARD` forward onto the back
# boot's sole row, and the frame where the back foot swings out behind, its boot `BACK_TOE`
# past the end of its trouser leg. Picked off tools/char_preview with Richard.
LUNGE = range(8, 16)
FRONT_FORWARD = 2
KICK = (15,)
BACK_TOE = 1
CAST = 16
# West's boot leathers, what each boot is cut out of.
BOOT_SHADES = {(93, 46, 40), (74, 36, 35), (145, 77, 49), (165, 94, 52)}


def west_boots():
    """West idle's front and back boots, mirrored to point east: each boot's own pixels with a
    fresh outline ring, and the hem's outline over the back boot's ankle, the pants and boot
    division the reference draws."""
    im = Image.open('art_source/character_extracted/idle_west.png').convert('RGBA')
    _, c = cells_of(im)
    cell = c[2]
    fx, fy = foot(cell)
    px = cell.load()
    out = []
    # Each boot's box in west's frame, off its toe: the two boots touch, so a flood would take
    # both.
    for l0, t0, r0, b0 in ((fx, fy - 3, fx + 7, fy), (fx - 5, fy - 5, fx, fy - 2)):
        part = {(x, y) for y in range(t0, b0) for x in range(l0, r0)
                if solid(px[x, y]) and px[x, y][:3] in BOOT_SHADES}
        l = min(x for x, _ in part) - 1
        t = min(y for _, y in part) - 1
        r = max(x for x, _ in part) + 2
        b = max(y for _, y in part) + 2
        boot = Image.new('RGBA', (r - l, b - t), CLEAR)
        for x, y in part:
            boot.putpixel((x - l, y - t), px[x, y])
        outline(boot)
        out.append(boot.transpose(Image.FLIP_LEFT_RIGHT))
    return out


def ring_off(image, box):
    """Inside `box`: outline where a clear pixel touches what is drawn, and no outline that
    touches nothing drawn."""
    px = image.load()
    w, h = image.size
    l, t, r, b = box
    for y in range(max(t, 0), min(b, h)):
        for x in range(max(l, 0), min(r, w)):
            near = [(x + dx, y + dy) for dx, dy in SIDES
                    if 0 <= x + dx < w and 0 <= y + dy < h]
            drawn = any(solid(px[n]) and px[n][:3] != OUTLINE for n in near)
            if not solid(px[x, y]) and drawn:
                px[x, y] = OUTLINE + (255,)
            elif solid(px[x, y]) and px[x, y][:3] == OUTLINE and not any(
                    solid(px[x + dx, y + dy]) and px[x + dx, y + dy][:3] != OUTLINE
                    for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                    if 0 <= x + dx < w and 0 <= y + dy < h):
                px[x, y] = CLEAR


def grey(c):
    """A pale, colourless pixel: one of the east legs' white or grey glints."""
    return max(c) - min(c) < 40 and sum(c) > 360


def fix(cell, boots, kick=False, lunge=False):
    out = cell.copy()
    px = out.load()
    w, h = out.size
    box = cell.getbbox()
    top = box[3] - 14
    # Recolour the trousers, leg rows only, never what hangs with the basket.
    woven = {(x, y) for y in range(h) for x in range(w) if solid(px[x, y]) and px[x, y][:3] in WICKER}
    basket = max(parts(woven), key=len) if woven else set()
    bl = min((x for x, _ in basket), default=0)
    br = max((x for x, _ in basket), default=-1)
    bt = min((y for _, y in basket), default=0)
    bb = max((y for _, y in basket), default=-1)
    for y in range(top, h):
        for x in range(w):
            if bl <= x <= br and bt <= y <= bb:
                continue
            c = px[x, y][:3]
            if solid(px[x, y]) and c in RAMP:
                px[x, y] = RAMP[c] + (255,)
            elif solid(px[x, y]) and grey(c):
                # The old shoes' and hems' white and grey glints: trouser light, or outline on
                # the leg's edge, where one stood in for it.
                edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or not solid(px[x + dx, y + dy])
                           for dx, dy in SIDES)
                px[x, y] = (OUTLINE if edge else (95, 120, 142)) + (255,)
    # A boot on every shoe: the shoe's lowest, rightmost pixel is the toe.
    shoes = {(x, y) for y in range(top, h) for x in range(w) if solid(px[x, y]) and px[x, y][:3] in SHOE}
    pieces = [part for part in parts(shoes)
              if not any((x + dx, y + dy) in woven for x, y in part for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
    # The old shoes are nubs in several pieces: one foot is every piece within FOOT_GAP across.
    pieces.sort(key=lambda part: min(x for x, _ in part))
    feet = []
    for part in pieces:
        if feet and min(x for x, _ in part) - max(x for x, _ in feet[-1]) <= FOOT_GAP:
            feet[-1] = feet[-1] | part
        else:
            feet.append(set(part))
    # The back boot first, so the front one is drawn over where they meet.
    for n, part in enumerate(feet):
        # With two feet in sight the one behind (left) wears the smaller back boot.
        boot = boots[1] if len(feet) > 1 and n == 0 else boots[0]
        toe_x = max(x for x, _ in part)
        sole = max(y for _, y in part)
        at = (toe_x + 2 - boot.width, sole + 2 - boot.height)
        back = len(feet) > 1 and n == 0
        if kick and back:
            # The foot swung out behind: the boot goes under the end of the leg, not on the old
            # nub at its heel, or the trousers reaching the ground beside it read as pants on
            # the heel.
            near = [x for y in range(sole - 3, sole + 1) for x in range(min(x for x, _ in part) - 1,
                    min(max(x for x, _ in part) + 9, w)) if 0 <= y < h and px[x, y][:3] in TROUSER_TONES
                    and not (bl <= x <= br and bt <= y <= bb)]
            if near:
                heel = min(x for x, _ in part) - 1
                toe_x = max(toe_x, max(near) + BACK_TOE)
                at = (toe_x + 2 - boot.width, sole + 2 - boot.height)
                for y in range(at[1] + 1, min(sole + 2, h)):
                    for x in range(max(heel, 0), min(at[0] + 1, w)):
                        if not (bl <= x <= br and bt <= y <= bb):
                            px[x, y] = CLEAR
                ring_off(out, (max(heel - 1, 0), at[1] - 1, min(at[0] + 2, w), min(sole + 3, h)))
        if lunge and len(feet) > 1 and not back:
            # In the stride the front foot is planted, not lifted: set forward, its sole on the
            # back boot's row.
            at = (at[0] + FRONT_FORWARD, back_sole + 1 - boot.height + 1)
        bp = boot.load()
        # Over whatever was there, but the basket: the old shoe's greys, and the hem's last row,
        # which becomes the outline between pants and boot.
        for by in range(boot.height):
            for bx in range(boot.width):
                x, y = at[0] + bx, at[1] + by
                if not (0 <= x < w and 0 <= y < h) or not solid(bp[bx, by]):
                    continue
                if bl <= x <= br and bt <= y <= bb:
                    continue
                px[x, y] = bp[bx, by]
        if back:
            back_sole = at[1] + boot.height - 2
    # What is left of the old nubs is boot.
    for x, y in shoes:
        if px[x, y][:3] in SHOE:
            px[x, y] = (74, 36, 35, 255)
    # And outline left standing on its own under the feet.
    trim(out, top)
    return out


def main(argv):
    strip = os.path.join(DIR, 'casting_east.png')
    orig = os.path.join(DIR, 'casting_east_orig.png')
    if not os.path.exists(orig):
        shutil.copyfile(strip, orig)
    src = Image.open(orig).convert('RGBA')
    w = src.width / CAST
    out = Image.new('RGBA', src.size, CLEAR)
    boots = west_boots()
    for i in range(CAST):
        l, r = round(i * w), round((i + 1) * w)
        out.alpha_composite(fix(src.crop((l, 0, r, src.height)), boots, i in KICK, i in LUNGE), (l, 0))
    path = argv[argv.index('--out') + 1] if '--out' in argv else strip
    out.save(path)
    print('wrote', path)


if __name__ == '__main__':
    main(sys.argv[1:])

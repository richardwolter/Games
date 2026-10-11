"""Where the angler's net hand is in every cast frame: `assets/character_grips.json`.

The hand holding the net pouch (the basket, which is the net he throws), frame by frame, so the
rope runs into it and the line hauled in hangs from it in loops (`CastNet`, 2026-10-11). Found
off the sliced sheet, not authored:

- East and south: the first frame's hand is the one touching the basket; every later frame's is
  the hand nearest the last one, so the grip never jumps to the other hand mid-throw.
- South hangs them on the net pouch itself, which swings out to the right on the throw.
- West throws with the front hand (its basket is on the far side) and north keeps the basket
  hand on the right, so there it is simply the hand on that side of the body.
- Where that hand is behind the body, the grip stays where it was last seen, and frames before
  it is first seen take its first place.

Hands are the skin between the face and the boots, measured up from the feet. Points are in
the frame's cell, as `character.json`'s regions are.

  PYTHONPATH=<psd-extract site-packages> python tools/build_grips.py

Re-run after `tools/slice_character.gd`. Check the marks with `--sheet`, which writes
`tools/last_grips_<pose>.png`.
"""
import json
import sys
from PIL import Image, ImageDraw

SHEET = 'assets/character.json'
OUT = 'assets/character_grips.json'
DIRS = ('east', 'west', 'south', 'north')

SKIN = {
    (243, 166, 119), (238, 179, 136), (212, 109, 76), (233, 136, 91), (192, 87, 63),
    (223, 124, 80), (221, 150, 108),
}
WICKER = {
    (200, 115, 57), (125, 61, 42), (181, 125, 85), (182, 104, 48), (165, 94, 52),
    (145, 77, 49), (170, 115, 69), (220, 191, 140),
}
# The net's mesh, once the throw has opened it.
MESH = {(204, 212, 220), (182, 190, 206), (168, 181, 196), (222, 222, 220), (140, 156, 184)}
# The hand on one side of the screen, where it is never the one touching the basket.
SIDE = {'west': 'left', 'north': 'right'}
# Where the loops sit on the net pouch itself rather than the hand: facing the camera the pouch
# swings out to the right of the body on the throw, and the loops go with it, over it
# (Richard, 2026-10-11).
ON_POUCH = ('south',)
# Hands start this far up from the feet; the face is above.
HANDS_FROM = 21
# Further than this from last frame's grip, in pixels, and the hand in sight is the other one.
HAND_STEP = 8.0


def solid(p):
    return p[3] > 128


def parts(pixels):
    left = set(pixels)
    out = []
    while left:
        start = left.pop()
        part, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in left:
                        left.discard(n)
                        part.add(n)
                        todo.append(n)
        out.append(part)
    return out


def pouch(cell, ink):
    """The net pouch's top middle, two pixels down, relative to the feet; None out of sight."""
    px = cell.load()
    w, h = cell.size
    ix, iy, iw, ih = ink
    below = iy + ih - HANDS_FROM
    held = {(x, y) for y in range(below, h) for x in range(w)
            if solid(px[x, y]) and (px[x, y][:3] in WICKER or px[x, y][:3] in MESH)}
    items = [p for p in parts(held) if len(p) >= 12]
    if not items:
        return None
    item = max(items, key=len)
    xs = [x for x, _ in item]
    top = min(y for _, y in item)
    return ((min(xs) + max(xs)) / 2 - (ix + iw / 2), top + 2 - (iy + ih))


def grip(cell, ink, last, side):
    """The net hand's middle, relative to the frame's feet (ink middle across, foot row down),
    or None where it is out of sight."""
    px = cell.load()
    w, h = cell.size
    ix, iy, iw, ih = ink
    feet = (ix + iw / 2, iy + ih)
    below = iy + ih - HANDS_FROM
    skin = {(x, y) for y in range(below, h) for x in range(w) if solid(px[x, y]) and px[x, y][:3] in SKIN}
    hands = [p for p in parts(skin) if len(p) >= 3]
    if not hands:
        return None

    def mid(p):
        return (sum(x for x, _ in p) / len(p) - feet[0], sum(y for _, y in p) / len(p) - feet[1])

    if side is not None:
        on = [p for p in hands if (mid(p)[0] < -2) == (side == 'left')]
        if not on:
            return None
        return min((mid(p) for p in on), key=lambda m: m[0] if side == 'left' else -m[0])
    if last is not None:
        best = min((mid(p) for p in hands), key=lambda m: (m[0] - last[0]) ** 2 + (m[1] - last[1]) ** 2)
        if (best[0] - last[0]) ** 2 + (best[1] - last[1]) ** 2 > HAND_STEP ** 2:
            return None
        return best
    held = {(x, y) for y in range(below, h) for x in range(w)
            if solid(px[x, y]) and (px[x, y][:3] in WICKER or px[x, y][:3] in MESH)}
    items = [p for p in parts(held) if len(p) >= 12]
    if not items:
        return None
    item = max(items, key=len)
    hand = min(hands, key=lambda p: min(abs(x - a) + abs(y - b) for x, y in p for a, b in item))
    return mid(hand)


def main(argv):
    book = json.load(open(SHEET))
    atlas = Image.open(book['sheet'].replace('res://', '')).convert('RGBA')
    out = {}
    for d in DIRS:
        pose = 'cast_%s' % d
        frames = book['poses'][pose]
        found = []
        last = None
        for f in frames:
            rx, ry, rw, rh = f['region']
            cell = atlas.crop((rx, ry, rx + rw, ry + rh))
            g = pouch(cell, f['ink']) if d in ON_POUCH else grip(cell, f['ink'], last, SIDE.get(d))
            if g is not None:
                last = g
            found.append(g)
        first = next((g for g in found if g is not None), (0.0, -14.0))
        held = first
        points = []
        for f, g in zip(frames, found):
            held = g if g is not None else held
            ix, iy, iw, ih = f['ink']
            points.append([round(held[0] + ix + iw / 2, 1), round(held[1] + iy + ih, 1)])
        out[pose] = points
        if '--sheet' in argv:
            sheet(atlas, frames, points, 'tools/last_grips_%s.png' % pose)
    with open(OUT, 'w', newline='\n') as file:
        json.dump(out, file, indent='\t')
        file.write('\n')
    print('wrote', OUT)


def sheet(atlas, frames, points, path):
    z = 5
    tiles = []
    for f, (gx, gy) in zip(frames, points):
        rx, ry, rw, rh = f['region']
        bg = Image.new('RGBA', (rw, rh), (86, 120, 60, 255))
        bg.alpha_composite(atlas.crop((rx, ry, rx + rw, ry + rh)))
        big = bg.resize((rw * z, rh * z), Image.NEAREST)
        x, y = gx * z, gy * z
        ImageDraw.Draw(big).ellipse([x - 6, y - 6, x + 6, y + 6], outline=(255, 0, 0, 255), width=2)
        tiles.append(big)
    tw = max(t.width for t in tiles)
    th = max(t.height for t in tiles)
    o = Image.new('RGBA', (tw * 8, th * ((len(tiles) + 7) // 8)), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        o.paste(t, ((i % 8) * tw, (i // 8) * th))
    o.save(path)


main(sys.argv[1:])

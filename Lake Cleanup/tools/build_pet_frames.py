"""Builds the angler's reach-to-pet strips by rule, off the first idle frame of each direction.

Rules first, polish after (2026-09-28, /grill-me with Richard): there is no painted reach in
the sheet, so this bends the idle figure down and puts an arm out towards the dog, and writes
`art_source/character_extracted/pet_<dir>.png` for `tools/slice_character.gd` to cut like any
other strip. Richard may paint over the strips; re-running this overwrites them.

Six frames: dip, dip with the arm starting out, the arm out (the touch), a pat, the arm out,
and half way back up. The upper body is lowered over the top of the legs (a crouch), never
moved sideways, so the body's middle stays where the idle one is and the arm alone reaches.

Run with the logo venv python (Pillow) from the project root:
    python tools/build_pet_frames.py
"""
from PIL import Image

SRC = "art_source/character_extracted/idle_%s.png"
OUT = "art_source/character_extracted/pet_%s.png"
IDLE_FRAMES = 9

# The four in the order the slicer reads them.
DIRS = ["south", "north", "east", "west"]

# Per frame: how many rows the upper body drops, and how far the arm is out (0 none, 1 half,
# 2 full), and the hand's lift (the pat).
FRAMES = [
    (2, 0, 0),
    (3, 1, 0),
    (4, 2, 0),
    (4, 2, -1),
    (4, 2, 0),
    (2, 0, 0),
]

# Where the waist is, as a share of the figure's inked height from the top: the rows above
# it are the upper body that bends.
WAIST = 0.64

# Room either side of the idle ink, so an arm out never leaves its cell.
PAD = 12

OUTLINE = (0, 0, 0, 255)
SLEEVE = (236, 218, 177, 255)
SLEEVE_SHADE = (196, 170, 128, 255)
SKIN = (243, 166, 119, 255)
SKIN_SHADE = (200, 115, 57, 255)


def ink_box(im):
    box = im.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    return box


def first_idle(direction):
    strip = Image.open(SRC % direction).convert("RGBA")
    cell = strip.width / IDLE_FRAMES
    frame = strip.crop((0, 0, round(cell), strip.height))
    left, top, right, bottom = ink_box(frame)
    wide = (right - left) + PAD * 2
    out = Image.new("RGBA", (wide, strip.height), (0, 0, 0, 0))
    out.alpha_composite(frame.crop((left, 0, right, strip.height)), (PAD, 0))
    return out


def crouch(figure, drop):
    """The rows above the waist lowered by `drop`, over the top of the legs."""
    left, top, right, bottom = ink_box(figure)
    waist = top + int((bottom - top) * WAIST)
    out = figure.copy()
    upper = figure.crop((0, 0, figure.width, waist))
    # Clear what the upper body will leave or cover, then lay it back lower.
    out.paste((0, 0, 0, 0), (0, 0, figure.width, waist + drop))
    out.alpha_composite(upper, (0, drop))
    return out, waist + drop


def put(im, x, y, colour):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), colour)


def ringed(im, cells):
    """Paints `cells` ({(x, y): colour}) and rings them in the outline where they meet air."""
    for (x, y), colour in cells.items():
        put(im, x, y, colour)
    for (x, y) in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in cells:
                continue
            if 0 <= n[0] < im.width and 0 <= n[1] < im.height and im.getpixel(n)[3] < 128:
                put(im, n[0], n[1], OUTLINE)


def side_arm(im, waist, out, lift, way):
    """An arm straight out in front at the waist, for the side views. `way` is +1 or -1."""
    left, top, right, bottom = ink_box(im)
    # The shoulder: the front edge of the body a few rows under the chest.
    chest = waist - 4
    row = [x for x in range(im.width) if im.getpixel((x, chest))[3] >= 128]
    front = max(row) if way > 0 else min(row)
    sleeve = 3 if out == 1 else 5
    hand = 2 if out == 1 else 3
    y0 = chest + 1
    cells = {}
    for i in range(sleeve):
        x = front + way * (i + 1)
        # The arm angles down towards the dog as it goes out.
        dy = i
        cells[(x, y0 + dy)] = SLEEVE
        cells[(x, y0 + dy + 1)] = SLEEVE
        cells[(x, y0 + dy + 2)] = SLEEVE_SHADE
    tip = front + way * (sleeve + 1)
    hy = y0 + sleeve + lift
    for i in range(hand):
        x = tip + way * i
        cells[(x, hy)] = SKIN
        cells[(x, hy + 1)] = SKIN
        cells[(x, hy + 2)] = SKIN_SHADE
    ringed(im, cells)


def front_arm(im, waist, out, lift):
    """The south view: the right hand comes forward and down in front of the legs."""
    left, top, right, bottom = ink_box(im)
    mid = (left + right) // 2
    cells = {}
    reach = 3 if out == 1 else 6
    for i in range(reach):
        cells[(mid + 2, waist - 3 + i)] = SLEEVE if i < reach - 2 else SKIN
        cells[(mid + 3, waist - 3 + i)] = SLEEVE_SHADE if i < reach - 2 else SKIN_SHADE
    y = waist - 3 + reach + lift
    for x in (mid + 1, mid + 2, mid + 3, mid + 4):
        cells[(x, y)] = SKIN
    cells[(mid + 2, y + 1)] = SKIN_SHADE
    cells[(mid + 3, y + 1)] = SKIN_SHADE
    ringed(im, cells)


def build(direction):
    figure = first_idle(direction)
    frames = []
    for drop, out, lift in FRAMES:
        frame, waist = crouch(figure, drop)
        if out:
            if direction == "east":
                side_arm(frame, waist, out, lift, 1)
            elif direction == "west":
                side_arm(frame, waist, out, lift, -1)
            elif direction == "south":
                front_arm(frame, waist, out, lift)
            # North: the reach is away from the camera, behind the body. The crouch is it.
        frames.append(frame)
    strip = Image.new("RGBA", (figure.width * len(frames), figure.height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(frame, (i * figure.width, 0))
    strip.save(OUT % direction)
    print("wrote", OUT % direction, strip.size)


def contact_sheet():
    rows = [Image.open(OUT % d) for d in DIRS]
    wide = max(r.width for r in rows)
    sheet = Image.new("RGBA", (wide, sum(r.height for r in rows)), (90, 100, 110, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet = sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST)
    sheet.save("tools/last_pet_frames.png")


if __name__ == "__main__":
    for d in DIRS:
        build(d)
    contact_sheet()

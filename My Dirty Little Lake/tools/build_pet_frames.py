"""Builds the angler's reach-to-pet strips by rule, off the first idle frame of each direction.

Rules first, polish after (2026-09-28, /grill-me with Richard): there is no painted reach in
the sheet, so this bends the idle figure down and puts an arm out, and writes
`art_source/character_extracted/pet<k>_<dir>.png` for `tools/slice_character.gd` to cut like
any other strip. Richard may paint over the strips; re-running this overwrites them.

The arm is the cast frames' arm: a cream sleeve rolled up into a lighter cuff, a bare orange
forearm and a fist, ringed in black and shaded on its lower side. The hand has to land on the
dog's head or body, whichever is nearer (Richard, same day), and a dog can be anywhere round
the angler, so every direction is built at `len(ANGLES)` arm angles and the game picks the one
pointing nearest the spot (`Angler.start_pet`). Side views: degrees below straight out. Front
view: degrees the arm swings off straight down, towards the figure's right. From behind the
arm is hidden by the body, so every angle is the crouch alone.

Six frames: dip, dip with the arm half out, the arm out (the touch), a pat, the arm out, and
half way back up. The upper body is lowered over the top of the legs, never moved sideways, so
the body's middle stays where the idle one is and the arm alone reaches.

Run with the logo venv python (Pillow) from the project root:
    python tools/build_pet_frames.py
"""
import math

from PIL import Image

SRC = "art_source/character_extracted/idle_%s.png"
OUT = "art_source/character_extracted/pet%d_%s.png"
IDLE_FRAMES = 9

# The four in the order the slicer reads them.
DIRS = ["south", "north", "east", "west"]

# Must match `Angler.PET_SIDE_ANGLES` / `PET_FRONT_ANGLES`.
SIDE_ANGLES = [0, 25, 50, 75]
FRONT_ANGLES = [-40, -12, 12, 40]
# Back view: degrees the arm swings off straight up the screen, towards screen right
# (`Angler.PET_BACK_ANGLES`). Mostly out to the left, the free hand's side, where the hat's
# brim does not hide it.
BACK_ANGLES = [-70, -45, -20, 5]

# Per frame: how many rows the upper body drops, how far the arm is out (0 none, 0.55 half,
# 1 full) and the hand's lift in pixels (the pat).
FRAMES = [
    (2, 0.0, 0),
    (3, 0.55, 0),
    (4, 1.0, 0),
    (4, 1.0, -1),
    (4, 1.0, 0),
    (2, 0.0, 0),
]

# Where the waist is, as a share of the figure's inked height from the top.
WAIST = 0.64

# Room either side of the idle ink, so an arm out never leaves its cell.
PAD = 16

# The arm along its length, in pixels from the shoulder: (up to, half-thickness, colour, shade).
SEGMENTS = [
    (4.0, 2.2, (236, 218, 177, 255), (196, 170, 128, 255)),  # sleeve
    (6.0, 2.6, (250, 238, 208, 255), (206, 182, 140, 255)),  # the roll, a touch wider
    (10.0, 1.7, (243, 166, 119, 255), (200, 115, 57, 255)),  # forearm
    (13.0, 2.2, (243, 166, 119, 255), (200, 115, 57, 255)),  # fist
]
ARM_LONG = SEGMENTS[-1][0]
OUTLINE = (0, 0, 0, 255)


def ink_box(im):
    return im.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()


def first_idle(direction):
    strip = Image.open(SRC % direction).convert("RGBA")
    cell = strip.width / IDLE_FRAMES
    frame = strip.crop((0, 0, round(cell), strip.height))
    left, top, right, bottom = ink_box(frame)
    wide = (right - left) + PAD * 2
    out = Image.new("RGBA", (wide, strip.height + 8), (0, 0, 0, 0))
    out.alpha_composite(frame.crop((left, 0, right, strip.height)), (PAD, 0))
    return out


def crouch(figure, drop):
    """The rows above the waist lowered by `drop`, over the top of the legs."""
    left, top, right, bottom = ink_box(figure)
    waist = top + int((bottom - top) * WAIST)
    out = figure.copy()
    upper = figure.crop((0, 0, figure.width, waist))
    out.paste((0, 0, 0, 0), (0, 0, figure.width, waist + drop))
    out.alpha_composite(upper, (0, drop))
    return out, waist + drop


def arm(im, shoulder, heading, reach, lift, behind=False):
    """Paints the arm from `shoulder` along `heading` (a unit vector), `reach` of its length."""
    long = ARM_LONG * reach
    # Only the fist and forearm when half out: the sleeve is always there.
    hx, hy = heading
    nx, ny = -hy, hx
    if ny < 0 or (ny == 0 and nx < 0):
        nx, ny = -nx, -ny  # the shade side faces down the screen
    cells = {}
    for y in range(im.height):
        for x in range(im.width):
            px, py = x + 0.5 - shoulder[0], y + 0.5 - shoulder[1]
            t = px * hx + py * hy
            s = px * nx + py * ny
            if t < 0 or t > long:
                continue
            # The fist rides the pat; nothing else does.
            seg = next((i for i, g in enumerate(SEGMENTS) if t <= g[0] * reach), None)
            if seg is None:
                continue
            _, half, colour, shade = SEGMENTS[seg]
            if seg == len(SEGMENTS) - 1:
                s -= lift
            if abs(s) > half:
                continue
            cells[(x, y)] = shade if s > half - 1.0 else colour
    if behind:
        # Reaching away from the camera: the arm is behind the body and the hat, so only
        # what shows past their edges is drawn.
        cells = {c: v for c, v in cells.items() if im.getpixel(c)[3] < 128}
    for (x, y), colour in cells.items():
        im.putpixel((x, y), colour)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in cells or not (0 <= n[0] < im.width and 0 <= n[1] < im.height):
                continue
            # Over the body too: laid across the shirt, an arm with no line round it is a
            # smear of cream on cream. Only where the arm is in front of it (the front view)
            # does that line show; on the side views the shoulder end is inside the arm's
            # own drawing.
            if behind and im.getpixel(n)[3] >= 128:
                continue
            im.putpixel(n, OUTLINE)


def shoulder_of(im, waist, direction):
    left, top, right, bottom = ink_box(im)
    row = waist - 3
    xs = [x for x in range(im.width) if im.getpixel((x, row))[3] >= 128]
    if direction == "east":
        return (max(xs) - 1.5, row)
    if direction == "west":
        return (min(xs) + 1.5, row)
    # Front and back: from the free hand's shoulder (Richard, 2026-09-28: "it should come
    # from free left hand"). The figure's left is the screen's right seen from the front and
    # the screen's left seen from behind; the basket is in the other hand.
    free = FREE_ARMS[direction]
    shoulder = free["shoulder"]
    return (shoulder[0] + PAD, shoulder[1] + (waist - _WAIST_AT_REST))


# The free arm on the front and back idle frames, in that frame's own pixels (measured off
# `idle_<dir>.png`, frame 0): the box it hangs in, outline included, which is cleared while
# the reach is out so there are not two; the column the torso's edge is re-inked on; and
# where the new arm leaves the shoulder. Re-measure if either idle frame is repainted.
FREE_ARMS = {
    # Sleeve from row 25, hand down to 35, its outline on 36; columns 26-31, torso at 25.
    "south": {"box": (26, 25, 32, 37), "edge": 25, "shoulder": (26.5, 26.5)},
    # Sleeve from row 22, hand down to 32, its outline on 33; columns 0-5, torso at 6.
    "north": {"box": (0, 22, 6, 34), "edge": 6, "shoulder": (4.5, 23.5)},
}
_WAIST_AT_REST = 0


def free_arm_off(figure, direction):
    """The figure with its hanging free arm taken off, the torso's edge re-inked."""
    out = figure.copy()
    free = FREE_ARMS[direction]
    x0, y0, x1, y1 = free["box"]
    for y in range(y0, y1):
        for x in range(x0 + PAD, x1 + PAD):
            out.putpixel((x, y), (0, 0, 0, 0))
        edge = (free["edge"] + PAD, y)
        if out.getpixel(edge)[3] >= 128:
            out.putpixel(edge, OUTLINE)
    return out


def heading_of(direction, angle):
    a = math.radians(angle)
    if direction == "east":
        return (math.cos(a), math.sin(a))
    if direction == "west":
        return (-math.cos(a), math.sin(a))
    if direction == "north":
        # Back: straight up the screen, swung by the angle.
        return (math.sin(a), -math.cos(a))
    # Front: straight down the screen, swung by the angle.
    return (math.sin(a), math.cos(a))


def build(direction, k, angle):
    global _WAIST_AT_REST
    figure = first_idle(direction)
    _, _WAIST_AT_REST = crouch(figure, 0)
    armless = free_arm_off(figure, direction) if direction in FREE_ARMS else figure
    frames = []
    for drop, reach, lift in FRAMES:
        frame, waist = crouch(armless if reach > 0 else figure, drop)
        if reach > 0:
            arm(frame, shoulder_of(frame, waist, direction), heading_of(direction, angle),
                reach, lift, behind=direction == "north")
        frames.append(frame)
    strip = Image.new("RGBA", (figure.width * len(frames), figure.height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(frame, (i * figure.width, 0))
    strip.save(OUT % (k, direction))
    return strip


def main():
    rows = []
    for direction in DIRS:
        angles = {"east": SIDE_ANGLES, "west": SIDE_ANGLES, "south": FRONT_ANGLES,
                  "north": BACK_ANGLES}[direction]
        for k, angle in enumerate(angles):
            rows.append(build(direction, k, angle))
    wide = max(r.width for r in rows)
    sheet = Image.new("RGBA", (wide, sum(r.height for r in rows)), (90, 100, 110, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
        "tools/last_pet_frames.png"
    )
    print("wrote", len(rows), "strips")


if __name__ == "__main__":
    main()

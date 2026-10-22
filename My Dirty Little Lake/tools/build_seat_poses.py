"""The angler's seated poses, built by rule from his idle frames (2026-10-22, /grill-me with
Richard, picked off four rounds of `tools/seat_look/seat_mockup.py`).

He is a short man, so nothing bends to reach: facing the room his short legs lie straight
out on the seat and show the soles of his boots; from the side they lie out level with the
boot on its heel, toe up; with his back to the room he is cut at the seat of his trousers,
which rest on the cushion. Each pose is (figure, anchor): the anchor is the figure pixel that
goes on the seat's spot (`ShedRoom.RESTS`). `tools/build_rest_frames.py` writes the strips.
"""
from PIL import Image

import build_pose_mockup as pose

INK = (0, 0, 0, 255)
CLEAR = (0, 0, 0, 0)

# The angler's own trouser and boot tones (idle_south).
T_LIT = (95, 120, 142, 255)
T_MID = (76, 95, 126, 255)
T_DARK = (62, 76, 108, 255)
T_SEAM = (37, 39, 53, 255)
B_TOP = (145, 77, 49, 255)
B_BODY = (93, 46, 40, 255)
B_SOLE = (74, 36, 35, 255)

def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def ink_round(im):
    """Re-ink the silhouette: the outline pass from the pose builder."""
    return pose.outlined(im)


# ---- the poses -----------------------------------------------------------------------------
# Each returns (figure, anchor): the anchor is the figure pixel laid on the seat's spot.

SKIN = (243, 166, 119, 255)
SKIN_SHADE = (212, 109, 76, 255)


def torso_south(lap=True):
    """Idle south above the belt's foot, the basket and its handle taken off. With `lap`, the
    hanging hands come off and the forearms run down and in to rest on the knees."""
    im = pose.idle("south").crop((0, 0, 32, 33))
    for y in range(29, 33):
        for x in range(0, 3):
            put(im, x, y, CLEAR)
    if not lap:
        return im
    big = Image.new("RGBA", (32, 38), CLEAR)
    for y in range(29, 33):
        for x in list(range(0, 9)) + list(range(24, 32)):
            put(im, x, y, CLEAR)
    big.alpha_composite(im, (0, 0))
    return big


def forearms(im, hand_y=32):
    """Forearms from the elbows down and in, the hands resting on the lap."""
    for side in (0, 1):
        steps = hand_y - 29
        pts = [(5 + i, 29 + i) for i in range(steps)]
        for x, y in pts:
            for dx in (0, 1):
                xx = x + dx
                c = SKIN if dx == 0 else SKIN_SHADE
                if side:
                    xx = 31 - xx
                    c = SKIN if dx else SKIN_SHADE
                put(im, xx, y, c)
        x0 = 5 + steps
        for x in range(x0, x0 + 3):
            for y in (hand_y, hand_y + 1):
                xx = 31 - x if side else x
                put(im, xx, y, SKIN if y == hand_y else SKIN_SHADE)


def body_axis(im, top, bottom):
    """The middle of the body, not of the ink box: the median of each row's middle."""
    mids = []
    a = im.getchannel("A")
    for y in range(top, min(bottom, im.height)):
        xs = [x for x in range(im.width) if a.getpixel((x, y)) >= 128]
        if xs:
            mids.append((xs[0] + xs[-1]) / 2.0)
    mids.sort()
    return round(mids[len(mids) // 2]) if mids else im.width // 2


def sole(im, x, y, right=False):
    """A boot seen from its sole: the toe cap over the top, the sole, a groove, the heel.
    Six wide, five tall, turned out a pixel at the toe."""
    rows = [
        (1, 4, B_TOP),
        (0, 5, B_BODY),
        (0, 5, B_SOLE),
        (1, 4, INK),
        (1, 4, B_SOLE),
    ]
    for dy, (a, b, c) in enumerate(rows):
        for xx in range(a, b + 1):
            put(im, x + xx, y + dy, c)
    # The lit rim round the sole.
    put(im, x, y + 1, B_TOP)
    put(im, x + 5, y + 1, B_TOP)
    tip = x - 1 if not right else x + 6
    put(im, tip, y, B_TOP)


def sit_front():
    """A short man sitting facing the room: his legs are short, so they lie straight out on
    the seat and stop short of its edge, the boots' toes up and towards us. Nothing bends."""
    top = torso_south()
    im = Image.new("RGBA", (32, 44), CLEAR)
    im.alpha_composite(top, (0, 0))
    for r, c in ((33, T_LIT), (34, T_LIT), (35, T_MID), (36, T_DARK), (37, T_DARK)):
        for x in list(range(9, 16)) + list(range(17, 24)):
            put(im, x, r, c)
        put(im, 16, r, T_SEAM)
    # The boots at the end of the legs, their soles towards us: a short man's legs lie out
    # on the seat, so what faces the room is the bottom of his boots.
    sole(im, 9, 37)
    sole(im, 18, 37, True)
    forearms(im, 32)
    out = ink_round(im)
    return out, (body_axis(out, 16, 33), 33)


def crouch_front():
    """Getting down onto the seat: the legs half under him."""
    top = torso_south(False)
    im = Image.new("RGBA", (32, 42), CLEAR)
    im.alpha_composite(top, (0, 0))
    for r in range(33, 36):
        for x in list(range(9, 16)) + list(range(17, 24)):
            put(im, x, r, T_MID if r == 33 else T_DARK)
        put(im, 16, r, T_SEAM)
    idle = pose.idle("south")
    im.alpha_composite(idle.crop((8, 38, 15, 43)), (8, 36))
    im.alpha_composite(idle.crop((19, 38, 26, 43)), (19, 36))
    out = ink_round(im)
    return out, (body_axis(out, 16, 33), 33)


def torso_west():
    return pose.idle("west").crop((0, 0, 30, 36))


def boot_up(im, x, y):
    """A boot in profile resting on its heel, toe up and forward (left): the toe cap tips
    over the front, the sole runs down the front and under the heel, the ankle joins the leg
    on the right."""
    shape = [
        ".TT...",
        "TBBT..",
        "SBBB..",
        "SBBBBB",
        "SBBBBB",
        "SSSSS.",
    ]
    tones = {"T": B_TOP, "B": B_BODY, "S": B_SOLE}
    for dy, row in enumerate(shape):
        for dx, ch in enumerate(row):
            if ch in tones:
                put(im, x + dx, y + dy, tones[ch])


def sit_side():
    """A short man sitting facing left, his back to a backrest on the right: the legs lie
    straight out on the seat, not reaching its edge, the boot on its heel, toe up."""
    top = torso_west()
    im = Image.new("RGBA", (30, 41), CLEAR)
    im.alpha_composite(top, (0, 0))
    for r, c in ((35, T_LIT), (36, T_LIT), (37, T_MID), (38, T_MID), (39, T_DARK)):
        for x in range(9, 22):
            put(im, x, r, c)
    boot_up(im, 4, 34)
    out = ink_round(im)
    return out, (21, 39)


def crouch_side():
    """Getting down onto the seat: the legs still under him."""
    top = torso_west()
    im = Image.new("RGBA", (30, 42), CLEAR)
    im.alpha_composite(top, (0, 0))
    for r in range(36, 39):
        for x in range(12, 21):
            put(im, x, r, T_MID if r == 36 else T_DARK)
    for r in (39, 40):
        for x in range(12, 16):
            put(im, x, r, T_DARK)
    boot_left(im, 9, 41)
    return ink_round(im), (21, 39)


def boot_left(im, x, y):
    for dy, (a, b, c) in enumerate(((2, 6, B_TOP), (0, 6, B_BODY), (0, 6, B_SOLE))):
        for xx in range(a, b + 1):
            put(im, x + xx, y + dy, c)


def sit_back():
    """Back to the room on a chair: down to the seat of his trousers, so he sits on the
    cushion that shows under the backrest. The basket and its handle off, the hands kept."""
    im = pose.idle("north").crop((0, 0, 32, 35))
    for y in range(28, 35):
        for x in range(24 if y >= 32 else 29, 32):
            put(im, x, y, CLEAR)
    out = ink_round(im)
    return out, (body_axis(out, 16, 29), 34)


def crouch_back():
    return sit_back()


def mirror(fig):
    im, (ax, ay) = fig
    return im.transpose(Image.FLIP_LEFT_RIGHT), (im.width - 1 - ax, ay)

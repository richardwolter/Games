"""Three pointing hands for the shed's switch cue, laid over the real room (2026-10-03).

Offline mockup, not a pipeline: writes tools/last_hand_mockup.png (each option in the room
at play size, beside a close-up and its four animation frames) and tools/last_hand_mockup.gif.
The room is tools/last_shed_turn.png (SHED_CUES=1 on shot_shed.tscn), where the hands are
hidden because a piece is in hand. Run with the psd-extract venv's site-packages on PYTHONPATH.

A  Glove    a cartoon glove, blue ribbed cuff, stitches, taps down with two impact ticks.
B  Carved   the hand cut from the menus' oak: grain, a V bite, a nail, sways on a twine.
C  Angler   the angler's own skin and cream shirt cuff, a gold star winking at the tip.

All three are drawn at the furniture's grain (SHED_SCALE 0.74 at the room's zoom 2, through
the 1.5 stretch: 2.2 screen px an art px), lit from the right like every painted asset, with
a soft shadow down and to the left.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ROOM = ROOT / "tools/last_shed_turn.png"
OUT = ROOT / "tools/last_hand_mockup.png"
GIF = ROOT / "tools/last_hand_mockup.gif"

PX = 2.22
INK = (24, 18, 17)

# The silhouette, pointing down, seen from the back of a hand: cuff (rows 0-3), the back of
# the hand with the thumb bulging out on the left, the curled fingers' rounded bumps along the
# bottom right, and the index finger going down on the left with a rounded tip.
HAND = [
    "....########....",
    "...##########...",
    "...##########...",
    "...##########...",
    "..############..",
    ".##############.",
    "################",
    "################",
    "################",
    ".###############",
    ".##############.",
    "..#####.##.##...",
    "..####..........",
    "..####..........",
    "..####..........",
    "..####..........",
    "..####..........",
    "..####..........",
    "...##...........",
]
CUFF_ROWS = 4
TIP = (3.5, len(HAND))  # the fingertip's foot, in art px


def mask():
    return {(x, y) for y, row in enumerate(HAND) for x, c in enumerate(row) if c == "#"}


def ring(fill):
    out = set()
    for (x, y) in fill:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n not in fill:
                    out.add(n)
    return out


def tone(fill, x, y):
    """Lit from the right, the game's rule: right edge lit, left and bottom edges shaded."""
    if (x + 1, y) not in fill or (x + 1, y - 1) not in fill and (x, y - 1) not in fill:
        return "lit"
    if (x - 1, y) not in fill or (x, y + 1) not in fill:
        return "low"
    if (x - 2, y) not in fill or (x, y + 2) not in fill:
        return "mid"
    return "body"


PALETTE = {
    "glove": {
        "hand": {"body": (246, 243, 234), "mid": (224, 219, 208), "lit": (255, 255, 255),
                 "low": (186, 180, 171), "line": (168, 161, 152)},
        "cuff": {"body": (90, 134, 173), "mid": (80, 121, 160), "lit": (138, 178, 210),
                 "low": (62, 98, 130), "line": (46, 74, 101)},
    },
    "carved": {
        "hand": {"body": (200, 158, 124), "mid": (184, 140, 108), "lit": (228, 194, 160),
                 "low": (146, 96, 70), "line": (166, 118, 88)},
        "cuff": {"body": (150, 100, 76), "mid": (140, 92, 70), "lit": (176, 128, 100),
                 "low": (112, 68, 50), "line": (88, 54, 38)},
    },
    "angler": {
        "hand": {"body": (243, 166, 119), "mid": (228, 143, 101), "lit": (252, 198, 158),
                 "low": (192, 87, 63), "line": (196, 98, 68)},
        "cuff": {"body": (236, 218, 177), "mid": (222, 202, 160), "lit": (250, 240, 214),
                 "low": (185, 160, 121), "line": (150, 124, 90)},
    },
}


def paint(look, frame):
    """One hand: art pixel -> colour, in its own frame."""
    fill = mask()
    pal = PALETTE[look]
    px = {}
    for p in ring(fill):
        px[p] = INK
    for (x, y) in fill:
        part = "cuff" if y < CUFF_ROWS else "hand"
        px[(x, y)] = pal[part][tone(fill, x, y)]
    # The cuff's foot, where it meets the hand.
    for x in range(4, 13):
        if (x, CUFF_ROWS - 1) in fill:
            px[(x, CUFF_ROWS - 1)] = pal["cuff"]["low"]
    # The curled fingers part from each other and from the index finger.
    for (x, y) in ((7, 10), (7, 9), (10, 10), (13, 10)):
        px[(x, y)] = pal["hand"]["line"]
    # The curled fingers' knuckles catch the light.
    for (x, y) in ((9, 11), (12, 11)):
        px[(x, y)] = pal["hand"]["lit"]
    # The thumb's crease, a short curve on the left of the back of the hand.
    for (x, y) in ((2, 6), (2, 7), (3, 8)):
        px[(x, y)] = pal["hand"]["line"]
    # The finger's joint.
    for x in (3, 4):
        px[(x, 14)] = pal["hand"]["mid"]
    if look == "glove":
        for x in (5, 7, 9, 11):
            px[(x, 1)] = pal["cuff"]["low"]
            px[(x, 2)] = pal["cuff"]["low"]
        for (x, y) in ((7, 5), (7, 6), (7, 7), (9, 5), (9, 6), (9, 7), (11, 5), (11, 6), (11, 7)):
            px[(x, y)] = pal["hand"]["mid"]
    if look == "carved":
        for (x, y) in ((4, 5), (5, 5), (6, 5), (9, 7), (10, 7), (11, 7), (12, 7), (3, 9),
                       (4, 9), (7, 9), (8, 9), (3, 12), (4, 16), (11, 2), (12, 2), (5, 1), (6, 1)):
            if (x, y) in fill and px[(x, y)] != INK:
                px[(x, y)] = pal["hand"]["line"] if y >= CUFF_ROWS else pal["cuff"]["line"]
        # A V bite out of the cuff's top edge, ringed in the hole's black like every bite.
        for p in ((8, 0), (9, 0), (8, 1)):
            px[p] = INK
        px[(7, 0)] = INK
        # The nail it hangs from.
        px[(8, 2)] = (66, 43, 28)
        px[(9, 2)] = (110, 104, 98)
    if look == "angler":
        # The shirt's cuff turned back, and a pink fingernail.
        for x in range(4, 12):
            px[(x, 1)] = pal["cuff"]["lit"]
        px[(3, 17)] = (250, 206, 186)
        px[(4, 17)] = (236, 178, 160)
    return px


def extras(look, frame):
    out = {}
    if look == "glove" and frame == 2:
        for (x, y) in ((-1, 17), (-2, 18), (8, 17), (9, 18)):
            out[(x, y)] = (255, 255, 255)
    if look == "angler":
        gold, pale = (255, 205, 77), (255, 245, 200)
        s = (8, 15)
        if frame in (1, 2):
            arm = 3 if frame == 1 else 2
            out[s] = pale
            for k in range(1, arm + 1):
                for n in ((s[0] + k, s[1]), (s[0] - k, s[1]), (s[0], s[1] + k), (s[0], s[1] - k)):
                    out[n] = gold
        else:
            out[s] = gold
    return out


# Each look loops on four frames: how far up it bobs (art px), and for the carved one how
# far its foot swings across (a pixel shear, the rows below the nail stepped across).
BOB = {"glove": [0, 1, -1, 0], "carved": [0, 0, 0, 0], "angler": [0, 1, 1, 0]}
SWAY = {"carved": [0, 1, 0, -1]}


def stamp(canvas, look, frame, tip, scale):
    """Draw a hand so its fingertip lands on `tip` (screen px) over a piece."""
    px = paint(look, frame)
    px.update(extras(look, frame))
    if look == "glove" and frame == 2:
        # The tap: a row out of the back of the hand, so the hand presses down a pixel.
        px = {(x, y if y >= 7 else y + 1): c for (x, y), c in px.items() if y != 7 or x < -0}
    sway = SWAY.get(look, [0, 0, 0, 0])[frame]
    if sway:
        px = {(x + (sway if y >= 10 else 0), y): c for (x, y), c in px.items()}
    bob = BOB[look][frame]
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def rect(x, y, c):
        sx = tip[0] + (x - TIP[0]) * scale
        sy = tip[1] + (y - TIP[1] - bob) * scale
        d.rectangle([round(sx), round(sy), round(sx + scale) - 1, round(sy + scale) - 1], fill=c)

    # The shadow first: the outline's shape, down and to the left, see-through.
    for (x, y) in px:
        rect(x - 1, y + 1, (0, 0, 0, 70))
    if look == "carved":
        # The twine up to the nail.
        for y in range(-6, 2):
            rect(8 + (sway if y > 0 else 0), y, (120, 100, 70, 255))
    for (x, y), c in px.items():
        rect(x, y, c + (255,))
    canvas.alpha_composite(layer)


NAMES = {"glove": "A  Glove: ribbed cuff, stitches, taps", "carved": "B  Carved oak: grain, bite, nail, sways",
         "angler": "C  Angler's hand: shirt cuff, gold star winks"}
LOOKS = ["glove", "carved", "angler"]


def main():
    room = Image.open(ROOM).convert("RGBA")
    # Fingertips over the fridge, the stove and the fireplace in the 1080p shot, two art px
    # over the top of each drawing.
    tips = [(534, 152), (1105, 223), (1058, 295)]
    crop = (440, 60, 1200, 380)
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    bands = [[None] * 3 for _ in range(4)]
    for f in range(4):
        for i, look in enumerate(LOOKS):
            r = room.copy()
            for t in tips:
                stamp(r, look, f, t, PX)
            bands[f][i] = r.crop(crop)
    close = 9
    tile = (24 * close, 30 * close)
    sheet = Image.new("RGBA", (cw + 30 + 4 * (tile[0] + 10), (ch + 40) * 3 + 20), (30, 34, 36, 255))
    d = ImageDraw.Draw(sheet)
    for i, look in enumerate(LOOKS):
        y0 = 24 + i * (ch + 40)
        d.text((10, y0 - 18), NAMES[look], fill=(240, 230, 200))
        sheet.alpha_composite(bands[0][i], (10, y0))
        for f in range(4):
            t = Image.new("RGBA", tile, (226, 206, 170, 255))
            stamp(t, look, f, (8 * close, 27 * close), close)
            sheet.alpha_composite(t, (cw + 30 + f * (tile[0] + 10), y0))
    sheet.save(OUT)
    frames = []
    for f in range(4):
        strip = Image.new("RGBA", (cw, ch * 3 + 20), (30, 34, 36, 255))
        for i in range(3):
            strip.alpha_composite(bands[f][i], (0, i * (ch + 10)))
        frames.append(strip.convert("RGB"))
    frames[0].save(GIF, save_all=True, append_images=frames[1:], duration=[300, 180, 180, 300],
                   loop=0)
    print("wrote", OUT, GIF)


if __name__ == "__main__":
    main()

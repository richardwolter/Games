#!/usr/bin/env python
"""Four looks for the record player's menu, drawn off the record player's own sprite.

    <psd-extract venv python> tools/build_record_menu_mockup.py

Writes tools/last_record_menu_mockup.png. A static picture to pick a style off; nothing in
the game reads it. Shapes are drawn on whole art pixels at 1x and blown up by SCALE, then
the words are set in Bungee at the blown-up size, the way the boards draw them.
"""
import math
from PIL import Image, ImageDraw, ImageFont

SCALE = 3
W, H = 200, 140
FONT = "assets/Bungee-Regular.ttf"

# The record player's own colours (assets/decor_clean.png, view "open").
OUT = (62, 14, 14)
LID = (104, 71, 78)
LID_LO = (97, 65, 72)
WALNUT = (99, 54, 31)
WALNUT_LO = (78, 28, 16)
WALNUT_HI = (138, 69, 48)
AMBER = (194, 96, 18)
AMBER_HI = (191, 110, 55)
AMBER_LO = (180, 85, 20)
PINK = (141, 58, 77)
VINYL = (28, 20, 22)
VINYL_HI = (58, 44, 48)
# The boards' paper (Style.PAPER / PAPER_INK / PAPER_HEAD).
PAPER = (234, 219, 184)
PAPER_EDGE = (206, 186, 146)
INK = (50, 36, 28)
HEAD = (115, 40, 26)
WATER = (90, 134, 173)
CREAM = (245, 232, 200)

SONGS = ["beatgucci", "Save ME", "Goin", "Indie Boi", "Habibs"]
LAKE = [True, True, True, False, False]
SHED = [False, False, False, True, False]
SYNC_ON = False


def rect(d, x, y, w, h, fill, edge=None):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=fill)
    if edge:
        d.rectangle([x, y, x + w - 1, y + h - 1], outline=edge)


def disc(d, cx, cy, r, label, spin):
    """A record on whole pixels: grooves, a lit arc, the label, the hole."""
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            q = math.hypot(x, y)
            if q > r + 0.3:
                continue
            c = VINYL
            if q > r - 0.8:
                c = OUT
            elif q > r * 0.42 and int(q) % 3 == 0:
                c = VINYL_HI
            a = (math.atan2(y, x) - spin) % (2 * math.pi)
            if q > r * 0.42 and q < r - 1 and a < 0.35:
                c = (96, 80, 84)
            if q <= r * 0.38:
                c = AMBER if q > r * 0.12 else OUT
                if r * 0.12 < q <= r * 0.2:
                    c = AMBER_HI
            d.point((cx + x, cy + y), fill=c)


def tick(d, x, y, on, face, edge, mark):
    rect(d, x, y, 7, 7, face, edge)
    if on:
        for p in [(1, 3), (2, 4), (3, 5), (4, 4), (5, 3), (5, 2)]:
            d.point((x + p[0], y + p[1]), fill=mark)


def lock(d, x, y, c):
    rect(d, x + 1, y + 3, 5, 4, c)
    d.rectangle([x + 2, y, x + 4, y + 3], outline=c)


def bites(d, x, y, w, h, hole):
    """The menus' V bites out of a frame's outer edge."""
    for bx in (x + w // 3, x + 2 * w // 3):
        for k in range(3):
            d.line([bx - 2 + k, y + k, bx + 2 - k, y + k], fill=hole)
    for by in (y + h // 2,):
        for k in range(3):
            d.line([x + k, by - 2 + k, x + k, by + 2 - k], fill=hole)


class Words:
    def __init__(self):
        self.jobs = []

    def at(self, x, y, text, size, col, anchor="la"):
        self.jobs.append((x, y, text, size, col, anchor))

    def draw(self, img, ox, oy):
        d = ImageDraw.Draw(img)
        for x, y, text, size, col, anchor in self.jobs:
            f = ImageFont.truetype(FONT, size)
            d.text((ox + x * SCALE, oy + y * SCALE), text, font=f, fill=col, anchor=anchor)


def option_a():
    """The case itself: the open lid's lining is the face, the platter on the left."""
    im = Image.new("RGB", (W, H), (40, 30, 34))
    d = ImageDraw.Draw(im)
    w = Words()
    rect(d, 4, 6, 192, 128, WALNUT, OUT)
    rect(d, 5, 7, 190, 2, WALNUT_HI)
    rect(d, 10, 12, 180, 116, LID_LO, OUT)
    rect(d, 11, 13, 178, 1, LID)
    bites(d, 4, 6, 192, 128, (40, 30, 34))
    # platter
    rect(d, 16, 20, 72, 72, WALNUT_LO, OUT)
    disc(d, 52, 56, 31, "", 0.9)
    d.line([80, 24, 80, 50], fill=CREAM)
    d.line([80, 50, 68, 60], fill=CREAM)
    rect(d, 66, 59, 4, 3, AMBER)
    rect(d, 77, 21, 6, 6, AMBER_LO, OUT)
    # now playing plate + skip
    rect(d, 16, 98, 72, 24, WALNUT, OUT)
    rect(d, 17, 99, 70, 1, WALNUT_HI)
    w.at(20, 101, "NOW PLAYING", 13, AMBER_HI)
    w.at(20, 108, "Save ME", 20, CREAM)
    rect(d, 74, 102, 11, 11, AMBER, OUT)
    d.polygon([(77, 104), (81, 107.5), (77, 111)], fill=OUT)
    d.line([82, 104, 82, 111], fill=OUT)
    # two columns of rows, then the sync switch centred under them
    w.at(98, 18, "SONG", 15, AMBER_HI)
    w.at(146, 18, "LAKE", 15, AMBER_HI, "ma")
    w.at(173, 18, "SHED", 15, AMBER_HI, "ma")
    for i, s in enumerate(SONGS):
        y = 26 + i * 15
        rect(d, 96, y, 88, 13, LID if i % 2 else LID_LO, None)
        locked = i == 4
        w.at(99, y + 3, s, 15, (170, 140, 140) if locked else CREAM)
        shed = LAKE[i] if SYNC_ON else SHED[i]
        if locked:
            lock(d, 143, y + 3, (170, 140, 140))
            lock(d, 170, y + 3, (170, 140, 140))
        else:
            tick(d, 143, y + 3, LAKE[i], WALNUT_LO, OUT, AMBER_HI)
            tick(d, 170, y + 3, shed, LID_LO if SYNC_ON else WALNUT_LO, OUT,
                 (150, 110, 100) if SYNC_ON else AMBER_HI)
    x, y = 116, 104
    rect(d, x, y, 48, 16, WALNUT, OUT)
    rect(d, x + 1, y + 1, 46, 1, WALNUT_HI)
    w.at(x + 14, y + 5, "SYNC", 15, CREAM, "ma")
    rect(d, x + 27, y + 4, 17, 8, OUT)
    knob = x + 36 if SYNC_ON else x + 28
    rect(d, x + 28, y + 5, 15, 6, AMBER_LO if SYNC_ON else WALNUT_LO)
    rect(d, knob, y + 5, 7, 6, AMBER_HI if SYNC_ON else LID)
    return im, w


def option_b():
    """The crate beside it: each song a sleeve standing in walnut, pulled up = ticked."""
    im = Image.new("RGB", (W, H), (40, 30, 34))
    d = ImageDraw.Draw(im)
    w = Words()
    rect(d, 4, 6, 192, 128, PAPER, OUT)
    rect(d, 4, 6, 192, 16, WALNUT, OUT)
    rect(d, 5, 7, 190, 1, WALNUT_HI)
    bites(d, 4, 6, 192, 128, (40, 30, 34))
    w.at(100, 9, "RECORD PLAYER", 20, CREAM, "ma")
    # divider tabs as the mode
    for i, name in enumerate(["LAKE", "SHED", "SYNC"]):
        x = 14 + i * 34
        on = i == 1
        rect(d, x, 28 if on else 30, 32, 12, AMBER if on else PAPER_EDGE, OUT)
        w.at(x + 16, (31 if on else 33), name, 15, OUT if on else INK, "ma")
    # the crate
    rect(d, 10, 40, 110, 88, WALNUT, OUT)
    rect(d, 11, 41, 108, 1, WALNUT_HI)
    sleeves = [PINK, AMBER_LO, (70, 90, 110), (90, 110, 70), (60, 50, 55)]
    for i, s in enumerate(SONGS):
        up = SHED[i]
        x = 16 + i * 20
        top = 52 if up else 66
        c = sleeves[i]
        rect(d, x, top, 18, 58, c, OUT)
        rect(d, x + 1, top + 1, 1, 56, tuple(min(255, v + 40) for v in c))
        if i == 4:
            lock(d, x + 6, top + 6, CREAM)
        w.at(x + 9, top + 18, s[:5].upper(), 11, CREAM, "ma")
    rect(d, 10, 100, 110, 28, WALNUT_LO, OUT)
    rect(d, 11, 101, 108, 1, WALNUT)
    w.at(65, 110, "PULL A SLEEVE UP TO PLAY IT", 11, AMBER_HI, "ma")
    # the disc sliding out of its sleeve
    rect(d, 128, 40, 60, 60, PINK, OUT)
    disc(d, 172, 70, 24, "", 2.2)
    rect(d, 128, 40, 30, 60, PINK, OUT)
    rect(d, 129, 41, 1, 58, (180, 90, 110))
    w.at(158, 105, "NOW PLAYING", 13, HEAD, "ma")
    w.at(158, 112, "Indie Boi", 19, INK, "ma")
    rect(d, 176, 118, 12, 10, AMBER, OUT)
    d.polygon([(179, 120), (183, 123), (179, 126)], fill=OUT)
    d.line([184, 120, 184, 126], fill=OUT)
    return im, w


def option_c():
    """A paper sleeve with its liner notes: tracklist written up, ticked by hand."""
    im = Image.new("RGB", (W, H), (40, 30, 34))
    d = ImageDraw.Draw(im)
    w = Words()
    rect(d, 4, 6, 192, 128, WALNUT, OUT)
    rect(d, 5, 7, 190, 1, WALNUT_HI)
    bites(d, 4, 6, 192, 128, (40, 30, 34))
    # disc half out of the top of a paper sleeve
    disc(d, 58, 46, 34, "", 4.0)
    rect(d, 12, 58, 176, 70, PAPER, OUT)
    for x in range(14, 186, 2):
        d.point((x, 59), fill=PAPER_EDGE)
    rect(d, 20, 50, 76, 12, WALNUT_LO, OUT)
    w.at(58, 52, "SIDE A", 15, AMBER_HI, "ma")
    # sync stamp
    d.ellipse([140, 14, 180, 46], outline=AMBER, width=2)
    w.at(160, 22, "SYNC", 16, AMBER, "ma")
    w.at(160, 31, "OFF", 13, AMBER_HI, "ma")
    # tracklist
    w.at(108, 62, "LAKE", 14, HEAD, "ma")
    w.at(134, 62, "SHED", 14, HEAD, "ma")
    for i, s in enumerate(SONGS):
        y = 70 + i * 10
        locked = i == 4
        w.at(18, y, f"{i + 1}. {s}", 15, (150, 130, 100) if locked else INK)
        for k, col in enumerate((LAKE, SHED)):
            x = 104 + k * 26
            if locked:
                lock(d, x + 1, y + 1, (150, 130, 100))
            else:
                d.rectangle([x, y + 1, x + 7, y + 7], outline=INK)
                if col[i]:
                    for p in [(1, 4), (2, 5), (3, 6), (4, 5), (5, 3), (6, 2), (7, 1), (8, 0)]:
                        d.point((x + p[0], y + p[1]), fill=HEAD)
    d.line([160, 66, 160, 122], fill=PAPER_EDGE)
    w.at(174, 70, "NOW", 13, HEAD, "ma")
    w.at(174, 77, "Goin", 16, INK, "ma")
    rect(d, 167, 90, 14, 12, AMBER, OUT)
    d.polygon([(170, 92), (175, 96), (170, 100)], fill=OUT)
    d.line([176, 92, 176, 100], fill=OUT)
    return im, w


def option_d():
    """A jukebox dial: walnut cabinet, amber lit panel, a lever for the mode."""
    im = Image.new("RGB", (W, H), (40, 30, 34))
    d = ImageDraw.Draw(im)
    w = Words()
    rect(d, 4, 6, 192, 128, WALNUT, OUT)
    d.pieslice([4, 0, 196, 60], 180, 360, fill=WALNUT, outline=OUT)
    rect(d, 5, 30, 190, 1, WALNUT_HI)
    bites(d, 4, 6, 192, 128, (40, 30, 34))
    # the lit arch with the spinning record in it
    d.pieslice([30, 6, 170, 76], 180, 360, fill=(70, 30, 20), outline=OUT)
    for r in range(3):
        d.arc([34 + r * 4, 10 + r * 4, 166 - r * 4, 72 - r * 4], 180, 360,
              fill=[AMBER, AMBER_HI, AMBER_LO][r])
    disc(d, 100, 38, 20, "", 5.2)
    rect(d, 60, 44, 80, 12, OUT)
    w.at(100, 46, "~ Save ME ~", 15, AMBER_HI, "ma")
    # song buttons, lit when ticked, for the side the lever says
    for i, s in enumerate(SONGS):
        y = 62 + i * 13
        on = LAKE[i]
        locked = i == 4
        rect(d, 14, y, 120, 11, AMBER if on else WALNUT_LO, OUT)
        rect(d, 15, y + 1, 118, 1, AMBER_HI if on else WALNUT)
        rect(d, 16, y + 2, 10, 7, OUT)
        w.at(21, y + 3, "ABCDE"[i], 13, AMBER_HI, "ma")
        w.at(30, y + 2, s, 16, (140, 110, 100) if locked else (OUT if on else CREAM))
        if locked:
            lock(d, 124, y + 2, (140, 110, 100))
    # lever
    rect(d, 142, 62, 44, 64, WALNUT_LO, OUT)
    for i, name in enumerate(["LAKE", "SHED", "SYNC"]):
        w.at(170, 66 + i * 14, name, 13, AMBER_HI if i == 0 else CREAM)
        d.point((166, 69 + i * 14), fill=AMBER)
    d.line([150, 100, 164, 69], fill=CREAM, width=2)
    d.ellipse([160, 65, 168, 73], fill=AMBER, outline=OUT)
    rect(d, 148, 112, 32, 10, AMBER, OUT)
    w.at(164, 114, "SKIP >", 12, OUT, "ma")
    return im, w


def main():
    global SYNC_ON
    pw, ph = W * SCALE, H * SCALE
    gap, title = 24, 40
    sheet = Image.new("RGB", (gap + 2 * (pw + gap), gap + ph + title + gap), (24, 18, 20))
    head = ImageFont.truetype(FONT, 22)
    sd = ImageDraw.Draw(sheet)
    for n, name in enumerate(["A  Sync off", "A  Sync on: shed follows the lake"]):
        SYNC_ON = n == 1
        im, words = option_a()
        ox = gap + n * (pw + gap)
        sd.text((ox, gap), name, font=head, fill=CREAM)
        sheet.paste(im.resize((pw, ph), Image.NEAREST), (ox, gap + title))
        words.draw(sheet, ox, gap + title)
    sheet.save("tools/last_record_menu_mockup.png")
    print(sheet.size)


if __name__ == "__main__":
    main()

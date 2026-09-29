"""Mockup of the angler's shed poses (sit, lie, read), for Richard to judge before any game code.

Rules first, polish after: every pose is cut and re-laid from the idle frames in
`art_source/character_extracted/`, the way `build_pet_frames.py` builds the reach. Laid on the
real furniture from `assets/decor_clean.png` at the shed's own ratio: furniture at 4 screen px a
painted px, the angler and the dog at 3 (zoom 2 in the room: furniture 2x, `YOU_TALL` draws the
43 px figure at 1.5x). Writes `tools/last_pose_mockup.png`. Nothing in the game reads it.

Run with the psd-extract venv python from the project root:
    python tools/build_pose_mockup.py
"""
from PIL import Image, ImageDraw

CHAR = "art_source/character_extracted/%s.png"
FURN = 4
MAN = 3
INK = (0, 0, 0, 255)

# Clean views on decor_clean.png, as pieces.json lists them.
SOFA = {"front": (52, 200, 49, 31), "side": (94, 2, 22, 55), "back": (22, 264, 49, 25)}
ARM = {"front": (129, 162, 32, 32), "side": (2, 162, 23, 36), "back": (2, 234, 32, 28)}
CHAIR = {"front": (198, 234, 16, 27), "side": (36, 234, 15, 28), "back": (136, 292, 16, 21)}
BED = (199, 162, 23, 32)
BOOKCASE = (36, 67, 46, 47)

decor = Image.open("assets/decor_clean.png").convert("RGBA")
dog_sheet = Image.open("assets/dogs/dog_22.png").convert("RGBA")


def piece(box, flip=False, scale=1.0):
    x, y, w, h = box
    im = decor.crop((x, y, x + w, y + h))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    k = round(FURN * scale)
    return im.resize((w * k, h * k), Image.NEAREST)


def idle(direction, frame=0):
    strip = Image.open(CHAR % ("idle_" + direction)).convert("RGBA")
    cell = strip.width / 9
    im = strip.crop((round(cell * frame), 0, round(cell * (frame + 1)), strip.height))
    return im.crop(im.getchannel("A").getbbox())


def rows_cut(im, start, count):
    """The figure with `count` rows from `start` taken out, the rest closed up."""
    top = im.crop((0, 0, im.width, start))
    bottom = im.crop((0, start + count, im.width, im.height))
    out = Image.new("RGBA", (im.width, im.height - count), (0, 0, 0, 0))
    out.alpha_composite(top, (0, 0))
    out.alpha_composite(bottom, (0, start))
    return out


def rect(im, box, colour, outline=True):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(im)
    d.rectangle((x0, y0, x1, y1), fill=colour)
    if outline:
        d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), outline=INK)
        d.rectangle((x0, y0, x1, y1), fill=colour)


def outlined(im):
    """One pixel of ink round every opaque pixel the ink does not already cover."""
    out = im.copy()
    a = im.getchannel("A")
    for y in range(im.height):
        for x in range(im.width):
            if a.getpixel((x, y)) >= 128:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < im.width and 0 <= n[1] < im.height and a.getpixel(n) >= 128:
                    out.putpixel((x, y), INK)
                    break
    return out


def chest_breath(im, top, bottom, middle):
    """A breath in on the chest, not the head: the rows from `top` to `bottom` (the shoulders
    and the shirt) open a pixel either side of `middle`, arms going out with them, and the
    head above and the legs below stay where they were. The figure is padded a pixel each
    side first so nothing is pushed off its canvas; the rest frame is padded the same."""
    out = Image.new("RGBA", (im.width + 2, im.height), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 0))
    if top is None:
        return out
    src = out.copy()
    m = middle + 1
    for y in range(top, bottom + 1):
        for x in range(out.width):
            out.putpixel((x, y), (0, 0, 0, 0))
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3] == 0:
                continue
            if x < m:
                out.putpixel((x - 1, y), p)
            else:
                out.putpixel((x + 1, y), p)
        # The two middle columns fill the gap the split left.
        for x in (m - 1, m):
            p = src.getpixel((x, y))
            if p[3]:
                out.putpixel((x, y), p)
    return out


def sit_front(breathe=0):
    """Facing the camera: the thighs come towards us, so three rows of leg go and the boots
    rest on the cushion's edge. The breath opens the chest (`chest_breath`). Returns (figure,
    hip row)."""
    im = rows_cut(idle("south"), 35, 3)
    im = chest_breath(im, 21, 29, 16) if breathe else chest_breath(im, None, None, None)
    return im, 33


def sit_back(breathe=0):
    """Back to the camera: three rows of leg out, the piece in front hides what is left."""
    im = rows_cut(idle("north"), 32, 3)
    im = chest_breath(im, 19, 28, 14) if breathe else chest_breath(im, None, None, None)
    return im, 30


# The books off the shelf: a cover colour, its spine's shade, and what is on the cover. One is
# picked each time the player reads (`ShedRoom._read_book`), so the room's books are several.
COVERS = [
    ((140, 40, 36, 255), (96, 26, 24, 255), "band"),
    ((44, 62, 120, 255), (28, 38, 80, 255), "emblem"),
    ((46, 104, 60, 255), (28, 68, 38, 255), "stripes"),
    ((110, 70, 40, 255), (72, 44, 24, 255), "corners"),
    ((96, 50, 110, 255), (62, 30, 74, 255), "band"),
]
GOLD = (214, 172, 80, 255)
CREAM = (236, 222, 184, 255)


def book_reader(page=0, cover=0):
    """Facing the camera with both hands on a book held up to read: its cover faces us, the
    pages face him. Both hanging arms come off (the basket's and the free one), so the arms
    are the bent pair holding the book and nothing else."""
    im = idle("south").copy()
    a = im.getchannel("A")
    for y in range(21, im.height):
        for x in range(im.width):
            if (x <= 8 and y >= 21) or (x >= 25 and y <= 34):
                im.putpixel((x, y), (0, 0, 0, 0))
    for y in range(21, 35):
        for x in (9, 24):
            if a.getpixel((x, y)) >= 128:
                im.putpixel((x, y), INK)
    d = ImageDraw.Draw(im)
    # Sleeves bent in from the shoulders.
    rect(im, (8, 22, 10, 26), (236, 218, 177, 255))
    rect(im, (23, 22, 25, 26), (236, 218, 177, 255))
    # The back cover, a spine down its left, and the cover's own mark.
    colour, spine, mark = COVERS[cover % len(COVERS)]
    rect(im, (10, 20, 22, 28), colour)
    d.line((11, 20, 11, 28), fill=spine)
    if mark == "band":
        d.rectangle((14, 22, 20, 22), fill=GOLD)
    elif mark == "emblem":
        d.rectangle((16, 23, 17, 24), fill=GOLD)
        d.point((15, 24), fill=GOLD)
        d.point((18, 23), fill=GOLD)
    elif mark == "stripes":
        d.line((13, 22, 21, 22), fill=CREAM)
        d.line((13, 26, 21, 26), fill=CREAM)
    elif mark == "corners":
        for x, y in ((13, 21), (21, 21), (13, 27), (21, 27)):
            d.point((x, y), fill=GOLD)
        d.rectangle((16, 23, 18, 25), outline=GOLD)
    # The pages' edges showing along the top.
    d.line((12, 20, 21, 20), fill=(246, 236, 210, 255))
    if page:
        # A page flipping over the top edge.
        d.polygon([(16, 20), (19, 16), (21, 17), (21, 20)], fill=(252, 246, 228, 255),
                  outline=INK)
    # Fists on the cover's sides.
    rect(im, (8, 24, 10, 26), (243, 166, 119, 255))
    rect(im, (22, 24, 24, 26), (243, 166, 119, 255))
    return im


def reach_up():
    """The pet reach from behind, as it is: no new frames for the shelf."""
    strip = Image.open(CHAR % "pet3_north").convert("RGBA")
    cell = strip.width / 6
    im = strip.crop((round(cell * 2), 0, round(cell * 3), strip.height))
    return im.crop(im.getchannel("A").getbbox())


def basket():
    im = idle("south").crop((0, 31, 10, 42))
    return im


def lying():
    """Head on the pillow, the blanket over the rest (bed art is front-on, headboard up)."""
    return idle("south").crop((0, 0, 32, 16))


def big(im, k=MAN):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def dog(seq, frame=0, flip=False):
    import json

    data = json.load(open("assets/dogs/dog_22.json"))
    x, y, w, h = data["sequences"][seq][frame]["region"]
    im = dog_sheet.crop((x, y, x + w, y + h))
    return big(im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im)


def main():
    # ---- the sheet ------------------------------------------------------------------------------

    CELL_W, CELL_H = 330, 300
    FLOOR = (164, 118, 78, 255)
    BG = (52, 44, 50, 255)
    cells = []


    def cell(title, draw):
        im = Image.new("RGBA", (CELL_W, CELL_H), BG)
        ImageDraw.Draw(im).rectangle((8, 40, CELL_W - 9, CELL_H - 9), fill=FLOOR)
        draw(im)
        ImageDraw.Draw(im).text((10, 12), title, fill=(240, 230, 200, 255))
        cells.append(im)


    def shade_on(im, f, fx, fy, gx, gy, g, hip):
        """The sitter's own silhouette pressed into the cushion: the figure's shape moved one art
        pixel right and two down, darkened, clipped to the piece and to the rows below the chest,
        so it hugs the body and reads as the cushion giving under him."""
        sil = Image.new("L", im.size, 0)
        sil.paste(g.getchannel("A").point(lambda a: 150 if a >= 128 else 0),
                  (gx + 2 * MAN, gy + MAN))
        top = gy + (hip - 18) * MAN
        sil.paste(0, (0, 0, im.width, max(0, top)))
        mask = Image.new("L", im.size, 0)
        mask.paste(f.getchannel("A"), (fx, fy))
        layer = Image.new("RGBA", im.size, (36, 22, 18, 255))
        layer.putalpha(Image.composite(sil, Image.new("L", im.size, 0), mask))
        im.alpha_composite(layer)


    def seat_scene(furn_box, pose, seat_up, flip=False, over=False, x_off=0, extra=None,
                   shade=False, cover=False):
        def draw(im):
            f = piece(furn_box, flip)
            fx = (CELL_W - f.width) // 2
            fy = CELL_H - 30 - f.height
            fig, hip = pose
            if flip:
                fig = fig.transpose(Image.FLIP_LEFT_RIGHT)
            g = big(fig)
            gx = CELL_W // 2 - g.width // 2 + x_off
            gy = fy + f.height - seat_up * FURN - hip * MAN
            if over:
                im.alpha_composite(g, (gx, gy))
                im.alpha_composite(f, (fx, fy))
            else:
                im.alpha_composite(f, (fx, fy))
                if shade:
                    shade_on(im, f, fx, fy, gx, gy, g, hip)
                im.alpha_composite(g, (gx, gy))
                if cover:
                    # The piece again from the hips down, over him: the near arm and the seat's
                    # front hide his legs.
                    cut = gy + hip * MAN - fy
                    im.alpha_composite(f.crop((0, cut, f.width, f.height)), (fx, fy + cut))
            if extra:
                extra(im, fx, fy, f)
        return draw


    # The seat heights are where the hips sit, in painted px up from the art's bottom edge,
    # picked by eye here: they are what the game will author per view (`sit` beside `seat`).
    cell("sofa front: sit", seat_scene(SOFA["front"], sit_front(), 12, x_off=-40, shade=True))
    cell("sofa front: breathe", seat_scene(SOFA["front"], sit_front(1), 12, x_off=-40, shade=True))
    cell("sofa back: head over rest", seat_scene(SOFA["back"], sit_back(), 10, over=True))

    cell("armchair front", seat_scene(ARM["front"], sit_front(), 13, shade=True))
    cell("armchair back", seat_scene(ARM["back"], sit_back(), 11, over=True))
    cell("dining chair front", seat_scene(CHAIR["front"], sit_front(), 12, shade=True))

    cell("dining chair back", seat_scene(CHAIR["back"], sit_back(), 10, over=True))


    def share(im, fx, fy, f):
        d = dog("laid", 0, flip=True)
        im.alpha_composite(d, (fx + f.width // 2 - 24, fy + f.height - 14 * FURN - d.height + 30))


    cell("sofa shared with a dog", seat_scene(SOFA["front"], sit_front(), 12, x_off=-45,
                                              extra=share, shade=True))


    def bed_scene(zz=False, dog_at_foot=False):
        def draw(im):
            f = piece(BED, scale=1.5)
            fx = (CELL_W - f.width) // 2
            fy = CELL_H - 20 - f.height
            im.alpha_composite(f, (fx, fy))
            head = big(lying())
            im.alpha_composite(head, (CELL_W // 2 - head.width // 2, fy + 8))
            # The body under the blanket: a darker ridge down the green.
            d = ImageDraw.Draw(im)
            cx = CELL_W // 2
            d.line((cx - 26, fy + 72, cx - 26, fy + f.height - 60), fill=(92, 112, 52, 255), width=3)
            d.line((cx + 26, fy + 72, cx + 26, fy + f.height - 60), fill=(92, 112, 52, 255), width=3)
            d.rectangle((cx - 30, fy + 66, cx + 30, fy + 71), fill=(150, 170, 90, 255))
            if zz:
                for i, (dx, dy, s) in enumerate(((50, 0, 10), (66, -18, 14), (86, -40, 18))):
                    x, y = cx + dx, fy + 20 + dy
                    d.line((x, y, x + s, y), fill=(255, 255, 255, 255), width=3)
                    d.line((x + s, y, x, y + s), fill=(255, 255, 255, 255), width=3)
                    d.line((x, y + s, x + s, y + s), fill=(255, 255, 255, 255), width=3)
            if dog_at_foot:
                dd = dog("sleep", 0)
                im.alpha_composite(dd, (cx - dd.width // 2 + 20, fy + f.height // 2 - dd.height // 2 + 10))
        return draw


    cell("bed: lying", bed_scene())
    cell("bed: asleep (Zz), dog at foot", bed_scene(zz=True, dog_at_foot=True))


    def shelf_scene(stage):
        def draw(im):
            f = piece(BOOKCASE)
            fx = (CELL_W - f.width) // 2
            fy = 50
            im.alpha_composite(f, (fx, fy))
            if stage == "reach":
                g = big(reach_up())
                im.alpha_composite(g, (CELL_W // 2 - g.width // 2 - 20, fy + f.height - 70))
            else:
                g = big(book_reader(1 if stage == "page" else 0))
                gx = CELL_W // 2 - g.width // 2
                gy = CELL_H - 14 - g.height
                im.alpha_composite(g, (gx, gy))
        return draw


    cell("bookcase: reach for a book", shelf_scene("reach"))
    cell("bookcase: read", shelf_scene("read"))
    cell("bookcase: page turn", shelf_scene("page"))

    COLS = 4
    rows = (len(cells) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (CELL_W * COLS + 10 * (COLS + 1), CELL_H * rows + 10 * (rows + 1)),
                      (30, 26, 30, 255))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, (10 + (i % COLS) * (CELL_W + 10), 10 + (i // COLS) * (CELL_H + 10)))
    sheet.save("tools/last_pose_mockup.png")
    print("wrote", len(cells), "cells")


if __name__ == "__main__":
    main()

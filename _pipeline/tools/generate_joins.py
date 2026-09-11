"""Generate the grass/sand join tiles the Forest Isometric pack is missing, for Lake Cleanup.

Why this exists
---------------
`Ground` fits the lawn to the beach with the pack's join tiles: grass cubes whose top face is
sand along the sides that face sand. The pack's set is a corner set with a gap in it. It has
sand along the back two sides (NW+NE, slice 27), the right two (NE+SE, 30), the left two
(NW+SW, 16 and 26), and three of the four three-side pieces (4, 5, 17) -- but nothing with
sand along the front two sides (SE+SW), and no three-side piece leaving grass only on the NE.
On a lake the lawn surrounds, the front-side case is the whole top stretch of shore.

Nothing here is drawn. Each missing piece is a pack tile's own top face flipped or mirrored
onto a plain grass cube's sides:

  join_sesw     sand SE+SW      slice 27's face flipped top-to-bottom, on slice 1's cube
  join_nwsesw   sand NW+SE+SW   slice 5's face mirrored left-to-right, on slice 1's cube

Only the face rows are flipped. The cube's two side faces are lit differently and would swap
their shading if the whole picture were mirrored, so they come from the plain grass tile and
the face is laid over them. The face is flat-lit, so turning it is safe.

Deterministic; re-running overwrites in place.

Needs Pillow:  python -m pip install Pillow
Run from anywhere:  python _pipeline/tools/generate_joins.py
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PACK = os.path.join(ROOT, "Lake Cleanup", "assets", "Forest Isometric Pack Free", "Tileset")
OUT = os.path.join(ROOT, "Lake Cleanup", "assets", "joins")

# The plain grass cube whose sides every generated piece stands on.
BASE = 1

# The top face is this many rows tall, starting at the picture's first opaque row.
FACE = 16

# (output name, source slice, flip top-to-bottom, mirror left-to-right)
PIECES = (
    ("join_sesw", 27, True, False),
    ("join_nwsesw", 5, False, True),
)


def _load(slice_no):
    return Image.open(os.path.join(PACK, "Slice %d.png" % slice_no)).convert("RGBA")


def _top_of(img):
    """The first row with anything in it -- the same measure `Ground._top_of` takes."""
    px = img.load()
    for y in range(img.height):
        if any(px[x, y][3] > 127 for x in range(img.width)):
            return y
    raise ValueError("empty tile")


def _is_sand(rgba):
    """Sand in this pack is warm, every grass is not. Same rule `tools/tile_edges.gd` uses."""
    r, g, b, a = rgba
    return a > 127 and r > g


def _face_rows(img):
    """The top face's rows only: from the first opaque row, FACE rows down."""
    top = _top_of(img)
    return top, img.crop((0, top, img.width, top + FACE))


def _compose(source_no, flip, mirror):
    base = _load(BASE)
    src = _load(source_no)
    base_top, _ = _face_rows(base)
    _, face = _face_rows(src)
    if flip:
        face = face.transpose(Image.FLIP_TOP_BOTTOM)
    if mirror:
        face = face.transpose(Image.FLIP_LEFT_RIGHT)

    out = base.copy()
    op = out.load()
    fp = face.load()
    # Only the sand comes across. The grass on the source face stays the base's own, so the
    # piece's turf matches the tile beside it rather than the source's.
    for y in range(FACE):
        for x in range(face.width):
            if _is_sand(fp[x, y]):
                op[x, base_top + y] = fp[x, y]
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, source_no, flip, mirror in PIECES:
        path = os.path.join(OUT, name + ".png")
        _compose(source_no, flip, mirror).save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()

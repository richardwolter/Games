#!/usr/bin/env python
"""The hive room's harvest kit: the oak honey bucket, the oak V-flume, the hot knife, the hive-stack
bottling stand, the fence shelf, the brass tap and its lever, the prize rosette.

2026-10-18, the hive's visual overhaul. Richard's picks: option B of the uncap sheet
(tools/hive_look/last_uncap.png, "OAK HONEY BUCKET under an oak V-flume") and option B of the pour
sheet (tools/hive_look/last_pour.png, "HIVE STACK, FENCE SHELF, ROSETTE") with the uncap's oak
bucket carried to the bottling stand, so one bucket family runs through both steps. **Every
piece here is the mockups' own drawing, called, not copied** (tools/hive_look/uncap_mockup.py,
pour_art.py, look.py): change a piece there and run this again. tools/hive_look is git-ignored,
like the bee sheet's source (tools/build_bees.py reads the same look.py).

Writes assets/hive_kitchen.png and assets/hive_kitchen.json, read by scripts/hive_kitchen_art.gd,
then reimport the project. Run from the project root with the base python and the psd-extract
venv's packages (App Control blocks the venv's own python.exe):

    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/build_hive_kitchen.py

Everything is at one painted pixel (the room's art grid, 640 x 360, HiveArt.PIXEL canvas px a
painted px). What is on the sheet:

    the bucket family, every piece cut from one canvas and anchored on the bucket's `foot`, so
    pieces drawn at the same foot stack:
      bucket            the uncap's bucket, its little brass tap shut low on the front
      bucket_open       the pour's: the same bucket with the tap left off (the gate goes on)
      bucket_rope       the rope handle laid back over the mouth, drawn BEHIND the body
      bucket_front      the near wall alone, drawn over what falls into the bucket
      bucket_open_front the same for the open bucket
      pool1..poolN      the honey inside at level k/N (pour_art.bucket_honey, no tide mark)
      pool_scraped      the bucket scraped out: runs down the far wall and a puddle
      tide1..tideN      the dotted film where the honey stood at level k/N, drawn under a pool
    the uncap:
      flume_back        the rope hangers behind, the back board's lit arris and inner face down
                        to the dark crease, the high end's inside (world-placed, `at` its top left)
      flume_front       the front board, its nails, butt joints, the low end's end grain, the
                        rope round under the keel and the knots round the frame's foot
      knife             the hot uncapping knife: anchors blade_l, blade_r (the top steel row),
                        handle
      wax_curl          the capping peeling up off the blade's tip: anchor root
    the pour:
      stand             the bottling stand built as a hive (world-placed)
      bench             the fence shelf the finished jars go to (world-placed)
      gate              the brass barrel tap: anchors top, pivot, spout
      lever0..leverN    the lever off the pivot at turn json["lever_turns"][k]: anchors pivot, grip
      lever_cue         shut, asking to be held (a glint on the knob, wobble ticks)
      rosette           the prize rosette with the crown on its boss: anchor boss
      bead              a drop of honey off the shut spout: anchor top

The json also carries the geometry the steps draw the moving honey on (the flume's line and
profile, the bucket's mouth and the honey's surface for every level) and the colours the code
draws with, as the builder's own 0-255 figures.
"""
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "hive_look"))
import look  # noqa: E402
import pour_art as pa  # noqa: E402
import uncap_mockup as um  # noqa: E402

OUT_PNG = os.path.join(ROOT, "assets", "hive_kitchen.png")
OUT_JSON = os.path.join(ROOT, "assets", "hive_kitchen.json")
W, H = 640, 380
GAP = 1
SHEET_W = 1024
POOL_LEVELS = 24
# The lever's turns: a little past shut (the spring's overshoot) to a quarter turn open.
LEVER_TURNS = [round(-0.2 + 0.1 * k, 2) for k in range(13)]
CLEAR = (0, 0, 0, 0)

# The pour's layout, the mockup's (pour_mockup.py STAND_X ... SLOTS), option B.
STAND_X, STAND_W = 202, 100
TOP_FACE = 219
STAND_TOP = TOP_FACE - 2
SHELF = 282
STAND_FEET = 296
BUCKET_SHIFT = -6
WAIT_GAP = 34
BENCH_X, BENCH_W = 326, 116
BENCH_TOP = 262
BENCH_FEET = 294
SLOTS = (20, 58, 96)


def bbox(im):
    return im.getchannel("A").getbbox()


class Book:
    """The pieces as they are cut: each its image and anchors in that image's own pixels."""

    def __init__(self):
        self.pieces = {}

    def add(self, name, im, anchors, at=None):
        """`im` with `anchors` in its pixels; cropped to what is opaque, anchors moved with it.
        `at`, when given, is where the image's (0, 0) stands on the room's art grid, and the
        cropped piece's top left there is recorded as its `at`."""
        box = bbox(im)
        if box is None:
            return False
        crop = im.crop(box)
        moved = {k: [v[0] - box[0], v[1] - box[1]] for k, v in anchors.items()}
        entry = {"im": crop, "anchors": moved}
        if at is not None:
            entry["at"] = [at[0] + box[0], at[1] + box[1]]
        self.pieces[name] = entry
        return True


def _num(v):
    return round(float(v), 3)


# =============================================================================================
# The bucket family
# =============================================================================================
PAD = 8


def bucket_family(book):
    """Both buckets, the rope, the near walls and the honey's level ladder on one canvas."""
    shut = um.oak_bucket()
    opened = pa.bucket("B")
    size = (shut["body"].width + 2 * PAD, shut["body"].height + 2 * PAD)
    mouth = (shut["mouth"][0] + PAD, shut["mouth"][1] + PAD)
    foot = (shut["foot"][0] + PAD, shut["foot"][1] + PAD)
    inner = shut["inner"]
    taper = opened["taper"]
    anchors = {"foot": foot, "mouth": mouth}

    def canvas(im, dx=0, dy=0):
        c = Image.new("RGBA", size, CLEAR)
        c.alpha_composite(im, (PAD + dx, PAD + dy))
        return c

    book.add("bucket", canvas(shut["body"]), anchors)
    book.add("bucket_front", canvas(shut["front"]), anchors)
    book.add("bucket_rope", canvas(shut["bail"], -1, -1), anchors)
    book.add("bucket_open", canvas(opened["body"]), anchors)
    book.add("bucket_open_front", canvas(opened["front"]), anchors)

    surfaces = [None]
    for k in range(1, POOL_LEVELS + 1):
        level = k / float(POOL_LEVELS)
        s = pa.Spr(*size)
        pa.bucket_honey(s, mouth, inner, level, taper, was=level)
        book.add("pool%d" % k, s.im, anchors)
        cx, cy, sx, sy = pa._honey_geometry(mouth, inner, taper, level)
        surfaces.append([_num(cx - foot[0]), _num(cy - foot[1]), _num(sx), _num(sy)])
        # The tide mark for a honey that stood at this level: drawn with almost nothing left,
        # then the little surface taken off again, so only the film is kept.
        t = pa.Spr(*size)
        pa.bucket_honey(t, mouth, inner, 0.07, taper, was=level)
        u = pa.Spr(*size)
        pa.bucket_honey(u, mouth, inner, 0.07, taper, was=0.07)
        tp, up = t.im.load(), u.im.load()
        for y in range(size[1]):
            for x in range(size[0]):
                if up[x, y][3]:
                    tp[x, y] = CLEAR
        book.add("tide%d" % k, t.im, anchors)
    s = pa.Spr(*size)
    pa.bucket_honey(s, mouth, inner, 0.0, taper, was=0.0)
    book.add("pool_scraped", s.im, anchors)
    return {
        "foot_to_mouth": [_num(mouth[0] - foot[0]), _num(mouth[1] - foot[1])],
        "inner": [_num(inner[0]), _num(inner[1])],
        "foot_half": [_num(shut["foot_half"][0]), _num(shut["foot_half"][1])],
        "taper": _num(taper),
        "levels": POOL_LEVELS,
        "surfaces": surfaces,
        "gate_dx": opened["gate_dx"],
    }, shut


# =============================================================================================
# The uncap: the flume, the knife, the wax curl
# =============================================================================================
def flume(book, shut):
    um._STYLE[0] = "B"
    bx, by = um.place_bucket(shut)
    mouth = (shut["mouth"][0] + bx, shut["mouth"][1] + by)
    foot = (shut["foot"][0] + bx, shut["foot"][1] + by)
    land_x = int(round(mouth[0] - shut["inner"][0] * 0.42))
    x1 = land_x - um.END_STREAM["B"][0]
    back = um.Art(W, H)
    um.draw_hangers_back(back, "B")
    um.draw_trough_back(back, "B", x1)
    book.add("flume_back", back.im, {"tl": (0, 0)}, at=(0, 0))
    front = um.Art(W, H)
    um.draw_trough_front(front, "B", x1)
    # The low end's wood (draw_low_end's B without its honey): the outline down the open end,
    # the back board's end grain and the front board's.
    y = um.ty(x1)
    bottom = um.tr_bottom("B")
    for dy in range(um.tr_top("B"), bottom + 1):
        front.px(x1 + 1, y + dy, um.OUT)
    for dy in range(-11, -6):
        front.px(x1, y + dy, um.OAK[5])
    for dy in range(0, bottom):
        front.px(x1, y + dy, um.OAK[5] if dy < 2 else um.OAK[4])
    um.draw_hangers_front(front, "B")
    book.add("flume_front", front.im, {"tl": (0, 0)}, at=(0, 0))
    sx, sy, sw = um.END_STREAM["B"]
    return {
        "g0": list(um.uncap_clean.G0), "g1": list(um.uncap_clean.G1), "drop": um.DROP,
        "x0": um.X0, "x1": x1,
        "hbot": um.TROUGHS["B"]["hbot"], "most": um.TROUGHS["B"]["most"],
        "rim": um.rim_row("B"), "bottom": bottom, "top": um.tr_top("B"),
        "wall_top": um.TROUGHS["B"]["wall"][0][0],
        "lip": [x1 + sx, y + sy], "lip_wide": sw,
        "straps": um.STRAPS,
        "bucket_foot": [int(foot[0]), int(foot[1])],
        "bucket_mouth": [_num(mouth[0]), _num(mouth[1])],
        "land_x": land_x,
    }


def knife(book):
    a = um.Art(W, H)
    loop = um.draw_knife(a)
    um.draw_loop(a, loop)
    um._outline_box(a, um.HEEL - 1, um.BLADE_TOP - 4, um.HEEL + 52, um.BLADE_TOP + 22)
    top = um.BLADE_TOP + 1
    book.add("knife", a.im, {
        "blade_l": (um.BLADE_TIP + 6, top), "blade_r": (um.HEEL, top),
        "handle": (um.HEEL + 7 + 19, um.BLADE_TOP + 4),
    })
    curl = um.wax_curl()
    at = (um.BLADE_TIP - 6, um.BLADE_TOP - 16)
    root = (um.BLADE_TIP + 6 - 3 - at[0], top - 1 - at[1])
    book.add("wax_curl", curl, {"root": root})
    return {"blade_top": top, "glint_at": um.GLINT_AT - (um.BLADE_TIP + 6),
            "sparks": [[x - (um.BLADE_TIP + 6), y - top, n] for (x, y, n) in um.SPARKS]}


# =============================================================================================
# The pour: the stand, the bench, the gate and lever, the rosette
# =============================================================================================
def _shade_box(im, x0, x1, y0, y1, t=0.35):
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] and px[x, y][:3] != pa.OUT[:3]:
                px[x, y] = look.mix(px[x, y], pa.OUT, t)[:3] + (255,)


def pour(book, fam):
    lay = Image.new("RGBA", (W, H), CLEAR)
    st = pa.hive_stand(lay, STAND_X, STAND_W, STAND_TOP, STAND_FEET, SHELF)
    assert st["top_face"] == TOP_FACE, st
    mid = STAND_X + STAND_W // 2 + BUCKET_SHIFT
    half = int(round(fam["foot_half"][0]))
    # the bucket's shadow on the stand's top, down and to the right (pour_mockup's own)
    _shade_box(lay, mid + half + 1, mid + half + 9, TOP_FACE - 2, TOP_FACE)
    book.add("stand", lay, {"tl": (0, 0)}, at=(0, 0))
    jar_feet = st["shelf"] - 1
    blay = Image.new("RGBA", (W, H), CLEAR)
    bc = pa.blue_bench(blay, BENCH_X, BENCH_W, BENCH_TOP, BENCH_FEET)
    book.add("bench", blay, {"tl": (0, 0)}, at=(0, 0))
    bfeet = bc["face"][0] + 3

    gate, ga = pa.honey_gate("tap", pa.BRASS)
    book.add("gate", gate, {k: v for k, v in ga.items()})
    for k, turn in enumerate(LEVER_TURNS):
        im, piv, grip = pa.lever(turn, "B")
        book.add("lever%d" % k, im, {"pivot": piv, "grip": grip})
    im, piv, grip = pa.lever(0.0, "B", cue=True)
    book.add("lever_cue", im, {"pivot": piv, "grip": grip})
    ro, boss = pa.rosette(15)
    book.add("rosette", ro, {"boss": boss})
    b = Image.new("RGBA", (8, 8), CLEAR)
    pa.gate_bead(b, 3, 2)
    book.add("bead", b, {"top": (3, 1)})
    gx = mid + fam["gate_dx"]
    gate_top = TOP_FACE - 13
    return {
        "bucket_foot": [mid, TOP_FACE],
        "gate_top": [gx, gate_top],
        "jar_feet": [gx, jar_feet],
        "wait_feet": [gx - WAIT_GAP, jar_feet],
        "slots": [[BENCH_X + s, bfeet] for s in SLOTS],
        "stand_box": [STAND_X - 4, STAND_TOP, STAND_X + STAND_W + 4, STAND_FEET],
        "bench_box": [BENCH_X, BENCH_TOP - 46, BENCH_X + BENCH_W, BENCH_FEET],
        "entrance": [STAND_X + 84, SHELF - 3],
        "lever_long": pa.LEVER_LONG, "lever_arm": pa.LEVER_ARM,
    }


# =============================================================================================
# The sheet
# =============================================================================================
def colours():
    c = {}
    for i, v in enumerate(um.OAK):
        c["oak%d" % i] = list(v[:3])
    for i, v in enumerate(um.PINE):
        c["pine%d" % i] = list(v[:3])
    for k, v in um.HONEY.items():
        c["honey_" + k] = list(v[:3])
    for k, v in um.HEAT.items():
        c["heat_" + k] = list(v[:3])
    for k, v in um.BRASS.items():
        c["brass_" + k] = list(v[:3])
    c["out"] = list(look.OUT[:3])
    c["glass"] = list(pa.GLASS[:3])
    c["glass_edge"] = list(pa.GLASS_EDGE[:3])
    c["white"] = list(pa.WHITE[:3])
    return c


def pack(book):
    """Shelf-pack the pieces, tallest first, a clear pixel between."""
    names = sorted(book.pieces, key=lambda n: (-book.pieces[n]["im"].height, n))
    x, y, row = GAP, GAP, 0
    spots = {}
    for n in names:
        im = book.pieces[n]["im"]
        if x + im.width + GAP > SHEET_W:
            x = GAP
            y += row + GAP
            row = 0
        spots[n] = (x, y)
        x += im.width + GAP
        row = max(row, im.height)
    sheet = Image.new("RGBA", (SHEET_W, y + row + GAP), CLEAR)
    for n, (sx, sy) in spots.items():
        sheet.alpha_composite(book.pieces[n]["im"], (sx, sy))
    return sheet, spots


def build():
    book = Book()
    fam, shut = bucket_family(book)
    fl = flume(book, shut)
    kn = knife(book)
    po = pour(book, fam)
    sheet, spots = pack(book)
    sheet.save(OUT_PNG)
    pieces = {}
    for n, entry in sorted(book.pieces.items()):
        sx, sy = spots[n]
        im = entry["im"]
        p = {"rect": [sx, sy, im.width, im.height],
             "anchors": {k: [_num(v[0]), _num(v[1])] for k, v in entry["anchors"].items()}}
        if "at" in entry:
            p["at"] = entry["at"]
        pieces[n] = p
    out = {
        "sheet": "res://assets/hive_kitchen.png",
        "pieces": pieces,
        "bucket": fam,
        "uncap": dict(fl, knife=kn),
        "pour": po,
        "lever_turns": LEVER_TURNS,
        "colours": colours(),
    }
    with open(OUT_JSON, "w", newline="\n") as fh:
        json.dump(out, fh, indent=1)
    print("hive_kitchen: %d pieces, sheet %s" % (len(pieces), sheet.size))
    print("flume x0..x1 %d..%d, lip %s, bucket foot %s mouth %s" % (
        fl["x0"], fl["x1"], fl["lip"], fl["bucket_foot"], fl["bucket_mouth"]))
    print("pour: %s" % po)


if __name__ == "__main__":
    build()

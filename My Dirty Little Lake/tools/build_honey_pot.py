#!/usr/bin/env python
"""The honey pot: one jar, drawn at every size the game shows it.

2026-10-18, the hive's visual overhaul. Richard: "make sure to use the same honey pot as the
other scenes". The canonical jar is the bottling jar on the pour sheet's option B
(tools/hive_look/last_pour.png; tools/hive_look/pour_art.py `jar_parts`): pale glass ringed in the
game's outline, lit white down its left, blue-grey down its right, a white streak and a shoulder
glint; honey in the hive's five-step ramp with a shine on its surface; a paper label with red
rules and a red honeycomb cell holding a drop of honey; a gingham cloth lid (red, pink, white
checks, a zigzag hem) tied round the neck with oak twine.

**One design, four grains, each its own drawing** (never a scaled copy):

    room   the pour step's jars, the room grain (one painted px = HiveArt.PIXEL 2 canvas px).
           pour_art.jar_parts itself, cut into layers so the step can draw honey between them,
           drop the lid on and stamp the label. 26 x 42, feet on (13, 41).
    hud    the jar plate's jar (honey sheet 1A), one HUD canvas px a px. The same parts drawn by
           `rule_jar` at 14 x 14 of glass: sealed (lid, label, full) and open with a wooden dipper
           standing in it, its honey at every level (the eaten window's hourglass).
    cue    the first-jar card's icon (honey sheet 5B), one icon px a px (CueCard.CELL_HINT 2
           canvas px): sealed, and open with honey heaped out of the mouth and a run down the
           front, the lid tilted off it at three heights of its hop.
    shelf  the island hive's cupboard jar (island sheet option C), one world px a px: 7 x 9, the
           whole design in its fewest pixels (cloth, twine, glint, label with its red cell).

**The rule a sealed jar follows everywhere**: a lid means a label. An open jar (being filled,
being eaten) is bare glass, as on the pour table.

Writes assets/honey_pot.png and assets/honey_pot.json; reimport after. Run from the project root:

    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/build_honey_pot.py

The json:

    {"sheet": "res://assets/honey_pot.png",
     "frames": {"<name>": {"rect": [x, y, w, h], "anchor": [ax, ay], "size": "room"}, ...},
     "sizes":  {"room": {...geometry...}, "hud": {...}, "cue": {...}, "shelf": {...}}}

`anchor` is the jar's feet: the middle of its bottom outline row. Every frame of one size is on one
canvas size with one anchor, so layers stack by drawing them all at the same point.

Frame names (see the json for every one):

    room_back<k>     k = 0..room.levels-1: the glass's back with the honey at level k (0 empty; the surface
                     row of level k is room.surface[k]). Draw first.
    room_mouth       the open jar's mouth seen through its neck (draw over the back, open jars).
    room_front       outline, glass edges, streaks, glint: over the honey.
    room_line        the dashed fill line on the glass (the jar under the gate).
    room_label       the paper label (sealed jars).
    room_lid         the gingham lid with its own outline (sealed jars; drop it in from above).
    room_full        a sealed jar at the line, composed (back, honey, front, label, lid).
    room_empty       the waiting jar: empty, open, composed.
    room_payoff      the finished jar of the payoff: honey a step lighter, the finds' gold rim
                     (one px bigger a side: 28 x 44, feet (14, 42)).
    hud_sealed       lid, label, full.
    hud_open<k>      k = 0..hud.levels-1: lid off, the dipper in it, honey at level k (0 empty).
    cue_sealed       lid, label, full.
    cue_open         the open jar with the honey heaped out of its mouth and a run down the front.
    cue_pop<k>       k = 0..2: cue_open with its lid tilted on top, k icon px up its hop (moved one
                     px right once it is off the heap).
    cue_lid          the tilted lid alone at rest (cue.lid_rest); a consumer animating the hop
                     draws it k px higher, one px right when k > 0.
    shelf            the island jar, full and sealed.
    shelf_shade      the same in the cupboard's shaded face (a fixed mix towards the outline).
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

OUT_PNG = os.path.join(ROOT, "assets", "honey_pot.png")
OUT_JSON = os.path.join(ROOT, "assets", "honey_pot.json")
CLEAR = (0, 0, 0, 0)
GAP = 1

# The swatches: every one the pour jar's own (pour_art), so the four sizes are one jar.
OUT = look.OUT
GLASS, GLASS_EDGE, WHITE = pa.GLASS, pa.GLASS_EDGE, pa.WHITE
EMPTY = GLASS[:3] + (34,)                       # empty glass: the room shows, one faint step
HONEY = pa.HONEY                                # deep, mid, honey, light, shine
GING_R, GING_P, GING_W = pa.GING
PAPER, PAPER_EDGE = pa.PAPER, pa.PAPER_EDGE
TWINE, TWINE_SHADE, TWINE_LIT = pa.OAK[3], pa.OAK[2], pa.OAK[5]
DIP, DIP_SHADE = look.SW["bark_lit"], look.SW["bark"]
SHELF_SHADE = 0.12                              # the cupboard's shaded face (island sheet C)


def _opaque(im):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3]:
                px[x, y] = p[:3] + (255,) if p[3] > 200 else p
    return out


def _diff(over, base):
    """The pixels of `over` that are not `base`'s: the layer that turns base into over."""
    out = Image.new("RGBA", over.size, CLEAR)
    po, pb, pd = over.load(), base.load(), out.load()
    for y in range(over.height):
        for x in range(over.width):
            if po[x, y] != pb[x, y]:
                pd[x, y] = po[x, y]
    return out


def _stack(*layers):
    out = Image.new("RGBA", layers[0].size, CLEAR)
    for l in layers:
        out.alpha_composite(l)
    return out


# =============================================================================================
# room: the pour jar itself, in layers
# =============================================================================================
def room_frames():
    lo, hi = pa.JAR_IN
    levels = hi - lo + 2                        # 0 empty, then one a surface row, bottom up
    surface = [None] + [hi - k + 1 for k in range(1, levels)]

    def fill_of(k):
        # the fill pour_art.jar_surface rounds onto level k's row (0 is empty)
        return 0.0 if k == 0 else max((hi - surface[k]) / float(hi - lo), 1e-3)

    frames = {}
    for k in range(levels):
        b, _ = pa.jar_parts(fill_of(k), lid=True, label=None)
        if k:
            assert pa.jar_surface(fill_of(k)) == surface[k], (k, surface[k])
        frames["room_back%d" % k] = b
    b_open, f_open = pa.jar_parts(0.0, lid=False, label=None)
    b_shut, f_shut = pa.jar_parts(0.0, lid=True, label=None)
    frames["room_mouth"] = _diff(b_open, b_shut)
    frames["room_front"] = f_open
    _, f_line = pa.jar_parts(0.0, lid=False, label=None, line=True)
    frames["room_line"] = _diff(f_line, f_open)
    _, f_lab = pa.jar_parts(0.0, lid=False, label="hex")
    frames["room_label"] = _diff(f_lab, f_open)
    _, f_sealed = pa.jar_parts(0.0, lid=True, label="hex")
    lid = _diff(f_sealed, f_lab)
    frames["room_lid"] = lid
    # the layers have to stack back into the pour sheet's own jar
    assert _stack(f_open, frames["room_label"], lid).tobytes() == \
        _stack(f_lab, lid).tobytes()
    frames["room_full"] = pa.jar(pa.JAR_LINE, lid=True, label="hex")
    frames["room_empty"] = pa.jar(0.0, lid=False, label=None)
    payoff = pa.gold_rim(pa.jar(pa.JAR_LINE, lid=True, label="hex", glow=True))
    geo = {
        "canvas": [pa.JAR_W + 2, pa.JAR_H + 2],
        "feet": list(pa.JAR_FEET),
        "levels": levels,
        "surface": [s + 1 if s is not None else None for s in surface],   # in the ringed canvas
        "honey_rows": [lo + 1, hi + 1],
        "neck": pa.JAR_NECK + 1,
        "line_fill": pa.JAR_LINE,
        "line_row": pa.jar_surface(pa.JAR_LINE) + 1,
        "spans": {str(y + 1): [l + 1, r + 1] for y, (l, r) in pa.JAR_ROWS.items()},
        "grain": "room (one painted px = HiveArt.PIXEL canvas px)",
    }
    return frames, {"room_payoff": payoff}, geo


# =============================================================================================
# The rule: the pour jar's parts at a smaller body (hud, cue)
# =============================================================================================
def rule_jar(W=14, H=14, fill=1.0, lid=True, label=None, dome=1, skirt=3, check=1, mouth=False,
             streak=True):
    """The pour jar's design on a glass body W wide and H tall, at one px a pixel, before its ring.

    Rows from the top: `dome` rows of cloth (inset 2), `skirt` rows of cloth hanging over the neck
    (inset 1, a zigzag hem, the twine on its last-but-one row), then the glass: two neck rows inset
    2, one shoulder row inset 1, the body, the bottom row inset 1. Glass lit white down the left,
    blue-grey down the right, a white streak inside the lit side, a glint on the shoulder; honey to
    `fill` in the five-step ramp, a shine on its surface; `label` True puts the paper label with
    its red rules and red cell on. Returns (back, front, rows, honey (top, bottom), top) where rows
    maps y -> (l, r) of the glass and the canvas is W x (top + H)."""
    top = dome + skirt - 1                      # the neck's first row sits under the hem
    if not lid:
        top = 1
    Hc = top + H
    back = pa.Spr(W, Hc)
    front = pa.Spr(W, Hc)
    rows = {}
    for i in range(H):
        y = top + i
        if i < 2:
            inset = 2
        elif i == 2 or i == H - 1:
            inset = 1
        else:
            inset = 0
        rows[y] = (inset, W - 1 - inset)
    hon_top, hon_bot = top + 3, top + H - 2
    surface = int(round(hon_bot - (hon_bot - hon_top) * min(max(fill, 0.0), 1.0))) if fill > 0 \
        else Hc + 5
    for y, (l, r) in rows.items():
        for x in range(l + 1, r):
            u = (x - l) / max(1, r - l)
            climb = 1 if (x - l <= 1 or r - x <= 1) else 0
            if y >= hon_top and y >= surface - climb:
                d = (y - surface) / max(1.0, hon_bot - surface)
                if y == surface - climb:
                    c = HONEY[4] if 0.25 < u < 0.7 else HONEY[3]
                elif d < 0.25:
                    c = HONEY[3]
                elif d < 0.65:
                    c = HONEY[2]
                else:
                    c = HONEY[1]
                if u < 0.2 and y > surface:
                    c = HONEY[3]
                if u > 0.8 and y > surface + 1:
                    c = HONEY[1]
                if y >= hon_bot:
                    c = HONEY[0] if u > 0.3 else HONEY[1]
                back.put(x, y, c)
            else:
                back.put(x, y, EMPTY)
    lit_until = top + int(H * 0.72)
    for y, (l, r) in rows.items():
        front.put(l, y, WHITE if y < lit_until else GLASS)
        front.put(r, y, GLASS_EDGE)
    # the neck's top edge (the mouth's rim when open, under the cloth when shut)
    for x in range(2, W - 2):
        front.put(x, top, WHITE if x < W // 2 else GLASS)
    # the shoulder's glint and the streak down the lit side
    front.put(1, top + 2, WHITE)
    front.put(2, top + 2, WHITE)
    front.put(1, top + 3, WHITE)
    if streak:
        for y in range(top + 4, top + 4 + max(2, int(H * 0.45))):
            if y < top + H - 2:
                front.put(2, y, WHITE)
        for y in range(top + int(H * 0.55), top + int(H * 0.55) + max(1, H // 6)):
            front.put(W - 3, y, WHITE[:3] + (150,))
    if mouth:
        for x in range(3, W - 3):
            back.put(x, top + 1, look.mix(GLASS_EDGE, OUT, 0.35)[:3] + (210,))
    if label:
        _rule_label(front, W, top, H)
    if lid:
        _rule_lid(front, W, dome, skirt, check)
    sil = Image.new("RGBA", (W, Hc), CLEAR)
    for y, (l, r) in rows.items():
        for x in range(l, r + 1):
            sil.putpixel((x, y), OUT)
    sil.alpha_composite(front.im)
    return back.im, front.im, sil, rows, (hon_top, hon_bot), top


def _rule_label(s, W, top, H):
    """The paper label: red rules top and bottom, the paper's edge down its right, the red
    honeycomb cell with a drop of honey in the middle (pour_art MARK_CELL; a 3 x 2 cell when the
    label is too small for it)."""
    lh = 6 if H >= 12 else 4
    y0 = top + 3 + (H - 3 - lh) // 2
    x0, x1 = 2, W - 3
    for y in range(y0, y0 + lh):
        for x in range(x0, x1 + 1):
            c = PAPER_EDGE if x == x1 else PAPER
            if y in (y0, y0 + lh - 1):
                c = GING_R if x < x1 else look.mix(GING_R, OUT, 0.25)
            s.put(x, y, c)
    cx = (x0 + x1) // 2
    if lh >= 6 and x1 - x0 >= 7:
        look.grid([".RRR.", "RhHhR", ".RRR."], {"R": GING_R, "h": HONEY[3], "H": HONEY[2]},
                  cx - 2, y0 + 1 + (lh - 2 - 3) // 2 + 0, into=s.im)
    else:
        look.grid(["RhR"], {"R": GING_R, "h": HONEY[3]}, cx - 1, y0 + lh // 2 - (0 if lh > 3 else 1),
                  into=s.im)


def _rule_lid(s, W, dome, skirt, check):
    """The gingham cloth over the neck: its top a dome inset two, the skirt inset one hanging in a
    zigzag hem, red, pink and white checks `check` px a side, lit on the left, shaded on the
    right, the oak twine round the neck on the skirt's last-but-one row."""
    for y in range(dome + skirt):
        if y < dome:
            l, r = 2, W - 3
        else:
            l, r = 1, W - 2
        hem = y == dome + skirt - 1
        for x in range(l, r + 1):
            if hem and ((x - l) // check) % 2 == 1:
                continue
            ch = ((x // check) % 2) + ((y // check) % 2)
            c = GING_R if ch == 2 else GING_P if ch == 1 else GING_W
            u = (x - l) / max(1, r - l)
            if y >= dome and u > 0.72:
                c = look.mix(c, OUT, 0.18)
            if y >= dome and u < 0.12:
                c = look.mix(c, WHITE, 0.25)
            s.put(x, y, c)
    ty = dome + skirt - 2
    for x in range(2, W - 2):
        s.put(x, ty, TWINE if x < W * 0.6 else TWINE_SHADE)
    s.put(W // 2, ty, TWINE_LIT)


def ringed(back, front, sil):
    """The pour jar's own inking: a ring round the silhouette, the layers one px in."""
    ring = look.inked(sil)
    ring_only = Image.new("RGBA", ring.size, CLEAR)
    rp, op, sp = ring.load(), ring_only.load(), sil.load()
    for y in range(ring.height):
        for x in range(ring.width):
            inside = 1 <= x <= sil.width and 1 <= y <= sil.height and sp[x - 1, y - 1][3] > 0
            if rp[x, y][3] and not inside:
                op[x, y] = rp[x, y]
    out = Image.new("RGBA", ring.size, CLEAR)
    out.alpha_composite(back, (1, 1))
    out.alpha_composite(front, (1, 1))
    out.alpha_composite(ring_only)
    return out


def with_dipper(jar, W):
    """A wooden honey dipper standing in an open jar, leaning out of the mouth to the right: two
    px of oak (lit, shade), its foot lost in the honey, ringed where it is out of the glass, a
    bead of honey run down it over the rim (honey sheet 1A). Returns a taller picture, the jar's
    feet one row lower by `up`."""
    up = 5
    out = Image.new("RGBA", (jar.width + 2, jar.height + up), CLEAR)
    stick = Image.new("RGBA", out.size, CLEAR)
    x0, y0 = W - 4, out.height - 6
    for i in range(out.height):
        x = x0 + int(round(i * 0.42))
        y = y0 - i
        if y < 1:
            break
        for dx in (0, 1):
            xx = min(x + dx, stick.width - 2)
            stick.putpixel((xx, y), DIP if dx == 0 else DIP_SHADE)
    stick = look.inked(stick).crop((1, 1, out.width + 1, out.height + 1))
    out.alpha_composite(stick)
    # the jar over the stick: the stick shows through the empty glass, is lost in the honey
    j = Image.new("RGBA", out.size, CLEAR)
    j.alpha_composite(jar, (0, up))
    out.alpha_composite(j)
    # the part of the stick above the jar's mouth stays whole
    px, sp = out.load(), stick.load()
    for y in range(out.height):
        for x in range(out.width):
            if sp[x, y][3] and y < up + 2:
                px[x, y] = sp[x, y]
    # a bead of honey run down the stick over the rim
    rim = up + 1
    for y in range(rim - 2, rim):
        for x in range(out.width - 1, -1, -1):
            if sp[x, y][3] and sp[x, y][:3] in (DIP[:3], DIP_SHADE[:3]):
                px[x, y] = HONEY[3] if y < rim - 1 else HONEY[2]
                break
    return out


# =============================================================================================
# hud: 14 x 14 of glass (honey sheet 1A)
# =============================================================================================
HUD_W, HUD_H = 14, 14


def hud_frames():
    frames = {}
    b, f, sil, rows, (ht, hb), top = rule_jar(HUD_W, HUD_H, 1.0, lid=True, label=True, dome=1,
                                              skirt=3, check=1)
    sealed = ringed(b, f, sil)
    levels = hb - ht + 2
    opens = []
    for k in range(levels):
        fill = 0.0 if k == 0 else (k - 0.5) / float(levels - 1)
        b, f, sil, rows2, _, top_o = rule_jar(HUD_W, HUD_H, fill, lid=False, label=False,
                                              mouth=True)
        opens.append(with_dipper(ringed(b, f, sil), HUD_W))
    # one canvas for every hud frame: the tallest (the open jar with its dipper), feet lined up
    cw = max(sealed.width, opens[0].width)
    ch = max(sealed.height, opens[0].height)
    feet = (1 + HUD_W // 2, ch - 1)

    def onto(im):
        out = Image.new("RGBA", (cw, ch), CLEAR)
        out.alpha_composite(im, (0, ch - im.height))
        return out

    frames["hud_sealed"] = onto(sealed)
    for k, im in enumerate(opens):
        frames["hud_open%d" % k] = onto(im)
    geo = {"canvas": [cw, ch], "feet": list(feet), "levels": levels,
           "glass": [HUD_W + 2, HUD_H + 2], "grain": "HUD canvas px"}
    return frames, geo


# =============================================================================================
# cue: the first jar's card icon (honey sheet 5B), authored at one icon px a px: 11 px of glass
# is too few for the rule's neck and shoulders to read, so the shapes are 5B's own grids, drawn in
# the pour jar's swatches (glass lit white left, blue-grey right, pale glass, the honey ramp, the
# gingham, the oak twine, the paper label with its red rules and cell).
# =============================================================================================
CUE_KEY = {"O": OUT, "G": GLASS_EDGE, "g": WHITE, "e": GLASS, "s": HONEY[4], "L": HONEY[3],
           "H": HONEY[2], "M": HONEY[1], "D": HONEY[0], "R": GING_R, "W": GING_W, "P": GING_P,
           "t": TWINE, "p": PAPER, "q": PAPER_EDGE, "r": look.mix(GING_R, OUT, 0.25),
           "h": HONEY[3], "k": HONEY[2]}
# open: honey heaped out of the mouth with a shine, glass empty at the top with honey run down
# its front, honey in the lower two thirds (5B's JAR_ICON_BODY)
CUE_OPEN = ["...OOOOO...",
            "..OsLLLHO..",
            ".OLHHHHHMO.",
            "OOgeeeeLeOO",
            "OgeeeeeLeGO",
            "OgeeeeeLMGO",
            "OgLHHHHLMGO",
            "OgLHHHHHMGO",
            "OgLHHHHHMGO",
            "OGMHHHHMDGO",
            ".OGGGGGGGO.",
            "..OOOOOOO.."]
# sealed: the same glass, full, the cloth tied on and the label on (a lid means a label)
CUE_SEALED = ["..OOOOOOO..",
              ".ORWRWRWRO.",
              ".OWRWRWRWO.",
              ".OPRPRPRPO.",
              "..OtttttO..",
              "OOgsLLLLMOO",
              "OgRRRRRRrGO",
              "OgppRRRpqGO",
              "OgpRhkhRqGO",
              "OgppRRRpqGO",
              "OgRRRRRRrGO",
              "OGMHHHHMDGO",
              ".OGGGGGGGO.",
              "..OOOOOOO.."]
# the cloth tilted off the jar at the top of its hop (5B's JAR_ICON_LID)
CUE_LID = ["......OOOO",
           "....OORWRO",
           "...ORWRWRO",
           "..OPRPRPOO",
           "..OttttO..",
           "..OOOOO..."]
CUE_HOP = 2                     # the lid's hop, icon px, at its top (cue_pop2)


def cue_frames():
    frames = {}
    body = look.grid(CUE_OPEN, CUE_KEY)
    sealed = look.grid(CUE_SEALED, CUE_KEY)
    lid = look.grid(CUE_LID, CUE_KEY)
    lift = len(CUE_LID)          # room over the open jar for the lid's hop
    cw = max(body.width, lid.width + 2)
    ch = max(body.height + lift, sealed.height)
    feet = (body.width // 2, ch - 1)

    def onto(im, x=0):
        out = Image.new("RGBA", (cw, ch), CLEAR)
        out.alpha_composite(im, (x, ch - im.height))
        return out

    frames["cue_sealed"] = onto(sealed)
    frames["cue_open"] = onto(body)
    rest = (1, ch - body.height - lift + 3)      # 5B: the lid resting tilted on the heap
    for k in range(CUE_HOP + 1):
        im = onto(body)
        im.alpha_composite(lid, (rest[0] + (1 if k else 0), rest[1] - k))
        frames["cue_pop%d" % k] = im
    only = Image.new("RGBA", (cw, ch), CLEAR)
    only.alpha_composite(lid, rest)
    frames["cue_lid"] = only
    geo = {"canvas": [cw, ch], "feet": list(feet), "lid_rest": list(rest), "hop": CUE_HOP,
           "grain": "icon px (CueCard.CELL_HINT canvas px)"}
    return frames, geo


# =============================================================================================
# shelf: the island cupboard's jar (island sheet C), 7 x 9 with its outline
# =============================================================================================
SHELF = [
    ".OOOOO.",
    "OrwrwrO",
    "OwrwpwO",
    ".OtttO.",
    "OgsLLEO",
    "OPRRPeO",
    "OLHHMEO",
    "OHMMDEO",
    ".OOOOO.",
]
SHELF_KEY = {"O": OUT, "r": GING_R, "w": GING_W, "p": GING_P, "t": TWINE, "g": WHITE,
             "s": HONEY[4], "L": HONEY[3], "H": HONEY[2], "M": HONEY[1], "D": HONEY[0],
             "E": GLASS_EDGE, "P": PAPER, "R": GING_R, "e": PAPER_EDGE}


def shelf_frames():
    jar = look.grid(SHELF, SHELF_KEY)
    return ({"shelf": jar, "shelf_shade": look.tinted(jar, OUT, SHELF_SHADE)},
            {"canvas": [7, 9], "feet": [3, 8], "pitch": 8,
             "grain": "island (one world px a px)"})


# =============================================================================================
def build():
    room, room_big, room_geo = room_frames()
    hud, hud_geo = hud_frames()
    cue, cue_geo = cue_frames()
    shelf, shelf_geo = shelf_frames()
    groups = [("room", room, room_geo), ("room", room_big, None), ("hud", hud, hud_geo),
              ("cue", cue, cue_geo), ("shelf", shelf, shelf_geo)]
    # shelf rows: each group on its own rows, wrapped at a fixed width
    WIDE = 512
    placed = []
    x, y, row_h = GAP, GAP, 0
    for size, frames, _ in groups:
        if x > GAP:
            x, y, row_h = GAP, y + row_h + GAP, 0
        for name, im in frames.items():
            if x + im.width + GAP > WIDE:
                x, y, row_h = GAP, y + row_h + GAP, 0
            placed.append((name, size, im, x, y))
            x += im.width + GAP
            row_h = max(row_h, im.height)
    height = y + row_h + GAP
    sheet = Image.new("RGBA", (WIDE, height), CLEAR)
    feet = {"room": tuple(room_geo["feet"]), "hud": tuple(hud_geo["feet"]),
            "cue": tuple(cue_geo["feet"]), "shelf": tuple(shelf_geo["feet"])}
    book = {"sheet": "res://assets/honey_pot.png", "frames": {},
            "sizes": {"room": room_geo, "hud": hud_geo, "cue": cue_geo, "shelf": shelf_geo}}
    for name, size, im, px_, py_ in placed:
        sheet.alpha_composite(im, (px_, py_))
        fx, fy = feet[size]
        if name == "room_payoff":
            fx, fy = fx + 1, fy + 1
        book["frames"][name] = {"rect": [px_, py_, im.width, im.height], "anchor": [fx, fy],
                                "size": size}
    sheet.save(OUT_PNG)
    with open(OUT_JSON, "w", newline="\n") as fh:
        json.dump(book, fh, indent=1)
        fh.write("\n")
    return sheet, book, placed


if __name__ == "__main__":
    sheet, book, _ = build()
    print("wrote %s %s, %d frames" % (OUT_PNG, sheet.size, len(book["frames"])))
    for k, g in book["sizes"].items():
        print("  %-6s canvas %s feet %s" % (k, g["canvas"], g["feet"]))

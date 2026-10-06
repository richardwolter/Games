"""Build the decoration picked on the Lake Pack Tagger from the 0_mem0ry packs.

The first batch (2026-10-01, `/grill-me` with Richard): every piece below is authored by
hand off the tagger's sets, read off `tools/last_deco_a/b/c.png`. A view is a catalogue
object id, optionally cut down to one of its islands (a sprite holding several objects):

    (id, cut, role, face, state, mirror)

`cut` is None for the whole object, or an island's [x0, y0, x1, y1] (inclusive) inside it.
`face` is what R turns along, `state` what E flips (0 off/shut, 1 on/open). A view with
`mirror` gets a flipped copy as one more face, in the same state: only side views are
mirrored, and only where the tagger marked "flip". Nothing with states is mirrored but a
side view, whose two states are mirrored together.

View 0 of every piece faces front, switched off, which is what leaves the store.

These are shed-only for now: their sheets are `decor_pack_dirty` / `decor_pack_clean`, and
`Lake._all_defs` reads finds off `decor_dirty` alone, so none is hidden in the lake. The
dirty sprite is rule-built grime over view 0 (`grime`), for when they are.

Writes:
  assets/decor_pack_clean.png    every clean view, packed
  assets/decor_pack_dirty.png    one grimy sprite per piece
  assets/pieces.json             the decor_pk_* entries replaced

    ComfyUI's venv python (PIL), from the project root; reimport after
"""
import json, random
from pathlib import Path
from PIL import Image
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_decor import shared_frame

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"
CATALOGUE = ROOT / "assets/pieces.json"
CLEAN, DIRTY = "decor_pack_clean", "decor_pack_dirty"
WIDTH, GAP, CELL = 512, 2, 16
# How big the shed draws the pack pieces against their art: drawn at 1 they stood large
# beside the angler (Richard, 2026-10-01). The stove and counter already ran at 0.75.
SHED_SCALE = 0.74

F, S, B, R = "front", "side", "back", "side_r"
# A view's `cut` may be TURN: the whole object turned a quarter, for the rugs, which the
# packs draw flat and only one way round (2026-10-03, Richard: "all rugs can be turned
# sideways"). A rug is a flat pattern, so a quarter turn is a rug lying the other way.
TURN = "turn"
# The two armchairs and the kitchen kit, cut to the island that is the piece.
CUT = {
    "chair_front": [0, 0, 30, 42], "chair_back": [32, 10, 62, 42],
    "seat_back": [32, 12, 62, 42],
    "sink": [48, 0, 79, 45], "basin": [128, 5, 159, 45],
    "bed_bare": [8, 29, 40, 93], "tub_bare": [0, 30, 28, 91],
    # 1054 is the fridge side-on, door open, with a table drawn against it.
    "fridge_side_open": [0, 0, 31, 58],
    # 2158 holds a dark armchair's back, the glass table side-on, and a scrap: the table.
    "glass_side": [0, 43, 22, 85],
    # The potted tree, without the leaf fallen beside it.
    # The fallen leaf reaches into that box at its bottom left (2026-10-01, Richard: "little
    # slice of green"), and the crown is as wide, so the piece keeps its biggest island too.
    "tree": [4, 0, 25, 53, "main"],
}

# The Messy pack draws a puddle under the fridge's front, its open front and its open side
# (2026-10-03, Richard: "it should be just the fridge"). The puddle is these four blue-greys
# and lies outside the fridge's own outline, so clearing them in the bottom rows leaves the
# fridge whole; the bottom rows only, because a magnet higher up is blue too.
DRY = {1049, 1050, 1054}

# The floor lamp's shade lit (2026-10-03, Richard: lamps switch): the Coastal lamp's three
# shade blues and its bulb mapped onto the lit table lamp's own yellows (1064), darkest to
# darkest, in the shade's rows only (the stand has none of these colours, but the rows keep
# it so).
LIT = {
    (120, 159, 168): (244, 160, 1),
    (149, 189, 198): (244, 191, 33),
    (188, 227, 236): (255, 216, 100),
    (236, 212, 143): (255, 244, 190),
    (255, 231, 162): (255, 255, 236),
}
LIT_ROWS = 17


def lit(im):
    out = im.copy()
    po = out.load()
    for y in range(min(LIT_ROWS, out.height)):
        for x in range(out.width):
            if po[x, y][3] and po[x, y][:3] in LIT:
                po[x, y] = LIT[po[x, y][:3]] + (po[x, y][3],)
    return out
PUDDLE = {(185, 204, 204), (121, 140, 140), (165, 184, 184), (209, 228, 228)}
PUDDLE_ROWS = 10


def dried(im):
    out = im.copy()
    po = out.load()
    w, h = out.size
    for y in range(max(0, h - PUDDLE_ROWS), h):
        for x in range(w):
            if po[x, y][3] and po[x, y][:3] in PUDDLE:
                po[x, y] = (0, 0, 0, 0)
    return out


# name, title, set, place, light, views
PIECES = [
    ("armchair", "Armchair", "ROTATE", "floor", "", [
        (373, CUT["chair_front"], F, 0, 0, 0), (374, None, S, 1, 0, 1), (373, CUT["chair_back"], B, 2, 0, 0)]),
    ("old_seat", "Old Seat", "ROTATE", "floor", "", [
        (925, CUT["chair_front"], F, 0, 0, 0), (926, None, S, 1, 0, 1), (925, CUT["seat_back"], B, 2, 0, 0)]),
    ("bathtub", "Bathtub", "ROTATE", "floor", "", [
        (2065, None, F, 0, 0, 0), (2058, None, S, 1, 0, 0), (2051, CUT["tub_bare"], "top", 2, 0, 0)]),
    ("bed", "Bed", "ROTATE", "floor", "", [
        (2137, CUT["bed_bare"], F, 0, 0, 0), (2147, None, S, 1, 0, 0), (2142, None, B, 2, 0, 0)]),
    ("bookshelf", "Bookshelf", "ROTATE", "floor", "", [
        (418, None, F, 0, 0, 0), (420, None, S, 1, 0, 1), (419, None, B, 2, 0, 0)]),
    ("chair", "Chair", "ROTATE", "floor", "", [
        (1593, None, F, 0, 0, 0), (1595, None, S, 1, 0, 0), (1594, None, B, 2, 0, 0), (1596, None, R, 3, 0, 0)]),
    ("coffee_table", "Coffee Table", "ROTATE", "floor", "", [
        (2208, None, F, 0, 0, 0), (2209, None, "front_open", 0, 1, 0), (2210, None, B, 1, 0, 0)]),
    ("corner_desk", "Corner Desk", "ROTATE", "floor", "", [
        (1158, None, F, 0, 0, 0), (1159, None, "front_open", 0, 1, 0), (1160, None, B, 1, 0, 0)]),
    ("drawer", "Drawer", "ROTATE", "floor", "", [
        (2150, None, F, 0, 0, 0), (2149, None, "front_open", 0, 1, 0), (2151, None, S, 1, 0, 1)]),
    ("drawer_desk", "Drawer Desk", "ROTATE", "floor", "", [
        (412, None, F, 0, 0, 0), (413, None, "front_open", 0, 1, 0), (414, None, B, 2, 0, 0)]),
    ("fancy_bed", "Fancy Bed", "ROTATE", "floor", "", [
        (443, None, F, 0, 0, 0), (445, None, S, 1, 0, 1), (444, None, B, 2, 0, 0)]),
    ("fancy_table", "Fancy Table", "ROTATE", "floor", "", [
        (395, None, F, 0, 0, 0), (394, None, S, 1, 0, 0)]),
    ("file_cabinet", "File Cabinet", "ROTATE", "floor", "", [
        (1324, None, F, 0, 0, 0), (1323, None, "front_open", 0, 1, 0), (1327, None, S, 1, 0, 1)]),
    ("fireplace", "Fireplace", "STATE", "floor", "fire", [
        (435, None, "off", 0, 0, 0), (436, None, "on", 0, 1, 0)]),
    ("kitchen_counter", "Kitchen Counter", "VARIANT", "floor", "", [
        (1854, CUT["sink"], "sink", 0, 0, 0), (1854, CUT["basin"], "basin", 1, 0, 0)]),
    ("microwave", "Microwave", "ROTATE", "small", "", [
        (1817, None, F, 0, 0, 0), (1818, None, "front_open", 0, 1, 0), (1819, None, B, 1, 0, 0)]),
    ("sofa", "Sofa", "ROTATE", "floor", "", [
        (2126, None, F, 0, 0, 0), (2122, None, S, 1, 0, 1), (2127, None, B, 2, 0, 0)]),
    ("stove", "Stove", "STATE", "floor", "ember", [
        (1857, None, "off", 0, 0, 0), (1858, None, "on", 0, 1, 0)]),
    ("table", "Table", "ROTATE", "floor", "", [
        (27, None, F, 0, 0, 0), (23, None, S, 1, 0, 1)]),
    ("toilet", "Toilet", "ROTATE", "floor", "", [
        (2011, None, F, 0, 0, 0), (2013, None, S, 1, 0, 1), (2014, None, "side_shut", 1, 1, 1),
        (2012, None, B, 2, 0, 0)]),
    ("diner_chair", "Diner Chair", "ROTATE", "floor", "", [
        (3, None, F, 0, 0, 0), (2, None, S, 1, 0, 1), (7, None, B, 2, 0, 0)]),
    ("green_chair", "Green Chair", "ROTATE", "floor", "", [
        (288, None, F, 0, 0, 0), (289, None, S, 1, 0, 1), (292, None, B, 2, 0, 0)]),
    ("wood_chair", "Wooden Chair", "ROTATE", "floor", "", [
        (352, None, F, 0, 0, 0), (355, None, S, 1, 0, 1), (353, None, B, 2, 0, 0)]),
    ("carved_chair", "Carved Chair", "ROTATE", "floor", "", [
        (399, None, F, 0, 0, 0), (401, None, S, 1, 0, 1), (400, None, B, 2, 0, 0)]),
    ("white_sofa", "White Sofa", "ROTATE", "floor", "", [
        (307, None, F, 0, 0, 0), (305, None, S, 1, 0, 1), (311, None, B, 2, 0, 0)]),
    ("nightstand", "Nightstand", "ROTATE", "floor", "", [
        (437, None, F, 0, 0, 0), (438, None, "front_open", 0, 1, 0), (439, None, B, 1, 0, 0)]),
    ("bonsai", "Bonsai", "SINGLE", "small", "", [(297, None, F, 0, 0, 0)]),
    ("rug", "Gold Rug", "ROTATE", "floor", "", [(300, None, F, 0, 0, 0), (300, TURN, S, 1, 0, 0)]),
    ("coat_stand", "Coat Stand", "SINGLE", "floor", "", [(328, None, F, 0, 0, 0)]),
    ("landscape", "Landscape", "SINGLE", "wall", "", [(385, None, F, 0, 0, 0)]),
    ("portrait", "Portrait", "SINGLE", "wall", "", [(389, None, F, 0, 0, 0)]),
    ("grandfather_clock", "Old Clock", "SINGLE", "floor", "", [(427, None, F, 0, 0, 0)]),
    ("globe", "Globe", "SINGLE", "floor", "", [(430, None, F, 0, 0, 0)]),
    ("sculpture", "Sculpture", "SINGLE", "floor", "", [(1146, None, F, 0, 0, 0)]),
    ("blue_rug", "Blue Rug", "ROTATE", "floor", "", [(1172, None, F, 0, 0, 0), (1172, TURN, S, 1, 0, 0)]),
    # The second batch (2026-10-01).
    ("fridge", "Fridge", "ROTATE", "floor", "cold", [
        (1049, None, F, 0, 0, 0), (1050, None, "front_open", 0, 1, 0),
        (1052, None, S, 1, 0, 1), (1054, CUT["fridge_side_open"], "side_open", 1, 1, 1)]),
    ("side_desk", "Side Desk", "ROTATE", "floor", "", [
        (1150, None, F, 0, 0, 0), (1149, None, "front_open", 0, 1, 0),
        (1152, None, S, 1, 0, 1), (1151, None, B, 2, 0, 0)]),
    ("sink", "Sink", "ROTATE", "floor", "", [
        (2008, None, F, 0, 0, 0), (2010, None, S, 1, 0, 1), (2009, None, B, 2, 0, 0)]),
    ("diner_table", "Diner Table", "SINGLE", "floor", "", [(4, None, F, 0, 0, 0)]),
    ("flower_vase", "Flower Vase", "SINGLE", "small", "", [(361, None, F, 0, 0, 0)]),
    ("flower_pot", "Flower Pot", "SINGLE", "floor", "", [(505, None, F, 0, 0, 0)]),
    ("car_picture", "Poster", "SINGLE", "wall", "", [(964, None, F, 0, 0, 0)]),
    ("dotted_rug", "Dotted Rug", "ROTATE", "floor", "", [(1192, None, F, 0, 0, 0), (1192, TURN, S, 1, 0, 0)]),
    ("aloe", "Aloe", "SINGLE", "small", "", [(1213, None, F, 0, 0, 0)]),
    ("cactus", "Cactus", "SINGLE", "small", "", [(2138, None, F, 0, 0, 0)]),
    # The third batch (2026-10-01).
    ("diner_seat", "Diner Seat", "ROTATE", "floor", "", [
        (49, None, F, 0, 0, 0), (45, None, S, 1, 0, 1)]),
    ("glass_table", "Glass Table", "ROTATE", "floor", "", [
        (2165, None, F, 0, 0, 0), (2158, CUT["glass_side"], S, 1, 0, 1)]),
    ("small_table", "Small Table", "SINGLE", "floor", "", [(380, None, F, 0, 0, 0)]),
    ("plant", "Plant", "SINGLE", "small", "", [(471, None, F, 0, 0, 0)]),
    ("sprout_pot", "Sprout Pot", "SINGLE", "small", "", [(673, None, F, 0, 0, 0)]),
    ("potted_tree", "Potted Tree", "SINGLE", "floor", "", [(1019, CUT["tree"], F, 0, 0, 0)]),
    # The Messy pack draws the table lamp off (1063) and lit (1064); E switches it
    # (2026-10-03). It was 1064 alone, so a lamp saved before reads as off.
    ("table_lamp", "Table Lamp", "STATE", "small", "warm", [
        (1063, None, "off", 0, 0, 0), (1064, None, "on", 0, 1, 0)]),
    # The record player is the old find's own entry, re-drawn (see REPLACES): lid down from
    # above (2222), lid up (2214). The menu E opens is drawn in these colours.
    ("record_player", "Record player", "STATE", "small", "", [
        (2222, None, "closed", 0, 0, 0), (2214, None, "open", 0, 1, 0)]),
    # The fourth batch (2026-10-03). 299 holds a rose in a vase over a potted plant, and is
    # two finds; 332 is the floor lamp with two cushions beside it, cut to the lamp. Rugs
    # turn a quarter (TURN). 1232 / 1229 are the tagger's "Decorated Table" set, front and
    # side of an open shelf dressed with books and plants.
    ("rose_vase", "Rose Vase", "SINGLE", "small", "", [(299, [0, 0, 10, 24], F, 0, 0, 0)]),
    ("leafy_pot", "Leafy Pot", "SINGLE", "floor", "", [(299, [2, 27, 24, 57], F, 0, 0, 0)]),
    # The Coastal pack has no lit floor lamp, so its "on" is the same cut with the shade lit
    # by rule (LIT).
    ("floor_lamp", "Floor Lamp", "STATE", "floor", "warm", [
        (332, [0, 0, 13, 42, "main"], "off", 0, 0, 0),
        (332, [0, 0, 13, 42, "main", "lit"], "on", 0, 1, 0)]),
    ("drinks_cart", "Drinks Cart", "SINGLE", "floor", "", [(428, None, F, 0, 0, 0)]),
    ("striped_rug", "Striped Rug", "ROTATE", "floor", "", [(1097, None, F, 0, 0, 0), (1097, TURN, S, 1, 0, 0)]),
    ("oval_rug", "Small Rug", "ROTATE", "floor", "", [(1112, None, F, 0, 0, 0), (1112, TURN, S, 1, 0, 0)]),
    ("runner_rug", "Runner Rug", "ROTATE", "floor", "", [(2156, None, F, 0, 0, 0), (2156, TURN, S, 1, 0, 0)]),
    ("decorated_table", "Decorated Table", "ROTATE", "floor", "", [
        (1232, None, F, 0, 0, 0), (1229, None, S, 1, 0, 1)]),
]

# Views added after a piece was first built, appended after every view (and mirror) it
# already had, so a saved `view` index still points at the same picture (2026-10-03, the
# counterpart review). Each is (id, cut, role, face, state, mirror), as in PIECES.
LATE = {
    # The side with its drawer pulled out; the side view used to be this one, as if shut.
    "side_desk": [(1153, None, "side_open", 1, 1, 1)],
    # The cabinet's back, which stood in for its side, and the side with a drawer out.
    "file_cabinet": [(1325, None, B, 2, 0, 0), (1326, None, "side_open", 1, 1, 1)],
    # The desk's side, shut and with its drawer out, which the pack drew and nobody used.
    "drawer_desk": [(409, None, S, 1, 0, 1), (410, None, "side_open", 1, 1, 1)],
}

# Pieces that take over an existing find's catalogue entry rather than joining as a new
# decor_pk_* one: the entry keeps its name, its place in the catalogue (so the lake's def
# list, and every save, is unchanged) and its title, and takes this art.
REPLACES = {"record_player": "decor_vynil_player"}

TAGS = PACKS / "tagger/pull/packs"


def tags():
    import glob
    out = {}
    for f in glob.glob(str(TAGS / "*.json")):
        d = json.loads(Path(f).read_text())
        out.update({int(k): v for k, v in d.get("data", d)["items"].items()})
    return out


TAG = tags()


def tier_of(views):
    """The piece's weight tier on the tagger, off its first view."""
    return int(TAG.get(views[0][0], {}).get("t", 1))

# How deep each piece's floor footprint is on its front view, in the art's own pixels: how
# much of the bottom of the picture is floor it stands on, the rest being height that may
# rise up the back wall. Set by eye in the spirit of the old finds' numbers (a cabinet 8, a
# chair about 10, a sofa or table about half its height, a bed most of it). A back view
# takes the front's; a side view takes what is left when the front's height above its
# footprint is taken off the side's height (the piece is as tall from every side). Scaled
# to the shed's drawing with SHED_SCALE. Rugs and wall pieces have none.
FRONT_BASE = {
    "armchair": 16, "old_seat": 16, "bathtub": 24, "bed": 40, "bookshelf": 8, "chair": 10,
    "coffee_table": 14, "corner_desk": 16, "drawer": 10, "drawer_desk": 12, "fancy_bed": 50,
    "fancy_table": 24, "file_cabinet": 8, "fireplace": 10, "kitchen_counter": 16,
    "microwave": 8, "sofa": 18, "stove": 12, "table": 24, "toilet": 18, "diner_chair": 10,
    "green_chair": 10, "wood_chair": 10, "carved_chair": 10, "white_sofa": 18,
    "nightstand": 8, "bonsai": 2, "coat_stand": 6, "grandfather_clock": 8, "globe": 8,
    "sculpture": 6, "fridge": 10, "side_desk": 10, "sink": 10, "diner_table": 14,
    "flower_vase": 2, "flower_pot": 4, "aloe": 2, "cactus": 2, "diner_seat": 20,
    "glass_table": 16, "small_table": 10, "plant": 2, "sprout_pot": 2, "potted_tree": 6,
    "table_lamp": 2, "record_player": 6,
    "rose_vase": 2, "leafy_pot": 4, "floor_lamp": 4, "drinks_cart": 10, "decorated_table": 10,
}
SIDE_ROLES = ("side", "top")

# How many of a piece are hidden in the lake. Every find is unique (2026-10-01, Richard:
# "I caught 3 of the same diner chair"); this was four diner chairs to the diner table.
COPIES = {}

# Where a dog's feet go on a piece it may lie on, per view, in drawn pixels up from the
# picture's bottom (Sheets.seat_of): front views only, where nothing is in front of the
# cushion. First guesses at 0.74; retune on tools/shot_shed.
SEATS = {"sofa": {0: 7}, "white_sofa": {0: 7}, "armchair": {0: 6}, "old_seat": {0: 6},
         "diner_seat": {0: 6},
         # Every face of a bed takes a dog (2026-10-01, Richard: "sleep in any bed"): a bed's
         # rails are low, so nothing in front hides a dog lying on it from the side or back.
         # Off the pillow on the faces whose pillow is at the near end (2026-10-03): there the
         # dog lay over the sleeper's head, so it lies at the far end, over the feet.
         "bed": {0: 32, 1: 12, 2: 18}, "fancy_bed": {0: 22, 1: 15, 2: 37, 3: 15}}


def bases_of(name, roles, heights):
    front = FRONT_BASE.get(name)
    if front is None:
        return []
    front_h = next((h for r, h in zip(roles, heights) if not r.startswith(SIDE_ROLES)), heights[0])
    out = []
    for r, h in zip(roles, heights):
        b = h - (front_h - front) if r.startswith(SIDE_ROLES) else front
        out.append(max(1, min(h, round(max(b, 4 if front >= 4 else front) * SHED_SCALE))))
    return out


# A dirty find: the lake's murk over the piece, and blotches of it.
MURK = (78, 92, 52)
SCUM = (52, 60, 34)


def grime(im, seed):
    rng = random.Random(seed)
    out = im.copy()
    px = out.load()
    w, h = out.size
    spots = [(rng.uniform(0, w), rng.uniform(0, h), rng.uniform(2, 5)) for _ in range(max(3, w * h // 120))]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            low = 0.25 + 0.3 * (y / max(h - 1, 1))
            r, g, b = (int(c + (m - c) * low) for c, m in zip((r, g, b), MURK))
            if any((x - sx) ** 2 + (y - sy) ** 2 < rr * rr for sx, sy, rr in spots):
                r, g, b = (int(c * 0.4 + s * 0.6) for c, s in zip((r, g, b), SCUM))
            px[x, y] = (r, g, b, a)
    return out


def pack(images):
    spots, x, y, row = [], 0, 0, 0
    order = sorted(range(len(images)), key=lambda i: -images[i].height)
    places = [None] * len(images)
    for i in order:
        im = images[i]
        if x + im.width > WIDTH:
            x, y, row = 0, y + row + GAP, 0
        places[i] = (x, y)
        x += im.width + GAP
        row = max(row, im.height)
    sheet = Image.new("RGBA", (WIDTH, y + row), (0, 0, 0, 0))
    for i, im in enumerate(images):
        sheet.paste(im, places[i])
    return sheet, [[p[0], p[1], images[i].width, images[i].height] for i, p in enumerate(places)]


def fill_of(im):
    a = im.getchannel("A")
    return round(sum(1 for v in a.getdata() if v > 0) / (im.width * im.height), 3)


def main_island(im):
    """Only the largest 8-connected island of opaque pixels; the rest cleared."""
    w, h = im.size
    px = im.load()
    seen, best = set(), []
    for sy in range(h):
        for sx in range(w):
            if (sx, sy) in seen or px[sx, sy][3] == 0:
                continue
            group, stack = [], [(sx, sy)]
            seen.add((sx, sy))
            while stack:
                x, y = stack.pop()
                group.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (x + dx, y + dy)
                        if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n][3] > 0:
                            seen.add(n)
                            stack.append(n)
            if len(group) > len(best):
                best = group
    keep = set(best)
    out = im.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if (x, y) not in keep:
                po[x, y] = (0, 0, 0, 0)
    return out


def main():
    cat = {e["id"]: e for e in json.loads((PACKS / "catalogue.json").read_text())}
    sheets = {}

    def cut(oid, box):
        e = cat[oid]
        if e["sheet"] not in sheets:
            sheets[e["sheet"]] = Image.open(PACKS / e["sheet"]).convert("RGBA")
        x, y, w, h = e["box"]
        im = sheets[e["sheet"]].crop((x, y, x + w, y + h))
        if oid in DRY:
            im = dried(im)
        if box == TURN:
            im = im.transpose(Image.ROTATE_90)
        elif box:
            im = im.crop((box[0], box[1], box[2] + 1, box[3] + 1))
            if "main" in box[4:]:
                im = main_island(im)
        im = im.crop(im.getbbox())
        if box and box != TURN and "lit" in box[4:]:
            im = lit(im)
        return im

    clean, dirty, plan = [], [], []
    for name, title, kind, place, light, views in PIECES:
        roles, faces, states, ims, flips = [], [], [], [], []
        late = LATE.get(name, [])
        everything = list(views) + late
        top = max(v[3] for v in everything)
        # A mirrored face gets a face of its own past every drawn one, shared by both its
        # states; mirrors of two different faces get two.
        flipped_face = {}
        for v in everything:
            if v[5] and v[3] not in flipped_face:
                flipped_face[v[3]] = top + 1 + len(flipped_face)
        for oid, box, role, face, state, mirror in everything:
            ims.append(cut(oid, box)); roles.append(role); faces.append(face); states.append(state)
            flips.append(mirror)
        # A face's on view shares one frame with its off view, slid to where they match,
        # so switching it (E) never moves the piece: the open fridge's door swings out of
        # the same body. Only a piece that turns is aligned; a switch of one face (the
        # fireplace) is two pictures of the same size already.
        for i in range(len(ims)):
            if states[i] == 1:
                j = next((j for j in range(len(ims)) if faces[j] == faces[i] and states[j] == 0), None)
                if j is not None:
                    ims[j], ims[i] = shared_frame(ims[j], ims[i])
        # Order: the first views, their mirrors, then the late views and theirs, so the
        # indices a save already holds never move.
        drawn = list(zip(ims, roles, faces, states, flips))
        first_n = len(views)

        def mirrors(part):
            return [(im.transpose(Image.FLIP_LEFT_RIGHT), role + "_r", flipped_face[face], state, 0)
                    for im, role, face, state, flip in part if flip]

        ordered = drawn[:first_n] + mirrors(drawn[:first_n]) + drawn[first_n:] + mirrors(drawn[first_n:])
        ims = [o[0] for o in ordered]; roles = [o[1] for o in ordered]
        faces = [o[2] for o in ordered]; states = [o[3] for o in ordered]
        first = len(clean)
        clean.extend(ims)
        dirty.append(grime(ims[0], name))
        plan.append((name, title, kind, place, light, roles, faces, states, first, len(ims), ims[0], everything))

    clean_sheet, clean_boxes = pack(clean)
    dirty_sheet, dirty_boxes = pack(dirty)
    clean_sheet.save(ROOT / "assets/decor_pack_clean.png")
    dirty_sheet.save(ROOT / "assets/decor_pack_dirty.png")

    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    book["pieces"] = [p for p in book["pieces"] if not p["name"].startswith("decor_pk_")]
    for k, (name, title, kind, place, light, roles, faces, states, first, n, front, views) in enumerate(plan):
        box = dirty_boxes[k]
        if name in REPLACES:
            entry = next(p for p in book["pieces"] if p["name"] == REPLACES[name])
            entry.update({
                "sheet": DIRTY, "region": box, "alt_sheet": CLEAN,
                "alt_views": clean_boxes[first:first + n], "alt_roles": roles,
                "faces": faces, "states": states, "base": [], "place": place,
                "base_px": bases_of(name, roles, [b[3] for b in clean_boxes[first:first + n]]),
                "scale": SHED_SCALE, "fill": fill_of(front),
                "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
            })
            continue
        book["pieces"].append({
            "name": "decor_pk_" + name, "title": title, "set": kind, "place": place,
            "light": light, "sheet": DIRTY, "region": box, "alt_sheet": CLEAN,
            "alt_views": clean_boxes[first:first + n], "alt_roles": roles,
            "faces": faces, "states": states, "base": [],
            "seat": [SEATS.get(name, {}).get(i, 0) for i in range(n)] if name in SEATS else [],
            "base_px": [] if place == "wall" else bases_of(name, roles, [b[3] for b in clean_boxes[first:first + n]]),
            "tier": tier_of(views),
            "copies": COPIES.get(name, 1), "scale": SHED_SCALE, "wash_scale": 1.0, "fill": fill_of(front),
            "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
        })
    book["sheets"][CLEAN] = {"file": "res://assets/decor_pack_clean.png", "size": list(clean_sheet.size)}
    book["sheets"][DIRTY] = {"file": "res://assets/decor_pack_dirty.png", "size": list(dirty_sheet.size)}
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8", newline="\n")
    print("%d pieces, %d views; clean %s dirty %s" % (len(plan), len(clean), clean_sheet.size, dirty_sheet.size))


if __name__ == "__main__":
    main()

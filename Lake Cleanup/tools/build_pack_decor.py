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
    "tree": [4, 0, 25, 53],
}

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
        (412, None, F, 0, 0, 0), (413, None, "front_open", 0, 1, 0), (414, None, B, 1, 0, 0)]),
    ("fancy_bed", "Fancy Bed", "ROTATE", "floor", "", [
        (443, None, F, 0, 0, 0), (445, None, S, 1, 0, 1), (444, None, B, 2, 0, 0)]),
    ("fancy_table", "Fancy Table", "ROTATE", "floor", "", [
        (395, None, F, 0, 0, 0), (394, None, S, 1, 0, 0)]),
    ("file_cabinet", "File Cabinet", "ROTATE", "floor", "", [
        (1324, None, F, 0, 0, 0), (1323, None, "front_open", 0, 1, 0), (1325, None, S, 1, 0, 1)]),
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
    ("rug", "Gold Rug", "SINGLE", "floor", "", [(300, None, F, 0, 0, 0)]),
    ("coat_stand", "Coat Stand", "SINGLE", "floor", "", [(328, None, F, 0, 0, 0)]),
    ("landscape", "Landscape", "SINGLE", "wall", "", [(385, None, F, 0, 0, 0)]),
    ("portrait", "Portrait", "SINGLE", "wall", "", [(389, None, F, 0, 0, 0)]),
    ("grandfather_clock", "Grandfather Clock", "SINGLE", "floor", "", [(427, None, F, 0, 0, 0)]),
    ("globe", "Globe", "SINGLE", "floor", "", [(430, None, F, 0, 0, 0)]),
    ("sculpture", "Sculpture", "SINGLE", "floor", "", [(1146, None, F, 0, 0, 0)]),
    ("blue_rug", "Blue Rug", "SINGLE", "floor", "", [(1172, None, F, 0, 0, 0)]),
    # The second batch (2026-10-01).
    ("fridge", "Fridge", "ROTATE", "floor", "cold", [
        (1049, None, F, 0, 0, 0), (1050, None, "front_open", 0, 1, 0),
        (1052, None, S, 1, 0, 1), (1054, CUT["fridge_side_open"], "side_open", 1, 1, 1)]),
    ("side_desk", "Side Desk", "ROTATE", "floor", "", [
        (1150, None, F, 0, 0, 0), (1149, None, "front_open", 0, 1, 0),
        (1153, None, S, 1, 0, 1), (1152, None, B, 2, 0, 0)]),
    ("sink", "Sink", "ROTATE", "floor", "", [
        (2008, None, F, 0, 0, 0), (2010, None, S, 1, 0, 1), (2009, None, B, 2, 0, 0)]),
    ("diner_table", "Diner Table", "SINGLE", "floor", "", [(4, None, F, 0, 0, 0)]),
    ("flower_vase", "Flower Vase", "SINGLE", "small", "", [(361, None, F, 0, 0, 0)]),
    ("flower_pot", "Flower Pot", "SINGLE", "floor", "", [(505, None, F, 0, 0, 0)]),
    ("car_picture", "Car Picture", "SINGLE", "wall", "", [(964, None, F, 0, 0, 0)]),
    ("dotted_rug", "Dotted Rug", "SINGLE", "floor", "", [(1192, None, F, 0, 0, 0)]),
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
    ("table_lamp", "Table Lamp", "SINGLE", "small", "", [(1064, None, F, 0, 0, 0)]),
    # The record player is the old find's own entry, re-drawn (see REPLACES): lid down from
    # above (2222), lid up (2214). The menu E opens is drawn in these colours.
    ("record_player", "Record player", "STATE", "small", "", [
        (2222, None, "closed", 0, 0, 0), (2214, None, "open", 0, 1, 0)]),
]

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
}
SIDE_ROLES = ("side", "top")


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


def main():
    cat = {e["id"]: e for e in json.loads((PACKS / "catalogue.json").read_text())}
    sheets = {}

    def cut(oid, box):
        e = cat[oid]
        if e["sheet"] not in sheets:
            sheets[e["sheet"]] = Image.open(PACKS / e["sheet"]).convert("RGBA")
        x, y, w, h = e["box"]
        im = sheets[e["sheet"]].crop((x, y, x + w, y + h))
        if box:
            im = im.crop((box[0], box[1], box[2] + 1, box[3] + 1))
        return im.crop(im.getbbox())

    clean, dirty, plan = [], [], []
    for name, title, kind, place, light, views in PIECES:
        roles, faces, states, ims = [], [], [], []
        top = max(v[3] for v in views)
        mirrored = []
        for oid, box, role, face, state, mirror in views:
            ims.append(cut(oid, box)); roles.append(role); faces.append(face); states.append(state)
        # A face's on view shares one frame with its off view, slid to where they match,
        # so switching it (E) never moves the piece: the open fridge's door swings out of
        # the same body. Only a piece that turns is aligned; a switch of one face (the
        # fireplace) is two pictures of the same size already.
        for i in range(len(ims)):
            if states[i] == 1:
                j = next((j for j in range(len(ims)) if faces[j] == faces[i] and states[j] == 0), None)
                if j is not None:
                    ims[j], ims[i] = shared_frame(ims[j], ims[i])
        for i, (oid, box, role, face, state, mirror) in enumerate(views):
            if mirror:
                mirrored.append((ims[i].transpose(Image.FLIP_LEFT_RIGHT), role + "_r", state))
        for k, (im, role, state) in enumerate(mirrored):
            ims.append(im); roles.append(role); states.append(state)
            # one new face for the mirrored side; both states of it share it
            faces.append(top + 1)
        first = len(clean)
        clean.extend(ims)
        dirty.append(grime(ims[0], name))
        plan.append((name, title, kind, place, light, roles, faces, states, first, len(ims), ims[0], views))

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
            "faces": faces, "states": states, "base": [], "seat": [],
            "base_px": [] if place == "wall" else bases_of(name, roles, [b[3] for b in clean_boxes[first:first + n]]),
            "tier": tier_of(views),
            "copies": 1, "scale": SHED_SCALE, "wash_scale": 1.0, "fill": fill_of(front),
            "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
        })
    book["sheets"][CLEAN] = {"file": "res://assets/decor_pack_clean.png", "size": list(clean_sheet.size)}
    book["sheets"][DIRTY] = {"file": "res://assets/decor_pack_dirty.png", "size": list(dirty_sheet.size)}
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8", newline="\n")
    print("%d pieces, %d views; clean %s dirty %s" % (len(plan), len(clean), clean_sheet.size, dirty_sheet.size))


if __name__ == "__main__":
    main()

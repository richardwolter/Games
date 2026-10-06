"""Build the lake's rubbish from the 0_mem0ry packs, as tagged on the Lake Pack Tagger.

Inputs (all but the last git-ignored with the packs, whose licence forbids
redistributing them):
  art_source/packs_local/catalogue.json      every cut object (tools/cut_packs.py)
  art_source/packs_local/tagger/pull/packs/  the tagger's saved tags (ArtifactData list)

A kind is its art, its material and its tier. Pay is resources/economy.tres's price table
and the fill's tier mix is LakeGrid.TIER_BY_DEPTH; nothing per kind is fitted.

Writes:
  assets/lake_objects.png                    the 121 sprites, packed
  assets/pieces.json                         the lake_objects entries replaced
  resources/trash/<slug>.tres                one per kind; old kinds' files removed
  scripts/lake.gd TRASH_ORDER                rewritten to the new kinds
  tools/pack_rubbish.json                    slug -> pack object, material, tier (no pixels)

Names: a kind is <material>_<noun>, and look-alikes share a noun with a trailing
number (metal_soda1..3), because LakeGrid.family_of reads a trailing number as
"another one of these" for the surface's anti-repeat.

    base python + ComfyUI site-packages (PIL), from the project root
"""
import glob, json, re, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"
PULL = PACKS / "tagger/pull/packs"
SHEET = "lake_objects"
SHEET_PNG = ROOT / "assets/lake_objects.png"
CATALOGUE = ROOT / "assets/pieces.json"
TRASH = ROOT / "resources/trash"
LAKE_GD = ROOT / "scripts/lake.gd"
WIDTH = 256
GAP = 2
KIND = {"plastic": 0, "wood": 1, "metal": 2, "rubber": 3}
YARD = {"plastic": "Plastic", "wood": "Wood", "metal": "Metal", "rubber": "Rubber"}
BLOCK = {"plastic": "Color(0.45, 0.62, 0.8, 1)", "wood": "Color(0.6, 0.42, 0.26, 1)",
         "metal": "Color(0.6, 0.66, 0.7, 1)", "rubber": "Color(0.25, 0.25, 0.25, 1)"}

# Pack object id -> noun. The material prefix comes from the tag.
NOUNS = {
    # metal
    88: "tin1", 89: "tin2", 1543: "tin3", 179: "can1", 186: "can2", 192: "can3",
    214: "soda1", 224: "soda2", 1122: "soda3", 1291: "clock", 1337: "pc_tower",
    1418: "phone1", 1405: "phone2", 1694: "jar", 1733: "pliers", 1408: "keypad",
    1587: "pipe", 1622: "bolt", 1675: "canister", 1689: "toolbox", 1738: "square",
    143: "kettle", 1238: "boombox", 1453: "pole", 1748: "lamp", 80: "gas_bottle",
    930: "case", 1209: "desk_lamp", 1664: "shelf", 1762: "valve", 107: "camp_chair",
    519: "barrel1", 1644: "barrel2", 1406: "bin", 1505: "chair",
    # plastic
    71: "mug1", 1429: "mug2", 81: "bottle1", 1535: "bottle2", 936: "bottle3", 2200: "bottle4",
    170: "jar", 1016: "bag1", 1022: "bag2", 1372: "frame", 1651: "sign1", 1654: "sign2",
    1813: "cup", 1812: "cups", 2302: "nutcracker", 2342: "cracker", 174: "sauce",
    642: "bucket1", 643: "bucket2", 1207: "glass", 371: "vase", 1057: "lamp", 2323: "gnome",
    2355: "ornament", 945: "milk", 974: "laptop", 1003: "chair", 1402: "jug1", 1536: "jug2",
    1495: "jerrycan",
    # rubber
    1017: "bag1", 1478: "bag2", 1711: "cables", 1749: "plug", 365: "clock", 928: "gamepad",
    1369: "cassette", 1555: "gas_mask1", 1565: "gas_mask2", 1750: "eraser", 1753: "screwdriver",
    1834: "knife", 2111: "candy", 1090: "shoes", 1094: "sock", 1119: "ketchup", 1476: "mat",
    1477: "ring", 1566: "jacket1", 1576: "jacket2", 448: "barrel", 1021: "ball", 1214: "vase",
    1540: "dome", 2347: "clover", 958: "laptop", 963: "tablet", 1464: "tire1", 1465: "tire2",
    2244: "puck",
    # wood
    1306: "hook", 1701: "sticks", 1723: "block", 1724: "scrap", 1730: "stick", 2303: "nutcracker",
    150: "log1", 149: "log2", 934: "peg", 1031: "fence1", 1030: "fence2", 1062: "stool", 1083: "drawer1",
    1084: "drawer2", 1732: "tile", 1036: "frames", 1059: "chair", 1469: "pallet1",
    1460: "pallet2", 1728: "splinter", 1037: "painting1", 1177: "painting2", 293: "frame1", 295: "frame2",
    1043: "wardrobe", 1068: "floor_lamp", 927: "table", 1662: "desk",
    587: "stake", 902: "branch", 1346: "bench",
    # second pick (2026-10-01): more variety
    156: "sleeping_bag", 171: "cap", 1163: "speaker", 1466: "tire3",
    1472: "sheet1", 1696: "sheet2", 1758: "socket",
    1391: "jug3", 1397: "office_chair", 1615: "crates", 1837: "bottle5", 1934: "mop_bucket",
    # third pick (2026-10-01): more variety
    136: "stove", 227: "crate", 282: "bank_lamp", 516: "barrel3", 521: "barrel4",
    1010: "bin2", 1697: "can4",
    91: "flask", 167: "pot", 382: "pendant", 415: "vase2", 434: "glass2", 922: "poster",
    935: "bottle6", 1004: "chair2", 1715: "bottle7", 1718: "bottle8",
    85: "roll1", 106: "roll2", 199: "crate", 333: "pillows", 446: "barrel2", 715: "tire4",
    720: "tire5", 1264: "scrap", 1380: "crumb", 1695: "rod",
    144: "stump1", 151: "stump2", 298: "plant", 360: "picture1", 369: "picture2",
    582: "stake2", 970: "boxes", 1048: "cabinet", 1174: "table2", 1233: "shelf",
    1308: "candle", 1678: "brushes", 1693: "rod",
    # fourth pick (2026-10-01)
    6: "lamp_globe", 32: "clock2", 58: "tap", 59: "hob", 84: "shovel", 99: "locker",
    139: "kettle2", 383: "candelabra", 525: "barrel5", 931: "bar", 1012: "bin3", 1015: "rod",
    1102: "oven", 1248: "stand", 1318: "desk",
    929: "packet", 946: "cup2", 957: "cooler", 983: "crate", 989: "cabinet", 1055: "bucket3",
    1075: "floor_lamp", 1086: "slipper", 1104: "ironing_board", 1121: "bottle9", 1192: "rug",
    1198: "lamp2", 1336: "computer", 1492: "heater", 1501: "jerrycan2",
    904: "screen", 1245: "slick", 1246: "lump", 1266: "rubble", 1278: "slab", 1281: "blocks",
    1282: "pebble", 1358: "badge", 1485: "mattress", 1520: "pebble2", 1588: "jacket3",
    1668: "clamp", 1754: "screwdriver2", 2170: "chair", 2253: "strip", 2330: "stain",
    145: "log3", 337: "ladder", 885: "door", 995: "planter", 1063: "lamp", 1143: "wardrobe2",
    1206: "chair2", 1218: "door2", 1304: "pencil", 1345: "desk2", 1367: "table3", 1381: "chair3",
    1704: "brush", 1722: "plank", 1752: "bench2", 1846: "plaque", 2325: "spoon",
    1239: "aircon", 1368: "water_jug",
}


def tags():
    out = {}
    for f in glob.glob(str(PULL / "*.json")):
        d = json.loads(Path(f).read_text())
        d = d.get("data", d)
        for k, v in d["items"].items():
            if v.get("r") == "r":
                out[int(k)] = v
    return out


def kinds():
    cat = {e["id"]: e for e in json.loads((PACKS / "catalogue.json").read_text())}
    got = tags()
    missing = sorted(set(got) - set(NOUNS))
    if missing:
        sys.exit("tagged rubbish with no noun: %s" % missing)
    rows = []
    for oid, t in got.items():
        if "m" not in t or "t" not in t:
            sys.exit("object %d is rubbish with no material or tier" % oid)
        slug = "%s_%s" % (t["m"], NOUNS[oid])
        rows.append({"slug": slug, "id": oid, "material": t["m"], "tier": int(t["t"]),
                     "sheet": cat[oid]["sheet"], "box": cat[oid]["box"], "flip": bool(t.get("f"))})
    order = ["metal", "plastic", "rubber", "wood"]
    rows.sort(key=lambda r: (order.index(r["material"]), r["tier"], r["slug"]))
    slugs = [r["slug"] for r in rows]
    if len(set(slugs)) != len(slugs):
        sys.exit("two kinds share a name")
    return rows


def pack(sprites):
    spots, x, y, row = {}, 0, 0, 0
    for slug, im in sorted(sprites.items(), key=lambda kv: -kv[1].height):
        if x + im.width > WIDTH:
            x, y, row = 0, y + row + GAP, 0
        spots[slug] = [x, y, im.width, im.height]
        x += im.width + GAP
        row = max(row, im.height)
    sheet = Image.new("RGBA", (WIDTH, y + row), (0, 0, 0, 0))
    for slug, im in sprites.items():
        sheet.paste(im, tuple(spots[slug][:2]))
    return sheet, spots


def fill_of(im):
    a = im.getchannel("A")
    return round(sum(1 for v in a.getdata() if v > 0) / (im.width * im.height), 3)


def title(slug):
    noun = slug.split("_", 1)[1]
    return re.sub(r"\d+$", "", noun).replace("_", " ").title()


def write_tres(r):
    w, h = r["box"][2], r["box"][3]
    (TRASH / ("%s.tres" % r["slug"])).write_text(
        '[gd_resource type="Resource" script_class="TrashDef" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/trash_def.gd" id="1_trash"]\n\n'
        '[resource]\nscript = ExtResource("1_trash")\n'
        'display_name = "%s"\nmaterial = %d\npiece = &"%s"\nsize = Vector2(%d, %d)\n'
        'tier = %d\nblock_color = %s\n'
        % (title(r["slug"]), KIND[r["material"]], r["slug"], w, h, r["tier"],
           BLOCK[r["material"]]), encoding="utf-8", newline="\n")


def rewrite_order(slugs):
    src = LAKE_GD.read_text(encoding="utf-8")
    start = src.index("const TRASH_ORDER := [")
    end = src.index("\n]\n", start) + 3
    lines, line = [], "\t"
    for s in slugs:
        item = '"%s", ' % s
        if len(line) + len(item) > 92:
            lines.append(line.rstrip())
            line = "\t"
        line += item
    lines.append(line.rstrip())
    body = ("const TRASH_ORDER := [\n\t# The 0_mem0ry packs' rubbish, tagged on the Lake Pack Tagger "
            "(tools/build_pack_rubbish.py).\n" + "\n".join(lines) + "\n]\n")
    src = src[:start] + body + src[end:]
    LAKE_GD.write_text(src, encoding="utf-8", newline="")


def main():
    rows = kinds()
    sheets, sprites = {}, {}
    for r in rows:
        if r["sheet"] not in sheets:
            sheets[r["sheet"]] = Image.open(PACKS / r["sheet"]).convert("RGBA")
        x, y, w, h = r["box"]
        sprites[r["slug"]] = sheets[r["sheet"]].crop((x, y, x + w, y + h))
        # "Flip" on the tagger: the object faces the other way in the lake.
        if r["flip"]:
            sprites[r["slug"]] = sprites[r["slug"]].transpose(Image.FLIP_LEFT_RIGHT)
    sheet, spots = pack(sprites)
    sheet.save(SHEET_PNG)

    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    cell = book.get("cell", 8)
    kept = [p for p in book["pieces"] if p["sheet"] != SHEET]
    taken = {p["name"] for p in kept}
    new = []
    for r in rows:
        if r["slug"] in taken:
            sys.exit("%s is already in the catalogue on another sheet" % r["slug"])
        box = spots[r["slug"]]
        new.append({"name": r["slug"], "display_name": title(r["slug"]), "yard": YARD[r["material"]],
                    "sheet": SHEET, "region": box,
                    "cells": [max(1, -(-box[2] // cell)), max(1, -(-box[3] // cell))],
                    "fill": fill_of(sprites[r["slug"]])})
    book["pieces"] = kept + new
    book["sheets"][SHEET] = {"file": "res://assets/lake_objects.png", "size": list(sheet.size)}
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8", newline="\n")

    slugs = [r["slug"] for r in rows]
    for old in TRASH.glob("*.tres"):
        if old.stem not in slugs:
            old.unlink()
    for r in rows:
        write_tres(r)
    rewrite_order(slugs)
    (ROOT / "tools/pack_rubbish.json").write_text(json.dumps(
        [{k: r[k] for k in ("slug", "id", "material", "tier", "sheet", "box", "flip")} for r in rows], indent=1))
    print("sheet %dx%d, %d kinds" % (sheet.width, sheet.height, len(rows)))


if __name__ == "__main__":
    main()

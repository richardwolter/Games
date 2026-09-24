#!/usr/bin/env python
"""Turn art_source/New_Objects_Lake.psd into the lake's rubbish sheet and its catalogue entries.

The PSD is the one source for every kind of rubbish in the lake (2026-09-21, Richard). It
replaced two sheets: the first 27 kinds, whose regions were cut once by a since-deleted
slicer and corrected by hand, and a second batch of ten off an older copy of this PSD.
Every kept kind was paired to its old sprite by pixels before the switch.

Layers are matched to slugs by name and left-to-right position, not by name alone: the PSD
holds five layers called 'Rubber Toy', and a lookup keyed on the name would silently pack
one of them five times. A repeated name is a numbered family (`rubber_toy`, then
`rubber_toy2`..), which `LakeGrid.family_of` reads as look-alikes for the surface's
anti-repeat — by decision, over giving each its own name.

**The numbering is by position, so moving a layer across the canvas in the PSD can swap
two slugs.** A slug is an index into the save's stacks (through `Lake.TRASH_ORDER`); the
builder prints every slug beside its layer's x so a swap shows up in the run's output.

Input:
  art_source/New_Objects_Lake.psd

Output:
  assets/lake_objects.png            every piece, despecked and packed
  assets/pieces.json                 the 'lake_objects' pieces, replacing any older run
                                     (and the retired 'lake_objects_new' sheet's)

Run from the project root, then reimport:
  <psd-extract venv python> tools/build_lake_objects.py
"""
import json
import sys
from pathlib import Path

from PIL import Image
from psd_tools import PSDImage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_decor import CELL, despeck, fill_of, pack  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PSD = ROOT / "art_source" / "New_Objects_Lake.psd"
CATALOGUE = ROOT / "assets" / "pieces.json"
SHEET_PNG = ROOT / "assets" / "lake_objects.png"
SHEET = "lake_objects"
RETIRED = ["lake_objects_new"]

## Layer name -> the slugs its layers take, left to right on the canvas. The yard is the
## material the slug starts with. A name the PSD spells oddly is keyed as spelled.
SLUGS = {
    "Metal Can1": ["metal_can1"], "Metal Can2": ["metal_can2"],
    "Metal Can3": ["metal_can3"], "Metal Can4": ["metal_can4"],
    "Metal Hanger": ["metal_hanger"], "Metal Lamp": ["metal_lamp"],
    "Metal Mirror": ["metal_mirror2", "metal_mirror"],
    "Metal Pan": ["metal_pan"],
    "Metal Phone": ["metal_phone", "metal_phone2"],
    "Metal Pot": ["metal_pot", "metal_pot2"],
    "Metal Support": ["metal_support"], "Metal Teapot": ["metal_teapot"],
    "Metal Bar": ["metal_bar"],
    "MEtal Box": ["metal_box1", "metal_box2"],
    "Metal Cart": ["metal_cart"],
    "Metal blah": ["metal_controller"],
    "Metal Dumbell": ["metal_dumbell"],
    "Metal Extinguisher": ["metal_extinguisher"],
    "Metal Radio": ["metal_radio"],
    "Metal Shaker": ["metal_shaker"],
    "Metal Sound": ["metal_sound"],
    "Plastic Bowl": ["plastic_bowl"], "Plastic Cup1": ["plastic_cup1"],
    "Plastic Cup2": ["plastic_cup2"], "Plastic Frame": ["plastic_frame"],
    "Plastic Mug": ["plastic_mug"], "Plastic Plate": ["plastic_plate"],
    "Plastic Sheet": ["plastic_sheet"], "Plastic Wrap": ["plastic_wrap"],
    "Plastic Sign": ["plastic_sign2", "plastic_sign"],
    "Plastic Bottle": ["plastic_bottle"],
    "Plastic Bottles": ["plastic_bottles"],
    "Plastic Chair": ["plastic_chair"],
    "Plastic Toy": ["plastic_toy1", "plastic_toy2", "plastic_toy3", "plastic_toy4",
                    "plastic_toy5"],
    "Plastic Vase": ["plastic_vase"],
    "Rubber Ball": ["rubber_ball", "rubber_ball2", "rubber_ball3", "rubber_ball4"],
    "Rubber Block": ["rubber_block"], "Rubber Disk": ["rubber_disk"],
    "Rubber Duck": ["rubber_duck"],
    "Rubber Tire": ["rubber_tire2", "rubber_tire"],
    "Rubber Toy": ["rubber_toy2", "rubber_toy3", "rubber_toy4", "rubber_toy5",
                   "rubber_toy"],
    "Rubber Shoes": ["rubber_shoes"],
    "Rubber Utensil": ["rubber_utensil"],
    "Wood Box1": ["wood_box1"], "Wood Box2": ["wood_box2"],
    "Wood Box": ["wood_box3", "wood_box4", "wood_box5"],
    "Wood Painting1": ["wood_painting1"], "Wood Painting2": ["wood_painting2"],
    "Wood Piece": ["wood_piece"],
    "Wood Block": ["wood_block"], "Wood Board": ["wood_board"],
    "Wood Chair": ["wood_chair"], "Wood Door": ["wood_door"],
    "Wood Drawer": ["wood_drawer"], "Wood Guitar": ["wood_guitar"],
    "Wood Lamp": ["wood_lamp"],
    "Wood Plank": ["wood_plank1", "wood_plank2"],
    "Wood Sign": ["wood_sign"], "Wood Skateboard": ["wood_skateboard"],
    "Wood Stool": ["wood_stool"], "Wood Toy": ["wood_toy"],
}
YARDS = {"wood": "Wood", "metal": "Metal", "plastic": "Plastic", "rubber": "Rubber"}


## The angler's outline is pure black; the rubbish was painted with tinted ones (slate, maroon)
## that read softer beside him (2026-09-24, Richard: "the same outline as the player has").
## Every silhouette pixel darker than OUTLINE_UNDER goes black; a lit edge pixel keeps its
## colour, since that is the painted highlight and not the line.
OUTLINE_INK = (0, 0, 0, 255)
OUTLINE_UNDER = 110


def ink_outline(im):
    px = im.load()
    w, h = im.size
    edge = []
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] == 0 or 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] >= OUTLINE_UNDER:
                continue
            if any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for spot in edge:
        px[spot] = OUTLINE_INK
    return im


def main():
    psd = PSDImage.open(PSD)
    layers = {}
    for layer in psd.descendants():
        if layer.is_group():
            continue
        layers.setdefault(layer.name.strip(), []).append(layer)
    unknown = set(layers) - set(SLUGS)
    if unknown:
        sys.exit("layers with no slug: %s" % ", ".join(sorted(unknown)))

    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    titles = {p["name"]: p["display_name"] for p in book["pieces"] if "display_name" in p}
    sprites = {}
    xs = {}
    for name, slugs in SLUGS.items():
        found = sorted(layers.get(name, []), key=lambda l: l.bbox[0])
        if len(found) != len(slugs):
            sys.exit("layer %r: expected %d, found %d" % (name, len(slugs), len(found)))
        for layer, slug in zip(found, slugs):
            im = despeck(layer.composite().convert("RGBA"))
            if im is None:
                sys.exit("layer %r (%s) is empty" % (name, slug))
            im = ink_outline(im)
            sprites[slug] = im
            xs[slug] = layer.bbox[0]
            titles.setdefault(slug, slug.replace("_", " ").title())

    sheet, spots = pack(sprites)
    sheet.save(SHEET_PNG)

    gone = {SHEET, *RETIRED}
    kept = [p for p in book["pieces"] if p["sheet"] not in gone]
    taken = {p["name"] for p in kept}
    pieces = []
    for slug in slug_order():
        if slug in taken:
            sys.exit("%s is already in the catalogue on another sheet" % slug)
        box = spots[slug]
        pieces.append({
            "name": slug,
            "display_name": titles[slug],
            "yard": YARDS[slug.split("_", 1)[0]],
            "sheet": SHEET,
            "region": box,
            "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
            "fill": fill_of(sprites[slug]),
        })
    book["pieces"] = kept + pieces
    for old in RETIRED:
        book["sheets"].pop(old, None)
    book["sheets"][SHEET] = {"file": "res://assets/lake_objects.png", "size": list(sheet.size)}
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8")

    for slug in slug_order():
        print("%-20s x %4d  %s" % (slug, xs[slug], spots[slug]))
    print("sheet %dx%d, %d pieces; catalogue %d kept + %d rubbish" % (
        sheet.width, sheet.height, len(pieces), len(kept), len(pieces)))


def slug_order():
    return [s for slugs in SLUGS.values() for s in slugs]


if __name__ == "__main__":
    main()

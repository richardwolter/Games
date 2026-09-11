#!/usr/bin/env python
"""Turn art_source/New_Objects_Lake into a packed rubbish sheet and its catalogue entries.

The first 27 kinds of rubbish live on assets/lake_objects.png, whose regions were cut once
and have been corrected since; nothing here touches that sheet. The second batch goes on
its own sheet, so re-running this can never move a region the first batch depends on.

Layers are matched to slugs by name and left-to-right position, not by name alone: the
PSD holds two layers called 'Wood Painting', and a lookup keyed on the name would silently
pack one of them twice.

Input:
  art_source/New_Objects_Lake        the PSD (no extension)

Output:
  assets/lake_objects_new.png        every piece, despecked and packed
  assets/pieces.json                 the 'lake_objects_new' pieces, replacing any older run

Run from the project root:
  <psd-extract venv python> tools/build_lake_objects_new.py
"""
import json
import sys
from pathlib import Path

from PIL import Image
from psd_tools import PSDImage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_decor import CELL, despeck, fill_of, pack  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PSD = ROOT / "art_source" / "New_Objects_Lake"
CATALOGUE = ROOT / "assets" / "pieces.json"
SHEET_PNG = ROOT / "assets" / "lake_objects_new.png"
SHEET = "lake_objects_new"

## Layer name -> the slugs its layers take, left to right on the canvas. The yard is the
## material the name starts with, the same split the first batch uses.
SLUGS = {
    "Wood Painting": ["wood_painting3", "wood_painting4"],
    "Metal Lamp": ["metal_lamp"],
    "Metal Mirror": ["metal_mirror"],
    "Plastic Sign": ["plastic_sign"],
    "Plastic Frame": ["plastic_frame"],
    "Plastic Toy": ["plastic_toy"],
    "Plastic Globe": ["plastic_globe"],
    "Rubber Block": ["rubber_block"],
    "Rubber Toy": ["rubber_toy"],
}
YARDS = {"wood": "Timber", "metal": "Metal", "plastic": "Plastic", "rubber": "Rubber"}


def main():
    psd = PSDImage.open(PSD)
    layers = {}
    for layer in psd.descendants():
        if layer.is_group():
            continue
        layers.setdefault(layer.name, []).append(layer)

    sprites = {}
    titles = {}
    for name, slugs in SLUGS.items():
        found = sorted(layers.get(name, []), key=lambda l: l.bbox[0])
        if len(found) != len(slugs):
            sys.exit("layer %r: expected %d, found %d" % (name, len(slugs), len(found)))
        for layer, slug in zip(found, slugs):
            im = despeck(layer.composite().convert("RGBA"))
            if im is None:
                sys.exit("layer %r (%s) is empty" % (name, slug))
            sprites[slug] = im
            titles[slug] = slug.replace("_", " ").title()
    unknown = set(layers) - set(SLUGS)
    if unknown:
        sys.exit("layers with no slug: %s" % ", ".join(sorted(unknown)))

    sheet, spots = pack(sprites)
    sheet.save(SHEET_PNG)

    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    kept = [p for p in book["pieces"] if p["sheet"] != SHEET]
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
    book["sheets"][SHEET] = {
        "file": "res://assets/lake_objects_new.png", "size": list(sheet.size)
    }
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8")

    for slug in slug_order():
        print("%-16s %s" % (slug, spots[slug]))
    print("sheet %dx%d, %d pieces; catalogue %d kept + %d new" % (
        sheet.width, sheet.height, len(pieces), len(kept), len(pieces)))


def slug_order():
    return [s for slugs in SLUGS.values() for s in slugs]


if __name__ == "__main__":
    main()

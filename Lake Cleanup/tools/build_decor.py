#!/usr/bin/env python
"""Turn the decoration PSD into two packed sheets and the decor half of pieces.json.

The lake shows a find grimy and the shed shows it restored, and those are no longer the
same picture twice: the dirty sofa is 22x55 and the clean one is three views, the widest
49 across. So the two go onto two sheets and every piece carries its own rectangle in
each, rather than one rectangle read against a parallel sheet the way the old
TopDownHouse pair worked.

Input:
  art_source/decoration_extracted/   one PNG per PSD layer, from the psd-extract skill
  tools/decor_sets.json              the authored catalogue: roles, kinds, slice rects

Output:
  assets/decor_clean.png             every clean view, packed
  assets/decor_dirty.png             one grimy sprite per find, packed
  assets/pieces.json                 the 'decor' pieces replacing the old 'furniture' ones

Run from the project root:
  <psd-extract venv python> tools/build_decor.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LAYERS = ROOT / "art_source" / "decoration_extracted"
TABLE = ROOT / "tools" / "decor_sets.json"
CATALOGUE = ROOT / "assets" / "pieces.json"
CLEAN_PNG = ROOT / "assets" / "decor_clean.png"
DIRTY_PNG = ROOT / "assets" / "decor_dirty.png"

CLEAN_SHEET = "decor_clean"
DIRTY_SHEET = "decor_dirty"

## The sheets the decoration art replaces. Their pieces are dropped from the catalogue.
RETIRED_SHEETS = ("furniture",)

## A gutter between packed sprites, in pixels.
##
## The atlas is sampled unfiltered and every region is whole pixels, so one column would
## do. Two costs nothing and leaves room to be wrong about that.
PAD = 2

## How close to the art an island has to be, in pixels, to count as part of it.
##
## The dirty 'Bath Sink' layer is a 19x29 sink with an 8-pixel fleck 150px away, which puts
## the layer's bounding box at 172x86 and packs a mostly-empty rectangle into the atlas.
## Drawn in the lake that reads as an invisible wall behind the object: it covers what is
## behind it and it eats clicks meant for the water. Godot's own trimming would not help,
## because as far as the file is concerned those pixels are art.
##
## Sizing the fleck was the wrong rule to reach for first — at eight pixels it is bigger
## than plenty of real detail, and a threshold that dropped it would drop a chair's foot.
## What actually separates the two is distance: the parts of one object touch, or nearly.
## So the largest island is the object, anything within this of what has been kept joins
## it, and whatever is left over is somebody else's stray pixel.
GLUE = 4

## The grid the shed measures footprints against, and the fill fraction below which a piece
## is treated as mostly holes. Both match the old slicer so the catalogue stays one shape.
CELL = 16


def islands(im):
    """Every run of touching opaque pixels, as [x0, y0, x1, y1, count] boxes."""
    from collections import deque

    w, h = im.size
    a = im.split()[3].load()
    seen = bytearray(w * h)
    out = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or a[sx, sy] == 0:
                continue
            q = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            x0 = x1 = sx
            y0 = y1 = sy
            n = 0
            while q:
                cx, cy = q.popleft()
                n += 1
                x0, x1 = min(x0, cx), max(x1, cx)
                y0, y1 = min(y0, cy), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            if not seen[ny * w + nx] and a[nx, ny] > 0:
                                seen[ny * w + nx] = 1
                                q.append((nx, ny))
            out.append([x0, y0, x1 + 1, y1 + 1, n])
    return out


def despeck(im):
    """Crop to the one object in this layer, leaving strays behind.

    The largest island, grown by whatever is within GLUE of it, grown again until nothing
    new joins. Returns the cropped image, or None for a layer with no pixels at all.
    """
    found = islands(im)
    if not found:
        return None
    found.sort(key=lambda b: -b[4])
    x0, y0, x1, y1 = found[0][:4]
    rest = found[1:]
    joined = True
    while joined:
        joined = False
        for b in list(rest):
            if (x0 - GLUE < b[2] and b[0] - GLUE < x1
                    and y0 - GLUE < b[3] and b[1] - GLUE < y1):
                x0, y0 = min(x0, b[0]), min(y0, b[1])
                x1, y1 = max(x1, b[2]), max(y1, b[3])
                rest.remove(b)
                joined = True
    return im.crop((x0, y0, x1, y1))


def load_layer(slug, cache, missing_ok=False):
    if slug not in cache:
        path = LAYERS / (slug + ".png")
        if not path.exists():
            if missing_ok:
                return None
            sys.exit("missing layer PNG: %s" % path)
        cache[slug] = Image.open(path).convert("RGBA")
    return cache[slug]


def rubbish_sprite(book, slug, cache):
    """One rubbish kind's own picture, cut off the lake sheet it lives on.

    A find born from the rubbish (the paintings, the chew toy, the globe — Richard,
    2026-09-13) has no dirty layer in the decoration PSD: what the lake shows is the
    rubbish kind itself, and the kind stays in the fill as well. So its grimy sprite is a
    copy of that region, packed onto the dirty sheet like any other find's, which keeps
    `Sheets.by_sheet["decor_dirty"]` the one list of finds.
    """
    for piece in book["pieces"]:
        if piece["name"] == slug:
            sheet = book["sheets"][piece["sheet"]]
            key = "sheet:" + piece["sheet"]
            if key not in cache:
                path = ROOT / sheet["file"].replace("res://", "")
                cache[key] = Image.open(path).convert("RGBA")
            x, y, w, h = piece["region"]
            return cache[key].crop((x, y, x + w, y + h))
    sys.exit("no rubbish kind called %s in the catalogue" % slug)


def fill_of(im):
    """How much of its own box a sprite covers, 0 to 1. A rug fills it, a chair does not."""
    a = im.split()[3].load()
    w, h = im.size
    n = sum(1 for y in range(h) for x in range(w) if a[x, y] > 0)
    return round(n / float(w * h), 3)


def pack(sprites):
    """Lay sprites out in shelves, tallest first. Returns (image, {key: [x, y, w, h]}).

    A shelf packer rather than anything cleverer: there are a few dozen sprites, the sheet
    is built once offline, and wasted atlas space costs nothing anybody can measure.
    """
    order = sorted(sprites.items(), key=lambda kv: -kv[1].height)
    width = max(im.width for _, im in order) + PAD * 2
    width = max(width, 256)
    x = y = PAD
    row_high = 0
    spots = {}
    for key, im in order:
        if x + im.width + PAD > width:
            x = PAD
            y += row_high + PAD
            row_high = 0
        spots[key] = [x, y, im.width, im.height]
        x += im.width + PAD
        row_high = max(row_high, im.height)
    height = y + row_high + PAD
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for key, im in order:
        sx, sy = spots[key][0], spots[key][1]
        sheet.paste(im, (sx, sy), im)
    return sheet, spots


## Where a find may go. See tools/decor_sets.json.
PLACES = ("floor", "wall", "small")


def main():
    table = json.loads(TABLE.read_text(encoding="utf-8"))
    entries = table["entries"]
    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))

    cache = {}
    clean_sprites = {}
    dirty_sprites = {}
    view_keys = {}
    fills = {}

    for e in entries:
        name = e["name"]
        views = e["views"]
        if not views:
            sys.exit("%s has no views" % name)
        if e["kind"] != "SINGLE" and len(views) < 2:
            sys.exit("%s is %s but has one view" % (name, e["kind"]))
        if e["kind"] == "SINGLE" and len(views) != 1:
            sys.exit("%s is SINGLE but has %d views" % (name, len(views)))
        if e["mirror"] and len(views) != 3:
            sys.exit("%s asks for a mirror but is not a three-view set" % name)
        if int(e.get("copies", 1)) < 1:
            sys.exit("%s asks for %s copies" % (name, e.get("copies")))
        if e.get("place", "floor") not in PLACES:
            sys.exit("%s is placed '%s'; one of %s" % (name, e.get("place"), PLACES))
        faces = len(views) + (1 if e["mirror"] else 0)
        bases = e.get("base")
        if bases is not None and len(bases) != faces:
            sys.exit("%s has %d views and %d bases" % (name, faces, len(bases)))

        # The grimy sprite first: a rubbish-born find's clean views fall back to it.
        if e.get("dirty_piece"):
            grimy = rubbish_sprite(book, e["dirty_piece"], cache)
        else:
            grimy = despeck(load_layer(e["dirty"], cache))
        if grimy is None:
            sys.exit("%s has no dirty art (layer %s is empty)" % (name, e.get("dirty")))

        keys = []
        for v in views:
            layer = load_layer(v["layer"], cache, missing_ok=bool(e.get("dirty_piece")))
            if layer is None:
                print("  %s/%s: no clean layer yet, using the rubbish sprite" % (
                    name, v["role"]))
                layer = grimy
            cut = layer.crop(tuple(
                [v["rect"][0], v["rect"][1],
                 v["rect"][0] + v["rect"][2], v["rect"][1] + v["rect"][3]]
            )) if v.get("rect") else layer
            cut = despeck(cut)
            if cut is None:
                sys.exit("%s view %s is empty" % (name, v["role"]))
            key = "%s/%s" % (name, v["role"])
            clean_sprites[key] = cut
            keys.append(key)

        if e["mirror"]:
            side = next((v["role"] for v in views if v["role"] == "side"), None)
            if side is None:
                sys.exit("%s asks for a mirror but has no 'side' view" % name)
            key = "%s/side_r" % name
            clean_sprites[key] = clean_sprites["%s/side" % name].transpose(
                Image.FLIP_LEFT_RIGHT
            )
            # front, side, back, side flipped: facing you, turned, facing away, turned back.
            keys.append(key)

        view_keys[name] = keys
        dirty_sprites[name] = grimy
        fills[name] = fill_of(grimy)

    clean_sheet, clean_spots = pack(clean_sprites)
    dirty_sheet, dirty_spots = pack(dirty_sprites)
    CLEAN_PNG.parent.mkdir(parents=True, exist_ok=True)
    clean_sheet.save(CLEAN_PNG)
    dirty_sheet.save(DIRTY_PNG)

    kept = [p for p in book["pieces"]
            if p["sheet"] not in RETIRED_SHEETS and not p["name"].startswith("decor_")]

    pieces = []
    for e in entries:
        name = e["name"]
        box = dirty_spots[name]
        views = [clean_spots[k] for k in view_keys[name]]
        roles = [k.split("/", 1)[1] for k in view_keys[name]]
        pieces.append({
            "name": name,
            "title": e["title"],
            "sheet": DIRTY_SHEET,
            "region": box,
            "alt_sheet": CLEAN_SHEET,
            "alt_views": views,
            "alt_roles": roles,
            "set": e["kind"],
            "copies": int(e.get("copies", 1)),
            "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
            "fill": fills[name],
            "place": e.get("place", "floor"),
            "scale": float(e.get("scale", 1.0)),
            # Per view, in view order; the shed reads a missing list as its own default.
            "base": [int(b) for b in e["base"]] if e.get("base") else [],
        })

    book["pieces"] = kept + pieces
    book["sheets"] = {k: v for k, v in book["sheets"].items()
                      if k not in RETIRED_SHEETS}
    book["sheets"][DIRTY_SHEET] = {
        "file": "res://assets/decor_dirty.png",
        "size": list(dirty_sheet.size),
    }
    book["sheets"][CLEAN_SHEET] = {
        "file": "res://assets/decor_clean.png",
        "size": list(clean_sheet.size),
    }
    CATALOGUE.write_text(json.dumps(book, indent=1, sort_keys=True), encoding="utf-8")

    print("clean sheet %dx%d, %d views" % (
        clean_sheet.width, clean_sheet.height, len(clean_sprites)))
    print("dirty sheet %dx%d, %d finds" % (
        dirty_sheet.width, dirty_sheet.height, len(dirty_sprites)))
    print("catalogue: %d kept + %d decor" % (len(kept), len(pieces)))


if __name__ == "__main__":
    main()

#!/usr/bin/env python
"""Turn the decoration PSD into two packed sheets and the decor half of pieces.json.

The lake shows a find grimy and the shed shows it restored, and those are no longer the
same picture twice: the dirty sofa is 22x55 and the clean one is three views, the widest
49 across. So the two go onto two sheets and every piece carries its own rectangle in
each, rather than one rectangle read against a parallel sheet the way the old
TopDownHouse pair worked.

Input:
  art_source/decoration_extracted/   one PNG per PSD layer, from the psd-extract skill
  art_source/decoration_extracted/manifest.json   the PSD's own layer tree
  tools/decor_sets.json              tuning numbers, and the older hand-authored entries

Two ways a find gets in, and a find uses exactly one of them:

  The convention (2026-09-20, Richard's call). The PSD says what a piece is and what its
  views are; tools/decor_sets.json says nothing but the numbers. A piece is a GROUP under
  'Decoration' holding ONE LAYER PER VIEW, and one layer of the same name under
  'Decoration Dirty':

      Decoration
        Sofa (rotate)        <- group name is the title; the suffix is the mechanic
          front              <- layer name is the role, one view per layer
          side
          back
        Fridge (state)
          shut
          open
        Pet Bed (variant)
          round
          oval
        Mirror (single)      <- a group still, holding its one layer
      Decoration Dirty
        Sofa                 <- one layer per piece, the title without its suffix
        Fridge
        Pet Bed
        Mirror

  The suffix is rotate / variant / state, and it is what decides the mechanic, because the
  role words cannot: the rugs turn between 'wide' and 'long', which no vocabulary of
  faces would have guessed, and 'round'/'oval' is a restyle while 'shut'/'open' is a
  switch. A piece with one view needs no suffix and its role is 'front' whatever the
  layer is called. Views come out in the PSD's own layer order, so the order R cycles
  them in is the order they are stacked in.

  A piece is always a group, never a bare layer: the flat layers under 'Decoration' are
  the authored finds, and reading those as pieces too would claim all 37 twice.

  The authored entries, in tools/decor_sets.json's 'entries'. Several views packed into
  one layer, split by rectangles read off the pixels by hand. This is how all 37 finds
  were built before the convention and none of them has to move; a piece may not be in
  both places.

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
MANIFEST = LAYERS / "manifest.json"
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

## How far, in pixels, one state of a piece may be slid over the other to find where they
## line up. The lamps needed 3; the rest 0 or 1.
ALIGN_REACH = 12

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


_BY_NAME = None


def layer_file(ref):
    """The PNG a layer reference names.

    A reference is 'Group/Layer name' (every group on the way down, so a piece group
    reads 'Decoration/Sofa (rotate)/front'), with '#n' for the nth layer of that name in that
    group ('Decoration/Drawer#2'), read through the manifest psd-extract writes. Never by
    slug: slugs are handed out in file order and de-duplicated across the WHOLE file, so
    the day the 'Decoration Dirty' group was moved above 'Decoration' (2026-09-20) every
    clean sprite took the name its dirty twin had had. A reference with no '/' is a plain
    file in the folder — the bed's two views, which come from another PSD and are kept.
    """
    global _BY_NAME
    if "/" not in ref:
        return LAYERS / (ref + ".png")
    if _BY_NAME is None:
        _BY_NAME = {}
        seen = {}
        tree = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for layer in tree["layers"]:
            key = ("/".join(layer["group_path"]), layer["name"].strip())
            seen[key] = seen.get(key, 0) + 1
            _BY_NAME["%s/%s#%d" % (key[0], key[1], seen[key])] = LAYERS / layer["file"]
    full = ref if "#" in ref else ref + "#1"
    if full not in _BY_NAME:
        sys.exit("no layer '%s' in %s" % (ref, MANIFEST))
    return _BY_NAME[full]


def load_layer(ref, cache, missing_ok=False):
    if ref not in cache:
        path = layer_file(ref)
        if not path.exists():
            if missing_ok:
                return None
            sys.exit("missing layer PNG: %s" % path)
        cache[ref] = Image.open(path).convert("RGBA")
    return cache[ref]


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


def _matched(a, b, dx, dy):
    """How many pixels are the same colour with b laid over a at (dx, dy)."""
    pa, pb = a.load(), b.load()
    n = 0
    for y in range(b.height):
        for x in range(b.width):
            X, Y = x + dx, y + dy
            if 0 <= X < a.width and 0 <= Y < a.height:
                p, q = pa[X, Y], pb[x, y]
                if p[3] and q[3] and p[:3] == q[:3]:
                    n += 1
    return n


def shared_frame(a, b):
    """Two states of one face, padded into one frame with what they share lying still.

    b is slid over a to the offset where the most pixels match exactly — the fridge's
    body, the lamp's foot — nearest offset winning a tie, and both are padded to the box
    that holds them. Measured each build, so a redrawn lamp re-aligns itself.
    """
    reach = ALIGN_REACH
    best = None
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            k = (_matched(a, b, dx, dy), -abs(dx) - abs(dy))
            if best is None or k > best[0]:
                best = (k, dx, dy)
    _, dx, dy = best
    x0, y0 = min(0, dx), min(0, dy)
    x1, y1 = max(a.width, dx + b.width), max(a.height, dy + b.height)
    out_a = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    out_b = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    out_a.paste(a, (-x0, -y0))
    out_b.paste(b, (dx - x0, dy - y0))
    return out_a, out_b


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

## What a piece gives off while switched on: nothing, the hearth (a warm pool and the
## crackle), a lamp (a warm pool, silent), the open fridge (a cold white pool).
LIGHTS = ("", "fire", "warm", "cold")


## The two top groups of the PSD: the restored piece, and the piece as the lake shows it.
CLEAN_GROUP = "Decoration"
DIRTY_GROUP = "Decoration Dirty"

## The word a piece's group name ends in, and the mechanic it buys. A piece with one view
## says nothing and is SINGLE.
KINDS = {"rotate": "ROTATE", "variant": "VARIANT", "state": "STATE"}

## The three faces that earn a mirrored fourth: facing you, turned, facing away — so the
## turn back is the same side flipped, and R goes all the way round. Any other three views
## are three drawings and the builder invents nothing.
MIRRORED = ("front", "side", "back")


def slug_of(title):
    """The piece name a title makes: 'Pet Bed' -> 'decor_pet_bed'."""
    keep = [c.lower() if c.isalnum() else "_" for c in title]
    out = "".join(keep)
    while "__" in out:
        out = out.replace("__", "_")
    return "decor_" + out.strip("_")


def split_kind(group_name):
    """A piece group's title and mechanic: 'Sofa (rotate)' -> ('Sofa', 'ROTATE')."""
    name = group_name.strip()
    if name.endswith(")") and "(" in name:
        head, word = name[:-1].rsplit("(", 1)
        word = word.strip().lower()
        if word in KINDS:
            return head.strip(), KINDS[word]
        sys.exit("%s: '%s' is not one of %s" % (group_name, word, tuple(KINDS)))
    return name, None


def from_manifest(named):
    """Read the PSD's own layer tree as catalogue entries.

    `named` is the piece names the authored entries already claim; a piece in both places
    is a piece with two answers, so it stops the build rather than picking one.
    """
    if not MANIFEST.exists():
        return []
    tree = json.loads(MANIFEST.read_text(encoding="utf-8"))
    groups = {}
    dirty = {}
    for layer in tree["layers"]:
        path = layer.get("group_path") or []
        if len(path) == 2 and path[0] == CLEAN_GROUP:
            groups.setdefault(path[1], []).append(layer)
        elif len(path) == 1 and path[0] == DIRTY_GROUP:
            dirty[layer["name"].strip()] = "%s/%s" % (DIRTY_GROUP, layer["name"].strip())

    entries = []
    for group_name, layers in groups.items():
        title, kind = split_kind(group_name)
        name = slug_of(title)
        if name in named:
            sys.exit("%s is both a PSD group and an authored entry; pick one" % title)
        if kind is None:
            if len(layers) != 1:
                sys.exit("%s has %d views and no (rotate|variant|state) in its name"
                         % (title, len(layers)))
            kind = "SINGLE"
        elif len(layers) < 2:
            sys.exit("%s is %s but holds one layer" % (title, kind))
        if title not in dirty:
            sys.exit("%s has no layer called '%s' under '%s'"
                     % (title, title, DIRTY_GROUP))
        roles = [layer["name"].strip().lower().replace(" ", "_") for layer in layers]
        if kind == "SINGLE":
            # Nothing cycles it, so the layer may be called anything; the catalogue's
            # word for the one face every other piece has is 'front'.
            roles = ["front"]
        if len(set(roles)) != len(roles):
            sys.exit("%s has two views with the same name" % title)
        entries.append({
            "name": name,
            "title": title,
            "dirty": dirty[title],
            "kind": kind,
            # A three-face set turns all the way round; everything else is what is drawn.
            "mirror": kind == "ROTATE" and tuple(roles) == MIRRORED,
            # One view per layer: the layer's own crop is the view, so no rect is authored.
            "views": [{"role": r, "layer": "%s/%s/%s" % (CLEAN_GROUP, group_name,
                                                         layer["name"].strip())}
                      for r, layer in zip(roles, layers)],
        })
    return entries


def main():
    table = json.loads(TABLE.read_text(encoding="utf-8"))
    entries = list(table["entries"])
    grown = from_manifest({e["name"] for e in entries})
    # The numbers live here whatever the art came in as: place, base, seat, scale, copies,
    # and a mirror said out loud. Richard retunes them by eye and never in the PSD.
    tuning = table.get("tuning", {})
    for e in grown:
        e.update(tuning.get(e["name"], {}))
    entries += grown
    book = json.loads(CATALOGUE.read_text(encoding="utf-8"))

    cache = {}
    clean_sprites = {}
    dirty_sprites = {}
    view_keys = {}
    axes = {}
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
        # A mirror flips every side view into the other side: the sofa's one, and the
        # toilet's two (empty and full), so R turns a toilet to either wall.
        mirrored = [v for v in views if v["role"].startswith("side")] if e["mirror"] else []
        if e["mirror"] and not mirrored:
            sys.exit("%s asks for a mirror but has no side view" % name)
        if int(e.get("copies", 1)) < 1:
            sys.exit("%s asks for %s copies" % (name, e.get("copies")))
        if e.get("place", "floor") not in PLACES:
            sys.exit("%s is placed '%s'; one of %s" % (name, e.get("place"), PLACES))
        faces = len(views) + len(mirrored)
        bases = e.get("base")
        if bases is not None and len(bases) != faces:
            sys.exit("%s has %d views and %d bases" % (name, faces, len(bases)))
        # base_px says the same thing in the drawing's own pixels, for a piece whose
        # contact with the floor is finer than a cell. The same length rule, because
        # Sheets wraps a short list with posmod and a mirrored view would get the wrong
        # number in silence. Never both: two numbers for one fact is one too many.
        bases_px = e.get("base_px")
        if bases_px is not None and len(bases_px) != faces:
            sys.exit("%s has %d views and %d pixel bases" % (name, faces, len(bases_px)))
        if bases is not None and bases_px is not None:
            sys.exit("%s authors both base and base_px; pick one" % name)
        # seat: where a dog's feet go on a view, in drawn pixels up from the picture's
        # bottom. 0 on a view nothing may lie on, so the list is as long as the others.
        seats = e.get("seat")
        if seats is not None and len(seats) != faces:
            sys.exit("%s has %d views and %d seats" % (name, faces, len(seats)))

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

        # Which way each view faces and whether it is switched on — what R and E move
        # along. Authored per view for a piece that does both (the toilet); otherwise the
        # kind says which of the two the views count.
        faces, states = [], []
        for i, v in enumerate(views):
            faces.append(int(v.get("face", 0 if e["kind"] == "STATE" else i)))
            states.append(int(v.get("state", i if e["kind"] == "STATE" else 0)))

        # Both states of one face share one frame, aligned on the pixels they have in
        # common, so pressing E changes what changed and nothing moves. Each view is cropped
        # to its own drawing, and a lit lamp's shade or an open fridge door makes that crop
        # a different size — the piece jumped sideways on every switch (Richard, 2026-09-21).
        for face in set(faces):
            off = [k for k, (f, st) in enumerate(zip(faces, states)) if f == face and st == 0]
            on = [k for k, (f, st) in enumerate(zip(faces, states)) if f == face and st == 1]
            if off and on:
                a, b = keys[off[0]], keys[on[0]]
                clean_sprites[a], clean_sprites[b] = shared_frame(
                    clean_sprites[a], clean_sprites[b])

        # Then the mirror, off the aligned pictures, so a flipped pair stays aligned.
        # front, side, back, side flipped: facing you, turned, facing away, turned back.
        if mirrored:
            turn_back = max(faces) + 1
            for v in mirrored:
                k = views.index(v)
                key = "%s/%s_r" % (name, v["role"])
                clean_sprites[key] = clean_sprites[keys[k]].transpose(Image.FLIP_LEFT_RIGHT)
                keys.append(key)
                faces.append(turn_back)
                states.append(states[k])
        pairs = list(zip(faces, states))
        if len(set(pairs)) != len(pairs):
            sys.exit("%s has two views facing the same way in the same state" % name)
        if pairs[0] != (0, 0):
            sys.exit("%s: view 0 is what leaves the store, so it must face 0, switched off"
                     % name)
        if e.get("light", "") not in LIGHTS:
            sys.exit("%s gives off '%s'; one of %s" % (name, e.get("light"), LIGHTS))
        axes[name] = (faces, states)
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
            "faces": axes[name][0],
            "states": axes[name][1],
            "light": e.get("light", ""),
            "copies": int(e.get("copies", 1)),
            "cells": [max(1, -(-box[2] // CELL)), max(1, -(-box[3] // CELL))],
            "fill": fills[name],
            "place": e.get("place", "floor"),
            "scale": float(e.get("scale", 1.0)),
            # Per view, in view order; the shed reads a missing list as its own default.
            "base": [int(b) for b in e["base"]] if e.get("base") else [],
            "base_px": [int(b) for b in e["base_px"]] if e.get("base_px") else [],
            "seat": [int(b) for b in e["seat"]] if e.get("seat") else [],
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

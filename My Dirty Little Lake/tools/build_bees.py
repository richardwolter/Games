#!/usr/bin/env python
"""The bee's sheet: tools/hive_look/look.py's variant A (the coin bee) baked for the game.

2026-10-18, the hive's visual overhaul: Richard picked bee "A" off tools/hive_look/last_bee.png.
Every frame here is look.py's own drawing, called, not copied: change the bee there and run this
again. **Variant A only.** Some later mockup sheets drew a reworked bee "R" (the queen sheet); it
is not the pick and is not baked.

Writes assets/bees.png and assets/bees.json, then reimport the project. Run from the project root
with the base python and the psd-extract venv's packages (App Control blocks the venv's own
python.exe):

    PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" \
        python tools/build_bees.py

What is on the sheet (every frame faces RIGHT; a consumer mirrors, scripts/bee_art.gd does it):

    worker_fly0..5      wings up / mid / down, the body bobbing one px on 3-5   (16 x 16 canvas)
    worker_hover0..2    the same wings, no bob (a bee held in a clump, over a flower)
    worker_walk0..1     crawling, wings folded, legs shuffling
    worker_rest0..3     landed and still; 3 blinks
    worker_walkback0..1 the crawl seen from behind: no eye, glint or cheek (look.bee_keyed face=False)
    worker_restback0..3 the rest seen from behind
    mini_fly0..5        the lake's round bee (look.mini_round): wings, a one-px bob on 3-5 (12 x 11)
    mini_rest0          on a flower, wings folded
    queen_walk0..1      her legs shuffling on the comb                          (21 x 16 canvas)
    queen_lay0          laying: her last QUEEN_TAIL columns dipped one px

**The mini is look.mini_round**, the round 8 x 7 lake bee the island and honey sheets moved to
(2026-10-17), not look.mini_bee (the bee sheet's squared 7 x 5 block). Both are A's colours.

Every frame keeps its whole canvas, so every frame of a kind lines up and its anchor (the body's
middle, look.bee_anchor / mini_round_anchor / queen_anchor) is the one point a consumer stands it
on. The json:

    {"sheet": "res://assets/bees.png", "variant": "A",
     "canvas": {"worker": [16, 16], "mini": [12, 11], "queen": [21, 16]},
     "loops": {"worker_fly": 6, ...},          # frames in each animation
     "held":  {"worker_fly": 0.05, ...},       # seconds a frame is held (first guesses)
     "frames": {"worker_fly0": {"rect": [x, y, w, h], "anchor": [ax, ay]}, ...}}
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "hive_look"))
import look  # noqa: E402

V = "A"
OUT_PNG = os.path.join(ROOT, "assets", "bees.png")
OUT_JSON = os.path.join(ROOT, "assets", "bees.json")
GAP = 1          # a clear pixel between cells, so a sampled edge never bleeds a neighbour

# Seconds a frame is held. First guesses for the game: wings flicker fast, a crawl is a shuffle,
# a resting bee breathes; rest's blink (frame 3) is held as long as the others, so a consumer
# that wants a short blink plays its own timing (BeeArt.frame_at takes any hold).
HELD = {
    "worker_fly": 0.05, "worker_hover": 0.05, "worker_walk": 0.14, "worker_rest": 0.45,
    "worker_walkback": 0.14, "worker_restback": 0.45,
    "mini_fly": 0.05, "mini_rest": 0.5,
    "queen_walk": 0.28, "queen_lay": 0.5,
}


def frames():
    """(name, animation, kind, image, anchor) for every frame, in sheet order."""
    out = []
    for pose in ("fly", "hover", "walk", "rest"):
        for f in range(look.bee_frames(pose)):
            out.append(("worker_%s%d" % (pose, f), "worker_" + pose, "worker",
                        look.bee(V, f, pose=pose), look.bee_anchor(V, pose, False, f)))
    for pose in ("walk", "rest"):
        for f in range(look.bee_frames(pose)):
            out.append(("worker_%sback%d" % (pose, f), "worker_%sback" % pose, "worker",
                        look.bee_keyed(V, f, pose=pose, face=False),
                        look.bee_anchor(V, pose, False, f)))
    for f in range(6):
        out.append(("mini_fly%d" % f, "mini_fly", "mini", look.mini_round(V, f, pose="fly"),
                    look.mini_round_anchor(V, "fly", False, f)))
    out.append(("mini_rest0", "mini_rest", "mini", look.mini_round(V, 0, pose="rest"),
                look.mini_round_anchor(V, "rest", False, 0)))
    for f in range(2):
        out.append(("queen_walk%d" % f, "queen_walk", "queen", look.queen(V, f),
                    look.queen_anchor(V)))
    out.append(("queen_lay0", "queen_lay", "queen", look.queen(V, 0, laying=True),
                look.queen_anchor(V)))
    return out


CANVAS = {"worker": look.BEE_CANVAS, "mini": look.ROUND_CANVAS, "queen": look.QUEEN_CANVAS}


def build():
    items = frames()
    # One row a kind: workers, minis, queens; cells at their canvas size plus the gap.
    rows = {}
    for it in items:
        rows.setdefault(it[2], []).append(it)
    order = ("worker", "mini", "queen")
    width = max(sum(CANVAS[k][0] + GAP for _ in rows[k]) + GAP for k in order)
    height = sum(CANVAS[k][1] + GAP for k in order) + GAP
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    book = {"sheet": "res://assets/bees.png", "variant": V,
            "canvas": {k: list(CANVAS[k]) for k in order},
            "loops": {}, "held": dict(HELD), "frames": {}}
    y = GAP
    for k in order:
        cw, ch = CANVAS[k]
        x = GAP
        for name, anim, _kind, im, anchor in rows[k]:
            assert im.size == (cw, ch), (name, im.size)
            sheet.alpha_composite(im, (x, y))
            book["frames"][name] = {"rect": [x, y, cw, ch], "anchor": [int(anchor[0]), int(anchor[1])]}
            book["loops"][anim] = book["loops"].get(anim, 0) + 1
            x += cw + GAP
        y += ch + GAP
    sheet.save(OUT_PNG)
    with open(OUT_JSON, "w", newline="\n") as fh:
        json.dump(book, fh, indent=1)
        fh.write("\n")
    return sheet, book


if __name__ == "__main__":
    sheet, book = build()
    print("wrote %s %s, %d frames" % (OUT_PNG, sheet.size, len(book["frames"])))
    for anim, n in book["loops"].items():
        print("  %-16s %d" % (anim, n))

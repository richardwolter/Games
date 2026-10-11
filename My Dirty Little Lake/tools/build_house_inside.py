"""Bakes the house's inside, three stages, out of the mockup's modules (2026-10-11).

    PYTHONPATH=<psd-extract site-packages> python tools/build_house_inside.py

The art is drawn by the mockup in art_source/house_inside/ (floor.py, damp.py, veg.py, life.py, laid
out by layout.json), Richard's approved look. This runs those modules frame by frame on an
empty room (no furniture, dogs or player: in the game those are the player's) and writes what
the game plays back, into assets/house/:

  house.json                 the sets below, the region they cover, and the blocking rects
  <set>_under.png            the parts of the layer that never change (dynamic tiles cleared)
  <set>_over.png
  <set>_tiles.png            every distinct 8x8 tile the moving parts ever show, in a grid
  <set>_index.png            one row a frame, one column a dynamic tile (under's, then
                             over's): which tile of `_tiles` stands there, as idx + 1 in
                             R (low byte) and G (high byte); 0 is an empty tile

Sets: s1, s1r (stage 1 in a shower), s2, s3 loop; u12, u23 play once (the stage-up). A loop
is LOOP_TRY seconds rendered and cut where it comes back closest to its first frame.

'under' is drawn under the furniture (on the floor layer), 'over' on top of everything. Both
cover REGION on the room's source grid: (x, y, w, h) in source px from the floor box's
top-left, so the frame's vegetation can hang out over the lake.

Needs the mockup's captures (art_source/house_inside/captures/, from tools/shot_house_layers.tscn):
floor.py reads the bare floor's colours off s1_shell.png and base.Ctx the room's rects off
layers.json. Reimport after a run.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "art_source" / "house_inside"))
import base  # noqa: E402
import damp  # noqa: E402
import floor  # noqa: E402
import life  # noqa: E402
import veg  # noqa: E402

OUT = HERE.parent / "assets" / "house"
FPS = 12
TILE = 8
LOOP_TRY = 30.0          # seconds rendered for a loop
LOOP_LEAST = 20.0        # the seam is searched from here to LOOP_TRY
UP_SECONDS = 2.5         # a stage-up, played once; p runs 0..1 over the first 2 s
MODS = [floor, damp, veg, life]

# The source grid the modules draw on is the 1080p capture's (640x360); the floor box is at
# (84, 84) on it. The baked region, in that grid, tile-aligned from its own corner.
GRID_ORIGIN = (84, 84)
REGION = (64, 24, 368, 328)          # x, y, w, h on the 640x360 grid


class BakeCtx(base.Ctx):
    """The room with nobody and nothing in it: what is drawn must not depend on the furniture."""

    def __init__(self, stage, rain=0.0, t=0.0):
        super().__init__(stage, rain)
        self.pieces = []
        self.dogs = []
        self.player = (-999.0, -999.0)
        self.t = t


_landings: list = []


def _watch_splash():
    """Every drop's landing, for its sound: damp.splash is called each frame of a splash's
    life with its age; age under one frame is the landing."""
    real = damp.splash

    def spy(O, at, age, seed, *a, **k):
        if 0 <= age < 1.0 / FPS:
            _landings.append((float(at[0]), float(at[1])))
        return real(O, at, age, seed, *a, **k)
    damp.splash = spy


def render(stage, t, rain=0.0, up=None):
    ctx = BakeCtx(stage, rain, t)
    under, over = base.blank(), base.blank()
    for m in MODS:
        if up is not None and hasattr(m, "stage_up"):
            m.stage_up(up[0], up[1], ctx, under, over)
        else:
            m.draw(stage, t, ctx, under, over)
    x, y, w, h = REGION
    return (np.asarray(under)[y:y + h, x:x + w].copy(), np.asarray(over)[y:y + h, x:x + w].copy())


def frames_of(stage, n, rain=0.0, up_from=None):
    U, O, L = [], [], []
    for i in range(n):
        del _landings[:]
        t = i / FPS
        up = None if up_from is None else (up_from, min(1.0, i / (2.0 * FPS)))
        u, o = render(stage, t, rain, up)
        U.append(u)
        O.append(o)
        L.append(list(_landings))
    return U, O, L


def seam(U, O):
    first = int(LOOP_LEAST * FPS)
    best = None
    for k in range(first, len(U)):
        d = int((U[k] != U[0]).any(-1).sum() + (O[k] != O[0]).any(-1).sum())
        if best is None or d < best[1]:
            best = (k, d)
    return best


def pack(name, U, O, L, loop):
    """Static layers, the tile atlas and the frame index for one set."""
    tw, th = REGION[2] // TILE, REGION[3] // TILE
    atlas: list = []
    seen: dict = {}

    def dyn_tiles(a):
        changed = (a != a[0]).any(-1).any(0)
        t = changed.reshape(th, TILE, tw, TILE).any(axis=(1, 3))
        return [(int(x), int(y)) for y, x in zip(*np.nonzero(t))]

    def tile_id(px):
        if px[..., 3].max() == 0:
            return 0
        key = px.tobytes()
        if key not in seen:
            seen[key] = len(atlas) + 1
            atlas.append(px)
        return seen[key]

    layers = {}
    columns = []
    for lname, frames in (("under", U), ("over", O)):
        a = np.stack(frames)
        tiles = dyn_tiles(a)
        static = a[0].copy()
        for x, y in tiles:
            static[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] = 0
        Image.fromarray(static, "RGBA").save(OUT / f"{name}_{lname}.png")
        layers[lname] = {"tiles": tiles}
        for x, y in tiles:
            columns.append([tile_id(f[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE]) for f in a])
    n = len(U)
    index = np.zeros((n, max(1, len(columns)), 4), np.uint8)
    for c, col in enumerate(columns):
        for f, v in enumerate(col):
            index[f, c] = (v & 0xFF, v >> 8, 0, 255)
    Image.fromarray(index, "RGBA").save(OUT / f"{name}_index.png")
    per_row = 64
    rows = max(1, (len(atlas) + per_row - 1) // per_row)
    sheet = np.zeros((rows * TILE, per_row * TILE, 4), np.uint8)
    for i, px in enumerate(atlas):
        r, c = divmod(i, per_row)
        sheet[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = px
    Image.fromarray(sheet, "RGBA").save(OUT / f"{name}_tiles.png")
    drips = []
    for f, events in enumerate(L):
        for x, y in events:
            drips.append([f, round(x - GRID_ORIGIN[0], 1), round(y - GRID_ORIGIN[1], 1)])
    print(f"{name}: {n} frames, under {len(layers['under']['tiles'])} + over "
          f"{len(layers['over']['tiles'])} moving tiles, {len(atlas)} distinct, {len(drips)} drips")
    return {"frames": n, "loop": loop, "under": layers["under"]["tiles"],
            "over": layers["over"]["tiles"], "per_row": per_row, "drips": drips}


def blocks():
    """The layout's blocking rects per stage, in placement px: 'walk' (holes and broken boards:
    no walking and no placing) and 'place' (puddles: no placing)."""
    lay = base.load_layout()
    out = {}
    for stage in (1, 2, 3):
        walk, place = [], []
        for f in lay["features"]:
            if stage not in f.get("stages", []):
                continue
            if f["kind"] in ("hole", "broken"):
                walk += f.get("block_s2", f["block"]) if stage == 2 else f["block"]
            elif f["kind"] == "puddle":
                cx, cy = f["center"]
                w, h = f.get("size_s2", f["size"]) if stage == 2 else f["size"]
                place.append([cx - w // 2, cy - h // 2, w, h])
        out[str(stage)] = {"walk": walk, "place": place}
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    _watch_splash()
    sets = {}
    n = int(LOOP_TRY * FPS)
    for name, stage, rain in (("s1", 1, 0.0), ("s1r", 1, 1.0), ("s2", 2, 0.0), ("s3", 3, 0.0)):
        U, O, L = frames_of(stage, n, rain)
        k, d = seam(U, O)
        print(f"{name}: seam at {k / FPS:.2f} s, {d} px off the first frame")
        sets[name] = pack(name, U[:k], O[:k], L[:k], True)
    m = int(UP_SECONDS * FPS)
    for name, frm in (("u12", 1), ("u23", 2)):
        U, O, L = frames_of(frm + 1, m, 0.0, up_from=frm)
        sets[name] = pack(name, U, O, L, False)
    x, y, w, h = REGION
    data = {
        "fps": FPS, "tile": TILE,
        "region": [x - GRID_ORIGIN[0], y - GRID_ORIGIN[1], w, h],
        "sets": sets, "blocks": blocks(),
    }
    (OUT / "house.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()

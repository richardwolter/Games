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


# The demo's half step (2026-10-15, `/grill-me` with Richard: "tease the player with some
# fixings"): stage 1 with the stove's ghost (h4) and the tented boards (b3) boarded over and
# the fresh leak (p2) dried. Run with --half: it renders stage 1 with those three left out of
# the layout and the flue's drip off, and lays stage 2's own pixels over MENDED (floor-rel
# rects: f4's and f7's fresh boards, the mushrooms at b3's foot, p2's ring), so what is mended
# is exactly what stage 2 mends. Sets: s1h, s1hr (in a shower), u1h (the play-in, stage 2's
# own stage-up inside the mask). Appended to an existing house.json; the other sets untouched.
HALF_DROP = ("h4", "b3", "p2")
HALF_SETS = ("s1h", "s1hr", "u1h")
DROP_IDS: tuple = ()


class BakeCtx(base.Ctx):
    """The room with nobody and nothing in it: what is drawn must not depend on the furniture."""

    def __init__(self, stage, rain=0.0, t=0.0):
        super().__init__(stage, rain)
        if DROP_IDS:
            for f in self.layout.get("features", []):
                if f["id"] in DROP_IDS:
                    f["stages"] = [s for s in f.get("stages", []) if s != 1]
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
            elif f["kind"] == "stack":
                # The saw and boards beside the low corner (st1): no placing on them, there
                # from stage 1 so nothing the player stands there is landed on at the mending
                # (Richard, after the staged shop's first run).
                place += f["block"]
            elif f["kind"] == "puddle":
                cx, cy = f["center"]
                w, h = f.get("size_s2", f["size"]) if stage == 2 else f["size"]
                place.append([cx - w // 2, cy - h // 2, w, h])
        out[str(stage)] = {"walk": walk, "place": place}
    return out


def _clear_caches():
    """The modules' own per-stage caches, so a stage drawn off another layout is drawn again."""
    for m in (damp, life, veg):
        for name, value in list(vars(m).items()):
            if name.startswith("_") and not name.startswith("__") and isinstance(value, dict):
                value.clear()


def _mended_mask():
    """MENDED on the bake region's grid: a (h, w) bool array."""
    lay = base.load_layout()
    feat = {f["id"]: f for f in lay["features"]}
    rects = []
    for fid in ("f4", "f7"):
        rects += feat[fid]["boards"]
    rects.append(feat["m3"]["rect"])
    rects.append(feat["s2"]["rect"])
    x0, y0, w, h = REGION
    m = np.zeros((h, w), bool)
    for rx, ry, rw, rh in rects:
        ax = rx + GRID_ORIGIN[0] - x0
        ay = ry + GRID_ORIGIN[1] - y0
        m[max(0, ay):ay + rh, max(0, ax):ax + rw] = True
    return m


def _half_blocks(full: dict) -> dict:
    """Stage 1's blocks less what the half step mends."""
    lay = base.load_layout()
    feat = {f["id"]: f for f in lay["features"]}
    gone = [list(r) for fid in ("h4", "b3") for r in feat[fid]["block"]]
    cx, cy = feat["p2"]["center"]
    w, h = feat["p2"]["size"]
    dry = [cx - w // 2, cy - h // 2, w, h]
    return {
        "walk": [r for r in full["1"]["walk"] if r not in gone],
        "place": [r for r in full["1"]["place"] if r != dry],
    }


def half():
    """Bake the demo's half step and add it to house.json."""
    global DROP_IDS
    data = json.loads((OUT / "house.json").read_text(encoding="utf-8"))
    _watch_splash()
    mask = _mended_mask()
    n = int(LOOP_TRY * FPS)
    m = int(UP_SECONDS * FPS)
    # Stage 2 and its stage-up first, off the layout as it is: only the masked pixels kept.
    _clear_caches()
    s2_under = []
    for i in range(n):
        u, _o = render(2, i / FPS)
        s2_under.append(u[mask])
    up_under = []
    for i in range(m):
        u, _o = render(2, i / FPS, 0.0, (1, min(1.0, i / (2.0 * FPS))))
        up_under.append(u[mask])
    # Stage 1 off the halved layout.
    _clear_caches()
    DROP_IDS = HALF_DROP
    damp.NO_FLUE = True
    try:
        for name, rain in (("s1h", 0.0), ("s1hr", 1.0)):
            U, O, L = frames_of(1, n, rain)
            for i in range(n):
                U[i][mask] = s2_under[i]
            k, d = seam(U, O)
            print(f"{name}: seam at {k / FPS:.2f} s, {d} px off the first frame")
            data["sets"][name] = pack(name, U[:k], O[:k], L[:k], True)
            if name == "s1h":
                Uu, Ou, Lu = U[:m], O[:m], L[:m]
                for i in range(m):
                    Uu[i] = Uu[i].copy()
                    Uu[i][mask] = up_under[i]
                data["sets"]["u1h"] = pack("u1h", Uu, Ou, Lu, False)
            del U, O, L
    finally:
        DROP_IDS = ()
        damp.NO_FLUE = False
        _clear_caches()
    data["blocks"]["1h"] = _half_blocks(data["blocks"])
    (OUT / "house.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print("wrote the half step into", OUT / "house.json")


def main():
    if "--half" in sys.argv:
        half()
        return
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

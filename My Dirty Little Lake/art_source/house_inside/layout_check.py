"""Checks a house-stages layout file and draws it over the room.

    PYTHONPATH=<psd-extract site-packages> python art_source/house_inside/layout_check.py [layout.json]

LAYOUT SCHEMA (all rects are [x, y, w, h] integers in the game's PLACEMENT PIXELS: source px
from the floor box's top-left, the same units a decor row's "cell" is in. The boards a piece
can stand on are ctx.boards; in placement px that is x 6..330, y 10..214).

{
  "name": "...", "idea": "one paragraph: the story of the damage",
  "features": [
    {"id": "h1", "kind": "hole",    "stages": [1] or [1, 2],
     "block": [[x,y,w,h], ...],               # stage 1 blocking rects (walk AND place)
     "block_s2": [[x,y,w,h], ...],            # optional: smaller in stage 2, inside block
     "note": "what it is: rot by the wall under the worst leak, joist showing ..."},
    {"id": "b1", "kind": "broken",  ...same as hole: sunken / missing / splintered boards
     that block but are not open holes},
    {"id": "p1", "kind": "puddle",  "stages": [1] or [1, 2],
     "center": [x, y], "size": [w, h],        # stage 1, dry weather (blocks PLACING only)
     "size_s2": [w, h],                       # optional smaller in stage 2
     "rain_grow": 1.3,                        # how much wider in a full shower
     "note": "..."},
    {"id": "c1", "kind": "crack" | "stain" | "loose" | "weeds" | "mushrooms" | "patch" | ...,
     "stages": [...], "rect": [x,y,w,h], "note": "..."}          # cosmetic, block nothing
  ]
}
Stage 3 has no holes, broken boards or puddles.

Prints a report and writes out/layout_<name>_s{1,2}.png (the room with the blocks drawn).
Exit code 0 always; read the report.
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import base  # noqa: E402

WALK_CLEAR = 3          # the game's: a piece's base grown by this blocks walkers
DOOR_LANE = 26          # source px wide, from the door down this far, must be open
DOOR_DEPTH = 40


def rects_mask(rects, shape, ox=0, oy=0):
    m = np.zeros(shape, bool)
    for x, y, w, h in rects:
        m[max(0, y + oy):max(0, y + oy + h), max(0, x + ox):max(0, x + ox + w)] = True
    return m


def check(path: Path):
    lay = json.loads(path.read_text(encoding="utf-8"))
    name = lay.get("name", path.stem)
    ctx1 = base.Ctx(1)
    fx, fy, fw, fh = ctx1.floor
    bx, by, bw, bh = ctx1.boards
    shape = (fh, fw)                                   # floor-relative grid
    boards = np.zeros(shape, bool)
    boards[by - fy:by - fy + bh, bx - fx:bx - fx + bw] = True
    lines = [f"== {name}", lay.get("idea", "")]
    ok = True
    for stage in (1, 2):
        ctx = base.Ctx(stage)
        blocks, puddles = [], []
        for f in lay["features"]:
            if stage not in f.get("stages", []):
                continue
            if f["kind"] in ("hole", "broken"):
                blocks += f.get("block_s2", f["block"]) if stage == 2 else f["block"]
            elif f["kind"] == "puddle":
                cx, cy = f["center"]
                w, h = f.get("size_s2", f["size"]) if stage == 2 else f["size"]
                puddles.append([cx - w // 2, cy - h // 2, w, h])
        bm = rects_mask(blocks, shape)
        pm = rects_mask(puddles, shape)
        area = boards.sum()
        lines.append(f"-- stage {stage}: blocking {bm.sum() / area:.1%} of the boards "
                     f"({len(blocks)} rects), puddles {pm.sum() / area:.1%}")
        if (bm & ~boards).any():
            lines.append("   FAIL: a block reaches onto the moulding"); ok = False
        # Furniture: bases (grown by WALK_CLEAR) must not meet a block or a puddle.
        for p in ctx.pieces:
            x, y, w, h = p["base"]
            r = [x - fx - WALK_CLEAR, y - fy - WALK_CLEAR, w + 2 * WALK_CLEAR, h + 2 * WALK_CLEAR]
            pmk = rects_mask([r], shape)
            if (pmk & bm).any():
                lines.append(f"   FAIL: {p['piece']} base meets a hole/broken board"); ok = False
            if (rects_mask([[x - fx, y - fy, w, h]], shape) & pm).any():
                lines.append(f"   FAIL: {p['piece']} stands in a puddle"); ok = False
        # Walkers: the player's feet and every dog not on a seat must be on open boards.
        spots = [("player", ctx.player)] + [("dog", (d[0], d[1])) for d in ctx.dogs if not d[2]]
        for who, (x, y) in spots:
            r = rects_mask([[int(x - fx) - 4, int(y - fy) - 2, 8, 4]], shape)
            if (r & bm).any():
                lines.append(f"   FAIL: {who} stands over a block"); ok = False
        # The way in: a lane straight down from the door.
        dx, dy, dw, dh = ctx.door
        cx = dx + dw // 2 - fx
        lane = rects_mask([[cx - DOOR_LANE // 2, by - fy, DOOR_LANE, DOOR_DEPTH]], shape)
        if (lane & bm).any():
            lines.append("   FAIL: the door's lane is blocked"); ok = False
        # Reachability: open boards (blocks and piece bases grown by WALK_CLEAR are closed),
        # a walker 8 px wide, flood from the door.
        closed = bm.copy()
        for p in ctx.pieces:
            x, y, w, h = p["base"]
            closed |= rects_mask([[x - fx, y - fy, w, h]], shape)
        k = WALK_CLEAR + 4
        grown = closed.copy()
        ys, xs = np.nonzero(closed)
        for y, x in zip(ys, xs):
            grown[max(0, y - WALK_CLEAR):y + WALK_CLEAR + 1, max(0, x - k):x + k + 1] = True
        free = boards & ~grown
        start = (by - fy + 4, cx)
        seen = np.zeros(shape, bool)
        if free[start]:
            q = deque([start]); seen[start] = True
            while q:
                y, x = q.popleft()
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < shape[0] and 0 <= nx < shape[1] and free[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        else:
            lines.append("   FAIL: the door's start is closed"); ok = False
        cut = (free & ~seen).sum()
        lines.append(f"   reachable {seen.sum() / max(1, free.sum()):.1%} of the walkable boards"
                     f" (cut off: {cut} px)")
        if cut > 40:
            ok = False; lines.append("   FAIL: floor cut off from the door")
        # Every piece reachable: some open pixel within 6 px of its base.
        for p in ctx.pieces:
            x, y, w, h = p["base"]
            near = rects_mask([[x - fx - 10, y - fy - 6, w + 20, h + 12]], shape)
            if not (near & seen).any() and not p["piece"].endswith(("_rug", "rug")):
                lines.append(f"   WARN: {p['piece']} cannot be walked up to")
        # Picture.
        img = base.room_crop(base.compose(stage, base.blank(), base.blank()), pad=4).convert("RGBA")
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        pad = 4 * base.S
        rec = json.loads((base.CAP / "layers.json").read_text(encoding="utf-8"))
        ox = fx * base.S - (rec["shed"][0] - pad)
        oy = fy * base.S - (rec["shed"][1] - pad)
        S = base.S
        for x, y, w, h in blocks:
            d.rectangle([ox + x * S, oy + y * S, ox + (x + w) * S - 1, oy + (y + h) * S - 1],
                        fill=(200, 30, 30, 110), outline=(255, 60, 60, 255))
        for x, y, w, h in puddles:
            d.ellipse([ox + x * S, oy + y * S, ox + (x + w) * S - 1, oy + (y + h) * S - 1],
                      fill=(60, 120, 230, 110), outline=(90, 160, 255, 255))
        for f in lay["features"]:
            if stage in f.get("stages", []) and "rect" in f:
                x, y, w, h = f["rect"]
                d.rectangle([ox + x * S, oy + y * S, ox + (x + w) * S - 1, oy + (y + h) * S - 1],
                            outline=(240, 220, 90, 255))
        d.rectangle([ox + (cx - DOOR_LANE // 2) * S, oy + (by - fy) * S,
                     ox + (cx + DOOR_LANE // 2) * S, oy + (by - fy + DOOR_DEPTH) * S],
                    outline=(120, 255, 120, 255))
        Image.alpha_composite(img, ov).save(base.OUT / f"layout_{name}_s{stage}.png")
    # Stage 2 inside stage 1.
    for f in lay["features"]:
        if 2 in f.get("stages", []) and f["kind"] in ("hole", "broken") and "block_s2" in f:
            outer = rects_mask(f["block"], shape)
            if (rects_mask(f["block_s2"], shape) & ~outer).any():
                lines.append(f"   FAIL: {f['id']} block_s2 is not inside its stage 1 block"); ok = False
        if 2 in f.get("stages", []) and 1 not in f.get("stages", []) and f["kind"] in ("hole", "broken", "puddle"):
            lines.append(f"   FAIL: {f['id']} appears in stage 2 but not stage 1"); ok = False
    lines.append("RESULT: " + ("PASS" if ok else "FAIL"))
    print("\n".join(lines))
    return ok


if __name__ == "__main__":
    base.OUT.mkdir(parents=True, exist_ok=True)
    check(Path(sys.argv[1]) if len(sys.argv) > 1 else base.HERE / "layout.json")

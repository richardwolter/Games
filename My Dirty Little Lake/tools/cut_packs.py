"""Cut 0_mem0ry's object sheets into single objects and catalogue them.

Reads art_source/packs_local/ (git-ignored, filled by tools/fetch_mem0ry_packs.py).
Only object sheets are cut: no shadow copies, no room/door/wall/terrain/building
tiles, no icons, and for the mega bundles only the 32x32-grid sheets (the 16x16
grid sheets are the same drawings laid out tighter).

An object is a connected group of opaque pixels, 8-way, with gaps of up to GLUE
px bridged so a chair's loose leg or a lamp's cord stays with it.

Writes art_source/packs_local/catalogue.json (id, pack, sheet, box) and one
contact sheet per pack, tools/last_packs_<pack>.png, every object numbered by
its id at 3x on the lake's murky water.

Run with ComfyUI's interpreter (PIL, numpy, scipy-free):
    tools/hd_rubbish/run.ps1 style: base python + ComfyUI site-packages
"""
import json, re
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"
GLUE = 1
MIN_PIXELS = 12
SKIP = re.compile(r"(shadow|room_door|door_tiles|walls|terrain|buildings|tileset|icons|font|16x16 grid)", re.I)
WATER = (58, 78, 60)


def sheets():
    for p in sorted(PACKS.rglob("*.png")):
        rel = p.relative_to(PACKS).as_posix()
        if SKIP.search(rel):
            continue
        yield rel.split("/")[0], rel, p


def grow(mask, n):
    m = mask.copy()
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        m = g
    return m


def cut(path):
    a = np.array(Image.open(path).convert("RGBA"))
    solid = a[:, :, 3] > 0
    joined = grow(solid, GLUE)
    H, W = solid.shape
    label = np.zeros((H, W), np.int32)
    n = 0
    boxes = []
    for y in range(H):
        for x in range(W):
            if not joined[y, x] or label[y, x]:
                continue
            n += 1
            q = deque([(y, x)])
            label[y, x] = n
            y0 = y1 = y
            x0 = x1 = x
            count = 0
            while q:
                cy, cx = q.popleft()
                count += solid[cy, cx]
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H and 0 <= nx < W and joined[ny, nx] and not label[ny, nx]:
                            label[ny, nx] = n
                            q.append((ny, nx))
            if count < MIN_PIXELS:
                continue
            # trim to the real pixels inside the grown box
            sub = solid[y0:y1 + 1, x0:x1 + 1] & (label[y0:y1 + 1, x0:x1 + 1] == n)
            ys, xs = np.where(sub)
            boxes.append([int(x0 + xs.min()), int(y0 + ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)])
    boxes.sort(key=lambda b: (b[1] // 16, b[0]))
    return a, boxes


def main():
    catalogue = []
    by_pack = {}
    for pack, rel, path in sheets():
        a, boxes = cut(path)
        for b in boxes:
            entry = {"id": len(catalogue), "pack": pack, "sheet": rel, "box": b}
            catalogue.append(entry)
            by_pack.setdefault(pack, []).append((entry, a))
        print(f"{rel}: {len(boxes)}")
    (PACKS / "catalogue.json").write_text(json.dumps(catalogue, indent=0))
    # fixed cells; an object is drawn at the biggest whole zoom up to 3 that fits its cell
    cell = 104
    for pack, items in by_pack.items():
        cols = 18
        rows = (len(items) + cols - 1) // cols
        img = Image.new("RGB", (cols * cell, rows * (cell + 12)), WATER)
        d = ImageDraw.Draw(img)
        for i, (e, a) in enumerate(items):
            x, y, w, h = e["box"]
            obj = Image.fromarray(a[y:y + h, x:x + w])
            Z = max(1, min(3, (cell - 8) // max(w, h)))
            big = obj.resize((w * Z, h * Z), Image.NEAREST)
            if big.width > cell or big.height > cell:
                big.thumbnail((cell, cell), Image.NEAREST)
            cx, cy = (i % cols) * cell, (i // cols) * (cell + 12)
            img.paste(big, (cx + (cell - big.width) // 2, cy + 12 + (cell - big.height) // 2), big)
            d.text((cx + 2, cy), str(e["id"]), fill=(255, 255, 210))
        img.save(ROOT / f"tools/last_packs_{pack}.png")
    print(len(catalogue), "objects")


if __name__ == "__main__":
    main()

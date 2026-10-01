"""Review sheet for tools/rubbish_map.json: every lake rubbish kind, old beside new.

Each cell shows the old sprite as the lake draws it today (its art at 2x) and the
proposed pack object as it would draw (its art at 1x), both at the same 3x
magnification over murky water, with the kind's material, tier, the object's
catalogue id and both drawn sizes in world px. Grouped by material.

Writes tools/last_rubbish_map.png.
"""
import json, re
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"
WATER = (58, 78, 60)
V = 3          # view magnification
CELL_W, CELL_H = 300, 210


def main():
    mapping = {k: v for k, v in json.loads((ROOT / "tools/rubbish_map.json").read_text()).items() if not k.startswith("_")}
    cat = {e["id"]: e for e in json.loads((PACKS / "catalogue.json").read_text())}
    pieces = {p["name"]: p for p in json.loads((ROOT / "assets/pieces.json").read_text())["pieces"]}
    lake = Image.open(ROOT / "assets/lake_objects.png").convert("RGBA")
    sheets = {}
    names = sorted(mapping)
    cols = 6
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (cols * CELL_W, rows * CELL_H), (34, 38, 34))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        cx, cy = (i % cols) * CELL_W, (i // cols) * CELL_H
        d.rectangle([cx + 2, cy + 2, cx + CELL_W - 3, cy + CELL_H - 3], fill=WATER)
        x, y, w, h = pieces[name]["region"]
        old = lake.crop((x, y, x + w, y + h))
        old_big = old.resize((w * 2 * V, h * 2 * V), Image.NEAREST)
        e = cat[mapping[name]]
        if e["sheet"] not in sheets:
            sheets[e["sheet"]] = Image.open(PACKS / e["sheet"]).convert("RGBA")
        bx, by, bw, bh = e["box"]
        new = sheets[e["sheet"]].crop((bx, by, bx + bw, by + bh))
        new_big = new.resize((bw * V, bh * V), Image.NEAREST)
        base = cy + CELL_H - 12
        for im, ox in ((old_big, cx + 10), (new_big, cx + CELL_W // 2 + 4)):
            scale = min(1.0, (CELL_W // 2 - 14) / im.width, (CELL_H - 50) / im.height)
            if scale < 1.0:
                im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.NEAREST)
            img.paste(im, (ox, base - im.height), im)
        tre = (ROOT / f"resources/trash/{name}.tres").read_text()
        tier = re.search(r"tier = (\d+)", tre)
        d.text((cx + 8, cy + 6), f"{name}  t{tier.group(1) if tier else 0}", fill=(255, 255, 220))
        d.text((cx + 8, cy + 20), f"old {w*2}x{h*2}", fill=(200, 210, 200))
        d.text((cx + CELL_W // 2 + 4, cy + 20), f"#{e['id']} {bw}x{bh}", fill=(255, 230, 150))
    img.save(ROOT / "tools/last_rubbish_map.png")
    print("done", len(names))


if __name__ == "__main__":
    main()

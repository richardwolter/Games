"""Render catalogue objects by id, labelled with id and size, for picking.

    python tools/show_ids.py 1395-1432 179 186 ...   -> tools/last_ids.png
"""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"


def main():
    ids = []
    for a in sys.argv[1:]:
        if "-" in a:
            lo, hi = map(int, a.split("-"))
            ids += list(range(lo, hi + 1))
        else:
            ids.append(int(a))
    cat = {e["id"]: e for e in json.loads((PACKS / "catalogue.json").read_text())}
    sheets = {}
    cell, cols = 120, 12
    rows = (len(ids) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 26)), (58, 78, 60))
    d = ImageDraw.Draw(img)
    for i, k in enumerate(ids):
        e = cat[k]
        if e["sheet"] not in sheets:
            sheets[e["sheet"]] = Image.open(PACKS / e["sheet"]).convert("RGBA")
        x, y, w, h = e["box"]
        obj = sheets[e["sheet"]].crop((x, y, x + w, y + h))
        z = max(1, min(3, (cell - 6) // max(w, h)))
        big = obj.resize((w * z, h * z), Image.NEAREST)
        if big.width > cell or big.height > cell:
            big.thumbnail((cell - 4, cell - 4), Image.NEAREST)
        cx, cy = (i % cols) * cell, (i // cols) * (cell + 26)
        img.paste(big, (cx + (cell - big.width) // 2, cy + 26 + (cell - big.height) // 2), big)
        d.text((cx + 3, cy + 2), f"{k}", fill=(255, 255, 160))
        d.text((cx + 3, cy + 13), f"{w}x{h}", fill=(200, 220, 200))
    img.save(ROOT / "tools/last_ids.png")


if __name__ == "__main__":
    main()

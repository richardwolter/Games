"""Give the pigeons the rubbish's black outline (2026-09-25).

Reads the pack's sheet and its mechanical cut (assets/pigeons.json, regions as painted),
rings every opaque pixel of every cell with one pixel of pure black OUTSIDE the silhouette,
and writes assets/pigeons_inked.png plus assets/pigeons_inked.json with every region grown
by one pixel a side to hold the ring. The pack's own sheet and cut are left alone: re-run
this after re-running tools/slice_pigeons.gd. psd-extract venv python, project root;
reimport after.
"""
import json
from pathlib import Path
from PIL import Image

SHEET = Path("assets/Pigeons/Original Diminsions/Pigeon Sprite Sheet.png")
CUT = Path("assets/pigeons.json")
OUT_PNG = Path("assets/pigeons_inked.png")
OUT_JSON = Path("assets/pigeons_inked.json")
INK = (0, 0, 0, 255)


def main():
    src = Image.open(SHEET).convert("RGBA")
    cut = json.loads(CUT.read_text(encoding="utf-8"))
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    grown = []
    for cell in cut["cells"]:
        x, y, w, h = cell["region"]
        piece = src.crop((x, y, x + w, y + h))
        big = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
        big.paste(piece, (1, 1))
        a = big.load()
        ring = []
        for py in range(h + 2):
            for px in range(w + 2):
                if a[px, py][3]:
                    continue
                if any(0 <= px + dx < w + 2 and 0 <= py + dy < h + 2 and a[px + dx, py + dy][3]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    ring.append((px, py))
        for p in ring:
            a[p] = INK
        box = (x - 1, y - 1, x + w + 1, y + h + 1)
        for other in grown:
            if not (box[2] <= other[0] or other[2] <= box[0] or box[3] <= other[1] or other[3] <= box[1]):
                raise SystemExit("%s's ring runs into a neighbour" % cell["name"])
        grown.append(box)
        out.alpha_composite(big, (x - 1, y - 1))
        cell = dict(cell)
        cell["region"] = [x - 1, y - 1, w + 2, h + 2]
        cell_list.append(cell)
    out.save(OUT_PNG)
    data = dict(cut)
    data["cells"] = cell_list
    OUT_JSON.write_text(json.dumps(data, indent="\t") + "\n", encoding="utf-8")


cell_list = []
if __name__ == "__main__":
    main()

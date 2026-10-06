"""Pack every catalogued 0_mem0ry object into one atlas for the pack tagger page.

Reads art_source/packs_local/catalogue.json (tools/cut_packs.py) and writes, into
art_source/packs_local/tagger/ (git-ignored with the packs, since the atlas IS
their pixels): atlas.png and objects.json ([id, pack, x, y, w, h] per object, in
atlas pixels, plus the pack names). The tagger artifact publishes these two files
beside its page; it is private and must not be shared, as the licence forbids
redistribution.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "art_source/packs_local"
OUT = PACKS / "tagger"
WIDTH = 2048
GAP = 1


def main():
    cat = json.loads((PACKS / "catalogue.json").read_text())
    sheets = {}
    items = []
    for e in cat:
        if e["sheet"] not in sheets:
            sheets[e["sheet"]] = Image.open(PACKS / e["sheet"]).convert("RGBA")
        x, y, w, h = e["box"]
        items.append((e, sheets[e["sheet"]].crop((x, y, x + w, y + h))))
    order = sorted(items, key=lambda it: -it[1].height)
    placed, cx, cy, row = {}, 0, 0, 0
    for e, im in order:
        if cx + im.width > WIDTH:
            cx, cy, row = 0, cy + row + GAP, 0
        placed[e["id"]] = (cx, cy)
        cx += im.width + GAP
        row = max(row, im.height)
    atlas = Image.new("RGBA", (WIDTH, cy + row), (0, 0, 0, 0))
    packs = sorted({e["pack"] for e, _ in items})
    rows = []
    for e, im in items:
        x, y = placed[e["id"]]
        atlas.paste(im, (x, y))
        rows.append([e["id"], packs.index(e["pack"]), x, y, im.width, im.height])
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / "atlas.png", optimize=True)
    (OUT / "objects.json").write_text(json.dumps({"packs": packs, "objects": rows}, separators=(",", ":")))
    print(atlas.size, len(rows), (OUT / "atlas.png").stat().st_size)


if __name__ == "__main__":
    main()

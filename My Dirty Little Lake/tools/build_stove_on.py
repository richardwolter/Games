"""Bake the lit stove, by rule, off the plain one.

The PSD has one stove. Its switched-on view is the same picture with the four burners on the
hob glowing red, their middles orange, and the oven window lit a dull red with a hotter
middle. Written to art_source/decoration_extracted/stove_on.png, which tools/decor_sets.json
names as a plain file (the bed's convention). Rules first: Richard may polish the PNG by hand.
Run from the project root with the psd-extract venv python, then tools/build_decor.py.
"""
import json
from pathlib import Path
from PIL import Image

HERE = Path("art_source/decoration_extracted")
DARK = {(62, 24, 27), (86, 43, 50), (73, 40, 45)}
HOB = (3, 2, 27, 16)      # x0, y0, x1, y1 of the cooktop, painted pixels
OVEN = (8, 25, 22, 36)    # the oven door's window
BURNER = (94, 53, 62)       # the burner plates, as painted
BURNER_RIM, BURNER_HOT = (196, 44, 32), (242, 122, 46)
OVEN_RIM, OVEN_HOT = (140, 38, 26), (214, 84, 36)


def main():
    tree = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    src = [l for l in tree["layers"] if l["name"] == "Stove" and l["group_path"] == ["Decoration"]][0]
    im = Image.open(HERE / src["file"]).convert("RGBA")
    px = im.load()
    out = im.copy()
    op = out.load()
    for box, rim, hot in ((HOB, BURNER_RIM, BURNER_HOT),):
        x0, y0, x1, y1 = box
        inside = lambda x, y: x0 <= x <= x1 and y0 <= y <= y1
        # A burner (or the window) is a patch of one colour walled in by the dark outline,
        # not touching the edge of its box: the hob's own frame runs to the edge and is not lit.
        seen = set()
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x, y) in seen or px[x, y][:3] in DARK or px[x, y][3] == 0:
                    continue
                colour, patch, todo, edge = px[x, y][:3], [], [(x, y)], False
                seen.add((x, y))
                while todo:
                    cx, cy = todo.pop()
                    patch.append((cx, cy))
                    if cx in (x0, x1) or cy in (y0, y1):
                        edge = True
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if inside(nx, ny) and (nx, ny) not in seen and px[nx, ny][:3] == colour:
                            seen.add((nx, ny))
                            todo.append((nx, ny))
                if edge or len(patch) < 6 or colour != BURNER:
                    continue
                for cx, cy in patch:
                    op[cx, cy] = hot + (255,)
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if inside(nx, ny) and px[nx, ny][:3] in DARK:
                            op[nx, ny] = rim + (255,)
    # The oven window is dark glass: every dark pixel of it lights, its outer ring dimmer.
    x0, y0, x1, y1 = OVEN
    dark = lambda x, y: x0 <= x <= x1 and y0 <= y <= y1 and px[x, y][:3] in DARK
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if dark(x, y):
                inner = all(dark(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                op[x, y] = (OVEN_HOT if inner else OVEN_RIM) + (255,)
    out.save(HERE / "stove_on.png")
    out.resize((out.width * 10, out.height * 10), Image.NEAREST).save("tools/last_stove.png")


if __name__ == "__main__":
    main()

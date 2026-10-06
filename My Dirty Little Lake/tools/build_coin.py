#!/usr/bin/env python
"""The coin, built from rules as pixel art: several designs, each with its toss frames.

    <psd-extract venv python> tools/build_coin.py            # options sheet only
    <psd-extract venv python> tools/build_coin.py --pick B   # also writes assets/coin.png/.json

Every design is a disc `SIZE` art pixels across with a stamp struck in its face. A toss frame
is the disc squashed across to `width` pixels: its thickness shows as a band on the side
turning away, and past edge-on the back is drawn (the struck ring, no stamp, no glint).
Frame order is one half turn and back to the face: FACE, 3/4, 1/2, 1/4, EDGE, back 1/4,
back 1/2, back 3/4, BACK — the game plays it forward then backward for a whole turn.

Options sheet: tools/last_coin_options.png (every design, every frame, 6x). Rules first,
polish after: Richard may repaint assets/coin.png by hand once a design is picked.
"""
import json, math, sys
from PIL import Image

SIZE = 18
OUT = (24, 18, 17, 255)       # the game's near-black outline
GOLD = (255, 204, 77, 255)
GOLD_LIT = (255, 236, 150, 255)
GOLD_DEEP = (184, 133, 36, 255)
GOLD_EDGE = (132, 88, 22, 255)
GLINT = (255, 252, 222, 255)
SHADE = (214, 160, 52, 255)

# Widths across, face to back: a cosine of the turn, rounded to whole pixels.
TURNS = [1.0, 0.75, 0.5, 0.25, 0.0, -0.25, -0.5, -0.75, -1.0]


def stamp_dollar(x, y):
    """A '$' in a 6x8 box centred on the face, in face coordinates -1..1."""
    rows = [
        "..#...",
        ".####.",
        "#.#...",
        ".###..",
        "..#.#.",
        "####..",
        "..#...",
    ]
    return _grid(rows, x, y)


def stamp_star(x, y):
    rows = [
        "...#...",
        "...#...",
        "#######",
        ".#####.",
        "..###..",
        ".##.##.",
        "#.....#",
    ]
    return _grid(rows, x, y)


def stamp_recycle(x, y):
    """Two arrows chasing round a ring, each ending in a wide head: the recycle box's own
    mark. Big on purpose (Richard, 2026-09-26): at 16 px a thin ring read as a smudge."""
    r = math.hypot(x, y)
    a = math.degrees(math.atan2(y, x)) % 360.0
    for start in (15.0, 195.0):
        end = start + 118.0
        if RING_IN <= r <= RING_OUT and _between(a, start, end):
            return True
        if _in_head(x, y, end):
            return True
    return False


RING_IN, RING_OUT = 0.44, 0.74
HEAD_IN, HEAD_OUT, HEAD_SWEEP = 0.22, 0.98, 46.0


def _between(a, lo, hi):
    return (a - lo) % 360.0 <= (hi - lo)


def _in_head(x, y, at):
    """The arrow's head: its base across the ring at `at`, its point ahead round the ring."""
    mid = (RING_IN + RING_OUT) * 0.5
    t0 = math.radians(at)
    tip_t = math.radians(at + HEAD_SWEEP)
    p1 = (HEAD_IN * math.cos(t0), HEAD_IN * math.sin(t0))
    p2 = (HEAD_OUT * math.cos(t0), HEAD_OUT * math.sin(t0))
    p3 = (mid * math.cos(tip_t), mid * math.sin(tip_t))
    def side(a, b, c):
        return (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])
    q = (x, y)
    d1, d2, d3 = side(p1, p2, q), side(p2, p3, q), side(p3, p1, q)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


def stamp_hole(x, y):
    # A square hole struck through: returns 'hole' inside, a raised square rim round it.
    if abs(x) <= 0.2 and abs(y) <= 0.2:
        return "hole"
    return abs(x) <= 0.36 and abs(y) <= 0.36


def _grid(rows, x, y):
    h, w = len(rows), len(rows[0])
    cx = int(math.floor((x * 0.62 + 0.5) * w)) if -0.81 < x < 0.81 else -1
    cy = int(math.floor((y * 0.58 + 0.5) * h)) if -0.87 < y < 0.87 else -1
    return 0 <= cx < w and 0 <= cy < h and rows[cy][cx] == "#"


DESIGNS = {
    "A": ("dollar", stamp_dollar, 2),   # classic: rim two pixels, '$' struck
    "B": ("star", stamp_star, 1),        # thin rim, star
    "C": ("recycle", stamp_recycle, 2),  # the lake's own mark
    "D": ("holed", stamp_hole, 2),       # old cash coin, square hole
}


def frame(design, turn):
    _, stamp, rim = DESIGNS[design]
    img = Image.new("RGBA", (SIZE + 4, SIZE + 2), (0, 0, 0, 0))
    r = SIZE / 2.0
    across = max(round(r * abs(turn)), 1) / r
    thick = 2.0 * (1.0 - abs(turn))  # pixels of edge showing
    lean = -1 if turn >= 0 else 1    # which side the edge band is on
    cx, cy = (SIZE + 4) / 2.0, (SIZE + 2) / 2.0
    px = img.load()
    for j in range(SIZE + 2):
        for i in range(SIZE + 4):
            X = i + 0.5 - cx
            Y = j + 0.5 - cy
            # Face ellipse and the edge's ellipse shifted by the thickness.
            fx = X / (r * across)
            fy = Y / r
            in_face = fx * fx + fy * fy <= 1.0
            ex = (X + lean * thick) / (r * across)
            in_edge = ex * ex + fy * fy <= 1.0
            if not (in_face or in_edge):
                continue
            if not in_face:
                px[i, j] = GOLD_EDGE
                continue
            d = math.sqrt(fx * fx + fy * fy)
            rim_at = 1.0 - rim / r
            if turn < 0:
                # The back: darker, no glint. It carries the stamp too (Richard: the symbol on
                # both sides), seen from behind, so mirrored.
                c = GOLD_DEEP if d > rim_at else SHADE
                if d <= rim_at and stamp(-fx / rim_at, fy / rim_at) is True:
                    c = GOLD_EDGE
                px[i, j] = c
                continue
            if d > rim_at:
                c = GOLD_DEEP if (fx + fy) > 0 else GOLD
            else:
                c = GOLD
                s = stamp(fx / rim_at, fy / rim_at)
                if s == "hole":
                    px[i, j] = (0, 0, 0, 0)
                    continue
                # Light from the upper left: a lit crescent inside the rim, under the stamp.
                if -fx - fy > 0.9 * rim_at and d > rim_at - 0.3:
                    c = GOLD_LIT
                if s:
                    c = GOLD_EDGE
            px[i, j] = c
    # One glint pixel on the face, upper left, only while mostly face on.
    if turn > 0.4:
        gx = int(cx - r * across * 0.45)
        gy = int(cy - r * 0.5)
        if px[gx, gy][3]:
            px[gx, gy] = GLINT
    return outline(img)


def outline(img):
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for j in range(h):
        for i in range(w):
            if src[i, j][3]:
                continue
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if 0 <= a < w and 0 <= b < h and src[a, b][3]:
                    dst[i, j] = OUT
                    break
    # A struck hole is ringed too, from inside.
    return out


def sheet(design):
    frames = [frame(design, t) for t in TURNS]
    fw, fh = frames[0].size
    img = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        img.paste(f, (k * fw, 0))
    return img, fw, fh


def main():
    scale = 6
    rows = []
    for d in DESIGNS:
        img, fw, fh = sheet(d)
        rows.append(img)
    w = max(r.width for r in rows) * scale + 40
    h = sum(r.height * scale + 16 for r in rows) + 16
    board = Image.new("RGBA", (w, h), (26, 51, 51, 255))
    y = 16
    for r in rows:
        board.paste(r.resize((r.width * scale, r.height * scale), Image.NEAREST), (20, y),
                    r.resize((r.width * scale, r.height * scale), Image.NEAREST))
        y += r.height * scale + 16
    board.save("tools/last_coin_options.png")
    print("wrote tools/last_coin_options.png", [f"{k}={v[0]}" for k, v in DESIGNS.items()])
    if "--pick" in sys.argv:
        d = sys.argv[sys.argv.index("--pick") + 1]
        img, fw, fh = sheet(d)
        img.save("assets/coin.png")
        json.dump({"design": DESIGNS[d][0], "frame": [fw, fh], "turns": TURNS},
                  open("assets/coin.json", "w", newline="\n"), indent=1)
        print("wrote assets/coin.png", d)


if __name__ == "__main__":
    main()

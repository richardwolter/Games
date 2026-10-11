"""The shared ground for the house-stages mockup (2026-10-11).

Everything a designer module needs: the captured room in layers, the room's geometry on the
SOURCE PIXEL GRID, the game's palettes, the room's own tile art, and a few pixel helpers.

THE CONTRACT
------------
A module (floor.py, damp.py, veg.py, life.py) exposes

    def draw(stage, t, ctx, under, over): ...

  stage   1 (abandoned), 2 (semi-fixed), 3 (fixed)
  t       seconds since the start of the clip (0.0 for stills); stepped motion uses
          ctx.step(t, fps) -- the game's pixel motion is 8 fps (`pixel_fps`)
  ctx     a Ctx (below): geometry, pieces, palettes, tiles, rain, layout
  under   PIL RGBA, 640x360, the source grid. Drawn OVER the bare room (floor, wall,
          moulding) and UNDER everything the game draws on top of the floor (the room's dim,
          the shadows, the furniture, dogs, the player, the light). Inside the shed rect the
          furniture covers it; OUTSIDE the shed rect (over the lake) it is the top of the
          picture, so a vine hanging off the frame onto the lake is drawn here too.
  over    PIL RGBA, 640x360. Drawn on top of everything: things in the air (drips falling,
          bees, butterflies, petals, dust motes), and veils.

Optionally:
    def stage_up(frm, p, ctx, under, over): ...   p 0..1 over the ~2 s play-in, frm 1 or 2
    CLOSEUPS = [(name, stage, (x, y, w, h))]      source-grid crops worth a 3x close-up

One SOURCE pixel = 3x3 SCREEN pixels in the 1920x1080 captures. Draw whole source pixels
only (that is the game's rule: pixel art, never finer). Coordinates below are absolute on
the 640x360 grid unless named `*_rel` (relative to the floor's top-left, the game's own
placement pixels: a hole's blocking rect in the game will be written in those).
"""
from __future__ import annotations

import json
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CAP = HERE / "captures"
OUT = HERE / "out"
S = 3                     # screen px per source px
GRID = (640, 360)         # the source grid of a 1920x1080 frame


# ---------------------------------------------------------------- palette

def _palette() -> dict:
    out = {}
    for line in (ROOT / "resources" / "palette.tres").read_text(encoding="utf-8").splitlines():
        if "= Color(" in line:
            name, _, rest = line.partition(" = Color(")
            r, g, b, *_ = [float(v) for v in rest.rstrip(")").split(",")]
            out[name.strip()] = (round(r * 255), round(g * 255), round(b * 255))
    return out


PAL = _palette()

# The outside hut's own ramps (tools/build_shed_v2.py), darkest first. The inside must match
# the outside: reuse these rather than inventing greens and pinks.
INK = (24, 18, 17)
MOSS = [(30, 56, 36), (52, 92, 46), (86, 132, 56), (128, 170, 72), (180, 206, 104)]
LEAF = [(22, 44, 32), (38, 78, 44), (66, 120, 52), (110, 162, 66), (168, 204, 96)]
DEAD = [(56, 46, 30), (92, 78, 44), (132, 114, 62), (172, 154, 90)]
FRESH = [(80, 50, 36), (128, 86, 56), (176, 126, 82), (214, 166, 108), (236, 198, 140), (246, 222, 170)]
HOLE = [(18, 13, 13), (32, 23, 21), (48, 34, 28)]
RAFTER = [(64, 42, 32), (98, 66, 46)]
PINK = [(140, 40, 66), (214, 84, 118), (248, 160, 178), (255, 214, 220)]
YELLOW = [(190, 120, 30), (240, 190, 70), (255, 232, 140)]
WHITE = [(170, 170, 170), (226, 224, 214), (255, 255, 246)]
BLUE = [(56, 70, 150), (100, 130, 214), (170, 196, 246)]
RED = [(130, 30, 30), (206, 62, 52), (246, 122, 96)]
WISTERIA = [(74, 46, 116), (132, 92, 186), (190, 158, 232), (228, 210, 250)]
CLAY = [(84, 38, 30), (140, 68, 46), (192, 106, 70), (224, 150, 104)]
# The lake's water, clean ramp, for puddles (a puddle in a house is clear water).
WATER = [PAL["water_clean_deep"], PAL["water_clean_mid"], PAL["water_clean"],
         PAL["water_clean_shallow"], PAL["water_clean_light"]]
FOAM = PAL.get("foam", (236, 242, 240))


# ---------------------------------------------------------------- tiles

def tile(name: str) -> Image.Image:
    """The room's own art, at source size: Floor_Tile (16x32), Wallpaper_Tile (15x14),
    Border_* (the moulding)."""
    return Image.open(ROOT / "assets" / f"Shed_{name}.png").convert("RGBA")


# ---------------------------------------------------------------- geometry

class Ctx:
    def __init__(self, stage: int, rain: float = 0.0):
        rec = json.loads((CAP / "layers.json").read_text(encoding="utf-8"))
        st = rec["stages"][stage - 1]
        self.stage = stage
        self.rain = rain                      # 0 dry .. 1 a full shower outside

        def src(box):
            return tuple(int(round(v / S)) for v in box)

        self.floor = src(rec["floor"])        # (x, y, w, h) the floor box, moulding included
        self.wall = src(rec["wall"])          # the back wall strip above the floor
        self.shed = src(rec["shed"])          # wall + floor: the whole room's drawn rect
        self.door = src(rec["door"])          # the dark opening in the back wall
        self.board = src(rec["board"])        # the Decorate shelf beside the room (keep clear)
        wx, wy = rec["window_at"]
        self.window = (int(round(wx / S)), int(round(wy / S)))  # where the sun shaft comes in
        self.border = rec["border_px"]        # moulding piece sizes in source px
        cols, rows, cell, wall_rows = rec["cells"]
        self.cell = cell                      # 8 source px: the walkers' grid
        fx, fy, fw, fh = self.floor
        bv = self.border["vertical"][0]       # side moulding width (6)
        bh = self.border["horizontal"][1]     # top run height (10)
        bs = self.border["sill"][1]           # bottom sill height (10)
        # The boards a walker can stand on and a piece can be put on: inside the moulding.
        self.boards = (fx + bv, fy + bh, fw - 2 * bv, fh - bh - bs)
        # Pieces: rect = where the picture's span stands (the game's footprint), base = the
        # bottom `base` rows of it, the part that takes floor. Absolute source coords.
        self.pieces = []
        for p in st["pieces"]:
            ax, ay = p["at"]
            sw, sh = p["span"]
            x, y = fx + ax, fy + ay
            self.pieces.append({
                "piece": p["piece"], "view": p["view"],
                "rect": (x, y, sw, sh),
                "base": (x, y + sh - p["base"], sw, p["base"]),
            })
        self.dogs = [(fx + d["at"][0] * cell, fy + d["at"][1] * cell, d["seat"]) for d in st["dogs"]]
        px, py = st["player_cells"]
        self.player = (fx + px * cell, fy + py * cell)   # the player's feet
        self.layout = load_layout()

    def to_rel(self, x, y):
        return x - self.floor[0], y - self.floor[1]

    def to_abs(self, x, y):
        return x + self.floor[0], y + self.floor[1]

    @staticmethod
    def step(t: float, fps: float = 8.0) -> float:
        """The game's stepped clock: time held to whole ticks of `fps`."""
        return math.floor(t * fps) / fps


def load_layout() -> dict:
    p = HERE / "layout.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


# ---------------------------------------------------------------- pixel helpers

def put(img: Image.Image, x, y, c, a: int = 255):
    """One source pixel, alpha-composited onto what is there."""
    x, y = int(x), int(y)
    if 0 <= x < img.width and 0 <= y < img.height:
        if a >= 255 or len(c) == 4 and c[3] >= 255:
            img.putpixel((x, y), (c[0], c[1], c[2], 255))
        else:
            under = img.getpixel((x, y))
            aa = a / 255.0
            ua = under[3] / 255.0
            oa = aa + ua * (1 - aa)
            if oa <= 0:
                return
            col = tuple(int(round((c[i] * aa + under[i] * ua * (1 - aa)) / oa)) for i in range(3))
            img.putpixel((x, y), col + (int(round(oa * 255)),))


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def shade(c, k):
    """k < 1 darker, k > 1 lighter (towards white)."""
    if k <= 1:
        return tuple(int(round(v * k)) for v in c[:3])
    return mix(c[:3], (255, 255, 255), min(1.0, k - 1))


def h(x, y, seed=0) -> float:
    """A stable hash in 0..1."""
    n = (int(x) * 374761393 + int(y) * 668265263 + int(seed) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / float(0xFFFFFF)


def vnoise(x, y, cell, seed=0) -> float:
    """Smooth value noise 0..1 with `cell`-pixel features."""
    gx, gy = x / cell, y / cell
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = h(x0, y0, seed), h(x0 + 1, y0, seed)
    c, d = h(x0, y0 + 1, seed), h(x0 + 1, y0 + 1, seed)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


def shell_src(stage: int) -> Image.Image:
    """The bare room on the source grid (read-only reference: what colour a board or the
    wallpaper is at a spot). The centre pixel of each 3x3 block of the shell capture."""
    im = Image.open(CAP / f"s{stage}_shell.png").convert("RGB")
    a = np.asarray(im)[1::S, 1::S]
    return Image.fromarray(a.copy())


def blank() -> Image.Image:
    return Image.new("RGBA", GRID, (0, 0, 0, 0))


# ---------------------------------------------------------------- compositing

_cache = {}


def _layers(stage: int):
    if stage in _cache:
        return _cache[stage]
    rd = lambda n: np.asarray(Image.open(CAP / f"s{stage}_{n}.png").convert("RGB")).astype(np.float32) / 255
    full, b, g, shell = rd("full"), rd("keyb"), rd("keyg"), rd("shell")
    alpha = np.clip(1 - (g - b) / 0.5, 0, 1)          # per channel coverage of the top layer
    rec = json.loads((CAP / "layers.json").read_text(encoding="utf-8"))
    x, y, w, hh = [int(v) for v in rec["shed"]]
    inside = np.zeros(full.shape[:2], bool)
    inside[y:y + hh, x:x + w] = True
    _cache[stage] = (full, b, alpha, shell, inside)
    return _cache[stage]


def _up(img: Image.Image) -> np.ndarray:
    a = np.asarray(img).astype(np.float32) / 255
    return np.repeat(np.repeat(a, S, axis=0), S, axis=1)


def compose(stage: int, under: Image.Image, over: Image.Image) -> Image.Image:
    full, top, alpha, shell, inside = _layers(stage)
    u = _up(under)
    base = shell * (1 - u[..., 3:]) + u[..., :3] * u[..., 3:]
    room = top + (1 - alpha) * base
    out = np.where(inside[..., None], room, base)
    o = _up(over)
    out = out * (1 - o[..., 3:]) + o[..., :3] * o[..., 3:]
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))


def room_crop(img: Image.Image, pad: int = 20) -> Image.Image:
    """The room and its frame with `pad` source px of lake round it, in screen px."""
    rec = json.loads((CAP / "layers.json").read_text(encoding="utf-8"))
    x, y, w, hh = rec["shed"]
    p = pad * S
    return img.crop((int(x - p), int(y - p), int(x + w + p), int(y + hh + p)))

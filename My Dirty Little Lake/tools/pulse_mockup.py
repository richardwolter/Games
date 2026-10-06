"""The HUD buttons' pulse, three ways, for Richard to pick (2026-10-05, `/grill-me`).

Reads `tools/last_pulse_base.png` and `.log` (`tools/shot_pulse_base.tscn`: the two picture
buttons at rest over the lake) and writes `tools/last_pulse_mockup.gif` (animated) and
`tools/last_pulse_mockup.png` (a strip of frames per option):

  A  bounce + motes: the button hops on each beat and squashes as it lands; gold pixel motes
     drift up off its top and sides.
  B  pixel ray burst: whole-pixel spokes turning slowly behind the button over a soft core.
  C  both.

Each option shows the burst (a hop every beat) then idle (one hop, slower rays, fewer motes).
Drawn at the HUD's canvas resolution (1280 wide) and blown up 3x nearest to look at.

  PYTHONPATH=<psd-extract site-packages> python tools/pulse_mockup.py
"""
import math
import random

from PIL import Image, ImageDraw

BASE = "tools/last_pulse_base.png"
LOG = "tools/last_pulse_base.log"
GIF = "tools/last_pulse_mockup.gif"
SHEET = "tools/last_pulse_mockup.png"

SHOW = 3          # blow-up for looking at
FPS = 30
BURST = 4.0       # s, as HudSkin.PULSE_TIME
BEATS = 3.5       # hops in the burst, as HudSkin.PULSE_BEATS
IDLE = 3.0        # s of idle shown after the burst
IDLE_HOP = 2.0    # s into idle the one hop lands

GOLD = (255, 214, 92)
GOLD_LIT = (255, 244, 190)
GOLD_DEEP = (214, 150, 40)
RIM = (24, 18, 17)

HOP = 6           # canvas px at the top of a hop
SQUASH = 0.08     # how much a landing squashes the button (height share)
RAYS = 12
RAY_SPIN = 0.35   # rad/s in the burst, half in idle


def read_boxes():
    boxes = {}
    scale = 1.5
    for line in open(LOG, encoding="utf-8"):
        part = line.split()
        if part[0] == "scale":
            scale = float(part[1])
        else:
            boxes[part[0]] = [int(v) for v in part[1:]]
    return {k: tuple(round(v / scale) for v in b) for k, b in boxes.items()}, scale


def hop_at(t):
    """Height (0..1) and squash (0..1) of the hop at time t, and the pulse's strength."""
    if t < BURST:
        beat = BURST / BEATS
        phase = (t % beat) / beat
        strength = 1.0
    else:
        phase = (t - BURST - IDLE_HOP + 0.4) / 0.6
        strength = 0.6
        if phase < 0.0 or phase > 1.0:
            return 0.0, 0.0, 0.45
    # Up fast, down under gravity, then a squash for the last fifth.
    if phase < 0.8:
        p = phase / 0.8
        height = 4.0 * p * (1.0 - p)
        squash = 0.0
    else:
        height = 0.0
        squash = math.sin((phase - 0.8) / 0.2 * math.pi)
    return height * strength, squash * strength, strength if t < BURST else 0.45


def cut_button(frame, box):
    x, y, w, h = box
    return frame.crop((x, y, x + w, y + h))


def backdrop(frame, box):
    """The lake under the button, faked from the strip just below it, for a lifted button."""
    x, y, w, h = box
    out = frame.copy()
    strip = frame.crop((x, y + h, x + w, y + h + 12))
    for yy in range(y, y + h, 12):
        out.paste(strip, (x, yy))
    return out


def draw_button(canvas, button, box, height, squash):
    x, y, w, h = box
    lift = round(height * HOP)
    if squash > 0.0:
        sh = max(1, round(h * (1.0 - SQUASH * squash)))
        sw = round(w * (1.0 + SQUASH * 0.5 * squash))
        part = button.resize((sw, sh), Image.NEAREST)
        canvas.alpha_composite(part, (x - (sw - w) // 2, y + h - sh))
    else:
        canvas.alpha_composite(button, (x, y - lift))


def put(px, x, y, colour, alpha, size):
    x, y = int(x), int(y)
    w, h = size
    for yy in range(y, y + 1):
        pass
    if 0 <= x < w and 0 <= y < h:
        r, g, b, a = px[x, y]
        k = alpha
        px[x, y] = (
            round(r + (colour[0] - r) * k), round(g + (colour[1] - g) * k),
            round(b + (colour[2] - b) * k), 255,
        )


class Motes:
    def __init__(self, box, seed):
        self.box = box
        self.rng = random.Random(seed)
        self.live = []
        self.carry = 0.0

    def step(self, dt, rate):
        x, y, w, h = self.box
        self.carry += rate * dt
        while self.carry >= 1.0:
            self.carry -= 1.0
            side = self.rng.random()
            if side < 0.6:
                at = [x + self.rng.uniform(4, w - 4), y + self.rng.uniform(-2, 6)]
            elif side < 0.8:
                at = [x - self.rng.uniform(0, 3), y + self.rng.uniform(8, h * 0.7)]
            else:
                at = [x + w + self.rng.uniform(0, 3), y + self.rng.uniform(8, h * 0.7)]
            self.live.append({
                "at": at, "vy": -self.rng.uniform(10, 22), "sway": self.rng.uniform(0, 6.28),
                "age": 0.0, "life": self.rng.uniform(0.9, 1.6), "big": self.rng.random() < 0.5,
                "star": self.rng.random() < 0.2,
            })
        for m in self.live:
            m["age"] += dt
            m["at"][1] += m["vy"] * dt
            m["at"][0] += math.sin(m["age"] * 4.0 + m["sway"]) * 6.0 * dt
        self.live = [m for m in self.live if m["age"] < m["life"]]

    def draw(self, canvas):
        px = canvas.load()
        size = canvas.size
        for m in self.live:
            k = m["age"] / m["life"]
            # Fades in hard steps, the way the foam dissolves: whole, then a dithered half.
            alpha = 1.0 if k < 0.55 else (0.6 if k < 0.8 else 0.3)
            x, y = round(m["at"][0]), round(m["at"][1])
            if m["star"] and k < 0.7:
                for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                    put(px, x + dx, y + dy, RIM, alpha * 0.5, size)
                for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    put(px, x + dx, y + dy, GOLD_LIT if (dx, dy) == (0, 0) else GOLD, alpha, size)
            elif m["big"]:
                for dx, dy in ((-1, 0), (2, 0), (-1, 1), (2, 1), (0, -1), (1, -1), (0, 2), (1, 2)):
                    put(px, x + dx, y + dy, RIM, alpha * 0.6, size)
                put(px, x, y, GOLD_LIT, alpha, size)
                put(px, x + 1, y, GOLD, alpha, size)
                put(px, x, y + 1, GOLD, alpha, size)
                put(px, x + 1, y + 1, GOLD_DEEP, alpha, size)
            else:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    put(px, x + dx, y + dy, RIM, alpha * 0.5, size)
                put(px, x, y, GOLD_LIT, alpha, size)


def draw_rays(canvas, box, spin, strength):
    """Whole-pixel spokes behind the button, long and short by turns, over a soft core."""
    x, y, w, h = box
    cx, cy = x + w / 2.0, y + h / 2.0
    px = canvas.load()
    size = canvas.size
    reach_long = max(w, h) * 0.5 + 34 * (0.7 + 0.3 * strength)
    reach_short = max(w, h) * 0.5 + 18 * (0.7 + 0.3 * strength)
    half = math.radians(7.0)
    x0, y0 = int(cx - reach_long - 2), int(cy - reach_long - 2)
    x1, y1 = int(cx + reach_long + 2), int(cy + reach_long + 2)
    for yy in range(max(0, y0), min(size[1], y1)):
        for xx in range(max(0, x0), min(size[0], x1)):
            dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
            # Seen on the 2:1? No: the HUD is upright, rays are round.
            d = math.hypot(dx, dy)
            if d < 1.0:
                continue
            a = math.atan2(dy, dx) - spin
            step = 2.0 * math.pi / RAYS
            k = int(math.floor((a + step / 2) / step)) % RAYS
            off = abs(((a + step / 2) % step) - step / 2)
            reach = reach_long if k % 2 == 0 else reach_short
            # A spoke narrows a little to its tip.
            if off > half * (1.0 - 0.45 * d / reach) or d > reach:
                # The soft core: a round glow, stepped in three rings.
                core = max(w, h) * 0.5 + 10
                if d < core:
                    ring = 0.5 if d < core - 6 else (0.32 if d < core - 3 else 0.16)
                    put(px, xx, yy, GOLD, ring * strength, size)
                continue
            t = d / reach
            alpha = 1.0 if t < 0.55 else (0.75 if t < 0.8 else 0.4)
            colour = GOLD_LIT if t < 0.45 else GOLD
            put(px, xx, yy, colour, alpha * strength, size)


def main():
    boxes, scale = read_boxes()
    frame_full = Image.open(BASE).convert("RGBA")
    canvas_size = (round(frame_full.width / scale), round(frame_full.height / scale))
    frame = frame_full.resize(canvas_size, Image.LANCZOS)
    region = (960, 0, 1280, 190)
    options = ["A", "B", "C"]
    buttons = {name: cut_button(frame, box) for name, box in boxes.items()}
    under = frame
    for box in boxes.values():
        under = backdrop(under, box)
    motes = {o: {n: Motes(b, hash((o, n)) & 0xFFFF) for n, b in boxes.items()} for o in options}
    frames = []
    total = BURST + IDLE
    count = int(total * FPS)
    sheet_rows = {o: [] for o in options}
    sheet_at = [round(v * FPS) for v in (0.1, 0.45, 0.85, 1.05, 2.2, BURST + IDLE_HOP - 0.15)]
    for i in range(count):
        t = i / FPS
        height, squash, strength = hop_at(t)
        spin = RAY_SPIN * t if t < BURST else RAY_SPIN * BURST + RAY_SPIN * 0.5 * (t - BURST)
        tiles = []
        for o in options:
            canvas = under.copy()
            for name, box in boxes.items():
                if o in ("B", "C"):
                    draw_rays(canvas, box, spin + (0.4 if name == "shed" else 0.0), strength)
            for name, box in boxes.items():
                if o in ("A", "C"):
                    m = motes[o][name]
                    m.step(1.0 / FPS, 30.0 if t < BURST else 8.0)
                if o in ("A", "C"):
                    draw_button(canvas, buttons[name], box, height, squash)
                else:
                    canvas.alpha_composite(buttons[name], box[:2])
                if o in ("A", "C"):
                    motes[o][name].draw(canvas)
            tile = canvas.crop(region)
            label = ImageDraw.Draw(tile)
            label.rectangle((0, 0, 26, 12), fill=(0, 0, 0, 200))
            label.text((3, 1), o + (" burst" if t < BURST else " idle")[:2], fill=(255, 255, 255))
            tiles.append(tile)
            if i in sheet_at:
                sheet_rows[o].append(tile)
        row = Image.new("RGBA", (tiles[0].width * 3 + 8, tiles[0].height), (20, 20, 20, 255))
        for k, tile in enumerate(tiles):
            row.paste(tile, (k * (tile.width + 4), 0))
        frames.append(row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert("P",
            palette=Image.ADAPTIVE))
    frames[0].save(GIF, save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    tw, th = sheet_rows["A"][0].size
    sheet = Image.new("RGBA", (tw * len(sheet_at) + 4 * len(sheet_at), (th + 4) * 3),
        (20, 20, 20, 255))
    for r, o in enumerate(options):
        for c, tile in enumerate(sheet_rows[o]):
            sheet.paste(tile, (c * (tw + 4), r * (th + 4)))
    sheet.resize((sheet.width * SHOW // 2, sheet.height * SHOW // 2), Image.NEAREST).save(SHEET)
    print("wrote", GIF, SHEET, len(frames), "frames")


if __name__ == "__main__":
    main()

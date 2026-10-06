"""Animate the Modern Daedalus logo: the figure glides in from the left beating its wings,
lands in the pose, then the three words are inked on. Writes logo_anim.gif.

Reads pieces/ from cut.py. `python anim.py test` writes test_wings.png instead: the wings
swung to both ends of the beat, for checking the seams.

Every piece is drawn with one transform per frame (its own swing times the figure's flight),
at the output size, so nothing is resampled twice.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from cut import HINGE_BACK, HINGE_FRONT

HERE = Path(__file__).parent
PIECES = HERE / "pieces"

FPS = 30
SCALE = 2                  # output size over the source's
SUB = 3                    # motion-blur subframes, spread over half a frame (a 180 shutter)

# The glide.
FLY_TIME = 1.5             # s from off the left edge to rest
FLY_FROM = -560            # source px, start offset (the figure is fully off screen)
BOB = 6                    # source px of rise and fall per beat on the way in
TILT = 7.0                 # degrees nose-up at the start, easing level
SETTLE = 0.18              # s of overshoot and settle at the end
OVERSHOOT = 9              # source px past the rest point

# The wings: angle (degrees, + is downstroke) and a squash across the wing as it swings
# edge-on, so a beat reads as a wing turning, not a flat card hinging.
BEATS = 2.5                # beats during the glide
BEAT_BACK = 24.0
BEAT_FRONT = 20.0
SQUASH = 0.22
RIM_IN = 4.0               # the cut's paper rim is whole by a quarter of the beat

# The words: when each is pressed (s), and how long the press lasts.
WORDS = [("modern", 1.62), ("daedalus", 1.86), ("studio", 2.12)]
PRESS = 0.26
PRESS_GROW = 0.07          # starts this much bigger
PRESS_SPREAD = 2           # source px of ink spread at the moment of the press
HOLD_UNTIL = 3.4           # s, total length


def load(name):
    img = Image.open(PIECES / f"{name}.png").convert("RGBA")
    return img.resize((img.width * SCALE, img.height * SCALE), Image.LANCZOS)


def ease_out(t):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** 3


def ease_in_out(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def move(dx, dy):
    return np.array([[1, 0, dx], [0, 1, dy], [0, 0, 1]], float)


def turn(angle):
    a = math.radians(angle)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def squash(along, k):
    """Scale by k across the unit direction `along`."""
    vx, vy = -along[1], along[0]
    return np.array([[1 + (k - 1) * vx * vx, (k - 1) * vx * vy, 0],
                     [(k - 1) * vx * vy, 1 + (k - 1) * vy * vy, 0], [0, 0, 1]])


def about(centre, m):
    return move(*centre) @ m @ move(-centre[0], -centre[1])


def draw(img, m):
    """`img` (at output size) under the source-space map `m`."""
    s = np.diag([SCALE, SCALE, 1.0])
    inv = np.linalg.inv(s @ m @ np.linalg.inv(s))
    return img.transform(img.size, Image.AFFINE, tuple(inv[:2].flatten()), resample=Image.BICUBIC)


def direction(hinge, tip):
    dx, dy = tip[0] - hinge[0], tip[1] - hinge[1]
    n = math.hypot(dx, dy)
    return dx / n, dy / n


BACK_ALONG = direction(HINGE_BACK, (103, 107))
FRONT_ALONG = direction(HINGE_FRONT, (518, 184))
PIVOT = (300, 160)         # where the whole figure turns


class Logo:
    def __init__(self):
        self.back = load("wing_back")
        self.front = load("wing_front")
        self.body = load("body")
        self.rims = {n: np.asarray(load(f"{n}_rim"), np.float32)
                     for n in ("wing_back", "wing_front", "body")}
        self.words = {name: load(name) for name, _ in WORDS}
        self.size = self.body.size

    def rim(self, name, show):
        a = self.rims[name].copy()
        a[..., 3] *= show
        return Image.fromarray(a.astype(np.uint8), "RGBA")

    def figure(self, beat, at, tilt):
        """The figure as one RGBA layer: wings at `beat` (-1 up .. 1 down), moved to `at`
        and tilted by `tilt` degrees."""
        flight = move(*at) @ about(PIVOT, turn(tilt))
        k = 1 - SQUASH * abs(beat)
        # The back wing swings the opposite way round to the front one: its tip is behind.
        back = flight @ about(HINGE_BACK, turn(-beat * BEAT_BACK) @ squash(BACK_ALONG, k))
        front = flight @ about(HINGE_FRONT, turn(beat * BEAT_FRONT) @ squash(FRONT_ALONG, k))
        show = min(1.0, abs(beat) * RIM_IN)
        # Order, back to front: the right wing, the body, the left wing over the body.
        layer = Image.new("RGBA", self.size, (0, 0, 0, 0))
        layer.alpha_composite(draw(self.front, front))
        if show:
            layer.alpha_composite(draw(self.rim("wing_front", show), front))
            layer.alpha_composite(draw(self.rim("body", show), flight))
        layer.alpha_composite(draw(self.body, flight))
        if show:
            layer.alpha_composite(draw(self.rim("wing_back", show), back))
        layer.alpha_composite(draw(self.back, back))
        return layer

    def figure_at(self, t):
        if t >= FLY_TIME + SETTLE:
            return self.figure(0.0, (0, 0), 0.0)
        p = ease_out(t / FLY_TIME)
        x = FLY_FROM * (1 - p)
        # Overshoot: pass the rest point by OVERSHOOT and come back over SETTLE.
        if t > FLY_TIME * 0.7:
            u = (t - FLY_TIME * 0.7) / (FLY_TIME * 0.3 + SETTLE)
            x += OVERSHOOT * math.sin(math.pi * min(u, 1.0))
        phase = t / FLY_TIME * BEATS
        fade = 1 - ease_in_out(t / (FLY_TIME + SETTLE))
        beat = math.sin(2 * math.pi * phase) * fade
        y = -BOB * math.sin(2 * math.pi * phase - 0.6) * fade
        tilt = -TILT * (1 - ease_out(t / FLY_TIME))
        return self.figure(beat, (x, y), tilt)

    def word_at(self, name, start, t):
        img = self.words[name]
        u = (t - start) / PRESS
        if u <= 0:
            return None
        if u >= 1:
            return img
        e = ease_out(u)
        a = np.asarray(img).copy()
        alpha = Image.fromarray(a[..., 3])
        spread = round(PRESS_SPREAD * SCALE * (1 - e))
        for _ in range(spread):
            alpha = alpha.filter(ImageFilter.MaxFilter(3))
        if spread:
            alpha = alpha.filter(ImageFilter.GaussianBlur(0.6 * SCALE))
        a[..., 3] = (np.asarray(alpha) * min(1.0, u * 3)).astype(np.uint8)
        a[..., :3] = (a[..., :3] * (0.55 + 0.45 * e)).astype(np.uint8)  # wet ink is darker
        box = img.getbbox()
        centre = ((box[0] + box[2]) / 2 / SCALE, (box[1] + box[3]) / 2 / SCALE)
        grow = 1 + PRESS_GROW * (1 - e)
        return draw(Image.fromarray(a, "RGBA"), about(centre, np.diag([grow, grow, 1.0])))

    def frame(self, t):
        out = Image.new("RGBA", self.size, (255, 255, 255, 255))
        if t < FLY_TIME + SETTLE:
            acc = np.zeros((self.size[1], self.size[0], 4), np.float32)
            for i in range(SUB):
                acc += np.asarray(self.figure_at(t + i / (2 * SUB * FPS)), np.float32)
            fig = Image.fromarray((acc / SUB).astype(np.uint8), "RGBA")
        else:
            fig = self.figure_at(t)
        out.alpha_composite(fig)
        for name, start in WORDS:
            word = self.word_at(name, start, t)
            if word is not None:
                out.alpha_composite(word)
        return out.convert("RGB")


def test():
    logo = Logo()
    w, h = logo.size
    sheet = Image.new("RGB", (w, h * 3), "white")
    for i, beat in enumerate((-1.0, 0.0, 1.0)):
        f = Image.new("RGBA", (w, h), (255, 255, 255, 255))
        f.alpha_composite(logo.figure(beat, (0, 0), 0.0))
        sheet.paste(f.convert("RGB"), (0, i * h))
    sheet.save(HERE / "test_wings.png")


def main():
    logo = Logo()
    n = round(HOLD_UNTIL * FPS)
    frames = [logo.frame(i / FPS) for i in range(n)]
    pal = [f.convert("P", palette=Image.ADAPTIVE, colors=128) for f in frames]
    durations = [round(1000 / FPS)] * n
    durations[-1] = 1500  # sit on the last frame before the viewer loops it
    pal[0].save(HERE / "logo_anim.gif", save_all=True, append_images=pal[1:],
                duration=durations, loop=0, optimize=False, disposal=1)
    frames[round(1.0 * FPS)].save(HERE / "frame_mid.png")
    frames[round(1.7 * FPS)].save(HERE / "frame_press.png")
    frames[-1].save(HERE / "frame_end.png")
    print("frames", n)


if __name__ == "__main__":
    test() if sys.argv[1:] == ["test"] else main()

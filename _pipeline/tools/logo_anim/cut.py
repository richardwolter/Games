"""Cut the flat Modern Daedalus logo into pieces for the animation.

Writes pieces/*.png (RGBA, full canvas size, so every piece shares the source's frame) and
pieces/contact.png. Pieces: wing_back (upper left), wing_front (right), body, and the three
words. The wings are cut along Richard's red outline in wing_marks.png (the logo at another
size with a hand-drawn line round each wing); each wing takes its own paper glow with it.

Run from this folder with base python and the psd-extract venv's site-packages on PYTHONPATH.
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).parent
SRC = HERE / "logo_flat.png"
OUT = HERE / "pieces"

# Darkness thresholds (0 black, 255 white).
LETTER_TH = 235      # letters are separate components here (the S joins the glow above it)
FIGURE_TH = 235      # the cut-out's solid body
GLOW_REACH = 6       # px of soft paper glow kept round the cut-out
GLOW_TONE = 236      # the glow's colour; its alpha comes from how far a pixel is off white
INK = 58             # the words' ink

MARKS = HERE / "wing_marks.png"
# wing_marks.png is the logo scaled by MARK_SCALE and moved; a source pixel (x, y) is at
# ((x - 76) * MARK_SCALE + MARK_AT[0], (y - 67) * MARK_SCALE + MARK_AT[1]) there. Fitted by
# matching the two pictures' greys.
MARK_SCALE = 1.55
MARK_AT = (79.5, 118.5)
MARK_CLOSE = 16      # px; the hand-drawn line has gaps, closed before the loops are filled
WING_GLOW = 8        # px past the line a wing reaches to take its own paper edge
WING_EDGE = 10       # ...but only within this far of the open background
# Where each wing turns, at the shoulder end of its outline.
HINGE_BACK = (312, 150)
HINGE_FRONT = (360, 170)


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    n = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not lab[y, x]:
                n += 1
                q = deque([(y, x)])
                lab[y, x] = n
                pts = []
                while q:
                    cy, cx = q.popleft()
                    pts.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = n
                                q.append((ny, nx))
                out.append(np.array(pts))
    return out


def grow(mask, px):
    im = Image.fromarray((mask * 255).astype(np.uint8))
    for _ in range(px):
        im = im.filter(ImageFilter.MaxFilter(3))
    return np.asarray(im) > 127


def fill_holes(mask):
    """Everything not reachable from the border through the background is inside."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not mask[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return ~seen


def marked_wings(shape):
    """The two red loops in wing_marks.png, filled and brought to source pixels.
    Returns (back, front): the left loop and the right one."""
    a = np.asarray(Image.open(MARKS).convert("RGB")).astype(int)
    red = (a[..., 0] > 170) & (a[..., 1] < 110) & (a[..., 2] < 110)
    im = Image.fromarray((red * 255).astype(np.uint8))
    for _ in range(MARK_CLOSE):
        im = im.filter(ImageFilter.MaxFilter(3))
    im = Image.fromarray((fill_holes(np.asarray(im) > 127) * 255).astype(np.uint8))
    for _ in range(MARK_CLOSE):
        im = im.filter(ImageFilter.MinFilter(3))
    inside = np.asarray(im) > 127
    loops = sorted((p for p in components(inside) if len(p) > 1000), key=lambda p: p[:, 1].mean())
    assert len(loops) == 2, f"expected two wing loops, found {len(loops)}"
    # Sampled smoothly, not nearest: at 1.55 to 1 a nearest pick cuts the edge in steps.
    h, w = shape
    k = MARK_SCALE
    to_marks = (k, 0, MARK_AT[0] - 76 * k, 0, k, MARK_AT[1] - 67 * k)
    out = []
    for p in loops:
        m = np.zeros(inside.shape, np.uint8)
        m[p[:, 0], p[:, 1]] = 255
        soft = Image.fromarray(m, "L").filter(ImageFilter.GaussianBlur(1.5))
        out.append(np.asarray(soft.transform((w, h), Image.AFFINE, to_marks,
                                             resample=Image.BILINEAR)) > 127)
    return out


RIM_PAPER = 2        # px of white paper along a cut
RIM_SHADE = 3        # px of soft shadow outside the paper
PAPER = 247


def rim(piece, others):
    """White paper then a fading shadow, grown out of `piece` into `others` only."""
    h, w = piece.shape
    a = np.zeros((h, w), np.float32)
    col = np.full((h, w, 3), PAPER, np.float32)
    seen = piece.copy()
    ring = piece
    for i in range(RIM_PAPER + RIM_SHADE):
        ring = grow(ring, 1) & others & ~seen
        seen |= ring
        if i < RIM_PAPER:
            a[ring] = 1.0
        else:
            k = (i - RIM_PAPER + 1) / (RIM_SHADE + 1)
            a[ring] = 0.45 * (1 - k)
            col[ring] = 150
    return a, col


def word_of(cx, cy):
    if cy >= 180:
        return "studio"
    if cx < 430 and cy < 105:
        return "modern"
    return "daedalus"


def main():
    OUT.mkdir(exist_ok=True)
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    grey = np.asarray(Image.open(SRC).convert("L")).astype(np.float32)
    h, w = grey.shape

    # Words: every letter-sized component, and every dot nearest to one.
    parts = components(grey < LETTER_TH)
    parts.sort(key=len, reverse=True)
    figure_core = np.zeros((h, w), bool)
    for p in parts[:1]:
        figure_core[p[:, 0], p[:, 1]] = True
    words = {k: np.zeros((h, w), bool) for k in ("modern", "daedalus", "studio")}
    letters = [p for p in parts[1:] if len(p) >= 40]
    centres = [(p[:, 1].mean(), p[:, 0].mean()) for p in letters]
    for p, (cx, cy) in zip(letters, centres):
        words[word_of(cx, cy)][p[:, 0], p[:, 1]] = True
    for p in parts[1:]:
        if len(p) >= 40:
            continue
        cx, cy = p[:, 1].mean(), p[:, 0].mean()
        if figure_core[max(0, int(cy) - 3):int(cy) + 4, max(0, int(cx) - 3):int(cx) + 4].any():
            continue
        i = int(np.argmin([(cx - a) ** 2 + (cy - b) ** 2 for a, b in centres]))
        if (cx - centres[i][0]) ** 2 + (cy - centres[i][1]) ** 2 < 30 ** 2:
            words[word_of(*centres[i])][p[:, 0], p[:, 1]] = True
    text_reach = np.zeros((h, w), bool)
    for k in words:
        words[k] = grow(words[k], 2) & (grey < 254)
        text_reach |= words[k]

    # The cut-out: its solid core with the holes filled, plus a soft glow round it.
    solid = fill_holes(figure_core)
    glow = grow(solid, GLOW_REACH) & ~solid & ~text_reach
    alpha = np.zeros((h, w), np.float32)
    alpha[solid] = 1.0
    alpha[glow] = np.clip((255.0 - grey[glow]) / (255.0 - GLOW_TONE), 0, 1)
    colour = rgb.copy()
    colour[glow] = GLOW_TONE

    def save(name, a, col):
        img = np.dstack([col, (a * 255)[..., None]]).clip(0, 255).astype(np.uint8)
        Image.fromarray(img, "RGBA").save(OUT / f"{name}.png")

    back, front = marked_wings((h, w))
    # The glow just outside a wing's outline is the wing's paper, not the body's: left with
    # the body it would hang in the air where the wing used to be.
    # The hand line runs a little inside the paper's edge in places, so take everything just
    # outside a wing that is near the open background; at the shoulder, deep in the figure,
    # nothing is near the background and the body keeps it all.
    open_bg = grow(~(solid | (alpha > 0)), WING_EDGE)
    back |= grow(back, WING_GLOW) & open_bg
    front |= grow(front, WING_GLOW) & open_bg & ~back
    body = ~(back | front)
    save("wing_back", alpha * back, colour)
    save("wing_front", alpha * front, colour)
    save("body", alpha * body, colour)
    # A paper rim along every cut, for the animation to show only while the wings are off
    # their rest pose (at rest it would draw white lines through the picture).
    for name, piece in (("wing_back", back), ("wing_front", front), ("body", body)):
        mine = solid & piece
        a, col = rim(mine, solid & ~mine)
        save(f"{name}_rim", a, col)

    for k, m in words.items():
        a = np.where(m, np.clip((255.0 - grey) / (255.0 - INK), 0, 1), 0)
        save(k, a, np.full_like(rgb, INK))

    # Contact sheet: each piece on a mid grey so its edges show.
    names = ["wing_back", "wing_front", "body", "modern", "daedalus", "studio"]
    sheet = Image.new("RGB", (w * 2, h * 3), (150, 150, 160))
    for i, n in enumerate(names):
        piece = Image.open(OUT / f"{n}.png")
        tile = Image.new("RGB", (w, h), (150, 150, 160))
        tile.paste(piece, (0, 0), piece)
        ImageDraw.Draw(tile).text((6, 6), n, fill=(255, 255, 0))
        sheet.paste(tile, ((i % 2) * w, (i // 2) * h))
    sheet.save(OUT / "contact.png")
    print("words:", {k: int(v.sum()) for k, v in words.items()}, "figure px:", int(solid.sum()))


if __name__ == "__main__":
    main()

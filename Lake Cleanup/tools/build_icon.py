"""The game's icon: the orange dog sitting in half-cleaned water.

Rules, decided with Richard (2026-10-03, /grill-me, picked off tools/last_icon_sheet.png):
- the orange dog (slot 1, assets/dogs/dog_02), mouth closed, the pack's own first sit
  frame, mirrored to face right. The sit row's bark frame was built first and swapped for
  this one by Richard's call ("lets try with its mouth closed instead");
- a bust: the sitting dog runs off the icon's bottom and right edges, its head up over the
  seam. A cut head filling a 16 px master was the other layout and lost ("B is much
  better"); it is still what the 16 px icon is, because the bust's head alone is 17 wide;
- a rounded square split on a stepped diagonal, murky water bottom-left, clean water
  top-right, flat palette swatches;
- no edge: the corners are cut transparent in whole pixels, through the dog too;
- native pixels only: masters at 16, 24 and 32, every other size one of them in whole steps.

Writes (with --write):
  icon.png                         256 px, project.godot's config/icon
  icon.ico                         16/24/32/48/64/128/256, the Windows export's icon
  <steam>/client_icon.ico          Steamworks client icon (16/32/48/64/256)
  <steam>/community_icon.jpg       184 x 184
Always writes tools/last_icon_sheet.png, every size on a light and a dark taskbar.

Run from the project root:
  PYTHONPATH=<psd-extract venv site-packages> python tools/build_icon.py [--write]
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEAM = os.path.join(ROOT, "..", "Marketing", "My Dirty Little Lake", "steam", "icons")

SHEET = "assets/dogs/dog_02.png"
FRAMES = "assets/dogs/dog_02.json"
ROW = "sit"
FRAME = 0          # the row's first, mouth closed (its last two are the bark)

# The palette's water, read from resources/palette.tres.
MURKY = "water_dirty"
CLEAN = "water_clean"

# 16 px: the head alone, cut out of the frame (a box, and a line across the neck: a pixel
# stays while x + y <= the line), a pixel off the snout's tip so it is as wide as the icon.
HEAD_16 = ((1, 0, 16, 9), 99)
HEAD_16_AT = 3     # three rows of water over it, three under
# The bust: where the frame's top-left corner stands on each master, before the mirror.
BUST = {23: (2, 3), 24: (2, 3), 32: (5, 6)}
# How far round the corners are cut, per master size.
ROUND = {16: 2, 24: 3, 32: 4}
FACE_LEFT = False  # the pack draws the dog facing left; the icon wears it mirrored


def palette():
    out = {}
    with open(os.path.join(ROOT, "resources", "palette.tres"), encoding="utf-8") as f:
        for line in f:
            if "= Color(" not in line:
                continue
            name, rest = line.split("=", 1)
            nums = rest.strip()[len("Color("):-1].split(",")
            out[name.strip()] = tuple(round(float(n) * 255) for n in nums[:3]) + (255,)
    return out


def dog_frame():
    with open(os.path.join(ROOT, FRAMES), encoding="utf-8") as f:
        seq = json.load(f)["sequences"][ROW]
    x, y, w, h = seq[FRAME]["region"]
    sheet = Image.open(os.path.join(ROOT, SHEET)).convert("RGBA")
    return sheet.crop((x, y, x + w, y + h))


def darkest(img):
    best = None
    for px in img.get_flattened_data():
        if px[3] == 0:
            continue
        if best is None or sum(px[:3]) < sum(best[:3]):
            best = px
    return best


def cut_head(frame, box, neck):
    """What the box and the neck line keep, every cut edge inked like the outline."""
    ink = darkest(frame)
    x0, y0, x1, y1 = box

    def kept(x, y):
        return x0 <= x <= x1 and y0 <= y <= y1 and x + y <= neck

    head = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px = frame.getpixel((x, y))
            if not px[3] or not kept(x, y):
                continue
            # A pixel beside drawing the cut took off is on the wound: ring it.
            cut = any(not kept(x + dx, y + dy)
                      and 0 <= x + dx < frame.width and 0 <= y + dy < frame.height
                      and frame.getpixel((x + dx, y + dy))[3]
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            head.putpixel((x - x0, y - y0), ink if cut else px)
    return head.crop(head.getbbox())


def rounded_mask(size, r):
    """Whole-pixel corners: a pixel is in while its middle is inside the round."""
    mask = [[True] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            cx = min(max(x + 0.5, r), size - r)
            cy = min(max(y + 0.5, r), size - r)
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > r * r:
                mask[y][x] = False
    return mask


def backing(size, pal, rounded=True):
    """Clean above the diagonal, murky below it, stepped in whole pixels."""
    img = Image.new("RGBA", (size, size))
    mask = rounded_mask(size, ROUND.get(size, 0) if rounded else 0)
    for y in range(size):
        for x in range(size):
            if not mask[y][x]:
                continue
            img.putpixel((x, y), pal[CLEAN] if x > y else pal[MURKY])
    return img, mask


def facing(art):
    return art if FACE_LEFT else art.transpose(Image.FLIP_LEFT_RIGHT)


def head_icon(pal):
    """16 px: the cut head, drawn over the cut corners so the snout keeps its tip."""
    img, _ = backing(16, pal)
    art = facing(cut_head(dog_frame(), *HEAD_16))
    ox = (16 - art.width) // 2
    for y in range(art.height):
        for x in range(art.width):
            px = art.getpixel((x, y))
            if px[3]:
                img.putpixel((ox + x, HEAD_16_AT + y), px)
    return img


def bust_icon(size, pal, rounded=True):
    """The sitting dog, running off the edges, cut by the corners like the water."""
    img, mask = backing(size, pal, rounded)
    frame = dog_frame()
    art = facing(frame)
    ox, oy = BUST[size]
    if not FACE_LEFT:
        ox = size - ox - frame.width
    for y in range(art.height):
        for x in range(art.width):
            px = art.getpixel((x, y))
            tx, ty = ox + x, oy + y
            if px[3] and 0 <= tx < size and 0 <= ty < size and mask[ty][tx]:
                img.putpixel((tx, ty), px)
    return img


def sizes(pal):
    """16, 24 and 32 are masters; every other size is one of them in whole steps."""
    m = {16: head_icon(pal), 24: bust_icon(24, pal), 32: bust_icon(32, pal)}

    def up(src, n):
        return m[src].resize((n, n), Image.NEAREST)
    return {16: m[16], 24: m[24], 32: m[32], 48: up(24, 48),
            64: up(32, 64), 128: up(32, 128), 256: up(32, 256)}


def sheet(rows, path):
    """Each row twice, on a light and a dark taskbar: a strip of every size at 1x, then 16/24/32 zoomed x8."""
    pad = 12
    zoom = 8
    width = pad + sum(s + pad for s in (16, 24, 32, 48, 64, 128, 256)) \
        + sum(s * zoom + pad for s in (16, 24, 32))
    row_h = max(256, 32 * zoom) + pad * 2
    out = Image.new("RGBA", (width, row_h * len(rows) * 2), (0, 0, 0, 255))
    for r, imgs in enumerate(rows):
        for k, bg in enumerate(((243, 243, 243, 255), (32, 32, 32, 255))):
            top = (r * 2 + k) * row_h
            band = Image.new("RGBA", (width, row_h), bg)
            out.paste(band, (0, top))
            x = pad
            for s in (16, 24, 32, 48, 64, 128, 256):
                out.alpha_composite(imgs[s], (x, top + (row_h - s) // 2))
                x += s + pad
            for s in (16, 24, 32):
                z = imgs[s].resize((s * zoom, s * zoom), Image.NEAREST)
                out.alpha_composite(z, (x, top + (row_h - s * zoom) // 2))
                x += s * zoom + pad
    out.save(path)


def main():
    pal = palette()
    write = "--write" in sys.argv
    final = sizes(pal)
    sheet([final], os.path.join(ROOT, "tools", "last_icon_sheet.png"))
    if not write:
        return
    final[256].save(os.path.join(ROOT, "icon.png"))
    final[256].save(os.path.join(ROOT, "icon.ico"),
                    sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)],
                    append_images=[final[s] for s in (16, 24, 32, 48, 64, 128)])
    os.makedirs(STEAM, exist_ok=True)
    final[256].save(os.path.join(STEAM, "client_icon.ico"),
                    sizes=[(s, s) for s in (16, 32, 48, 64, 256)],
                    append_images=[final[s] for s in (16, 32, 48, 64)])
    # 184 is 23 x 8: the bust on a square 23 px backing, no corners (a JPG has no alpha).
    community = bust_icon(23, pal, rounded=False).resize((184, 184), Image.NEAREST)
    community.convert("RGB").save(os.path.join(STEAM, "community_icon.jpg"), quality=95)


if __name__ == "__main__":
    main()

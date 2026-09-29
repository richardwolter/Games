"""Mockup sheet for sky reflections on clean water and the wash room's clouds.

Offline, psd-extract venv python, from the project root. Writes
tools/last_sky_mockup.png. Not a pipeline: options to judge before building.
"""
import math, random
from PIL import Image, ImageDraw, ImageFont

P = 2          # screen px per art px in the sheet
W, H = 220, 124  # panel size in art px

def c(r, g, b): return (int(r * 255), int(g * 255), int(b * 255))
DEEP = c(.173, .302, .431); MID = c(.255, .42, .573); CLEAN = c(.353, .525, .678)
SHAL = c(.498, .655, .776); LIGHT = c(.769, .859, .91); FOAM = c(.933, .965, .984)
WHITE = (255, 255, 255)
SKY = {"noon": (c(.49, .72, .9), c(.72, .86, .94)),
       "afternoon": (c(.58, .66, .8), c(.93, .8, .62))}

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def hash2(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return (n & 0xffff) / 65535.0

def vnoise(x, y, s):
    xi, yi = math.floor(x), math.floor(y); fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash2(xi, yi, s), hash2(xi + 1, yi, s)
    d, e = hash2(xi, yi + 1, s), hash2(xi + 1, yi + 1, s)
    return a + (b - a) * fx + (d - a) * fy + (a - b - d + e) * fx * fy

def fbm(x, y, s):
    return sum(vnoise(x * 2 ** o, y * 2 ** o, s + o) / 2 ** o for o in range(3)) / 1.75

def water(img):
    for y in range(H):
        for x in range(W):
            band = math.sin(x * 0.05 + y * 0.18 + math.sin(y * 0.07) * 2)
            t = 0.5 + 0.25 * band + 0.25 * fbm(x / 30, y / 30, 3)
            img.putpixel((x, y), DEEP if t < .38 else MID if t < .55 else CLEAN if t < .8 else SHAL)

def cloud_mask(x, y, stretch=3.0, cut=0.55):
    return fbm(x / (26 * stretch), y / 26, 11) > cut

def lake_panel(kind, tint=None):
    img = Image.new("RGB", (W, H)); water(img)
    ink = SHAL if tint is None else lerp(SHAL, tint, .2)
    hi = LIGHT if tint is None else lerp(LIGHT, tint, .4)
    for y in range(H):
        for x in range(W):
            if not cloud_mask(x, y): continue
            deep = fbm(x / 78, y / 26, 11)  # how far inside the cloud
            if kind == "dash":       # A: sparse dashes, faint
                if y % 3 == 0 and hash2(x // 5, y, 7) > .45:
                    img.putpixel((x, y), ink)
            elif kind == "rows":     # B: dense rows, brighter core
                if y % 2 == 0 and hash2(x // 4, y, 7) > .3:
                    img.putpixel((x, y), hi if deep > .64 and hash2(x // 3, y, 9) > .5 else ink)
            elif kind == "solid":    # C: flat stepped patch, dashed rim only
                edge = deep < .58
                if not edge or (y % 2 == 0 and hash2(x // 4, y, 7) > .4):
                    img.putpixel((x, y), ink)
    return img

# ---- wash room sky ----
CL = [WHITE, FOAM, c(.8, .87, .94), c(.62, .72, .86)]  # lit, body, shade, underside

def cumulus(img, cx, base, width, height, rng, tones=4, scallop=True):
    blobs = []
    n = max(4, width // 9)
    for i in range(n):  # base row
        bx = cx - width / 2 + width * (i + .5) / n
        blobs.append((bx, base - 5, 6 + rng.random() * 4))
    y, w = base - 8, width
    while base - y < height:  # tower rises and narrows
        w *= .72; k = max(1, int(w // 10))
        for i in range(k):
            bx = cx - w / 2 + w * (i + .5) / k + rng.uniform(-3, 3)
            blobs.append((bx, y, 7 + rng.random() * 6 * (w / width + .4)))
        y -= 9 + rng.random() * 4
    x0, x1 = int(cx - width), int(cx + width)
    for yy in range(max(0, int(base - height - 20)), int(base) + 1):
        for xx in range(max(0, x0), min(W, x1)):
            best = None
            for bx, by, r in blobs:
                d = math.hypot(xx - bx, (yy - by) * 1.1)
                if d < r and (best is None or d / r < best[0]):
                    best = (d / r, bx, by, r)
            if not best or yy > base: continue
            _, bx, by, r = best
            lit = ((bx - xx) + (by - yy)) / r   # light from top-left
            under = (yy - (base - 10)) / 10
            if tones == 2:
                col = CL[1] if under < .3 else CL[3]
            else:
                if under > .3: col = CL[3]
                elif lit > .55: col = CL[0]
                elif lit > -.3: col = CL[1]
                else: col = CL[2]
            if scallop and best[0] > .88: col = CL[2] if col in (CL[0], CL[1]) else CL[3]
            img.putpixel((xx, yy), col)

def wisp(img, x, y, rng):
    for i in range(rng.randint(3, 7)):
        for j in range(rng.randint(2, 6)):
            px, py = x + i * 2 + j, y + (i % 2)
            if 0 <= px < W and 0 <= py < H: img.putpixel((px, py), FOAM if i % 3 else CL[2])

def cloud_field(cx, base, width, height, s):
    """Density of one cloud: flat base, a noisy column that narrows as it rises."""
    def f(x, y):
        up = (base - y) / height
        if up < 0 or up > 1.25: return 0.0
        half = width * 0.5 * math.sqrt(max(0.0, 1 - (up / 1.1) ** 2)) * (0.8 + 0.4 * fbm(y / 14, s, s + 5))
        side = 1 - abs(x - cx) / max(half, 1)
        n = fbm(x / 18, y / 15, s)
        return side * 1.4 + (n - 0.5) * 1.6 - max(0, up - 0.85) * 3
    return f

def cx_of(x, near):
    return near[0][0] if near else x

def paint_clouds(img, clouds, hz, sky_at, soft):
    """Two masses of tone, like the reference: sunlit white billows, and shade
    taken from the sky itself. No dark band under the cloud: its base is shade
    melting into the low sky."""
    fields = [cloud_field(*c) for c in clouds]
    dens = lambda x, y: max(f(x, y) for f in fields)
    hi_sky = sky_at(0)
    for y in range(hz):
        for x in range(W):
            d = dens(x, y)
            if d < 0.35: continue
            low = sky_at(y)
            shade = lerp(CL[2], CL[3], .45)
            deep = lerp(CL[3], hi_sky, .25)
            # one sun, top-left: the whole mass is lit on its upper-left side,
            # each billow on its own upper-left, and the lower part in shade
            nb = dens(x + 6, y + 6) if dens(x, min(y + 6, hz - 1)) > 0 else d
            mass = (d - nb) * 1.6
            bill = (fbm(x / 12, y / 10, 31) - fbm((x + 3) / 12, (y + 3) / 10, 31)) * 4
            near = [c for c in clouds if abs(x - c[0]) < c[2] * .6]
            base = min(c[1] for c in near) if near else hz
            top = min(c[1] - c[3] for c in near) if near else 0
            height = (base - y) / max(base - top, 1)
            lit = mass * 1.4 + bill + (height - .5) * 1.8 + (cx_of(x, near) - x) / 60
            if d < 0.48:
                col = lerp(low, shade if lit < .2 else CL[1], .75) if soft else shade
            elif lit > -.05: col = CL[0]
            elif lit > -.3: col = CL[1]
            elif lit > -.75: col = shade
            else: col = deep if soft else CL[3]
            img.putpixel((x, y), col)

def sky_panel(style, reflect):
    img = Image.new("RGB", (W, H)); hz = int(H * .56)
    hi, lo = SKY["noon"]
    sky_at = lambda y: lerp(hi, lo, round(min(y, hz) / hz * 4) / 4)
    for y in range(hz):
        for x in range(W): img.putpixel((x, y), sky_at(y))
    for y in range(hz, H):
        t = (y - hz) / (H - hz)
        col = SHAL if t < .12 else CLEAN if t < .4 else MID if t < .8 else SHAL
        for x in range(W): img.putpixel((x, y), col)
    rng = random.Random(5)
    if style == "towers":
        clouds = [(30, hz - 1, 70, 60, 3), (195, hz - 1, 72, 66, 7), (118, hz - 1, 50, 16, 9)]
        paint_clouds(img, clouds, hz, sky_at, True)
        for _ in range(8): wisp(img, rng.randint(60, 160), rng.randint(6, 30), rng)
    elif style == "hard":
        clouds = [(30, hz - 1, 70, 60, 3), (195, hz - 1, 72, 66, 7), (118, hz - 1, 50, 16, 9)]
        paint_clouds(img, clouds, hz, sky_at, False)
    elif style == "drift":
        clouds = [(38, hz - 14, 86, 34, 4), (150, hz - 30, 96, 30, 8), (228, hz - 6, 70, 38, 12)]
        paint_clouds(img, clouds, hz, sky_at, True)
        for _ in range(8): wisp(img, rng.randint(10, 210), rng.randint(4, 24), rng)
    else:
        for cx, cy in ((40, 20), (120, 34), (185, 14)):
            cumulus(img, cx, cy, 30, 8, rng, tones=2, scallop=False)
    if reflect:
        top = img.copy()
        for y in range(hz, H):
            sy = hz - (y - hz) * 2 - 1
            if sy < 0: continue
            for x in range(W):
                src = top.getpixel((x, sy))
                if src in CL and y % 2 == 0 and hash2(x // 4, y, 3) > .35:
                    img.putpixel((x, y), lerp(img.getpixel((x, y)), src, .55))
    return img

panels = [
    ("C  flat patch, dashed rim", lake_panel("solid")),
    ("C  afternoon tint", lake_panel("solid", SKY["afternoon"][1])),
    ("3  bigger, sun top-left", sky_panel("drift", True)),
    ("3  no reflection", sky_panel("drift", False)),
]
cols, gap, lab = 2, 12, 22
sheet = Image.new("RGB", (cols * (W * P + gap) + gap, 2 * (H * P + lab + gap) + gap), (30, 30, 34))
d = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(panels):
    x = gap + (i % cols) * (W * P + gap); y = gap + (i // cols) * (H * P + lab + gap)
    d.text((x, y + 4), name, fill=(235, 235, 235))
    sheet.paste(im.resize((W * P, H * P), Image.NEAREST), (x, y + lab))
sheet.save("tools/last_sky_mockup.png"); print("ok")

# Draws the balcony template (art_ref/balcony_in.png) for img2img, and its exact
# alpha mask (art_ref/balcony_mask.png): the geometry is ours, the ink comes from
# the model, and the mask keeps the gaps between balusters see-through so the city
# shows behind. Coordinates are generation pixels (1664x256).
#
# A carved stone balustrade - coping stone the crows perch on, vase-shaped
# balusters, a plinth, piers every few bays - to match the old European city.
# (The first version was a plank railing and read as flat and cartoonish.)
from PIL import Image, ImageDraw
import math
W, H = 1664, 256
img = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(img)
mask = Image.new("L", (W, H), 0); m = ImageDraw.Draw(mask)
K = (20, 20, 20); STONE = (255, 255, 255); SHADE = "hatch"
import random
random.seed(9)

def hatch(poly, spacing=7, slope=1.0):
    # pen hatching clipped to a polygon: draw lines on a scratch layer, then keep
    # only the part inside the shape
    x0 = min(p[0] for p in poly); x1 = max(p[0] for p in poly)
    y0 = min(p[1] for p in poly); y1 = max(p[1] for p in poly)
    lay = Image.new("L", (W, H), 0); ld = ImageDraw.Draw(lay)
    for k in range(int(x0 - (y1 - y0) * slope) - spacing, int(x1) + spacing, spacing):
        j = random.uniform(-1.5, 1.5)
        ld.line((k + j, y1, k + (y1 - y0) * slope + j, y0), fill=255, width=2)
    clip = Image.new("L", (W, H), 0); ImageDraw.Draw(clip).polygon(poly, fill=255)
    from PIL import ImageChops
    img.paste(K, (0, 0), ImageChops.multiply(lay, clip))

def shape(pts, fill=STONE):
    d.polygon(pts, fill=(255, 255, 255), outline=K)
    if fill == SHADE or isinstance(fill, tuple) and fill != (255, 255, 255):
        hatch(pts, spacing=6 if fill == SHADE else 11)
    d.line(pts + [pts[0]], fill=K, width=3)
    m.polygon(pts, fill=255)

def baluster(cx, top, bot):
    # vase profile: neck, swelling belly, collar, foot - sampled as a polygon
    h = bot - top
    prof = []
    for i in range(41):
        t = i / 40
        r = 7 + 9 * math.sin(min(1.0, t / 0.72) * math.pi) ** 1.3 if t < 0.72 else 8 + 6 * ((t - 0.72) / 0.28)
        if t < 0.08: r = 13
        if t > 0.92: r = 15
        prof.append((t, r))
    left = [(cx - r, top + t * h) for t, r in prof]
    right = [(cx + r, top + t * h) for t, r in reversed(prof)]
    shape(left + right)
    # shadow side of the belly, hatched
    hatch([(cx + r * 0.2, top + t * h) for t, r in prof[4:38]] + [(cx + r, top + t * h) for t, r in reversed(prof[4:38])], spacing=5, slope=0.6)

# plinth (the balcony floor edge) and the base rail the balusters stand on
shape([(0, 206), (W, 206), (W, H - 1), (0, H - 1)], fill=(185, 185, 180))
d.line((0, 222, W, 222), fill=K, width=2)
shape([(0, 184), (W, 184), (W, 206), (0, 206)])
for x in range(40, W, 56):
    baluster(x, 66, 184)
# coping stone: the ledge the crows stand on, with an overhanging lip
shape([(0, 30), (W, 30), (W, 52), (0, 52)])
shape([(0, 52), (W, 52), (W, 66), (0, 66)], fill=SHADE)
d.line((0, 40, W, 40), fill=K, width=2)
# piers every few bays
for x in (0, 470, 1000, W - 60):
    shape([(x, 20), (x + 60, 20), (x + 60, H - 1), (x, H - 1)], fill=(195, 195, 190))
    shape([(x - 8, 8), (x + 68, 8), (x + 68, 30), (x - 8, 30)])
    hatch([(x + 40, 32), (x + 58, 32), (x + 58, H - 2), (x + 40, H - 2)], spacing=5)
img.save("art_ref/balcony_in.png"); mask.save("art_ref/balcony_mask.png")

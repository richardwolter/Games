# Finishes the scene art from the approved previews:
#  - balcony: stone balustrade, `balcony` d0.5 seed 7601, ink kept as the model drew
#             it (slight contrast lift only); alpha from the template mask so the
#             city shows between the balusters
#  - sun:     `sun` seed 8201 - the rayed sun cut out of its decorative ring
#  - moon:    `moon` seed 8303, cratered disc
# The city is built separately by tools/skyline_art.py.
from PIL import Image, ImageFilter, ImageDraw, ImageOps

raw = Image.open("art/_preview/balcony_2_d05.png").convert("L").resize((1664, 256), Image.LANCZOS)
ink = raw.point(lambda v: 0 if v < 40 else 255 if v > 235 else int((v - 40) / 195 * 255))
mask = Image.open("art_ref/balcony_mask.png").convert("L").filter(ImageFilter.MaxFilter(3))
Image.merge("RGBA", (ink, ink, ink, mask)).resize((1152, 178), Image.LANCZOS).save("art/scene/balcony.png")

def disc_cut(src, frac, out, size, core=None):
    import numpy as np, cv2
    im = Image.open(src).convert("RGBA")
    flat = Image.new("RGBA", im.size, "white"); flat.alpha_composite(im)
    w, h = im.size; r = min(w, h) * frac / 2; cx, cy = w / 2, h / 2
    m = Image.new("L", im.size, 0); ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    # filled silhouette: paper enclosed by the drawing stays opaque, so the sky
    # never shows through the disc
    solid = (np.array(im.split()[3]) > 40).astype(np.uint8)
    solid = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    ff = solid.copy() * 255; pad = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(ff, pad, (0, 0), 128)
    filled = Image.fromarray(np.where(ff == 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1))
    if core is not None:
        # rays stay as drawn (gaps see-through); only the central disc is solid
        filled = im.split()[3].copy()
        ImageDraw.Draw(filled).ellipse((cx - r * core, cy - r * core, cx + r * core, cy + r * core), fill=255)
    from PIL import ImageChops
    flat.putalpha(ImageChops.multiply(filled, m.filter(ImageFilter.GaussianBlur(2))))
    b = flat.getbbox(); flat.crop(b).resize((size, size), Image.LANCZOS).save(out)

disc_cut("art/_preview/sun_2_d1.png", 0.66, "art/scene/sun.png", 256, core=0.62)
disc_cut("art/_preview/moon_4_d1.png", 1.0, "art/scene/moon.png", 256)

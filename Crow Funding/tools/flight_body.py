# Builds the flight-pose collage from the approved crow: body (wing hole already
# inked, legs cut) rotated towards horizontal, head re-attached level so the beak
# still points forward. Output: art_ref/crow_fly_in.png for a low-denoise img2img.
from PIL import Image, ImageDraw, ImageFilter
body = Image.open("art/crows/crow_body.png").convert("RGBA")   # 629x944, wing hole inked
W, H = body.size
flat = Image.new("RGBA", (W, H), "white"); flat.alpha_composite(body)
flat.putalpha(body.split()[3])
# fill interior alpha holes (white hatching is alpha 0 in the source)
m = body.split()[3].point(lambda v: 255 if v > 40 else 0).convert("RGB")
for p in [(0, 0), (W-1, 0), (0, H-1), (W-1, H-1)]:
    ImageDraw.floodfill(m, p, (255, 0, 0))
px = m.load(); a = Image.new("L", (W, H), 255); pa = a.load()
for y in range(H):
    for x in range(W):
        if px[x, y] == (255, 0, 0): pa[x, y] = 0
# cut legs: everything below the belly line, except the tail wedge on the left
ImageDraw.Draw(a).polygon([(170, 700), (629, 640), (629, 944), (150, 944), (140, 860), (200, 760)], fill=0)
flat.putalpha(a)
# head: above the neck line
hm = Image.new("L", (W, H), 0); ImageDraw.Draw(hm).polygon([(300, 0), (629, 0), (629, 160), (520, 205), (400, 215), (310, 190)], fill=255)
hm = hm.filter(ImageFilter.GaussianBlur(3))
head = Image.new("RGBA", (W, H), (0, 0, 0, 0)); head.paste(flat, (0, 0), Image.composite(a, Image.new("L", (W, H), 0), hm))
torso = flat.copy()
ta = torso.split()[3]; ta.paste(0, (0, 0), hm.point(lambda v: 255 if v > 128 else 0)); torso.putalpha(ta)
# rotate torso so the back runs near-horizontal (tail back-left, chest forward)
ANG = -52   # PIL: positive is counter-clockwise
pivot = (420, 220)   # neck base
big = Image.new("RGBA", (W + 800, H + 400), (0, 0, 0, 0)); big.alpha_composite(torso, (400, 0))
big_r = big.rotate(ANG, resample=Image.BICUBIC, center=(pivot[0] + 400, pivot[1]), fillcolor=(0, 0, 0, 0))
bb = big_r.getbbox(); big_r = big_r.crop(bb)
nx, ny = pivot[0] + 400 - bb[0], pivot[1] - bb[1]    # neck in cropped coords
# place: neck at (700, 260) of the output canvas
out = Image.new("RGBA", (1152, 640), (0, 0, 0, 0))
out.alpha_composite(big_r, (700 - nx, 260 - ny))
# round the belly where the legs were cut: an ink ellipse under the rotated torso
bd = ImageDraw.Draw(out)
bd.ellipse((330, 250, 760, 470), fill=(10, 10, 12, 255))
out.alpha_composite(big_r, (700 - nx, 260 - ny))
out.alpha_composite(head, (700 - 440, 260 - 205))
# chest: join the head's throat down into the belly
bd = ImageDraw.Draw(out)
bd.polygon([(610, 230), (745, 240), (765, 330), (720, 420), (640, 330)], fill=(10, 10, 12, 255))
# trim the square leg-cut corner into a rounded underside
oa = out.split()[3]; od = ImageDraw.Draw(oa)
od.polygon([(140, 372), (250, 440), (340, 480), (340, 640), (140, 640)], fill=0)
od.ellipse((250, 330, 700, 490), fill=255)
out.putalpha(oa)
bd.ellipse((252, 332, 698, 488), outline=(10, 10, 12, 255), width=6)
import random
random.seed(11)
for i in range(70):
    # feather strokes over the flat ink, running tail-ward along the body
    x = random.randint(260, 720); y = random.randint(240, 460)
    L = random.randint(25, 70)
    bd.line([(x, y), (x - L, y + random.randint(-4, 8))], fill=(235, 235, 235, 255), width=random.choice([1, 1, 2]))
out.save("art_ref/crow_fly_in.png")
v = Image.new("RGBA", out.size, (200, 220, 255, 255)); v.alpha_composite(out); v.convert("RGB").save("tools/_fly_in.png")

# Draws the modern balcony template (art_ref/balcony_modern_in.png) for img2img,
# and its alpha mask (art_ref/balcony_modern_mask.png). Level 2 downtown: frameless
# glass panels under a round steel handrail, held by slim posts and clamps.
#
# The mask keeps steel fully opaque and the glass mostly see-through (a faint
# paper tint), with its diagonal reflection streaks and edge lines inked, so the
# city reads through the glass. Coordinates are generation pixels (1664x256),
# which balcony.gd shows at 1152x178 from y 476: the rail top at y ~22 here lands
# at ~491 on screen, under the crows' feet.
from PIL import Image, ImageDraw
import random
W, H = 1664, 256
random.seed(11)
img = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(img)
mask = Image.new("L", (W, H), 0); m = ImageDraw.Draw(mask)
K = (20, 20, 20)
GLASS = 46  # alpha of plain glass

RAIL_Y0, RAIL_Y1 = 22, 40
GLASS_Y0, GLASS_Y1 = 50, 250
POST_W = 12
BAY = 208

# glass panels between posts
for x0 in range(0, W, BAY):
    gx0, gx1 = x0 + POST_W // 2 + 6, x0 + BAY - POST_W // 2 - 6
    m.rectangle((gx0, GLASS_Y0, gx1, GLASS_Y1), fill=GLASS)
    d.rectangle((gx0, GLASS_Y0, gx1, GLASS_Y1), outline=K, width=2)
    m.rectangle((gx0, GLASS_Y0, gx1, GLASS_Y1), outline=255, width=2)
    # a few diagonal reflection streaks, in a band near one corner
    base = random.randint(gx0 + 10, gx1 - 90)
    for k in range(random.randint(2, 4)):
        sx = base + k * random.randint(9, 16)
        ln = random.randint(40, 110)
        pts = (sx, GLASS_Y0 + 8 + k * 4, sx + ln * 0.55, GLASS_Y0 + 8 + k * 4 + ln)
        d.line(pts, fill=K, width=2)
        m.line(pts, fill=200, width=2)
    # clamps holding the glass to the posts
    for cy in (GLASS_Y0 + 20, GLASS_Y1 - 26):
        for cx in (gx0 - 4, gx1 - 6):
            d.rectangle((cx, cy, cx + 10, cy + 16), fill=(255, 255, 255), outline=K, width=2)
            m.rectangle((cx, cy, cx + 10, cy + 16), fill=255)

# posts (brushed steel: vertical hatching on the shaded side)
for x0 in range(0, W + BAY, BAY):
    px0, px1 = x0 - POST_W // 2, x0 + POST_W // 2
    d.rectangle((px0, RAIL_Y1, px1, H), fill=(255, 255, 255), outline=K, width=2)
    for hx in range(px0 + POST_W // 2, px1, 3):
        d.line((hx, RAIL_Y1, hx, H), fill=K, width=1)
    m.rectangle((px0, RAIL_Y1, px1, H), fill=255)

# round handrail: outline, a highlight kept white, and shading hatched underneath
d.rectangle((0, RAIL_Y0, W, RAIL_Y1), fill=(255, 255, 255), outline=K, width=3)
for hx in range(-20, W, 5):
    d.line((hx, RAIL_Y1 - 1, hx + 6, RAIL_Y0 + 11), fill=K, width=1)
d.line((0, RAIL_Y0 + 5, W, RAIL_Y0 + 5), fill=K, width=1)
m.rectangle((0, RAIL_Y0, W, RAIL_Y1), fill=255)
# base channel along the floor edge
d.rectangle((0, GLASS_Y1, W, H), fill=(255, 255, 255), outline=K, width=2)
for hx in range(-10, W, 6):
    d.line((hx, H, hx + 6, GLASS_Y1), fill=K, width=1)
m.rectangle((0, GLASS_Y1, W, H), fill=255)

img.save("art_ref/balcony_modern_in.png")
mask.save("art_ref/balcony_modern_mask.png")
print("wrote art_ref/balcony_modern_in.png, balcony_modern_mask.png")

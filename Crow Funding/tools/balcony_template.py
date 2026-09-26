# Draws the balcony railing template (art_ref/balcony_in.png) for img2img, and its
# exact alpha mask (art_ref/balcony_mask.png): the geometry is ours, the ink comes
# from the model, and the mask keeps the gaps between balusters see-through so the
# city shows behind. Coordinates are generation pixels (1664x256).
from PIL import Image, ImageDraw
import random
W, H = 1664, 256
random.seed(5)
img = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(img)
mask = Image.new("L", (W, H), 0); m = ImageDraw.Draw(mask)
K = (15, 15, 15); FILL = (175, 175, 175); DARK = (90, 90, 90)
def box(x0, y0, x1, y1, fill=FILL):
    d.rectangle((x0, y0, x1, y1), fill=fill, outline=K, width=4)
    m.rectangle((x0, y0, x1, y1), fill=255)
# deck: planks in perspective under the railing
d.rectangle((0, 196, W, H), fill=(200, 200, 200)); m.rectangle((0, 196, W, H), fill=255)
for i in range(1, 4):
    y = 196 + int((H - 196) * (i / 4) ** 1.6); d.line((0, y, W, y), fill=K, width=3)
vp = W / 2
for i in range(-14, 15):
    xb = vp + i * 140; d.line((xb, H, vp + (xb - vp) * 0.55, 196), fill=K, width=3)
# balusters
for x in range(30, W, 72):
    box(x, 58, x + 24, 184)
    d.line((x + 17, 62, x + 17, 180), fill=DARK, width=3)       # shadow side
# bottom rail, top rail (the perch), posts
box(0, 170, W, 196)
box(0, 22, W, 58)
d.line((0, 50, W, 50), fill=DARK, width=4)
for x in (0, 416, 832, 1248, W - 44):
    box(x, 8, x + 44, H - 1, fill=(150, 150, 150))
    box(x - 6, 2, x + 50, 22, fill=(160, 160, 160))
# grain hints for the model to turn into hatching
for i in range(160):
    y = random.randint(26, 54); x = random.randint(0, W - 60)
    d.line((x, y, x + random.randint(30, 90), y + random.randint(-1, 1)), fill=DARK, width=1)
img.save("art_ref/balcony_in.png"); mask.save("art_ref/balcony_mask.png")

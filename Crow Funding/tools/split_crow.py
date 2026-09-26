# Cuts art/crows/crow.png into a body layer and a wing layer for crow.gd's rig.
# The wing polygon and shoulder pivot are authored here in source pixels; the
# hole left in the body is filled with solid ink (a crow is black, so any edge
# exposed while the wing flaps reads as shadow, not as a hole).
from PIL import Image, ImageDraw, ImageFilter
import json

SRC = "art/crows/crow.png"
WING = [(365,200),(415,200),(450,235),(460,300),(445,380),(420,460),(385,540),
        (340,610),(285,650),(215,655),(165,625),(150,575),(170,505),(215,420),
        (265,340),(315,260)]
PIVOT = (400, 225)   # shoulder: where the wing hinges

im = Image.open(SRC).convert("RGBA"); W, H = im.size
mask = Image.new("L", (W, H), 0); ImageDraw.Draw(mask).polygon(WING, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(1.5))

wing = Image.new("RGBA", (W, H), (0, 0, 0, 0))
wing.paste(im, (0, 0), mask)
# inside the wing, white hatching is alpha 0 in the source; make it opaque white
# so the flapping wing never shows the body through its gaps
wa = wing.split()[3]; solid = Image.new("RGBA", (W, H), (255, 255, 255, 255))
solid.alpha_composite(wing); solid.putalpha(mask); wing = solid

body = im.copy()
ink = Image.new("RGBA", (W, H), (8, 8, 10, 255))
hole = mask.point(lambda v: 255 if v > 0 else 0)
body.paste(ink, (0, 0), hole)

bx = wing.getbbox()
wing_c = wing.crop(bx)
body_bx = body.getbbox(); body_c = body.crop(body_bx)
body_c.save("art/crows/crow_body.png"); wing_c.save("art/crows/crow_wing.png")
parts = {
    "_comment": "Written by tools/split_crow.py. Offsets are the part's top-left in body-local pixels; pivot is in the wing's own pixels.",
    "source_size": [W, H],
    "body": {"file": "crow_body.png", "offset": [body_bx[0], body_bx[1]], "size": list(body_c.size)},
    "wing": {"file": "crow_wing.png", "offset": [bx[0]-body_bx[0], bx[1]-body_bx[1]], "size": list(wing_c.size),
             "pivot": [PIVOT[0]-bx[0], PIVOT[1]-bx[1]]},
}
json.dump(parts, open("art/crows/crow_parts.json", "w", newline="\n"), indent=4)
# debug: body alone and the wing lifted 40 px, on a light background
dbg = Image.new("RGBA", (W*2+20, H), (200, 220, 255, 255))
dbg.alpha_composite(body, (0, 0))
dbg.alpha_composite(body, (W+20, 0)); dbg.alpha_composite(wing, (W+20, -40))
d = ImageDraw.Draw(dbg); d.ellipse((PIVOT[0]+W+20-6, PIVOT[1]-46, PIVOT[0]+W+26, PIVOT[1]-34), outline="red", width=3)
dbg.convert("RGB").save("tools/_split_debug.png")
print(parts)

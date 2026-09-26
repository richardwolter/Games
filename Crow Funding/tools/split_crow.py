# Cuts art/crows/crow.png into a body layer and a wing layer for crow.gd's rig.
# The wing polygon and shoulder pivot are authored here in source pixels; the
# hole left in the body is filled with solid ink (a crow is black, so any edge
# exposed while the wing flaps reads as shadow, not as a hole).
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import json

SRC = "art/crows/crow.png"
WING = [(365,200),(415,200),(450,235),(460,300),(445,380),(420,460),(385,540),
        (340,610),(285,650),(215,655),(165,625),(150,575),(170,505),(215,420),
        (265,340),(315,260)]
PIVOT = (400, 225)   # shoulder: where the wing hinges
# Head: turns and bobs on the neck; the scarf covers the seam.
HEAD = [(300, 0), (629, 0), (629, 150), (540, 190), (470, 205), (400, 205), (330, 185)]
NECK = (440, 195)
# Tail: flicks about the rump.
TAIL = [(95, 585), (180, 605), (222, 700), (205, 772), (70, 895), (0, 900), (0, 845)]
RUMP = (165, 640)

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

# filled silhouette: exterior flood-filled from the corners, everything else is bird
_m = im.split()[3].point(lambda v: 255 if v > 40 else 0).convert("RGB")
for _p in [(0, 0), (W-1, 0), (0, H-1), (W-1, H-1)]:
    if _m.getpixel(_p) == (0, 0, 0): ImageDraw.floodfill(_m, _p, (255, 0, 0))
SIL = Image.eval(_m.split()[1], lambda v: 0)
_px = _m.load(); _ps = SIL.load()
for _y in range(H):
    for _x in range(W):
        if _px[_x, _y] != (255, 0, 0): _ps[_x, _y] = 255

def cut(poly, grow=1.2):
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon(poly, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(grow))
    part = Image.new("RGBA", (W, H), (255, 255, 255, 255)); part.alpha_composite(im)
    a = Image.new("L", (W, H), 0); a.paste(im.split()[3], (0, 0), m)
    # interior white hatching is alpha 0 in the source: keep the part opaque inside
    inner = ImageChops.multiply(m.filter(ImageFilter.MinFilter(9)), SIL)
    a.paste(255, (0, 0), inner)
    part.putalpha(Image.eval(a, lambda v: v))
    return part, m
head, head_m = cut(HEAD)
tail, tail_m = cut(TAIL)
# the body keeps ink under both, so a small turn or flick never opens a hole
hb = ImageChops.multiply(head_m.filter(ImageFilter.MinFilter(15)).point(lambda v: 255 if v > 128 else 0), SIL.filter(ImageFilter.MinFilter(9)))
tb = ImageChops.multiply(tail_m.filter(ImageFilter.MinFilter(15)).point(lambda v: 255 if v > 128 else 0), SIL.filter(ImageFilter.MinFilter(9)))
# head: clear the drawn head (beak included) so a turned head never shows a second
# beak, then back the skull only (not the beak) with ink
ba = body.split()[3]; ba.paste(0, (0, 0), head_m.point(lambda v: 255 if v > 0 else 0)); body.putalpha(ba)
hb.paste(0, (500, 0, W, H))
body.paste(ink, (0, 0), hb); body.paste(ink, (0, 0), tb)
for name, part, pv in (("crow_head", head, NECK), ("crow_tail", tail, RUMP)):
    b = part.getbbox(); part.crop(b).save(f"art/crows/{name}.png")
    globals()[name + "_info"] = {"file": name + ".png", "offset": [b[0], b[1]], "size": [b[2]-b[0], b[3]-b[1]], "pivot": [pv[0]-b[0], pv[1]-b[1]]}

bx = wing.getbbox()
wing_c = wing.crop(bx)
body_bx = body.getbbox(); body_c = body.crop(body_bx)
body_c.save("art/crows/crow_body.png"); wing_c.save("art/crows/crow_wing.png")
old = json.load(open("art/crows/crow_parts.json"))
parts = {
    "_comment": "Written by tools/split_crow.py. Offsets are the part's top-left in body-local pixels; pivot is in the wing's own pixels.",
    "source_size": [W, H],
    "body": {"file": "crow_body.png", "offset": [body_bx[0], body_bx[1]], "size": list(body_c.size)},
    "wing": {"file": "crow_wing.png", "offset": [bx[0]-body_bx[0], bx[1]-body_bx[1]], "size": list(wing_c.size),
             "pivot": [PIVOT[0]-bx[0], PIVOT[1]-bx[1]]},
    "head": crow_head_info,
    "tail": crow_tail_info,
}
for keep in ("scarf", "flight"):
    if keep in old: parts[keep] = old[keep]
json.dump(parts, open("art/crows/crow_parts.json", "w", newline="\n"), indent=4)
# debug: body alone and the wing lifted 40 px, on a light background
dbg = Image.new("RGBA", (W*2+20, H), (200, 220, 255, 255))
dbg.alpha_composite(body, (0, 0))
dbg.alpha_composite(body, (W+20, 0)); dbg.alpha_composite(wing, (W+20, -40))
d = ImageDraw.Draw(dbg); d.ellipse((PIVOT[0]+W+20-6, PIVOT[1]-46, PIVOT[0]+W+26, PIVOT[1]-34), outline="red", width=3)
dbg.convert("RGB").save("tools/_split_debug.png")
print(parts)

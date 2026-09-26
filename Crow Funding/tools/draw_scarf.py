# Draws the crow's scarf as its own layer: white fill (crow.gd tints it with
# scarf_color via modulate, so white takes the full colour), black ink outline and
# a few fold lines so it matches the pen drawing. Coordinates are source pixels of
# art/crows/crow.png; the offset is written into crow_parts.json.
from PIL import Image, ImageDraw
import json
W, H = 629, 944
S = 2  # supersample for smooth ink
img = Image.new("RGBA", (W*S, H*S), (0,0,0,0)); d = ImageDraw.Draw(img)
P = lambda pts: [(x*S, y*S) for x, y in pts]
K = (10,10,12,255); Wt = (255,255,255,255)
band = [(372,168),(420,182),(470,186),(522,172),(530,200),(478,218),(420,216),(366,198)]
tail = [(452,205),(492,210),(500,262),(512,318),(488,322),(470,300),(458,258)]
knot = [(446,192),(490,190),(498,222),(452,226)]
for shape in (band, tail, knot):
    d.polygon(P(shape), fill=Wt)
    d.line(P(shape + [shape[0]]), fill=K, width=5*S, joint="curve")
# fold lines
for a, b in [((392,186),(440,198)),((486,200),(515,188)),((470,232),(482,300)),((486,236),(497,305)),((460,200),(485,215))]:
    d.line(P([a, b]), fill=K, width=2*S)
img = img.resize((W, H), Image.LANCZOS)
bx = img.getbbox(); img.crop(bx).save("art/crows/crow_scarf.png")
parts = json.load(open("art/crows/crow_parts.json"))
parts["scarf"] = {"file": "crow_scarf.png", "offset": [bx[0], bx[1]], "size": [bx[2]-bx[0], bx[3]-bx[1]], "tint": "scarf_color"}
json.dump(parts, open("art/crows/crow_parts.json", "w", newline="\n"), indent=4)
# preview: crow + scarf tinted orange, full size and in-game size
crow = Image.open("art/crows/crow.png").convert("RGBA")
sc = img.copy(); r,g,b,a = sc.split()
tint = Image.merge("RGBA", (r.point(lambda v: v*0.95), g.point(lambda v: v*0.72), b.point(lambda v: v*0.25), a))
out = Image.new("RGBA", (W+120, H), (240,236,225,255)); out.alpha_composite(crow); out.alpha_composite(tint)
small = out.crop((0,0,W,H)).resize((47,70), Image.LANCZOS); out.alpha_composite(small, (W+30, 40))
out.convert("RGB").save("tools/_scarf_view.png")

# Cuts the ink scarf out of the approved crow_scarf img2img result (d0.4 seed 7103)
# using the placeholder scarf's own alpha, grown a little so the new ink outline
# survives. Writes art/crows/crow_scarf.png in place of the placeholder; the
# offset in crow_parts.json stays the same apart from the grow margin.
from PIL import Image, ImageFilter, ImageOps
import json
SRC = "art/_preview/crow_scarf_4_d04.png"
GROW = 6
parts = json.load(open("art/crows/crow_parts.json"))
ox, oy = parts["scarf"]["offset"]
crow = Image.open("art/crows/crow.png").convert("RGBA"); W, H = crow.size
res = Image.open(SRC).convert("RGBA")
if res.size != (W, H):
    # the generator trims to the silhouette; the silhouette matches the source, so
    # a straight resize puts every pixel back where it was
    res = res.resize((W, H), Image.LANCZOS)
flat = Image.new("RGBA", (W, H), "white"); flat.alpha_composite(res)
# placeholder alpha in full-image space, grown
ph = Image.open("art/crows/crow_scarf_placeholder.png").convert("RGBA")
m = Image.new("L", (W, H), 0); m.paste(ph.split()[3], (ox, oy))
m = m.point(lambda v: 255 if v > 20 else 0).filter(ImageFilter.MaxFilter(GROW * 2 + 1)).filter(ImageFilter.GaussianBlur(1))
out = Image.new("RGBA", (W, H), (0, 0, 0, 0)); out.paste(flat, (0, 0), m)
bx = out.getbbox(); out.crop(bx).save("art/crows/crow_scarf.png")
parts["scarf"].update({"offset": [bx[0], bx[1]], "size": [bx[2]-bx[0], bx[3]-bx[1]], "source": SRC})
json.dump(parts, open("art/crows/crow_parts.json", "w", newline="\n"), indent=4)
print(parts["scarf"])

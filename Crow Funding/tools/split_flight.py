# Flight rig parts.
#  - flight body: crow_fly_body d0.5 seed 7300 (tools/flight_body.py + img2img)
#  - spread wing: cut from crow_fly seed 6101, split at the wrist into an arm piece
#    (coverts + secondaries) and a hand piece (the fingered primaries).
# The wing lies along +x (shoulder left, tip right). crow.gd turns it upright and
# foreshortens it along that axis to fake the stroke seen from the side.
# Pivots are written in each piece's own pixels.
from PIL import Image, ImageDraw, ImageFilter
import json

def filled(path):
    im = Image.open(path).convert("RGBA"); W, H = im.size
    flat = Image.new("RGBA", (W, H), "white"); flat.alpha_composite(im)
    m = im.split()[3].point(lambda v: 255 if v > 40 else 0).convert("RGB")
    for p in [(0, 0), (W-1, 0), (0, H-1), (W-1, H-1)]:
        if m.getpixel(p) == (0, 0, 0): ImageDraw.floodfill(m, p, (255, 0, 0))
    px = m.load(); a = Image.new("L", (W, H), 255); pa = a.load()
    for y in range(H):
        for x in range(W):
            if px[x, y] == (255, 0, 0): pa[x, y] = 0
    flat.putalpha(a); return flat

body = filled("art/_preview/crow_fly_body_1_d05.png")
bb = body.getbbox(); body = body.crop(bb); body.save("art/crows/fly_body.png")

src = filled("art/_preview/crow_fly_2_d1.png")
WING = [(285, 140), (400, 115), (600, 103), (800, 118), (989, 205), (989, 275), (960, 335),
        (800, 352), (700, 368), (600, 358), (500, 352), (400, 352), (330, 322), (285, 260)]
WRIST_X = 620
SHOULDER = (300, 190); WRIST = (WRIST_X, 215)
def piece(poly, name):
    m = Image.new("L", src.size, 0); ImageDraw.Draw(m).polygon(poly, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(1.2))
    a = Image.new("L", src.size, 0); a.paste(src.split()[3], (0, 0), m)
    p = src.copy(); p.putalpha(a); b = p.getbbox(); p.crop(b).save(f"art/crows/{name}.png"); return b
def clip(poly, x0, x1):
    return [(min(max(x, x0), x1), y) for x, y in poly]
arm_b = piece(clip(WING, 0, WRIST_X + 25), "wing_arm")
hand_b = piece(clip(WING, WRIST_X - 15, 2000), "wing_hand")

# where the wing root sits on the flight body (shoulder), in fly_body pixels
BODY_SHOULDER = (520, 125)   # top of the back behind the neck, read off the trimmed body
parts = json.load(open("art/crows/crow_parts.json"))
parts["flight"] = {
    "body": {"file": "fly_body.png", "size": list(body.size), "shoulder": list(BODY_SHOULDER)},
    "arm": {"file": "wing_arm.png", "size": [arm_b[2]-arm_b[0], arm_b[3]-arm_b[1]],
            "pivot": [SHOULDER[0]-arm_b[0], SHOULDER[1]-arm_b[1]], "wrist": [WRIST[0]-arm_b[0], WRIST[1]-arm_b[1]]},
    "hand": {"file": "wing_hand.png", "size": [hand_b[2]-hand_b[0], hand_b[3]-hand_b[1]],
             "pivot": [WRIST[0]-hand_b[0], WRIST[1]-hand_b[1]]},
}
json.dump(parts, open("art/crows/crow_parts.json", "w", newline="\n"), indent=4)
print(json.dumps(parts["flight"]))

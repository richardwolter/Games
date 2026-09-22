"""Static mockup of the shop tour, composited on tools/last_menu_upgrades.png (1080p).
Judged by eye before anything is built. Writes tools/last_shop_tour_mockup.png."""
from PIL import Image, ImageDraw, ImageFont
SHEET = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
BG = "tools/last_menu_upgrades.png"
T, COLS, S = 16, 34, 2
sheet = Image.open(SHEET).convert("RGBA")
def tile(n):
    r, c = divmod(n, COLS)
    return sheet.crop((c*T, r*T, c*T+T, r*T+T)).resize((T*S, T*S), Image.NEAREST)
ARROW, MOUSE, PAD_A = 604, 77, 4
FONT = ImageFont.truetype("assets/Bungee-Regular.ttf", 15)
SMALL = ImageFont.truetype("assets/Bungee-Regular.ttf", 12)
PAPER, EDGE, INK, SOFT, OUTER = (234,219,184), (199,179,138), (50,36,28), (94,77,60), (60,42,30)
TOURS = [
 ((62, 80, 482, 720), "Your net can be upgraded to catch more objects, higher tiers and for faster cast and reel.", "right"),
 ((1490, 262, 1806, 462), "You can also increase your net luck and double cast chance.", "left"),
 ((522, 80, 940, 720), "Boats are essential for money making, make sure to keep them upgraded.", "right"),
 ((980, 80, 1398, 720), "Dogs will help bring objects to the recycle box.", "left"),
 ((1490, 466, 1806, 664), "You can make more money by giving a bonus to recycling, and catching pigeons earn more.", "left"),
 ((537, 758, 1385, 975), "You can check the materials average price here, and which recycle has a bonus.", "above"),
]
def wrap(d, text, font, wide):
    lines, line = [], ""
    for w in text.split():
        t = w if not line else line + " " + w
        if d.textlength(t, font=font) > wide and line: lines.append(line); line = w
        else: line = t
    return lines + [line]
def frame(i, pad=False):
    box, text, side = TOURS[i]
    img = Image.open(BG).convert("RGBA")
    dim = Image.new("RGBA", img.size, (0, 0, 0, 150))
    hole = Image.new("L", img.size, 255); ImageDraw.Draw(hole).rectangle(box, fill=0)
    img.paste(dim, (0, 0), Image.composite(Image.new("L", img.size, 150), Image.new("L", img.size, 0), hole).point(lambda v: 255 if v else 0))
    # redo properly: alpha dim outside the hole
    base = Image.open(BG).convert("RGBA")
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(shade)
    sd.rectangle((0, 0) + img.size, fill=(0, 0, 0, 150)); sd.rectangle(box, fill=(0, 0, 0, 0))
    base.alpha_composite(shade); img = base
    d = ImageDraw.Draw(img)
    d.rectangle(box, outline=(255, 255, 255, 230), width=3)
    wide = 300
    lines = wrap(d, text, FONT, wide - 28)
    tall = 22 * len(lines) + 70
    if side == "right": x, y = box[2] + 30, box[1] + 120
    elif side == "left": x, y = box[0] - 30 - wide, box[1] + 20
    else: x, y = (box[0] + box[2]) // 2 - wide // 2, box[1] - tall - 40
    d.rectangle((x-5, y-5, x+wide+5, y+tall+5), fill=OUTER)
    d.rectangle((x, y, x+wide, y+tall), fill=PAPER, outline=EDGE, width=3)
    d.text((x+wide-14, y+10), f"{i+1}/6", fill=SOFT, font=SMALL, anchor="ra")
    for k, s in enumerate(lines):
        d.text((x+wide/2, y+28+k*22), s, fill=INK, font=FONT, anchor="ma")
    foot = y + tall - 26
    d.text((x+14, foot), "Skip", fill=SOFT, font=SMALL, anchor="lm")
    icon = tile(PAD_A if pad else MOUSE)
    d.text((x+wide-14-icon.width-6, foot), "Continue", fill=INK, font=SMALL, anchor="rm")
    img.alpha_composite(icon, (x+wide-14-icon.width, foot-icon.height//2))
    a = tile(ARROW).transpose(Image.FLIP_TOP_BOTTOM)
    img.alpha_composite(a, ((box[0]+box[2])//2 - a.width//2, box[1] - a.height - 4))
    return img
shots = [frame(i) for i in range(6)] + [frame(0, pad=True)]
names = [f"{i+1}" for i in range(6)] + ["1 (pad)"]
w, h = 960, 540
out = Image.new("RGBA", (w*2+30, (h+30)*4+10), (30,30,30,255)); od = ImageDraw.Draw(out)
for i, im in enumerate(shots):
    x, y = 10+(i%2)*(w+10), 10+(i//2)*(h+30)
    od.text((x, y), names[i], fill=(255,240,200), font=SMALL)
    out.alpha_composite(im.resize((w, h), Image.LANCZOS), (x, y+20))
out.save("tools/last_shop_tour_mockup.png")

"""Static mockup of the decoration tour, composited on probe shots at 1080p.
Writes tools/last_decor_tour_mockup.png. Judged by eye before anything is built."""
from PIL import Image, ImageDraw, ImageFont
SHEET = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
T, COLS, S = 16, 34, 2
sheet = Image.open(SHEET).convert("RGBA")
def tile(n):
    r, c = divmod(n, COLS)
    return sheet.crop((c*T, r*T, c*T+T, r*T+T)).resize((T*S, T*S), Image.NEAREST)
FONT = ImageFont.truetype("assets/Bungee-Regular.ttf", 15)
SMALL = ImageFont.truetype("assets/Bungee-Regular.ttf", 12)
PAPER, EDGE, INK, SOFT, OUTER = (234,219,184), (199,179,138), (50,36,28), (94,77,60), (60,42,30)

def wrap(d, text, wide):
    lines, line = [], ""
    for w in text.split():
        t = w if not line else line + " " + w
        if d.textlength(t, font=FONT) > wide and line: lines.append(line); line = w
        else: line = t
    return lines + [line]

def shed_with_plank():
    img = Image.open("tools/last_shed.png").convert("RGBA")
    d = ImageDraw.Draw(img)
    # The tour's shelf: nothing kept yet, the bed waiting at the pump.
    d.rectangle((1332, 205, 1612, 905), fill=PAPER)
    d.text((1472, 260), "Nothing kept yet.", fill=SOFT, font=SMALL, anchor="mm")
    d.rectangle((1370, 290, 1575, 345), fill=(60,42,30)); d.rectangle((1376, 296, 1569, 339), fill=(28,52,48))
    d.text((1472, 318), "WASH  1", fill=(234,219,184), font=FONT, anchor="mm")
    d.text((1480, 178), "DECORATE 0", fill=(234,219,184), font=FONT, anchor="mm")
    return img

def frame(img, box, text, side, n, total, card=True, count=True):
    shade = Image.new("RGBA", img.size, (0,0,0,0)); sd = ImageDraw.Draw(shade)
    sd.rectangle((0,0)+img.size, fill=(0,0,0,150)); sd.rectangle(box, fill=(0,0,0,0))
    img.alpha_composite(shade); d = ImageDraw.Draw(img)
    d.rectangle(box, outline=(255,255,255,230), width=3)
    a = tile(604).transpose(Image.FLIP_TOP_BOTTOM)
    img.alpha_composite(a, ((box[0]+box[2])//2 - a.width//2, box[1] - a.height - 4))
    wide = 300; lines = wrap(d, text, wide - 28); tall = 22*len(lines) + (70 if count else 30)
    if side == "right": x, y = box[2] + 30, box[1] + 60
    elif side == "left": x, y = box[0] - 30 - wide, box[1] + 20
    elif side == "below": x, y = (box[0]+box[2])//2 - wide, box[3] + 20
    else: x, y = box[2] - wide - 30, box[1] + 30
    d.rectangle((x-5, y-5, x+wide+5, y+tall+5), fill=OUTER)
    d.rectangle((x, y, x+wide, y+tall), fill=PAPER, outline=EDGE, width=3)
    top = y + (28 if count else 12)
    if count: d.text((x+wide-14, y+10), f"{n}/{total}", fill=SOFT, font=SMALL, anchor="ra")
    for k, s in enumerate(lines): d.text((x+wide/2, top+k*22), s, fill=INK, font=FONT, anchor="ma")
    if count:
        foot = y + tall - 26
        d.text((x+14, foot), "Skip", fill=SOFT, font=SMALL, anchor="lm")
        icon = tile(77); d.text((x+wide-14-icon.width-6, foot), "Continue", fill=INK, font=SMALL, anchor="rm")
        img.alpha_composite(icon, (x+wide-14-icon.width, foot-icon.height//2))
    return img

shots = [
 ("B. first find: arrow on Decorate", frame(Image.open("tools/last_steps_move.png").convert("RGBA"), (1520,30,1697,176),
   "You caught a decoration! Open Decorate to see it.", "below", 0, 0, count=False)),
 ("1. shed: wash plank", frame(shed_with_plank(), (1366,286,1579,349),
   "You need to wash objects before it is available for decoration.", "left", 1, 5)),
 ("2. wash: list (bed free)", frame(Image.open("tools/last_wash_room.png").convert("RGBA"), (45,180,440,515),
   "Select the object to wash, it costs $5 to $15 depending on size.", "right", 2, 5)),
 ("3. wash: stand", frame(Image.open("tools/last_wash_room.png").convert("RGBA"), (440,180,1480,1000),
   "Point and click to spray the object with water. It goes to decoration inventory when done.", "inside", 3, 5)),
 ("4. shed: shelf", frame(Image.open("tools/last_shed.png").convert("RGBA"), (1300,155,1655,925),
   "Select and drag the object to its position. Press R to rotate or change style.", "left", 4, 5)),
 ("5. shed: room", frame(Image.open("tools/last_shed.png").convert("RGBA"), (285,155,1290,925),
   "You can interact with some objects. It shows when available.", "right", 5, 5)),
]
w, h = 960, 540
out = Image.new("RGBA", (w*2+30, (h+30)*3+10), (30,30,30,255)); od = ImageDraw.Draw(out)
for i, (name, im) in enumerate(shots):
    x, y = 10+(i%2)*(w+10), 10+(i//2)*(h+30)
    od.text((x, y), name, fill=(255,240,200), font=SMALL)
    out.alpha_composite(im.resize((w,h), Image.LANCZOS), (x, y+20))
out.save("tools/last_decor_tour_mockup.png")

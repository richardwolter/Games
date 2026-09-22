"""Static mockup of the first-steps hints, composited on a game screenshot.
Judged by eye before anything is built. Writes tools/last_tutorial_mockup.png."""
from PIL import Image, ImageDraw, ImageFont
SHEET = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
BG = "tools/last_letter_walking.png"
T, COLS, S = 16, 34, 2
sheet = Image.open(SHEET).convert("RGBA")
def tile(n, s=S):
    r, c = divmod(n, COLS)
    return sheet.crop((c*T, r*T, c*T+T, r*T+T)).resize((T*s, T*s), Image.NEAREST)
MOUSE_IDLE, MOUSE_CLICK = 76, 77
W, A, SK, D, Z, Q = 358, 392, 393, 394, 427, 357
STICK, STICK_DIR, RT, ARROW = 246, 253, 590, 604
HEAD = (970, 500)          # over the angler's hat
BEACH = (1360, 520)        # a spot on the east beach
WATER = (1560, 470)        # green water in reach from there
CRATE = (1138, 550)
FONT = ImageFont.truetype("assets/Bungee-Regular.ttf", 18)
NOTE_FONT = ImageFont.truetype("assets/Bungee-Regular.ttf", 13)
PAPER, EDGE, INK, HEADINK = (234,219,184), (199,179,138), (50,36,28), (115,40,26)

def ring(img, at, rx, ry, dashed=False):
    # the pulse: a fainter ring breathing out past the solid one
    glow = Image.new("RGBA", img.size); g = ImageDraw.Draw(glow)
    g.ellipse((at[0]-rx*1.3, at[1]-ry*1.3, at[0]+rx*1.3, at[1]+ry*1.3),
              outline=(255,255,255,110), width=3)
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    for w, col in ((7, (0,0,0,110)), (3, (255,255,255,235))):
        box = (at[0]-rx, at[1]-ry, at[0]+rx, at[1]+ry)
        if dashed:
            for a in range(0, 360, 30):
                d.arc(box, a, a+18, fill=col, width=w)
        else:
            d.ellipse(box, outline=col, width=w)

def arrow(img, at):
    a = tile(ARROW).transpose(Image.FLIP_TOP_BOTTOM)
    img.alpha_composite(a, (at[0]-a.width//2, at[1]-a.height-14))

def paste_row(img, tiles, centre, gap=4):
    wide = sum(t.width for t in tiles) + gap*(len(tiles)-1)
    x = centre[0] - wide//2
    for t in tiles:
        img.alpha_composite(t, (x, centre[1]-t.height//2)); x += t.width + gap

def keys(img, centre, up, left, down, right):
    t = tile(up); w = t.width
    img.alpha_composite(t, (centre[0]-w//2, centre[1]-w))
    paste_row(img, [tile(left), tile(down), tile(right)], (centre[0], centre[1]+w//2), gap=0)

def move_frame(mode):
    img = Image.open(BG).convert("RGBA")
    ring(img, BEACH, 34, 17); arrow(img, BEACH)
    if mode == "pad":
        paste_row(img, [tile(STICK_DIR)], (HEAD[0], HEAD[1]-40))
    else:
        img.alpha_composite(tile(MOUSE_CLICK), (HEAD[0]-58, HEAD[1]-60))
        k = (Z, Q, SK, D) if mode == "azerty" else (W, A, SK, D)
        keys(img, (HEAD[0]+20, HEAD[1]-40), *k)
    return img

def cast_frame(mode):
    img = Image.open(BG).convert("RGBA")
    # angler now stands on the beach spot
    ring(img, WATER, 60, 30); arrow(img, WATER)
    over = (BEACH[0], BEACH[1]-70)
    paste_row(img, [tile(RT if mode == "pad" else MOUSE_CLICK)], over)
    return img

def note_frame():
    img = Image.open(BG).convert("RGBA")
    d = ImageDraw.Draw(img)
    lines = ["Objects caught go to the", "recycle box so boats can take",
             "them to piers for money"]
    x0, y0, wide, tall = CRATE[0]+60, CRATE[1]-30, 270, 80
    d.rectangle((x0-6, y0-6, x0+wide+6, y0+tall+6), fill=(60,42,30))
    d.rectangle((x0, y0, x0+wide, y0+tall), fill=PAPER, outline=EDGE, width=3)
    for i, s in enumerate(lines):
        w = d.textlength(s, font=NOTE_FONT)
        d.text((x0+(wide-w)/2, y0+11+i*21), s, fill=INK, font=NOTE_FONT)
    arrow(img, (CRATE[0], CRATE[1]-44))
    # the catch arcing in from the water
    for i, t in enumerate((0.2, 0.45, 0.7)):
        px = WATER[0] + (CRATE[0]-WATER[0])*t
        py = WATER[1] + (CRATE[1]-WATER[1])*t - 160*4*t*(1-t)
        d.ellipse((px-7, py-7, px+7, py+7), fill=(200,70,60), outline=(0,0,0))
    return img

CROP = (620, 260, 1720, 700)
frames = [("1. Move - keyboard/mouse", move_frame("qwerty")),
          ("1. Move - AZERTY", move_frame("azerty")),
          ("1. Move - gamepad", move_frame("pad")),
          ("2. Cast - mouse", cast_frame("mouse")),
          ("2. Cast - gamepad", cast_frame("pad")),
          ("3. Recycle box note", note_frame())]
cw, ch = CROP[2]-CROP[0], CROP[3]-CROP[1]
out = Image.new("RGBA", (cw*2+30, (ch+40)*3+10), (30,30,30,255))
d = ImageDraw.Draw(out)
for i, (name, im) in enumerate(frames):
    x, y = 10 + (i%2)*(cw+10), 10 + (i//2)*(ch+40)
    d.text((x, y), name, fill=(255,240,200), font=FONT)
    out.alpha_composite(im.crop(CROP), (x, y+28))
out.save("tools/last_tutorial_mockup.png")

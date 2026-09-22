"""Numbered contact sheet of Kenney Input Prompts Pixel, for picking tiles."""
from PIL import Image, ImageDraw
SRC = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
T, S, PAD = 16, 3, 12
src = Image.open(SRC).convert("RGBA")
cols, rows = src.width // T, src.height // T
cw, ch = T * S + 4, T * S + PAD + 4
out = Image.new("RGBA", (cols * cw, rows * ch), (58, 74, 60, 255))
d = ImageDraw.Draw(out)
for r in range(rows):
    for c in range(cols):
        tile = src.crop((c*T, r*T, c*T+T, r*T+T)).resize((T*S, T*S), Image.NEAREST)
        x, y = c*cw + 2, r*ch + 2
        out.alpha_composite(tile, (x, y))
        d.text((x, y + T*S), str(r*cols + c), fill=(255, 240, 200, 255))
out.save("tools/last_prompt_contact.png")
print(cols, rows, out.size)

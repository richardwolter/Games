# Cuts the level 2 (downtown) balcony out of its img2img pass:
#  - balcony_modern: glass + steel rail, `balcony_modern` d0.4 seed 9101.
# Alpha is the template mask (steel opaque, glass a faint tint) lifted wherever
# the model inked a line, so every stroke on the glass stays solid.
# The city is built separately by tools/skyline_art.py --modern; the sun and moon
# are drawn in code (sky.gd).
from PIL import Image, ImageChops, ImageOps
W, H = 1664, 256
raw = Image.open("art/_preview/balcony_modern_2_d04.png").convert("L").resize((W, H), Image.LANCZOS)
# the left few columns carry a grey border from the generation canvas
raw.paste(255, (0, 0, 6, H))
mask = Image.open("art_ref/balcony_modern_mask.png").convert("L")
ink_alpha = ImageOps.invert(raw).point(lambda v: 255 if v > 90 else v * 2)
alpha = ImageChops.lighter(mask, ink_alpha)
Image.merge("RGBA", (raw, raw, raw, alpha)).resize((1152, 178), Image.LANCZOS).save("art/scene/balcony_modern.png")
print("wrote art/scene/balcony_modern.png")

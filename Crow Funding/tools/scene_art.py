# Finishes the scene art from the approved previews:
#  - city:    city_bg seed 6200, fitted to the 1152-wide design, ink kept as-is
#  - balcony: balcony d0.5 seed 7500, greys pushed to ink-on-paper, alpha from the
#             template mask so the city shows between the balusters
from PIL import Image, ImageFilter
city = Image.open("art/_preview/city_bg_1_d1.png").convert("RGB")
city = city.resize((1152, round(city.height * 1152 / city.width)), Image.LANCZOS)
# lighter ink for distance, so the crows and the railing read in front of it
city = city.point(lambda v: 255 - int((255 - v) * 0.6))
city.save("art/scene/city.png")

raw = Image.open("art/_preview/balcony_1_d05.png").convert("L").resize((1664, 256), Image.LANCZOS)
# flat greys become pen hatching: darker grey, denser diagonal lines, so the
# railing reads as ink rather than as a grey fill
ink = Image.new("L", raw.size, 255); src = raw.load(); dst = ink.load()
for y in range(raw.height):
    for x in range(raw.width):
        v = src[x, y]
        if v < 60:
            dst[x, y] = 0
        elif v < 215:
            dark = 1.0 - (v - 60) / 155.0            # 0 light .. 1 dark
            spacing = 11 - int(dark * 7)             # 11 px apart when light, 4 when dark
            if (x + y) % spacing < 2 or (dark > 0.6 and (x - y) % spacing < 1):
                dst[x, y] = 20
mask = Image.open("art_ref/balcony_mask.png").convert("L").filter(ImageFilter.MaxFilter(5))
out = Image.merge("RGBA", (ink, ink, ink, mask))
out.resize((1152, 178), Image.LANCZOS).save("art/scene/balcony.png")

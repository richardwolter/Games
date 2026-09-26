# Turns an approved skyline preview into the two textures city.gd draws:
#
#   art/scene/city.png         the drawing with its sky cut away (alpha 0), so the
#                              sun and moon, drawn behind it, set behind buildings
#                              instead of showing through their white paper
#   art/scene/city_lights.png  warm window glows for the night, drawn additively
#
# The sky cut: ink is dense wherever there is architecture and sparse in the sky
# (loose cloud strokes, open paper). Blur the darkness, threshold it, and keep
# only what is connected to the bottom edge: that is the city. Whatever else is
# left is sky, including any paper trapped between spires.
#
# Windows: small, upright, dark blobs inside the city. A random third of them
# light up, so the pattern reads as lived-in rather than as a grid.
#
#   python tools/skyline_art.py art/_preview/skyline_3_d1.png
import sys
import cv2
import numpy as np

SRC = sys.argv[1] if len(sys.argv) > 1 else "art/_preview/skyline_1_d1.png"
W = 1152
rng = np.random.default_rng(1234)

img = cv2.imread(SRC, cv2.IMREAD_GRAYSCALE)
H = round(img.shape[0] * W / img.shape[1])
img = cv2.resize(img, (W, H), interpolation=cv2.INTER_AREA)

dark = 255 - img.astype(np.float32)
density = cv2.GaussianBlur(dark, (0, 0), 3.0)
# Horizon: the first row (from the top) where the ink stays dense across most of
# the width for a good stretch - the carpet of distant rooftops.
row_frac = (density > 45).mean(axis=1)
horizon = next(y for y in range(H - 20) if row_frac[y:y + 12].min() > 0.55)
# Above the horizon only towers and spires count as city: per column, climb up
# from the horizon while the ink stays dense; everything higher is sky, clouds
# included (clouds are sparse strokes separated from the spires by paper).
tall = cv2.GaussianBlur(dark, (0, 0), 1.6) > 60
tall = cv2.morphologyEx(tall.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 3), np.uint8)).astype(bool)
top = np.full(W, horizon, np.int32)
for x in range(W):
    y = horizon
    gap = 0
    while y > 0:
        if tall[y - 1, max(0, x - 1):x + 2].any():
            gap = 0
        else:
            gap += 1
            if gap > 3:
                break
        y -= 1
    top[x] = y + gap
sky = np.zeros((H, W), bool)
for x in range(W):
    sky[:top[x], x] = True
mask = (~sky).astype(np.uint8) * 255
mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
mask = cv2.GaussianBlur(mask, (0, 0), 0.8)

# fade the ink a little for distance, so crows and railing read in front of it
page = (255 - (255 - img.astype(np.float32)) * 0.78).astype(np.uint8)
rgba = np.dstack([page, page, page, mask])
cv2.imwrite("art/scene/city.png", rgba)

# windows
ink = (img < 95).astype(np.uint8)
n3, l3, stats, cent = cv2.connectedComponentsWithStats(ink, connectivity=8)
lights = np.zeros((H, W), np.float32)
core = np.zeros((H, W), np.float32)
horizon_y = int(H * 0.30)
lit = 0
for i in range(1, n3):
    x, y, w, h, area = stats[i]
    if y < horizon_y or area < 6 or area > 260:
        continue
    if not (h >= w * 0.9 and h <= w * 4.5):
        continue
    if area / float(w * h) < 0.45:
        continue
    if mask[y + h // 2, x + w // 2] < 200 or rng.random() > 0.33:
        continue
    sel = l3[y:y + h, x:x + w] == i
    core[y:y + h, x:x + w][sel] = 1.0
    lit += 1
halo = cv2.GaussianBlur(core, (0, 0), 3.5) * 2.2
lights = np.clip(core * 0.95 + halo, 0.0, 1.0)
warm = np.array([0.42, 0.78, 1.0], np.float32)  # BGR: warm amber
out = np.dstack([warm[0] * np.ones_like(lights), warm[1] * np.ones_like(lights), warm[2] * np.ones_like(lights), lights]) * 255
cv2.imwrite("art/scene/city_lights.png", out.astype(np.uint8))
print(f"{SRC}: {W}x{H}, horizon {horizon}, sky {sky.mean():.0%}, {lit} lit windows")

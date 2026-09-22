"""Cut the input prompts the first-steps hints use out of Kenney's Input Prompts Pixel
(CC0, art_source/kenney_inputPromptsPixel16x/). Tile numbers are Richard's picks off
tools/last_prompt_contact.png (tools/prompt_contact.py). Writes assets/ui/prompts/*.png at
the pack's own 16 px; the game scales them. Reimport after a re-run."""
import os
from PIL import Image
SHEET = "art_source/kenney_inputPromptsPixel16×/Tilemap/tilemap_packed.png"
OUT = "assets/ui/prompts"
T, COLS = 16, 34
PICKS = {
    "mouse_idle": 76, "mouse_click": 77,
    "key_w": 358, "key_a": 392, "key_s": 393, "key_d": 394, "key_z": 427, "key_q": 357,
    "stick": 246, "stick_dirs": 253, "pad_rt": 590, "pad_a": 4, "arrow_up": 604,
}
os.makedirs(OUT, exist_ok=True)
sheet = Image.open(SHEET).convert("RGBA")
for name, n in PICKS.items():
    r, c = divmod(n, COLS)
    sheet.crop((c*T, r*T, c*T+T, r*T+T)).save(f"{OUT}/{name}.png")
print(len(PICKS), "prompts")

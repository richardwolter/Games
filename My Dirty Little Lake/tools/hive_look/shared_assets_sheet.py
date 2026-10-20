#!/usr/bin/env python
"""Contact sheet of assets/bees.png and assets/honey_pot.png: every frame at 1x and 6x, its anchor
(pink). Writes tools/hive_look/last_shared_assets.png. Run from the project root with the base
python and PYTHONPATH on the psd-extract venv site-packages."""
import sys, json
sys.path.insert(0, "tools/hive_look")
import look
from PIL import Image, ImageDraw
BG=(84,120,96,255)
def load(n):
    j=json.load(open("assets/%s.json"%n)); im=Image.open("assets/%s.png"%n).convert("RGBA"); return j,im
parts=[]
for n in ("bees","honey_pot"):
    j,sh=load(n)
    tiles=[]
    for name,fr in j["frames"].items():
        x,y,w,h=fr["rect"]; c=sh.crop((x,y,x+w,y+h))
        big=look.zoom(c,6)
        t=Image.new("RGBA",(max(w*6,w)+w+18, max(h*6,40)+30),BG)
        t.alpha_composite(c,(4,4)); t.alpha_composite(big,(w+12,4))
        ax,ay=fr["anchor"]; d=ImageDraw.Draw(t)
        d.rectangle([w+12+ax*6+2,4+ay*6+2,w+12+ax*6+3,4+ay*6+3],fill=(255,0,200,255))
        d.text((4,t.height-22),name,font=look.font(14,"bold"),fill=(255,255,255,255))
        tiles.append(t)
    parts.append(look.text_block(n+".png  (pink dot = anchor; each tile 1x then 6x)",1800,22,"bold"))
    parts.append(look.flow(tiles,1800,10))
out=look.stack(parts,"v",14)
bg=Image.new("RGBA",(out.width+40,out.height+40),look.SHEET_BG); bg.alpha_composite(out,(20,20))
bg.convert("RGB").save("tools/hive_look/last_shared_assets.png"); print(bg.size)

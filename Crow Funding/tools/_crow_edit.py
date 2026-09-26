# One-off: hand edits on crow_merge d045 seed 5203 before a low-denoise img2img pass.
from PIL import Image, ImageDraw
import random, math
random.seed(7)
im=Image.open("art/_preview/crow_merge_4_d045.png").convert("RGBA"); W,H=im.size
# exterior mask from original alpha (flood from corners + leg gap)
m=im.split()[3].point(lambda v:255 if v>40 else 0).convert("RGB")
for p in [(W-1,0),(0,H-1),(W-1,H-1),(0,0),(240,775)]: ImageDraw.floodfill(m,p,(255,0,0))
ext=Image.new("L",(W,H),0); pe=ext.load(); pm=m.load()
for y in range(H):
    for x in range(W):
        if pm[x,y]==(255,0,0): pe[x,y]=255
alpha=Image.eval(ext,lambda v:255-v); ad=ImageDraw.Draw(alpha)
c=Image.new("RGBA",(W,H),"white"); c.alpha_composite(im); d=ImageDraw.Draw(c)
K=(0,0,0,255); Wt=(255,255,255,255)
# 1. tail
d.rectangle((0,690,150,830),fill=Wt); ad.rectangle((0,690,150,830),fill=0)
def feather(root,tip,w):
    dx,dy=tip[0]-root[0],tip[1]-root[1]; L=math.hypot(dx,dy); nx,ny=-dy/L,dx/L
    mid=(root[0]+dx*0.55,root[1]+dy*0.55)
    pts=[(root[0]+nx*w*0.5,root[1]+ny*w*0.5),(mid[0]+nx*w,mid[1]+ny*w),tip,(mid[0]-nx*w,mid[1]-ny*w),(root[0]-nx*w*0.5,root[1]-ny*w*0.5)]
    d.polygon(pts,fill=K); ad.polygon(pts,fill=255)
    d.line(pts[:3],fill=Wt,width=2)
    d.line([root,(tip[0]-dx*0.08,tip[1]-dy*0.08)],fill=Wt,width=1)
    for k in range(4):
        t=0.3+0.15*k; p=(root[0]+dx*t,root[1]+dy*t)
        d.line([p,(p[0]+nx*w*0.8+dx*0.08,p[1]+ny*w*0.8+dy*0.08)],fill=Wt,width=1)
for root,tip,w in [((140,700),(15,800),20),((135,710),(30,830),22),((150,715),(55,850),22),((160,715),(90,860),20)]:
    feather(root,tip,w)
poly=[(40,690),(160,660),(175,735),(110,725)]; d.polygon(poly,fill=K); ad.polygon(poly,fill=255)
# 2. eye
ex,ey=382,57
d.ellipse((ex-17,ey-17,ex+17,ey+17),fill=K); d.ellipse((ex-13,ey-13,ex+13,ey+13),fill=Wt)
d.ellipse((ex-8,ey-8,ex+8,ey+8),fill=K); d.ellipse((ex-4,ey-6,ex+1,ey-1),fill=Wt)
# 3. shoulder patch
for j in range(22):
    x0=338+random.randint(0,55); y0=205+random.randint(0,95); ln=random.randint(35,80)
    d.line([(x0,y0),(x0-ln*0.2,y0+ln)],fill=K,width=random.randint(3,6))
for j in range(5):
    x0=315+j*15; d.arc((x0-30,220+j*14,x0+30,280+j*14),200,340,fill=K,width=4)
c.putalpha(alpha); c.save("art_ref/crow_edit.png")
bb=Image.new("RGBA",c.size,(200,220,255,255)); bb.alpha_composite(c); bb.convert("RGB").save("tools/_edit_view.png")

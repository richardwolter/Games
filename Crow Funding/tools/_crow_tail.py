# One-off: redraw the tail as one wedge continuing the back line, on a canvas widened
# to the left, keeping the eye and shoulder edits from _crow_edit.py.
from PIL import Image, ImageDraw
import math, random
random.seed(3)
PAD=110
src=Image.open("art_ref/crow_edit.png").convert("RGBA"); W,H=src.size
c=Image.new("RGBA",(W+PAD,H+20),(0,0,0,0)); c.alpha_composite(src,(PAD,0))
rgb=Image.new("RGBA",c.size,"white"); rgb.alpha_composite(c)
alpha=c.split()[3]; d=ImageDraw.Draw(rgb); ad=ImageDraw.Draw(alpha)
X=lambda x:x+PAD
# clear the old tail feathers and blob below y=600 left of the legs
clr=[(X(-PAD),600),(X(54),600),(X(150),690),(X(160),770),(X(140),900),(X(-PAD),900)]
d.polygon(clr,fill="white"); ad.polygon(clr,fill=0)
def bez(p0,p1,p2,n=30):
    return [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0],(1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in [i/n for i in range(n+1)]]
tipU=(X(-60),872); tipL=(X(-30),890)
upper=bez((X(56),605),(X(40),720),tipU)           # continues the back contour
lower=bez(tipL,(X(70),800),(X(150),735))           # underside, tucks behind the legs
body=[(X(150),735),(X(158),665),(X(100),615)]
wedge=upper+[tipU,(X(-50),888),tipL]+lower+body
d.polygon(wedge,fill="black"); ad.polygon(wedge,fill=255)
# hatching: white strokes running base->tip, fanning slightly, like the body's feather lines
for i in range(55):
    f=random.random()
    a=(X(55+f*95),520+f*170)
    b=(X(-50+f*25+random.uniform(-6,6)),870+f*14)
    t0=random.uniform(0.0,0.5); t1=t0+random.uniform(0.2,0.45)
    p=lambda t:(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
    d.line([p(t0),p(t1)],fill="white",width=random.choice([1,1,2]))
# two overlapping feather-layer edges, drawn along the wedge in perspective
for off in (0.35,0.65):
    e=bez((X(60+off*80),640+off*100),(X(20+off*40),790),(X(-45+off*20),875))
    d.line(e,fill="white",width=2)
rgb.putalpha(alpha); rgb.save("art_ref/crow_tail.png")
v=Image.new("RGBA",rgb.size,(200,220,255,255)); v.alpha_composite(rgb); v.convert("RGB").save("tools/_tail_view.png")

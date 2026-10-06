import json,sys
from PIL import Image,ImageDraw
d=json.load(open('assets/pieces.json'));p=d.get('pieces',d)
P={q['name']:q for q in p} if isinstance(p,list) else p
names=sys.argv[1].split(',')
Z=6;img=Image.open('assets/decor_clean.png').convert('RGBA')
tiles=[]
for n in names:
  q=P[n]
  for i,(x,y,w,h) in enumerate(q['alt_views']):
    c=img.crop((x,y,x+w,y+h)).resize((w*Z,h*Z),Image.NEAREST)
    t=Image.new('RGBA',(w*Z+60,h*Z+30),(40,40,50,255));t.alpha_composite(c,(50,20))
    dr=ImageDraw.Draw(t)
    for r in range(0,h+1,4):
      yy=20+(h-r)*Z;dr.line((40,yy,50,yy),fill=(255,255,0));dr.text((2,yy-6),str(r),fill=(255,255,0))
    dr.text((50,2),f"{n[6:]} v{i} {q['alt_roles'][i]}",fill=(255,255,255))
    tiles.append(t)
W=sum(t.width for t in tiles);H=max(t.height for t in tiles)
o=Image.new('RGBA',(W,H),(0,0,0,255));x=0
for t in tiles:o.paste(t,(x,0));x+=t.width
o.save(sys.argv[2])

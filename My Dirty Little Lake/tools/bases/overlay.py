import json
from PIL import Image,ImageDraw
d=json.load(open('assets/pieces.json'));P={q['name']:q for q in d.get('pieces',d)}
img=Image.open('assets/decor_clean.png').convert('RGBA');Z=5;CLR=3;tiles=[]
for n in 'sofa loveseat dining_chair dresser nightstand bookcase_drawers bookcase_tall big_table side_desk kitchen_counter toilet bed bathtub'.split():
  q=P['decor_'+n];s=q['scale']
  for i,(x,y,w,h) in enumerate(q['alt_views']):
    W,H=round(w*s),round(h*s)
    c=img.crop((x,y,x+w,y+h)).resize((W*Z,H*Z),Image.NEAREST)
    b=min(q['base_px'][i%len(q['base_px'])],H)
    t=Image.new('RGBA',(W*Z+2*CLR*Z+10,H*Z+2*CLR*Z+24),(40,40,50,255))
    ox,oy=CLR*Z+5,CLR*Z+18;t.alpha_composite(c,(ox,oy));dr=ImageDraw.Draw(t,'RGBA')
    dr.rectangle((ox,oy+(H-b)*Z,ox+W*Z,oy+H*Z),fill=(255,0,0,70),outline=(255,0,0,255))
    dr.rectangle((ox-CLR*Z,oy+(H-b-CLR)*Z,ox+(W+CLR)*Z,oy+(H+CLR)*Z),outline=(255,255,0,200))
    dr.text((2,2),f"{n} {q['alt_roles'][i]} {b}px",fill=(255,255,255));tiles.append(t)
rows=[tiles[i:i+9] for i in range(0,len(tiles),9)]
imgs=[]
for r in rows:
  o=Image.new('RGBA',(sum(t.width for t in r),max(t.height for t in r)),(0,0,0,255));x=0
  for t in r:o.paste(t,(x,0));x+=t.width
  imgs.append(o)
F=Image.new('RGBA',(max(i.width for i in imgs),sum(i.height for i in imgs)),(0,0,0,255));y=0
for i in imgs:F.paste(i,(0,y));y+=i.height
F.save('tools/last_shed_bases.png')

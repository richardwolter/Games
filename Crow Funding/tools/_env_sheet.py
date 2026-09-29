import sys
from PIL import Image
names=['env_water_tower','env_fire_escape','env_belfry','env_harbour_crane','env_park_lamp']
def sheet(ns,w,out):
    h=w*832//1536
    S=Image.new('L',(4*w,len(ns)*h),255)
    for r,n in enumerate(ns):
        for i in range(4):
            S.paste(Image.open(f'art/env/{n}_{i+1}.png').convert('L').resize((w,h)),(i*w,r*h))
    S.save(out,optimize=True)
if sys.argv[1]=='review':
    for n in names: sheet([n],700,f'tools/_rev_{n}.png')
else: sheet(names,768,'art/env_candidates.png')

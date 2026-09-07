from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,re,csv,hashlib,math
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/visuals/2026-09-06'
OUT.mkdir(parents=True,exist_ok=True)
sources={p.relative_to(ROOT).as_posix():p.read_text(encoding='utf-8',errors='replace') for base in ('scripts','scenes','data/raw') for p in (ROOT/base).rglob('*') if p.suffix in ('.gd','.tscn','.json') and '/debug/' not in p.as_posix() and '/sim/' not in p.as_posix()}
sources['project.godot']=(ROOT/'project.godot').read_text()
dm=sources['scripts/autoloads/DataManager.gd']
rows=[]
for base in ('assets','legacy-angular/public','icon.svg'):
 for p in ([ROOT/base] if (ROOT/base).is_file() else sorted((ROOT/base).rglob('*'))):
  if p.suffix.lower() not in ('.png','.webp','.svg','.ttf','.gdshader','.tres','.glb','.obj'): continue
  rel=p.relative_to(ROOT).as_posix(); owners=[s for s,t in sources.items() if 'res://'+rel in t]
  if rel=='icon.svg': group='app-icon'
  elif rel.startswith('assets/portraits/enemies/'): group='enemies'
  elif rel.startswith('assets/portraits/'): group='heroes'
  elif rel.startswith('assets/icons/items/'): group='items'
  elif rel.startswith('assets/ui/events/'): group='events'
  elif 'logo' in rel.lower(): group='logo'
  elif rel.startswith('legacy-angular/'): group='legacy'
  elif '/new icons/' in rel: group='source-pack'
  elif '/pips/' in rel: group='pips'
  elif '/icons/' in rel: group='icons'
  else: group='chrome'
  status='literal reference' if owners else 'unverified / source variant'
  if group=='heroes' and p.suffix=='.png' and re.match(r'^(pulse|combat|shield|avalanche|medic|engineer|ghost|breaker)(_|\.)',p.name) and p.name!='pulse_base_new.png': status='runtime convention'; owners.append('scripts/autoloads/DataManager.gd')
  if group=='enemies' and '"'+p.name+'"' in dm: status='runtime map'; owners.append('scripts/autoloads/DataManager.gd')
  if group=='events' and p.stem in sources['scripts/autoloads/GameState.gd']: status='runtime event convention';owners.append('scripts/autoloads/GameState.gd')
  w=h=0; alpha=''; box=''
  if p.suffix in ('.png','.webp'):
   im=Image.open(p); w,h=im.size
   if 'A' in im.getbands():
    a=im.getchannel('A'); alpha=str(round(sum(a.histogram()[:255])/(w*h)*100,1));box=str(a.getbbox())
  rows.append(dict(path=rel,group=group,width=w,height=h,nonopaque_percent=alpha,alpha_bbox=box,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),reference_evidence=status,owners='; '.join(sorted(set(owners)))))
with (OUT/'asset-index.csv').open('w',newline='',encoding='utf-8') as f:
 wr=csv.DictWriter(f,fieldnames=rows[0]);wr.writeheader();wr.writerows(rows)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',14)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',11)
manifest={}
for group in ('heroes','enemies','items','events','pips','icons','logo','chrome','legacy'):
 entries=[r for r in rows if r['group']==group and r['width'] and not r['path'].endswith('.webp')]
 if not entries: continue
 if group=='legacy':
  manifest[group]={'count':len(entries),'pages':[], 'note':'Indexed as source warehouse; not part of current visual judgement.'}
  continue
 cols=5 if group in ('heroes','enemies','events') else 6; cw,ch=200,228
 pages=[]
 for page in range(math.ceil(len(entries)/30)):
  subset=entries[page*30:page*30+30]; im=Image.new('RGB',(cols*cw,50+math.ceil(len(subset)/cols)*ch),'#101820');d=ImageDraw.Draw(im)
  d.text((12,14),f'{group.upper()} | {page+1} | Source assets; runtime crops may differ',font=font,fill='#b8e9ed')
  for i,r in enumerate(subset):
   x=(i%cols)*cw;y=50+(i//cols)*ch
   a=Image.open(ROOT/r['path']).convert('RGBA');a.thumbnail((cw-16,ch-52),Image.Resampling.NEAREST)
   im.paste(a,(x+(cw-a.width)//2,y+(ch-52-a.height)//2),a)
   name=Path(r['path']).stem
   d.text((x+5,y+ch-48),name[:26],font=small,fill='white')
   if len(name)>26:d.text((x+5,y+ch-35),name[26:52],font=small,fill='white')
   d.text((x+5,y+ch-19),f"{r['width']}x{r['height']} | {page*30+i+1}",font=small,fill='#91a3ae')
  name=f'{group}-{page+1:02}.jpg';im.save(OUT/name,quality=92);pages.append(name)
 manifest[group]={'count':len(entries),'pages':pages}
(OUT/'inventory-summary.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({'files':len(rows),'groups':manifest},indent=2))

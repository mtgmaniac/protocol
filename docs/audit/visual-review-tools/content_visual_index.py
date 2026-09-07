from pathlib import Path
import json,re,csv
R=Path(__file__).resolve().parents[3]; O=R/'docs/visuals/2026-09-06'
dm=(R/'scripts/autoloads/DataManager.gd').read_text(encoding='utf-8')
def mapping(name):
 return dict(re.findall(r'"([^"]+)":\s*"([^"]+)"',re.search(r'const '+name+r' := \{(.*?)\n\}',dm,re.S)[1]))
hero_notes={
'pulse':'Keep yellow faceplate; strengthen an energy-tool silhouette, since it competes with Engineer.',
'pulse_pyro':'Keep ember tubes; put the heat source within the face/shoulder crop so orange alone does not identify it.',
'pulse_arc':'Keep electrical shoulder arcs; simplify tiny filaments for battle scale.',
'combat':'Keep blue visor; give the standard soldier one unique helmet notch or armor contour.',
'combat_blade':'Rework silhouette: bladed shoulder/arm element must survive the crop; currently close to base.',
'combat_ravager':'Keep angular red visor and more aggressive armor; effective branch separation.',
'shield':'Rework first: the base Spike Guard has few visible spikes; purple face also competes with Ghost.',
'shield_bulwark':'Keep broad chest and shield cells; prioritize one bold barrier shape over small hex detail.',
'shield_sentinel':'Keep strong spikes; this branch communicates the defensive counterattack role more clearly than the base.',
'avalanche':'Keep white armor and fur collar; strongest base silhouette/value anchor.',
'avalanche_glacier':'Keep ice framing, simplify peripheral crystals; clear theme and readable upgrade.',
'avalanche_trench':'Keep heavy brown enclosure and amber lamp; strong contrast against Glacier.',
'medic':'Keep white/red armor and medical insignia; immediately identifiable.',
'medic_medic':'Strengthen silhouette beyond extra equipment; base and Combat Medic remain very close.',
'medic_synth':'Keep green tubes and ring apparatus; strong mechanical evolution while retaining the white armor family.',
'engineer':'Keep asymmetric optics; clarify tools rather than adding more tiny connectors.',
'engineer_overclocked':'Keep amber powered visor; distinguish silhouette from Pulse at small size.',
'engineer_phantom':'Keep partial digital dissolution; preserve Engineer optics so it does not become another Ghost.',
'ghost':'Keep hood; it is an effective silhouette anchor, though its purple palette overlaps Spike.',
'ghost_shadow':'Rework first: base/Shadow use nearly identical hood and mask; streaming cloth is mostly lost in crop.',
'ghost_wraith':'Keep faceless sigil; restrict ornament to one clear alien-tech motif to avoid generic fantasy necromancer.',
'breaker':'Keep orange band visor; include a compact signal apparatus within the crop.',
'breaker_noise':'Keep radial emitter; its distinguishing crown is vulnerable to the established head-focused crop.',
'breaker_nullwire':'Rework first: currently close to base; move cut-cable or muted-emitter identity inside the face/shoulder crop.'}
enemy_notes={
'Scrap Drone':'Keep round single lens and exposed cable torso; clear low-rank industrial enemy.',
'Rust Drone':'Keep rust and flat visor; separate from friendly blue-visored soldiers with asymmetry.',
'Static Skimmer':'Keep hovering saucer profile; strongly different from humanoid drones.',
'Patrol Enforcer':'Keep blank faceplate; add an obvious weapon/shoulder cue at battle crop.',
'Shield Enforcer':'Strengthen actual barrier or shield silhouette; goggles alone do not explain defense.',
'Heavy Warden':'Keep bulky furnace torso; good industrial silhouette.',
'Volt Enforcer':'Keep yellow insulated suit; electrical hardware can be clearer.',
'Scrapmaster':'Keep scrap crown and furnace mouth; widen silhouette so boss rank survives the card crop.',
'Skitterling':'Strengthen small insect/chaff read; bust treatment makes it look like another armored humanoid.',
'Bloodmite':'Purple crystal-like spikes overlap Mantle/Veil; use organic sacks or hooked limbs to emphasize biology.',
'Spine Stalker':'Keep spine fan and narrow head; coherent predatory shape.',
'Carapace Beetle':'Keep broad plated skull; coherent armored insect.',
'Broodwarden':'Keep egg-like back sacs; keep these visible within crop.',
'Caustic Spewer':'Keep swollen mouth and green acid; clear functional read.',
'Hive Matriarch':'Rework rank: too close to Aegis Anchor and smaller-looking than Broodwarden; distinctive brood crown needed.',
'Shard Drone':'Keep geometric floating shield body; strongest Veil design anchor.',
'Prism Charger':'Keep hard angular gold prism; use as second Veil anchor.',
'Aegis Anchor':'Rework first: organic chitin head is too close to Hive Matriarch; make shield architecture visibly geometric.',
'Resonance Warden':'Keep cyan resonator crown; extend this Veil language across the faction.',
'Phaseblade':'Keep narrow blade helmet; make sharp weapon geometry visible.',
'Relay Herald':'Circular machinery overlaps Signal; emphasize luminous resonator symmetry.',
'Stormweaver':'Rework first: hooded many-eyed cultist reads like Signal rather than geometric Veil.',
'Veil Overseer':'Rework first: hood and gold eyepieces resemble Signal cultists; needs a unique geometric boss crown.',
'Signal Wisp':'Keep glitch dissolution; ensure face silhouette survives purple noise.',
'Circuit Acolyte':'Keep hood and restrained magenta circuit light; clear machine-cult anchor.',
'Cipher Scribe':'Keep narrow mask and segmented hanging strip; simplify micro-glyph detail.',
'Oath Binder':'Keep heavy mechanical chest; distinguish restraint/clamp shapes from general cult machinery.',
'False Image':'Keep split/double face; readable deception motif.',
'Ash Channeler':'Keep violet core and hood; support role can use larger central emitter.',
'Signal Hierophant':'Keep ceremonial red-purple circuit crown; preserve head outline in boss crop.',
'Pumice Climber':'Keep columnar rock mane; close to Basalt Ape, so exaggerate smaller agile head silhouette.',
'Obsidian Hound':'Keep shard-edged canine; separate black glass from Slag molten material.',
'Slag Hound':'Keep orange fractures; make soft/flowing slag contour distinct from Obsidian sharp plates.',
'Geode Panther':'Keep purple crystal growth; avoid letting crystals erase its feline head.',
'Magma Drake':'Keep molten plates and rounder snout; coherent volcanic predator.',
'Cinder Raptor':'Keep long toothed profile and crest; strong silhouette.',
'Basalt Ape':'Keep flat heavy face; differentiate its scale/shape from Pumice Climber.',
'Mantle Tyrant':'Keep dark massive jaw; brighten one edge and enlarge rank silhouette, otherwise it reads as another hound.'}
item_outliers={
'corrosion_bomb':'Replace art: green leaking chemical bomb implies acid/poison, but Interference Charge lowers a roll. Use an interference emitter or antenna charge.',
'gravityWell':'Replace art: 32px pastel ring is the only mapped item/relic image outside the dominant 128px detailed set; fails style cohesion.',
'twinFates':'Reframe art: two small dice and a fine gold line occupy little of the tile; simplify into two large linked dice.',
'entropyLeak':'Rework hourglass motif toward a damaged clock/regulator; currently reads fantasy time magic.',
'standingOrder':'Rework parchment/scroll into a stamped command plate if military emphasis is chosen.',
'salvageDirective':'Replace parchment with salvage requisition slate; keep the stamped hierarchy.',
'scavengerManifest':'Use inventory slate rather than parchment to distinguish it from Salvage Directive.',
'signalJam':'Increase antenna silhouette brightness/area; very thin gold wire disappears small.',
'chainDoctrine':'Increase central object occupancy; book/plate is tiny and excessively dark.',
'resonanceCascade':'Clarify machinery; bell-like silhouette reads ceremonial before technological.',
'neural_splice':'Keep skull machine only as a controlled grimdark accent; do not make every item a skull.',
'mercyProtocol':'Keep as ceremonial relic; winged saint shape should remain exceptional.',
'acid_vial':'Keep clear vial silhouette; green chemical art is appropriate here.',
'deep_zero_pin':'Keep pale cryogenic cylinder; strong item function cue.',
'patch_kit':'Keep medical pack and green cross; clear utility silhouette.',
'combat_plating':'Keep armor plate silhouette; immediately understandable.',
'predator_lens':'Keep large lens; one of the strongest icons at reward scale.'}
rows=[]
heroes=json.loads((R/'data/raw/heroes.data.json').read_text())['heroes']
for h in heroes:
 for x,key,kind in [(h,h['id'],'hero')]+[(e,h['id']+'_'+e['id'],'evolution') for e in h['evolutions']]:
  rows.append(dict(kind=kind,id=key,name=x['name'],asset='assets/portraits/'+key+'.png',review=hero_notes[key]))
emap=mapping('ENEMY_PORTRAIT_BY_NAME')
for name,x in json.loads((R/'data/raw/enemies.data.json').read_text())['enemyUnitDefs'].items():
 rows.append(dict(kind='enemy',id=x['type'],name=name,asset='assets/portraits/enemies/'+emap[name],review=enemy_notes[name]))
for file,kind in [('items','consumable'),('gear','gear'),('relics','relic')]:
 data=json.loads((R/f'data/raw/{file}.data.json').read_text()); xs=data[file] if isinstance(data,dict) else data
 imap=mapping('RELIC_ICON_BY_ID' if kind=='relic' else 'ITEM_ICON_BY_ID')
 for x in xs:
  note=item_outliers.get(x['id'],'Keep subject and rendering family; normalize occupied area and verify recognition at loadout size. Reduce small gold detail where it carries no meaning.')
  rows.append(dict(kind=kind,id=x['id'],name=x['name'],asset=imap[x['id']].replace('res://',''),review=note))
with (O/'content-index.csv').open('w',encoding='utf-8',newline='') as f:
 wr=csv.DictWriter(f,fieldnames=rows[0]);wr.writeheader();wr.writerows(rows)
assert all((R/r['asset']).exists() for r in rows)
print('Mapped content:',len(rows),'missing:',0)
# Index every presentation function that contains a tween or animation signal,
# including functions that delegate to presentation helpers, not only raster art.
motion=[]
for p in sorted((R/'scripts').rglob('*.gd')):
 if any(x in p.parts for x in ('debug','sim','checks')):continue
 source=p.read_text(encoding='utf-8'); funcs=list(re.finditer(r'^(?:static )?func (\w+)\(',source,re.M))
 for i,m in enumerate(funcs):
  body=source[m.start():funcs[i+1].start() if i+1<len(funcs) else len(source)]
  if re.search(r'create_tween|tween_property|AnimationPlayer|play_.*feedback|play_jam_flicker|play_rewrite_scramble|set_die_frozen_visual',body):
   motion.append({'owner':p.relative_to(R).as_posix(),'function':m[1],'line':source[:m.start()].count('\n')+1,'evidence':'source inventory; see bible for rendered coverage'})
with (O/'animation-functions.csv').open('w',encoding='utf-8',newline='') as f:
 wr=csv.DictWriter(f,fieldnames=motion[0]);wr.writeheader();wr.writerows(motion)
print('Presentation-related functions:',len(motion))

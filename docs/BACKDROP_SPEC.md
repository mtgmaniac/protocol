# Battle backdrop spec (flat pixel B, 2026-10-16)

The battle backdrop is one full-screen image per battle, drawn BEHIND everything:
the cards, the tray, the header and the footer all sit on top of it. It shows only
in the gaps around them, so it sets the place without competing with the fight.
Code: `battle_depth.gd backdrop_for`, drawn by `battle_bay_floor.gd` (flat scene).
Placeholder example: `assets/battle_backdrops/placeholder_facility_backdrop_01.png`
(and `_boss.png`), made by `scripts/assets/make_placeholder_backdrops.py`.

## Size and scale

| | value |
|---|---|
| Canvas | **270 x 600 px** (required) |
| Scale | **1 image px = 4 design px** (the battle scene's art grid, same as the tray and the title backdrop) |
| Covers | 1080 x 2400 design px, the whole portrait screen |
| On screen | 2 px per image px in the 540 x 1200 desktop preview; about 1.44 px on a 390 px wide phone |
| Optional bleed | up to **270 x 660** for phones taller than 20:9 (the board's card rows stretch on taller screens). The image is drawn **centred**; anything it does not cover shows the plain dark tile. |

Draw at exactly 270 px wide. Never author at design resolution and downscale: the
painter draws one texel per art pixel with NEAREST filtering, so a 1080-wide image
would be drawn 4x too large.

## Safe zones (design px at 1080 x 2400; divide by 4 for image px)

Measured from the shipped layout (±4 px). On taller phones the two card rows grow
and the tray stays put.

| Zone | Design px (y) | Image px (y) | What covers it |
|---|---|---|---|
| Header | 0 - 144 | 0 - 36 | Opaque header band. Fully hidden. |
| Strip under the header | 144 - 158 | 36 - 40 | Visible, full width (thin). |
| **Enemy row** | 158 - 726 | 40 - 182 | Enemy cards. **The main visible area**: see below. |
| Gutter | 726 - 742 | 182 - 186 | Visible, full width (thin). |
| Tray | 742 - 1690 | 186 - 423 | The tray floor is opaque. Hidden except about 10 px each side. |
| Hero row | 1704 - 2272 | 426 - 568 | Hero cards, edge to edge (x 22 - 1058). Hidden except slivers. |
| Footer | 2256 - 2400 | 564 - 600 | Opaque footer. Fully hidden. |

Enemy row, by enemy count (x, design px; image px = / 4):

| Enemies | Cards at | Backdrop shows at |
|---|---|---|
| 1 | 374 - 706 | 0 - 374 and 706 - 1080 (two wide columns) |
| 2 | 105 - 443, 631 - 969 | 0 - 105, **443 - 631 (centre)**, 969 - 1080 |
| 3 | 22 - 354, 374 - 706, 726 - 1058 | slivers only |

So: put the operation's landmark (a machine, a hive wall, a relay mast) in the
enemy-row band, image y 36 - 186, either centred (shows with 2 enemies) or on both
sides (shows with 1). Keep everything below image y 186 a calm, continuous texture:
it is almost all covered, and what peeks out should not look cut off.

## Values (keep it dark)

The cards (fill about `#11191e`) and the tray floor must stay the brightest,
clearest things on screen.

- **Most pixels: luminance 8 - 28** (of 255). The placeholder sits at 10 - 31.
- **Highlights at most 48**, and only as single pixels or short lines (lamps,
  rivets, embers).
- **Saturation at most about 35%.** Low, warm or cool grays per operation.
- Reserved hues, never strong in a backdrop: the player cobalt (`PLAYER_ACCENT`
  `2a6ae6`), the operation's own encounter color (it belongs to the header and the
  enemy cards), and green (HP and heals only, INVARIANTS #7).
- Hard pixel edges, flat tones, no gradients or blur (match the portraits' grid).
- Opaque: no transparency is needed (nothing is drawn under it but the dark tile).

## File format and path

- **PNG**, 8-bit sRGB, RGB or RGBA (opaque). No mipmaps.
- Import stays **Lossless** (`compress/mode=0`, the default). Never lossy WebP or
  VRAM compression: lossy noise shows on dark flat tones.
- Path: `assets/battle_backdrops/<operation>_backdrop_<NN>.png` for the ordinary
  pool, `assets/battle_backdrops/<operation>_backdrop_boss.png` for the boss.
  Operation ids: `facility`, `hive`, `veil`, `voidCirclet` (Signal),
  `stellarMenagerie` (Mantle). Drop the `placeholder_` prefix on real art.

## Registering it

In `data/raw/battle-tray-scenes.json`, under `scenes.<operation id>`:

```json
"backdrops": [
  "res://assets/battle_backdrops/facility_backdrop_01.png",
  "res://assets/battle_backdrops/facility_backdrop_02.png"
],
"boss_backdrop": "res://assets/battle_backdrops/facility_backdrop_boss.png",
"boss_backdrop_battles": [10]
```

- `backdrops`: the pool. One is picked per battle, seeded from the run seed, the
  operation and the battle number (never the combat streams), so a resumed battle
  shows the same image. An empty list draws the plain dark texture.
- `boss_backdrop`: used on the battles listed in `boss_backdrop_battles`. Empty
  means those battles pick from `backdrops` like any other.
- `boss_backdrop_battles`: battle numbers, default `[10]` (the operation boss).
  Add `5` for the mid-run boss: `[5, 10]`.

Then let Godot import the file (open the editor once, or run
`<godot console> --headless --path . --import`) and commit the PNG with its
`.import` file. A path that does not exist falls back to the plain texture, so a
typo shows as "no backdrop", not a crash.

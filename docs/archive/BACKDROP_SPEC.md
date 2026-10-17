# Battle backdrop spec (flat pixel B, 2026-10-16) — RETIRED

> **Retired 2026-10-17 (Kev, DECISIONS_RESOLVED G-76): there is no battle
> backdrop image.** Battle and in-run screens show the plain dark background
> token; the `backdrops` / `boss_backdrop` / `boss_backdrop_battles` fields, the
> placeholder art and `backdrop_for` are removed. Kept for history only. See
> `docs/ART_SPEC.md`.

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
| Scale | **1 image px = 4 design px** (the battle scene's art grid, same as the tray and the title backdrop; the one art-pixel rule of `docs/ART_SPEC.md`, confirmed 2026-10-17) |
| Covers | 1080 x 2400 design px, the whole portrait screen |
| On screen | 2 px per image px in the 540 x 1200 desktop preview; about 1.44 px on a 390 px wide phone |
| Optional bleed | up to **270 x 660** for phones taller than 20:9 (the board's card rows stretch on taller screens). The image is drawn **centred**; anything it does not cover shows the plain dark tile. |

Draw at exactly 270 px wide. Never author at design resolution and downscale: the
painter draws one texel per art pixel with NEAREST filtering, so a 1080-wide image
would be drawn 4x too large.

## Safe zones (design px at 1080 x 2400; divide by 4 for image px)

Measured from the live layout on 2026-10-17 (cards 578 tall after the name-row
step-up, tray 892). On taller phones the two card rows grow and the tray stays
put. One GAP (16) separates each band.

| Zone | Design px (y) | Image px (y) | What covers it |
|---|---|---|---|
| Header | 0 - 144 | 0 - 36 | Opaque header band. Fully hidden. |
| Strip under the header | 144 - 160 | 36 - 40 | Visible, full width (thin). |
| **Enemy row** | 160 - 738 | 40 - 184 | Enemy cards. **The main visible area**: see below. |
| Gutter | 738 - 754 | 184 - 188 | Visible, full width (thin). |
| Tray | 754 - 1646 | 188 - 412 | The tray floor and its 8 px rim are opaque (x 12 - 1068). Hidden except 3 image px each side. |
| Gutter | 1646 - 1662 | 412 - 416 | Visible, full width (thin). |
| Hero row | 1662 - 2240 | 416 - 560 | Hero cards, x 18 - 362, 368 - 712, 718 - 1062. Hidden except slivers. |
| Gutter | 2240 - 2256 | 560 - 564 | Visible, full width (thin). |
| Footer | 2256 - 2400 | 564 - 600 | Opaque footer. Fully hidden. |

Enemy row, by enemy count (x, design px; image px = / 4):

| Enemies | Cards at | Backdrop shows at |
|---|---|---|
| 1 | 368 - 712 | 0 - 368 and 712 - 1080 (two wide columns) |
| 2 | 105 - 449, 630 - 974 | 0 - 105, **449 - 630 (centre)**, 974 - 1080 |
| 3 | 18 - 362, 368 - 712, 718 - 1062 | slivers only |

So: put the operation's landmark (a machine, a hive wall, a relay mast) in the
enemy-row band, image y 36 - 188, either centred (shows with 2 enemies) or on both
sides (shows with 1). Keep everything below image y 188 a calm, continuous texture:
it is almost all covered, and what peeks out should not look cut off.

## Values (keep it dark)

The cards (fill about `#11191e`) and the tray floor must stay the brightest,
clearest things on screen.

- **Most pixels: luminance 8 - 28** (of 255). The placeholder: 11 - 24 for 90% of pixels, max 35.
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

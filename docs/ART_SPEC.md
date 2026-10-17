# Art spec: portraits, items, relics, backdrops (2026-10-17)

Sizes for art made outside the repo, measured from the live layout on
`integration/ui-merge` (after the 2026-10-17 text step-up) at the 1080 x 2400
design resolution. Backdrops (Kev, 2026-10-17, DECISIONS_RESOLVED G-76): a space
image on the title, one Operation Cleared image per operation, no image on
battle or in-run screens. UI rules: `docs/UI_STYLE.md`.

## The one rule: 1 art pixel = 4 design pixels

Every piece of art is drawn on the same grid: **one art pixel covers 4 x 4 design
px**. The full screen is **270 x 600 art px**. On screen one art pixel is 2 px in
the 540 x 1200 desktop preview, about 1.33 px on a 360 px wide phone and 1.44 px
on a 390 px phone.

- Draw at the final art-pixel size. Never paint large and downscale, never upscale
  a small file: the game shows art with NEAREST sampling at **whole multiples** of
  the grid only (4x design, or 8x for a doubled icon), so a file at the wrong size
  shows at the wrong size, not resampled.
- **The one exception: `tools/pixelize.py`** (Kev, 2026-10-17, G-76). A raw,
  large AI-generated source may be converted, because the file that ships is
  written at the exact final art size: an area (box) downscale to the target
  size, then a median-cut quantize to about 32 colours with no dithering
  (`--accents N` keeps a few of them for small lit pixels such as lamps, which
  median cut would otherwise merge away). Raw sources live in
  `assets/art_incoming/`, which holds a `.gdignore`: Godot never imports them and
  they never ship. Only the converted file goes under `assets/`. The title and
  victory images are built by `tools/build_backdrops.py` (the bleed canvas and
  the title's brightness limits on top of pixelize).
- Hard pixel edges, flat tones, no gradients, blur or anti-aliasing.
- PNG, 8-bit sRGB. Import stays **Lossless** (the default). Never lossy WebP or
  VRAM compression: the noise moves on dark flat tones and breaks framing crops.

## Portraits (heroes, evolutions, enemies, bosses)

### Master size: 80 x 96 art px

The battle card shows a **320 x 384 design px** window of the portrait: the card
fits art to a 332 x 384 crop and the card shell (8 px border + 4 px inset) covers 6
px of it on each side. At the one rule that window is exactly **80 x 96 art px**,
so that is the master: one file, the whole visible window, no bleed. (Inside the
"roughly 64 to 80 art px across" aim: 80.) Every multiple is a whole, even number
of design px, so every use below can show it at a whole scale.

| Use | Window today (design px) | 80 x 96 master at | Whole-scale target |
|---|---|---|---|
| Battle card: hero, enemy, boss | 320 x 384 visible (332 x 384 crop) | **4x exact** | 320 x 384 (4x) |
| Squad select, hero tile | 230 x 266 | 2.88x | 240 x 288 (3x), or 160 x 192 (2x) |
| Squad select, encounter thumb (boss) | 216 x 250 | 2.7x | 240 x 288 (3x), or 160 x 192 (2x) |
| Evolution choice | 162 x 188 | 2.03x | 160 x 192 (2x) |
| Unlock screen, new unit | 144 x 166 | 1.8x | 160 x 192 (2x) |
| Help, bestiary rows | 96 x 112 | 1.2x | 80 x 96 (1x) |
| Inspect pop-ups (hero, enemy, item) | no portrait (text and icons only) | | |

Every screen shows the **same window** onto the art, smaller: one framing
(CLAUDE.md "Portrait region"). Nothing else crops a portrait. Squad select at 3x
needs a 248 px tile cell (240 + 4 px border each side): 4 x 248 + 3 x 16 = 1,040
of the 1,080 px row, so it fits but the grid must be checked; 2x always fits.

**What the code does today, and what changes when this art lands.** Today's
portraits are large painted files (heroes 592 x 880) that `cover_fit_portrait`
scales to each window by a fractional factor, adds a 1.2 hero zoom, seats by the
hand-declared head anchors (`portrait_anchors.json`) and nudges by physical px.
None of that is a whole multiple. Showing the 80 x 96 masters at 4x / 3x / 2x / 1x
needs a code task: a native-art framing path (exact scale, no zoom, no anchor
fit, no physical-px nudges, the art placed on the window) and the window sizes
in the table. **Region re-ruled (Kev, 2026-10-17, DECISIONS_RESOLVED G-77):**
the portrait region is the battle card's visible window, 320 x 384 (aspect
0.833), master 80 x 96. Recorded, not yet in code: `PixelUI.HERO_PORTRAIT_REGION`
stays 328 x 380 (0.863), because moving it would make every portrait frame
outside the battle card about 4% taller today. Until that task lands, the other
screens would cover-fit the 80 x 96 master into their 0.863 windows (fitting the
width, the bottom 3% trimmed).

### Framing inside the master

From `portrait_anchors.json` `_targets` (head top at 0.1225 of the window
height, head height 0.42), on the 80 x 96 grid:

- **Head** (skull or helmet dome to chin): top at **row 12**, chin at **row 52**
  (40 art px tall), centred on **column 40**. The head is what frames
  consistently. Antennas, crowns, hoods, horns and halos may run off the top edge
  (ruled acceptable): never shrink the head to keep them.
- **Top-left 16 x 16** (rows 2 to 16, columns 2 to 16): the hero cast-order badge
  sits here on battle cards. Keep the face out of it.
- **Bottom 19 rows** (rows 77 to 94): status chips sit over the bottom of the
  battle card portrait when the unit has statuses. Shoulders and chest only.
- Fill the frame edge to edge; the subject reaches the bottom edge (a bust, cut by
  the frame). Same head size for heroes, enemies and bosses.

### Facing

Draw **every portrait facing right** (turned toward screen right). Heroes show as
drawn. The game mirrors every enemy and boss portrait once at load
(`DataManager._mirror_enemy_portrait`, Kev 2026-09-21), so enemies face left and
the two rows look at each other across the board. Do not pre-mirror enemy art.
Because enemies are mirrored, keep lettering, numbers and one-sided insignia off
enemy and boss art.

### Background

**Opaque pure black, `#000000`.** No transparency. It matches the black backdrop
every portrait frame draws behind its art (`PORTRAIT_BACKDROP_COLOR`), so any gap
is invisible, and opaque hero art is used as-is (transparent art is cropped to
its opaque box at load, which would re-frame the master). No vignette, glow or
scenery behind the subject.

### Files

- Heroes: `assets/portraits/<hero id>.png`; evolutions
  `assets/portraits/<hero id>_<evolution id>.png` (for example
  `avalanche_glacier.png`).
- Enemies and bosses: `assets/portraits/enemies/<file>.png`, the names the
  enemy map in `DataManager` uses.
- Replace each file in place; keep its framing entry in
  `portrait_anchors.json` (the native-art path will ignore the anchor fit).

## Items and relics

### Master size: 32 x 32 art px

**32 x 32, transparent background**, the visual mass centred. At the one rule a
32 px icon is 128 design px: the size of every standard icon box.
`PixelUI.make_integer_icon` already draws any icon of 48 px or less at exactly 4x
on an emblem plate, so 32 px masters follow the grid on every screen with no code
change. Today 88 of the 89 mapped item and relic icons are 128 x 128 files shown
at 1x or 2x (one design px per art pixel, far off the grid); the masters replace
them.

| Box | Where | Box (design px) | 32 px master at |
|---|---|---|---|
| Inspect header icon, inspect gear icon | inspect pop-up | 128 | 4x, fills it |
| Loadout slots | loadout menu | 128 | 4x, fills it |
| Unlock grid | unlock screen | 128 | 4x, fills it |
| Starting Directive relic | squad select | 128 | 4x, fills it |
| Item card | reward and shop cards | 182 (190 less 8) | 4x (128), centred on the plate |
| Reward rows, relic rows | reward screen | 256 | 4x (128), centred on the 256 plate |
| Boss relic | unlock screen | 256 | 4x (128), centred on the 256 plate |

Why not 64: in the 128 px boxes a 64 px icon draws at 2x, half an art pixel of
the grid: 0.67 screen px on a 360 px phone, under one screen pixel, so detail
drops out and shimmers. 64 px works only where a box is 256 (4x). If the 256 px
boxes should be filled, the code can show the 32 px master at 8x there (each art
pixel two grid cells, still on the grid); that is a code choice, not a second
file.

Framing: `portrait_anchors.json` `items` / `relics` entries (`center_x`,
`center_y`, `scale`) place an icon in its box when its mass is off-centre;
`scale` rounds to a whole multiple. Files: `assets/icons/items/<id>.png`,
registered by id in `DataManager.ITEM_ICON_BY_ID` / `RELIC_ICON_BY_ID` (replace
a file in place to keep its entry).

## Battle and in-run screens: no backdrop image

**Ruled out (Kev, 2026-10-17, DECISIONS_RESOLVED G-76).** Battle and every in-run
screen (route fork, intercept, reward, evolution, unlock, the Directive picker)
show the plain dark background token, `PixelUI.UI_BG`. Do not make battle
backdrops; the old spec is archived (`docs/archive/BACKDROP_SPEC.md`). The dice
tray floor is not art either: it is the "grate + ember" floor drawn in code on
the same grid (`battle_bay_floor.gd`, data `tray_floors` in
`data/raw/battle-tray-scenes.json`).

## Title screen backdrop

### Canvas

- **Core: 270 x 600 art px** (1080 x 2400 design px), the 20:9 screen.
- **With bleed: 338 x 660 art px**, the core centred in it (34 art px extra
  each side, 30 top and bottom). The screen keeps 1080 x 2400 design px only at
  20:9: a taller phone adds height (21:9 is 1080 x 2520, 22:9 1080 x 2640, 660
  art px), a shorter one adds width (16:9 is 1350 x 2400, 338 art px). The logo
  and menu stay centred on the screen, so the art is drawn centred too and the
  bleed only shows on those phones. Without bleed, uncovered edges show the plain
  dark screen colour.

### What sits on it (core coordinates; bleed canvas = core + (34, 30) art px)

| Element | Design px (x, y) | Art px (x, y) |
|---|---|---|
| Header band (opaque, with ? and back) | 0 - 1080, 0 - 144 | 0 - 270, 0 - 36 |
| Logo, drawn (run waiting) | 80 - 1000, 716 - 1008 | 20 - 250, 179 - 252 |
| Logo, drawn (no run) | 80 - 1000, 880 - 1172 | 20 - 250, 220 - 293 |
| Menu buttons (run waiting: CONTINUE, BEGIN, FEEDBACK, ABANDON RUN) | 220 - 860, 1060 - 1688 | 55 - 215, 265 - 422 |
| Menu buttons (no run: BEGIN, FEEDBACK) | 220 - 860, 1224 - 1524 | 55 - 215, 306 - 381 |
| Version stamp and its underline | 24 - 177, 2340 - 2390 | 6 - 45, 585 - 598 |

The logo and menu column is centred vertically, so it grows both ways when a
state adds a row (RESUME EARLIER POINT and its note, a save warning).

### Safe zone (exact): **art px x 20 - 250, y 130 - 470** (core)

Design px **x 80 - 1000, y 520 - 1880**; on the bleed canvas art px x 54 - 284,
y 160 - 500. Every menu state's logo, buttons and notes sit inside it, the
tallest (run waiting, with the earlier-point button and a browser save warning)
from about y 528 to 1872. Inside it:

- **Luminance at most 20** (of 255), flat or a very low-contrast texture; no
  edges, windows or lamps behind the logo or button text.
- No shapes that line up with or frame the buttons (they would read as UI).

### Brightness limits (everywhere else)

Same family as the battle backdrops, darker than the menu:

- Most pixels **luminance 8 - 30**; the current placeholder street sits at 10 -
  46 (`PixelUI.TITLE_*`).
- **Highlights at most 48**, single pixels or short lines (lamps, windows,
  rivets), outside the safe zone only.
- **Saturation at most about 35%.** Reserved, never strong: the player cobalt
  `2a6ae6`, the Protocol cyan `66e0ff` (the logo core), the operation encounter
  colours, green.
- Landmarks go outside the safe zone: the band under the header (art y 36 -
  130), the street level below the menu (art y 470 - 585), and the side strips
  (art x 0 - 20 and 250 - 270, wider on 16:9 phones).

### The live image (Kev, 2026-10-17, G-76)

`assets/ui/title/title_backdrop.png`: deep space with a planet's limb along the
bottom, 338 x 660 (the bleed canvas), Lossless import. `scripts/ui/title_backdrop.gd`
draws it one texel per art pixel, centred on the screen, on the shared grid
(`PixelUI.make_art_grid_view`); a missing file draws the plain dark screen
colour (the procedural street is gone). Built from
`assets/art_incoming/title_space_raw.png` by `tools/build_backdrops.py`, which
also prints these checks (`--check` measures the shipped file only; luminance is
Rec. 601 luma):

- Stars are crisp single art pixels; the four-point sparkles keep their cross
  but at plain-star brightness. Stars in the safe zone are kept at luma 20 or
  under, so they are faint there.
- Safe zone: luma 9.6 to 19.7 (median 11.7), limit 20.
- Everywhere else: median 11.7, 97% of pixels in 8 - 30, max 43.7 (the planet's
  rim; the planet is passed through a soft knee so the rim tops out under 48).
  Saturation (HSV) max 35.7%: the stars' cool white.
- Bleed: the core mirrored outward, so the space keeps its faint texture with no
  seam; within 30 art px of the planet the mirror keeps the radius of a circle
  fitted to the rim, so the limb carries on along its own curve to the 16:9
  edges (it meets the core edge at about core y 528 and the bleed edge at about
  540), and the bottom 30 rows mirror the planet's body. A sparse seeded
  starfield is added outside the planet.

Check it at 360 x 800, 390 x 867, 540 x 1200, a 16:9 window (360 x 640) and a
21:9 window (360 x 840) with `scripts/debug/main_menu_capture.gd`
(`--capture-run-save` for the taller menu).

## Operation Cleared image (victory screen)

One per operation (Kev, 2026-10-17, G-76), named by the operation's
`victoryBackdrop` in `data/raw/battle-modes.json` (Facility:
`assets/ui/victory/victory_facility.png`). Same canvas as the title: the 270 x
600 core in a 338 x 660 bleed, drawn one texel per art pixel, centred (the
victory screen reuses `title_backdrop.gd`). An operation without one shows the
plain dark background.

What sits on it (core art px): the header band (y 0 - 36); OPERATION CLEARED and
the operation's name over the sky (about y 60 - 105); the report panel and
CONTINUE in the bottom third (about y 380 - 588 at 20:9). Keep the sky behind the
title calm and put the busy foreground where the panel covers it (the panel is
88% opaque). No brightness limits beyond the global ones: it is a ceremony
screen, not a play surface. Lossless import.

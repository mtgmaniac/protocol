# Flat pixel prototype A (2026-10-16)

Branch `proto/flat-pixel-a`. Rendering and UI only: gameplay, balance data,
copy, saves, dice physics and flow are unchanged. TRUTH.md and
DECISIONS_RESOLVED.md are not edited; this file is the record.
`assets/fonts/battle_block.svg.import` stays out of every commit.

## Phase 0: setup

- The working tree had uncommitted TRUTH.md / DECISIONS_RESOLVED.md entries for
  the battle depth v2 prototype. They were committed as found (`40946c3`, on
  `proto/ui-restyle-a`), without edits; `battle_block.svg.import` was left out.
- UI restyle batch A is on `proto/ui-restyle-a`, head `cbf3915` ("UI restyle A:
  shared theme, Title, Help/Settings, Reward"). It contains battle depth v3
  (`80296e3`). `proto/flat-pixel-a` was cut from `40946c3` (cbf3915 plus the
  docs commit).
- Godot: `project.godot` features line is `"4.6", "Mobile"`. The only modified
  `.import` file is `battle_block.svg.import`, which was already modified before
  this task (it strips the texture importer block; it looks like an import from a
  different editor, possibly the 4.7.2 exe on the Desktop). Not committed, not
  touched. All runs here use `Godot_v4.6.2-stable_win64_console.exe` from
  Downloads.
- Read: TRUTH.md (top entries, Dice rules, Visual identity), INVARIANTS.md,
  DECISIONS_RESOLVED.md (top entries, rarity ruling 18), UI_RESTYLE.md,
  BATTLE_DEPTH_PROTOTYPE.md.

Rules that bear on this task:

- INVARIANTS #7: "Green is reserved for HP bars and heals — nothing else is ever
  green." This decides the PHOSPHOR candidate (Phase 2).
- INVARIANTS #7 / six components: strong cyan belongs to `selected_card`. Squad
  select's selected tile uses that component; recoloring it is logged below.
- Dice rules 1-10 (TRUTH): the flat tray and pixel dice must not touch physics,
  faces, landing, snap, Freeze, Set or recorded throws.
- INVARIANTS #14 (pixel snap): new strokes are even design px and >= 4.

## Phase 1: color roles

All in `scripts/ui/pixel_ui.gd` ("Color roles" block):

- **SYSTEM_ACCENT / SYSTEM_ACCENT_DIM / SYSTEM_ACCENT_INK** (static vars, so F10
  can swap them). The restyle's `UI_ACCENT` / `UI_ACCENT_INK` are gone; every use
  (title logo tint, version underline, title backdrop windows, primary button,
  tabs, toggles, slider, selectable card, art frame, help headers/terms/bullets,
  reward title/relic strip) now reads SYSTEM_ACCENT. The two places that used
  `UI_ACCENT.darkened(...)` as a dim border (art frame, relic card) use
  SYSTEM_ACCENT_DIM.
- **ENCOUNTER accents:** `ENCOUNTER_FACILITY` (amber `cf9a36`, the value v3 used
  through DT_AMBER), `ENCOUNTER_HIVE` (red `c8404a`), `ENCOUNTER_VEIL` (violet
  `8f7ae0`), `ENCOUNTER_SIGNAL` (`b653c8`), `ENCOUNTER_MANTLE` (`d89b4a`). The
  data (`data/raw/battle-tray-scenes.json`, `accent`) names the token per
  operation; `battle_depth.gd encounter_accent(op)` reads it. Signal and Mantle
  had no scene entry: stub entries were added carrying only the accent.
- **The other two operations' colors (reported):** the briefing copy already gave
  every operation a color, as hex literals in `operation_briefing_overlay.gd`:
  Facility `C07A45` (copper), Hive `B94A70` (raspberry), Veil `A6A9C9`
  (lavender gray), **Signal `B653C8` (magenta-violet)**, **Mantle `D89B4A`
  (ochre)**. Signal and Mantle keep their existing colors as their encounter
  tokens. The briefing's five hex literals are removed: `operation_copy()` now
  fills `accent` from the data, so the squad-select site line, its THREATS label
  and the briefing's SITE value show the same encounter color as the battle
  (Facility, Hive and Veil therefore shift to amber, red and violet there).
- **NEUTRAL chrome:** `NEUTRAL_STEEL` (`7d8a96`) and `NEUTRAL_BLUEGRAY`
  (`4c5a66`); the restyle's charcoal family (UI_BG ... UI_TRACK) is declared part
  of this role. The secondary button's left bar was a warm gray (`8c8478`); it is
  now NEUTRAL_STEEL, so secondary buttons carry no warm tint.
- **Unchanged meaning tokens:** hero coding (DT_HERO_*, DT_CYAN), enemy coding
  (DT_ENEMY_*, DT_RUST), HP (BATTLE_HP_*, DT_HP_*), heal / effect icon colors
  (COLOR_*), warning (UI_WARN), rarity. **Legendary** was `UI_ACCENT` by
  reference; it is now its own literal with the same value (`edb03e`, "legendary
  gold") so it does not follow the system color.

Checks: MainMenu and BattleScene load headless with no script errors;
`component_contract.py` PASS.

**Correction (found in Phase 2):** the Phase 1 boot check above did not run. The
Downloads folder holds only the 4.6.2 console wrapper, which exits with "Main
executable not found", and the grep hid it. Re-run in Phase 2 with the 4.6.2 pair
in an earlier session's scratchpad (`.../2c274bf6-.../scratchpad/godot/`):
MainMenu and BattleScene load headless with no script errors.

## Phase 2: the system color

Four candidates in `PixelUI.SYSTEM_ACCENT_CANDIDATES` (accent / dim / ink):

| id | accent | dim | ink |
|---|---|---|---|
| bone | `e6dec8` | `837d6e` | `15130e` |
| phosphor | `8fd16a` | `4c7338` | `0c1409` |
| cyan | `3fd0e2` (= DT_CYAN) | `1f6f7a` | `061217` |
| amber | `edb03e` (= restyle A's UI_ACCENT) | `8a6526` | `17120a` |

- **F10** (debug builds, any screen) cycles them: `PersistentHeader` calls
  `PixelUI.set_system_accent`, restyles the header, then calls the current
  screen's `restyle_system_accent()` if it has one (the battle screen, so a fight
  is not lost) or reloads the screen otherwise.
- **`--system-accent=<id>`** on the command line starts on a candidate (captures).
- Scored from title captures at 390x867, all four side by side
  (`debug_artifacts/flat_pixel_a/title_*.png` are the final versions).

Scores, 1 (bad) to 5 (good):

| | a. not generic sci-fi | b. no meaning collision | c. legibility at 390 | d. pixel / Slice & Dice fit | e. distinct from encounters | total |
|---|---|---|---|---|---|---|
| **BONE** | 5 | 4 | 5 | 5 | 4 | **23** |
| PHOSPHOR | 3 | 1 | 4 | 3 | 5 | 16 |
| CYAN | 1 | 1 | 4 | 2 | 5 | 13 |
| AMBER | 2 | 1 | 4 | 3 | 1 | 11 |

Why:

- **a.** Cyan on navy and amber on black are the stock "AI sci-fi" palettes.
  Phosphor green is the retro-terminal trope, less generic but still a trope.
  Bone reads as paper / parchment / tabletop.
- **b.** PHOSPHOR is green: it collides with the HP bars, the heal icon and the
  ROLL button, and INVARIANTS #7 forbids any other green ("nothing else is ever
  green"). CYAN is DT_CYAN exactly: hero coding (names, borders, hero dice) and the
  `selected_card` component. AMBER is restyle A's accent, the same hex as
  legendary gold (`edb03e`), within a few degrees of the Facility encounter amber
  and the Protocol cost badges (DT_AMBER), and next to the warning rust. BONE has
  no hue meaning anywhere; its one collision is with body text (below).
- **c.** All four read at 390 px. Bone is the brightest, and the selected state
  (a bone fill with dark ink) has the most contrast of the four.
- **d.** Slice & Dice-style pixel UIs carry warm off-white chrome over dark
  fields and leave saturated color to the dice and units. Bone does exactly that
  and lets the hero cyan and enemy rust keep the color meaning.
- **e.** Encounters are amber, red, violet, magenta and ochre. Bone is low
  saturation, so it sits apart from all five; ochre (Mantle) is its nearest
  neighbour by hue but far more saturated. Amber collides with Facility and
  Mantle.

**Default: BONE** (`SYSTEM_ACCENT_DEFAULT = 0`). All four stay on F10.

**Collision reported, not fixed:** bone is close to `UI_TEXT` (`e8e6df`, warm
white). A primary button's label is now about the same color as a secondary
button's label; the primary still reads by its bone border, thick left edge and
tab. A cooler neutral `UI_TEXT` would separate them, but it is the body text color
on every restyled screen, so it was left for a ruling. No HP, heal or hero color
was changed to make any candidate work.

## Phase 3: the system color applied

Already reading SYSTEM_ACCENT through the restyle A components (Phase 1): the
title (logo reactor core and PROTOCOL line through `accent_tint_material`, the
primary button, the version underline, the backdrop window lights), Help (tabs,
section terms, bullets, scrollbar grab), Settings (toggles, sliders, SEND
FEEDBACK), Reward (CHOOSE REWARD, the selected card border and fill, the relic
name strip, CONFIRM).

New in this phase:

- **Squad select (recolor only, no layout change):** the selected tile frame is
  `PixelUI.system_selected_style()` (the COMPONENT_SELECTED geometry with a
  SYSTEM_ACCENT border), the numbered pick badges are SYSTEM_ACCENT with
  SYSTEM_ACCENT_INK numerals, a selected hero name is SYSTEM_ACCENT, and DEPLOY
  SQUAD is `style_primary_button(..., system = true)`: the same button and
  corner brackets in SYSTEM_ACCENT. Also moved (system-layer cyan, not hero
  coding): the SELECT SQUAD heading, the 3 / 3 counter, the active carousel dot.
  Unselected tile borders and names keep the hero cyan (hero coding).
- **Header ? and back** (every screen, the header is global) and the dev-only
  debug chevrons: icons drawn in SYSTEM_ACCENT. The icon art is baked cyan, so
  `PixelUI.system_icon(path)` makes a recolored copy (alpha kept, brightness
  relative to the brightest pixel), cached per color. Frames stay neutral.
- **Battle footer icons** (Nudge, Set, Item, Protocol spend): the same
  `system_icon` path through `_style_frame_icon_action_button`. The Protocol cost
  badges on those buttons were DT_AMBER; they are SYSTEM_ACCENT now, so Protocol
  reads in one color (meter and prices).
- **Protocol meter:** `cell_charged.svg` has amber baked into the art, so a
  charged cell is now the empty cell plus a SYSTEM_ACCENT fill inset 4 design px
  (the art's own inset). `cell_charged.svg` is no longer used by the meter.
- **F10 in battle** restyles in place: `PersistentHeader` emits
  `system_accent_changed`; `BattleLayout` listens and restyles the footer icons,
  the cost badges and the meter. Other screens have no listener and are reloaded.
  `battle_scene.gd` stays at 3,639 lines (watermark 3,640): the handler lives in
  `battle_layout.gd`.
- `home_screen_capture.gd` gained `--capture-help-tab=<id>` (opens Help on a tab).

Left cyan on purpose (not system layer, or screens outside this batch): hero
coding everywhere, the battle card selection (`compact_unit_card`
COMPONENT_SELECTED / SELECT_LINE), the evolution and discard-picker selected
cards, the old teal `style_primary_button` on screens not in this batch.

## Phase 4: flat tray

- **Projection off by default.** `battle_depth.gd` has `perspective_on` (false).
  Flat: `die_scale` is 1.0, `die_center` is the simulated point, the floor is the
  tray rectangle (`floor_at`, `wall_base`, `depth_for_floor_y`). In
  `dice_tray_3d.gd` the flat path draws each die exactly where it simulates, at
  its settle scale only, so every die is the same size. **F9** (debug builds,
  battle) turns the v3 path back on: depth scaling, the walled scene, the soft
  ellipse shadows. `battle_ui_capture.gd --capture-depth-perspective-output=`
  saves the same frame again with F9 on.
- **Scene** (`battle_bay_floor.gd` flat branch, still drawn in the quarter-res
  pixel-grid SubViewport): `flat_backdrop_tile.png` (staggered slabs, two tones
  apart) tinted `BATTLE_FLAT_BACKDROP_TINT` over `BATTLE_FLAT_BACKDROP` behind the
  whole board; the floor is the tray rectangle snapped to the art grid, tiled with
  the operation's `flat_floor_texture` times its `flat_floor_tint`; the rim is two
  art px just outside the tray (a dark seam outside, one art px of the ENCOUNTER
  accent inside); the reticle decal sits flat at the tray centre, one texel per
  art px, ENCOUNTER-tinted at `BATTLE_FLAT_DECAL_ALPHA` 0.16, under the dice. No
  side walls, window slots, vignette or rust streak in the flat scene (they stay
  in the F9 path).
- **Data** (`battle-tray-scenes.json`): new `flat_floor_texture` and
  `flat_floor_tint` per operation. Facility: deck plates
  (`flat_floor_plates.png`, `BATTLE_FLAT_FLOOR_FACILITY`). **Hive filled:** resin
  cells (`flat_floor_hive.png`, `BATTLE_FLAT_FLOOR_HIVE`, a dark maroon), red
  rim, red decal. Veil, Signal, Mantle: no floor texture yet, plain
  `BATTLE_FLAT_FLOOR`, with their accent on the rim and decal.
- **Art:** `scripts/assets/make_flat_pixel_art.py` writes the three PLACEHOLDER
  textures as light gray masks (the color lives in the tint tokens). Imported with
  4.6.2 (`--headless --import`); no other `.import` file changed.
- **Hard drop shadows** (`dice_tray_3d.gd _update_drop_shadow`): each die gets a
  `DropShadow` mesh, the die's own d20 silhouette flattened onto the floor,
  unshaded, solid `BATTLE_FLAT_SHADOW`, offset down-right, no blur. It renders in
  the dice viewport, so it shares the dice pixel grid (Phase 5). It is a
  top-level child of the die (freed with it, ignores the spin) with no collision.
  A die in the air throws it further (+6 design px per world unit of height). The
  soft ellipses only draw with F9 on.
  - **Offset: 12 design px (3 art px), not the asked 1-2 design px.** At 390 px
    wide a design px is 0.36 screen px, so 1-2 design px cannot show. 2 art px
    (8 design px) was tried first: at 390 px it merged with the die's own dark
    edge lines and read as no shadow. 3 art px reads as a hard shadow
    (`DROP_SHADOW_PX`, one constant).
- **Header:** the rule under the title is drawn in the ENCOUNTER accent
  (`_count_tint`), like the battle count. `BattleLayout` reads the accent through
  `encounter_accent`.
- **Unchanged:** tray bounds, walls, bodies, throws, hops, slots, snaps; pips stay
  transparent with their pixel outline (the v3 tag field). Dice stay inside the
  floor: the floor is the tray rectangle, whose edges are the physics walls, and
  flat dice are drawn where they simulate.

## Phase 5: pixelated dice

- **Reduced-resolution render.** The dice SubViewport's container now stretches
  (`stretch = true`, `stretch_shrink = render_shrink`, NEAREST), so the 3D dice
  (and their drop shadows) render at 1 / render_shrink of the tray and are shown
  back at full size on a hard pixel grid. `DiceTray3D.DICE_RENDER_SHRINK` holds
  the choice; `--dice-render-shrink=N` overrides it for captures.
- **Coordinates.** The camera now speaks reduced viewport pixels, so every camera
  point goes through `_unproject` (x `_view_scale()`, tray px per viewport px on
  each axis) and the slot anchors through `/ _view_scale()` on the way in. Tags,
  hit areas (`get_die_screen_position` / `_bounds` / `_projected_diameter`),
  result slots and the projection all keep speaking tray pixels, so touch targets
  stay on the drawn dice. The container is resized synchronously in
  `_sync_viewport_size` so the viewport is never a frame stale.
- **Physics untouched by the render scale:** `_update_world_bounds` now reads the
  tray size in whole px (exactly the value the full-resolution viewport used to
  have) instead of the viewport size, so walls and bounces are identical at any
  render scale. Possible visual-only drift: the camera's horizontal extent comes
  from the reduced viewport's aspect, which can differ from the tray's by under
  one dice pixel.
- **Options tried** (390x867 captures, `debug_artifacts/flat_pixel_a/dice_scales.png`;
  each capture rolled its own dice):

  | render | dice px per design px | top numeral | side-face numerals |
  |---|---|---|---|
  | 1/1 (old) | 1 | clear | readable |
  | 1/2 | 1/2 | clear | readable |
  | **1/3** | 1/3 | clear | **readable** (the lowest where they still are) |
  | 1/4 | 1/4 | clear | broken into noise on most faces |
  | 1/6 | 1/6 | blocky but legible | noise |

  **Chosen: 1/3.** It is the lowest scale that keeps every face numeral readable
  at 390 px. Trade-off reported: the scene's art grid is 4 design px, so a dice
  pixel (3 design px) is slightly finer than a scene pixel; 1/4 would match the
  scene grid exactly but loses the side-face numerals.
- **Quantized shading: yes, light.** `DICE_FLAT_TONES` turns specular off on the
  body, face panels and bevels, so each face (one flat normal) lights to one flat
  tone instead of carrying a highlight gradient that dithers at reduced
  resolution. Diffuse lighting, emission, colors and the edge lines are as before.
  Compared side by side at 1/3: slightly cleaner faces, numerals unchanged.
- **Behaviour unchanged by construction:** nothing in physics, face printing,
  landing, the upright snap, Freeze, Set, hops or recorded throws reads the render
  resolution. Checked in Phase 6.

## Phase 6: verify

- **Boot / smoke:** every deliverable capture ran with no script errors (title in
  all four candidates, squad select, Help › Settings, reward, three battle
  captures and the tumble), plus headless loads of MainMenu, UnitSelect and
  BattleScene.
- **`dice face` gate at 390x867** (`dice_face_gate.gd -- --size=390x867`, once):
  **PASS**, 0 failures on all twelve criteria: (a) 10,207, (b) 93,919,
  (c) 94,394, (d) 197, (e) 8, (f) 1,604, (g) 210, (h) 12, (i) containment 94,457,
  (j) 88,783, (k) hop/tip-over hulls 1,076,024, (l) 8 checks. It ran every path:
  live throws, tutorial recorded rounds 1-2 plus a free round, hero rerolls (40 +
  60-on-six-dice stress), enemy item rerolls, Set, Nudge, reprint, hijack,
  Freeze, Firewall Hack, Heretic Signal. Log:
  `debug_artifacts/flat_pixel_a/dice_face_gate_390.log`.
- **20 throws + 20 consecutive rerolls** (`debug_artifacts/flat_pixel_a/flat_probe.gd`,
  scratch probe adapted from the v2 depth probe; 390x867 window, battle-sized
  tray, every drawn frame): **PASS, 0 failures** (1,452 throw frames, 1,095 hop
  frames). Every die's drawn hull stayed inside the tray / floor (closest
  approach 4.5 px inside); no die or drop shadow disappeared for a frame (no
  flash); no face label changed while a die moved; every die ended flat with its
  numeral upright and the landed face was the roll; no other die moved during a
  hop; every die drawn at its settle scale only (0.95 at rest, 1.0 moving: no
  depth scaling); the dice viewport was 344x312 for the 1032x938 tray (1/3);
  F6 / F7 / F9 each toggle and toggle back. Log: `flat_probe.log`.
- **Fixed during verification:** the synchronous container resize in Phase 5
  warned ("non-equal opposite anchors ... overridden after _ready()") because the
  container was anchored full-rect. It now has top-left anchors and is sized
  explicitly by `_sync_viewport_size` (called on every tray resize). No warning in
  later runs.
- **Found, not fixed:** `battle_ui_capture.gd --capture-mid-roll-ms` segfaults
  at exit, after it has saved the PNG, when it quits with dice in the air. It
  happens with the drop shadows disabled and at full render resolution
  (`--dice-render-shrink=1`) too, and a settled capture exits cleanly, so it is
  not caused by the shadows or the render scale. Not checked against v3.
- Not run, as asked: `verify_gate.py`, any build or itch package.
  `component_contract.py` PASS; `battle_scene.gd` 3,639 lines (watermark 3,640).
  The growth hook warns that `protocol_actions.gd` is 1,231 lines against a
  971 high-water mark: it was already 1,223 before this task (+8 here: the cost
  badge color and its F10 refresh). Warning only.

## Final report

**Deliverables** (390 px wide, `debug_artifacts/flat_pixel_a/`, gitignored like
every capture folder): `title_bone.png`, `title_phosphor.png`, `title_cyan.png`,
`title_amber.png`; `battle_facility_flat.png`, `battle_hive_flat.png`,
`battle_facility_perspective.png` (the same frame with F9), `battle_tumble_flat.png`
(380 ms into a throw); `reward.png`, `help_settings.png`, `squad_select.png` (BONE);
`dice_scales.png` (1/1, 1/2, 1/3, 1/4, 1/6, each its own roll).

**Winning system color: BONE** (`e6dec8`), 23 / 25: not generic 5, no meaning
collision 4, legibility 5, pixel / Slice & Dice fit 5, distinct from encounters
4. Phosphor 16, Cyan 13, Amber 11. All four stay on F10.

**Color collisions found:**

- PHOSPHOR is green: HP bars, heal icon, ROLL button, and INVARIANTS #7.
- CYAN is DT_CYAN: hero coding and the `selected_card` component.
- AMBER is the legendary gold hex (`edb03e`), next to the Facility encounter
  amber, the Mantle ochre, the old Protocol amber and the warning rust.
- BONE sits close to `UI_TEXT`, so primary and secondary button labels are about
  the same color (the primary still reads by its border and tab). On Settings,
  ON (bone outline and text) against OFF (gray) has less contrast than it had in
  amber.
- Encounter colors against unchanged meanings: Hive red against enemy coding
  (rust / red) and the warning rust; Veil violet against rare / epic purple and
  the debuff icon purple; Signal magenta against Veil violet (both purple-family);
  Mantle ochre against Facility amber.

**Dice render scale chosen: 1/3** (the lowest that keeps side-face numerals
readable at 390 px; 1/4 matches the scene's 4 px art grid but breaks them).
Flat face tones on (no specular).

**Gate and reroll results:** dice face gate at 390x867 PASS (0 failures); 20
throws + 20 consecutive rerolls PASS (0 failures). Details above.

**Could not do / deviations:**

- Drop shadow offset is 12 design px (3 art px), not 1-2 design px: below 3 art
  px it cannot be seen at 390 px (see Phase 4).
- The Hive capture shows the END TURN prompt over the tray: that is the game's
  state in that battle, not something this task added.
- Veil, Signal and Mantle have no flat floor texture yet (plain floor, their
  accent on rim and decal).
- F9 and F10 are keyboard only (debug builds); there is no touch path.
- The mid-roll capture's exit segfault (above) is reported, not fixed.

**Screens still on old styling:** Route Fork, Intercept, Evolution, Unlock, Run
End; the battle screen's cards (including the cyan battle selection), loadout
menu, inspect popups, keyword primers, training prompts and tutorial, operation
briefing overlay frame, state code panel, discard picker; the squad-select
encounter carousel frame and arrows (cyan hero chrome) and the old teal primary
buttons on screens outside this batch; Help's non-settings page bodies.

---

# Flat pixel polish B (2026-10-16)

Branch `proto/flat-pixel-b`, cut from `proto/flat-pixel-a` at `d0093ea` (nothing
was outstanding). Rendering and UI only. TRUTH.md and DECISIONS_RESOLVED.md are
not edited (unchanged since `40946c3`); this section is the record. Godot 4.6.2
(`config/features` is still `"4.6", "Mobile"`; no 4.7 changes seen).
`battle_block.svg.import` stays out of every commit.

## B Phase 1: color ownership

Principle: the player owns the bottom, the enemy owns the top, the tray is
shared ground; the world changes per operation, the player never does.

**Tokens** (`pixel_ui.gd`, "Color roles"):

- **CHROME** = flat-pixel-a's system color, renamed: `SYSTEM_ACCENT*` became
  `CHROME`, `CHROME_DIM`, `CHROME_INK`; `set_system_accent` became `set_chrome`;
  the header signal is `chrome_changed`. Bone by default, F10 still cycles the
  four candidates (`--system-accent=<id>` still works for captures).
- **PLAYER_ACCENT** `2a6ae6` (cobalt matched to the hero die: base `1f6be0`, lit
  edge about `2070f0`), **PLAYER_ACCENT_LIGHT** `9cbcff` (text and icons on
  dark), **PLAYER_ACCENT_DIM** `1c3f82` (resting friendly frames),
  **PLAYER_ACCENT_INK** `060d1c` (dark text on a player fill).
- **ENCOUNTER_ACCENT**: a static var holding the current battle's encounter
  color, set by `BattleLayout.setup` from the data (`encounter_accent`).
- `PixelUI.unit_card_palette(hero)` derives each side's card palette from those
  tokens (rest / targetable / selected frame, title fill, name text).
- `system_icon(path)` became `tinted_icon(path, color)`; `style_dt_icon_button`
  takes an `icon_tint` color instead of a flag.

**Recolored to PLAYER:**

1. Friendly battle cards: frame `PLAYER_ACCENT_DIM` at rest, `PLAYER_ACCENT` when
   targetable, title plate `PLAYER_ACCENT_DIM` darkened, name `PLAYER_ACCENT_LIGHT`
   (was BATTLE_HERO_LINE / HEADER / TEXT, steel and pale cyan).
2. Selected card, either side: `PLAYER_ACCENT_LIGHT` (was DT_CYAN). The frame
   now always reads the side palette, so the selected frame no longer falls back
   to the cyan component border.
3. The "needs a target" name highlight: PLAYER_ACCENT_LIGHT toward white (was
   cyan toward white). Cast-order badge number: PLAYER_ACCENT_LIGHT (was
   DT_HERO_NAME), its frame PLAYER_ACCENT_DIM.
4. Squad select: picked tile frame `PLAYER_ACCENT`, pick badges `PLAYER_ACCENT`
   with `PLAYER_ACCENT_INK` numerals, picked names `PLAYER_ACCENT_LIGHT`, the
   active carousel dot, DEPLOY SQUAD.
5. Footer action buttons (Nudge, Set, Item, Protocol spend): icons
   `PLAYER_ACCENT_LIGHT`; their cost numbers `PLAYER_ACCENT_LIGHT`.
6. Protocol meter charged cells: `PLAYER_ACCENT`.
7. END TURN: the player primary (it was the amber variant, so it showed amber in
   every operation, Hive included). ROLL: same player primary (was teal). The
   Set-die confirm (`protocol_actions` confirm) lost its amber flag too.
8. Every `style_primary_button` caller is player-colored now (border
   PLAYER_ACCENT, text PLAYER_ACCENT_LIGHT, pressed ink PLAYER_ACCENT_INK); the
   `amber` flag survives only for route fork's flagged card. This also reaches
   old screens (evolution, route fork, run end, unlock, state code panel,
   training prompt, battle stay / cancel buttons).
9. Restyle components: the notched primary (title, reward CONFIRM, help), active
   help tabs (PLAYER fill, PLAYER_ACCENT_INK text), settings toggles ON
   (PLAYER outline, light text), slider fill (PLAYER) and thumb (LIGHT), the
   selected reward card (PLAYER border over a faint PLAYER fill) and its art
   frame (PLAYER_DIM).
10. The briefing's ENGAGE button (was DT_CYAN). The boss-relic "YOUR HEROES HOLD
    THIS ROUND" banner (was cyan bright).

**Recolored to ENCOUNTER:** enemy battle cards: frame `ENCOUNTER_ACCENT`
darkened at rest, full accent when targetable, title plate darkened, name
lightened (was BATTLE_ENEMY_LINE / HEADER / TEXT rust). The death debris shards
take each side's resting frame color. The header battle count and rule were
already the encounter accent. Boss title plates keep the boss orange.

**Recolored to CHROME (encounter or cyan removed):**

- Squad select: the site line, the THREATS label and the LV label (were the
  encounter accent / DT_AMBER; the brief reserves the encounter color for the
  header and enemy cards, so operation copy now carries CHROME through
  `operation_copy()`), the encounter banner frame and the carousel arrows (were
  hero cyan), the lock icons, unpicked hero names, resting tile frames
  (UI_CARD_LINE). Choice: a resting tile in PLAYER_DIM looked almost like a pick,
  so unpicked heroes read neutral and picks stand out.
- The briefing SITE value.
- Header ? / back / debug icons (already CHROME), the "BATTLE RESUMED" callout
  (was cyan), the generic status cue (was cyan; it fires on enemy summons, so a
  player color would lie), the DEV TOOLS UNLOCKED notice.

**Unchanged:** dice colors, HP, heal / effect icons, rarity, warning, the enemy
rust on squad select's boss thumbnail and threat pips (enemy coding), the boss
plate.

**Collision reported:** PLAYER_ACCENT_LIGHT sits near the shield icon blue
(`COLOR_SHIELD` `57a8ff`) and the uncommon steel blue; none were changed.

`battle_scene.gd` stays at 3,639 lines (watermark 3,640). `component_contract`
PASS. MainMenu, BattleScene, UnitSelect, RewardScreen load headless clean.

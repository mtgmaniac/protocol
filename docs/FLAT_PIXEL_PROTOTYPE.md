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

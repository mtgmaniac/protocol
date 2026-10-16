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

# Overload Protocol AI Agent Reference

This file is the current handoff guide for AI agents working on the Godot
version of Overload Protocol. It describes the live project structure, the real
runtime owners, and the traps that have already cost time so future work can
start with the right assumptions.

Last refreshed from local source on 2026-07-01.

**Also read:** [BASELINE.md](BASELINE.md) (verify runners + tag), [AGENTS.md](../AGENTS.md) (branch split).

## 1. Project Basics

- Engine: Godot 4.6.2
- Language: GDScript
- Main scene: [MainMenu.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/MainMenu.tscn) (splash; continues into UnitSelect)
- Orientation: portrait
- Internal authored viewport: `1080x2400`
- Desktop preview window: `450x1000`
- Stretch mode: `canvas_items`
- Rendering method: mobile
- 3D physics engine: Jolt

Important workspace rules:

- Live game code is under `scripts/`, `scenes/`, `assets/`, and `data/raw/`
- **`legacy-angular/` is assets-only (portraits/UI rasters). The Angular app was removed — never edit or restore it.**
- Headless balance sims live in `scripts/sim/` + `scripts/debug/balance_sim_*.ts`
- See root **`AGENTS.md`** for the hard rule assistants must follow
- `debug_artifacts/` contains generated screenshots and scratch output
- `docs/` is the active local documentation set

## 2. Global Autoloads

These are live global singletons:

- `GameState`
  - [GameState.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/GameState.gd)
- `DataManager`
  - [DataManager.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/DataManager.gd)
- `SceneManager`
  - [SceneManager.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/SceneManager.gd)
- `AudioManager`
  - [AudioManager.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/AudioManager.gd)
- `DebugBattleLauncher`
  - [DebugBattleLauncher.gd](C:/Users/Kev/Documents/protocol/scripts/debug/DebugBattleLauncher.gd)

Important note:

- The old `Theme` autoload (`Theme.gd`) has been **removed**. Visual constants now live
  in `PixelUI` ([pixel_ui.gd](C:/Users/Kev/Documents/protocol/scripts/ui/pixel_ui.gd)),
  the single source of truth.
- `PixelUI` is a `class_name`, so reference it directly (`PixelUI.DT_CYAN`) — no preload needed.

## 3. Current Run Loop

Current high-level loop:

1. player enters [UnitSelect.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/UnitSelect.tscn) (script: [home_screen.gd](C:/Users/Kev/Documents/protocol/scripts/ui/home_screen.gd))
2. player chooses up to 3 heroes
3. `GameState.start_run(unit_ids, operation_id)` stores squad and operation
4. `SceneManager.go_to_battle()` loads [BattleScene.tscn](C:/Users/Kev/Documents/protocol/scenes/battle/BattleScene.tscn)
5. battle plays until win/loss
6. on victory:
   - reward selection if not run-complete
   - evolution selection if XP threshold is hit
   - next battle if no pending evolution/reward
7. on final victory or loss:
   - run end / reset flow

Important correction versus older docs:

- current battle flow is 3-unit, not 4-unit
- the project is portrait, not landscape

## 4. Active Scene Map

### Primary UI scenes

- Home / unit select:
  - [UnitSelect.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/UnitSelect.tscn)
- Main menu:
  - [MainMenu.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/MainMenu.tscn)
- Battle:
  - [BattleScene.tscn](C:/Users/Kev/Documents/protocol/scenes/battle/BattleScene.tscn)
- Reward screen:
  - [RewardScreen.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/RewardScreen.tscn)
- Evolution screen:
  - [EvolutionScreen.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/EvolutionScreen.tscn)

### Shared battle-support scenes

- [AbilityReadout.tscn](C:/Users/Kev/Documents/protocol/scenes/shared/AbilityReadout.tscn)

`BattleHeader.tscn` and `UnitDetailPanel.tscn` are deleted — the global
`PersistentHeader` autoload owns the header on every screen, and the unified
long-press `InspectPopup` replaced the detail panel.

## 5. Current Battle UI Architecture

The battle screen is driven primarily by:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)
- [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)
- [combat_manager.gd](C:/Users/Kev/Documents/protocol/scripts/battle/combat_manager.gd)
- [dice_manager.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_manager.gd)

### Important truth

The live battle card is **not** the old `UnitCard.tscn` (removed — referenced a deleted script).

The active battle card owner is:

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Battle creates cards directly with:

- `CompactUnitCard.new()`

in:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)

## 6. Current Battle Visual Language

The battle UI is in a readability-first transition phase.

Current direction:

- flatter, lower-detail card styling
- thin borders
- fewer ornate frame details
- starfield background instead of old grid
- portraits remain dominant, but must not consume the whole card
- HP and status bands must be readable on a phone

Theme source:

- [pixel_ui.gd](C:/Users/Kev/Documents/protocol/scripts/ui/pixel_ui.gd) — `PixelUI`, the
  single source of truth (Direction-05 "Dithered Terminal" `DT_*` palette).
- [assets/ui/theme_overload.tres](C:/Users/Kev/Documents/protocol/assets/ui/theme_overload.tres)
  — project default `Theme` that mirrors `PixelUI` for default-inheritance only.

Current core colors (canonical `PixelUI` tokens; old `UiTheme` names → new in parentheses):

- `PixelUI.DT_FIELD_BG` (was `VOID`) — base background
- `PixelUI.DT_HERO_BG` (was `PANEL`) — hero card surface
- `PixelUI.DT_TRAY_BG` (was `RAISED`) — dice tray surface
- `PixelUI.DT_CYAN` (was `CYAN`) — hero accent
- `PixelUI.DT_RUST` (was `RED`) — enemy accent
- `PixelUI.DT_AMBER` (was `PROTOCOL_GREEN`) — protocol bar is **amber** now, not green
- `PixelUI.GOLD_ACCENT` (was `GOLD`) — callouts
- `PixelUI.DT_HP_GREEN` (was `HP_GREEN`) — HP fill (green reserved for HP + ROLL only)
- `PixelUI.COLOR_DAMAGE` (was `DMG_RED`) — incoming-damage forecast
- `PixelUI.TEXT_MUTED` (was `MUTED`) — secondary text
- `PixelUI.DT_HERO_BORDER` (was `BORDER_PLAYER`) — hero card border
- `PixelUI.DT_ENEMY_BORDER` (was `BORDER_ENEMY`) — enemy card border

## 7. Card Structure and Current Constraints

The live `CompactUnitCard` currently has these major bands:

1. Name row
2. Portrait frame
3. HP region
4. Optional action pip region
5. Status region

Important active lesson:

- the card’s VBox structure can be correct while the proportions still look
  wrong at `450x1000`
- preview scale is about `0.4167x`, so logical sizes that look reasonable in
  code can still become too small on screen

When changing card layout:

- check the screenshot, not just the constants
- compile success does not prove visual success

## Effect pips (abilities, gear, relics, items)

**Single source of truth:** `scripts/ui/effect_pip.gd` (`EffectPip`). See **`docs/EFFECT_PIP_GUIDE.md`**.

All pip UI must call `EffectPip.build_group()` with the correct profile (`PROFILE_READOUT`, `PROFILE_CARD`, `PROFILE_REWARD`, etc.). Do not add local icon maps or custom value formatting in scene scripts.

## 8. Portrait Sizing Trap

Portrait sizing is currently handled in:

- `_update_portrait_size()`
- `_update_portrait_rect_transform()`

Known issue we diagnosed:

- `_locked_layout_size.y` can be much larger than the actual rendered card
  height on the preview window
- using only `_locked_layout_size.y` to size the portrait can let the portrait
  dominate the card visually

When debugging portrait/card proportions:

- inspect the real screenshot
- prefer the actual resolved card size when available
- do not assume a base-resolution logical value maps cleanly to the preview

## 8b. Portrait Pipeline Rules (July 2026)

Two portrait art styles coexist and are auto-classified at load:

- **cutout** — transparent background, subject fills the canvas (heroes, older
  facility/hive enemies)
- **full-bleed** — opaque scenic background, subject centred (veil / menagerie
  / void circlet)

`DataManager._crop_to_content()` tags every portrait texture with a
`full_bleed` meta (sampled opaque coverage > 90%). ALL portrait framing must go
through **`PixelUI.cover_fit_portrait()`** — full-bleed art centres both axes,
cutout art top-anchors (heads never crop). Never add per-unit pixel offsets.

White fringe on cutout art (semi-transparent near-white edge pixels baked by a
white-background cutout) is fixed by the pipeline tool — rerun it whenever new
cutout art lands:

```bash
python scripts/assets/defringe_alpha_edges.py   # add --dry-run to audit only
```

Enemy portrait files live in `assets/portraits/enemies/` named by slugified
display name (the DataManager fallback loader). Void Circlet art was migrated
from `legacy-angular/public/enemies/` in July 2026 via centre-square crops.

## 9. HP Region Rules

Current HP region implementation lives in:

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Important implementation note:

- `HPBack` height and `HPFill` height are separate
- increasing only the outer HP region height may not change the visible bar if
  the fill remains thin

Current readability rule:

- the visible HP band must be judged from the screenshot
- HP label contrast on top of the bar matters as much as raw font size

## 9b. HP Preview Contract (July 2026)

Previews are **net-outcome projections**, not sequential event displays. The
aggregation lives in `battle_card_view.compute_preview_for_unit()`; the
projection/paint lives in `compact_unit_card._layout_preview_overlays()`:

- projects the round in true resolution order: hero heals/shields → enemy
  damage → burn tick (damage and burn both drain shields before HP)
- zones: red = net loss (purple lead slice = unshielded burn), mint = net
  gain, blue = loss the shield prevents (counterfactual); lethal = whole fill
- label shows `cur → final / max` while a net-changing preview is active
- the burn tick amount is single-sourced from
  `combat_manager.get_expected_burn_tick()` — never re-derive it in UI code
- the resolution-feedback chip (`_hp_chip` / `forecast_hp`) is hidden while a
  preview is active; the two systems must not both paint

## 10. Ability Readout Rules

Ability readouts are separate from the card and owned by:

- [ability_readout.gd](C:/Users/Kev/Documents/protocol/scripts/ui/ability_readout.gd)

Current behavior:

- pips are hidden by default
- they reveal together after dice resolution
- no gold box around the whole row
- no per-pip capsule backing
- no gold underline
- readouts sit closer to the dice than to the cards

## 11. Dice System

3D dice are owned by:

- [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)

Physics model (July 2026 overhaul — see `docs/GDD.md` §6 for the design):

- hand-toss throw: one shared per-side "hand" origin, low flat launch
  (`THROW_HAND_HEIGHT_*`), forward tumble around the travel-perpendicular axis
- physical walls are rebuilt from the live camera/viewport
  (`_update_world_bounds`) so their inner faces sit exactly at the visible
  combat-zone edges, leaning inward `WALL_LEAN_RADIANS` (sloped tray rim, no
  corner wedging); there is NO screen-bounds teleport code — do not re-add it
- zero damping while rolling; energy loss comes from the two PhysicsMaterials
  (die vs felt tray) plus a late "felt grab" ramp
- frozen dice are immovable static bodies at full collision size; new dice
  spawn-sidestep them (`_adjust_spawn_for_occupants`)
- result presentation scales the die's `Visuals` container, never the
  RigidBody3D (body scale would also scale the collision shape)
- all dice wait until the final die settles, then snap to result rows; the
  landed face shows the effective roll (raw kept in metas for crit/overload)
- contact shadows and roll SFX were removed on user direction — do not re-add

Feel tuning knobs: `THROW_*`, `DIE_GRAVITY_SCALE`, `_make_die_physics_material`,
`_make_tray_physics_material`.

**Regression gate for ANY dice change** (must stay at 0/0/0):

```powershell
& $GODOT --headless --path . 'res://scenes/debug/DiceTrayPhysicsProbe.tscn'
# [PROBE] penetration_events=0 flyover_events=0 ... tilted_rests=0
```

A screenshot cannot verify motion quality — feel needs a human playtest.

## 12. Current Battle Header/Footer Model

The header is the global `PersistentHeader` autoload
([PersistentHeader.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/PersistentHeader.gd) +
[PersistentHeader.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/PersistentHeader.tscn)) —
a CanvasLayer alive on every screen; scenes bind their button handlers via
`bind_battle_actions()` (see root `CLAUDE.md`).

Current header rules:

- same placement across battle, reward, and evolution
- operation name and battle counter on the same line
- right-side action buttons stay consistent

Footer rules:

- protocol display on the left
- action buttons on the right
- protocol capped at `10`; battles start at `0`, gain `+1` at end of each turn
- footer actions: Reroll (2), Nudge (1, +3 roll), Set-a-die (3), Item (1 flat)

## 13. Data Source Files

Primary raw data lives in:

- [heroes.data.json](C:/Users/Kev/Documents/protocol/data/raw/heroes.data.json)
- [enemies.data.json](C:/Users/Kev/Documents/protocol/data/raw/enemies.data.json)
- [items.data.json](C:/Users/Kev/Documents/protocol/data/raw/items.data.json)
- [gear.data.json](C:/Users/Kev/Documents/protocol/data/raw/gear.data.json)
- [relics.data.json](C:/Users/Kev/Documents/protocol/data/raw/relics.data.json)

Loaded resources include:

- `UnitData`
- `EnemyData`
- `ItemData`
- `OperationData`

## 14. Current Debug Workflow

Battle capture script:

- [battle_ui_capture.gd](C:/Users/Kev/Documents/protocol/scripts/debug/battle_ui_capture.gd)

Primary screenshot output:

- [latest.png](C:/Users/Kev/Documents/protocol/debug_artifacts/battle_ui/latest.png)

Ability audit (must load autoloads — run as a scene, **not** `--script`):

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/debug/AbilityAuditRunner.tscn'
```

Quick battle smoke test (skips unit select):

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path 'C:\Users\Kev\Documents\protocol' -- --debug-battle
```

Main-scene smoke test:

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/ui/UnitSelect.tscn' --quit-after 3
```

Full scene-flow smoke test (home → battle → reward → home → evolution → run-end):

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path 'C:\Users\Kev\Documents\protocol' --script 'res://scripts/debug/flow_smoke_test.gd'
```

Tutorial playthrough (drives all 21 coachmark steps with real actions and
asserts every spotlight resolves):

```powershell
& $GODOT --headless --path . --script 'res://scripts/debug/tutorial_smoke_test.gd'
```

Dice physics probe (regression gate for any dice change):

```powershell
& $GODOT --headless --path . 'res://scenes/debug/DiceTrayPhysicsProbe.tscn'
```

The battle smoke test also accepts `--debug-op <operation_id>` (facility,
hive, veil, voidCirclet, stellarMenagerie) to launch a specific operation.

Most useful visual verification:

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --path 'C:\Users\Kev\Documents\protocol' --script 'res://scripts/debug/battle_ui_capture.gd'
```

Verification gotcha:

- Godot `--check-only` / headless scene quit **misses parser errors in scripts
  outside the launched scene's dependency chain** (e.g. a broken legacy `.tscn`).
- Do not rely on compile checks alone. Launch the game (or the audit / debug-battle
  runners above) and watch the console for errors.

Core rule:

- do not claim an improvement unless the screenshot plainly shows it

## 15. Current Known Fragile Areas

- `CompactUnitCard` proportions and readability are still being tuned
- battle UI is cleaner than before, but not visually final
- reward and evolution screens share the battle header but still need ongoing
  visual consistency checks
- custom one-off probe scripts can trigger a Godot `user://logs` crash path on
  this machine, so prefer existing debug runners when possible

## 16. Backend vs UI (2026-06-21)

Parallel workstreams:

- **`fix/cleanup`** — backend/data/combat (`combat_manager.gd`, `data/raw/`, sim). **No UI edits.**
- **`codex/compact-battle-ui-three-unit-pips`**, **`codex/ui-compact-card-prototype`** — UI only.

On `fix/cleanup`, avoid scenes, `compact_unit_card.gd`, `pixel_ui.gd`, and visual battle chrome unless the user overrides.

## 17. Guidance for Future Agents

- find the real runtime owner before editing
- do not assume an authored scene is the active implementation
- keep battle layout ownership in `battle_scene.gd`
- keep combat truth in `combat_manager.gd`
- keep dice logic in `dice_tray_3d.gd`
- keep card internals in `compact_unit_card.gd`
- use screenshot verification for UI claims
- use `PixelUI` (`scripts/ui/pixel_ui.gd`) for all shared visual language values — never hardcode hex

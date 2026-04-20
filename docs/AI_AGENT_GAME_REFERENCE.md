# Overload Protocol AI Agent Reference

This file is a local handoff guide for AI agents working on the Godot version of
Overload Protocol. It describes how the live game is wired, where systems live,
and the important implementation traps to avoid.

Last updated from local source on 2026-04-19.

## Project Basics

- Engine: Godot 4.6.
- Main scene: `res://scenes/ui/UnitSelect.tscn`.
- Designed viewport: portrait, 1080x2400 internal with 450x1000 window override.
- Autoloads:
  - `GameState`: run state, rewards, progression, XP, evolutions.
  - `DataManager`: loads JSON data into resources.
  - `SceneManager`: scene transitions.
- Live Godot code is under `scripts/`, `scenes/`, `data/raw/`, and `assets/`.
- `legacy-angular/` is historical/reference material. Do not treat it as live game code.
- `.ziva/` contains snapshots. Do not edit it for gameplay work.

## High-Level Game Loop

1. Player chooses up to 3 heroes on `UnitSelect`.
2. `GameState.start_run()` stores selected unit ids and operation id.
3. `SceneManager.go_to_battle()` loads `BattleScene`.
4. `BattleScene` builds runtime hero/enemy states using `DataManager` and `GameState`.
5. Each battle round:
   - Player presses Roll.
   - Dice roll in `DiceTray3D`.
   - Rolled values map to ability tiers through `DiceManager.get_ability_for_roll()`.
   - Some hero abilities require manual target selection.
   - `CombatManager.resolve_round()` applies hero and enemy abilities.
   - Battle scene plays visual feedback and updates cards.
6. Victory:
   - If final battle, `GameState.finish_run("victory")` and `RunEndScreen`.
   - Otherwise `GameState.prepare_battle_rewards()` and `RewardScreen`.
7. Reward claim:
   - Consumables go into `GameState.consumables`.
   - Gear goes into `GameState.gear_by_unit[target_unit_id]`.
   - Relics go into `GameState.relics`.
   - XP is awarded. If evolution is pending, go to `EvolutionScreen`.
   - Otherwise `GameState.advance_to_next_battle()` and return to battle.

## Core Data Files

### Heroes

File: `data/raw/heroes.data.json`

Loaded by `DataManager._load_units()` into `UnitData`.

`UnitData` fields:

- `id`
- `display_name`
- `class_name_text`
- `role`
- `picker_category`
- `picker_blurb`
- `max_hp`
- `source_key`
- `portrait`
- `dice_ranges`
- `passives`
- `evolution_paths`

Hero dice ranges are normalized by `DataManager._build_hero_dice_ranges()` into:

```gdscript
{
  "min": int,
  "max": int,
  "zone": String,
  "ability_name": String,
  "description": String,
  "raw": Dictionary
}
```

Hero raw ability keys commonly handled by `CombatManager._apply_hero_ability()`:

- `dmg`
- `heal`
- `shield`
- `shT`
- `blastAll`
- `healAll`
- `shieldAll`
- `healLowest`
- `shTgt`
- `healTgt`
- `dot`
- `dT`
- `rfm`
- `rfmT`
- `rfmTgt`
- `ignSh`
- `rfe`
- `rfT`
- `rfeAll`
- `taunt`
- `revive`
- `cloak`
- `cloakAll`
- `freezeEnemyDice`
- `freezeAllEnemyDice`
- `freezeAnyDice`

### Enemies

File: `data/raw/enemies.data.json`

Loaded by `DataManager._load_enemies()` into `EnemyData`.

`EnemyData` fields:

- `id`
- `display_name`
- `faction`
- `enemy_type`
- `ai_type`
- `max_hp`
- `damage_preview_min`
- `damage_preview_max`
- `phase_two_damage_preview_min`
- `phase_two_damage_preview_max`
- `phase_two_threshold`
- `can_summon_elite`
- `portrait`
- `dice_ranges`
- `traits`

Enemy dice ranges use fixed zones from `DataManager.ENEMY_ZONE_RANGES`:

- recharge
- strike
- surge
- crit
- overload

Enemy raw ability keys commonly handled by `CombatManager._apply_enemy_ability()`:

- `dmg`
- `dmgP2`
- `heal`
- `shield`
- `shT`
- `shieldAlly`
- `shAllyT`
- `dot`
- `dT`
- `lifestealPct`
- `wipeShields`
- `rfm`
- `rfmT`
- `erb`
- `erbT`
- `erbAll`
- `cowerT`
- `cowerAll`
- `grantRampage`
- `grantRampageAll`
- `counterspellPct`
- `curseDice`
- `enemySelfTaunt`
- `packBonus`
- `summonChance`
- `summonName`

### Items, Gear, Relics

Files:

- `data/raw/items.data.json`: consumables.
- `data/raw/gear.data.json`: gear.
- `data/raw/relics.data.json`: relics.

All load into `ItemData` through `DataManager._build_item_resource()`.

`ItemData` fields:

- `id`
- `display_name`
- `item_type`: `consumable`, `gear`, or `relic`.
- `rarity`
- `icon_key`
- `target_kind`
- `description`
- `icon`
- `effect`

Reward claiming is in `GameState.claim_reward()`.

Gear is persistent for the run and stored by unit id in:

```gdscript
GameState.gear_by_unit: Dictionary
```

Consumables are stored in:

```gdscript
GameState.consumables: Array
```

Relics are stored in:

```gdscript
GameState.relics: Array
```

## Autoload Responsibilities

### DataManager

File: `scripts/autoloads/DataManager.gd`

Responsibilities:

- Parse raw JSON.
- Build `UnitData`, `EnemyData`, `ItemData`, and `OperationData`.
- Load portraits from legacy public asset paths.
- Provide lookup helpers:
  - `get_unit(unit_id)`
  - `get_enemy(enemy_id)`
  - `get_enemy_by_display_name(enemy_name)`
  - `get_item(item_id)`
  - `get_operation(operation_id)`
  - `get_operation_order()`

Do not put run-state logic here.

### GameState

File: `scripts/autoloads/GameState.gd`

Responsibilities:

- Selected squad.
- Current battle index.
- Selected operation.
- Relics, consumables, and gear.
- Pending rewards.
- XP and evolution state.
- Run start/reset/end.

Important functions:

- `start_run(unit_ids, operation_id)`
- `advance_to_next_battle()`
- `prepare_battle_rewards()`
- `claim_reward(item_id, target_unit_id)`
- `award_battle_xp()`
- `has_pending_evolution()`
- `apply_pending_evolution(path_name)`
- `get_run_unit_data(unit_id)`

Do not put UI layout or combat-resolution code here.

### SceneManager

File: `scripts/autoloads/SceneManager.gd`

Thin wrapper around `get_tree().change_scene_to_file()`.

Known scenes:

- Unit select: `res://scenes/ui/UnitSelect.tscn`
- Battle: `res://scenes/battle/BattleScene.tscn`
- Reward: `res://scenes/ui/RewardScreen.tscn`
- Evolution: `res://scenes/ui/EvolutionScreen.tscn`
- Run end: `res://scenes/ui/RunEndScreen.tscn`

## Battle System

### BattleScene

File: `scripts/battle/battle_scene.gd`

`BattleScene` is the large UI/controller script. It owns:

- battle UI layout
- compact cards
- dice tray
- roll button phase changes
- target selection
- HUD tooltips
- help overlay
- item/relic HUD
- unit detail panel
- dice tooltip overlays
- action feedback visuals

Key state variables:

- `dice_manager`
- `combat_manager`
- `protocol_points`
- `hero_card_views`
- `enemy_card_views`
- `hero_rolls`
- `enemy_rolls`
- `turn_phase`
- `active_targeting_hero_id`
- `legal_target_ids`
- `pending_manual_target_ids`
- `_pending_item`
- `_unit_detail_panel`
- `_is_resolving_turn`

Turn phases:

- `await_roll`
- `targeting`
- `ready_to_end`
- `reroll_pick`
- `nudge_pick`
- `item_pick_ally`
- `item_pick_dead`
- `item_pick_enemy`

Important battle flow functions:

- `_ready()`: setup battle, UI, cards, dice tray, item panel.
- `_on_roll_button_pressed()`: starts roll flow.
- `_begin_targeting_phase()`: evaluates rolled abilities and decides target requirements.
- `_resolve_current_turn()`: sends effective rolls to `CombatManager.resolve_round()`.
- `_refresh_all_cards()`: rebuilds UI card states from combat states.
- `_set_turn_phase(next_phase)`: central phase switch and roll/end button styling.

### CombatManager

File: `scripts/battle/combat_manager.gd`

Owns combat truth and runtime states. It should not do UI layout.

Runtime state is a dictionary created by `_create_runtime_state()` and includes health, shields,
statuses, selected targets, gear bonuses, and death state.

Important functions:

- `setup_battle(hero_units, enemy_units)`
- `setup_relics(relic_ids)`
- `setup_gear(gear_by_unit)`
- `apply_battle_start_relic_effects(battle_index)`
- `apply_battle_start_gear_effects()`
- `resolve_round(hero_rolls, enemy_rolls, dice_manager)`
- `_apply_hero_ability(hero_state, ability_entry)`
- `_apply_enemy_ability(enemy_state, ability_entry)`
- `_damage_state(state, amount, ignore_shield)`
- `_tick_end_of_round_states()`
- `apply_item_*()` functions for consumables.

Important current mechanics:

- Shield is stored both as `shield_stacks` and summarized into `state["shield"]`.
- Roll debuff stacks are stored in `rfe_stacks`.
- Roll buffs use `roll_buff`, `roll_buff_turns`, and `roll_buff_skip_next_tick`.
- Poison uses `poison`, `poison_turns`, and skip-next-tick logic.
- Cower uses `cower_turns` and `cower_skip_next_tick`.
- Freeze uses `die_freeze_turns` and `frozen_die_value`.
- Cloak is currently an 80 percent evade-next-damage mechanic, consumed on a damage attempt.
- Counter uses `counter_pct`: chance to reflect a full targeted hero attack, then clear.
- Rampage uses `rampage_charges`: next enemy damage is doubled and one charge is consumed.
- Curse uses `cursed`: next roll keeps the lower of two dice.

### DiceManager

File: `scripts/battle/dice_manager.gd`

Simple D20 roller and roll-to-ability mapper.

Important functions:

- `roll_d20()`
- `roll_all(units)`
- `get_ability_for_roll(unit_data, roll)`

`get_ability_for_roll()` clamps to 1-20 and returns the first `dice_ranges` entry where
`min <= roll <= max`.

### DiceTray3D

File: `scripts/battle/dice_tray_3d.gd`

Owns the 3D dice physics and result presentation. It builds D20 geometry in code.

Important functions:

- `play_rolls(hero_entries, enemy_entries)`
- `get_hero_rolls()`
- `get_enemy_rolls()`
- `get_die_screen_position(side, unit_id)`
- `show_result_actions(action_entries)`
- `update_die_result_in_place(side, unit_id, result)`
- `set_die_frozen_visual(side, unit_id, is_frozen)`
- `reroll_die_to_result(side, unit_id, result)`

Dice are keyed by:

```gdscript
"%s:%s" % [side, unit_id]
```

where side is usually `hero` or `enemy`.

Do not change dice physics unless the task is specifically about dice behavior.

## Targeting Rules

Target selection is mostly coordinated in `BattleScene`.

Key functions:

- `_begin_targeting_phase()`
- `_update_phase_target_sets()`
- `_assign_enemy_target_to_hero()`
- `_assign_hero_target_to_hero()`
- `_assign_dead_hero_target_to_hero()`
- `_clear_target_assignments()`
- `_auto_assign_pending_targets()`

Important behavior:

- Single-enemy hero abilities should require enemy target selection.
- All-target abilities should not require manual selection unless mixed with a single-target component.
- Mixed all-support plus single-enemy ability should still require enemy target selection.
- Self/support abilities should target self or allies according to raw ability fields.
- Taunt can override normal target selection.

## UI Architecture

### PixelUI

File: `scripts/ui/pixel_ui.gd`

Shared colors, font loading, panel/button/label styling, and effect colors.

The project uses `m5x7.ttf` as a pixel font. `PixelUI.scale_font_size()` snaps to defined sizes.

Use `PixelUI` for battle UI styling when possible.

### Battle Header

Scene: `scenes/shared/BattleHeader.tscn`

Currently used by `RewardScreen`.

Important: `BattleScene.tscn` was restored to its original inline header after a prior shared-header pass
visually damaged battle. Do not replace the battle header again unless explicitly requested.

### CompactUnitCard

File: `scripts/ui/compact_unit_card.gd`

Used in battle instead of full `UnitCard`.

Responsibilities:

- Compact portrait card.
- HP bar and HP preview tooltip.
- Status chips and tooltips.
- Portrait long press for unit detail panel.
- Card click/target selection through `card_pressed`.

Signals:

- `card_pressed`
- `unit_detail_requested(card)`

Important functions:

- `configure(data)`
- `set_tooltip_callback(callback)`
- `show_combat_preview(effects)`
- `build_status_chip(status)`
- `_wire_portrait_detail_input()`

Only set `mouse_filter = STOP` on specific tooltip/detail targets, and add passthrough input if needed.
Do not make the whole compact card block its normal tap behavior.

### AbilityReadout

File: `scripts/ui/ability_readout.gd`

Renders the compact ability pip/result row attached to each card.

Important functions:

- `configure(result_data, side_hint)`
- `set_tooltip_callback(callback)`
- `_make_effect_group(effect)`
- `_build_effect_tooltip(effect)`

Known pip kinds include:

- `dmg`
- `shield`
- `heal`
- `dot`
- `rfe`
- `rfm`
- `pierce`
- `blast`
- `freeze`
- `cloak`
- `revive`

Tooltips should go through the battle HUD tooltip callback.

### UnitDetailPanel

Files:

- `scenes/shared/UnitDetailPanel.tscn`
- `scripts/ui/unit_detail_panel.gd`

Triggered by long press on a compact card portrait. It overlays the center/dice area.

Shows:

- portrait
- unit name/role
- equipped gear chips
- dice range entries with descriptions

Gear chips can use the battle HUD tooltip callback to show gear descriptions.

### UnitCard

Files:

- `scenes/shared/UnitCard.tscn`
- `scripts/units/unit_card.gd`

This is the older/full card with mature tooltip and details systems. It is not used for compact battle cards
when `USE_COMPACT_BATTLE_CARDS := true`.

Do not replace `CompactUnitCard` with `UnitCard` unless the user explicitly requests it.

## HUD Tooltip System

The shared battle HUD tooltip lives in `BattleScene`.

Important functions:

- `_build_hud_tooltip()`
- `_set_hud_tooltip(node, text, wrap_text=false)`
- `_show_hud_tooltip(text, anchor_node)`
- `_hide_hud_tooltip_safe()`
- `_on_hud_tooltip_gui_input()`

Behavior:

- PC uses hover.
- Mobile uses long press through a hold timer.
- Tooltip display entry point should be `_set_hud_tooltip`.
- Do not build parallel tooltip systems for battle UI.

## Items and Rewards

### RewardScreen

Files:

- `scenes/ui/RewardScreen.tscn`
- `scripts/ui/reward_screen.gd`

Purpose:

- Shows three rewards after battle.
- Lets player claim one.
- Gear requires selecting a unit.
- Consumables go to item inventory.
- Relics are run-wide and only one can be owned.

Current important warning:

The current `RewardScreen` implementation is known broken because it mixes Godot container layout with
manual sizing and positioning. Symptoms include overlapping cards and unclickable buttons.

Known bad pattern in current code:

- `_create_reward_card()` returns a plain `Control` wrapper.
- A child `PanelContainer` named `CardPanel` is manually positioned and sized.
- `_update_reward_layout()` sets `Control.size` directly for container-managed children.
- `_place_square_card_panel()` manually sets `panel.position` and `panel.size`.

Future fix direction:

- Remove the outer wrapper entirely.
- Return `PanelContainer` directly from `_create_reward_card()`.
- Do not set `Control.size` or `Control.position` inside a `VBoxContainer` layout.
- Use `custom_minimum_size.x` for width only.
- Let content define height.
- Let `ScrollContainer` handle overflow.
- Remove dynamic vertical-centering math.
- Remove dead comparison functions if not used:
  - `_refresh_gear_comparison`
  - `_create_compare_line`
  - `_create_gain_line`
  - `_build_aggregate_gear_parts`
  - `_accumulate_gear_effect`
  - `_add_total`
  - `_append_total_part`

Suggested card root:

```gdscript
func _create_reward_card(item: ItemData) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    panel.custom_minimum_size = Vector2(_get_card_width(), 0)
    _style_reward_panel(panel, item, false)
    # Add MarginContainer -> VBoxContainer -> content -> button.
    return panel
```

Do not enforce square cards unless explicitly re-requested. Vertical cards are better for readability here.

## Consumable Item Use In Battle

Battle HUD item slots are built in `BattleScene`:

- `_build_item_panel()`
- `_update_item_panel()`
- `_add_item_slot_filled(item)`
- `_on_item_button_pressed(item)`
- `_apply_item_effect(item, target_state)`

Items use `target_kind`:

- `ally`
- `allyDead`
- `enemy`
- `none`

Item effects are applied through `CombatManager.apply_item_*()` or directly for special effects.

## Gear and Relics

Gear setup:

- `BattleScene._ready()` calls `combat_manager.setup_gear(GameState.gear_by_unit)`.
- `CombatManager.setup_gear()` applies passive gear effects to hero runtime states.
- `CombatManager.apply_battle_start_gear_effects()` applies battle-start gear effects.

Examples:

- `battleStartShield`: add shield stack at battle start.
- `maxHpBonus`: increase max/current HP at battle start.
- `rollBonus`: permanent roll bonus.
- `dotDmgBonus`: increases enemy DoT ticks.
- `battleStartCloak`: starts hero cloaked.
- `healOnKill`: heals on enemy kill.
- `protocolOnBattleStart`: adds protocol at battle start.
- `surviveOnce`: survive lethal damage once.
- `firstAbilityDmgBonus`: first damaging ability gets bonus.
- `dmgReduction`: reduces incoming hero damage.

Relics:

- Loaded as `ItemData` with `item_type == "relic"`.
- Setup through `combat_manager.setup_relics(GameState.relics)`.
- Battle-start and turn-start relic logic lives in `CombatManager`.

## Data-to-UI Text Alignment

Ability descriptions come from data:

- Heroes: `heroes.data.json` ability `eff` fields.
- Enemies: `enemies.data.json` ability `eff` fields.
- Items/gear/relics: `desc`.

Runtime behavior is in code. When changing mechanics, update descriptions/tooltips in all relevant places.

Places that build visible effect text:

- `BattleScene._build_compact_action_pips()`
- `AbilityReadout._build_effect_tooltip()`
- `CompactUnitCard.STATUS_DESCRIPTIONS`
- `RewardScreen._build_effect_parts_from_effect()`
- `BattleScene._build_item_tooltip()`
- `BattleScene._build_relic_tooltip()`
- `UnitDetailPanel._populate_tiers()`

## Debug and Verification

Ability audit harness:

- `scripts/debug/ability_audit.gd`
- `scripts/debug/ability_audit_runner.gd`
- `scenes/debug/AbilityAuditRunner.tscn`

Common headless checks:

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/battle/BattleScene.tscn' --quit
```

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/ui/RewardScreen.tscn' --quit
```

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/debug/AbilityAuditRunner.tscn' --quit
```

Headless compile passing does not prove layout is visually correct. For layout work, inspect the scene in the
running game at the 450x1000 viewport.

## Coding Guidelines For Future Agents

- Prefer existing systems over parallel implementations.
- Do not edit `DataManager`, `GameState`, or `SceneManager` unless the task explicitly requires core data/run-flow changes.
- Keep combat behavior in `CombatManager`.
- Keep battle UI/controller behavior in `BattleScene`.
- Use `PixelUI` for shared colors/font/panel/button styling.
- For Godot container layouts, do not manually set `Control.size` or `Control.position` for children managed by containers.
- Use `custom_minimum_size`, `size_flags_*`, and container nodes.
- Avoid wrappers that intercept input unless their `mouse_filter` is intentional.
- When setting a child to `MOUSE_FILTER_STOP`, preserve parent tap behavior if needed with passthrough handlers.
- Do not replace `CompactUnitCard` with full `UnitCard`.
- For battle tooltips, use `_set_hud_tooltip()` as the single display entry point.
- For dice, avoid changing `DiceTray3D` physics unless necessary.
- After code changes, run the relevant headless scene compile and `git diff --check`.

## Current Dirty/Fragile Areas

- `RewardScreen` layout is currently broken and should be structurally refactored as noted above.
- `BattleScene` is large and mixes UI orchestration, targeting, feedback, item UI, and tooltip logic. Keep changes tightly scoped.
- Some reward-screen helper code is dead after the comparison UI was removed.
- Some icon strings in `reward_screen.gd` may display incorrectly in some terminal encodings, but Godot source itself may still contain valid Unicode. Verify in editor/runtime before rewriting icon maps.
- `legacy-angular/` is huge; avoid broad searches that include it unless specifically comparing legacy behavior.

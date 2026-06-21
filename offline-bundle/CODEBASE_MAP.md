# Overload Protocol — CODEBASE MAP (Offline Reference)
*What each major script does, the data contracts, and where to look when something breaks. Built by reading the actual source. Line counts are approximate as of clone.*

---

## Mental model

```
UnitSelect → GameState.start_run(ids, op) → SceneManager.go_to_battle()
   → BattleScene._ready() builds runtime states via DataManager + GameState
   → loop: Roll → DiceTray3D rolls → DiceManager.get_ability_for_roll()
           → (manual targeting) → CombatManager.resolve_round()
           → BattleScene plays feedback, updates cards
   → win: final? GameState.finish_run("victory") → RunEndScreen
          else GameState.prepare_battle_rewards() → RewardScreen
   → claim reward → award XP → evolution pending? EvolutionScreen
          else GameState.advance_to_next_battle() → BattleScene
```

Three autoloads are always available: `GameState`, `DataManager`, `SceneManager`.

---

## Autoloads (the spine — small, read these first)

### `scripts/autoloads/SceneManager.gd` (~32 lines)
Thin wrapper over `change_scene_to_file`. Constants for all 5 scene paths + `go_to_*()` helpers. **Lowest-risk file.** If you add a screen, add its path + helper here.

### `scripts/autoloads/GameState.gd` (~366 lines)
Owns ALL run-persistent state. Key vars: `selected_units`, `current_battle`, `selected_operation_id`, `relics`, `consumables`, `gear_by_unit`, `equipped_gear`, `unit_xp/levels/evolutions`, `pending_evolution_unit_id`. Constants: `SQUAD_UNIT_LIMIT=3`, `XP_PER_BATTLE=50`, `XP_TO_EVOLVE=100`, `total_battles=10`.
Key API: `start_run`, `enforce_squad_limit`, `advance_to_next_battle`, `reset_run`, `prepare_battle_rewards`, `get_pending_reward_items`, `claim_reward`, `award_battle_xp`, `has_pending_evolution`, `apply_pending_evolution`, `get_run_unit_data` (returns evolution-modified UnitData), reward RNG helpers `_roll_reward_*`.
**This is where run/economy/progression bugs live.**

### `scripts/autoloads/DataManager.gd` (~462 lines)
Loads `data/raw/*.json` → typed Resources at boot. API: `get_unit`, `get_enemy`, `get_enemy_by_display_name`, `get_item`, `get_operation`, `get_operation_order`, `get_hero_zone_ranges`, `get_logo_texture`.
Builders translate raw JSON → resources: `_build_hero_dice_ranges`, `_build_evolution_paths`, `_build_enemy_dice_ranges`, `_build_item_resource`, `_build_operation_battles`. Portraits resolved by `_load_hero_portrait` (`assets/portraits/<id>.png`) and `_load_enemy_portrait` (slugified display name → `assets/portraits/enemies/`). JSON parse failures `push_warning` (search the Godot Output panel for "Missing data file" / "Failed to parse JSON" when data won't load).
**This is where data-loading / "my JSON change didn't show up" bugs live.**

---

## Resource contracts (`scripts/resources/`)

### `unit_data.gd` — `class_name UnitData`
`id, display_name, callsign, class_name_text, role, picker_category, picker_blurb, max_hp, source_key, portrait, dice_ranges: Array[Dictionary], passives, evolution_paths`. Helper `battle_name()` → callsign else display_name.

### `enemy_data.gd` — `class_name EnemyData`
`id, display_name, callsign, faction, enemy_type, ai_type, max_hp, damage_preview_min/max, phase_two_damage_preview_min/max, phase_two_threshold, can_summon_elite, portrait, dice_ranges, traits`. Same `battle_name()` helper.

### `item_data.gd` (~13 lines) / `operation_data.gd` (~15 lines)
Thin data holders. Low risk.

---

## Battle layer (`scripts/battle/` — the heavy code)

### `dice_manager.gd` (27 lines — trivial, fully understood)
`RefCounted`, not a node. `roll_d20()`, `roll_all(units)`, and `get_ability_for_roll(unit_data, roll)` which clamps 1–20 and returns the matching `dice_ranges` entry. **The roll→ability mapping is here and it's simple — if an ability fires for the wrong roll, the bug is in the DATA ranges, not this file.**

### `combat_manager.gd` (~970 lines — the rules engine)
The authority on what abilities DO. Pipeline: `setup_battle(heroes, enemies)` → `setup_relics` / `setup_gear` → `apply_battle_start_*_effects` → `resolve_round(hero_rolls, enemy_rolls, dice_manager)`.
Effect appliers: `_apply_hero_ability` (~line 375) and `_apply_enemy_ability` (~530) — **these two functions are where every ability keyword (dmg/dot/heal/shield/rfe/cloak/freeze/revive/blastAll/ignSh…) is interpreted.** Supporting: `_damage_state` (shields + `ignSh`), `_heal_state`, `_apply_poison`, `_add_shield_stack`, `_add_rfe_stack`, `_add_roll_buff`, `_freeze_die_state`, `_revive_state`, `_on_unit_killed` (triggers Chain Reaction / heal-on-kill), targeting helpers (`_first_living_state`, `_lowest_hp_state`, etc.), `get_effective_roll` (applies rfe/roll buffs to a raw roll), and dmg multipliers `_get_hero_dmg_mult` / `_get_enemy_dmg_mult` / `_get_total_dot_bonus` (relic/gear).
**If an ability resolves wrong, start at `_apply_hero_ability` / `_apply_enemy_ability` and the specific `_*_state` helper.**

### `battle_scene.gd` (~2,635 lines — orchestrator + turn flow)
Wires turn flow, targeting, protocol actions, and delegates layout/card/feedback to helpers below.

### `battle_layout.gd` (~300 lines)
V2 band geometry, dice anchor math (`_get_combat_zone_rect`, `_layout_dice_from_combat_zone`, etc.).

### `battle_card_view.gd` (~520 lines)
Card view updates, compact status tokens, action pips, preview chips.

### `battle_feedback.gd` (~490 lines)
Event-driven game feel: hit pause, lunge, shake, floating numbers, overload celebration; wired to `AudioManager`.

### `dice_tray_3d.gd` (~1,508 lines — the 3D dice presentation)
Visual dice rolling/animation in the center rail. Presentation, not rules. **If dice LOOK wrong but combat math is right, it's here. If math is wrong, it's combat_manager.**

---

## UI layer (`scripts/ui/`)
`boot_scene.gd` (entry/splash), `main_menu.gd`, `home_screen.gd` (squad + operation picker on [UnitSelect.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/UnitSelect.tscn)), `reward_screen.gd`, `evolution_screen.gd`, `run_end_screen.gd`, `unit_detail_panel.gd`, `compact_unit_card.gd` (the live battlefield card), `ability_readout.gd`, plus background helpers (`pixel_ui.gd`, `pattern_background.gd`, `menu_panel_background.gd`, `battle_space_background.gd`).

## Debug layer (`scripts/debug/`)
`DebugBattleLauncher.gd` (launch straight into a battle with `-- --debug-battle`), `ability_audit.gd` + `ability_audit_runner.gd` (validates ability data — **run via `scenes/debug/AbilityAuditRunner.tscn`**, not `--script`, so autoloads load), `battle_ui_capture.gd` (screenshot; extends `SceneTree`), `home_screen_capture.gd`, `compact_unit_card_preview.gd`.

## Not live code (do not treat as game source)
`legacy-angular/public/` — portrait/UI rasters only (Angular app **removed**). `scripts/sim/` — headless balance sim. `.ziva/` snapshots. `addons/ziva_agent/` (the in-editor agent tool).

---

## Health check (what's solid vs. risky)

**Solid:** data layer (complete + typed), autoloads (clean APIs), dice mapping (trivial + correct), combat keyword coverage (broad). No TODO/FIXME/BUG/HACK markers anywhere in `scripts/`.

**Risk concentration:** `battle_scene.gd` is still the largest orchestration file (~2,635 lines). Layout, card view, and feedback are extracted but turn flow + targeting remain here.

**Quick triage rule:**
- Ability does the wrong thing → `combat_manager._apply_*_ability` (or the data range).
- Right number, wrong dice visual → `dice_tray_3d.gd`.
- Card/layout/spacing wrong → `battle_scene.gd` layout helpers + check against `BATTLE_UI_V2_SPEC.md` band heights.
- Data edit didn't apply → `DataManager` builder for that type; run `ability_audit`.
- Reward/XP/evolution wrong → `GameState`.

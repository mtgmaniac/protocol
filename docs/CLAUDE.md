# CLAUDE.md

> **Agents: read `docs/TRUTH.md` first, then `docs/INVARIANTS.md` immediately after** — TRUTH is the canonical reference (wins every doc conflict); INVARIANTS carries the WHY rules and what violations look like; `docs/DECISIONS_RESOLVED.md` holds closed rulings (never relitigate). Then `docs/AI_AGENT_GAME_REFERENCE.md` and `docs/BATTLE_UI_V2_SPEC.md` (runtime map + layout contract). `offline-bundle/CODEBASE_MAP.md` maps the code. Tasks follow `docs/TASK_TEMPLATE.md`; the gate is `python scripts/verify_gate.py`.

This file is the practical AI-assistant context for the current Overload
Protocol Godot project. It is intentionally grounded in the live repo, not the
original migration fantasy.

Last refreshed on 2026-07-12.

## Canonical facts (do not contradict)

| Fact | Value |
|------|--------|
| Orientation | Portrait **1080×2400** internal; **540×1200** desktop preview (exactly half, 0.5× — see `project.godot`) |
| Squad | **3** heroes chosen from **8** (`GameState.SQUAD_UNIT_LIMIT`) |
| Healer | **Splice Medic** (callsign SPLICE) — not "Systems Medic" |
| Operations | **5** fully defined in `data/raw/battle-modes.json` |
| Main scene | `res://scenes/ui/MainMenu.tscn` (splash → UnitSelect) |
| Combat authority | `scripts/battle/combat_manager.gd` |
| Phase | Well past Phase 0 — battle, reward, and evolution loops run |

**Ignore stale claims:** landscape layout, 4-unit squads, empty-shell / Phase-0 setup language. Superseded docs live in `docs/archive/` — do not use them.

## What the Project Is Right Now

Overload Protocol is a portrait-phone-first, tactical dice battler in Godot 4.

Current active target:

- `1080x2400` internal layout
- `540x1200` desktop preview (exactly half of the internal layout, 0.5× scale)
- `canvas_items` stretch
- portrait orientation

The current game is built around:

- 3-unit squad battles
- a battle scene with manual targeting, protocol, consumables, and readouts
- post-battle rewards
- unit evolution flow

It is **not** landscape anymore, and it is **not** still in an empty-shell
migration phase.

## Developer Context

- solo developer
- AI-assisted workflow
- prefers direct execution and concrete fixes
- values visual iteration through screenshots
- wants honesty about what is and is not visibly changed

Important working rule:

- do not say something improved unless the screenshot plainly shows it

## Core Runtime Owners

### Autoloads

(the live set, in `project.godot` load order)

- `GameState`
- `DataManager`
- `SceneManager`
- `AudioManager`
- `MusicManager`
- `SaveManager`
- `PersistentHeader` (`scenes/ui/PersistentHeader.tscn` — the one global header bar)
- `DebugBattleLauncher`

The old `Theme` / `UiTheme` autoload (`scripts/autoloads/Theme.gd`) is **deleted** —
do not re-add it. Visual constants live in `PixelUI` (`scripts/ui/pixel_ui.gd`).

### Primary battle systems

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)
- [combat_manager.gd](C:/Users/Kev/Documents/protocol/scripts/battle/combat_manager.gd)
- [dice_manager.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_manager.gd)
- [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)

### Active battle card

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Important correction:

- the older `UnitCard.tscn` and `scripts/units/unit_card.gd` were removed; the live
  battle card is [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

### Ability readouts

- [ability_readout.gd](C:/Users/Kev/Documents/protocol/scripts/ui/ability_readout.gd)

### Shared visual language

- [pixel_ui.gd](C:/Users/Kev/Documents/protocol/scripts/ui/pixel_ui.gd) — `PixelUI`, single
  source of truth (Direction-05 `DT_*` palette). The old `Theme` autoload is removed.
- [assets/ui/theme_overload.tres](C:/Users/Kev/Documents/protocol/assets/ui/theme_overload.tres)
  — project default `Theme` mirroring `PixelUI` for default inheritance.

## Current UI Reality

Battle UI has been heavily rebuilt and iterated already.

Current truths:

- battle cards are now flatter and less ornate than earlier passes
- starfield battle background is active
- home/unit-select uses imported texture backgrounds, not procedural ones
- reward/evolution share the battle header structure
- protocol lives on the footer left

UI work should assume:

- structure is mostly there
- proportions and readability are still under active tuning
- screenshots are the source of truth

## Known Architectural Lessons

These are worth repeating because they cost time:

1. The live owner matters more than the old scene file.
2. A compile-clean change can still be visually irrelevant.
3. The `540x1200` preview scale (0.5×) makes logical sizes shrink more than they
   look in code.
4. `HPBack` height and visible `HPFill` height are different things.
5. `_locked_layout_size` can mislead portrait sizing if used blindly.
6. Godot container structure can be correct while proportions still look wrong.

## Current Debug Workflow

Primary battle screenshot flow:

- [battle_ui_capture.gd](C:/Users/Kev/Documents/protocol/scripts/debug/battle_ui_capture.gd)

Output:

- [latest.png](C:/Users/Kev/Documents/protocol/debug_artifacts/battle_ui/latest.png)

Primary compile check:

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Kev\Documents\protocol' 'res://scenes/battle/BattleScene.tscn' --quit
```

If a change is visual, the assistant should prefer:

1. edit
2. compile-check
3. regenerate screenshot
4. describe only what the screenshot plainly shows

## Current Areas Still Worth Care

- compact battle card readability
- HP band / HP text clarity
- battle card name readability at phone scale
- final status strip balance
- dice feel and resolved presentation
- reward/evolution visual consistency

## Guidance for Future Assistants

- use `PixelUI` (`scripts/ui/pixel_ui.gd`) for new shared color language — never hardcode hex
- prefer updating active runtime owners instead of stale authored scenes
- for battle card work, start with:
  - [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)
  - [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)
- for dice/readout work, start with:
  - [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)
  - [ability_readout.gd](C:/Users/Kev/Documents/protocol/scripts/ui/ability_readout.gd)
- do not assume probe scripts are safe: ad hoc Godot probe launches have hit a
  recurring `user://logs` crash path on this machine
- prefer existing battle capture/debug runners where possible

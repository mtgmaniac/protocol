# Overload Protocol AI Context

The project reference instructions live in [docs/CLAUDE.md](docs/CLAUDE.md).

This root file exists so agents and tools that look for `CLAUDE.md` at the repo root
find a pointer to the live docs.

## Source of truth

Read these before doing anything:

- [docs/AI_AGENT_GAME_REFERENCE.md](docs/AI_AGENT_GAME_REFERENCE.md)
- [docs/BATTLE_UI_V2_SPEC.md](docs/BATTLE_UI_V2_SPEC.md)
- [offline-bundle/GROUND_TRUTH.md](offline-bundle/GROUND_TRUTH.md)
- [offline-bundle/CODEBASE_MAP.md](offline-bundle/CODEBASE_MAP.md)

When any doc conflicts, **GROUND_TRUTH.md wins**.

## Orientation

**Portrait** — internal viewport `1080×2400`, desktop preview `450×1000`. The old
landscape / Phase 0 docs are obsolete; see [docs/PHASE_0_STATUS.md](docs/PHASE_0_STATUS.md).

## Visual theming — single source of truth

- **`PixelUI` (`scripts/ui/pixel_ui.gd`) is the single source of truth for all visual
  constants** — colors, fonts, and the programmatic styling helpers. The canonical palette
  is the Direction-05 "Dithered Terminal" `DT_*` tokens. Pull colors from `PixelUI`; never
  hardcode hex and never reintroduce a second color system.
- **`assets/ui/theme_overload.tres`** is the project default `Theme` (set via
  `gui/theme/custom`). It only **mirrors** the `PixelUI` values to give new Control nodes a
  baseline (default font + per-type default Panel/Button/Label styles). Keep its colors equal
  to `PixelUI` — do not edit them independently. The battle screen's signature look (dither
  overlays, per-side card tints, dynamic dividers, bevels) stays programmatic in `PixelUI`,
  not in the `.tres`.
- The old `UiTheme` (`scripts/autoloads/Theme.gd`) is **deleted** — do not re-add it.

## Persistent header — one global header bar

- **`PersistentHeader`** is a global autoload (`scenes/ui/PersistentHeader.tscn` +
  `scripts/autoloads/PersistentHeader.gd`) — a `CanvasLayer` that is **always alive on every
  screen** and never rebuilt on scene transitions. **No individual scene contains its own
  header bar** (the old `scenes/shared/BattleHeader.tscn` is deleted).
- It overlays the top 144px (`HEADER_HEIGHT`) of every screen, so each non-battle screen
  reserves that space at the top of its layout (BattleScene already does via its 144 offset).
- Public API:
  - `update_progress(battle_number, total_battles, operation_name)` — sets the run label.
  - `set_run_active(active)` — blanks the label when no run is active (home / run-end).
  - `bind_battle_actions(help, debug, debug2, back)` / `clear_battle_actions()` — the active
    screen binds its button handlers on `_ready` and clears them on `_exit_tree`. Unbound
    buttons are inert (no-op). This is how the same buttons do different things per screen.
  - `set_debug_enabled(bool)` / `set_debug2_enabled(bool)` — toggle the debug buttons.

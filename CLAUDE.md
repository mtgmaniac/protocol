# Overload Protocol AI Context

The project reference instructions live in [docs/CLAUDE.md](docs/CLAUDE.md).

This root file exists so agents and tools that look for `CLAUDE.md` at the repo root
find a pointer to the live docs.

## Source of truth

Read these before doing anything:

- [docs/TRUTH.md](docs/TRUTH.md) — **canonical; wins every doc conflict**
- [docs/INVARIANTS.md](docs/INVARIANTS.md) — **read immediately after TRUTH.md: the WHY rules + what a violation looks like**
- [docs/DECISIONS_RESOLVED.md](docs/DECISIONS_RESOLVED.md) — closed rulings; do not relitigate, do not implement pending rulings from chat memory
- [docs/AI_AGENT_GAME_REFERENCE.md](docs/AI_AGENT_GAME_REFERENCE.md)
- [docs/BATTLE_UI_V2_SPEC.md](docs/BATTLE_UI_V2_SPEC.md)
- [offline-bundle/CODEBASE_MAP.md](offline-bundle/CODEBASE_MAP.md)

Every task follows [docs/TASK_TEMPLATE.md](docs/TASK_TEMPLATE.md). The full gate is
`python scripts/verify_gate.py` (also `/verify`). One-time per clone:
`git config core.hooksPath scripts/hooks` (baseline ceremony + growth warning).

When any doc conflicts, **docs/TRUTH.md wins** (it supersedes `offline-bundle/GROUND_TRUTH.md`).

## Orientation

**Portrait** — internal viewport `1080×2400`, desktop preview `450×1000`. The old
landscape / Phase 0 docs are archived under `docs/archive/` — do not use them.

## Band vocabulary rule

Never use the words "recharge", "strike", "surge", "crit", or "overload" to
describe or name dice bands in any player-facing copy, documentation, or design
discussion. These are internal JSON/code keys only. In player-facing text, bands
are referred to by their numeric range (e.g. "1–4", "20") or not at all. Do not
claim higher bands are strictly stronger — they are not. (Proper nouns are exempt:
the unit "Strike Unit", the title "Overload Protocol", and ability/gear/relic/enemy
names like "Overload Capacitor" or "Core Surge" stay as-is.)

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

## Portrait region — single source of truth

> **The hero portrait window is `PixelUI.HERO_PORTRAIT_REGION` = 328 × 380, aspect
> 0.863** — measured live from the battle card. Every screen that displays a hero
> portrait uses this aspect (scaled to its physical size) and routes through
> `PixelUI.cover_fit_portrait`. Do not define a portrait window anywhere else, and
> do not hardcode a second aspect.
>
> Portraits are authored to this window. A *taller* display frame cover-fits by
> height and trims the sides, which is harmless. A *shorter* frame trims the bottom
> and destroys the framing — that was the 320×486 bug: squad select and the battle
> card showed different windows onto the same art, and every framing pass authored
> against the wrong one. Never derive head positions from pixels — framing anchors
> are hand-declared in `assets/portraits/portrait_anchors.json`.

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

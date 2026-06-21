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

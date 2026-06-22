# Effect pip guide

**Source of truth:** `scripts/ui/effect_pip.gd` (`class_name EffectPip`).

All ability, gear, relic, and consumable effect pips must be built through `EffectPip` so notation, icons, fonts, colors, and spacing stay identical everywhere.

## Consumers

| Screen / widget | Profile | Builder |
|-----------------|---------|---------|
| Battle dice-tray (`ability_readout.gd`) | `PROFILE_READOUT` | `EffectPip.build_group()` |
| Compact unit cards (`compact_unit_card.gd`) | `PROFILE_CARD` | `EffectPip.build_group()` |
| Reward screen (`reward_screen.gd`) | `PROFILE_CARD` | `EffectPip.build_group()` |
| Battle card payload (`battle_card_view.gd`) | — | `EffectPip.ability_readout_payload()` |

Do **not** add local pip icon maps, emoji fallbacks, or custom value formatting in UI files. Extend `effect_pip.gd` instead.

## Profiles

| Key | Icon px | Value font | Icon↔text gap | Min width | Outline |
|-----|---------|------------|---------------|-----------|---------|
| `PROFILE_READOUT` | 56 | 80 | 4 | 90 | 3 |
| `PROFILE_CARD` | 40 | 48 | 4 | 72 | 2 |

`PROFILE_REWARD` aliases `PROFILE_CARD` (reward items match unit-card action pips).

Duration superscript uses `duration_ratio` (0.6 × value font) and `duration_outline`.

## Notation

| Scope | Display | Example |
|-------|---------|---------|
| All allies / broadcast | `)value(` | `)5(` heal all |
| Self | `(value)` | `(3)` self shield |
| Single target | plain | `5` ally heal, `T` taunt |

**Keyword letters (no icon):** `P` pierce, `C` cloak, `T` taunt, `CO` counter, `RA` rampage, `R{n}%` revive, `↓` heal-lowest.

**Freeze:** snowflake icon only; duration as superscript (no value text).

**Enemy `rfm` debuff:** plain `+N` with roll-down icon — never `)N(` (all scope is hero-only when `rfmTgt` is absent).

## Effect dictionaries

Pips use a normalized dict:

```gdscript
{ "kind": "heal", "value": "5", "duration": 0, "scope": "all" }
```

- `scope`: `""` (single), `"self"`, or `"all"`
- Legacy `"text"` keys are normalized at card boundaries; new code must use `"value"`.

## Data → pips

- **Abilities:** `EffectPip.effects_from_ability_raw(raw, side)` — pass `"hero"` or `"enemy"` for correct `rfm` scope.
- **Gear / relics / items:** `EffectPip.effects_from_passive(effect_dict, target_kind)` — add new `type` branches here when data gains effect types.

## Icons & colors

- Icons: `PixelUI.pip_texture_for_key()` (atlas in `assets/ui/icons/pip_icons.png`).
- Pip key resolution: `EffectPip.pip_key_for_effect(effect, side)`.
- Value colors: `PixelUI.effect_value_color()` via `_value_color_for_kind()` in `effect_pip.gd`.
- Font: `PixelUI.apply_pixel_font()` on all pip labels.

## Adding a new effect type

1. Add combat/data handling in `combat_manager.gd` and `data/raw/*.json`.
2. Map the passive or ability fields in `effects_from_passive()` or `effects_from_ability_raw()`.
3. If needed, extend `display_text_for_effect()` and `LETTER_ONLY_KINDS`.
4. Run `python scripts/debug/audit_gear_relic_effects.py` and visual check at 450×1000.

## Godot setup

`EffectPip` is a global `class_name`. After adding the script or on a fresh clone, run Godot once with `--import` so the class registers (`.godot/` is gitignored).

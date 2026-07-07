# Font audit — every screen, 2026-07-07

Requested by Kev: record font sizes across the game and verify phone readability.

## How to read this

Two font paths exist:
- **Scaled** — anything through `PixelUI.style_label` / `style_primary_button` /
  `scale_font_size`: authored size × **1.35**, snapped UP to the next step in
  `[20,24,28,32,36,42,48,56,64,72]`. An authored `24` actually renders at 32 design px.
- **Raw** — direct `add_theme_font_size_override` (home_screen `_make_pixel_label`,
  compact_unit_card `_apply_label`): renders exactly the authored size, on purpose
  (pixel-crisp m5x7 multiples).

**Window px** = design px × (450/1080) ≈ ×0.417 at the 450×1000 preview.
Working floor for "easily readable on a phone": **~13 window px** (32 design) for
anything that must be read, ~11 px (28 design) tolerable for badges/decoration.

## The table (smallest rendered sizes per screen)

| Screen / file | Smallest sites (authored → rendered design px → window px) | Verdict |
|---|---|---|
| Battle cards (`compact_unit_card`) | action fallback **16 → 16 → 6.7 FIXED → 32/13.3** · chip values **48 → 48 → 20 raised to 60/25** · chip names 48 → 20 · name/HP 72 → 30 | fixed this pass |
| Unit select (`home_screen`) | NEW badge **26 → 26 → 10.8 FIXED → 32/13.3** · legend 30 → 12.5 · tile names 56 → 23.3 | fixed this pass; legend borderline, decorative |
| Battle chrome (`battle_scene`, `protocol_actions`, `ability_readout`) | log detail 24 → 32 → 13.3 · set-hint 26 → 36 → 15 · readout 48 → 48 → 20 | OK |
| Inspect popup (`inspect_popup`) | META/SECTION/HINT 26 → 36 → 15 · body 34+ → 48+ → 20+ | OK |
| Help menu (`help_menu`) | SYNTAX 27 → 36 → 15 · PICKER/BLURB 28 → 42 → 17.5 | OK |
| Reward (`reward_screen`) | 28 → 42 → 17.5 up to 84 | OK |
| Route fork (`route_fork_screen`) | TYPE 28 → 42 → 17.5 · CHIP 30 → 42 · BODY 36 → 56 | OK |
| Intercept (`intercept_screen`) | TYPE 28 → 42 → 17.5 | OK |
| Run end (`run_end_screen`) | 24 → 32 → 13.3 · SECTION_HEAD 26 → 36 → 15 | OK (bottom of range) |
| Evolution (`evolution_screen`) | 30+ → 42+ → 17.5+ | OK |
| Loadout (`loadout_menu`) | SECTION 28 → 42 → 17.5 | OK |
| Main menu (`main_menu`) | 34 → 48 → 20 | OK |
| Tutorial / primers (`spotlight_layer`, `tutorial_controller`) | HINT 24 → 32 → 13.3 · SKIP 26 → 36 → 15 | OK (bottom of range) |
| Header (`PersistentHeader`) | 112 → 47 window px | OK |

## Verdicts

- **Fixed now (raw-path offenders):** battle-card action fallback 16→32; unit-select
  NEW badge 26→32; battle-card chip value numerals 48→60 (plus the width-estimate fix
  that was forcing them into an unnecessary downscale step).
- **Nothing else renders under ~13 window px.** The scaled path's ×1.35 + step-up
  means authored numbers in the 24–28 range are bigger than they look in code —
  don't "fix" them by reading the literals.
- **Bottom-of-range cohort for Kev's device pass** (13.3 window px, readable but the
  first to bump if anything still squints): battle-log detail (battle_scene:1289),
  run-end body 24s, spotlight hint 24, home-screen role legend 30-raw.

## Rule of thumb going forward

New text: authored ≥24 scaled (renders 32+) or ≥32 raw. Raw-path labels must state
why they bypass the scaler.

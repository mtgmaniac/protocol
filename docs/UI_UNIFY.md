# UI unification pass (2026-10-16)

Branch `proto/ui-unify`, cut from `proto/flat-pixel-b` at `9e65ddd` (nothing was
outstanding). Rendering and UI only: no gameplay, data, copy, flow or dice change.
TRUTH.md and DECISIONS_RESOLVED.md are not edited (unchanged since `40946c3`);
this file is the record. Godot 4.6.2 (`config/features` `"4.6", "Mobile"`; no 4.7
changes seen). `assets/fonts/battle_block.svg.import` stays out of every commit.

The direction is fixed (player bottom in cobalt, enemy top in the encounter
color, neutral tray and CHROME, constant dice colors, one notch on a screen's
primary, flat pixel art). This pass applies it everywhere.

## Phase 1: audit

The searches are a script so they can be re-run (Phase 9):
`python scripts/checks/ui_audit.py [--section fonts|colors|textures] [--summary]`.
It scans `scripts/ui`, `scripts/battle`, `scripts/autoloads`, `scripts/units`,
`scripts/resources` and the `.tscn` scenes; debug, sim and check scripts are out
of scope. `pixel_ui.gd` (the token owner) and `theme_overload.tres` (its mirror)
are excluded from the color scan.

Context found alongside:

- **Two font files:** `m5x7.ttf` (native em 16: one font pixel = 1 px at size
  16; full ASCII incl. lowercase) and `battle_block.fnt` (bitmap, native 32, 60
  glyphs: digits, CAPITALS and punctuation only, no lowercase).
- **Sizes are scaled, not on a lattice:** most sites go through
  `scale_font_size` (x1.35, then a 48 / 64 / 80 ladder, raw above 80) or
  `text_px` (floor 48, otherwise raw). So many rendered sizes (56, 72, 84, 100,
  112...) are not integer multiples of m5x7's 16 or Battle Block's 32.
- **Battle Block is used** for the battle header (112), battle card names and HP
  (72): not multiples of 32.
- **Default canvas texture filter is LINEAR** (`project.godot` sets none); text
  gets NEAREST through `PixelUI.install_text_filter`, art through per-node
  settings.

## Fonts

### Font files

- `assets/fonts/battle_block.fnt`
- `assets/fonts/m5x7.ttf`

### Font loads (by path)

- `res://assets/fonts/battle_block.fnt`: 1 (scripts/ui/pixel_ui.gd:2200)

### Font application calls (counts)

- apply_pixel_font (m5x7): **21** (pixel_ui.gd 8, battle_scene.gd 3, PersistentHeader.gd 3, ability_readout.gd 1, compact_unit_card.gd 1, effect_pip.gd 1, run_end_screen.gd 1, training_prompt.gd 1, unlock_screen.gd 1, protocol_actions.gd 1)
- get_pixel_font (m5x7): **16** (home_screen.gd 8, pixel_ui.gd 4, compact_unit_card.gd 3, dice_tray_3d.gd 1)
- style_battle_text (Battle Block): **6** (compact_unit_card.gd 2, PersistentHeader.gd 2, pixel_ui.gd 1, battle_scene.gd 1)
- add_theme_font_override: **4** (home_screen.gd 2, pixel_ui.gd 2)
- get_battle_font (Battle Block): **3** (pixel_ui.gd 2, dice_tray_3d.gd 1)

### Font size sites, per file

Total size sites: **256** in 29 files.

| file | sites | size expressions (count) |
|---|---|---|
| `scripts/ui/home_screen.gd` | 33 | `ENC_SITE_FONT` 3, `DETAIL_DESC_FONT` 3, `DETAIL_THREAT_FONT` 3, `PROGRESS_FONT` 2, `LORE_FONT` 2, `HEADER_FONT` 2, `FOCUS_CHIP_FONT` 2, `PixelUI.text_px(size_logical` 2 ... |
| `scripts/ui/help_menu.gd` | 22 | `SECTION_FONT` 7, `BODY_FONT` 4, `TAB_FONT` 3, `40` 2, `0.17` 1, `44` 1, `BODY_LONG_FONT` 1, `ROW_NAME_FONT` 1 ... |
| `scripts/ui/pixel_ui.gd` | 18 | `font_size` 9, `scale_font_size(font_size` 3, `font_px` 3, `font_size: int` 2, `text_px(font_size` 1 |
| `scripts/ui/reward_screen.gd` | 17 | `font_size` 2, `CONFIRM_FONT` 2, `42` 1, `BODY_FONT_SIZE` 1, `64` 1, `NAME_FONT_SIZE` 1, `TYPE_HEADER_FONT` 1, `VIEW_BATTLE_FONT` 1 ... |
| `scripts/ui/compact_unit_card.gd` | 15 | `PixelUI.text_px(int(48 * text_scale` 2, `int(48 * text_scale` 2, `PixelUI.text_px(int(CARD_NAME_FONT_SIZE * text_scale` 1, `int(CARD_NAME_FONT_SIZE * text_scale` 1, `PixelUI.text_px(int(CARD_HP_FONT_SIZE * text_scale` 1, `int(CARD_HP_FONT_SIZE * text_scale` 1, `PixelUI.text_px(int(CAST_BADGE_FONT_SIZE * text_scale` 1, `int(CAST_BADGE_FONT_SIZE * text_scale` 1 ... |
| `scripts/ui/evolution_screen.gd` | 15 | `BODY_FONT_SIZE` 3, `0.12` 1, `40` 1, `CARD_TITLE_FONT_SIZE` 1, `_` 1, `0.050` 1, `ABILITY_DESC_FONT_SIZE` 1, `BUTTON_FONT_SIZE` 1 ... |
| `scripts/ui/main_menu.gd` | 15 | `ABANDON_FONT` 3, `BEGIN_FONT` 2, `PROMPT_TITLE_FONT` 2, `PROMPT_BUTTON_FONT` 2, `PROMPT_SKIP_FONT` 2, `SECONDARY_FONT` 1, `FEEDBACK_FONT` 1, `24` 1 ... |
| `scripts/battle/battle_scene.gd` | 14 | `action_font` 2, `56` 1, `36` 1, `int(round(tag_size.y * DIE_TAG_FONT_RATIO` 1, `int(round(base_font * DIE_TAG_SHRINK_STEP` 1, `PixelUI.text_px(value_font` 1, `value_font` 1, `38` 1 ... |
| `scripts/ui/inspect_popup.gd` | 12 | `BODY_FONT` 3, `ROLL_FONT` 2, `BODY_LONG_FONT` 1, `HINT_FONT` 1, `SECTION_LABEL_FONT` 1, `48` 1, `SUBTITLE_FONT` 1, `ABILITY_NAME_FONT` 1 ... |
| `scripts/ui/loadout_menu.gd` | 12 | `SECTION_FONT` 4, `DISCARD_BUTTON_FONT` 2, `NAME_FONT` 2, `HEADER_FONT` 1, `DISCARD_HEADER_FONT` 1, `DISCARD_STRIP_FONT` 1, `font_size` 1 |
| `scripts/ui/route_fork_screen.gd` | 9 | `BODY_FONT` 6, `TYPE_FONT` 1, `TITLE_FONT` 1, `CARD_TITLE_FONT` 1 |
| `scripts/ui/unlock_screen.gd` | 9 | `NAME_FONT` 3, `TITLE_FONT` 1, `SECTION_HEAD_FONT` 1, `PixelUI.FONT_INFO_MIN` 1, `GRID_NAME_FONT` 1, `PixelUI.text_px(font_size` 1, `font_size` 1 |
| `scripts/ui/run_end_screen.gd` | 8 | `title_font` 1, `SUMMARY_FONT` 1, `maxi(SUMMARY_FONT - 6` 1, `PixelUI.FONT_INFO_MIN` 1, `PixelUI.scale_font_size(PixelUI.FONT_INFO_MIN)` 1, `SECTION_HEAD_FONT` 1, `PixelUI.text_px(font_size` 1, `font_size` 1 |
| `scripts/ui/operation_briefing_overlay.gd` | 7 | `SECTION_FONT` 3, `TITLE_FONT` 1, `BODY_FONT` 1, `ACTION_FONT` 1, `font_size` 1 |
| `scripts/battle/battle_feedback.gd` | 7 | `FLOAT_FONT_SIZE` 1, `RESUME_CALLOUT_FONT` 1, `44` 1, `PixelUI.scale_font_size(16` 1, `16` 1, `PixelUI.scale_font_size(30` 1, `30` 1 |
| `scripts/battle/protocol_actions.gd` | 6 | `36` 2, `_scene._layout.presentation("protocol_cost_font", 48` 1, `132` 1, `PixelUI.FONT_INFO_MIN` 1, `38` 1 |
| `scripts/battle/boss_relic_actions.gd` | 5 | `HOLD_BANNER_FONT` 1, `HOLD_DETAIL_FONT` 1, `PICK_NOTE_FONT` 1, `56` 1, `36` 1 |
| `scripts/battle/dice_tray_3d.gd` | 5 | `50` 2, `font_size` 1, `_numeral_font_size(value_text) + font_size_delta` 1, `56` 1 |
| `scripts/ui/intercept_screen.gd` | 4 | `0.050` 2, `font_size` 1, `BODY_FONT` 1 |
| `scripts/ui/item_card.gd` | 4 | `LABEL_FONT` 1, `TYPE_CHIP_FONT` 1, `BODY_FONT` 1, `font_size` 1 |
| `scripts/ui/feedback.gd` | 3 | `TITLE_FONT` 1, `BODY_FONT` 1, `PixelUI.FONT_ACCENT_MIN` 1 |
| `scripts/ui/spotlight_layer.gd` | 3 | `60` 1, `COACH_FONT` 1, `HINT_FONT` 1 |
| `scripts/autoloads/PersistentHeader.gd` | 3 | `_battle_style.get("header_font", SUMMARY_FONT_SIZE` 2, `48` 1 |
| `scripts/ui/ability_readout.gd` | 2 | `PixelUI.text_px(font_size` 1, `font_size` 1 |
| `scripts/ui/effect_pip.gd` | 2 | `font_size if superscript else PixelUI.text_px(font_size` 1, `font_size` 1 |
| `scripts/ui/state_code_panel.gd` | 2 | `TITLE_FONT` 1, `28` 1 |
| `scripts/battle/landscape_card_layout.gd` | 2 | `PixelUI.text_px(fitted` 1, `fitted` 1 |
| `scripts/ui/training_prompt.gd` | 1 | `64 if value == heading else 56` 1 |
| `scripts/battle/landscape_battle_layout.gd` | 1 | `STYLE.protocol_font` 1 |

<details><summary>Every font size site (file:line, call, size)</summary>

- `scripts/autoloads/PersistentHeader.gd:212` add_theme_font_size_override `_battle_style.get("header_font", SUMMARY_FONT_SIZE`
- `scripts/autoloads/PersistentHeader.gd:225` add_theme_font_size_override `_battle_style.get("header_font", SUMMARY_FONT_SIZE`
- `scripts/autoloads/PersistentHeader.gd:449` add_theme_font_size_override `48`
- `scripts/battle/battle_feedback.gd:640` add_theme_font_size_override `FLOAT_FONT_SIZE`
- `scripts/battle/battle_feedback.gd:960` style_label `RESUME_CALLOUT_FONT`
- `scripts/battle/battle_feedback.gd:1152` style_label `44`
- `scripts/battle/battle_feedback.gd:1369` add_theme_font_size_override `PixelUI.scale_font_size(16`
- `scripts/battle/battle_feedback.gd:1369` scale_font_size `16`
- `scripts/battle/battle_feedback.gd:1413` add_theme_font_size_override `PixelUI.scale_font_size(30`
- `scripts/battle/battle_feedback.gd:1413` scale_font_size `30`
- `scripts/battle/battle_scene.gd:863` style_label `56`
- `scripts/battle/battle_scene.gd:900` style_button(size) `36`
- `scripts/battle/battle_scene.gd:1693` text_px `int(round(tag_size.y * DIE_TAG_FONT_RATIO`
- `scripts/battle/battle_scene.gd:1704` text_px `int(round(base_font * DIE_TAG_SHRINK_STEP`
- `scripts/battle/battle_scene.gd:1763` add_theme_font_size_override `PixelUI.text_px(value_font`
- `scripts/battle/battle_scene.gd:1763` text_px `value_font`
- `scripts/battle/battle_scene.gd:2175` style_label `38`
- `scripts/battle/battle_scene.gd:2184` style_label `24`
- `scripts/battle/battle_scene.gd:2549` add_theme_font_size_override `PROTOCOL_STACK_LABEL_FONT`
- `scripts/battle/battle_scene.gd:2789` ui button size `action_font`
- `scripts/battle/battle_scene.gd:2797` ui button size `action_font`
- `scripts/battle/battle_scene.gd:2812` style_button(size) `font_size`
- `scripts/battle/battle_scene.gd:3539` add_theme_font_size_override `PROTOCOL_LABEL_FONT_SIZE`
- `scripts/battle/battle_scene.gd:3545` add_theme_font_size_override `PROTOCOL_VALUE_FONT_SIZE`
- `scripts/battle/boss_relic_actions.gd:128` style_label `HOLD_BANNER_FONT`
- `scripts/battle/boss_relic_actions.gd:139` style_label `HOLD_DETAIL_FONT`
- `scripts/battle/boss_relic_actions.gd:251` style_label `PICK_NOTE_FONT`
- `scripts/battle/boss_relic_actions.gd:411` style_label `56`
- `scripts/battle/boss_relic_actions.gd:441` style_button(size) `36`
- `scripts/battle/dice_tray_3d.gd:1562` font_size = `font_size`
- `scripts/battle/dice_tray_3d.gd:2587` font_size = `_numeral_font_size(value_text) + font_size_delta`
- `scripts/battle/dice_tray_3d.gd:2677` font_size = `56`
- `scripts/battle/dice_tray_3d.gd:2706` font_size = `50`
- `scripts/battle/dice_tray_3d.gd:2755` font_size = `50`
- `scripts/battle/landscape_battle_layout.gd:69` add_theme_font_size_override `STYLE.protocol_font`
- `scripts/battle/landscape_card_layout.gd:42` add_theme_font_size_override `PixelUI.text_px(fitted`
- `scripts/battle/landscape_card_layout.gd:42` text_px `fitted`
- `scripts/battle/protocol_actions.gd:100` add_theme_font_size_override `_scene._layout.presentation("protocol_cost_font", 48`
- `scripts/battle/protocol_actions.gd:728` style_label `36`
- `scripts/battle/protocol_actions.gd:735` style_label `36`
- `scripts/battle/protocol_actions.gd:740` style_label `132`
- `scripts/battle/protocol_actions.gd:778` style_label `PixelUI.FONT_INFO_MIN`
- `scripts/battle/protocol_actions.gd:790` style_button(size) `38`
- `scripts/ui/ability_readout.gd:421` add_theme_font_size_override `PixelUI.text_px(font_size`
- `scripts/ui/ability_readout.gd:421` text_px `font_size`
- `scripts/ui/compact_unit_card.gd:153` add_theme_font_size_override `PixelUI.text_px(int(CARD_NAME_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:153` text_px `int(CARD_NAME_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:154` add_theme_font_size_override `PixelUI.text_px(int(48 * text_scale`
- `scripts/ui/compact_unit_card.gd:154` text_px `int(48 * text_scale`
- `scripts/ui/compact_unit_card.gd:155` add_theme_font_size_override `PixelUI.text_px(int(48 * text_scale`
- `scripts/ui/compact_unit_card.gd:155` text_px `int(48 * text_scale`
- `scripts/ui/compact_unit_card.gd:161` add_theme_font_size_override `PixelUI.text_px(int(CARD_HP_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:161` text_px `int(CARD_HP_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:165` add_theme_font_size_override `PixelUI.text_px(int(CAST_BADGE_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:165` text_px `int(CAST_BADGE_FONT_SIZE * text_scale`
- `scripts/ui/compact_unit_card.gd:366` add_theme_font_size_override `CAST_BADGE_FONT_SIZE`
- `scripts/ui/compact_unit_card.gd:991` add_theme_font_size_override `PixelUI.text_px(int(STATUS_ICON_FONT_SIZE * _battle_text_scale`
- `scripts/ui/compact_unit_card.gd:991` text_px `int(STATUS_ICON_FONT_SIZE * _battle_text_scale`
- `scripts/ui/compact_unit_card.gd:1430` add_theme_font_size_override `PixelUI.text_px(font_size`
- `scripts/ui/compact_unit_card.gd:1430` text_px `font_size`
- `scripts/ui/effect_pip.gd:706` add_theme_font_size_override `font_size if superscript else PixelUI.text_px(font_size`
- `scripts/ui/effect_pip.gd:706` text_px `font_size`
- `scripts/ui/evolution_screen.gd:124` style_button(size) `0.12`
- `scripts/ui/evolution_screen.gd:181` _make_*label(size) `40`
- `scripts/ui/evolution_screen.gd:187` _make_*label(size) `BODY_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:252` _make_*label(size) `CARD_TITLE_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:261` _make_*label(size) `_`
- `scripts/ui/evolution_screen.gd:271` style_button(size) `0.050`
- `scripts/ui/evolution_screen.gd:342` _make_*label(size) `ABILITY_DESC_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:351` style_button(size) `BUTTON_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:399` _make_*label(size) `BODY_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:408` _make_*label(size) `BODY_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:419` _make_*label(size) `SMALL_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:610` style_label `TITLE_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:611` style_label `SUMMARY_FONT_SIZE`
- `scripts/ui/evolution_screen.gd:612` style_label `30`
- `scripts/ui/evolution_screen.gd:620` style_label `font_size`
- `scripts/ui/feedback.gd:68` style_label `TITLE_FONT`
- `scripts/ui/feedback.gd:81` style_label `BODY_FONT`
- `scripts/ui/feedback.gd:87` style_label `PixelUI.FONT_ACCENT_MIN`
- `scripts/ui/help_menu.gd:279` style_button(size) `TAB_FONT`
- `scripts/ui/help_menu.gd:285` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:380` style_button(size) `0.17`
- `scripts/ui/help_menu.gd:389` style_button(size) `TAB_FONT`
- `scripts/ui/help_menu.gd:446` style_button(size) `TAB_FONT`
- `scripts/ui/help_menu.gd:480` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:526` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:708` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:711` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:916` ui button size `44`
- `scripts/ui/help_menu.gd:934` ui button size `BODY_FONT`
- `scripts/ui/help_menu.gd:952` ui button size `BODY_FONT`
- `scripts/ui/help_menu.gd:1036` _make_*label(size) `40`
- `scripts/ui/help_menu.gd:1038` _make_*label(size) `BODY_FONT`
- `scripts/ui/help_menu.gd:1070` _make_*label(size) `40`
- `scripts/ui/help_menu.gd:1128` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:1144` _make_*label(size) `BODY_LONG_FONT`
- `scripts/ui/help_menu.gd:1340` _make_*label(size) `SECTION_FONT`
- `scripts/ui/help_menu.gd:1365` _make_*label(size) `ROW_NAME_FONT`
- `scripts/ui/help_menu.gd:1368` _make_*label(size) `BODY_FONT`
- `scripts/ui/help_menu.gd:1376` _make_*label(size) `ROW_DESCRIPTOR_FONT`
- `scripts/ui/help_menu.gd:1479` style_label `font_size`
- `scripts/ui/home_screen.gd:60` scale_font_size `PixelUI.FONT_BODY_MIN`
- `scripts/ui/home_screen.gd:288` _make_*label(size) `ENC_NAME_FONT`
- `scripts/ui/home_screen.gd:296` _make_*label(size) `ENC_SITE_FONT`
- `scripts/ui/home_screen.gd:301` text_px `ENC_SITE_FONT`
- `scripts/ui/home_screen.gd:308` _make_*label(size) `PROGRESS_FONT`
- `scripts/ui/home_screen.gd:311` text_px `PROGRESS_FONT`
- `scripts/ui/home_screen.gd:325` _make_*label(size) `128`
- `scripts/ui/home_screen.gd:357` _make_*label(size) `LORE_FONT`
- `scripts/ui/home_screen.gd:362` text_px `LORE_FONT`
- `scripts/ui/home_screen.gd:391` _make_*label(size) `ENC_META_FONT`
- `scripts/ui/home_screen.gd:450` add_theme_font_size_override `PixelUI.text_px(ENC_UNLOCK_FONT`
- `scripts/ui/home_screen.gd:450` text_px `ENC_UNLOCK_FONT`
- `scripts/ui/home_screen.gd:454` add_theme_font_size_override `PixelUI.text_px(ENC_SITE_FONT`
- `scripts/ui/home_screen.gd:454` text_px `ENC_SITE_FONT`
- `scripts/ui/home_screen.gd:580` _make_*label(size) `HEADER_FONT`
- `scripts/ui/home_screen.gd:583` _make_*label(size) `COUNTER_FONT`
- `scripts/ui/home_screen.gd:641` _make_*label(size) `DETAIL_DESC_FONT`
- `scripts/ui/home_screen.gd:650` text_px `DETAIL_DESC_FONT`
- `scripts/ui/home_screen.gd:658` _make_*label(size) `DETAIL_THREAT_FONT`
- `scripts/ui/home_screen.gd:661` _make_*label(size) `DETAIL_THREAT_FONT`
- `scripts/ui/home_screen.gd:667` text_px `DETAIL_THREAT_FONT`
- `scripts/ui/home_screen.gd:724` _make_*label(size) `TILE_NAME_FONT`
- `scripts/ui/home_screen.gd:780` _make_*label(size) `P`
- `scripts/ui/home_screen.gd:984` ui button size `DEPLOY_FONT`
- `scripts/ui/home_screen.gd:1060` _make_*label(size) `DETAIL_NAME_FONT`
- `scripts/ui/home_screen.gd:1061` _make_*label(size) `DETAIL_DESC_FONT`
- `scripts/ui/home_screen.gd:1078` style_button(size) `FOCUS_CHIP_FONT`
- `scripts/ui/home_screen.gd:1105` style_button(size) `FOCUS_CHIP_FONT`
- `scripts/ui/home_screen.gd:1128` add_theme_font_size_override `PixelUI.text_px(size_logical`
- `scripts/ui/home_screen.gd:1128` text_px `size_logical`
- `scripts/ui/home_screen.gd:1136` _make_*label(size) `HEADER_FONT`
- `scripts/ui/home_screen.gd:1143` add_theme_font_size_override `PixelUI.text_px(size_logical`
- `scripts/ui/home_screen.gd:1143` text_px `size_logical`
- `scripts/ui/inspect_popup.gd:189` _make_*label(size) `ROLL_FONT`
- `scripts/ui/inspect_popup.gd:206` _make_*label(size) `BODY_LONG_FONT`
- `scripts/ui/inspect_popup.gd:213` _make_*label(size) `HINT_FONT`
- `scripts/ui/inspect_popup.gd:225` _make_*label(size) `SECTION_LABEL_FONT`
- `scripts/ui/inspect_popup.gd:245` _make_*label(size) `48`
- `scripts/ui/inspect_popup.gd:260` _make_*label(size) `SUBTITLE_FONT`
- `scripts/ui/inspect_popup.gd:290` _make_*label(size) `BODY_FONT`
- `scripts/ui/inspect_popup.gd:334` _make_*label(size) `ROLL_FONT`
- `scripts/ui/inspect_popup.gd:345` _make_*label(size) `ABILITY_NAME_FONT`
- `scripts/ui/inspect_popup.gd:348` _make_*label(size) `BODY_FONT`
- `scripts/ui/inspect_popup.gd:370` _make_*label(size) `BODY_FONT`
- `scripts/ui/inspect_popup.gd:517` style_label `font_size`
- `scripts/ui/intercept_screen.gd:131` style_label `font_size`
- `scripts/ui/intercept_screen.gd:189` style_button(size) `0.050`
- `scripts/ui/intercept_screen.gd:230` style_label `BODY_FONT`
- `scripts/ui/intercept_screen.gd:239` style_button(size) `0.050`
- `scripts/ui/item_card.gd:77` style_label `LABEL_FONT`
- `scripts/ui/item_card.gd:100` style_label `TYPE_CHIP_FONT`
- `scripts/ui/item_card.gd:161` style_label `BODY_FONT`
- `scripts/ui/item_card.gd:172` style_label `font_size`
- `scripts/ui/loadout_menu.gd:136` _make_*label(size) `HEADER_FONT`
- `scripts/ui/loadout_menu.gd:139` _make_*label(size) `SECTION_FONT`
- `scripts/ui/loadout_menu.gd:159` _make_*label(size) `SECTION_FONT`
- `scripts/ui/loadout_menu.gd:211` _make_*label(size) `DISCARD_HEADER_FONT`
- `scripts/ui/loadout_menu.gd:218` _make_*label(size) `SECTION_FONT`
- `scripts/ui/loadout_menu.gd:241` style_button(size) `DISCARD_BUTTON_FONT`
- `scripts/ui/loadout_menu.gd:251` style_button(size) `DISCARD_BUTTON_FONT`
- `scripts/ui/loadout_menu.gd:274` _make_*label(size) `DISCARD_STRIP_FONT`
- `scripts/ui/loadout_menu.gd:298` _make_*label(size) `NAME_FONT`
- `scripts/ui/loadout_menu.gd:407` _make_*label(size) `NAME_FONT`
- `scripts/ui/loadout_menu.gd:412` _make_*label(size) `SECTION_FONT`
- `scripts/ui/loadout_menu.gd:567` style_label `font_size`
- `scripts/ui/main_menu.gd:127` ui button size `BEGIN_FONT`
- `scripts/ui/main_menu.gd:138` ui button size `SECONDARY_FONT`
- `scripts/ui/main_menu.gd:140` ui button size `BEGIN_FONT`
- `scripts/ui/main_menu.gd:149` ui button size `FEEDBACK_FONT`
- `scripts/ui/main_menu.gd:159` ui button size `ABANDON_FONT`
- `scripts/ui/main_menu.gd:250` style_label `24`
- `scripts/ui/main_menu.gd:292` ui button size `ABANDON_FONT`
- `scripts/ui/main_menu.gd:348` style_label `PROMPT_TITLE_FONT`
- `scripts/ui/main_menu.gd:362` ui button size `PROMPT_BUTTON_FONT`
- `scripts/ui/main_menu.gd:370` ui button size `PROMPT_SKIP_FONT`
- `scripts/ui/main_menu.gd:451` ui button size `ABANDON_FONT`
- `scripts/ui/main_menu.gd:501` style_label `PROMPT_TITLE_FONT`
- `scripts/ui/main_menu.gd:515` ui button size `PROMPT_BUTTON_FONT`
- `scripts/ui/main_menu.gd:523` ui button size `PROMPT_SKIP_FONT`
- `scripts/ui/main_menu.gd:578` style_label `NOTICE_FONT`
- `scripts/ui/operation_briefing_overlay.gd:188` _make_*label(size) `TITLE_FONT`
- `scripts/ui/operation_briefing_overlay.gd:194` _make_*label(size) `SECTION_FONT`
- `scripts/ui/operation_briefing_overlay.gd:200` _make_*label(size) `BODY_FONT`
- `scripts/ui/operation_briefing_overlay.gd:239` _make_*label(size) `SECTION_FONT`
- `scripts/ui/operation_briefing_overlay.gd:245` _make_*label(size) `SECTION_FONT`
- `scripts/ui/operation_briefing_overlay.gd:264` style_button(size) `ACTION_FONT`
- `scripts/ui/operation_briefing_overlay.gd:274` style_label `font_size`
- `scripts/ui/pixel_ui.gd:125` text_px `font_size: int`
- `scripts/ui/pixel_ui.gd:1524` add_theme_font_size_override `scale_font_size(font_size`
- `scripts/ui/pixel_ui.gd:1524` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:1537` scale_font_size `font_size: int`
- `scripts/ui/pixel_ui.gd:1970` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:1971` add_theme_font_size_override `font_px`
- `scripts/ui/pixel_ui.gd:2001` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:2002` add_theme_font_size_override `font_px`
- `scripts/ui/pixel_ui.gd:2036` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:2037` add_theme_font_size_override `font_px`
- `scripts/ui/pixel_ui.gd:2159` add_theme_font_size_override `scale_font_size(font_size`
- `scripts/ui/pixel_ui.gd:2159` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:2170` style_label `font_size`
- `scripts/ui/pixel_ui.gd:2191` add_theme_font_size_override `text_px(font_size`
- `scripts/ui/pixel_ui.gd:2191` text_px `font_size`
- `scripts/ui/pixel_ui.gd:2541` add_theme_font_size_override `scale_font_size(font_size`
- `scripts/ui/pixel_ui.gd:2541` scale_font_size `font_size`
- `scripts/ui/pixel_ui.gd:2665` style_label `font_size`
- `scripts/ui/reward_screen.gd:226` _make_*label(size) `42`
- `scripts/ui/reward_screen.gd:234` _make_*label(size) `BODY_FONT_SIZE`
- `scripts/ui/reward_screen.gd:373` _make_*label(size) `64`
- `scripts/ui/reward_screen.gd:455` _make_*label(size) `NAME_FONT_SIZE`
- `scripts/ui/reward_screen.gd:465` _make_*label(size) `TYPE_HEADER_FONT`
- `scripts/ui/reward_screen.gd:581` style_label `font_size`
- `scripts/ui/reward_screen.gd:699` ui button size `VIEW_BATTLE_FONT`
- `scripts/ui/reward_screen.gd:741` ui button size `CONFIRM_FONT`
- `scripts/ui/reward_screen.gd:747` ui button size `CONFIRM_FONT`
- `scripts/ui/reward_screen.gd:848` _make_*label(size) `GEAR_TARGET_TITLE_FONT`
- `scripts/ui/reward_screen.gd:862` ui button size `GEAR_TARGET_BUTTON_FONT_SIZE`
- `scripts/ui/reward_screen.gd:1072` style_label `44`
- `scripts/ui/reward_screen.gd:1073` style_label `72`
- `scripts/ui/reward_screen.gd:1074` style_label `32`
- `scripts/ui/reward_screen.gd:1075` style_label `28`
- `scripts/ui/reward_screen.gd:1076` style_label `FOOTER_FONT`
- `scripts/ui/reward_screen.gd:1132` style_label `font_size`
- `scripts/ui/route_fork_screen.gd:112` style_label `TYPE_FONT`
- `scripts/ui/route_fork_screen.gd:118` style_label `TITLE_FONT`
- `scripts/ui/route_fork_screen.gd:125` style_label `BODY_FONT`
- `scripts/ui/route_fork_screen.gd:146` style_label `BODY_FONT`
- `scripts/ui/route_fork_screen.gd:243` style_label `CARD_TITLE_FONT`
- `scripts/ui/route_fork_screen.gd:250` style_label `BODY_FONT`
- `scripts/ui/route_fork_screen.gd:258` style_label `BODY_FONT`
- `scripts/ui/route_fork_screen.gd:262` style_label `BODY_FONT`
- `scripts/ui/route_fork_screen.gd:267` style_label `BODY_FONT`
- `scripts/ui/run_end_screen.gd:148` style_label `title_font`
- `scripts/ui/run_end_screen.gd:196` style_label `SUMMARY_FONT`
- `scripts/ui/run_end_screen.gd:211` style_label `maxi(SUMMARY_FONT - 6`
- `scripts/ui/run_end_screen.gd:221` scale_font_size `PixelUI.FONT_INFO_MIN`
- `scripts/ui/run_end_screen.gd:221` style_label `PixelUI.scale_font_size(PixelUI.FONT_INFO_MIN)`
- `scripts/ui/run_end_screen.gd:229` style_label `SECTION_HEAD_FONT`
- `scripts/ui/run_end_screen.gd:235` add_theme_font_size_override `PixelUI.text_px(font_size`
- `scripts/ui/run_end_screen.gd:235` text_px `font_size`
- `scripts/ui/spotlight_layer.gd:28` add_theme_font_size_override `60`
- `scripts/ui/spotlight_layer.gd:177` style_label `COACH_FONT`
- `scripts/ui/spotlight_layer.gd:187` style_label `HINT_FONT`
- `scripts/ui/state_code_panel.gd:96` style_label `TITLE_FONT`
- `scripts/ui/state_code_panel.gd:126` style_label `28`
- `scripts/ui/training_prompt.gd:31` add_theme_font_size_override `64 if value == heading else 56`
- `scripts/ui/unlock_screen.gd:106` style_label `TITLE_FONT`
- `scripts/ui/unlock_screen.gd:143` style_label `SECTION_HEAD_FONT`
- `scripts/ui/unlock_screen.gd:202` style_label `NAME_FONT`
- `scripts/ui/unlock_screen.gd:206` style_label `PixelUI.FONT_INFO_MIN`
- `scripts/ui/unlock_screen.gd:240` style_label `NAME_FONT`
- `scripts/ui/unlock_screen.gd:264` style_label `NAME_FONT`
- `scripts/ui/unlock_screen.gd:324` style_label `GRID_NAME_FONT`
- `scripts/ui/unlock_screen.gd:366` add_theme_font_size_override `PixelUI.text_px(font_size`
- `scripts/ui/unlock_screen.gd:366` text_px `font_size`

</details>

## Hardcoded colors

Total hardcoded color sites: **183** in 28 files (rgb 146, named 17, hex 14, tscn 6). `pixel_ui.gd` (the token owner) and `theme_overload.tres` (its mirror) are excluded.

| file | sites | kinds |
|---|---|---|
| `scripts/battle/dice_tray_3d.gd` | 38 | rgb 38 |
| `scripts/battle/battle_feedback.gd` | 25 | rgb 25 |
| `scripts/ui/compact_unit_card.gd` | 22 | rgb 19, named 3 |
| `scripts/ui/home_screen.gd` | 13 | rgb 8, named 3, hex 2 |
| `scripts/battle/battle_scene.gd` | 12 | rgb 9, named 3 |
| `scripts/ui/ability_readout.gd` | 11 | rgb 11 |
| `scripts/ui/title_backdrop.gd` | 9 | hex 9 |
| `scripts/ui/evolution_screen.gd` | 6 | rgb 6 |
| `scripts/ui/loadout_menu.gd` | 6 | rgb 6 |
| `scripts/ui/spotlight_layer.gd` | 5 | rgb 2, hex 2, named 1 |
| `scripts/autoloads/PersistentHeader.gd` | 5 | named 4, rgb 1 |
| `scripts/ui/reward_screen.gd` | 4 | rgb 4 |
| `scripts/battle/protocol_actions.gd` | 4 | rgb 3, named 1 |
| `scripts/ui/battle_bay_floor.gd` | 3 | named 2, rgb 1 |
| `scripts/ui/pattern_background.gd` | 3 | rgb 3 |
| `scripts/ui/inspect_popup.gd` | 2 | rgb 2 |
| `scripts/ui/intercept_screen.gd` | 2 | rgb 2 |
| `scripts/autoloads/DataManager.gd` | 2 | rgb 2 |
| `scenes/ui/PersistentHeader.tscn` | 2 | tscn 2 |
| `scripts/ui/effect_pip.gd` | 1 | rgb 1 |
| `scripts/ui/help_menu.gd` | 1 | rgb 1 |
| `scripts/ui/run_end_screen.gd` | 1 | rgb 1 |
| `scripts/ui/unlock_screen.gd` | 1 | rgb 1 |
| `scripts/battle/battle_layout.gd` | 1 | hex 1 |
| `scenes/ui/EvolutionScreen.tscn` | 1 | tscn 1 |
| `scenes/ui/RewardScreen.tscn` | 1 | tscn 1 |
| `scenes/ui/RunEndScreen.tscn` | 1 | tscn 1 |
| `scenes/ui/UnlockScreen.tscn` | 1 | tscn 1 |

<details><summary>Every hardcoded color (file:line, kind, value)</summary>

- `scenes/ui/EvolutionScreen.tscn:22` tscn color `Color(0.0509804, 0.054902, 0.0862745, 1)`
- `scenes/ui/PersistentHeader.tscn:25` tscn color `Color(0.035294, 0.047059, 0.054902, 1)`
- `scenes/ui/PersistentHeader.tscn:100` tscn color `Color(0.105882, 0.133333, 0.14902, 1)`
- `scenes/ui/RewardScreen.tscn:22` tscn color `Color(0.0509804, 0.054902, 0.0862745, 1)`
- `scenes/ui/RunEndScreen.tscn:21` tscn color `Color(0.0431373, 0.0470588, 0.0745098, 1)`
- `scenes/ui/UnlockScreen.tscn:21` tscn color `Color(0.0431373, 0.0470588, 0.0745098, 1)`
- `scripts/autoloads/DataManager.gd:991` rgb `Color(0, 0, 0, 1)`
- `scripts/autoloads/DataManager.gd:991` rgb `Color(0, 0, 0, 0)`
- `scripts/autoloads/PersistentHeader.gd:214` rgb `Color(0.02, 0.03, 0.05, 0.98)`
- `scripts/autoloads/PersistentHeader.gd:229` named `Color.WHITE`
- `scripts/autoloads/PersistentHeader.gd:230` named `Color.WHITE`
- `scripts/autoloads/PersistentHeader.gd:231` named `Color.WHITE`
- `scripts/autoloads/PersistentHeader.gd:232` named `Color.WHITE`
- `scripts/battle/battle_feedback.gd:546` rgb `Color(1, 1, 1, 1)`
- `scripts/battle/battle_feedback.gd:549` rgb `Color(1.0, 0.45, 0.45, 1.0)`
- `scripts/battle/battle_feedback.gd:553` rgb `Color(0.45, 1.0, 0.65, 1.0)`
- `scripts/battle/battle_feedback.gd:555` rgb `Color(0.55, 0.82, 1.0, 1.0)`
- `scripts/battle/battle_feedback.gd:557` rgb `Color(1.0, 0.80, 0.20, 1.0)`
- `scripts/battle/battle_feedback.gd:560` rgb `Color(1.0, 0.30, 0.30, 1.0)`
- `scripts/battle/battle_feedback.gd:641` rgb `Color(0.02, 0.03, 0.05, 0.95)`
- `scripts/battle/battle_feedback.gd:777` rgb `Color(1.0, 0.42, 0.42, 1.0)`
- `scripts/battle/battle_feedback.gd:779` rgb `Color(1.0, 0.30, 0.30, 1.0)`
- `scripts/battle/battle_feedback.gd:781` rgb `Color(0.5, 1.0, 0.62, 1.0)`
- `scripts/battle/battle_feedback.gd:783` rgb `Color(0.55, 0.82, 1.0, 1.0)`
- `scripts/battle/battle_feedback.gd:785` rgb `Color(1, 1, 1, 1)`
- `scripts/battle/battle_feedback.gd:856` rgb `Color(1.0, 0.82, 0.20, 0.0)`
- `scripts/battle/battle_feedback.gd:884` rgb `Color(0.95, 0.55, 0.20, 1.0)`
- `scripts/battle/battle_feedback.gd:886` rgb `Color(1.0, 0.82, 0.20, 1.0)`
- `scripts/battle/battle_feedback.gd:888` rgb `Color(1.0, 0.80, 0.20, 1.0)`
- `scripts/battle/battle_feedback.gd:890` rgb `Color(0.86, 0.42, 0.28, 1.0)`
- `scripts/battle/battle_feedback.gd:895` rgb `Color(0.55, 0.82, 1.0, 0.95)`
- `scripts/battle/battle_feedback.gd:904` rgb `Color(0.95, 0.76, 0.28, 1.0)`
- `scripts/battle/battle_feedback.gd:912` rgb `Color(0.95, 0.45, 0.30, 1.0)`
- `scripts/battle/battle_feedback.gd:1270` rgb `Color(0.42, 0.44, 0.50, 1.0)`
- `scripts/battle/battle_feedback.gd:1371` rgb `Color(0.02, 0.03, 0.05, 0.95)`
- `scripts/battle/battle_feedback.gd:1397` rgb `Color(1.35, 1.35, 1.4, 1.0)`
- `scripts/battle/battle_feedback.gd:1414` rgb `Color(1.0, 0.82, 0.20, 1.0)`
- `scripts/battle/battle_feedback.gd:1415` rgb `Color(0.03, 0.03, 0.05, 1.0)`
- `scripts/battle/battle_layout.gd:521` hex `Color("2a333a")`
- `scripts/battle/battle_scene.gd:41` rgb `Color(0.38, 0.64, 0.92, 1.0)`
- `scripts/battle/battle_scene.gd:42` rgb `Color(0.42, 0.54, 0.68, 1.0)`
- `scripts/battle/battle_scene.gd:500` rgb `Color(1, 1, 1, 1)`
- `scripts/battle/battle_scene.gd:1533` rgb `Color(1.0, 1.0, 1.0, 0.0)`
- `scripts/battle/battle_scene.gd:2139` rgb `Color(0.004, 0.006, 0.012, 0.58)`
- `scripts/battle/battle_scene.gd:2804` rgb `Color(0.014, 0.020, 0.032, 0.92)`
- `scripts/battle/battle_scene.gd:2821` named `Color.WHITE`
- `scripts/battle/battle_scene.gd:2822` named `Color.WHITE`
- `scripts/battle/battle_scene.gd:2831` named `Color.WHITE`
- `scripts/battle/battle_scene.gd:3541` rgb `Color(0.02, 0.03, 0.05, 0.98)`
- `scripts/battle/battle_scene.gd:3547` rgb `Color(0.02, 0.03, 0.05, 0.98)`
- `scripts/battle/battle_scene.gd:3569` rgb `Color(0.010, 0.014, 0.022, 0.95)`
- `scripts/battle/dice_tray_3d.gd:223` rgb `Color(1.0, 1.0, 1.0, 0.0)`
- `scripts/battle/dice_tray_3d.gd:1415` rgb `Color(0.46, 0.26, 0.03, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1416` rgb `Color(1.0, 0.58, 0.10, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1419` rgb `Color(0.06, 0.14, 0.32, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1420` rgb `Color(0.04, 0.10, 0.25, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1423` rgb `Color(0.30, 0.06, 0.05, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1424` rgb `Color(0.20, 0.04, 0.03, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1480` rgb `Color(0.06, 0.06, 0.08, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1481` rgb `Color(0.03, 0.03, 0.04, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1486` rgb `Color(0.15, 0.15, 0.18, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1487` rgb `Color(0.08, 0.08, 0.10, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1492` rgb `Color(0.25, 0.18, 0.04, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1493` rgb `Color(0.6, 0.4, 0.05, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1498` rgb `Color(0.3, 0.12, 0.02, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1499` rgb `Color(0.8, 0.35, 0.05, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1504` rgb `Color(0.15, 0.3, 0.35, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1505` rgb `Color(0.1, 0.8, 0.9, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1509` rgb `Color(0.06, 0.14, 0.32, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1510` rgb `Color(0.04, 0.10, 0.25, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1738` rgb `Color(0.45, 0.72, 1.0, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1752` rgb `Color(0, 0, 0, 0)`
- `scripts/battle/dice_tray_3d.gd:1754` rgb `Color(0.20, 0.34, 0.52, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1860` rgb `Color(0.12, 0.42, 0.88, 1.0)`
- `scripts/battle/dice_tray_3d.gd:1860` rgb `Color(0.72, 0.20, 0.18, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2384` rgb `Color(0.12, 0.42, 0.88, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2399` rgb `Color(0.96, 0.97, 0.98, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2679` rgb `Color(0.02, 0.06, 0.10, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2684` rgb `Color(0.72, 0.70, 0.66, 0.94)`
- `scripts/battle/dice_tray_3d.gd:2684` rgb `Color(0.70, 0.94, 1.0, 0.92)`
- `scripts/battle/dice_tray_3d.gd:2707` rgb `Color(0.95, 0.76, 0.28, 0.95)`
- `scripts/battle/dice_tray_3d.gd:2709` rgb `Color(0.06, 0.05, 0.02, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2757` rgb `Color(0.04, 0.02, 0.06, 1.0)`
- `scripts/battle/dice_tray_3d.gd:2763` rgb `Color(0.82, 0.55, 1.0, 0.95)`
- `scripts/battle/dice_tray_3d.gd:2766` rgb `Color(0.95, 0.45, 0.30, 0.95)`
- `scripts/battle/dice_tray_3d.gd:2779` rgb `Color(0.55, 0.53, 0.49, 0.38)`
- `scripts/battle/dice_tray_3d.gd:2792` rgb `Color(0.92, 0.68, 0.20, 0.20)`
- `scripts/battle/dice_tray_3d.gd:2805` rgb `Color(0.48, 0.86, 1.0, 0.26)`
- `scripts/battle/dice_tray_3d.gd:2807` rgb `Color(0.28, 0.70, 1.0, 1.0)`
- `scripts/battle/protocol_actions.gd:79` rgb `Color(1.0, 1.0, 1.0, 0.45)`
- `scripts/battle/protocol_actions.gd:105` rgb `Color(0.02, 0.03, 0.05, 0.95)`
- `scripts/battle/protocol_actions.gd:126` named `Color.WHITE`
- `scripts/battle/protocol_actions.gd:699` rgb `Color(0.0, 0.0, 0.0, 0.62)`
- `scripts/ui/ability_readout.gd:41` rgb `Color(1, 1, 1, 0)`
- `scripts/ui/ability_readout.gd:66` rgb `Color(1, 1, 1, 0)`
- `scripts/ui/ability_readout.gd:96` rgb `Color(0, 0, 0, 0)`
- `scripts/ui/ability_readout.gd:162` rgb `Color(1, 1, 1, 1)`
- `scripts/ui/ability_readout.gd:164` rgb `Color(1, 1, 1, 0)`
- `scripts/ui/ability_readout.gd:166` rgb `Color(1, 1, 1, 1)`
- `scripts/ui/ability_readout.gd:177` rgb `Color(1, 1, 1, 0)`
- `scripts/ui/ability_readout.gd:196` rgb `Color(1, 1, 1, 1)`
- `scripts/ui/ability_readout.gd:351` rgb `Color(0.84, 0.90, 0.96, 0.78)`
- `scripts/ui/ability_readout.gd:362` rgb `Color(0.82, 0.90, 0.96, 0.88)`
- `scripts/ui/ability_readout.gd:423` rgb `Color(0.01, 0.015, 0.025, 0.98)`
- `scripts/ui/battle_bay_floor.gd:127` named `Color.WHITE`
- `scripts/ui/battle_bay_floor.gd:209` rgb `Color(0.85, 0.85, 0.85)`
- `scripts/ui/battle_bay_floor.gd:261` named `Color.WHITE`
- `scripts/ui/compact_unit_card.gd:352` named `Color.BLACK`
- `scripts/ui/compact_unit_card.gd:369` rgb `Color(0.006, 0.012, 0.020, 0.80)`
- `scripts/ui/compact_unit_card.gd:549` rgb `Color(0.0, 0.0, 0.0, 0.0)`
- `scripts/ui/compact_unit_card.gd:592` rgb `Color(0.48, 0.50, 0.58, 0.55)`
- `scripts/ui/compact_unit_card.gd:594` rgb `Color(0.70, 0.80, 0.95, 0.42)`
- `scripts/ui/compact_unit_card.gd:596` rgb `Color(1.12, 1.12, 1.12, 1.0)`
- `scripts/ui/compact_unit_card.gd:602` rgb `Color(0.55, 0.56, 0.62, 0.72)`
- `scripts/ui/compact_unit_card.gd:604` named `Color.WHITE`
- `scripts/ui/compact_unit_card.gd:775` rgb `Color(0.006, 0.012, 0.020, 0.72)`
- `scripts/ui/compact_unit_card.gd:853` rgb `Color(0.02, 0.03, 0.05, 0.92)`
- `scripts/ui/compact_unit_card.gd:874` rgb `Color(0.0, 0.0, 0.0, 0.55)`
- `scripts/ui/compact_unit_card.gd:1174` named `Color.WHITE`
- `scripts/ui/compact_unit_card.gd:1185` rgb `Color(0.86, 0.32, 0.28, 0.92)`
- `scripts/ui/compact_unit_card.gd:1187` rgb `Color(0.38, 0.82, 0.55, 0.92)`
- `scripts/ui/compact_unit_card.gd:1189` rgb `Color(0.42, 0.66, 0.88, 0.92)`
- `scripts/ui/compact_unit_card.gd:1191` rgb `Color(0.82, 0.40, 0.58, 0.92)`
- `scripts/ui/compact_unit_card.gd:1193` rgb `Color(0.86, 0.66, 0.26, 0.92)`
- `scripts/ui/compact_unit_card.gd:1195` rgb `Color(0.38, 0.82, 0.55, 0.92)`
- `scripts/ui/compact_unit_card.gd:1197` rgb `Color(0.48, 0.78, 0.88, 0.92)`
- `scripts/ui/compact_unit_card.gd:1202` rgb `Color(0.34, 0.52, 0.70, 0.86)`
- `scripts/ui/compact_unit_card.gd:1351` rgb `Color(0.22, 0.55, 0.95, 0.80)`
- `scripts/ui/compact_unit_card.gd:1432` rgb `Color(0.01, 0.015, 0.025, 0.98)`
- `scripts/ui/effect_pip.gd:710` rgb `Color(0.01, 0.015, 0.025, 0.98)`
- `scripts/ui/evolution_screen.gd:12` rgb `Color(0.024, 0.040, 0.060, 0.82)`
- `scripts/ui/evolution_screen.gd:13` rgb `Color(0.036, 0.060, 0.086, 0.92)`
- `scripts/ui/evolution_screen.gd:124` rgb `Color(0.04, 0.09, 0.12, 0.96)`
- `scripts/ui/evolution_screen.gd:154` rgb `Color(0.005, 0.007, 0.012, 0.82)`
- `scripts/ui/evolution_screen.gd:271` rgb `Color(0.022, 0.034, 0.050, 0.95)`
- `scripts/ui/evolution_screen.gd:599` rgb `Color(0.055, 0.070, 0.095, 1.0)`
- `scripts/ui/help_menu.gd:380` rgb `Color(0.06, 0.13, 0.17, 0.98)`
- `scripts/ui/home_screen.gd:111` hex `Color("c25d3f")`
- `scripts/ui/home_screen.gd:112` rgb `Color(0.10, 0.11, 0.07, 1.0)`
- `scripts/ui/home_screen.gd:115` rgb `Color(0.040, 0.050, 0.060, 1.0)`
- `scripts/ui/home_screen.gd:116` rgb `Color(0.13, 0.15, 0.17, 1.0)`
- `scripts/ui/home_screen.gd:117` rgb `Color(0.34, 0.38, 0.42, 1.0)`
- `scripts/ui/home_screen.gd:182` rgb `Color(0.055, 0.070, 0.095, 1.0)`
- `scripts/ui/home_screen.gd:479` rgb `Color(0.035, 0.045, 0.065, 1.0)`
- `scripts/ui/home_screen.gd:479` named `Color.WHITE`
- `scripts/ui/home_screen.gd:700` rgb `Color(0.035, 0.045, 0.065, 1.0)`
- `scripts/ui/home_screen.gd:700` named `Color.WHITE`
- `scripts/ui/home_screen.gd:914` named `Color.WHITE`
- `scripts/ui/home_screen.gd:949` hex `Color("9a6ad0")`
- `scripts/ui/home_screen.gd:1040` rgb `Color(0, 0, 0, 0.72)`
- `scripts/ui/inspect_popup.gd:110` rgb `Color(1.0, 1.0, 1.0, 0.0)`
- `scripts/ui/inspect_popup.gd:438` rgb `Color(1.0, 1.0, 1.0, 1.0)`
- `scripts/ui/intercept_screen.gd:189` rgb `Color(0.022, 0.034, 0.050, 0.95)`
- `scripts/ui/intercept_screen.gd:239` rgb `Color(0.022, 0.034, 0.050, 0.95)`
- `scripts/ui/loadout_menu.gd:121` rgb `Color(1.0, 1.0, 1.0, 0.0)`
- `scripts/ui/loadout_menu.gd:197` rgb `Color(1.0, 1.0, 1.0, 0.0)`
- `scripts/ui/loadout_menu.gd:494` rgb `Color(1.0, 1.0, 1.0, 1.0)`
- `scripts/ui/loadout_menu.gd:533` rgb `Color(1.0, 0.30, 0.30, 1.0)`
- `scripts/ui/loadout_menu.gd:540` rgb `Color(1.0, 1.0, 1.0, 1.0)`
- `scripts/ui/loadout_menu.gd:542` rgb `Color(1.0, 1.0, 1.0, 1.0)`
- `scripts/ui/pattern_background.gd:8` rgb `Color(0.18, 0.35, 0.52, 0.12)`
- `scripts/ui/pattern_background.gd:9` rgb `Color(0.24, 0.48, 0.70, 0.18)`
- `scripts/ui/pattern_background.gd:10` rgb `Color(0.02, 0.06, 0.10, 0.22)`
- `scripts/ui/reward_screen.gd:81` rgb `Color(0.040, 0.050, 0.060, 1.0)`
- `scripts/ui/reward_screen.gd:82` rgb `Color(0.13, 0.15, 0.17, 1.0)`
- `scripts/ui/reward_screen.gd:83` rgb `Color(0.34, 0.38, 0.42, 1.0)`
- `scripts/ui/reward_screen.gd:810` rgb `Color(0.005, 0.007, 0.012, 0.76)`
- `scripts/ui/run_end_screen.gd:237` rgb `Color(0.02, 0.03, 0.05, 0.98)`
- `scripts/ui/spotlight_layer.gd:32` rgb `Color(0.01, 0.015, 0.02, 0.82)`
- `scripts/ui/spotlight_layer.gd:33` hex `Color("6fe0ef")`
- `scripts/ui/spotlight_layer.gd:68` rgb `Color(0.01, 0.015, 0.02, 0.82)`
- `scripts/ui/spotlight_layer.gd:69` hex `Color("6fe0ef")`
- `scripts/ui/spotlight_layer.gd:216` named `Color.WHITE`
- `scripts/ui/title_backdrop.gd:11` hex `Color("0c0d0f")`
- `scripts/ui/title_backdrop.gd:12` hex `Color("111214")`
- `scripts/ui/title_backdrop.gd:13` hex `Color("16171a")`
- `scripts/ui/title_backdrop.gd:14` hex `Color("1d1e21")`
- `scripts/ui/title_backdrop.gd:15` hex `Color("0a0a0b")`
- `scripts/ui/title_backdrop.gd:16` hex `Color("141517")`
- `scripts/ui/title_backdrop.gd:17` hex `Color("1f2023")`
- `scripts/ui/title_backdrop.gd:18` hex `Color("1b1c1f")`
- `scripts/ui/title_backdrop.gd:19` hex `Color("292a2e")`
- `scripts/ui/unlock_screen.gd:368` rgb `Color(0.02, 0.03, 0.05, 0.98)`

</details>

## Textures and icons (filtering, scaling)

Total: **43** sites (project default canvas filter: see project.godot).

| file | sites |
|---|---|
| `scripts/ui/pixel_ui.gd` | 9 |
| `scripts/ui/effect_pip.gd` | 6 |
| `scripts/ui/home_screen.gd` | 6 |
| `scenes/ui/TitleLogo.tscn` | 6 |
| `scripts/ui/compact_unit_card.gd` | 4 |
| `scripts/ui/help_menu.gd` | 4 |
| `scripts/ui/route_fork_screen.gd` | 2 |
| `scripts/ui/spotlight_layer.gd` | 2 |
| `scripts/autoloads/TransitionManager.gd` | 2 |
| `scenes/battle/BattleScene.tscn` | 2 |

<details><summary>Every site</summary>

- `scripts/ui/compact_unit_card.gd:345` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/compact_unit_card.gd:346` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/compact_unit_card.gd:968` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/compact_unit_card.gd:969` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/effect_pip.gd:209` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/effect_pip.gd:210` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/effect_pip.gd:239` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/effect_pip.gd:240` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/effect_pip.gd:258` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/effect_pip.gd:259` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/help_menu.gd:471` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/help_menu.gd:472` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/help_menu.gd:560` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/help_menu.gd:561` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/home_screen.gd:411` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/home_screen.gd:412` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/home_screen.gd:774` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/home_screen.gd:775` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/home_screen.gd:805` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/home_screen.gd:806` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/ui/pixel_ui.gd:914` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/pixel_ui.gd:915` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/pixel_ui.gd:1188` stretch TextureRect.STRETCH_KEEP_ASPECT_COVERED
- `scripts/ui/pixel_ui.gd:1192` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/pixel_ui.gd:1227` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/pixel_ui.gd:1228` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/pixel_ui.gd:1629` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/pixel_ui.gd:1630` stretch TextureRect.STRETCH_KEEP_ASPECT_COVERED
- `scripts/ui/pixel_ui.gd:1667` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/route_fork_screen.gd:177` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/route_fork_screen.gd:180` stretch TextureRect.STRETCH_SCALE
- `scripts/ui/spotlight_layer.gd:167` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/ui/spotlight_layer.gd:168` stretch TextureRect.STRETCH_KEEP_ASPECT_CENTERED
- `scripts/autoloads/TransitionManager.gd:102` stretch TextureRect.EXPAND_IGNORE_SIZE
- `scripts/autoloads/TransitionManager.gd:103` stretch TextureRect.STRETCH_SCALE
- `scenes/battle/BattleScene.tscn:26` expand_mode 1
- `scenes/battle/BattleScene.tscn:27` stretch_mode 6
- `scenes/ui/TitleLogo.tscn:44` expand_mode 1
- `scenes/ui/TitleLogo.tscn:45` stretch_mode 5
- `scenes/ui/TitleLogo.tscn:58` expand_mode 1
- `scenes/ui/TitleLogo.tscn:59` stretch_mode 5
- `scenes/ui/TitleLogo.tscn:72` expand_mode 1
- `scenes/ui/TitleLogo.tscn:73` stretch_mode 5

</details>

### Screens and overlays

| Screen / overlay | Owner | Status before this pass |
|---|---|---|
| Title (MainMenu) | `main_menu.gd`, `title_logo.gd`, `title_backdrop.gd` | restyled (flat pixel B) |
| Persistent header | `PersistentHeader.gd` | restyled |
| Squad select | `home_screen.gd` | partly (tiles, badges, DEPLOY restyled; encounter panel, detail panel, Starting Directive picker old) |
| Starting Directive picker | `home_screen._open_directive_picker` | old (cyan chips, amber modal) |
| Battle: cards, header, footer, tray | `battle_scene.gd`, `compact_unit_card.gd`, `protocol_*` | restyled |
| Battle: die tags, float text, banners | `battle_scene.gd`, `battle_feedback.gd` | partly |
| Battle: Set-die popup, round popups, boss relic confirm | `protocol_actions.gd`, `battle_scene.gd`, `boss_relic_actions.gd` | old |
| Loadout menu + discard picker | `loadout_menu.gd` | old |
| Inspect / long-press popups | `inspect_popup.gd`, `inspect_resolver.gd` | old |
| Keyword primers | `keyword_primer.gd` | old |
| Operation briefing | `operation_briefing_overlay.gd` | partly (accent CHROME, ENGAGE player) |
| State code panel | `state_code_panel.gd` | old |
| Feedback form | `feedback.gd` | old |
| Reward | `reward_screen.gd`, `item_card.gd` | restyled (item_card partly) |
| Route Fork | `route_fork_screen.gd` | old |
| Intercept | `intercept_screen.gd` | old |
| Evolution | `evolution_screen.gd` | old |
| Unlock | `unlock_screen.gd` | old |
| Run End | `run_end_screen.gd` | old |
| Help: Settings tab | `help_menu.gd` | restyled |
| Help: Basics, Units, Battle Log, icon guide, bestiary | `help_menu.gd` | partly (tabs restyled, page bodies old) |
| Tutorial: spotlight, coach, training prompts | `spotlight_layer.gd`, `training_prompt.gd`, `tutorial_controller.gd` | old |

## Phase 2: type system

**Families (two):**

- **m5x7** (`m5x7.ttf`, native em 16): LABEL, BODY, SMALL, NUMERAL. It is the
  only face with lowercase (BODY is sentence case), every reading role already
  uses it, and at x3 (48 design px) one font pixel is exactly one screen pixel
  on a 360 px wide phone: the crispest small text the project can draw there.
  The HP and pip widths in the code are measured with its advance.
- **Battle Block** (`battle_block.fnt`, native 32): DISPLAY only. Its 2 px
  chunky capitals read best as headlines, but it has no lowercase (60 glyphs),
  so it cannot carry reading text. At x3 (96) it is also one bitmap pixel per
  screen pixel at 360 px.
- The dice faces keep their font (m5x7, flat pixel B bold numerals): untouched.

**Roles** (`PixelUI.TYPE_ROLES`, applied with `PixelUI.apply_type(control, role)`):

| Role | Family | Size (design px) | Use | Caps |
|---|---|---|---|---|
| DISPLAY | Battle Block | 96 (x3) | screen titles, the battle header | yes |
| LABEL | m5x7 | 64 (x4); full-width primaries step up the lattice (112 = x7 for DEPLOY / CONFIRM) | buttons, tabs, section headers, unit names | yes |
| BODY | m5x7 | 64 (x4), line spacing 10 | descriptions, help text, the battle log | no |
| SMALL | m5x7 | 48 (x3) | rarity labels, version tag, cost labels, the Protocol label | metadata copy that is already caps (see below) |
| NUMERAL | m5x7 | 64 (x4) on cards; die tags use the x5 rung (80) | HP, intent and pip numbers | n/a |

**Integer multiples only.** `PixelUI.lattice_px(size, family)` snaps a size to
the nearest whole multiple of the family's native size (m5x7 floor 48, Battle
Block floor 64). Every choke point routes through it: `text_px` (was: floor 48,
otherwise raw), `scale_font_size` above its 48/64/80 ladder (was raw x1.35, e.g.
113), `style_battle_text` (Battle Block now snaps to multiples of 32; the header
went 112 -> 96), and the restyled button / tab helper. The EffectPip duration
superscript (its smaller size is its meaning, the text-legibility exemption)
snaps to the lattice with a 32 floor instead of a raw 29.

**Letter spacing:** one rule for every role, the fonts' own advance (no extra
tracking). Glyph spacing in a pixel font must also be whole font pixels; zero is
the only value that is identical on every role and size.

**Applied in this phase:** the battle header and count (DISPLAY, Battle Block
96); battle card names (LABEL, m5x7 64; they were Battle Block 72); battle HP
numbers (NUMERAL, m5x7 64; were Battle Block 72); the footer PROTOCOL label
(SMALL, m5x7 48; was Battle Block 70); every restyled button, tab and toggle
(LABEL); the reward title CHOOSE REWARD (DISPLAY). The other screens take their
roles in Phases 5 to 8; the sizes they pass already land on the lattice through
the choke points.

**Conflict logged:** "caps only for DISPLAY and LABEL" meets the capitalization
law (INVARIANTS #7, Kev 2026-07-14), which puts small metadata labels in ALL
CAPS ("LEGENDARY CONSUMABLE", "ROLL: 1 - 4"). Copy is unchanged and the law is a
ruling, so SMALL keeps caps where the copy is caps; nothing is upper-cased by
the type system except DISPLAY and LABEL helpers.

## Phase 3: color system

**New and changed tokens** (`pixel_ui.gd`, after the role block):

| Token | Value | Role |
|---|---|---|
| `PROTOCOL_ACCENT` | `c4dcff` | electric near-white blue; also the logo core's light centre (the shader reads this token, one source) |
| `WARNING` (= `UI_WARN`) | `e8a33a` | amber warnings; DESTRUCTIVE button. Was rust `e06a3c` |
| `WARNING_INK` | `1a1206` | text on a WARNING fill; the hazard stripes' dark band |
| `RARITY_UNCOMMON` | `aab4bd` | steel / silver (was `UI_STEEL` blue `7f9cb8`). Legendary gold and common gray unchanged |
| `KW_DAMAGE` / `KW_HEAL` / `KW_SHIELD` / `KW_PROTOCOL` | `f2584c` / `5fd17a` / `a9bccb` / = PROTOCOL_ACCENT | keyword colors in text |
| `INK_OUTLINE` | 0.02, 0.03, 0.05, 0.98 | the dark edge on text over art (replaced 14 literals) |
| `SCRIM` | 0.005, 0.007, 0.012, 0.78 | the dim behind modals (replaced 5 literals) |
| `FX_*` (13) | old literal values | battle float text, flashes, particles |
| `PORTRAIT_LIVE / DEAD / CLOAKED`, `CARD_DEAD`, `SILHOUETTE` | old values | portrait and card state tints |
| `PLATE_DARK`, `PLATE_SHADOW`, `SHIELD_PREVIEW`, `READOUT_INK(_STRONG)`, `PIP_BORDERS`, `BATTLE_TICK` | old values | battle card plates, previews, readouts |
| `TITLE_*` (9) | old values | the title's placeholder street palette (was in `title_backdrop.gd`) |

**DESTRUCTIVE button** (`style_ui_destructive_button`): WARNING border and text,
a 24 px hazard-stripe accent down the left edge (4 px diagonal bands, WARNING /
WARNING_INK), no notch. Applied in Phase 5.

**Replaced:** 82 literal sites became tokens (183 literal sites -> 101, of which 76 are the allowed classes) in battle feedback, battle cards,
readouts, effect pips, the header, the battle scene (scrim, minimal buttons,
Protocol labels and the hidden Protocol bar, which now fills PROTOCOL_ACCENT),
Protocol actions, the battle layout, squad select, reward, loadout, run end,
unlock, the bay painter and the title backdrop. Two dead idle-color constant
sets in squad select and reward were removed (`CONFIRM_IDLE_*`) or pointed at
tokens (`DEPLOY_IDLE_*`). The Siphon drift pip (Protocol drained from the bar)
is PROTOCOL_ACCENT now (was gold).

**Audit after Phase 3** (`ui_audit.py --section colors`): 25 real hardcoded
colors left, all on screens restyled in Phases 6 to 8 (Evolution 6, Intercept 2,
Help replay 1, tutorial spotlight 4, the pattern background 3, squad-select
threat pips 2, scene background ColorRects in 5 `.tscn` files, PersistentHeader
`.tscn` 2) plus `DataManager.gd:991`, an image fill used to build placeholder
art (not a UI color). The audit now reports two allowed classes apart:
**opacity** (`Color(1, 1, 1, a)`, `Color.WHITE` / `BLACK` as identity modulates,
fully transparent black: 38) and **dice** (3D dice materials and die base colors
in `dice_tray_3d.gd`, 38; dice colors are constant by rule and the dice
rendering is out of scope).

**Keyword colors: tokens defined, not applied inline.** No text in the game can
take inline color today: every description, help line and primer is a plain
`Label`, and the battle log is a `RichTextLabel` with BBCode off. The brief says
to apply keyword colors only where inline color already exists, so none were
applied; converting the description labels to BBCode is a follow-up.

## Phase 4: Protocol meter and footer

- **Meter** (`protocol_pips.gd`): segmented pixel cells as before; a charged
  cell's interior is `PROTOCOL_ACCENT` (was PLAYER_ACCENT), an empty cell is the
  dark skin alone (`cell.svg`: a `303a41` frame around `181e23`), so empty reads
  as clearly empty. The label is SMALL (m5x7 48, Phase 2).
- **Full-meter pulse:** at 10/10 the charged cells step through
  `PixelUI.PROTOCOL_PULSE_STEPS` (0 / 12 / 24 / 12 % darker) over
  `PROTOCOL_PULSE_PERIOD` 1.6 s: flat tones, no smooth ramp, redrawn only when
  the step changes. Off (steady full brightness) under Reduced Motion and No
  Animations.
- **Footer cost numbers** (1, 2, 4): `PROTOCOL_ACCENT` (were PLAYER light), SMALL
  (48). The footer icons stay PLAYER light (they are the player's actions; the
  number is the Protocol price).
- **Unaffordable actions** keep one rule: the whole button (frame, icon, price)
  at `UNAFFORDABLE_ALPHA` 0.45 opacity, the same for Nudge, Protocol spend and
  Set (`refresh_action_affordability`). The Item button has no Protocol price
  and does not dim for Protocol.
- **"Protocol" in item, relic and help text: not colored.** It needs inline
  color, which no text in the game supports (Phase 3); `KW_PROTOCOL` is ready
  for when descriptions move to BBCode.
- The hidden legacy Protocol progress bar (`protocol_bar`, kept for layout
  code) fills PROTOCOL_ACCENT on a BATTLE_PROTO_EMPTY track (Phase 3).

## Phase 5: components

All in `pixel_ui.gd`; screens get them through the shared helpers.

- **Buttons:** primary `style_ui_primary_button` (PLAYER border and text, the
  notch), secondary `style_ui_secondary_button` (CHROME), disabled (dimmed
  secondary), destructive `style_ui_destructive_button` (WARNING, hazard
  stripes, no notch). Focus on any of them: the PLAYER outline outside the
  button. Labels are the LABEL role.
- **Pop-ups:** a pop-up's main confirm is its primary (the notch sits inside the
  pop-up); a destructive confirm uses the destructive style. Applied on the
  title: the first-run pop-up's RUN TUTORIAL is its primary, the abandon pop-up's
  ABANDON RUN is destructive (flat pixel B had made both secondary). The other
  pop-ups follow in Phases 6 and 7.
- **One border weight:** MIN_STROKE (4 design px), already enforced by
  `min_stroke` for every factory border.
- **One corner treatment, square:** `make_panel_style` ignores its `corner`
  argument (it defaulted to 4 px rounded corners for `style_panel` and
  `style_button` callers). **No four-corner brackets:** `_refresh_corner_brackets`
  only clears (`CORNER_BRACKETS_ENABLED = false`), which removes them from the
  old bracketed primary buttons, the transmission panels, the scene banners,
  route fork and run end. `style_transmission_panel` is a plain CHROME section
  panel now (`UI_PANEL` fill, `UI_PANEL_EDGE` border; was teal `2f6b7a` with cyan
  brackets).
- **Spacing grid:** multiples of 4 design px for new and restyled layout. The
  audit gained a spacing scan (`ui_audit.py --section spacing`): 74 literal
  spacing constants were off the grid at this point; the restyled screens are
  fixed in their phases and the rest in the sweep.
- **Panels, tabs, toggles, sliders, selectable cards, badges:** the restyle A /
  flat pixel B components (`make_ui_section`, `make_ui_row`, `style_ui_tab`,
  `style_ui_toggle`, `style_ui_slider`, `ui_card_style`, `selection_badge_style`).
- **The six components** (`component_style`) follow the ownership rules:
  SELECTED is PLAYER_ACCENT (was cyan); NORMAL hero-tinted is PLAYER_ACCENT_DIM;
  NORMAL plain is the CHROME panel; ENEMY is the current ENCOUNTER_ACCENT
  darkened (was rust); REWARD's default is CHROME_DIM (was amber); MODAL and the
  gold MAJOR tier unchanged.
- **Legacy names follow the direction:** `DT_CYAN`, `DT_CYAN_BRIGHT`,
  `BTN_TEAL_*`, `DT_HERO_BORDER` and `DT_HERO_NAME` now hold the PLAYER family
  (cobalt, not cyan), so the screens that still read them change with no edit.
  `DT_HERO_DITHER` / `DT_ENEMY_DITHER` are untouched (the dice renderer reads
  them). The theme mirror (`theme_overload.tres`) took the same values for its
  Button text and its selected / primary styles.
- **Squad select's encounter panel** previews the enemy side: the boss portrait
  frame, the LV pips and the THREATS label take the selected operation's
  ENCOUNTER_ACCENT (they were rust / CHROME). The site line and the banner frame
  stay CHROME. Empty LV pips are `BATTLE_PROTO_EMPTY`.

Checks: `component_contract.py` PASS, `framing_sites.py` PASS, MainMenu /
UnitSelect / BattleScene load headless clean.

## Phase 6: run flow screens

Rules applied on every screen: the background is `UI_BG`; the screen title is
DISPLAY (Battle Block 96, CHROME, capitals by the role's `uppercase`); eyebrow
labels and section heads are SMALL in CHROME_DIM; card and option titles are
LABEL; panels are the CHROME component; a choice between equals uses secondary
buttons; the one button that commits the screen is the notched primary; no
amber, gold or cyan outside their meanings. Copy, flow and logic are unchanged.

- **Route Fork:** title DISPLAY; DECISION POINT SMALL; both route cards CHROME
  panels; the standard card's title CHROME, the flagged card's title and frame
  in the encounter color (the enemy's risk); REWARD line CHROME (was gold); both
  TAKE buttons secondary (two equal choices, so no single primary; the flagged
  one was an amber variant).
- **Intercept:** title DISPLAY; INTERCEPT SMALL; banner frame CHROME (was amber);
  option boxes CHROME panels; option buttons secondary (were amber-bordered
  legacy buttons); card titles LABEL CHROME (were amber).
- **Evolution:** title DISPLAY CHROME (was gold); branch names and trait titles
  LABEL in PLAYER light (a hero's branches are the player's); trait and HP lines
  CHROME (were amber / gold); roll ranges PLAYER light; VIEW ALL, SELECT, the
  trait CHOOSE and VIEW BATTLEFIELD are secondary; CONFIRM (SELECT A BRANCH
  until a branch is picked) is the notched primary; help dim SCRIM; card fills
  `UI_PANEL` / `UI_ROW` (were literals). **The cards keep the gold MAJOR frame:**
  evolutions are the ceremonial tier by ruling (Polish Build A, "strong gold
  here and ONLY here"); selected cards turn PLAYER through the component.
- **Unlock:** title DISPLAY CHROME (was amber); section heads SMALL CHROME_DIM on
  a plain row plate (were amber on the reward strip); names CHROME (were amber);
  grid emblem plates CHROME_DIM (were amber); CONTINUE is the notched primary.
  The boss relic card keeps the gold MAJOR frame (ceremonial, ruled).
- **Run End:** title DISPLAY, PLAYER light on a win and WARNING on a loss (were
  teal / rust); the summary panel CHROME with that accent's dark border; section
  heads SMALL CHROME_DIM (were amber); the notched primary CONTINUE.
- **Starting Directive picker:** the modal is plain (was amber-accented); its
  title LABEL CHROME (was amber); relic rows CHROME buttons (were cyan) with
  UI_TEXT copy (was cyan bright); NO DIRECTIVE secondary.
- `PersistentHeader` applies `--capture-window=WxH` in debug builds, so every
  capture tool can shoot at 390 px without its own option.

Checks: the five run-flow scenes load headless with no script errors;
`component_contract.py` and `caps_law.py` PASS.

## Phase 7: battle overlays

- **Inspect pop-ups:** an enemy's frame, ability names and ranges are the current
  ENCOUNTER_ACCENT, a hero's PLAYER_ACCENT (`inspect_resolver._side_accent`, was
  rust / steel-cyan); the title is LABEL (capitals: intel-popup titles are page
  headings by the caps law); the roll column follows the side accent (was
  cyan); "Tap anywhere to close" is SMALL.
- **Loadout menu:** title LABEL CHROME; usable-relic notes PLAYER light (were
  amber).
- **Discard picker:** title LABEL in WARNING (a warning; was DT_AMBER); the
  INCOMING card a plain reward component with a SMALL CHROME_DIM label (was
  amber); **CONFIRM DISCARD is destructive** (it destroys a held item; was a
  cyan legacy button) and ABANDON is secondary (it keeps all four).
- **Briefing:** the deployment title CHROME (was cyan), SITUATION in the encounter
  color (was rust); the boss alert's title and rule line in the encounter color
  (were rust); **ENGAGE is the pop-up's notched primary** on both. **Layout fix:**
  the boss alert sized itself to its longest unwrapped line and ran off a 390 px
  screen; the slate now has the deployment grid's width plus padding and its
  labels wrap.
- **State code panel:** title LABEL CHROME (was cyan); CLOSE the pop-up's primary.
- **Primers and the coach** (`spotlight_layer.gd`, shared with the tutorial): the
  ring and the "Continue" hint PLAYER light (were cyan literals), the dim is
  SCRIM, the hint SMALL.
- **Battle pop-ups:** the leave-battle dialog's KEEP PLAYING is its primary and
  ABANDON is destructive (was an amber legacy button); the round-complete NEXT is
  the primary (it still used the old yellow sci-fi texture button); the Set-die
  CONFIRM and Heretic Signal's RE-THROW are their pop-ups' primaries, its
  CANCEL secondary (CANCEL was the bracketed primary).
- **Training prompts:** heading LABEL, body BODY; the first choice is the
  primary, the rest secondary; the shade is SCRIM.
- New harness `scripts/debug/overlay_capture.gd` (briefing, boss alert, discard,
  state code): it loads the overlay scripts at run time, because
  `operation_briefing_capture.gd` no longer compiles under `--script` (it
  preloads the overlay, which names the AudioManager autoload).

`battle_scene.gd` is 3,638 lines (watermark 3,640). `component_contract.py` and
`caps_law.py` PASS; BattleScene loads headless clean.

## Phase 8: Help and tutorial

- **Help pages** (Basics, Units with its operation sub-tabs, Battle Log, the icon
  guide and bestiary that live on them): tabs and sub-tabs are the shared tab
  component (active PLAYER); section headers are LABEL; bullets and keyword
  definitions BODY (m5x7 64, line spacing 10; sizes were already on the lattice
  through the choke points); hero rows in the Units list take the player's
  resting frame and a LABEL name in PLAYER light (were cyan frames and CHROME
  names); bestiary enemy rows keep the enemy rust frame and a CHROME name (Help
  has no current encounter to borrow a color from); REPLAY TUTORIAL is
  secondary (was a cyan legacy button with a literal fill). The Settings tab was
  restyled in flat pixel A/B.
- **Tutorial:** frames, highlights and prompts only. The coach card is the MODAL
  component, the spotlight ring and the "Continue" hint PLAYER light, the dim
  SCRIM (Phase 7, `spotlight_layer.gd`, shared with primers); training prompts
  use LABEL / BODY and the primary / secondary buttons (Phase 7).
  `tutorial_controller.gd` and the training flow carry no colors of their own.
  Scripted logic, rolls, step order and copy are untouched.

## Phase 9: pixel grid and sweep

**Textures and icons.** The Phase 1 list has no texture drawn with a LINEAR or
mipmapped filter set in code or scenes. Every icon TextureRect on it (pips,
help icons, squad-select icons, the coach glyph, card status icons, the route
banner) already sets NEAREST, the item art goes through `make_integer_icon`
(integer multiples, enforced by `framing_sites` and `reward_model_test`), and
portraits through the shared portrait frame (a cover fit by design, ruled).
**Not integer-scaled, reported:** the UI icons are 128 px art shown in 44-64 px
boxes (`STRETCH_KEEP_ASPECT_CENTERED`, NEAREST), a non-integer downscale; a clean
fix is 32 / 64 px icon variants (an art task). The title logo (1588 px art) and
the battle starfield are scaled the same way, by design.

**Re-run of the Phase 1 searches** (`ui_audit.py`):

- **Hardcoded colors: 1 real left**, `DataManager.gd:991`, a black / transparent
  image fill used to build placeholder art (data, not a UI color; it stays).
  The allowed classes: opacity 37, dice 38. Fixed in this phase: the five
  scenes' Background / Divider `.tscn` color values (their scripts already set
  them from tokens in `_ready`, so the values were dead and are removed) and
  the pattern background's blue grid defaults (now `PATTERN_GRID`,
  `PATTERN_GRID_MAJOR`, `PATTERN_SCANLINE`, neutral steel).
- **Off-system fonts: none.** Only m5x7 and Battle Block are loaded; every size
  choke point lands on the lattice. The last raw sizes off it were fixed: the
  coach label in training presentation (60 -> BODY 64) and the footer Protocol
  label constants (60 and 70 -> SMALL 48). The dice faces keep their own
  Label3D sizes (out of scope by rule).
- **Spacing:** 40 literal spacing constants rounded to the 4 px grid in the
  restyled overlay and run-flow files (evolution, help, inspect, item card,
  loadout, briefing, run end, spotlight, unlock). **34 remain, on purpose,** in
  files whose layout is pinned by measured contracts: the battle card
  (`compact_unit_card.gd`, 11: 1-2 px insets inside the card's measured
  geometry), the battle scene, Protocol and boss-relic actions (4), reward (12,
  `reward_model_test` geometry) and squad select (7, the frozen composition and
  the DEPLOY clearance). They want their own pass with those tests.

Checks: `text_legibility_test` PASS (232 text nodes), `reward_model_test` PASS,
`panel_count_test` PASS; the touched scenes load headless clean.

## Phase 10: style doc

`docs/UI_STYLE.md`: the reference for future UI work. Ownership rules, the color
token table with hex and role, the type roles, the components, the notch rule,
the Protocol color rule, the spacing grid and pixel-grid rules, keyword colors.

## Phase 11: verify

- **Boot / smoke:** every touched screen and overlay was captured at 390x867
  with no script errors in any log (26 captures plus the primer sequence), and
  MainMenu, UnitSelect, BattleScene, RewardScreen, RouteFork, Intercept,
  Evolution, Unlock and RunEnd load headless clean.
- Related gates run because font sizing and components changed system-wide:
  `text_legibility_test` (232 text nodes), `reward_model_test`,
  `panel_count_test`, `component_contract.py`, `caps_law.py`,
  `framing_sites.py`: all PASS.
- Dice rendering and physics untouched: no dice gates, no `verify_gate.py`, no
  build or itch package.

## Final report

**Deliverables** (390 px, `debug_artifacts/ui_unify/`, gitignored): `title`,
`squad_select`, `route_fork`, `intercept`, `evolution`, `unlock`, `run_end`,
`run_end_defeat`, `directive_picker`, `loadout`, `inspect_enemy`, `inspect_hero`,
`primer`, `discard_picker`, `briefing`, `briefing_boss`, `state_code`,
`help_basics`, `help_units`, `help_battle_log`, `help_settings`, `tutorial`,
`footer_4`, `footer_10`, `reward`, `battle`.

**Fonts chosen and why:** m5x7 for LABEL, BODY, SMALL and NUMERAL (full charset
with lowercase; at x3 = 48 design px it lands one font pixel per screen pixel on
a 360 px phone, the crispest reading text available; the code already measures
pip widths with it). Battle Block for DISPLAY only (chunky capitals for titles
and the battle header; no lowercase, so it cannot carry reading text; 96 = x3).
All sizes are whole multiples of the native size; the dice faces are untouched.

**Remaining hardcoded colors or fonts:** one color, `DataManager.gd:991` (an
image fill for placeholder art, not UI). Allowed classes reported apart: 37
opacity-only modulates, 38 dice materials. No off-system fonts.

**Could not do / decisions to review:**

- **Keyword colors and "Protocol" in text are not applied:** no text in the game
  supports inline color (plain Labels; the battle log's BBCode is off). Tokens
  `KW_*` are ready; a BBCode conversion of description labels is the follow-up.
- **"Caps only for DISPLAY and LABEL"** conflicts with the capitalization law
  (metadata labels are ALL CAPS by ruling); SMALL keeps caps where the copy has
  them.
- **Gold kept** on the evolution cards and the unlock boss relic card: the
  major-event tier is ruled ceremonial gold.
- **Icons are not integer-scaled** (128 px art in 44-64 px boxes, NEAREST);
  needs 32 / 64 px variants.
- **34 off-grid spacing constants remain** in measured-layout files (battle
  card, battle scene, Protocol / relic actions, reward, squad select).
- **Battle card names and HP moved from Battle Block to m5x7** (LABEL /
  NUMERAL), and the battle header shrank 112 -> 96: the type rules. Easy to
  revisit if the chunkier battle lettering is preferred.
- `operation_briefing_capture.gd` no longer compiles under `--script`; replaced
  by `overlay_capture.gd`.

**Still off-style:** Help's bestiary enemy rows keep the enemy rust (no
encounter context in Help); squad select's DEPLOY sits in a panel whose default
theme border draws a thin dark ring; the old `style_button` helper still serves two
callers (the Starting Directive relic rows, which carry an icon layout, and
the battle scene's minimal action buttons) with token colors but the legacy
shape (Help's BACK / reference / MORE and the Set-die CANCEL were moved to
secondary in the last commit); the F9 v3 perspective path keeps its encounter-colored walls
by design; float text and battle FX keep their pre-existing palette (now
tokens, not re-designed).

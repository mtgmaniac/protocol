# UI restyle

## Batch A: shared theme, Title, Help/Settings, Reward (2026-10-14)

Branch `proto/ui-restyle-a`, from `proto/battle-depth-v3` (`80296e3`). Rendering and
UI only. TRUTH.md and DECISIONS_RESOLVED.md are not edited; this file is the record.
`assets/fonts/battle_block.svg.import` stays out of every commit.

References: `debug_artifacts/ui_restyle/mock_title.png`, `mock_settings.png`,
`mock_reward.png` (AI mockups; layout, hierarchy, palette and components were matched,
content was not copied).

### Shared theme (scripts/ui/pixel_ui.gd)

**Tokens.** `UI_ACCENT` (#edb03e, sampled from the mocks) is the one amber; every
amber on the restyled screens comes from it. The charcoal family beside it:
`UI_BG`, `UI_PANEL`, `UI_PANEL_EDGE`, `UI_ROW`, `UI_BUTTON`, `UI_LINE`,
`UI_CARD_LINE`, `UI_RULE`, `UI_BAR`, `UI_TRACK`, `UI_TEXT`, `UI_TEXT_DIM`,
`UI_TEXT_OFF`, `UI_ACCENT_INK` (dark text on amber), `UI_STEEL`, `UI_WARN`.

**Rarity tokens:** `RARITY_LEGENDARY` = `UI_ACCENT`, `RARITY_UNCOMMON` = `UI_STEEL`,
`RARITY_COMMON` = `UI_TEXT_DIM`. Rare/epic stay purple. These are the shared rarity
tokens, so every screen that colors by rarity (inspect popups, loadout, intercept)
now shows the new colors too.

**Warnings stay distinct from the accent.** `UI_WARN` (#e06a3c) is a rust
orange-red, a clearly different hue from the amber accent (about 15 degrees
against 38). It is used for warning TEXT only (the discarded-save notice,
the resume-guard line, the private-browser notice, the ABANDON RUN? title) and
never on a button frame, so amber still means "act here" and red-orange "careful".

**Components** (all strokes `MIN_STROKE` = 4 design px; the mocks' 2 px border is
4 design px, which is the stroke law's floor and reads as 1-2 px at phone size):

- `style_ui_primary_button`: dark fill, amber border, a thicker amber left edge, and
  ONE notched tab on the top-left edge (a nine-patch texture, so the tab keeps its
  size at any button width). Pressed inverts to an amber fill.
- `style_ui_secondary_button`: dark fill, gray border, a thin lighter bar on the
  left edge, light text.
- Disabled: the secondary shape with border, bar and text dimmed. Both button
  styles use it for their `disabled` state.
- `style_ui_tab`: boxed tab; active is solid amber with dark text, inactive dark
  with gray text. Equal widths come from the container.
- `make_ui_section` + `make_ui_row`: a dark panel, header in large pixel caps, a
  thin gray rule, rows on a lighter plate.
- `style_ui_toggle`: ON is an amber outline with amber text, OFF gray outline and
  gray text.
- `style_ui_slider`: amber filled track, dark empty track, amber rectangular thumb.
- `ui_card_style`: selectable card, gray border at rest, amber border over a faint
  amber fill when selected. `ui_art_frame_style` is the square frame around item
  art.
- `make_art_grid_view`: the v3 battle scene's quarter-res, 4x NEAREST pixel grid,
  as a shared helper for placeholder backdrops.
- `accent_tint_material`: recolors the title logo's core and PROTOCOL line into
  `UI_ACCENT`.

All text uses the pixel font.

### Title (scripts/ui/main_menu.gd, title_logo.gd, title_backdrop.gd)

- **Backdrop:** a full-bleed PLACEHOLDER backdrop on the shared pixel grid
  (`title_backdrop.gd`, drawn in code): a dark street, tall slabs both sides, a rust
  panel on the right with a faint stenciled "4" and chevrons, rubble and broken
  girders along the bottom, a few dim windows in `UI_ACCENT` darkened.
- **Logo:** same layers and animation. The core and PROTOCOL line are recolored to
  `UI_ACCENT` by a shader that keys only the logo's saturated teal pixels, so
  VERLOAD stays gray.
- **Menu:** one column of equal-width (640) buttons.
  - The primary button is CONTINUE when a run is saved, otherwise BEGIN. A screen
    with no primary looked wrong, so BEGIN is primary on a fresh profile (decision
    taken here; easy to flip).
  - BEGIN with a saved run, FEEDBACK, ABANDON RUN and RESUME EARLIER POINT are
    secondary.
  - Visibility rules are unchanged: ABANDON RUN still appears only with a run (it
    is never shown disabled). The disabled style shows while the logo boots.
- **Version tag:** bottom-left in dim text with a short `UI_ACCENT` underline. The
  seven-tap dev unlock is unchanged.
- **Modals:** the first-run and abandon modals use the new buttons; the abandon
  title is `UI_WARN`.

### Help / Settings (scripts/ui/help_menu.gd)

- **Tabs:** existing tabs and order (BASICS, UNITS, BATTLE LOG, SETTINGS) use the
  tab component. The close X is an inactive tab box. The in-page sub-tabs (icon
  guide, bestiary factions) share it.
- **Settings:** every existing setting in section panels with row plates, toggles
  and sliders. Wording and behavior are unchanged; descriptions moved into their
  row under the label. SEND FEEDBACK is a full-width primary button; the version
  tag is at the bottom. Dev and Debug sections use the same panels.
- **Help-wide colors:** section headers are `UI_TEXT`, bullets and terms
  `UI_ACCENT`, and the scrollbar is gray with an amber active grab.

### Reward (scripts/ui/reward_screen.gd)

- **Title:** CHOOSE REWARD in large `UI_ACCENT` pixel caps.
- **Offers:** each ordinary offer is a selectable card: the CURRENT item art through
  the existing shared framing (`make_integer_icon`, unchanged) inside a square frame,
  then the name, the rarity + type label in its rarity color, and the effect.
- **Selection:** shown by the amber border and fill; the old cyan corner brackets
  are hidden.
- **Relic offers:** keep their ceremonial layout with a dimmed-accent frame, and use
  the same selected state.
- **CONFIRM:** the full-width primary at the bottom when armed. "SELECT AN ITEM" is
  the disabled style.
- **Other buttons:** VIEW BATTLEFIELD and the gear-equip chooser buttons are
  secondary.
- Offers, names, descriptions, logic and copy are unchanged.

### Bug found and fixed on the way

The reward screen's header band rendered **pure white**. `PersistentHeader._draw_battle_frame`
built its strip style inside the draw callback; the style and its texture were freed
before the queued draw ran. In battle something else holds the same texture, so it
only showed off the battle screen. Same bug class as the Protocol cells (`aaed29a`);
fixed the same way (the style is held on the node).

### Mock features we lack (reported, not added)

- **Settings:** none. Every setting the settings mock shows already exists here
  (separate DICE and UI volume, No animations, Auto-select sole valid target,
  One-time ability tips, and the BATTLE LOG tab). We also have one the mock lacks:
  "Mute all audio". Nothing was added or removed.
- **Reward:** the mock's button reads SELECT REWARD; ours keeps CONFIRM / SELECT AN
  ITEM (copy unchanged). The mock puts CHOOSE REWARD at the top; ours keeps the
  existing centered heading-plus-cards group (pinned by `reward_model_test` T10).
  The mock's item art was not used.
- **Title:** the mock has no header buttons; ours keeps "?" and back (the shared
  PersistentHeader, not restyled: it is global chrome).

### Needs a ruling or a copy decision

- **The reward screen's help overlay copy is now wrong.** It says "The selected
  reward lights up cyan." and "Border color = rarity; the boxed word = type."
  Selection is now amber and rarity is the label color. Copy was not changed;
  it needs new lines or a decision.
- **INVARIANTS #7 conflicts.** The restyle follows Kev's brief, so the conflicts are
  logged here for a ruling:
  - The six-component frame rule: the new buttons, tabs, sections, toggles and
    cards are new frame styles.
  - "Strong gold only on major_event": the amber primary border and the selected
    card.
  - "Selection is cyan": reward selection is now amber, while squad select and
    battle still select in cyan.
  - The 2026-07-10 orange legendary is now amber.

  `component_contract.py` still passes: all styleboxes are built in PixelUI and no
  strong token is passed to a factory.

### Screens still on the old style (batch B)

- Squad select / home (`UnitSelect.tscn`, `home_screen.gd`), Route Fork, Intercept,
  Evolution, Unlock, Run End.
- The battle screen (cards, footer, loadout menu, protocol actions, boss relic
  actions), inspect popups, keyword primers, training prompts and the tutorial,
  the operation briefing overlay, the state code panel, the discard picker.
- The shared PersistentHeader buttons.
- The modal frames on title prompts (their buttons are restyled).
- Help's non-settings page bodies (Basics/Units/Battle Log text, reference rows,
  BACK TO BASICS and other in-page buttons): colors only, no structural restyle.

### Checks

- Boot: MainMenu, RewardScreen and BattleScene load headless with no script errors.
- Smoke: every deliverable capture ran with no script errors.
- `component_contract.py`: PASS. `caps_law.py`: PASS. `git diff --check`: clean.
- No verify_gate and no dice gates, as asked.

### Deliverables (390 px, debug_artifacts/ui_restyle/)

- `title_continue.png` (saved run present) and `title_fresh.png` (no run).
- `help_settings.png` and `help_basics.png`.
- `reward.png`: Combat Cogitator selected. A legendary consumable is used because
  selecting a gear offer opens the existing equip chooser, which hides the
  selected card.

New capture options: `main_menu_capture.gd` `--capture-window=WxH`,
`--capture-run-save`; `reward_screen_capture.gd` `--capture-window=WxH`.

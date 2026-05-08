# Battle UI V2 Spec

This document is the current battle UI contract for Overload Protocol.

It is no longer just a rebuild wish list. It now reflects the real
implementation path, the real runtime owners, and the constraints we have
validated during the current Godot 4 port.

This file should be treated as the living reference for:

- battle layout structure
- shared battle-screen visual language
- card ownership and runtime sizing
- dice/readout placement rules
- battle header/footer consistency
- debug and verification workflow

## 1. Platform and Viewport

- Primary target: portrait phone
- Internal design baseline: `1080x2400`
- Desktop preview window: `450x1000`
- Stretch mode: `canvas_items`
- Orientation: portrait
- Battle is touch-first
- No battle scrolling

Important implication:

- `450x1000` is the desktop preview for the `1080x2400` authored layout
- preview scale is approximately `0.4167x`
- logical sizes that look reasonable in code may still read too small on the
  real preview if they are not proportioned for that scale

## 2. Real Runtime Owners

The battle UI has two card systems in the repo, but only one is live.

### Active battle card owner

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Battle creates cards directly with:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)

using:

- `CompactUnitCard.new()`

### Legacy authored scene

- [UnitCard.tscn](C:/Users/Kev/Documents/protocol/scenes/shared/UnitCard.tscn)

This older scene exists, but it is not the live owner for the current battle
screen. It should not be treated as the source of truth for battle card
structure unless battle is explicitly rewired to use it again.

## 3. Global Theme Source

Battle styling should now reference the global theme autoload:

- [Theme.gd](C:/Users/Kev/Documents/protocol/scripts/autoloads/Theme.gd)

Available shared color constants:

- `Theme.VOID`
- `Theme.PANEL`
- `Theme.RAISED`
- `Theme.CYAN`
- `Theme.RED`
- `Theme.PROTOCOL_GREEN`
- `Theme.GOLD`
- `Theme.HP_GREEN`
- `Theme.DMG_RED`
- `Theme.MUTED`
- `Theme.BORDER_PLAYER`
- `Theme.BORDER_ENEMY`
- `Theme.BORDER_PROTOCOL`

Important note:

- In scripts, `Theme` can collide with Godot's built-in `Theme` type
- when a script needs theme constants at compile time, prefer:
  - `const UiTheme = preload("res://scripts/autoloads/Theme.gd")`

## 4. Shared Battle Header

All in-match screens should share one header scene and one placement model.

Shared header scene:

- [BattleHeader.tscn](C:/Users/Kev/Documents/protocol/scenes/shared/BattleHeader.tscn)

Current intended screens using the shared header:

- battle
- reward selection
- evolution selection

Header rules:

- same structure on every in-match screen
- same top position on every in-match screen
- same button set and button size
- same title line treatment

Current title behavior:

- operation name on the left
- battle counter directly after it on the same line
- example: `FACILITY  1/10`

## 5. Current Battle Background

Battle now uses an imported starfield background texture, not the old grid:

- [starfield_background.png](C:/Users/Kev/Documents/protocol/assets/ui/starfield_background.png)

Rules:

- faint deep-space backdrop only
- no grid overlay
- no scanline treatment
- no bright visual competition with cards, dice, or pips

## 6. Current Battle Shell

Battle is still organized as five major vertical bands:

1. Header
2. Enemy rail
3. Center combat zone
4. Hero rail
5. Footer

Current important runtime shell values live in:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)

Examples include:

- `BAR_HEIGHT`
- `CENTER_ZONE_HEIGHT`
- `CARD_ZONE_HEIGHT`
- `COMPACT_CARD_WIDTH_PX`
- `COMPACT_CARD_HEIGHT_PX`
- `COMPACT_READOUT_HEIGHT_PX`
- `COMPACT_DICE_ANCHOR_HEIGHT_PX`

These are the real geometry owners now, not older sketch-era values.

## 7. Current Card Structure

The live battle card built by `CompactUnitCard` is:

1. Name row
2. Portrait region
3. HP region
4. Optional action pip region
5. Status region

Current node structure inside [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd):

- card root (`PanelContainer`)
  - margin
    - root `VBoxContainer`
      - `NameLabel`
      - `PortraitFrame`
        - `PortraitCrop`
          - `PortraitRect`
      - `HPBack`
        - `HPFill`
        - `HPLabel`
      - `ActionPanel`
        - `ActionMargin`
          - `ActionGrid`
      - `StatusSlot`
        - `StatusTint`
        - `StatusDivider`
        - `StatusMargin`
          - `StatusRow`

## 8. Card Visual Language

Current intended battle card language:

- flat, low-detail, readability-first
- no ornate sci-fi beveling on the active battle cards
- thin border only
- clinical corners
- portrait remains the dominant emotional element
- HP/status bands must be visible enough to read on a phone

Player card styling:

- surface: `Theme.PANEL`
- border: `Theme.BORDER_PLAYER`
- unit name: `Theme.CYAN`

Enemy card styling:

- surface: `#120808`
- border: `Theme.BORDER_ENEMY`
- unit name: `Theme.RED`

Targeting state:

- targetable cards still use the cyan targeting highlight

## 9. Current Card Proportion Rules

The major lesson from recent debugging:

- the card layout structure can be correct while the proportions are still wrong

Because the project previews at `0.4167x`, fixed bands that look acceptable in
logical units can still become visually negligible on screen.

Current direction:

- larger fixed bands
- reduced total card height
- smaller portrait share of the total card

This is the current logical split owner:

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)
- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)

## 10. Portrait Sizing Rules

Portraits are manually transformed in:

- `_update_portrait_size()`
- `_update_portrait_rect_transform()`

Important lessons learned:

- portrait minimum height must not be derived only from the locked logical card
  height
- `_locked_layout_size.y` can be much larger than the card's actual rendered
  on-screen size at preview scale
- `size.y` is the more trustworthy source once the card has a real layout

Current portrait behavior goals:

- heroes and enemies share the same card shell
- hero portraits can use slightly different crop scaling
- top of head should sit near the top of the portrait frame
- portrait should not visually consume the whole card after fixed bands are
  accounted for

## 11. HP Region Rules

Current HP region design direction:

- HP band should be clearly visible on a phone
- HP text should be readable against the bar color
- unresolved incoming damage should be shown as a red segment on the same bar

Current owner:

- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Important implementation notes:

- `HPBack` is the band container
- `HPFill` is the visible filled bar
- `HPLabel` is an overlay child of `HPBack`
- increasing `HPBack` height alone is not enough if `HPFill` remains thin

## 12. Status Region Rules

Status region goals:

- visible enough to matter
- not heavy or boxed
- integrated into the lower card
- readable at phone scale

Status region is owned in:

- `StatusSlot`
- `StatusRow`
- status chip helpers inside [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)

Current styling direction:

- subtle to transparent banding only
- no ornate panel chrome
- status text uses the gold accent family

## 13. Ability Readouts

Ability readouts are separate from the cards.

Owner:

- [ability_readout.gd](C:/Users/Kev/Documents/protocol/scripts/ui/ability_readout.gd)

Current rules:

- pips are hidden before roll resolution
- pips are revealed together after dice resolution
- no gold box around the full row anymore
- no individual pip capsule frames anymore
- no gold underline anymore
- pips sit close to the dice, not stuck to the cards
- readout can break to two rows when needed

Known active concern:

- two-row readability and clipping must always be judged from screenshots, not
  assumed from constants alone

## 14. Dice and Dice Anchoring

Battle dice behavior is owned by:

- [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)

Presentation and placement integration are owned by:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)

Current behavior:

- dice wait until the final die settles
- then all snap into presentation together after a short delay
- resolved dice scale down from roll size
- readouts sit inward toward the dice
- frozen dice should remain physical blockers
- visible combat-zone edges should behave like hard bounds for rolling dice

Important rule:

- do not treat old decorative tray art as the source of truth for physics bounds
- the actual visible combat zone is the important reference

## 15. Footer

Current footer direction:

- simpler than earlier ornate versions
- protocol on the left
- action buttons on the right

Footer currently includes:

- protocol display
- reroll / nudge / item-adjacent actions depending on current pass

Protocol art:

- uses the newer left-side protocol footer bar artwork
- protocol lights up as points are gained
- battle protocol is capped at `7`

## 16. Interaction Rules

Current live interaction expectations:

- tapping a hero card behaves the same as tapping that hero's die
- tapping an enemy card behaves the same as tapping that enemy's die
- targeting highlight must remain visible even when default card coloring is
  simplified
- unit detail can be opened from the portrait press/hold path

## 17. Debug and Verification Workflow

Current reliable capture path:

- [battle_ui_capture.gd](C:/Users/Kev/Documents/protocol/scripts/debug/battle_ui_capture.gd)

Primary output:

- [latest.png](C:/Users/Kev/Documents/protocol/debug_artifacts/battle_ui/latest.png)

Verification rule:

- do not claim an improvement unless the screenshot plainly shows it

This matters because several layout issues in this project have looked
"theoretically fixed" in code while remaining visually unchanged on screen.

## 18. Known Truths Learned During This Pass

These are the battle UI lessons that should not be relearned from scratch:

- the live battle card is `CompactUnitCard`, not the old `UnitCard.tscn`
- `_locked_layout_size` can mislead portrait sizing if used without the actual
  resolved `size.y`
- `HPBack` height and `HPFill` height are separate concerns
- the preview window scale can make "reasonable" logical values unreadable
- container structure can be correct while proportions are still wrong
- screenshot verification is mandatory for card readability work
- battle layout owners and card internal owners must stay separated

## 19. Current Open Tuning Areas

These are still active tuning areas and should be treated as ongoing work:

- final card proportion balance between portrait / HP / status
- exact phone-readable unit-name sizing
- exact HP-number readability over the HP bar
- final status-region density and clarity
- readout overflow behavior in the most complex two-row cases
- final button/header/footer polish after the readability pass is stable

## 20. Editing Rules Going Forward

When adjusting battle UI from here:

1. identify the real owner first
2. make one class of change at a time
3. capture a fresh screenshot
4. judge the screenshot, not the intention

For card problems specifically:

- change card proportions in:
  - [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)
  - [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)
- do not assume the old scene file is active
- do not assume a compile success means a visual success

# Battle UI V2 Spec

This document is the rebuild contract for the battle screen presentation layer.

It is intentionally simple. The goal is to stop improvising layout in code and
to give the next battle UI pass one clear geometry target.

## 1. Viewport and Platform Target

- Primary target: modern portrait phone
- Internal design baseline: `1080x2400`
- Desktop preview window: `450x1000`
- These share the same aspect ratio and should be treated as equivalent layouts
  at different scales
- No scrolling in battle
- Touch-first sizing rules apply

This spec overrides older battle UI ambiguity. Battle UI V2 is portrait-first.

## 2. Core Design Rules

- Header and footer are fixed-height rows
- Header height and footer height must be exactly the same
- All unit cards are exactly the same outer size
- Hero and enemy card structure is identical
- Dice align to card slots, not to arbitrary free space
- Readouts live in a dedicated strip outside the cards
- The center action button is exactly centered on screen
- Footer controls use a reduced set of actions:
  - `Reroll`
  - `Nudge`
  - `Item`
- The `Item` button opens an item menu instead of showing many separate item
  slots on the footer row

## 3. Vertical Layout Bands

Battle UI V2 is built as five stacked bands:

1. Header
2. Enemy rail
3. Center rail
4. Hero rail
5. Footer

### Baseline Heights at 1080x2400

- Header: `144 px`
- Enemy rail: `768 px`
- Center rail: `432 px`
- Hero rail: `768 px`
- Footer: `144 px`
- Total: `2256 px`

The remaining `144 px` is reserved for outer safe-area padding and inter-band
breathing room.

### Preview Heights at 450x1000

- Header: `60 px`
- Enemy rail: `320 px`
- Center rail: `180 px`
- Hero rail: `320 px`
- Footer: `60 px`
- Total: `940 px`

The remaining `60 px` is reserved for top/bottom padding and small band gaps.

## 4. Outer Safe Area and Gaps

At `450x1000`:

- Outer page padding: `8 px`
- Gap between major bands: `6 px`

At `1080x2400`:

- Outer page padding: `18 px`
- Gap between major bands: `14 px`

These values may scale slightly, but the overall relationship should stay
stable. Do not use content-driven resizing to invent extra gaps.

## 5. Header

Header is one fixed-height horizontal row.

### Header contents

- Left side: battle label only
  - Example: `Facility Sweep   Battle 1/10`
- Right side: square icon buttons

### Header button set

- Help
- Auto turn
- Auto battle
- Back

### Header rules

- All header buttons must be exactly the same size
- Button size must match footer button size
- Header text must remain single-line
- Header must never grow taller because of text wrapping

## 6. Footer

Footer is one fixed-height horizontal row.

### Footer contents

- Protocol label and value
- Protocol progress bar
- `Reroll` button
- `Nudge` button
- `Item` button

### Footer rules

- Footer buttons must be the same size as header buttons
- Footer is one row only
- No wrapping
- No second line
- No overflow off the screen edge
- The `Item` button opens an expandable menu or overlay instead of placing many
  separate item buttons in the footer itself

## 7. Enemy Rail

Enemy rail has three sub-rows:

1. Enemy card row
2. Enemy readout row
3. Enemy dice row

### Enemy rail rules

- Supports 1, 2, or 3 active units
- Units are centered within the three-slot system
  - 1 unit uses the center slot
  - 2 units use the left-center and right-center positions
  - 3 units use all three slots
- Each die is centered on its corresponding slot
- Readouts sit in a dedicated strip below the cards and above the dice

## 8. Hero Rail

Hero rail has three sub-rows:

1. Hero dice row
2. Hero readout row
3. Hero card row

### Hero rail rules

- Supports 1, 2, or 3 active units
- Units are centered within the same three-slot system as enemies
- Each die is centered on its corresponding slot
- Readouts sit in a dedicated strip above the cards and below the dice

## 9. Card Slot Grid Rules

The battle layout always uses three logical columns for both hero and enemy
rails.

### Slot behavior

- Three equal slot columns exist in the rail
- A unit card is placed only in a used slot
- Empty logical slots are invisible and should not draw placeholder frames
- Dice and readout alignment still references the logical slot positions

This keeps 1-unit and 2-unit fights centered without changing card sizes.

## 10. Unit Card Internal Structure

Every unit card uses exactly this internal structure:

1. Name row
2. Portrait area
3. HP bar
4. Status pip area

### Card rules

- All cards share the same width and height
- Enemy cards and hero cards use the same layout rules
- Portrait crop behavior is the same for hero and enemy
- Status pips live inside the card in their own reserved area
- Readout text does not live inside the card

## 11. Readout Strip

The readout strip is intentionally separate from the card.

### Readout rules

- One dedicated row per side
- Fixed row height
- May change later without forcing a card redesign
- Should be simple and compact in the first rebuild
- Must align with the same three logical slots as the dice and cards

## 12. Center Rail

The center rail contains the battle action focus.

### Center contents

- Empty space for visual breathing room around dice
- Centered `Roll` / `Select Targets` / `End Turn` button

### Center rules

- The action button sits exactly in the vertical and horizontal center of the
  center rail
- The center rail must not become so large that it starves the card rails
- The center rail must not be so small that the dice feel cramped

## 13. Dice Placement Rules

- Dice are not sized from card content
- Dice are not positioned by measuring card internals
- Dice align to the three logical slot centers
- Dice should be the visual focal element during roll resolution
- Card height must never expand in a way that pushes dice out of their intended
  rail

## 14. Ownership Rules

This is the most important part of the rebuild.

### Scene file owns

- Shell structure
- Band order
- Fixed band sizes
- Major containers

### Battle scene controller owns

- Which slots are occupied
- Which cards/readouts/dice appear in each logical column
- Runtime data binding
- Phase-based button label changes

### Unit card script owns

- Internal card composition only
- Name, portrait, HP, status pip layout only

### Dice tray owns

- Dice rendering
- Dice physics
- Dice visual presentation

### No cross-ownership allowed

The following must not be set in multiple layers:

- `custom_minimum_size` for the same node in multiple files
- `size_flags` for the same node in multiple files
- button sizes in both scene and controller
- card outer height in both scene and card script
- dice anchors derived from card internal content

## 15. Build Order for Rebuild

Build Battle UI V2 in this exact order:

1. Static shell only
2. Three logical card slots per side
3. Fixed card boxes
4. Readout strips
5. Center action rail
6. Dice alignment to slot centers
7. Real card content
8. Styling pass

Do not skip ahead to polish before geometry is correct.

## 16. Verification Rules

Every rebuild step should be checked at `450x1000`.

Battle UI V2 is only considered structurally correct when:

- Header is fully visible
- Footer is fully visible
- All cards are equal size
- 1-unit, 2-unit, and 3-unit formations center correctly
- Dice align to card slots
- Readout strips are visible and separate from cards
- Center button is truly centered
- No scroll bars appear
- No clipping occurs at top or bottom

## 17. Notes for Future Changes

- The readout strip is expected to evolve later
- The footer item system may grow into an overlay or slide-up menu
- Decorative polish can change later
- The layout geometry should stay stable even if styling changes

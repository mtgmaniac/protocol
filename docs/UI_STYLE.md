# UI style reference

The rules for all UI work. Tokens and helpers live in `scripts/ui/pixel_ui.gd`
(`PixelUI`), the single source; `assets/ui/theme_overload.tres` only mirrors it.
History and reasons: `docs/UI_UNIFY.md`, `docs/FLAT_PIXEL_PROTOTYPE.md`.

## Ownership

- **The player owns the bottom:** PLAYER cobalt for friendly frames, primary
  buttons, selection, the footer.
- **The enemy owns the top:** the operation's ENCOUNTER color for the header
  battle count and rule and the enemy frames. Nothing else.
- **The tray is neutral shared ground:** CHROME-derived darks, never the
  encounter color.
- **CHROME carries no meaning:** text, panels, borders, secondary and disabled
  buttons. Most UI is CHROME.
- **Dice colors are constant:** hero blue, enemy red, every operation.
- Green is HP bars, heals and the uncommon rarity only (INVARIANTS #7; the rarity green is its own leaf green).

## Color tokens

| Token | Hex | Role |
|---|---|---|
| `CHROME` | `e6dec8` (bone; F10 cycles candidates) | neutral bright: titles, labels, secondary text |
| `CHROME_DIM` | `837d6e` | eyebrows, section heads, inactive |
| `CHROME_INK` | `15130e` | text on a CHROME fill |
| `PLAYER_ACCENT` | `2a6ae6` | primary buttons, selection, picks, friendly frames when targetable |
| `PLAYER_ACCENT_LIGHT` | `9cbcff` | player text and icons on dark |
| `PLAYER_ACCENT_DIM` | `1c3f82` | resting friendly frames |
| `PLAYER_ACCENT_INK` | `060d1c` | text on a PLAYER fill (active tab, pressed primary) |
| `PROTOCOL_ACCENT` | `66e0ff` (electric cyan-blue) | Protocol: meter cells, cost numbers, the keyword; the logo core's light centre |
| `ENCOUNTER_FACILITY` / `_HIVE` / `_VEIL` / `_SIGNAL` / `_MANTLE` | `cf9a36` / `c8404a` / `8f7ae0` / `b653c8` / `d89b4a` | per operation, named in `data/raw/battle-tray-scenes.json` (`accent`); `ENCOUNTER_ACCENT` holds the current battle's |
| `ENEMY_DEFAULT` | `c9755a` (rust) | enemy UI outside any operation (Help's bestiary rows: name, and the frame darkened 0.3 as in battle) |
| `WARNING` | `e8a33a` | warning text; the DESTRUCTIVE button |
| `WARNING_INK` | `1a1206` | text on a WARNING fill (a pressed destructive button) |
| `UI_BG` | `0e1216` | screen field |
| `UI_PANEL` / `UI_PANEL_EDGE` | `161c1f` / `22292d` | section panel fill / frame |
| `UI_ROW` | `202427` | row plate inside a panel |
| `UI_BUTTON` / `UI_LINE` | `1a1c20` / `4a5057` | button fill / neutral border |
| `UI_TEXT` / `UI_TEXT_DIM` / `UI_TEXT_OFF` | `e8e6df` / `8a8f94` / `4f5458` | body / secondary / disabled text |
| `RARITY_COMMON` / `RARITY_UNCOMMON` / `RARITY_RARE` / `RARITY_LEGENDARY` | `8a8f94` muted gray / `84b84a` leaf green / `9d52d8` violet / `edb03e` gold | rarity (epic = rare). The uncommon green leans yellow (hue ~88) so it never reads as a heal (`KW_HEAL` / `COLOR_HEAL`, hue ~136-141) |
| `INK_OUTLINE`, `SCRIM` | near-black, 98% / 78% | dark text edge over art / modal dim |
| `KW_DAMAGE` / `KW_HEAL` / `KW_SHIELD` / `KW_PROTOCOL` | `f2584c` / `5fd17a` / `a9bccb` / `66e0ff` | keyword colors in text |

Battle-only families: `BATTLE_*` (cards, tray), `FX_*` (float text, flashes),
`PORTRAIT_*`, `PIP_BORDERS`, effect icon colors `COLOR_*`. Never a hex in a
screen script; opacity-only modulates (`Color(1, 1, 1, a)`) are fine.

## Type roles

Two families: **m5x7** (native 16) and **Battle Block** (native 32, capitals and
digits only). Sizes are whole multiples of the native size only
(`PixelUI.lattice_px`); apply with `PixelUI.apply_type(control, role)`.

| Role | Font | Size | Use | Case |
|---|---|---|---|---|
| DISPLAY | Battle Block | 96, drawn pixel-exact (below) | screen titles, battle header | caps |
| CARD | Battle Block | 64 to 96, drawn pixel-exact (below) | battle card unit names and HP numbers | caps |
| LABEL | m5x7 | 64 (full-width primaries up to 112) | buttons, tabs, section headers, unit names off the battle card, the footer PROTOCOL label | caps |
| BODY | m5x7 | 64, line spacing 10 | descriptions, help, battle log | sentence |
| SMALL | m5x7 | 48 | rarity, version tag, cost labels, eyebrows | as written (metadata caps per the caps law) |
| NUMERAL | m5x7 | 64 (die tags 80) | intent and pip numbers, HP off the battle card | n/a |

**Battle Block draws pixel-exact.** A bitmap font keeps every stroke the same
width only when one font pixel is a whole number of screen pixels, and the
stretch scale differs per device (360 px wide: 1/3; 390: 0.361; the 540 preview:
1/2). A fixed 64 put one font pixel on 1.33 screen px at 360 and 1.44 at 390,
so strokes drew 1 and 2 px wide in the same numeral. Every Battle Block label
(`apply_type` with DISPLAY or CARD, `style_battle_text`) is laid out at its
role's cap and drawn with a scale of at most 1 (`PixelUI.bind_block_snap`) that
puts one font pixel on exactly k screen px: the smallest k at or above the
role's size, or the largest under the cap when that is over. Font pixel = size
/ 16 design px. CARD 4 to 6 (64 to 96): 96 at 360, 88.6 at 390, 64 at 540.
DISPLAY 6 (96): 96 at 360, 88.6 at 390, 96 at 540. Never set a Battle Block
label's font size directly; check with `scripts/checks/stroke_runs.py` on a
capture (every ink run a multiple of k).

**HP numerals (Kev, 2026-10-17).** CARD Battle Block, "60 / 60", centred on the
78 px bar: the line is laid out at 96, so the label grows both ways and the
snap scales about the bar's centre (it used to grow down and sat a font pixel
low). Options B (one font pixel larger, "60/60", falls back where it overruns)
and C (m5x7 thickened like the dice numerals) stay switchable by
`CompactUnitCard.HP_NUMERAL_OPTION`; A is the default. Comparison:
`debug_artifacts/ui_fix/hp_font_comparison.png`. The glyphs are a classic 5x7
set: 5 is narrower at the bottom than the top, 4 and 7 end in one column; that
is the design, not the render.

**Trait names take the unit's home colour:** the card's name colour (the
encounter-derived enemy name, the hero name), no per-trait colour.

**Card name row (88 design px).** A trait title or the BOSS tag (SMALL, m5x7 48,
the text floor) sits fully above the callsign: both are placed by glyph
extents, clear of the 3 px the card shell covers at the row's top and the 8 px
title divider at its bottom (`compact_unit_card._layout_name_lines`). A card
with neither keeps the centred callsign. The row grew 80 -> 88 for every card
(boss, trait and plain cards stay aligned) and the HP bar gave the 8 px back
(86 -> 78), so the portrait window keeps its ruled aspect.

The CARD cap (96, x3) fits the card: the longest name (AVALANCHE) and a
three-digit HP ("140 / 140") are 324 px in the 332 px label. Landscape (dev)
cards step the role down to fit and keep the same draw rule. Check widths with
`battle_ui_capture.gd --capture-card-fit`.

No extra letter spacing on any role. Text floor 48 (`TEXT_MIN_PX`); the pip
duration superscript is the one smaller exception. The dice faces keep their own
font settings.

## Components

| Component | Helper | Look |
|---|---|---|
| Primary button | `style_ui_primary_button` | dark fill, PLAYER border and thick left edge, `PLAYER_ACCENT_LIGHT` text, **the notch**; pressed PLAYER fill + INK text (the 2026-10-16 solid fill is reverted, Kev 2026-10-17) |
| Secondary | `style_ui_secondary_button` | neutral border, steel left bar, UI_TEXT |
| Disabled | (state of both) | the secondary shape, dimmed |
| Destructive | `style_ui_destructive_button` | WARNING (amber) border and WARNING text on the button fill; **no stripes, no notch** |
| Tab | `style_ui_tab` | active PLAYER fill + INK text; inactive neutral |
| Toggle / slider | `style_ui_toggle` / `style_ui_slider` | ON / fill in PLAYER |
| Section panel / row | `make_ui_section` / `make_ui_row` | CHROME panel, LABEL header, row plates |
| Selectable card | `ui_card_style` | neutral at rest, PLAYER border + faint fill when selected |
| Pick badge | `selection_badge_style` | PLAYER fill, INK numeral |
| Frames | `component_style` | NORMAL (CHROME / PLAYER_DIM for heroes), SELECTED (PLAYER), ENEMY (encounter), MODAL, MAJOR (gold, ceremonial only) |

- One border weight: 4 design px (`MIN_STROKE`). Square corners only, no corner
  brackets or four-corner notches.
- Focus: a PLAYER outline 8 px outside the button (`_ui_focus_style`).

## The notch rule

The single top-left notch marks a screen's **one primary action** (title
CONTINUE / BEGIN, reward CONFIRM, DEPLOY SQUAD, the battle's ROLL / END TURN,
the run-flow screens' commit button) and **a pop-up's main confirm**. A choice
between equals is secondary. A destructive confirm (abandon, discard) is
DESTRUCTIVE, never notched. The notch never moves.

## Protocol color

PROTOCOL_ACCENT for everything Protocol: the meter's filled cells (empty cells
dark), the footer cost numbers, Protocol drained or gained in feedback, the
Protocol keyword in text. At 10/10 the meter pulses in flat brightness steps
(off under Reduced Motion and No Animations). An unaffordable action is the
whole button at `UNAFFORDABLE_ALPHA` 0.45.

## Spacing and the pixel grid

- **One GAP: `PixelUI.GAP` = 16 design px.** It is the space between a bar and
  the cards, and between stacked blocks on every screen: header -> enemy cards,
  enemy cards -> tray, tray -> hero cards, hero cards -> footer (mirrored, all
  16), the footer row's padding above and below, the space between footer
  buttons, a run-flow screen's content below the header, and every screen-level
  column's separation. No spacer controls add a second gap. Line spacing inside
  a card or row is not a GAP.
- **Header and footer bars are the same height**: 144 design px
  (`PersistentHeader.HEADER_HEIGHT`), each with a `MIN_STROKE` divider (the
  header's along its bottom, the footer's along its top). Footer: the Protocol
  block (LABEL caps on top, the cells at the bottom) and the four action buttons
  (108 px squares, GAP apart) sit GAP from both bar edges.
- Gate: `layout rhythm` (`scripts/debug/layout_rhythm_test.gd`, windowed at 360
  and 390 px). Measure a capture with `battle_ui_capture.gd
  --capture-layout-report` and `scripts/checks/annotate_layout.py`; run-flow
  screens with `scripts/debug/screen_rhythm_probe.gd`.
- Spacing in multiples of 4 design px (one art pixel).
- Pixel art and pixel fonts draw NEAREST; item art at integer multiples
  (`make_integer_icon`); portraits only through `make_portrait_frame`.
- Strokes and 1 px elements snap to physical pixels (INVARIANTS #14).
- Scene art (title backdrop, battle backdrops, tray) is drawn on the quarter-res
  grid: 1 art px = 4 design px. Backdrop spec: `docs/BACKDROP_SPEC.md`.

## Keyword colors

Damage `KW_DAMAGE`, heal `KW_HEAL`, shield `KW_SHIELD` (steel), Protocol
`KW_PROTOCOL`. Only where text supports inline color; today no text does (all
descriptions are plain Labels, the battle log has BBCode off), so these wait
for a BBCode conversion. Never rewrite copy to add color.

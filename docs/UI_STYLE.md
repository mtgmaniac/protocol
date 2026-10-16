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
- Green is HP bars and heals only (INVARIANTS #7).

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
| `WARNING` | `e8a33a` | warning text; the DESTRUCTIVE button |
| `WARNING_INK` | `1a1206` | on a WARNING fill; hazard stripes |
| `UI_BG` | `0e1216` | screen field |
| `UI_PANEL` / `UI_PANEL_EDGE` | `161c1f` / `22292d` | section panel fill / frame |
| `UI_ROW` | `202427` | row plate inside a panel |
| `UI_BUTTON` / `UI_LINE` | `1a1c20` / `4a5057` | button fill / neutral border |
| `UI_TEXT` / `UI_TEXT_DIM` / `UI_TEXT_OFF` | `e8e6df` / `8a8f94` / `4f5458` | body / secondary / disabled text |
| `RARITY_LEGENDARY` / `RARITY_UNCOMMON` / `RARITY_COMMON` | `edb03e` gold / `aab4bd` silver / `8a8f94` gray | rarity (rare / epic `9d52d8`) |
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
| DISPLAY | Battle Block | 96 | screen titles, battle header | caps |
| LABEL | m5x7 | 64 (full-width primaries up to 112) | buttons, tabs, section headers, unit names | caps |
| BODY | m5x7 | 64, line spacing 10 | descriptions, help, battle log | sentence |
| SMALL | m5x7 | 48 | rarity, version tag, cost labels, eyebrows | as written (metadata caps per the caps law) |
| NUMERAL | m5x7 | 64 (die tags 80) | HP, intent, pip numbers | n/a |

No extra letter spacing on any role. Text floor 48 (`TEXT_MIN_PX`); the pip
duration superscript is the one smaller exception. The dice faces keep their own
font settings.

## Components

| Component | Helper | Look |
|---|---|---|
| Primary button | `style_ui_primary_button` | PLAYER border, thick left edge, LIGHT text, **the notch** |
| Secondary | `style_ui_secondary_button` | neutral border, steel left bar, UI_TEXT |
| Disabled | (state of both) | the secondary shape, dimmed |
| Destructive | `style_ui_destructive_button` | WARNING border and text, hazard-stripe left edge, no notch |
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

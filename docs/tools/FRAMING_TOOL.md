# Framing editor

A dev-only visual editor for `assets/portraits/portrait_anchors.json`, the ONE
framing entry per asset that every screen uses (docs/TRUTH.md, "Framing data").
You drag the head lines on a portrait, or the centre and scale of an item or
relic, and every screen that shows the asset previews live, side by side, at
real in-game size. The previews use the same helpers and frame sizes as the
screens themselves.

The editor never derives anchors from pixels and never edits art. The stray-pixel
scan only suggests crop insets, and nothing changes until you accept one.

## Open it

```bash
godot --path . res://dev/framing_editor/FramingEditor.tscn
```

Or open `dev/framing_editor/FramingEditor.tscn` in the Godot editor and press
**F6** (Run Current Scene). The window opens at 1800×1000. `dev/` is excluded
from the Web and Android export presets, so the editor never ships.

## Controls

| Key | Action |
|---|---|
| **1–5** | Tabs: Heroes, Enemies, Bosses, Items, Relics |
| **W / S** (or PgUp / PgDn) | Previous / next asset |
| **Up / Down** | Portraits: move the selected line (head_top or chin). Items: move the centre up/down |
| **Left / Right** | Move the centre line (portraits) or the centre (items) |
| **Shift** + arrow | 5 px instead of 1 |
| **Tab** | Switch the selected line: head_top ↔ chin |
| **Mouse drag** | Drag a line (portraits) or the centre cross (items) on the source image |
| **+ / −** | Items: scale ±0.05 (Shift: ±0.25). Integer-law screens round to a whole multiple |
| **A** | Portraits: toggle anchor framing for this asset (`use_anchors`) |
| **R** | Toggle reviewed |
| **Y / N** | Accept / reject the stray-pixel suggestion |
| Inset boxes | Crop insets per edge, in source pixels |
| **Del** | Clear this asset's entry (it goes back to its old look) |
| **G** | Grid view: every asset in the tab in one frame (pick the frame from "Grid frame"), click to select |
| **H** | Guides: the target head_top/chin lines and centre line on every preview |
| **Shift+O** | Make the current asset the onion-skin reference |
| **O** | Toggle the onion skin (reference drawn at 40% over every preview) |
| **F** | Show only assets with a pending stray flag |
| **P** | Preview scale: 0.5× (the 540-wide desktop game window) or 1× (native phone px) |
| **Ctrl+Z** | Undo (200 steps) |
| **Ctrl+S** | Save to `portrait_anchors.json` |

List markers: `A` anchored · `R` reviewed · `*` anchor framing on · `!` stray flag pending.

## How portrait framing works

- `head_top` is the top of the skull or helmet dome, never antennas, crowns,
  hoods or glow. `chin` is the bottom of the head. `center_x` is the head's
  horizontal centre. All three are source pixels of the PNG on disk.
- With anchor framing off, an asset keeps its old look, including the
  pre-anchor offsets that were moved out of code (`legacy_zoom`,
  `legacy_anchor_y`, `legacy_down_px`).
- With anchor framing on, the head is scaled to `_targets.<class>.head_height`
  of the frame height, its top is seated at `_targets.<class>.head_top`, and
  `center_x` goes to the frame centre. Because these are fractions of the frame,
  the same head framing appears on every screen. The editor test checks the
  fractions on every site.
- The first edit on a portrait with no anchors seeds them from its current
  battle-card framing, so turning anchor framing on changes nothing until you
  move a line. The heroes already have hand-declared anchors (2026-07-12), so
  pressing **A** on a hero uses those.
- Class targets (`_targets`) are edited in the JSON. The editor reloads them
  on the next launch.

## Stray pixels

```bash
python scripts/assets/stray_pixel_scan.py
```

This writes `dev/framing_editor/stray_scan.json` and only detects. It flags a
detached fragment when it lies wholly in the margin between an image edge and
the main art. The main art grows to include anything within 3 px, so dither
and glow count as art. Opaque scenic art is skipped, as is a matted bust's
bottom margin. Each flag suggests the smallest single-edge inset that removes
the fragment. In the editor the fragments show as red boxes. **Y** copies the
suggestion into `insets` and **N** records `"stray": "rejected"`. Re-run the
scan when new art lands.

## Display sites (who shows what)

Every site builds its art through its class helper. The `framing sites` gate
fails on any screen that frames art itself. Sizes are design px (1080-wide);
`dev/framing_editor/framing_sites.gd` reads them from each screen's own
constants.

| Class | Screen | Code | Frame | Helper |
|---|---|---|---|---|
| Hero, enemy, boss | Battle card | `compact_unit_card._update_portrait_rect_transform` | 328×380 | `cover_fit_portrait` |
| Hero | Squad select tile | `home_screen._build_unit_tile` / `_cover_fit_portrait` | 230×266 | `cover_fit_portrait` |
| Boss | Encounter panel thumb | `home_screen` (boss thumb) | 216×252 | `cover_fit_portrait` |
| Hero | Evolution branches | `evolution_screen` | 162×188 | `cover_fit_portrait` |
| Hero | Unlock screen / run end | `unlock_screen._make_hero_row` | 144×167 | `cover_fit_portrait` |
| Hero, enemy, boss | Help › Units rows | `help_menu` unit rows | 96×96 | `cover_fit_portrait` (was a private cover-fit) |
| Item | Reward row | `reward_screen` | 256 | `make_integer_icon` |
| Relic | Relic reward card | `reward_screen` | 256 | `make_integer_icon` |
| Consumable | Battle item card | `item_card` (via `protocol_actions`) | 182 | `make_integer_icon` |
| Consumable, relic | Inventory (Item button) | `loadout_menu._make_icon` | 136 | `make_item_art` contain (was a raw TextureRect) |
| Item, relic | Unlock grid | `unlock_screen._make_icon_grid` | 128 | `make_integer_icon` |
| Relic | Boss relic unlock | `unlock_screen` | 256 | `make_integer_icon` |
| Relic | Starting Directive picker | `home_screen._open_directive_picker` | 168 | `make_item_art` contain (was a raw TextureRect) |
| Item, relic | Inspect popup header | `inspect_popup._build_header` | 84 | `make_item_art` cover (was a raw TextureRect) |
| Gear | Inspect popup gear rows | `inspect_popup._build_gear_row` | 64 | `make_item_art` contain (was a raw TextureRect) |

The inspect popup shows no unit portrait (by design). The run-end screen shows
units through the unlock screen.

**Known exception:** the parked landscape battle plate
(`compact_unit_card._battle_plate`, `LANDSCAPE_BATTLE_ENABLED = false`) shows
native-aspect art outside the portrait window. It is dead in production, and
TRUTH lists it as an open landscape question.

**Integer law note:** the four contain/cover sites (inventory 136, inspect 84,
gear row 64, Directive 168) were already scaling 128 px art by non-integer
factors before the helper existed. They are kept pixel-identical. Moving one
to the integer law is a one-word mode change at its call.

## Gates and evidence

- `framing data`: `scripts/checks/framing_data.py`. Schema, every key is a live
  asset in the right section, values in range.
- `framing sites`: `scripts/checks/framing_sites.py`. Static helper routing,
  plus `dev/*` in every export preset's exclude filter.
- `framing editor`: `dev/framing_editor/FramingEditorTest.tscn`. Editing,
  previews, undo, stray accept/reject, save round trip, and a check that the
  real file is untouched.
- `framing sheet`: the editor with `--framing-sheet=<png>`. One sample asset of
  each type on every screen that shows it, written to
  `debug_artifacts/framing/capture_sheet.png`.
- Export proof: `godot --headless --path . --export-pack Web out.pck`, then
  `python scripts/checks/pck_list.py out.pck --grep dev/`. A raw string
  search is not evidence, because the pack's UID cache still names excluded
  paths.

# Landscape Stage B — typography and polish

Approved by Kev after Checkpoint 2, 2026-09-23. Builds on Stage A commit
`f427037`. The production flag remains false. No deployment or merge into the
original dirty checkout is included.

## Presentation changes

The shared `CompactUnitCard` now has a per-instance `apply_battle_presentation`
API. Landscape requests 1.5× typography; portrait instances retain the default
1.0 and do not call the API. This changes individual fonts and component
dimensions, not the scale of the whole UI.

| Element | Portrait/default | Landscape |
|---|---:|---:|
| Unit name and HP font | 72 | 108 |
| Boss sublabel and cast-order font | 48 | 72 |
| Name strip | 80 | 120 |
| HP band | 86 | 129 |
| Cast badge size | 56 | 84 |
| Header summary font | 112 | 144 |
| Header content band | 144 | 192 |
| Header buttons | 112 | 152 |
| Protocol label font | 60 | 100 |
| Protocol footer band | 144 | 208 |
| Protocol buttons | 112 | 160 |
| Protocol cost font | 48 | 72 |
| Roll/End Turn nominal font passed to the existing font helper | 48 | 80 |

Values are design pixels, rendered through the unchanged canvas stretch. At
1280×720, the larger name/HP fonts are 32.4 physical pixels before the existing
font's glyph metrics; header text is 43.2. The original font assets, colors,
hierarchy, cover-fit portraits, filters and interaction controls remain shared.
Dice numerals and ability pips retain Stage A's enlarged die-relative rendering;
there is no new label renderer or ability implementation.

Status icons and values grow within the existing three-chip plus overflow row.
Landscape numeric chips measure their actual font width and select one fitted
size for multi-digit values. This avoids overflow from three large values and
preserves the shared overflow/inspection behavior. The portrait fitting rule
remains exactly as before. Status plate widths use physical pixel scale.

The landscape strategy reserves the taller header/footer bands, balances the
card width against the remaining height, and keeps the central tray dominant.
All cards and six dice remain visible at 1920×1080, 1280×720 and 960×600. No
scrolling was added. Existing max-three/summon behavior remains unchanged.

`PersistentHeader.set_battle_landscape` styles only the active landscape battle.
The scene's exit signal restores the original header font, band and buttons;
resize retains the active style. Help/inspect overlays read the real band height.
There is no persistent setting or global theme change. The footer and cards are
battle-owned instances, so their overrides disappear with the battle.

## Scope and code ownership

Stage A's single battle scene, shared controllers, default-false flag, platform
rules, tutorial exception and dev override are unchanged. See
`LANDSCAPE_STAGE_A.md` for the architecture and activation instructions.

Stage B changes only `compact_unit_card.gd`, `PersistentHeader.gd`,
`landscape_battle_layout.gd`, the layout delegate, battle chrome font/size hooks,
Protocol cost typography, regression tests and documentation. No balance, data,
RNG, saves, progression, tutorial content, audio, font assets, global themes,
project viewport/stretch settings or non-battle screen layout was changed.

## Verification

- Dedicated layout test: **410 checks, zero failures**, including header
  restoration after landscape → main menu, scoped fonts, card/HP/status bounds,
  long name and boss HP fit, three simultaneous three-digit statuses plus
  overflow, cast badge, existing pointer/target callbacks and Stage A's summon,
  Brood, tutorial and deterministic-roll coverage.
- Existing gate with `--skip-sim`: **52 passes / 1 failure**, unchanged from
  Stage A. Tutorial reachability remains the gate failure associated with the
  Windows certificate-store error; no new gate failures. An earlier run with
  an unnormalized test-profile path was discarded and rerun with an absolute
  isolated APPDATA path. No save implementation or gate threshold was changed.
- Existing flow smoke with landscape forced passes through menu, battle,
  rewards, next battle and both run-end routes.
- Portrait screenshot comparison against the pre-edit committed-source baseline:
  HUD, hero/enemy card and Protocol regions are pixel-identical at all four
  captured sizes. Entire 432×960 and 390×844 images are identical; 540×1200 differs
  by one dice pixel, and the desktop difference stays within one cosmetic die
  region. No measured portrait layout regression.
- Native captures cover 3v3, Matriarch + escort + spawned third enemy, a synthetic
  typography/status stress fixture, tutorial AUTO/forced initialization, and the
  main menu after leaving landscape. The stress fixture changes display-only
  values for the screenshot, not game data or balance.
- Debug and release Web exports succeed. Browser evidence and exact tested
  viewport/iframe sizes are indexed in the accompanying Stage B review report.
- In-app browser: forced landscape at 1280×720 and 1920×1080, rolled dice,
  target assignment and reward transition; release AUTO portrait at 1920×1080
  and 640×960. The reward header restores its default presentation.
- Local iframe: current 640×960 AUTO portrait and proposed 960×600 forced
  landscape captured. Fullscreen fills the native 3440×1440 viewport correctly.
  Fullscreen with a temporary 1920×1080 browser override showed a canvas/output
  scaling mismatch; resetting the override restored correct rendering. This is
  retained as a test-environment limitation, not counted as a passing emulated
  fullscreen check. Actual itch.io settings were not changed.

No physics code changed in Stage B; the Stage A physics probe remains applicable
(eight rolls, zero penetrations/flyovers/tilted rests/frozen drift). No balance
simulation or per-operation delta was generated for this presentation-only pass.
Existing missing-audio and shutdown warnings remain; no baseline was updated.

## Remaining limitations

The pre-existing die-click Nudge cancellation is preserved; do not claim that
interaction succeeds. The shared card callback and normal target selection work.
Tutorial AUTO stays portrait. Explicit forced-landscape tutorial initialization
is tested, but full landscape tutorial support and all 21 coach beats remain
outside this task. No tutorial content was changed.

Native normal launch still uses its existing fixed portrait window. Native
widescreen captures use the test harness; web naturally receives the available
canvas. Physical phones/tablets and browser engines beyond the tested in-app
browser remain release-validation work. Desktop OS tablets still have the
Stage A device-detection limitation. Do not enable the player flag or change
itch settings without separate release approval.

Keep the implementation as a shared-component experiment ready for visual
review. Future features remain implemented once; placement and sizing still
need checks in both orientations. No second battle UI was introduced.

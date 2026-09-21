# UI consistency polish — 2026-09-20

Scope: battle portrait positioning, Help organization and reference readability,
desktop cursor and interaction polish. Version: `0.9.0-demo4`.

## Findings and changes

- Strike, Splice and Engineer already shared the same portrait layout and zoom.
  Engineer's source art ends above a matte black bottom region; the shared upward
  content offset exposed that region. A shared 6 physical pixel downward correction
  removes the strip while maintaining identical friendly framing and existing zoom.
- Scrap/Rust clipping came from the upward portrait offset. Their content alone
  moves down 5 physical pixels. Skitter, Shard and Prism were checked and did not
  need the correction. Enemy size, cover scale, crop frame and HP placement stay intact.
- Help now has Basics, Units, Battle Log and Settings, opening directly on Basics.
  Basics contains the turn/card rules, Protocol, evolution/rewards, win/loss and
  Replay Tutorial. Keywords / Icon Guide opens one secondary combat glossary.
  Units contains Squad plus Facility Sweep, Hive Incursion, Veil Breach, Signal Purge
  and Mantle Hunt, sourced from canonical operation data.
- Descriptors increase from 27 to 46 font units; names from 33 to 44. Rows grow to a
  minimum 154 design pixels with consistent spacing, square 96px thumbnails,
  top-aligned uniform cover fitting and stronger secondary variant connectors.
  A scrollbar gutter keeps all HP values visible on a common right edge.
- Help buttons gain restrained hover feedback. Wheel scrolling works over rows;
  Escape dismisses inspection, returns from reference subsections, then closes Help.
- Native 32px default/interactive cursors are directly rasterized as a solid polygon
  matching the supplied pointer: tall left edge, long diagonal face, lower ledge and
  diagonal tail return. Continuous scanlines prevent holes or scaling artifacts, and
  both states share the exact (2,2) hotspot.
  Buttons opt into the interactive cursor; the game canvas does not scale the cursor.
- The Squad Selector keeps its existing shared frame and zoom while applying the
  proven 6-physical-pixel correction only to Engineer; battle framing is untouched.

## Evidence

Captured before edits and after changes at 486×1080 using the real native renderer:

| Surface | Before | After |
|---|---|---|
| Battle | `debug_artifacts/ui_polish/battle_before.png` | `debug_artifacts/ui_polish/battle_after.png` |
| Units | `debug_artifacts/ui_polish/units_before.png` | `debug_artifacts/ui_polish/units_after.png` |

Other enemy comparisons: `hive_before.png`, `veil_before.png` in the same folder.
Chrome 1440×900 DPR 1/2 captures: `web_units_dpr1.png`, `web_units_dpr2.png`.
Actual cursor textures: `cursor_default.png`, `cursor_hover.png`.

## Verification

- Baseline: `python scripts/verify_gate.py --skip-sim` PASS before this polish.
- Focused `help_polish_test.gd`: PASS headless and native; all filters, thumbnail
  dimensions, HP visibility/right alignment, actual wheel input and Escape navigation.
- `icon_guide_capture.gd`: PASS Basics reference entry and More Effects navigation.
- Chrome and Edge `help_browser_test.cjs`: PASS DPR 1 and 2 with actual mouse input, distinct
  custom cursor URLs and hotspots, scrolling, small close button and Escape.
- Dice physics probe: 8 rolls, zero penetration/flyover events, zero frozen drift.
- Non-sim gate initially found the obsolete default-page tutorial replay assertion;
  updated test finds replay directly on Basics and passes. Final full non-sim rerun:
  **All hard gates PASS**, recorded in `debug_artifacts/ui_polish/gate_final.log`.
  The separately passing Help regression is also registered for future gate runs.
- No balance surfaces changed; per-operation sim deltas and baseline updates are
  not applicable. Local exports only; no public deployment.

Existing missing summon/revive audio warnings are unrelated to this UI scope.
The exporter also reports the existing Ziva editor extension's unavailable Windows
DLL; the Web pack is generated and the exported game passes browser checks.

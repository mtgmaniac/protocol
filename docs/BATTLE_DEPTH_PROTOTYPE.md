# Battle depth prototype — 2026-10-13

TASK: Test one environmental tray and cosmetic dice depth on
`codex/battle-depth-prototype`, then stop for visual review.

STEP 0 — CONTEXT: Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, the runtime reference,
TASK_QUEUE and TASK_TEMPLATE. Branched from the current `codex/battle-ui-pixel-restyle`
checkout with its existing uncommitted component work preserved. No commits made.

CONSTRAINTS: Invariants 1 (positions never affect combat), 7 (PixelUI owns colors),
10 (documentation), 11 (portrait layout) and 14 (physical pixel snapping). Existing
cards, header, actions, portrait/dice art, physics and combat remain as found.

CHANGE: A code-drawn shallow metal bay inside the current tray rectangle; no new
asset generation. The existing die cosmetic container combines its settle scale
with a clamped 0.90–1.10 projected-y multiplier, independent of rigid bodies and
collision shapes. Bounds already read that cosmetic scale, so die tags and hit
regions follow it. Shadows are translucent ellipses behind the dice viewport;
they vary with depth and hop height. No perspective camera or new physics system.

VERIFY:
- Godot 4.6.2 import/load and actual rendered capture completed without script errors.
- `component_contract.py`: PASS. `git diff --check`: PASS.
- `roll_button_clearance_test.gd`: PASS; hero gap 42.3 px, enemy gap 52.2 px
  against the existing 40 px floor.
- Eight-roll physics probe: zero penetration, zero frozen drift, zero tilted rests;
  10 flyover events. The original script reported 0 in a separate ordinary run.
  A fixed-60-fps comparison reported 101 original / 60 prototype flyover samples,
  both still with zero penetration, frozen drift and tilted rests. This probe is
  timing-sensitive here; it does not establish a clean zero-flyover pass or identical
  trajectories. No physics parameters were changed to chase its result. Logs are
  `debug_artifacts/depth_{baseline_,}physics.log` and
  `debug_artifacts/depth_{baseline_fixed,physics_fixed}.log`.
- Screenshot: `debug_artifacts/battle_depth_prototype.png` (1080 x 2400).
- Relevant checks only, per canonical TRUTH / G-59. No balance changes or sim run.

REPORT: No baseline pins changed. Visual prototype only; no balance delta claimed.
The physical footprint stays constant while visible size varies by up to 10%,
so apparent contacts can differ slightly from exact mesh edges during a throw.

CLOSEOUT: TRUTH and DECISIONS_RESOLVED updated; first rendered treatment retained
for review. No follow-on UI restyle or visual iteration performed.

---

# Battle depth prototype v2 (rendering only), 2026-10-13

TASK: Give the tray a sense of place and depth on `proto/battle-depth-v2` (from
`codex/battle-depth-prototype` at `d18fda2`) without adding information, then stop
for a feel review.

STEP 0 - CONTEXT: Read TRUTH (Dice rules), INVARIANTS and DECISIONS_RESOLVED
(G-24, G-31, G-32, G-47 and the v1 entry). The task was transcribed into
DECISIONS_RESOLVED first. The v1 scene matched `debug_artifacts/battle_depth_prototype.png`.
The task named `bug_artifacts/`; the images live in `debug_artifacts/`. The mood
reference arrived as a chat attachment and is saved as
`debug_artifacts/battle_depth_v2/reference_chatgpt_mockup.webp`. No full gate was
asked for, so no step-0 snapshot was taken.

CONSTRAINTS: INVARIANTS #1 (dice positions never reach combat: the projection is
read by drawing only), #7 (PixelUI owns colours; plates are filled, not outlined),
#11 (portrait layout frozen), #13 (the `battle_scene.gd` line watermark is not
raised), #14 (wall and floor corners snap to physical pixels). Dice rules 1 to 10
unchanged. No gameplay, balance data, copy, layout or other scene touched.

CHANGE:
- `scripts/ui/battle_depth.gd` (new): the one draw-time projection, plus the two
  debug switches.
- `scripts/battle/dice_tray_3d.gd`: `Visuals` is scaled AND moved through the
  projection; the drawn die is clamped to the tray; contact shadows follow the
  drawn position; `get_die_screen_position` / `get_die_screen_bounds` return the
  drawn die. Bodies, shapes, walls, throws, hops, slots and snaps are untouched.
- `scripts/ui/battle_bay_floor.gd`: rewritten as the tray scene (back wall art
  slot, side walls, perspective floor, edge accent, reactor decal).
- `data/raw/battle-tray-scenes.json` (new): scene per operation. Facility filled,
  Hive and Veil stubs.
- `assets/battle_tray/` (new): `placeholder_facility_wall.png`,
  `placeholder_facility_floor.png`, `reactor_emblem_decal.png`. Regenerate with
  `debug_artifacts/battle_depth_v2/make_placeholder_art.py`, then reimport.
- `scripts/ui/pixel_ui.gd`: v2 bay colours, depth numbers, the tag plate style.
- `scripts/battle/battle_scene.gd` / `battle_layout.gd`: the tag plate, the
  operation id handed to the scene, F6 / F7.
- `scripts/ui/protocol_pips.gd`: the white empty cells (a real bug, see REPORT).
- `scripts/debug/battle_ui_capture.gd`: `--capture-depth-flat-output=<path>`
  saves the same frame again with the scene and decal off.

VERIFY (targeted only; the full gate was not run, as asked):
- Boot: `BattleScene.tscn` loads headless with no script errors. Rendered captures
  at 1080x2400 and 390x867 completed with no errors.
- `debug_artifacts/battle_depth_v2/depth_probe.gd` (scratch probe, not a gate), on
  a tray the size of the battle tray, checked on every drawn frame: 20 full throws
  (1,372 frames) and 20 consecutive reroll hops (963 frames). 0 failures. Every
  die's drawn hull stayed inside the tray (closest approach 2.0 px inside), no
  face label changed while a die moved, every die ended flat with its numeral
  upright, the landed face was the roll, and no other die moved during a hop.
  Log: `debug_artifacts/battle_depth_v2/depth_probe.log`.
- `dice face` gate at 1080x2400: PASS, 0 failures on all twelve criteria
  (containment (i) 86,314 checks; hop and tip-over hulls (k) 1,073,687 checks).
- `roll_button_clearance_test.gd`: PASS. Hero gap 52.4 px, enemy gap 42.5 px,
  floor 40 (v1: 42.3 and 52.2).
- `component_contract.py`: PASS. `battle_scene_growth.py`: PASS (3,639 lines,
  watermark 3,640). `git diff --check`: clean.
- Not run: `dice face 540x1200`, `reroll hop`, `tutorial recorded throws`, the
  sim, anything on a phone or a web build.

REPORT: No balance surface touched; no pins moved; no sim run.
- Measured at 1080 wide: enemy die 154 px, hero die 186 px (83%). At 390 wide
  that is 56 px and 67 px.
- **The white Protocol cells were a real bug, not a capture artifact.** It came in
  with the 2026-10-12 component restyle on this branch line (main draws plain
  rectangles). `ProtocolPips._draw` made its two cell styles as locals; they were
  freed when `_draw` returned, their textures with them, so the queued draw had no
  texture and painted white. Holding the styles on the node fixes it: the cells
  are dark in every v2 capture.
- Limits. The dice are still drawn top-down, so depth comes from size, position,
  the shadow and the floor, not from seeing a die's side. A resting die sits about
  40 px (enemy) or 20 px (hero) inside its card's centre at 1080 wide. The wall
  slot is 15.5% of the tray (33 art pixels tall at 1080); taller would push the
  enemy row into the Roll button's 40 px clearance, which now has 2.5 px to spare.
  The lower half of the wall sits behind the enemy tags. F6 / F7 are keyboard
  only: there is no touch path, because the task ruled out new buttons. Signal and
  Mantle have no scene entry and draw the bare bay like the Hive and Veil stubs.

CLOSEOUT: TRUTH and DECISIONS_RESOLVED updated. Nothing committed: the work is
uncommitted on `proto/battle-depth-v2` for review. Captures:
`debug_artifacts/battle_depth_v2.png` and `battle_depth_v2_flat.png` (390 px wide,
the same roll), with 1080 px copies in `debug_artifacts/battle_depth_v2/`.

---

# Battle depth prototype v3 (rendering only), 2026-10-13

TASK: Push the scene toward the reference mood (composition, atmosphere,
layering; not its painterly rendering) and make the die tags transparent again,
on `proto/battle-depth-v3`. Then stop for a feel review.

STEP 0 - CONTEXT: v2 was committed first, as asked: `aaed29a` (the ProtocolPips
fix alone) and `f2b2beb` (the rest of v2). The v2 TRUTH.md and DECISIONS_RESOLVED.md
edits stay uncommitted and untouched; this log is the only record of v3. Dice
rulings re-read; nothing here touches them. The reference is
`debug_artifacts/battle_depth_v2/reference_chatgpt_mockup.png`.
`assets/fonts/battle_block.svg.import` was already modified in the working tree
by something other than this task; it is left out of every commit.

CONSTRAINTS: As v2 (INVARIANTS #1, #7, #11, #13, #14; Dice rules 1 to 10). No
dice physics, tray bounds, gameplay, balance data, copy, card or footer change.
Die tags go back to transparent (the 2026-07-09 ruling); the v2 plate survives
only behind F8. No verify_gate and no dice face gate: a boot/smoke check only.

CHANGE:
- **Full-bleed scene** (`scripts/ui/battle_bay_floor.gd`, rewritten). It now sits
  behind the whole board, not in the tray: a back wall behind the enemy cards
  (slab texture, a ledge at its foot, a rust run near the top right), slab side
  walls down both edges with horizontal seams toward the vanishing point and four
  lit amber window slots near the top, and one floor that runs from the back wall
  through the tray and on under the hero cards, widening the whole way. The floor
  edges are the same lines the dice are clamped to, so a die meets the floor's
  edge where it bounces. The tray's frame and fill are off while the scene is on.
- **Pixel grid.** BattleLayout puts the painter in a SubViewport a quarter of the
  screen's size, shown 4x with NEAREST, so every slanted edge, step and warped
  texel is one art pixel (4 design px), like the portraits. No gradients; the only
  soft edges are the dice's contact shadows.
- **Floor:** flat dark panels (`placeholder_facility_floor_panels.png`) in
  perspective, darker toward the back in flat bands; a dark seam plus short amber
  hazard dashes on both slanted edges.
- **Reticle decal** (`placeholder_reactor_reticle_decal.png`): the logo's reactor
  emblem at the centre with its core as a filled disc, a dashed inner ring, a
  four-arc outer ring and crosshair ticks. Tinted with the operation accent at
  22%, under the dice and shadows.
- **Vignette:** hard steps of black (`PixelUI.BATTLE_VIGNETTE_STEPS`) toward both
  screen edges, around both card rows (lighter), and under both die tag rows
  (the back wall's foot and the floor's front edge, which is the darker edge
  where the floor meets the hero row).
- **Header:** the battle count is a second label in the operation accent, and a
  4 px rule runs under the title to the buttons. Both are off outside battle and
  with the scene off. No other header change.
- **Transparent die tags:** no plate; every icon gets a hard dark outline (eight
  black copies one 4 px step out, behind it) and every digit a dark text outline
  (`PixelUI.make_battle_tag_field`). Sizes, positions and content are unchanged.
  F8 restores the v2 plate. F6 and F7 still switch the scene and the decal.
- **Data** (`data/raw/battle-tray-scenes.json`): per operation, `wall_texture`,
  `floor_texture`, `accent` (decal and battle count), `edge_accent` (hazard dashes
  and window slots) and `streak`, all PixelUI token names. Facility filled; Hive,
  Veil and the fallback stay bare stubs. The v2 conveyor wall art and grating are
  deleted: the wall strip where they sat now carries the enemy tags.
- New art comes from `debug_artifacts/battle_depth_v3/make_placeholder_art_v3.py`
  (PLACEHOLDER, scripted). `reactor_emblem_decal.png` stays as the reticle's source.
- `scripts/debug/battle_ui_capture.gd`: `--capture-depth-plates-output=` (the same
  frame with F8 on), `--capture-depth-flat-output=` (then scene and decal off), and
  `--capture-mid-roll-ms=` (press Roll, capture mid-throw).

VERIFY:
- Boot: `BattleScene.tscn` loads headless, no script errors. Four rendered captures
  at 390x867 completed with no errors.
- `component_contract.py`: PASS. `battle_scene_growth.py`: 3,639 lines (watermark
  3,640). `git diff --check`: clean.
- Dice code is untouched since v2 (`dice_tray_3d.gd` unchanged), so the v2 probe
  and dice face results stand; not re-run.

REPORT:
- Deliverables (390 px wide, `debug_artifacts/battle_depth_v3/`):
  `battle_depth_v3.png`, `battle_depth_v3_plates.png` and `battle_depth_v3_flat.png`
  are the same frame; `battle_depth_v3_tumble.png` is 380 ms into a throw.
- **"BATTLE RESUMED" banner over the enemy dice: it happens on main too.** The
  banner code (`BattleFeedback.show_resume_callout`) is identical on main. It is
  placed 24 px below the top of the centre panel, which is the enemy dice row.
  Running the checkpoint save and resume legs windowed on a scratch main worktree,
  the banner sits across both enemy dice:
  `debug_artifacts/battle_depth_v3/resume_banner_main.png` (main) and
  `resume_banner_v3.png` (this branch). Not fixed. Separately, those windowed resume
  legs fail their own "banner names the restored round" check on main and here
  alike (they resumed round 2 and round 1); not investigated.
- Could not / did not:
  - The mockup's header has no box; ours keeps its framed band (no other header
    change was allowed), so the scene starts below it and the rust run starts at
    the header's bottom edge, visible only between the enemy cards.
  - With three enemies the middle card covers the rust run.
  - Most of the back wall sits behind the enemy cards; only the strip below them,
    the gap between them and the side walls show.
  - Tag row darkening is placed by fixed shares of the tray height, not read from
    the live tags. It matches the measured rows at the shipped layout.
  - F6, F7 and F8 are keyboard only.

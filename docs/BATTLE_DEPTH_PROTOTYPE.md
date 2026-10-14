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
